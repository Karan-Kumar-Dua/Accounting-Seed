trigger BillingCreditMemo on Billing_Credit_Memo__c (before insert, after insert, before update, after update, before delete, after delete) {

    if (Trigger.isBefore && Trigger.isInsert) {
        SObjectActions.setISOCodeFromParent(Trigger.new, 'Billing_Credit_Memo__c');
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, BillingCreditMemoActions.currencyAndNumberFields);
        BillingCreditMemoActions.setAppliedDateIfBlank(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        SObjectActions.validateAppliedDateIsInAppliedAccountingPeriod(Trigger.new);
        MasterRecordMatchingRulesValidator.validate(Trigger.newMap);
        BillingCreditMemoActions.preventIfExistBCRInFutureAccountingPeriod(Trigger.newMap);
        BillingCreditMemoActions.preventIfInvoiceStatusIsInProgress(Trigger.newMap);
        BillingCreditMemoActions.updateBillings(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, BillingCreditMemoActions.currencyAndNumberFields);
        BillingCreditMemoActions.setAppliedDateIfBlank(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        SObjectActions.validateAppliedDateIsInAppliedAccountingPeriod(Trigger.new);
        BillingCreditMemoActions.preventIfInvoiceStatusIsInProgress(Trigger.newMap);
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, Trigger.newMap);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        BillingCreditMemoActions.preventIfExistBCRInFutureAccountingPeriod(Trigger.oldMap);
        BillingCreditMemoActions.preventIfInvoiceStatusIsInProgress(Trigger.oldMap);
    }

    if (Trigger.isAfter && Trigger.isDelete) {
        BillingCreditMemoActions.updateBillings(Trigger.old);
        Database.emptyRecycleBin(Trigger.old);
    }
}