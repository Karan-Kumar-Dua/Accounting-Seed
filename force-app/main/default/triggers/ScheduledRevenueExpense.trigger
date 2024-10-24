trigger ScheduledRevenueExpense on Scheduled_Revenue_Expense__c (before insert, after insert, before update, after update, before delete) {

    if (Trigger.isInsert && Trigger.isBefore) {
        ScheduledRevenueExpenseActions.setAndValidateSameLedgerFromSourceRecord(Trigger.new);
        ScheduledRevenueExpenseActions.setDefaultFields(Trigger.new);
        ScheduledRevenueExpenseActions.populateGLAVsFromAccountOrProduct(Trigger.new);
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, ScheduledRevenueExpenseActions.currencyAndNumberFields);
    }

    if (Trigger.isInsert && Trigger.isAfter) {
        ScheduledRevenueExpenseActions.requireFields(Trigger.new);
        SObjectActions.validateLedgerType(Trigger.new);
        GLAccountValidator.validateGlAccountLookups(Trigger.new, NULL);
        ScheduledRevenueExpenseActions.validateSourceField(Trigger.new);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
        SObjectActions.lockAccountingMethodChanging(Trigger.new);
        ScheduledRevenueExpenseActions.post(Trigger.new);
    }

    if (Trigger.isUpdate && Trigger.isBefore) {
        ScheduledRevenueExpenseActions.setDefaultAcctMethod(Trigger.new);
        SObjectActions.updateLedgerField(Trigger.oldMap, Trigger.newMap);
        MulticurrencyHandler.setCurrencyIsoCodeByLedger(Trigger.new);
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, ScheduledRevenueExpenseActions.currencyAndNumberFields);
        TriggerObserver.getInstance().watch(Trigger.new);
    }

    if (Trigger.isUpdate && Trigger.isAfter) {
        ScheduledRevenueExpenseActions.requireFields(Trigger.new);
        ScheduledRevenueExpenseActions.setAndValidateSameLedgerFromSourceRecord(Trigger.new);
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, Trigger.newMap);
        ScheduledRevenueExpenseActions.validateSourceField(Trigger.new);
        SObjectActions.validateLedgerType(Trigger.new);
        GLAccountValidator.validateGlAccountLookups(Trigger.new, Trigger.oldMap, !ScheduledRevenueExpenseActions.isFirstRun);
        TriggerObserver.getInstance().validateObservedContent(Trigger.new);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
        SObjectActions.lockAccountingMethodChanging(Trigger.new);
    }

    if (Trigger.isDelete && Trigger.isBefore) {
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, Trigger.newMap);
    }
}