public with sharing class PurgeSourceDocumentsLDVBatch implements Database.Batchable<SObject>, Database.Stateful {

    //private properties
    //an wrapper instanse
    private RecordProcessingStatistics recordStatistics;
    private final LDVPurgeHandler purgeHandler;
    private final static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    public PurgeSourceDocumentsLDVBatch() {
        this.purgeHandler = new LDVPurgeHandler();
        //initialize the default processing statistics
        this.recordStatistics = new RecordProcessingStatistics();
    }

    public PurgeSourceDocumentsLDVBatch(LDVPurgeHandler purgeHandler, RecordProcessingStatistics result) {
        this.purgeHandler = purgeHandler;
        //whenever it calls itself make sure to keep the previous processing statistics
        this.recordStatistics = new RecordProcessingStatistics(result);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return DomainUtils.getQueryLocator(purgeHandler.getSDQuery());
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        if (!purgeHandler.checkJobRunning()) {
            this.recordStatistics = purgeHandler.purge(scope,this.recordStatistics);
        }
    }

    public void finish(Database.BatchableContext bc) {
        purgeHandler.purgeRelatedRecords();
        if (purgeHandler.hasNext()) {
            purgeHandler.setNext();
            PurgeSourceDocumentsLDVBatch batch = new PurgeSourceDocumentsLDVBatch(purgeHandler,recordStatistics);
            Database.executeBatch(batch);
        }else{
            //send an email once all the chunks has been finished
            sendEmail();
        }
    }
    /**
     * Send an email to the user containing the processed, succeeded, and failed record counts
     */
    private void sendEmail() {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        List<String> toAddresses = new List<String>{UserInfo.getUserEmail()};
        mail.setToAddresses(toAddresses);
        mail.setSenderDisplayName(Label.COMMON_ACCOUNTING_SEED);
        mail.setSubject(Label.INF_PURGE_DOCUMENT_STUCK_JOB_IS_COMPLETED_SUBJECT);

        //prepare email body
        mail.setPlainTextBody(Label.INF_PURGE_DOCUMENT_STUCK_JOB_IS_COMPLETED_BODY
            + '\n' + Label.COMMON_RECORDS_PROCESSED + ': ' + String.valueOf(recordStatistics.processedRecords)
            + '\n' + Label.COMMON_RECORDS_SUCCEEDED + ': ' + String.valueOf(recordStatistics.succeededRecords)
            + '\n' + Label.COMMON_RECORDS_FAILED + ': ' + String.valueOf(recordStatistics.failedRecords));
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail});
    }
    private with sharing class LDVPurgeHandler{

        private final Set<SObjectType> sdCollection = new Set<SObjectType>{
            Billing__c.SObjectType,
            Account_Payable__c.SObjectType,
            Cash_Receipt__c.SObjectType,
            Cash_Disbursement__c.SObjectType,
            Journal_Entry__c.SObjectType,
            Billing_Cash_Receipt__c.SObjectType,
            AP_Disbursement__c.SObjectType
        };

        private SourceDocumentBatchHelper helper;
        private Schema.SObjectType currentSObjectType;
        private Schema.SObjectType lineSObjectType;
        private String parentRelationshipField;

        private LDVPurgeHandler() {
            helper = new SourceDocumentBatchHelper();
            setNext();
        }

        private Boolean hasNext() {
            return !sdCollection.isEmpty();
        }

        private void setNext() {
            if (!sdCollection.isEmpty()) {
                currentSObjectType = new List<SObjectType>(sdCollection)[0];
                sdCollection.remove(currentSObjectType);
            }
            this.lineSObjectType = helper.mParentToChild.get(this.currentSObjectType);
            this.parentRelationshipField = SourceDocumentBatchHelper.mChildRelationship.get(this.lineSObjectType).getDescribe().getName();
        }

        private String getSDQuery() {
            SelectorAbstract lineSelector = (SelectorAbstract) this.helper.mSelectors.get(this.lineSObjectType).newInstance();
            Set<String> fields = new Set<String> {'Id'};
            fields.add(this.parentRelationshipField);

            if (currentSObjectType == Billing_Cash_Receipt__c.getSObjectType() || currentSObjectType == AP_Disbursement__c.getSObjectType()) {
                lineSObjectType = Transaction__c.getSObjectType();
                if (currentSObjectType == Billing_Cash_Receipt__c.getSObjectType() ) {
                    lineSelector.postingStatusField = 'Billing_Cash_Receipt__r.Status__c';
                    fields.add('Billing_Cash_Receipt__c');
                    fields.add('Billing_Cash_Receipt__r.Billing__c');
                } else {
                    lineSelector.postingStatusField = 'AP_Disbursement__r.Status__c';
                    fields.add('AP_Disbursement__c');
                    fields.add('AP_Disbursement__r.Account_Payable__c');
                }
            }

            String query =
                'SELECT ' +
                    String.join(fields, ',') +
                    ' FROM ' + lineSObjectType.getDescribe().getName() +
                    ' WHERE ' + lineSelector.postingStatusField + ' IN ' +
                    '(\'' + AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTING_IN_PROGRESS + '\', \'' + AbstractPostHandler.DEFAULT_POSTING_STATUS_UNPOSTING_IN_PROGRESS + '\')';

            return query;
        }

        private void purgeRelatedRecords() {
            if (currentSObjectType == Billing_Cash_Receipt__c.getSObjectType() || currentSObjectType == AP_Disbursement__c.getSObjectType()) {
                String sourceField = currentSObjectType == Billing_Cash_Receipt__c.getSObjectType() ? 'Billing__c' : 'Account_Payable__c';
                String query =
                    'SELECT Id, ' +
                        sourceField +
                        ' FROM ' + currentSObjectType.getDescribe().getName() +
                        ' WHERE Status__c IN ' +
                        '(\'' + AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTING_IN_PROGRESS + '\', \'' + AbstractPostHandler.DEFAULT_POSTING_STATUS_UNPOSTING_IN_PROGRESS + '\')';

                Map<Id, SObject> sobjectByIds = new Map<Id, SObject>(Database.query(query));
                if (!sobjectByIds.keySet().isEmpty()) {
                    helper.setPostingStatus(
                        new List<Id> (sobjectByIds.keySet()),
                        AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                        currentSObjectType
                    );
                }
                Set<Id> sourceForDelete = new Set<Id>();
                for (SObject obj : sobjectByIds.values()) {
                    sourceForDelete.add((Id) obj.get(sourceField));
                }
                SFDCSecurityUtils.deleteProxy(queryTransactionGroup(sourceForDelete));
            }
        }

        private Boolean checkJobRunning() {
            List<String> batchApexClasses = PostProcessor.BATCHES_BY_SOBJECT_TYPES.get(currentSObjectType).values();
            return BatchJobUtils.checkJobRunning(new Set<String>(batchApexClasses));
        }

        private RecordProcessingStatistics purge(List<SObject> scope,RecordProcessingStatistics recordStatistics) {
            if (!scope.isEmpty()) {
                List<Transaction__c> transForDelete = scope[0].getSObjectType() == Transaction__c.getSObjectType() ?
                    (List<Transaction__c>) scope :
                    TransactionActions.queryTransactions(scope, AccountingSettingsHandler.isHeaderLevelPost(), 1000);

                Set<Id> sourceForDelete = new Set<Id>();
                String field = String.valueOf(SourceDocumentBatchHelper.mChildRelationship.get(lineSObjectType));
                if (currentSObjectType == Billing_Cash_Receipt__c.getSObjectType() || currentSObjectType == AP_Disbursement__c.getSObjectType()) {
                    field = currentSObjectType == Billing_Cash_Receipt__c.getSObjectType() ?
                        'Billing_Cash_Receipt__r.Billing__c' : 'AP_Disbursement__r.Account_Payable__c';
                }

                sourceForDelete = getSourceIdForDelete(field, scope);
                TransactionActions.deleteTransactions(transForDelete);
    

                List<Transaction_Group__c> txnGroups = queryTransactionGroup(sourceForDelete);
                recordStatistics.processedRecords+=txnGroups.size();

                if(txnGroups.size() > 0){
                    //delete the transactions
                    List<Database.DeleteResult> results = SFDCSecurityUtils.deleteProxyDatabase(txnGroups,false);

                    //calculate the succeeded and failed record count
                    for(Database.DeleteResult result : results){
                        if(result.isSuccess()){
                            recordStatistics.succeededRecords+=1;
                        }else{
                            recordStatistics.failedRecords+=1;
                        }
                    }
                }

                helper.setPostingStatus(
                    new List<Id> (sourceForDelete),
                    AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                    currentSObjectType
                );

                try {
                        //check for other transaction groups and delet them
                    List<Transaction_Group__c> txnGroupBySourceStatuses = queryTransactionGroupBySourceStatuses(new Set<String>{
                                        AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                                        AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED
                                    });
                    if(txnGroupBySourceStatuses != null && txnGroupBySourceStatuses.size() > 0){
                        //calculate the processed records count
                        recordStatistics.processedRecords+=txnGroupBySourceStatuses.size();

                        //delete extra transaction groups
                        List<Database.DeleteResult> deleteResults = SFDCSecurityUtils.deleteProxyDatabase(txnGroupBySourceStatuses,false);

                        //calculate the succeeded and failed record count
                        for(Database.DeleteResult result : deleteResults){
                            if(result.isSuccess()){
                                recordStatistics.succeededRecords+=1;
                            }else{
                                recordStatistics.failedRecords+=1;
                            }
                        }
                    }
                } catch (Exception e) {}
            }
            return recordStatistics;
        }

        private Set<Id> getSourceIdForDelete(String field, List<SObject> scope) {
            Set<Id> sourceForDelete = new Set<Id>();
            for (SObject obj : scope) {
                if (field.contains('__r')) {
                    sourceForDelete.add((Id) obj.getSObject(field.substringBefore('.')).get(field.substringAfter('.')));
                } else {
                    sourceForDelete.add((Id) obj.get(field));
                }
            }
            return sourceForDelete;
        }

        private List<Transaction_Group__c> queryTransactionGroupBySourceStatuses(Set<String> statuses) {
            List<String> fieldsToQuery = new List<String>{'Id'};
            List<String> conditions = new List<String>();
            for (String statusField : new Set<String>{
                PACKAGE_QUALIFIER + 'Billing__r.' + PACKAGE_QUALIFIER + 'Status__c', 
                PACKAGE_QUALIFIER + 'Account_Payable__r.' + PACKAGE_QUALIFIER + 'Status__c', 
                PACKAGE_QUALIFIER + 'AP_Disbursement__r.' + PACKAGE_QUALIFIER + 'Status__c', 
                PACKAGE_QUALIFIER + 'Billing_Cash_Receipt__r.' + PACKAGE_QUALIFIER + 'Status__c', 
                PACKAGE_QUALIFIER + 'Cash_Disbursement__r.' + PACKAGE_QUALIFIER + 'Status__c', 
                PACKAGE_QUALIFIER + 'Cash_Receipt__r.' + PACKAGE_QUALIFIER + 'Status__c', 
                PACKAGE_QUALIFIER + 'Journal_Entry__r.' + PACKAGE_QUALIFIER + 'Status__c', 
                PACKAGE_QUALIFIER + 'Time_Card__r.' + PACKAGE_QUALIFIER + 'Status__c'
            }) {
                conditions.add(statusField + ' =: statuses');
            }
            String dynamicSOQL = SOQLBuilder.buildDynamicSoqlQuery(
                    fieldsToQuery,
                    null,
                    Transaction_Group__c.SObjectType,
                    String.join(conditions, ' OR '),
                    800,
                    false,
                    false
            );
            return (List<Transaction_Group__c>) Database.query(dynamicSOQL);
        }

        private List<Transaction_Group__c> queryTransactionGroup(Set<Id> sourceIds) {
            List<String> fieldsToQuery = new List<String> {
                'Id',
                'Amortization_Entry__c',
                'AP_Disbursement__c',
                'Batch_Id__c',
                'Billing__c',
                'Billing_Cash_Receipt__c',
                'Cash_Disbursement__c',
                'Cash_Receipt__c',
                'Journal_Entry__c',
                'Ledger__c',
                'Line_Count__c',
                'Lines_Processed__c',
                'Account_Payable__c',
                'Time_Card__c'
            };

            Schema.SObjectType selectedSObjectType;
            if (currentSObjectType == Billing_Cash_Receipt__c.getSObjectType() || currentSObjectType == AP_Disbursement__c.getSObjectType()) {
                selectedSObjectType = currentSObjectType == Billing_Cash_Receipt__c.getSObjectType() ?
                    Billing__c.getSObjectType() : Account_Payable__c.getSObjectType();
            } else {
                selectedSObjectType = currentSObjectType;
            }

            String queryCondition = selectedSObjectType + ' IN :sourceIds';
            String dynamicSOQL = SOQLBuilder.buildDynamicSoqlQuery(
                fieldsToQuery,
                null,
                Transaction_Group__c.SObjectType,
                queryCondition,
                false,
                false
            );
            return (List<Transaction_Group__c>) Database.query(dynamicSOQL);
        }
    }
    public class RecordProcessingStatistics{
        public Integer processedRecords;
        public Integer succeededRecords;
        public Integer failedRecords;

        public RecordProcessingStatistics(){
            this.processedRecords = 0;
            this.succeededRecords = 0;
            this.failedRecords = 0;
        }
        public RecordProcessingStatistics(RecordProcessingStatistics result){
            this.processedRecords = result.processedRecords;
            this.succeededRecords = result.succeededRecords;
            this.failedRecords = result.failedRecords;
        }
    }
}