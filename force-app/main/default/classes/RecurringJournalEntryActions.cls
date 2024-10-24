public with sharing class RecurringJournalEntryActions {
    public static final String RECURRING_STATUS_ACTIVE = 'Active';

    public static final List<String> nonUpdateFields {
        get {
            nonUpdateFields = new List<String> {};
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                nonUpdateFields.add('CurrencyIsoCode');
            }
            return nonUpdateFields;
        }
        set;
    }
    public static Boolean isPreventUpdateOverride = false;

    public static void requireFields(List<Recurring_Journal_Entry__c> recurringJE) {
        for (Recurring_Journal_Entry__c rJE : recurringJE) {
            if (String.isBlank(rJE.Ledger__c)) {
                rJE.Ledger__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
        }
    }

    public static void setStatusInactiveEndDateExceeded(List<Recurring_Journal_Entry__c> recurringJournalEntries){
        for (Recurring_Journal_Entry__c recurringJournalEntry : recurringJournalEntries) {
            if(recurringJournalEntry.End_Date__c != NULL && recurringJournalEntry.Next_Journal_Entry_Date__c != null &&
            recurringJournalEntry.Next_Journal_Entry_Date__c >= recurringJournalEntry.End_Date__c){
                recurringJournalEntry.Status__c = RecurringBillingActions.RECURRING_STATUS_INACTIVE;
            }
        }
    }

    public static void setDefaultValues(List<Recurring_Journal_Entry__c> recurringJournalEntries) {
        for (Recurring_Journal_Entry__c recurringJournalEntry : recurringJournalEntries) {
            if (String.isBlank(recurringJournalEntry.Accrual_and_or_Cash__c) && String.isNotBlank(recurringJournalEntry.Ledger__c)) {
                recurringJournalEntry.Accrual_and_or_Cash__c = LedgerHandler.getInstanceWithoutSharing().getLedgerById(recurringJournalEntry.Ledger__c)?.Accounting_Method__c;
            }
        }
    }
}