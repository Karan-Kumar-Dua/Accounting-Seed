public with sharing class DeleteTransactionsBatch implements Database.Batchable<sObject>, Database.Stateful {

    private Id batchId;
    private Schema.SObjectType headerSObjectType;
    private Schema.SObjectType lineSObjectType;
    private SourceDocumentBatchHelper helper = new SourceDocumentBatchHelper();

    public DeleteTransactionsBatch(Id batchId, Schema.SObjectType headerSObjectType) {
        this.batchId = batchId;
        this.headerSObjectType = headerSObjectType;
        this.lineSObjectType = helper.mParentToChild.get(this.headerSObjectType);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        SelectorAbstract lineSelector = (SelectorAbstract)this.helper.mSelectors.get(this.lineSObjectType).newInstance();
        String soql = lineSelector.getDeleteQuery();
        return DomainUtils.getQueryLocator(soql, new Set<Id> {batchId});
    }

    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        TransactionActions.deleteTransactions(
            TransactionActions.queryTransactions(scope, AccountingSettingsHandler.isHeaderLevelPost(), 1000)
        );

        Set<Id> sourceForDelete = new Set<Id>();
        for (Sobject obj : scope) {
            sourceForDelete.add((Id) obj.get(SourceDocumentBatchHelper.mChildRelationship.get(lineSObjectType)));
        }
        SFDCSecurityUtils.deleteProxy(queryTransactionGroup(batchId, sourceForDelete));
        helper.setPostingStatus(
            new List<Id> (sourceForDelete),
            AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
            headerSObjectType
        );
    }

    public void finish(Database.BatchableContext bc) {
    }

    private List<Transaction_Group__c> queryTransactionGroup(Id batchId, Set<Id> sourceIds) {
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
        String queryCondition = headerSObjectType + ' IN :sourceIds AND Batch_Id__c = :batchId';
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