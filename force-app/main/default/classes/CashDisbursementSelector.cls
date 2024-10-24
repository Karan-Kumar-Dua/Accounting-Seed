public with sharing class CashDisbursementSelector extends SelectorAbstract {

    public CashDisbursementSelector(){
        super(Cash_Disbursement__c.getSObjectType());
        this.postingStatusField = 'Status__c';
    }

    public override List<Schema.SObjectField> getFields(){
        return new List<Schema.SObjectField>{
                Cash_Disbursement__c.Id,
                Cash_Disbursement__c.Name,
                Cash_Disbursement__c.Status__c,
                Cash_Disbursement__c.Project__c,
                Cash_Disbursement__c.Project_Task__c,
                Cash_Disbursement__c.Product__c,
                Cash_Disbursement__c.Accounting_Period__c,
                Cash_Disbursement__c.Bank_Reconciliation__c,
                Cash_Disbursement__c.Check_Number__c,
                Cash_Disbursement__c.Amount__c,
                Cash_Disbursement__c.Bank_Account__c,
                Cash_Disbursement__c.Cash_Flow_Category__c,
                Cash_Disbursement__c.Ledger__c,
                Cash_Disbursement__c.GL_Account_Variable_1__c,
                Cash_Disbursement__c.GL_Account_Variable_2__c,
                Cash_Disbursement__c.GL_Account_Variable_3__c,
                Cash_Disbursement__c.GL_Account_Variable_4__c
        };
    }

    public override List<String> getAdditionalFieldPaths() {
        return new List<String>{
                'Accounting_Period__r.Name',
                'Accounting_Period__r.Status__c',
                'Bank_Reconciliation__r.Name',
                'Ledger__r.Name',
                'Ledger__r.Type__c'
        };
    }

}