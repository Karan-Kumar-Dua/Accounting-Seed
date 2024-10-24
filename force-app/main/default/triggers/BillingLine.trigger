trigger BillingLine on Billing_Line__c (before insert, after insert, before update, after update, before delete, after delete) {

    if (Trigger.isBefore && Trigger.isInsert) {
        BillingLineActions.associateDefaultGLAccounts(Trigger.new);
        SObjectActions.populateGLAVsFromAccountOrProduct(Trigger.new);
        SObjectActions.setISOCodeFromParent(Trigger.new, 'Billing__c');
        BillingLineActions.calculateTaxAmountAndSetTaxGroup(Trigger.new, null);
        BillingLineActions.setVATReportingFields(Trigger.new);
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, BillingLineActions.currencyAndNumberFields);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        BillingLineActions.validateTax(Trigger.new, null);
        BillingLineActions.requireRevenueGLAccount(Trigger.new);
        BillingLineActions.preventTaxGroup(Trigger.new);
        GLAccountValidator.validateGlAccountLookups(Trigger.new, null, BillingLineActions.isBypassGLAccountValidations);
        FinancialSuiteService.validateVATCountryReportable(Trigger.new);
        SourceDocumentUpdateFieldValidator.validate(null, Trigger.newMap);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate && !BillingLineActions.isSkipLineUpdateTrigger4LDV) {
        BillingLineActions.calculateTaxAmountAndSetTaxGroup(Trigger.new, Trigger.oldMap);
        BillingLineActions.setVATReportingFields(Trigger.new);
        SObjectActions.setISOCodeFromParent(Trigger.new, 'Billing__c');
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, BillingLineActions.currencyAndNumberFields);
    }

    if (Trigger.isAfter && Trigger.isUpdate && !BillingLineActions.isSkipLineUpdateTrigger4LDV) {
        BillingLineActions.validateTax(Trigger.new, Trigger.oldMap);
        BillingLineActions.requireRevenueGLAccount(Trigger.new);
        BillingLineActions.preventTaxGroup(Trigger.new);
        GLAccountValidator.validateGlAccountLookups(Trigger.new, Trigger.oldMap, BillingLineActions.isBypassGLAccountValidations);
        BillingLineActions.preventReparentingIfBillingIsPosted(Trigger.new, Trigger.oldMap);
        FinancialSuiteService.validateVATCountryReportable(Trigger.new);
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, Trigger.newMap);
        SObjectActions.preventShadowLedgers(Trigger.new);
            SObjectActions.preventInactiveLedgers(Trigger.new);
    }

    if (Trigger.isDelete && Trigger.isBefore) {
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, NULL);
        if (!AccountingPeriodActions.isDelarcInProgress) {
            TimeCardLineActions.setTimeCardLinesFromBillingLines(Trigger.oldMap);
            ExpenseLineActions.setExpenseLinesFromBillingLines(Trigger.oldMap);
        }
    }

    if (Trigger.isDelete && Trigger.isAfter) {
        if (!AccountingPeriodActions.isDelarcInProgress) {
            TimeCardLineActions.setTimeCardLineNonBilled();
            ExpenseLineActions.setExpenseLineNonBilled();
        }
    }

}