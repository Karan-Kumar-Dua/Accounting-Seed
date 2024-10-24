public with sharing class TransactionGroupSelector extends SObjectSelector {

    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    public TransactionGroupSelector() {
        super();
    }

    public TransactionGroupSelector(System.AccessLevel accessLevel, SharingMode sharingType) {
        super(accessLevel, sharingType);
    }

    public override Schema.SObjectType getSObjectType() {
        return Transaction_Group__c.SObjectType;
    }

    public override List<Schema.SObjectField> getSObjectFields() {
        return new List<Schema.SObjectField> {
            Transaction_Group__c.Id,
            Transaction_Group__c.Account_Payable__c,
            Transaction_Group__c.Amortization_Entry__c,
            Transaction_Group__c.AP_Disbursement__c,
            Transaction_Group__c.Batch_Id__c,
            Transaction_Group__c.Billing__c,
            Transaction_Group__c.Billing_Cash_Receipt__c,
            Transaction_Group__c.Cash_Disbursement__c,
            Transaction_Group__c.Cash_Receipt__c,
            Transaction_Group__c.Job_Type__c,
            Transaction_Group__c.Journal_Entry__c,
            Transaction_Group__c.Ledger__c,
            Transaction_Group__c.Line_Count__c,
            Transaction_Group__c.Lines_Processed__c,
            Transaction_Group__c.Recurring_Account_Payable__c,
            Transaction_Group__c.Recurring_Billing__c,
            Transaction_Group__c.Recurring_Journal_Entry__c,
            Transaction_Group__c.Status__c,
            Transaction_Group__c.Time_Card__c
        };
    }

    public Database.QueryLocator queryLocatorForFailedSrcDocsByBatchId(String batchId, Schema.SObjectType headerType, Schema.SObjectType lineType) {
        String headerName = headerType.getDescribe().getName();
        String lineName = lineType.getDescribe().getName();
        String query =
            'SELECT Id ' +
            'FROM ' + lineName + ' ' +
            'WHERE '+ headerName + ' IN '+
            '(SELECT ' + headerName + ' FROM ' + getSObjectName() + ' ' +
            'WHERE ' + PACKAGE_QUALIFIER + 'Batch_Id__c = :batchId AND ' + PACKAGE_QUALIFIER +  'Status__c = :status) ';

        Map<String, Object> bindMap = new Map<String, Object> {
            'batchId' => batchId,
            'status' => TransactionGroupActions.STATUS_FAILED
        };

        return database().getQueryLocatorWithBinds(query, bindMap);
    }

    public Database.QueryLocator queryLocatorByBatchId(String batchId) {
        SOQLBuilder builder = getSOQLBuilder();
        builder.setCondition('Batch_Id__c = :batchId');
        Map<String, Object> bindMap = new Map<String, Object>{'batchId' => batchId};
        return database().getQueryLocatorWithBinds(builder.toSOQL(), bindMap);
    }

}