trigger APCreditMemo on AP_Credit_Memo__c (before insert, after insert, before update, after update, before delete, after delete) {

    if (Trigger.isBefore && Trigger.isInsert) {
        SObjectActions.setISOCodeFromParent(Trigger.new, 'Account_Payable_Credit_Memo__c');
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, APCreditMemoActions.currencyAndNumberFields);
        APCreditMemoActions.setAppliedDateIfBlank(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        SObjectActions.validateAppliedDateIsInAppliedAccountingPeriod(Trigger.new);
        MasterRecordMatchingRulesValidator.validate(Trigger.newMap);
        APCreditMemoActions.preventIfExistAPDInFutureAccountingPeriod(Trigger.newMap);
        APCreditMemoActions.preventIfInvoiceStatusIsInProgress(Trigger.newMap);
        //Fire update action for master Payable records to recalculate Credit Memo Applied field values
        APCreditMemoActions.updateAccountPayables(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, APCreditMemoActions.currencyAndNumberFields);
        APCreditMemoActions.setAppliedDateIfBlank(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        SObjectActions.validateAppliedDateIsInAppliedAccountingPeriod(Trigger.new);
        APCreditMemoActions.preventIfInvoiceStatusIsInProgress(Trigger.newMap);
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, Trigger.newMap);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        APCreditMemoActions.preventIfExistAPDInFutureAccountingPeriod(Trigger.oldMap);
        APCreditMemoActions.preventIfInvoiceStatusIsInProgress(Trigger.oldMap);
    }

    if (Trigger.isAfter && Trigger.isDelete) {
        //Fire update action for master Payable records to recalculate Credit Memo Applied field values
        APCreditMemoActions.updateAccountPayables(Trigger.old);
        Database.emptyRecycleBin(Trigger.old);
    }

}