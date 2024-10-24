trigger JournalEntry on Journal_Entry__c (before insert, after insert, before update, after update, before delete) {

    if (Trigger.isBefore && Trigger.isInsert) {
        SObjectActions.setAccountingPeriod(Trigger.new, Journal_Entry__c.Journal_Date__c);
        JournalEntryActions.setDefaultFields(Trigger.new);
        JournalEntryActions.setReverseAccountingPeriod(Trigger.new);
        MultiCurrencyHandler.setCurrencyConversionRateBySourceDocumentAndLedger(NULL, Trigger.new, 'Journal_Date__c');
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        SObjectActions.validateLedgerType(Trigger.new, true);
        JournalEntryActions.requireFields(Trigger.new);
        SObjectActions.validateCurrencyConversionRate(Trigger.new);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
        SObjectActions.lockAccountingMethodChanging(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        MultiCurrencyHandler.revertCurrencyIsoCodeIfNull(Trigger.oldMap, Trigger.new);
        SObjectActions.updateLedgerField(Trigger.oldMap, Trigger.newMap);
        MultiCurrencyHandler.setCurrencyConversionRateBySourceDocumentAndLedger(Trigger.oldMap, Trigger.new, 'Journal_Date__c');
        TriggerObserver.getInstance().watch(Trigger.new);
        JournalEntryActions.setReverseAccountingPeriod(Trigger.new, Trigger.oldMap);
        JournalEntryActions.reverseJournalEntries(Trigger.newMap, Trigger.oldMap);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, Trigger.newMap);
        SObjectActions.preventUpdateLineCount(Trigger.new, Journal_Entry__c.Line_Count__c, NULL);
        SObjectActions.validateCurrencyConversionRate(Trigger.new);
        JournalEntryActions.requireFields(Trigger.new);
        SObjectActions.validateLedgerType(Trigger.new, true);
        TriggerObserver.getInstance().validateObservedContent(Trigger.new);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
        SObjectActions.lockAccountingMethodChanging(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, Trigger.newMap);
        JournalEntryActions.updateBankTransactionStatus(Trigger.oldMap);
    }
}