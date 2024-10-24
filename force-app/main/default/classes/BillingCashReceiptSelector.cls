public with sharing class BillingCashReceiptSelector extends SelectorAbstract {

    public BillingCashReceiptSelector(){
        super(Billing_Cash_Receipt__c.getSObjectType());
        this.postingStatusField = 'Status__c';
    }

    public override List<Schema.SObjectField> getFields(){
        return new List<Schema.SObjectField>{
                Billing_Cash_Receipt__c.Id,
                Billing_Cash_Receipt__c.Name,
                Billing_Cash_Receipt__c.Accounting_Period__c,
                Billing_Cash_Receipt__c.Adjustment_Amount__c,
                Billing_Cash_Receipt__c.Adjustment_GL_Account__c,
                Billing_Cash_Receipt__c.Applied_Amount__c,
                Billing_Cash_Receipt__c.Applied_Date__c,
                Billing_Cash_Receipt__c.Billing__c,
                Billing_Cash_Receipt__c.Cash_Receipt__c,
                Billing_Cash_Receipt__c.Ledger__c,
                Billing_Cash_Receipt__c.Period_Applied__c,
                Billing_Cash_Receipt__c.Status__c
        };
    }

    public override List<String> getAdditionalFieldPaths() {
        return new List<String>{
                'Accounting_Period__r.Name',
                'Accounting_Period__r.Status__c',
                'Billing__r.Ledger__r.Name',
                'Billing__r.Ledger__r.Type__c'
        };
    }

}