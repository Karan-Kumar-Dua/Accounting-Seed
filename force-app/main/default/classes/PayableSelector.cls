public with sharing class PayableSelector extends SelectorAbstract {

    public PayableSelector() {
        super(Account_Payable__c.getSObjectType());
    }

    public override List<Schema.SObjectField> getFields() {
        return new List<Schema.SObjectField>{
                Account_Payable__c.Vendor__c
                // ...
        };
    }
}