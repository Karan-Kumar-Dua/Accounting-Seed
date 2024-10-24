trigger RecurringJournalEntryLine on Recurring_Journal_Entry_Line__c (before insert, before update, after insert, after update) {

    if (Trigger.isBefore && Trigger.isInsert) {
        SObjectActions.populateGLAVsFromAccountOrProduct(Trigger.new);
        SObjectActions.setISOCodeFromParent(Trigger.new, 'Recurring_Journal_Entry__c');
        SObjectActions.associateWithCashFlowCategory(Trigger.new);
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, RecurringJournalEntryLineActions.currencyAndNumberFields);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        RecurringJournalEntryLineActions.requireFields(Trigger.new);
        GLAccountValidator.validateGlAccountLookups(Trigger.new, NULL, RecurringJournalEntryLineActions.bypassGLAccountValidation);
        JournalEntryLineActions.validateDebitOrCreditField(Trigger.new);
        JournalEntryLineActions.validatePayeeSetCorrect(Trigger.new);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        SObjectActions.setISOCodeFromParent(Trigger.new, 'Recurring_Journal_Entry__c');
        JournalEntryLineActions.associateWithCashFlowCategoryOnUpdate(Trigger.new, Trigger.oldMap);
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, RecurringJournalEntryLineActions.currencyAndNumberFields);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        RecurringJournalEntryLineActions.requireFields(Trigger.new);
        GLAccountValidator.validateGlAccountLookups(Trigger.new, Trigger.oldMap);
        JournalEntryLineActions.validateDebitOrCreditField(Trigger.new);
        JournalEntryLineActions.validatePayeeSetCorrect(Trigger.new);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
    }

}