public with sharing class APDisbursementSelector extends SelectorAbstract {

    public APDisbursementSelector(){
        super(AP_Disbursement__c.getSObjectType());
        this.postingStatusField = 'Status__c';
    }

    public override List<Schema.SObjectField> getFields(){
        return new List<Schema.SObjectField>{
                AP_Disbursement__c.Id,
                AP_Disbursement__c.Name,
                AP_Disbursement__c.Account_Payable__c,
                AP_Disbursement__c.Account_Payable_Date__c,
                AP_Disbursement__c.Accounting_Period__c,
                AP_Disbursement__c.Applied_Date__c,
                AP_Disbursement__c.Cash_Disbursement__c,
                AP_Disbursement__c.Disbursement_Period__c,
                AP_Disbursement__c.Discount_Amount__c,
                AP_Disbursement__c.Net_Amount__c,
                AP_Disbursement__c.Paid_Amount__c,
                AP_Disbursement__c.Payable_Account__c,
                AP_Disbursement__c.Payable_Amount__c,
                AP_Disbursement__c.Payee_Reference__c,
                AP_Disbursement__c.Status__c
        };
    }

    public override List<String> getAdditionalFieldPaths() {
        return new List<String>{
                'Accounting_Period__r.Name',
                'Accounting_Period__r.Status__c',
                'Account_Payable__r.Ledger__r.Name',
                'Account_Payable__r.Ledger__r.Type__c'
        };
    }

}