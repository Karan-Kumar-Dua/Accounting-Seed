trigger Ledger on Ledger__c (before insert, before update, after insert, after update, before delete, after delete) {

    if (Trigger.isBefore && Trigger.isInsert) {
        LedgerActions.setAccountingMethod(Trigger.new);
        LedgerActions.checkFeatureParameterFieldLevelAccessInsert();
        LedgerActions.setDefaultTaxSetting(Trigger.new);
        LedgerActions.setDefaultCurrency(Trigger.new);
        FinancialSuiteService.validateAvaVATLedgerSettings(Trigger.new);
        LedgerActions.presetAccountingMethodLastModifiedDate(Trigger.new, null);
        LedgerActions.resetRelatedLedger(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        LedgerActions.preventAvaTax4CashLedger(Trigger.new);
        LedgerActions.preventInsertOverMaxQuantity(Trigger.new);
        LedgerActions.preventConsolidationsAccrualAndCashMethod(Trigger.new);
        LedgerActions.requireTypeField(Trigger.new);
        LedgerActions.requireCompanyCode(Trigger.new);
        LedgerActions.insertEliminationForConsolidation(Trigger.new);
        LedgerActions.preventCreateEliminationManually(Trigger.new);
        LedgerActions.createGLAccountDefaults(Trigger.new);
        LedgerActions.createShadowLedgers(Trigger.newMap, null);
        TaxService.reset();
        LedgerHandler.reset();
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        LedgerActions.checkFeatureParameterFieldLevelAccessUpdate();
        LedgerActions.setLegacyAccountingMethod(Trigger.new);
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, Trigger.newMap);
        FinancialSuiteService.validateAvaVATLedgerSettings(Trigger.new);
        LedgerActions.presetAccountingMethodLastModifiedDate(Trigger.new, Trigger.oldMap);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        LedgerActions.validateConsolidationAccountingMethod(Trigger.new, Trigger.oldMap);
        LedgerActions.preventAvaTax4CashLedger(Trigger.new);
        LedgerActions.preventChangeTypeOverMaxQuantity(Trigger.oldMap, Trigger.newMap);
        LedgerActions.requireTypeField(Trigger.new);
        LedgerActions.requireCompanyCode(Trigger.new);
        LedgerActions.preventChangeTypeField(Trigger.oldMap, Trigger.newMap);
        LedgerActions.preventCurrencyChange(Trigger.oldMap, Trigger.newMap);
        LedgerActions.preventChangeTaxSettingIfLDOInProgress(Trigger.oldMap, Trigger.newMap);
        GLAccountValidator.validateGlAccountLookups(Trigger.new, Trigger.oldMap, LedgerActions.isPreventUpdateOverride);
        LedgerActions.preventAccountingMethodChangeOnShadowLedger(Trigger.new, Trigger.oldMap);
        LedgerActions.preventAccountingMethodChangeFromCashToAccrualOnLedger(Trigger.new, Trigger.oldMap);
        LedgerActions.preventAccountingMethodChangeFromAccrualToCashOnLedger(Trigger.new, Trigger.oldMap);
        LedgerActions.createShadowLedgers(Trigger.newMap, Trigger.oldMap);
        LedgerActions.updateShadowLedgers(Trigger.new, Trigger.oldMap);
        LedgerActions.updateEliminationLedgers(Trigger.newMap, Trigger.oldMap);
        TaxService.reset();
        LedgerHandler.reset();
        LedgerActions.apAutomation(Trigger.new,Trigger.oldMap);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        LedgerActions.preventLedgerWithRelatedObjectDelete(Trigger.oldMap);
        LedgerActions.preventEliminationLedgerDelete(Trigger.oldMap);
        LedgerActions.preventShadowLedgerDelete(Trigger.old);
        LedgerActions.preventDeleteInactiveLedgers(Trigger.old);
        TaxService.reset();
        LedgerHandler.reset();
    }

    if (Trigger.isAfter && Trigger.isDelete) {
        LedgerActions.deleteEliminationForConsolidation(Trigger.oldMap);
        LedgerActions.deleteShadowLedger(Trigger.old);
    }

}