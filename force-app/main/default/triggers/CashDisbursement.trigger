trigger CashDisbursement on Cash_Disbursement__c (before insert, after insert, before update, after update, before delete, after delete) {

    if (Trigger.isBefore && Trigger.isInsert) {

        CashDisbursementActions.checkFeatureParameterFieldLevelAccessInsert();
        SObjectActions.setAccountingPeriod(Trigger.new, Cash_Disbursement__c.Disbursement_Date__c);
        CashDisbursementActions.setDefaultFields(Trigger.new);
        CashDisbursementActions.populatePayeeDataFromVendor(Trigger.new);
        SObjectActions.populateGLAVsFromAccountOrProduct(Trigger.new, CashDisbursementActions.isSourcedFromPayables);
        CashDisbursementActions.amountToWords(Trigger.new);
        SObjectActions.associateWithCashFlowCategory(Trigger.new);
        MultiCurrencyHandler.setCurrencyConversionRateBySourceDocumentAndLedger(NULL, Trigger.new, 'Disbursement_Date__c');
        SObjectActions.handleNonCloneableFields(Trigger.new);
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, CashDisbursementActions.currencyAndNumberFields);
        CashDisbursementActions.validateBankDisbursementRelatedFields(Trigger.new);
        CashDisbursementActions.validateIfRecordPostedBeforeAssociating(Trigger.new, Trigger.oldMap);
        if (!CashDisbursementActions.isSourcedFromPayables) {
            CashDisbursementActions.set1099Fields(Trigger.new);
        }
        if (CashDisbursementActions.isSourcedFromPayables) {
            TriggerObserver.getInstance().watch(Trigger.new);
        }
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        CashDisbursementActions.requireFields(Trigger.new);
        CashDisbursementActions.validateVendorContactEmployee(Trigger.new);
        CashDisbursementActions.validateCashDisbursementBatchHasTheSameCurrency(Trigger.new);
        SObjectActions.validateCurrencyConversionRate(Trigger.new);
        SObjectActions.validateLedgerType(Trigger.new);
        GLAccountValidator.validateGlAccountLookups(Trigger.new, NULL, CashDisbursementActions.isBypassGLAccountValidations);
        if (CashDisbursementActions.isSourcedFromPayables) {
            TriggerObserver.getInstance().validateObservedContent(Trigger.new);
        }
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
        CashDisbursementActions.calculateAmountFields(Trigger.New, Trigger.OldMap);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {

        CashDisbursementActions.checkFeatureParameterFieldLevelAccessUpdate();
        CashDisbursementActions.setSourceAndAmountAndDebitGLAccountFields(Trigger.oldMap, Trigger.new);
        CashDisbursementActions.amountToWords(Trigger.new);
        CashDisbursementActions.updatePaymentStatus(Trigger.new);
        CashDisbursementActions.validateVoid(Trigger.new);
        CashDisbursementActions.validateBankDisbursementRelatedFields(Trigger.new);
        CashDisbursementActions.validateIfRecordPostedBeforeAssociating(Trigger.new, Trigger.oldMap);
        CashDisbursementActions.preventBankDisbUpdateIfBankRecCleared(Trigger.new,Trigger.oldMap);
        if (!CashDisbursementActions.isBatchPay) {

            MultiCurrencyHandler.revertCurrencyIsoCodeIfNull(Trigger.oldMap, Trigger.new);
            SObjectActions.updateLedgerField(Trigger.oldMap, Trigger.newMap);
            CashDisbursementActions.updateLegacyVoidedDateField(Trigger.oldMap, Trigger.newMap);
            CashDisbursementActions.validate1099Info(Trigger.new, Trigger.oldMap);
            CashDisbursementActions.PaymentServicesValidation(Trigger.new, Trigger.oldMap);
            MultiCurrencyHandler.setCurrencyConversionRateBySourceDocumentAndLedger(Trigger.oldMap, Trigger.new, 'Disbursement_Date__c');
            SObjectActions.amountUpdateSourceRecordUpdateBTStatus(Trigger.new, Trigger.oldMap, Cash_Disbursement__c.Bank_Transaction__c);
            SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, CashDisbursementActions.currencyAndNumberFields);
            TriggerObserver.getInstance().watch(Trigger.new);
        }
        CashDisbursementActions.preventBDBAssociationIfDifferentGLV(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate && !CashDisbursementActions.isBatchPay) {
        CashDisbursementActions.requireFields(Trigger.new);
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, Trigger.newMap);
        CashDisbursementActions.validateVendorContactEmployee(Trigger.new);
        CashDisbursementActions.preventUpdateFieldsIfSourcedAP(Trigger.oldMap, Trigger.newMap);
        CashDisbursementActions.validateCashDisbursementBatchHasTheSameCurrency(Trigger.new);
        SObjectActions.validateCurrencyConversionRate(Trigger.new);
        SObjectActions.validateLedgerType(Trigger.new);
        GLAccountValidator.validateGlAccountLookups(Trigger.new, Trigger.oldMap, CashDisbursementActions.isBypassGLAccountValidations);
        SObjectActions.handleBtForceMatch(Trigger.new, Trigger.oldMap);
        TriggerObserver.getInstance().validateObservedContent(Trigger.new);
        TriggerObserver.purgeUnlockedFields(Cash_Disbursement__c.Amount__c);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
        CashDisbursementActions.calculateAmountFields(Trigger.New, Trigger.OldMap);
    }

    if (Trigger.isDelete && Trigger.isBefore) {
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, NULL);
        CashDisbursementActions.preventDeleteIfApdExists(Trigger.old);
        CashDisbursementActions.deleteCashDisbursementUpdateAPStatus(Trigger.old);
        SObjectActions.deleteSourceRecordUpdateBTStatus(Trigger.old);
    }

    if (Trigger.isDelete && Trigger.isAfter) {
        CashDisbursementActions.calculateAmountFields(Trigger.New, Trigger.OldMap);
        Database.emptyRecycleBin(Trigger.old);
    }

}