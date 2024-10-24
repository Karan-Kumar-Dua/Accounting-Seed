public with sharing class CashReceiptSelector extends SelectorAbstract {

    public CashReceiptSelector(){
        super(Cash_Receipt__c.getSObjectType());
        this.postingStatusField = 'Status__c';
    }

    public override List<Schema.SObjectField> getFields(){
        return new List<Schema.SObjectField>{
            Cash_Receipt__c.Id,
            Cash_Receipt__c.Name,
            Cash_Receipt__c.Status__c,
            Cash_Receipt__c.Project__c,
            Cash_Receipt__c.Project_Task__c,
            Cash_Receipt__c.Product__c,
            Cash_Receipt__c.Accounting_Period__c,
            Cash_Receipt__c.Number_of_Billing_Cash_Receipts__c,
            Cash_Receipt__c.Bank_Reconciliation__c,
            Cash_Receipt__c.Bank_Deposit__c,
            Cash_Receipt__c.Check_Number__c,
            Cash_Receipt__c.Amount__c,
            Cash_Receipt__c.Receipt_Date__c,
            Cash_Receipt__c.Bank_Account__c,
            Cash_Receipt__c.Account__c,
            Cash_Receipt__c.Cash_Flow_Category__c,
            Cash_Receipt__c.Payment_Reference__c,
            Cash_Receipt__c.Credit_GL_Account__c,
            Cash_Receipt__c.Ledger__c,
            Cash_Receipt__c.GL_Account_Variable_1__c,
            Cash_Receipt__c.GL_Account_Variable_2__c,
            Cash_Receipt__c.GL_Account_Variable_3__c,
            Cash_Receipt__c.GL_Account_Variable_4__c
        };
    }

    public override List<String> getAdditionalFieldPaths() {
        return new List<String>{
            'Accounting_Period__r.Name',
            'Accounting_Period__r.Status__c',
            'Bank_Reconciliation__r.Name',
            'Bank_Deposit__r.Name',
            'Ledger__r.Name',
            'Ledger__r.Type__c'
        };
    }

}