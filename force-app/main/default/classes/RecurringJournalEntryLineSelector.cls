public with sharing class RecurringJournalEntryLineSelector extends SObjectSelector implements RecurringLineSelector{
    public RecurringJournalEntryLineSelector() {
        super();
    }

    public RecurringJournalEntryLineSelector(System.AccessLevel accessLevel, SharingMode sharingType) {
        super(accessLevel, sharingType);
    }

    public override Schema.SObjectType getSObjectType() {
        return Recurring_Journal_Entry_Line__c.SObjectType;
    }

    public override List<Schema.SObjectField> getSObjectFields() {
        List<Schema.SObjectField> fields = new List<Schema.SObjectField> {
            Recurring_Journal_Entry_Line__c.Id,
            Recurring_Journal_Entry_Line__c.Name,
            Recurring_Journal_Entry_Line__c.Account__c,
            Recurring_Journal_Entry_Line__c.Cash_Flow_Category__c,
            Recurring_Journal_Entry_Line__c.Contact__c,
            Recurring_Journal_Entry_Line__c.Credit__c,
            Recurring_Journal_Entry_Line__c.Debit__c,
            Recurring_Journal_Entry_Line__c.GL_Account_Variable_1__c,
            Recurring_Journal_Entry_Line__c.GL_Account_Variable_2__c,
            Recurring_Journal_Entry_Line__c.GL_Account_Variable_3__c,
            Recurring_Journal_Entry_Line__c.GL_Account_Variable_4__c,
            Recurring_Journal_Entry_Line__c.Description__c,
            Recurring_Journal_Entry_Line__c.Employee__c,
            Recurring_Journal_Entry_Line__c.GL_Account__c,
            Recurring_Journal_Entry_Line__c.Ledger__c,
            Recurring_Journal_Entry_Line__c.Product__c,
            Recurring_Journal_Entry_Line__c.Project__c,
            Recurring_Journal_Entry_Line__c.Project_Task__c,
            Recurring_Journal_Entry_Line__c.Quantity__c,
            Recurring_Journal_Entry_Line__c.Recurring_Journal_Entry__c,
            Recurring_Journal_Entry_Line__c.Line_Order__c,
            Recurring_Journal_Entry_Line__c.Reference__c
        };

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            Schema.SObjectField currencyIsoCode = SchemaDescribe.getDescribe(Recurring_Journal_Entry_Line__c.SObjectType).getField('CurrencyIsoCode');
            fields.add(currencyIsoCode);
        }

        return fields;
    }
    public List<SObject> selectLinesByHeaderId(Set<Id> headerIds) {
        SOQLBuilder builder = getSOQLBuilder();
        builder.setCondition('Recurring_Journal_Entry__c IN :headerIds');
        Map<String,Object> bindMap = new Map<String,Object>{'headerIds' => headerIds};
        return database().queryWithBinds(builder.toSOQL(), bindMap);
    }

    public Database.QueryLocator queryLocatorByHeaderId(Set<Id> headerIds) {
        SOQLBuilder builder = getSOQLBuilder();
        builder.setCondition('Recurring_Journal_Entry__c IN :headerIds');
        Map<String,Object> bindMap = new Map<String,Object>{'headerIds' => headerIds};
        return database().getQueryLocatorWithBinds(builder.toSOQL(), bindMap);
    }

    public Database.QueryLocator queryLocatorByReadyToProcess() {
        SOQLBuilder builder = getSOQLBuilder();
        String condition = 'Recurring_Journal_Entry__r.Exclude_From_Automation__c = false ' + 
            'AND Recurring_Journal_Entry__r.Status__c = :active ' +
            'AND Recurring_Journal_Entry__r.Next_Journal_Entry_Date__c <= :today';
        builder.setCondition(condition);

        Map<String,Object> bindMap = new Map<String,Object>{
            'active' => RecurringJournalEntryActions.RECURRING_STATUS_ACTIVE, 
            'today' => Date.today()
        };
        return database().getQueryLocatorWithBinds(builder.toSOQL(), bindMap);
    }

}