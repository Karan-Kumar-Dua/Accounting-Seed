trigger RecurringAccountPayableLine on Recurring_Account_Payable_Line__c (before insert, after insert, before update, after update) {

    if (Trigger.isBefore && Trigger.isInsert) {
        RecurringAccountPayableLineActions.associateDefaultExpenseGLAccount(Trigger.new);
        SObjectActions.populateGLAVsFromAccountOrProduct(Trigger.new);
        SObjectActions.setISOCodeFromParent(Trigger.new, 'Recurring_Account_Payable__c');
        RecurringAccountPayableLineActions.calculateTaxAmountAndSetTaxGroup(Trigger.new, null);
        PayableLineActions.validateAndSetAmountAndUnitCostFields(Trigger.new, NULL);
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, RecurringAccountPayableLineActions.currencyAndNumberFields);
        TriggerObserver.getInstance().watch(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        RecurringAccountPayableLineActions.requireFields(Trigger.new);
        RecurringAccountPayableLineActions.validateTax(Trigger.new, null);
        GLAccountValidator.validateGlAccountLookups(Trigger.new, NULL, RecurringAccountPayableLineActions.bypassGLAccountValidation);
        TriggerObserver.getInstance().validateObservedContent(Trigger.new);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        SObjectActions.setISOCodeFromParent(Trigger.new, 'Recurring_Account_Payable__c');
        RecurringAccountPayableLineActions.calculateTaxAmountAndSetTaxGroup(Trigger.new, Trigger.oldMap);
        PayableLineActions.validateAndSetAmountAndUnitCostFields(Trigger.new,  Trigger.oldMap);
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, RecurringAccountPayableLineActions.currencyAndNumberFields);
        TriggerObserver.getInstance().watch(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        RecurringAccountPayableLineActions.requireFields(Trigger.new);
        RecurringAccountPayableLineActions.validateTax(Trigger.new, Trigger.oldMap);
        GLAccountValidator.validateGlAccountLookups(Trigger.new, Trigger.oldMap);
        TriggerObserver.getInstance().validateObservedContent(Trigger.new);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
    }

}