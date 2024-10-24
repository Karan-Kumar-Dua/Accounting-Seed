trigger AccountPayable on Account_Payable__c (before insert, after insert, before update, after update, before delete, after delete) {

    if (Trigger.isBefore && Trigger.isInsert) {
        
        AccessControlService controlService =  new AccessControlService(new APAutomationControl(), Account_Payable__c.SObjectType);
        controlService.checkInsertFieldGrants();

        SObjectActions.setAccountingPeriod(Trigger.new, Account_Payable__c.Date__c);
        AccountPayableActions.setDefaultFields(Trigger.new);
        AccountPayableActions.associateAccountFields(Trigger.new);
        AccountPayableActions.preventUpdatingOnHoldstatus(Trigger.New);
        MultiCurrencyHandler.setCurrencyConversionRateBySourceDocumentAndLedger(NULL, Trigger.new, 'Date__c');
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, AccountPayableActions.currencyAndNumberFields);
        AccountPayableActions.requiredPayeeRefOnStatusDraft(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        AccountPayableActions.validateVendorContactEmployee(Trigger.new);
        AccountPayableActions.preventDuplicatePayeeReference(Trigger.oldMap, Trigger.new);
        AccountPayableActions.requireFields(Trigger.new);
        SObjectActions.validateLedgerType(Trigger.new);
        SObjectActions.validateCurrencyConversionRate(Trigger.new);
        SObjectActions.preventShadowLedgers(Trigger.new);
            SObjectActions.preventInactiveLedgers(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {

        AccessControlService controlService =  new AccessControlService(new APAutomationControl(), Account_Payable__c.SObjectType);
        controlService.checkUpdateFieldGrants();

        MultiCurrencyHandler.revertCurrencyIsoCodeIfNull(Trigger.oldMap, Trigger.new);
        SObjectActions.updateLedgerField(Trigger.oldMap, Trigger.newMap);
        AccountPayableActions.setDiscountToZeroIfEmpty(Trigger.new, Trigger.oldMap);
        AccountPayableActions.calculateCreditMemoAppliedAmountAndPaymentStatus(Trigger.newMap);
        MultiCurrencyHandler.setCurrencyConversionRateBySourceDocumentAndLedger(Trigger.oldMap, Trigger.new, 'Date__c');
        AgingHandler.setClosedAccountingPeriod(Trigger.new, Trigger.oldMap);
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, AccountPayableActions.currencyAndNumberFields);
        AccountPayableActions.requiredPayeeRefOnStatusDraft(Trigger.new);
        AccountPayableActions.updateStatusToInProcess(Trigger.new);
        AccountPayableActions.preventUpdatingOnHoldstatus(Trigger.New);
        TriggerObserver.getInstance().watch(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        AccountPayableActions.preventUpdateDiscountAmountForPaidRecords(Trigger.new, Trigger.oldMap);
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, Trigger.newMap);
        AccountPayableActions.validateVendorContactEmployee(Trigger.new);
        AccountPayableActions.preventDuplicatePayeeReference(Trigger.oldMap, Trigger.new);
        SObjectActions.preventUpdateLineCount(Trigger.new, Account_Payable__c.Line_Count__c, NULL);
        SObjectActions.preventUpdateLedgerIfAmortizationEntry(Trigger.oldMap, Trigger.newMap, 'Account_Payable__c');
        AccountPayableActions.requireFields(Trigger.new);
        SObjectActions.validateLedgerType(Trigger.new);
        SObjectActions.validateCurrencyConversionRate(Trigger.new);
        AccountPayableActions.preventOverAppliedPayables(Trigger.new);
        TriggerObserver.getInstance().validateObservedContent(Trigger.new);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, NULL);
        if (!AccountingPeriodActions.isDelarcInProgress) {
            ExpenseLineActions.setExpenseLinesFromAccountPayables(Trigger.oldMap);
        }
    }

    if (Trigger.isAfter && Trigger.isDelete) {
        if (!AccountingPeriodActions.isDelarcInProgress) {
            ExpenseLineActions.setExpenseLineUnpaid();
        }
    }
}