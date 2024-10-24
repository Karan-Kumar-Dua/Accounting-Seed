/*
**   Created By    : AccountingSeed
**  Created For    : Deepclone for ReverseJournalEntry. 
** Created Date    : July 19, 2011
*/

public with sharing class JournalEntryReverseDeepClone {

    private ApexPages.StandardController controller {get; set;}
    private Journal_Entry__c dcJournalEntries {get; set;}

    private Journal_Entry__c lstDeepJELines = new Journal_Entry__c();
    private Journal_Entry__c deepJEvalues = new Journal_Entry__c();
    @TestVisible
    private List<Journal_Entry_Line__c> lstJELines = new List<Journal_Entry_Line__c>();
    @TestVisible
    private List<Journal_Entry_Line__c> lstInsertJELines = new List<Journal_Entry_Line__c>();
    private List<String> setJEFlds;
    private List<String> setJELineFlds;
    public static final String NO_OPEN_PERIOD_ERROR_MESSAGE = Label.ERR_NO_ACCOUNTING_PERIOD_EXIST + System.now().format('MM/dd/yyyy') + Label.ERR_CLONE_RECORD;

    public JournalEntryReverseDeepClone(ApexPages.StandardController controller) {
        dcJournalEntries = (Journal_Entry__c) controller.getRecord();

        Map<String, Schema.SObjectField> mapGetAllJEFields = Schema.SObjectType.Journal_Entry__c.fields.getMap();
        Map<String, Schema.SObjectField> mapGetAllJELineFields = Schema.SObjectType.Journal_Entry_Line__c.fields.getMap();

        // Get the creatable fields,
        // Get the isupdatable fields,
        // and the field should not be unique.
        setJEFlds = new List<String>();
        for (String objname : mapGetAllJEFields.keyset()) {
            Schema.DescribeFieldResult allField = mapGetAllJEFields.get(objname).getDescribe();
            if (allField.isUpdateable() == true && allField.isCreateable() == true && allField.isUnique() == false) {
                setJEflds.add(allField.getName());
            }
        }

        setJELineFlds = new List<String>();
        for (String objname : mapGetAllJELineFields.keyset()) {
            Schema.DescribeFieldResult allField = mapGetAllJELineFields.get(objname).getDescribe();
            if (allField.isUpdateable() == true && allField.isCreateable() == true && allField.isUnique() == false) {
                setJELineFlds.add(allField.getName());
            }
        }
    }

    public PageReference jeCloneWithLines() {

        // Query for most recent accounting period
        Accounting_Period__c acctPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDateAndStatus(System.today(), new Set<String>{AccountingPeriodActions.OPEN_STATUS}, Journal_Entry__c.SObjectType);

        if (acctPeriod == NULL) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, NO_OPEN_PERIOD_ERROR_MESSAGE));
            return NULL;
        }

        // setup the save point for rollback
        Savepoint sp = Database.setSavepoint();

        try {
            //Dynamic query for Journal Entry
            deepJEValues = queryJournalEntry();
            lstDeepJELines = deepJEValues.clone(false);

            Schema.DescribeFieldResult getListInfromation = Journal_Entry__c.Status__c.getDescribe();
            List<Schema.PicklistEntry> getDefaultInfromation = getListInfromation.getPicklistValues();

            for (Schema.PicklistEntry iRows : getDefaultInfromation) {
                if (irows.isDefaultValue() == true) {
                    lstDeepJELines.Status__c = iRows.getValue();
                }
            }

            // add '-Reversal' suffix to journal name
            lstDeepJELines.Name = deepJEValues.Name + '-Reversal';
            lstDeepJELines.Journal_Date__c = System.today();
            lstDeepJELines.Status__c = 'In Process';
            lstDeepJELines.Accounting_Period__c = acctPeriod.Id;

            SFDCSecurityUtils.insertCheckCRUDAndFLS(lstDeepJELines, new List<String>{
                'Journal_Date__c',
                'Status__c',
                'Accounting_Period__c'
            });

            //Clone journal entryline records
            lstJELines = queryJournalEntryLines();

            for (Journal_Entry_Line__c iJEL: lstJELines) {
                Journal_Entry_Line__c jeLines = iJEL.clone(false);
                jeLines.Credit__c = iJEL.Debit__c;
                jeLines.Debit__c = iJEL.Credit__c;
                jeLines.Journal_Entry__c = lstDeepJELines.Id;
                lstInsertJELines.add(jeLines);
            }

            SFDCSecurityUtils.insertCheckCRUDAndFLS(lstInsertJELines, new List<String>{
                'Credit__c',
                'Debit__c'
            });
        }
        catch(Exception e) {
            Database.rollback(sp);
            ApexPages.addMessages(e);
            return NULL;
        }

        return new PageReference('/' + lstDeepJELines.Id + '/e?retURL=%2F' + lstDeepJELines.Id);
    }

    private Journal_Entry__c queryJournalEntry() {
        //=== Build SOQL query with CRUD checks ===
        String jeId = dcJournalEntries.Id;
        //Add query condition
        String queryCondition = 'Id = :jeId LIMIT 1';

        SOQLBuilder theQuery = new SOQLBuilder(Journal_Entry__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(setJEFlds)
            .setCondition(queryCondition);

        return (Journal_Entry__c) Database.query(theQuery.toSOQL());
    }

    private List<Journal_Entry_Line__c> queryJournalEntryLines() {
        //=== Build SOQL query with CRUD checks ===
        //Add query condition
        String jeId = dcJournalEntries.Id;
        String queryCondition = 'Journal_Entry__c = :jeId';

        SOQLBuilder theQuery = new SOQLBuilder(Journal_Entry_Line__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(setJELineFlds)
            .setCondition(queryCondition);

        return (List<Journal_Entry_Line__c>) Database.query(theQuery.toSOQL());
    }

}