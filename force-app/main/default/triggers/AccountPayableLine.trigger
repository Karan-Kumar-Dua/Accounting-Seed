trigger AccountPayableLine on Account_Payable_Line__c (before insert, after insert, before update, after update, before delete, after delete) {

    if (Trigger.isBefore && Trigger.isInsert) {
        AccountPayableLineActions.associateDefaultExpenseGLAccount(Trigger.new);
        SObjectActions.populateGLAVsFromAccountOrProduct(Trigger.new);
        SObjectActions.setISOCodeFromParent(Trigger.new, 'Account_Payable__c');
        AccountPayableLineActions.calculateTaxAmountAndSetTaxGroup(Trigger.new, null);
        AccountPayableLineActions.setVATReportingFields(Trigger.new);
        PayableLineActions.validateAndSetAmountAndUnitCostFields(Trigger.new, NULL);
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, AccountPayableLineActions.currencyAndNumberFields);
        TriggerObserver.getInstance().watch(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        AccountPayableLineActions.validateTax(Trigger.new, null);
        AccountPayableLineActions.requireFields(Trigger.new);
        GLAccountValidator.validateGlAccountLookups(Trigger.new, NULL, AccountPayableLineActions.isBypassGLAccountValidations);
        FinancialSuiteService.validateVATCountryReportable(Trigger.new);
        SourceDocumentUpdateFieldValidator.validate(NULL, Trigger.newMap);
        TriggerObserver.getInstance().validateObservedContent(Trigger.new);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        AccountPayableLineActions.associateDefaultExpenseGLAccount(Trigger.new);
        SObjectActions.setISOCodeFromParent(Trigger.new, 'Account_Payable__c');
        AccountPayableLineActions.calculateTaxAmountAndSetTaxGroup(Trigger.new, Trigger.oldMap);
        AccountPayableLineActions.setVATReportingFields(Trigger.new);
        PayableLineActions.validateAndSetAmountAndUnitCostFields(Trigger.new,  Trigger.oldMap);
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, AccountPayableLineActions.currencyAndNumberFields);
        TriggerObserver.getInstance().watch(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        AccountPayableLineActions.validateTax(Trigger.new, Trigger.oldMap);
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, Trigger.newMap);
        AccountPayableLineActions.requireFields(Trigger.new);
        GLAccountValidator.validateGlAccountLookups(Trigger.new, Trigger.oldMap, AccountPayableLineActions.isBypassGLAccountValidations);
        FinancialSuiteService.validateVATCountryReportable(Trigger.new);
        TriggerObserver.getInstance().validateObservedContent(Trigger.new);
        SObjectActions.preventShadowLedgers(Trigger.new);
            SObjectActions.preventInactiveLedgers(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, NULL);
        if (!AccountingPeriodActions.isDelarcInProgress) {
            ExpenseLineActions.setExpenseLinesFromAccountPayableLines(Trigger.oldMap);
        }
    }

    if (Trigger.isAfter && Trigger.isDelete) {
        if (!AccountingPeriodActions.isDelarcInProgress) {
            ExpenseLineActions.setExpenseLineUnpaid();
        }
    }
}