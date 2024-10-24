public with sharing class RecurringAccountPayableLineSelector extends SObjectSelector implements RecurringLineSelector {
    
    public RecurringAccountPayableLineSelector() {
        super();
    }

    public RecurringAccountPayableLineSelector(System.AccessLevel accessLevel, SharingMode sharingType) {
        super(accessLevel, sharingType);
    }

    public override Schema.SObjectType getSObjectType() {
        return Recurring_Account_Payable_Line__c.SObjectType;
    }

    public override List<Schema.SObjectField> getSObjectFields() {
        List<Schema.SObjectField> fields = new List<Schema.SObjectField> {
            Recurring_Account_Payable_Line__c.Id,
            Recurring_Account_Payable_Line__c.Name,
            Recurring_Account_Payable_Line__c.Combined_Tax_Rate__c,
            Recurring_Account_Payable_Line__c.Expense_GL_Account__c,
            Recurring_Account_Payable_Line__c.Date__c,
            Recurring_Account_Payable_Line__c.Internal_Comment__c,
            Recurring_Account_Payable_Line__c.Ledger__c,
            Recurring_Account_Payable_Line__c.GL_Account_Variable_1__c,
            Recurring_Account_Payable_Line__c.GL_Account_Variable_2__c,
            Recurring_Account_Payable_Line__c.GL_Account_Variable_3__c,
            Recurring_Account_Payable_Line__c.GL_Account_Variable_4__c,
            Recurring_Account_Payable_Line__c.Recurring_Account_Payable__c,
            Recurring_Account_Payable_Line__c.Line_Order__c,
            Recurring_Account_Payable_Line__c.Unit_Cost__c,
            Recurring_Account_Payable_Line__c.Product__c,
            Recurring_Account_Payable_Line__c.Project__c,
            Recurring_Account_Payable_Line__c.Project_Task__c,
            Recurring_Account_Payable_Line__c.Quantity__c,
            Recurring_Account_Payable_Line__c.Sub_Total__c,
            Recurring_Account_Payable_Line__c.Tax_Amount__c,
            Recurring_Account_Payable_Line__c.Tax_Group__c,
            Recurring_Account_Payable_Line__c.Tax_Inclusive__c,
            Recurring_Account_Payable_Line__c.Tax_Rate__c,
            Recurring_Account_Payable_Line__c.Amount2__c
        };

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            Schema.SObjectField currencyIsoCode = SchemaDescribe.getDescribe(Recurring_Account_Payable__c.SObjectType).getField('CurrencyIsoCode');
            fields.add(currencyIsoCode);
        }

        return fields;
    }
    
    public List<SObject> selectLinesByHeaderId(Set<Id> headerIds) {
        SOQLBuilder builder = getSOQLBuilder();
        builder.setCondition('Recurring_Account_Payable__c IN :headerIds');
        Map<String,Object> bindMap = new Map<String,Object>{'headerIds' => headerIds};
        return database().queryWithBinds(builder.toSOQL(), bindMap);
    }

    public Database.QueryLocator queryLocatorByHeaderId(Set<Id> headerIds) {
        SOQLBuilder builder = getSOQLBuilder();
        builder.setCondition('Recurring_Account_Payable__c IN :headerIds');
        Map<String,Object> bindMap = new Map<String,Object>{'headerIds' => headerIds};
        return database().getQueryLocatorWithBinds(builder.toSOQL(), bindMap);
    }

    public Database.QueryLocator queryLocatorByReadyToProcess() {
        SOQLBuilder builder = getSOQLBuilder();
        String condition = 'Recurring_Account_Payable__r.Exclude_From_Automation__c = false ' + 
            'AND Recurring_Account_Payable__r.Status__c = :active ' +
            'AND Recurring_Account_Payable__r.Next_Account_Payable_Date__c <= :today';
        builder.setCondition(condition);

        Map<String,Object> bindMap = new Map<String,Object>{
            'active' => RecurringAccountPayableAction.RECURRING_STATUS_ACTIVE, 
            'today' => Date.today()
        };
        return database().getQueryLocatorWithBinds(builder.toSOQL(), bindMap);
    }

}