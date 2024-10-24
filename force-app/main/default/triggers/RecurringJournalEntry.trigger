trigger RecurringJournalEntry on Recurring_Journal_Entry__c (before insert, before update, after insert, after update) {

    if (Trigger.isBefore && Trigger.isInsert) {
        SObjectActions.populateLedgerField(Trigger.new);
        RecurringJournalEntryActions.setStatusInactiveEndDateExceeded(Trigger.new);
        RecurringJournalEntryActions.setDefaultValues(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        RecurringJournalEntryActions.requireFields(Trigger.new);
        SObjectActions.validateLedgerType(Trigger.new, true);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
        SObjectActions.lockAccountingMethodChanging(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        SObjectActions.updateLedgerField(Trigger.oldMap, Trigger.newMap);
        RecurringJournalEntryActions.setStatusInactiveEndDateExceeded(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        SObjectActions.preventUpdateAction(Trigger.oldMap, Trigger.new, RecurringJournalEntryActions.nonUpdateFields, RecurringJournalEntryActions.isPreventUpdateOverride);
        RecurringJournalEntryActions.requireFields(Trigger.new);
        SObjectActions.validateLedgerType(Trigger.new, true);
        SobjectActions.preventUpdateLineCount(Trigger.new, Recurring_Journal_Entry__c.Line_Count__c, NULL);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
        SObjectActions.lockAccountingMethodChanging(Trigger.new);
    }

}