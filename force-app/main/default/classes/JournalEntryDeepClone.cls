public with sharing class JournalEntryDeepClone {

    private Journal_Entry__c cloneJournalEntry;
    @TestVisible
    private Journal_Entry__c journalEntry;
    @TestVisible
    private List<Journal_Entry_Line__c> jeList;
    private List<String> jeFields;
    private List<String> jelFields;
    private Boolean isReverseClone;

    public Journal_Entry__c tempJournalEntry {get; set;}
    public Id theNewJournalEntryId {get; set;}
    public Boolean isError {get; set;}
    public Boolean isMultiCurrencyEnabled {get ;set;}

    public static final String NO_OPEN_PERIOD_ERROR_MESSAGE =
            Label.ERR_NO_OPEN_ACCOUNTING_PERIOD;

    public JournalEntryDeepClone(ApexPages.StandardController controller) {
        isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
        if (isMultiCurrencyEnabled && !Test.isRunningTest()) {
            controller.addFields(new List<String>{'CurrencyIsoCode'});
        }
        journalEntry = (Journal_Entry__c)controller.getRecord();
        theNewJournalEntryId = journalEntry.Id;
        isError = false;
        jeList = new List<Journal_Entry_Line__c>();
        isReverseClone = false;
        tempJournalEntry = new Journal_Entry__c();
        tempJournalEntry.Journal_Date__c = System.today();
        if (isMultiCurrencyEnabled) {
            tempJournalEntry.put('CurrencyIsoCode', controller.getRecord().get('CurrencyIsoCode'));
        }
        Map<String, Schema.SObjectField> journalEntrySchemaMap = Schema.SObjectType.Journal_Entry__c.fields.getMap();
        Map<String, Schema.SObjectField> jeLineSchemaMap = Schema.SObjectType.Journal_Entry_Line__c.fields.getMap();

        // Get the creatable fields,
        // Get the isupdatable fields,
        // and the field should not be unique.
        jeFields = new List<String>();
        for (String fieldName : journalEntrySchemaMap.keySet()) {
            Schema.DescribeFieldResult field = journalEntrySchemaMap.get(fieldName).getDescribe();
            if (field.isUpdateable() == true && field.isCreateable() == true && field.isUnique() == false) {                            
                jeFields.add(field.getName());
            }
        }

        jelFields = new List<String>();
        for (String fieldName : jeLineSchemaMap.keyset()) {
            Schema.DescribeFieldResult field = jeLineSchemaMap.get(fieldName).getDescribe();
            if (field.isUpdateable() == true && field.isCreateable() == true && field.isUnique() == false) {            
                jelFields.add(field.getName());
            }
        }
    }
    
    public PageReference reverseCloneJournalEntry() {
        isReverseClone = true;
        return cloneJournalEntry();
    }
    
    public PageReference cloneJournalEntry() {
        isError = false;
        //Query for most recent accounting period
        Accounting_Period__c acctPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDateAndStatus(
            tempJournalEntry.Journal_Date__c,
            new Set<String>{AccountingPeriodActions.OPEN_STATUS},
            Journal_Entry__c.SObjectType
        );
        
        if (acctPeriod == null) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                String.format(NO_OPEN_PERIOD_ERROR_MESSAGE, new List<String>{(tempJournalEntry.Journal_Date__c).format()})
            ));
            isError = true;
            return null;
        }

        //Continue in async context if LDV is enabled
        if (FeatureManagementHandler.isLargeDataVolumeModeEnabled()) {
            Set<Id> sourceIds = new Set<Id>{journalEntry.Id};
            JournalEntryLDVCloneBatch batchInstance = new JournalEntryLDVCloneBatch(
                sourceIds,
                acctPeriod.Id,
                tempJournalEntry.Journal_Date__c,
                isMultiCurrencyEnabled ? (String) tempJournalEntry.get('CurrencyIsoCode') : null,
                isReverseClone
            );

            Database.executeBatch(batchInstance);

            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, Label.INF_LDV_CLONE_W_LINES));
            return null;
        }
        else {
            // setup the save point for rollback
            Savepoint sp = Database.setSavepoint();

            try {
                //Dynamic query for Journal Entry
                journalEntry = queryJournalEntry();
                cloneJournalEntry = journalEntry.clone(false);

                // add '-Reversal' suffix to journal name
                cloneJournalEntry.Name = journalEntry.Name + (isReverseClone ? '-Reversal' : '');
                cloneJournalEntry.Journal_Date__c = tempJournalEntry.Journal_Date__c;
                cloneJournalEntry.Accounting_Period__c = acctPeriod.Id;
                cloneJournalEntry.Currency_Conversion_Rate__c = NULL;
                cloneJournalEntry.Auto_Reverse__c = false;
                cloneJournalEntry.Auto_Reversal_JE__c = null;
                cloneJournalEntry.Reverse_Accounting_Period__c = null;
                if (isMultiCurrencyEnabled) {
                    cloneJournalEntry.put('CurrencyIsoCode', tempJournalEntry.get('CurrencyIsoCode'));
                }

                SFDCSecurityUtils.insertCheckCRUDAndFLS(cloneJournalEntry, new List<String>{
                    'Journal_Date__c',
                    'Accounting_Period__c'
                });

                for (Journal_Entry_Line__c je : (List<Journal_Entry_Line__c>) queryJournalEntryLines()) {
                    Journal_Entry_Line__c cloneJE = je.clone(false);
                    cloneJE.Credit__c = isReverseClone ? je.Debit__c : je.Credit__c;
                    cloneJE.Debit__c = isReverseClone ? je.Credit__c : je.Debit__c;
                    cloneJE.Journal_Entry__c = cloneJournalEntry.Id;
                    cloneJE.Date__c = tempJournalEntry.Journal_Date__c;
                    jeList.add(cloneJE);
                }

                SFDCSecurityUtils.insertCheckCRUDAndFLS(jeList, new List<String>{
                    'Credit__c',
                    'Debit__c',
                    'Date__c'
                });

                theNewJournalEntryId = cloneJournalEntry.Id;
            }
            catch (Exception e) {
                Database.rollback(sp);
                isError = true;
                ApexPages.addMessages(e);
                return NULL;
            }

            return new PageReference(FinancialSuiteUtils.getRedirectToSObjectURL(theNewJournalEntryId, Journal_Entry__c.SObjectType, true));
        }
    }

    private Journal_Entry__c queryJournalEntry() {
        //=== Build SOQL query with CRUD checks ===
        String jeId = journalEntry.Id;
        //Add query condition
        String queryCondition = 'Id = :jeId LIMIT 1';

        SOQLBuilder theQuery = new SOQLBuilder(Journal_Entry__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(jeFields)
            .setCondition(queryCondition);

        return (Journal_Entry__c) Database.query(theQuery.toSOQL());
    }

    private List<Journal_Entry_Line__c> queryJournalEntryLines() {
        //=== Build SOQL query with CRUD checks ===
        //Add query condition
        String jeId = journalEntry.Id;
        String queryCondition = 'Journal_Entry__c = :jeId ORDER BY Name ASC';

        SOQLBuilder theQuery = new SOQLBuilder(Journal_Entry_Line__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(jelFields)
            .setCondition(queryCondition);

        return (List<Journal_Entry_Line__c>) Database.query(theQuery.toSOQL());
    }

}