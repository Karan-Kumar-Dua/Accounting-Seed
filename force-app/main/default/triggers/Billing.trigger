trigger Billing on Billing__c (before insert, after insert, before update, after update, before delete, after delete) {

    if (Trigger.isBefore && Trigger.isInsert) {
        SObjectActions.setAccountingPeriod(Trigger.new, Billing__c.Date__c);
        BillingActions.setDefaultFields(Trigger.new);
        BillingActions.associateAccountFields(Trigger.new);
        BillingActions.associateBillingFormat(Trigger.new);
        BillingActions.setDefaultPaymentProcessor(Trigger.new);
        MultiCurrencyHandler.setCurrencyConversionRateBySourceDocumentAndLedger(NULL, Trigger.new, 'Date__c');
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, BillingActions.currencyAndNumberFields);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        BillingActions.requireFields(Trigger.new);
        SObjectActions.validateLedgerType(Trigger.new);
        SObjectActions.validateCurrencyConversionRate(Trigger.new);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        MultiCurrencyHandler.revertCurrencyIsoCodeIfNull(Trigger.oldMap, Trigger.new);
        BillingActions.updateDueDateField(Trigger.new);
        SObjectActions.updateLedgerField(Trigger.oldMap, Trigger.newMap);
        BillingActions.calculateCreditMemoAppliedAmount(Trigger.newMap);
        BillingActions.createPaymentLink(Trigger.new, Trigger.oldMap);
        BillingActions.removePaymentLinkWhenNoPaymentProcessor(Trigger.oldMap,Trigger.new);
        MultiCurrencyHandler.setCurrencyConversionRateBySourceDocumentAndLedger(Trigger.oldMap, Trigger.new, 'Date__c');
        AgingHandler.setClosedAccountingPeriod(Trigger.new, Trigger.oldMap);
        BillingActions.updatePaidDate(Trigger.newMap);
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, BillingActions.currencyAndNumberFields);
        TriggerObserver.getInstance().watch(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, Trigger.newMap);
        SObjectActions.preventUpdateLineCount(Trigger.new, Billing__c.Line_Count__c, NULL);
        SObjectActions.preventUpdateLedgerIfAmortizationEntry(Trigger.oldMap, Trigger.newMap, 'Billing__c');
        BillingActions.preventUpdateLedgerIfAvalaraIsEnabled(Trigger.oldMap, Trigger.new);
        SObjectActions.validateCurrencyConversionRate(Trigger.new);
        BillingActions.requireFields(Trigger.new);
        SObjectActions.validateLedgerType(Trigger.new);
        BillingActions.preventOverAppliedBillings(Trigger.new);
        TriggerObserver.getInstance().validateObservedContent(Trigger.new);
        SObjectActions.preventShadowLedgers(Trigger.new);
            SObjectActions.preventInactiveLedgers(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, NULL);
        if (!AccountingPeriodActions.isDelarcInProgress) {
            TimeCardLineActions.setTimeCardLinesFromBillings(Trigger.oldMap);
            ExpenseLineActions.setExpenseLinesFromBillings(Trigger.oldMap);
        }
    }

    if (Trigger.isAfter && Trigger.isDelete) {
        if (!AccountingPeriodActions.isDelarcInProgress) {
            TimeCardLineActions.setTimeCardLineNonBilled();
            ExpenseLineActions.setExpenseLineNonBilled();
        }
    }

}