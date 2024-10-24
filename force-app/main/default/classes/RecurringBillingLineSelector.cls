public with sharing class RecurringBillingLineSelector extends SObjectSelector implements RecurringLineSelector {

    public RecurringBillingLineSelector() {
        super();
    }

    public RecurringBillingLineSelector(System.AccessLevel accessLevel, SharingMode sharingType) {
        super(accessLevel, sharingType);
    }
    
    public override Schema.SObjectType getSObjectType() {
        return Recurring_Billing_Line__c.SObjectType;
    }

    public override List<Schema.SObjectField> getSObjectFields() {
        List<Schema.SObjectField> fields = new List<Schema.SObjectField> {
            Recurring_Billing_Line__c.Id,
            Recurring_Billing_Line__c.Name,
            Recurring_Billing_Line__c.Combined_Tax_Rate__c,
            Recurring_Billing_Line__c.Comment__c,
            Recurring_Billing_Line__c.Date__c,
            Recurring_Billing_Line__c.Discount_Amount__c,
            Recurring_Billing_Line__c.Discount_Percent__c,
            Recurring_Billing_Line__c.GL_Account_Variable_1__c,
            Recurring_Billing_Line__c.GL_Account_Variable_2__c,
            Recurring_Billing_Line__c.GL_Account_Variable_3__c,
            Recurring_Billing_Line__c.GL_Account_Variable_4__c,
            Recurring_Billing_Line__c.Ledger__c,
            Recurring_Billing_Line__c.Line_Order__c,
            Recurring_Billing_Line__c.List_Price__c,
            Recurring_Billing_Line__c.Opportunity_Product_Id__c,
            Recurring_Billing_Line__c.Product__c,
            Recurring_Billing_Line__c.Project__c,
            Recurring_Billing_Line__c.Project_Task__c,
            Recurring_Billing_Line__c.Quantity__c,
            Recurring_Billing_Line__c.Rate__c,
            Recurring_Billing_Line__c.Recurring_Billing__c,
            Recurring_Billing_Line__c.Revenue_GL_Account__c,
            Recurring_Billing_Line__c.Sub_Total__c,
            Recurring_Billing_Line__c.Tax_Amount__c,
            Recurring_Billing_Line__c.Tax_Group__c,
            Recurring_Billing_Line__c.Tax_Inclusive__c,
            Recurring_Billing_Line__c.Tax_Rate__c,
            Recurring_Billing_Line__c.Total__c
        };

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            Schema.SObjectField currencyIsoCode = SchemaDescribe.getDescribe(Recurring_Billing_Line__c.SObjectType).getField('CurrencyIsoCode');
            fields.add(currencyIsoCode);
        }

        return fields;
    }

    public List<SObject> selectLinesByHeaderId(Set<Id> headerIds) {
        SOQLBuilder builder = getSOQLBuilder();
        builder.selectFields(join(Recurring_Billing_Line__c.Product__c, new ProductSelector()));
        builder.setCondition('Recurring_Billing__c IN :headerIds');
        Map<String,Object> bindMap = new Map<String,Object>{'headerIds' => headerIds};
        return database().queryWithBinds(builder.toSOQL(), bindMap);
    }

    public Database.QueryLocator queryLocatorByHeaderId(Set<Id> headerIds) {
        SOQLBuilder builder = getSOQLBuilder();
        builder.selectFields(join(Recurring_Billing_Line__c.Product__c, new ProductSelector()));
        builder.setCondition('Recurring_Billing__c IN :headerIds');
        Map<String,Object> bindMap = new Map<String,Object>{'headerIds' => headerIds};
        return database().getQueryLocatorWithBinds(builder.toSOQL(), bindMap);
    }

    public Database.QueryLocator queryLocatorByReadyToProcess() {
        SOQLBuilder builder = getSOQLBuilder();
        builder.selectFields(join(Recurring_Billing_Line__c.Product__c, new ProductSelector()));
        String condition = 'Recurring_Billing__r.Exclude_From_Automation__c = false ' + 
            'AND Recurring_Billing__r.Status__c = :active ' +
            'AND Recurring_Billing__r.Next_Billing_Date__c <= :today';
        builder.setCondition(condition);

        Map<String,Object> bindMap = new Map<String,Object>{
            'active' => RecurringBillingActions.RECURRING_STATUS_ACTIVE, 
            'today' => Date.today()
        };
        return database().getQueryLocatorWithBinds(builder.toSOQL(), bindMap);
    }

}