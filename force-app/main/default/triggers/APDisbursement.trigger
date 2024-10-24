trigger APDisbursement on AP_Disbursement__c (  before insert, after insert, before update,
                                                after update, before delete, after delete   ) {

    if (Trigger.isBefore && Trigger.isInsert) {
        APDisbursementActions.preventInsertWhenCDIsPostedWithSourcePayable(Trigger.new);
        APDisbursementActions.setAccountingPeriod(Trigger.new);
        APDisbursementActions.setDefaultFields(Trigger.new);
        APDisbursementActions.setAppliedDateIfBlank(Trigger.new);
        SObjectActions.setISOCodeFromParent(Trigger.new, 'Account_Payable__c');
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, APDisbursementActions.currencyAndNumberFields);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        APDisbursementActions.requireFields(Trigger.new);
        APDisbursementActions.validateAppliedDateIsInAppliedAccountingPeriod(Trigger.new);
        MasterRecordMatchingRulesValidator.validate(Trigger.newMap);
        APDisbursementActions.preventIfExistAPDInFutureAccountingPeriod(Trigger.newMap);
        APDisbursementActions.preventPartialPayIfDiscount(Trigger.newMap);
        APDisbursementActions.post(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        APDisbursementActions.setAccountingPeriod(Trigger.new);
        APDisbursementActions.setAppliedDateIfBlank(Trigger.new);
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, APDisbursementActions.currencyAndNumberFields);
        APDisbursementActions.setPostingStatusForLegacyRecords(Trigger.new);
        TriggerObserver.getInstance().watch(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        APDisbursementActions.requireFields(Trigger.new);
        APDisbursementActions.validateAppliedDateIsInAppliedAccountingPeriod(Trigger.new);
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, Trigger.newMap);
        TriggerObserver.getInstance().validateObservedContent(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        APDisbursementActions.preventIfExistAPDInFutureAccountingPeriod(Trigger.oldMap);
        APDisbursementActions.handleDeletion(Trigger.old);
    }

    if (Trigger.isAfter && Trigger.isDelete) {
        Database.emptyRecycleBin(Trigger.old);
    }

}