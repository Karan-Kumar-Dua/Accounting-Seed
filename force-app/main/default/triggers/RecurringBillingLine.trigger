trigger RecurringBillingLine on Recurring_Billing_Line__c (before insert, after insert, before update, after update) {

    if (Trigger.isBefore && Trigger.isInsert) {
        RecurringBillingLineActions.setDefaultRevenueGLAccount(Trigger.new);
        SObjectActions.populateGLAVsFromAccountOrProduct(Trigger.new);
        RecurringBillingLineActions.calculateTaxAmountAndSetTaxGroup(Trigger.new, null);
        SObjectActions.setISOCodeFromParent(Trigger.new, 'Recurring_Billing__c');
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, RecurringBillingLineActions.currencyAndNumberFields);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        RecurringBillingLineActions.requireRevenueGLAccount(Trigger.new);
        RecurringBillingLineActions.preventTaxGroup(Trigger.new);
        GLAccountValidator.validateGlAccountLookups(Trigger.new, NULL, RecurringBillingLineActions.bypassGLAccountValidation);
        RecurringBillingLineActions.validateTax(Trigger.new, null);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        RecurringBillingLineActions.calculateTaxAmountAndSetTaxGroup(Trigger.new, Trigger.oldMap);
        SObjectActions.setISOCodeFromParent(Trigger.new, 'Recurring_Billing__c');
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, RecurringBillingLineActions.currencyAndNumberFields);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        RecurringBillingLineActions.requireRevenueGLAccount(Trigger.new);
        RecurringBillingLineActions.preventTaxGroup(Trigger.new);
        GLAccountValidator.validateGlAccountLookups(Trigger.new, Trigger.oldMap);
        RecurringBillingLineActions.validateTax(Trigger.new, Trigger.oldMap);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
    }

}