trigger CashReceipt on Cash_Receipt__c (before insert, before update, after insert, after update, before delete) {

    if (Trigger.isBefore && Trigger.isInsert) {
        CashReceiptActions.setDefaultFields(Trigger.new);
        SObjectActions.setAccountingPeriod(Trigger.new, Cash_Receipt__c.Receipt_Date__c);
        CashReceiptActions.populateCreditGLAccount(Trigger.new);
        CashReceiptActions.setDefaultBankAccountAndCheckControlAccount(Trigger.new);
        SObjectActions.populateGLAVsFromAccountOrProduct(Trigger.new, CashReceiptActions.isSkipAutoGLAVsFromAccount);
        SObjectActions.associateWithCashFlowCategory(Trigger.new);
        MultiCurrencyHandler.setCurrencyConversionRateBySourceDocumentAndLedger(NULL, Trigger.new, 'Receipt_Date__c');
        SObjectActions.handleNonCloneableFields(Trigger.new);
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, CashReceiptActions.currencyAndNumberFields);
        CashReceiptActions.amountToWords(Trigger.new);
        CashReceiptActions.setCheckNumber(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        SObjectActions.preventUpdateAction(Trigger.oldMap, Trigger.new, CashReceiptActions.nonUpdateFields, false);
        CashReceiptActions.requireAndValidateFields(Trigger.new);
        SObjectActions.validateLedgerType(Trigger.new);
        GLAccountValidator.validateGlAccountLookups(Trigger.new, NULL);
        SObjectActions.validateCurrencyConversionRate(Trigger.new);
        CashReceiptActions.postApprovedCashReceipts(Trigger.new);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        MultiCurrencyHandler.revertCurrencyIsoCodeIfNull(Trigger.oldMap, Trigger.new);
        CashReceiptActions.populateCreditGLAccount(Trigger.new);
        SObjectActions.updateLedgerField(Trigger.oldMap, Trigger.newMap);
        MultiCurrencyHandler.setCurrencyConversionRateBySourceDocumentAndLedger(Trigger.oldMap, Trigger.new, 'Receipt_Date__c');
        SObjectActions.amountUpdateSourceRecordUpdateBTStatus(Trigger.new, Trigger.oldMap, Cash_Receipt__c.Bank_Transaction__c);
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, CashReceiptActions.currencyAndNumberFields);
        CashReceiptActions.amountToWords(Trigger.new);
        TriggerObserver.getInstance().watch(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, Trigger.newMap);
        SObjectActions.preventSameTimeApplyOnDepositAndReconciliation(Trigger.oldMap, Trigger.new);
        SObjectActions.preventUpdateCustomerAndPeriodIfAppliedBCROrApDisb(Trigger.oldMap, Trigger.newMap, 'Account__c');
        SObjectActions.validateCurrencyConversionRate(Trigger.new);
        CashReceiptActions.requireAndValidateFields(Trigger.new);
        SObjectActions.validateLedgerType(Trigger.new);
        GLAccountValidator.validateGlAccountLookups(Trigger.new, Trigger.oldMap, !CashReceiptActions.isFirstRun);
        SObjectActions.handleBtForceMatch(Trigger.new, Trigger.oldMap);
        CashReceiptActions.postApprovedCashReceipts(Trigger.new, Trigger.oldMap);
        TriggerObserver.getInstance().validateObservedContent(Trigger.new);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, Trigger.newMap);
        CashReceiptActions.preventDeleteBillingCashReceipts(Trigger.old);
        SObjectActions.deleteSourceRecordUpdateBTStatus(Trigger.old);
    }

}