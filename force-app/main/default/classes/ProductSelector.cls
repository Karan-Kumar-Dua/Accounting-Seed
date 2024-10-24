public with sharing class ProductSelector extends SObjectSelector {
    
    public ProductSelector() {
        super();
    }

    public ProductSelector(System.AccessLevel accessLevel, SharingMode sharingType) {
        super(accessLevel, sharingType);
    }

    public override Schema.SObjectType getSObjectType() {
        return Product2.SObjectType;
    }

    public override List<Schema.SObjectField> getSObjectFields() {
        return new List<Schema.SObjectField> {
            Product2.Id,
            Product2.Name,
            Product2.Accounting_Type__c,
            Product2.Expense_GL_Account__c,
            Product2.GL_Account_Variable_1__c,
            Product2.GL_Account_Variable_2__c,
            Product2.GL_Account_Variable_3__c,
            Product2.GL_Account_Variable_4__c,
            Product2.Inventory_GL_Account__c,
            Product2.Inventory_Product__c,
            Product2.Inventory_Type__c,
            Product2.Revenue_GL_Account__c,
            Product2.Tax_Code__c,
            Product2.Tax_Group__c,
            Product2.Tax_Rate__c,
            Product2.Unit_Cost__c
        };
    }

}