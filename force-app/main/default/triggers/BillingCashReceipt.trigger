trigger BillingCashReceipt on Billing_Cash_Receipt__c (before insert, after insert, before update, after update, before delete, after delete) {

    if (Trigger.isBefore && Trigger.isInsert) {
        BillingCashReceiptActions.setAccountingPeriod(Trigger.new);
        BillingCashReceiptActions.setDefaultFields(Trigger.new);
        BillingCashReceiptActions.setAppliedDateIfBlank(Trigger.new);
        SObjectActions.setISOCodeFromParent(Trigger.new, 'Cash_Receipt__c');
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, BillingCashReceiptActions.currencyAndNumberFields);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        BillingCashReceiptActions.requireFields(Trigger.new);
        BillingCashReceiptActions.validateAppliedDateIsInAppliedAccountingPeriod(Trigger.new);
        MasterRecordMatchingRulesValidator.validate(Trigger.newMap);
        BillingCashReceiptActions.checkControlAccount(Trigger.new);
        BillingCashReceiptActions.requireAdjustmentGLAccountAndAmount(Trigger.new);
        GLAccountValidator.validateGlAccountLookups(Trigger.new, NULL);
        BillingCashReceiptActions.preventIfExistBCRInFutureAccountingPeriod(Trigger.newMap);
        BillingCashReceiptActions.post(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        BillingCashReceiptActions.setAppliedDateIfBlank(Trigger.new);
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, BillingCashReceiptActions.currencyAndNumberFields);
        BillingCashReceiptActions.setPostingStatusForLegacyRecords(Trigger.new);
        TriggerObserver.getInstance().watch(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        BillingCashReceiptActions.requireFields(Trigger.new);
        GLAccountValidator.validateGlAccountLookups(Trigger.new, Trigger.oldMap, !BillingCashReceiptActions.isFirstRun);
        BillingCashReceiptActions.validateAppliedDateIsInAppliedAccountingPeriod(Trigger.new);
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, Trigger.newMap);        
        TriggerObserver.getInstance().validateObservedContent(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        BillingCashReceiptActions.preventDeleteClosedAccountingPeriod(Trigger.oldMap);
        BillingCashReceiptActions.preventIfExistBCRInFutureAccountingPeriod(Trigger.oldMap);
        BillingCashReceiptActions.unpost(Trigger.old);
    }

    if (Trigger.isAfter && Trigger.isDelete) {
        Database.emptyRecycleBin(Trigger.old);
    }

}