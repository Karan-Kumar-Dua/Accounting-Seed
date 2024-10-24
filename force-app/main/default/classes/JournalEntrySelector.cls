public with sharing class JournalEntrySelector extends SObjectSelector {
    public JournalEntrySelector() {
        super();
    }

    public JournalEntrySelector(System.AccessLevel accessLevel, SharingMode sharingType) {
        super(accessLevel, sharingType);
    }

    public override Schema.SObjectType getSObjectType() {
        return Journal_Entry__c.SObjectType;
    }

    public override List<Schema.SObjectField> getSObjectFields() {
        List<Schema.SObjectField> fields = new List<Schema.SObjectField> {
            Journal_Entry__c.Id,
            Journal_Entry__c.Name,
            Journal_Entry__c.Accounting_Period__c,
            Journal_Entry__c.Accounting_Year__c,
            Journal_Entry__c.Auto_Reversal_JE__c,
            Journal_Entry__c.Auto_Reverse__c,
            Journal_Entry__c.Currency_Conversion_Rate__c,
            Journal_Entry__c.Journal_Date__c,
            Journal_Entry__c.Ledger__c,
            Journal_Entry__c.Line_Count__c,
            Journal_Entry__c.Out_of_Balance__c,
            Journal_Entry__c.Status__c,
            Journal_Entry__c.Recurring_Journal_Entry__c,
            Journal_Entry__c.Reference__c,
            Journal_Entry__c.Reverse_Accounting_Period__c,
            Journal_Entry__c.Source__c,
            Journal_Entry__c.Total_Credits__c,
            Journal_Entry__c.Total_Debits__c,
            Journal_Entry__c.Type__c
        };

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            Schema.SObjectField currencyIsoCode = SchemaDescribe.getDescribe(Journal_Entry__c.SObjectType).getField('CurrencyIsoCode');
            fields.add(currencyIsoCode);
        }

        return fields;
    }
}