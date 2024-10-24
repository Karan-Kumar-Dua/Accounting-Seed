trigger AccountingSettings on Accounting_Settings__c (before insert, after insert, after update, after delete) {

    if (Trigger.isBefore && Trigger.isInsert) {
        AccountingSettingsActions.preventInsertSecondRecord(Trigger.new);
        AccountingSettingsActions.setRequiredFields(Trigger.new);
        //reset Accounting Settings storing in memory to enforce query for updated record later
        AccountingSettingsHandler.resetAccountingSettings();
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        AccountingSettingsActions.createLedgerCustomSettingsIfNotExist(Trigger.new);
        AccountingSettingsActions.preventUpdatePostSettings(Trigger.new, NULL);
        AccountingSettingsActions.updatePaymentProcessors(Trigger.new);
        if (!AccountingSettingsActions.isPreventUpdateOverride) {
            GLAccountValidator.validateGlAccountLookups(Trigger.new, NULL, AccountingSettingsActions.isPreventUpdateOverride);
        }
        AccountingSettingsActions.sendAccountingSettingInfo(Trigger.new, null, TriggerOperation.AFTER_INSERT);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        AccountingSettingsActions.checkProjectTaskLaborGLAccountUniqueness(Trigger.new, Trigger.oldMap);
        AccountingSettingsActions.preventUpdateLedgerSettings(Trigger.new, Trigger.oldMap);
        AccountingSettingsActions.preventUpdateArchiveMonthOffset(Trigger.new, Trigger.oldMap);
        AccountingSettingsActions.preventEnableMultiCurrency(Trigger.new, Trigger.oldMap);
        AccountingSettingsActions.preventEnableProductCosting(Trigger.new, Trigger.oldMap);
        AccountingSettingsActions.preventUpdateAvalaraConfiguration(Trigger.new, Trigger.oldMap);
        AccountingSettingsActions.preventUpdateInventoryValuationMethod(Trigger.new, Trigger.oldMap);
        AccountingSettingsActions.preventUpdatePostSettings(Trigger.new, Trigger.oldMap);
        if (!AccountingSettingsActions.isPreventUpdateOverride) {
            GLAccountValidator.validateGlAccountLookups(Trigger.new, Trigger.oldMap, AccountingSettingsActions.isPreventUpdateOverride);
        }
        AccountingSettingsActions.validateAvaSalesTaxGLAccount(Trigger.new);
        //reset Accounting Settings storing in memory to enforce query for updated record later
        AccountingSettingsHandler.resetAccountingSettings();
        TaxService.reset();
        AccountingSettingsActions.updatePaymentProcessors(Trigger.new);
        AccountingSettingsActions.sendAccountingSettingInfo(Trigger.new, Trigger.oldMap, TriggerOperation.AFTER_UPDATE);
    }

    if (Trigger.isAfter && Trigger.isDelete) {
        //reset Accounting Settings storing in memory to enforce query for updated record later
        AccountingSettingsHandler.resetAccountingSettings();
    }

}