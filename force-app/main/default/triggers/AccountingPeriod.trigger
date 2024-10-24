trigger AccountingPeriod on Accounting_Period__c (before insert, before update, after insert, after update, before delete, after delete) {

    if (Trigger.isBefore && Trigger.isInsert) {
        AccountingPeriodActions.setDefaultFields(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        AccountingPeriodActions.validateDateRanges(Trigger.new);
        AccountingPeriodActions.checkNameFormatField(Trigger.new);
        AccountingPeriodActions.preventNameDuplication(Trigger.new);
        AccountingPeriodActions.checkStartDateLessThanEndDate(Trigger.new);
        AccountingPeriodActions.preventOpenPeriodBeforeClosedOrArchivedOrInProgress(Trigger.new);
        AccountingPeriodActions.resetAccountingPeriodHandler();
    }

    if (Trigger.isAfter && Trigger.isUpdate && AccountingPeriodActions.isFirstRun) {
        AccountingPeriodActions.preventSourceDocDeleteCheck(Trigger.new, Trigger.oldMap);
        AccountingPeriodActions.preventBulkUpdateAccountingPeriods(Trigger.new);
        AccountingPeriodActions.checkAllPeriodsHaveSameStatus(Trigger.new, Trigger.old);
        AccountingPeriodActions.checkAccountingPeriodsAreContiguous(Trigger.new);
        AccountingPeriodActions.preventSetStatusClosedIfPreviousIsOpenOrInProgress(Trigger.new, Trigger.oldMap);
        AccountingPeriodActions.allowOnlyOpenStatusFromInProgress(Trigger.new, Trigger.oldMap);
        AccountingPeriodActions.validateDateRanges(Trigger.new);
        AccountingPeriodActions.checkStatusValue(Trigger.new);
        AccountingPeriodActions.preventStatusChangeArchived(Trigger.oldMap, Trigger.newMap);
        AccountingPeriodActions.checkNameFormatField(Trigger.new);
        AccountingPeriodActions.preventNameDuplication(Trigger.new);
        AccountingPeriodActions.checkStartDateLessThanEndDate(Trigger.new);
        AccountingPeriodActions.preventOpenPeriodBeforeClosedOrArchivedOrInProgress(Trigger.new);
        AccountingPeriodActions.preventOpenClosedOrArchivedPeriodIfConsolidation(Trigger.new,  Trigger.oldMap);
        AccountingPeriodActions.preventClosedOrArchivedPeriodLDOInProgress(Trigger.newMap,  Trigger.oldMap);
        AccountingPeriodActions.openAccountingPeriods(Trigger.new, Trigger.oldMap);
        AccountingPeriodActions.closeAccountingPeriods(Trigger.new, Trigger.oldMap);
        AccountingPeriodActions.resetAccountingPeriodHandler();
        AccountingPeriodActions.createCloseBillingAgingOnSoftClose(Trigger.new, Trigger.oldMap);
        AccountingPeriodActions.createCloseAPAgingOnSoftClose(Trigger.new, Trigger.oldMap);
        AccountingPeriodActions.createInventoryHistoriesOnSoftClose(Trigger.new, Trigger.oldMap);
        AccountingPeriodActions.deleteAPAgingOnSoftOpen(Trigger.new, Trigger.oldMap);
        AccountingPeriodActions.deleteARAgingOnSoftOpen(Trigger.new, Trigger.oldMap);
        AccountingPeriodActions.deleteInventoryHistoriesOnSoftOpen(Trigger.new, Trigger.oldMap);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        AccountingPeriodActions.preventDeleteIfRelatedRecordsExist(Trigger.oldMap);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        AccountingPeriodActions.preventCloseAPCloseARCloseInvIfStatusClosed(Trigger.new, Trigger.oldMap);
        AccountingPeriodActions.preventMixOfOpenCloseAndSoftOpenClose(Trigger.new, Trigger.oldMap);
        AccountingPeriodActions.preventSoftOperationWhenOpenCloseInProgress(Trigger.new, Trigger.oldMap);
    }

    if (Trigger.isAfter && Trigger.isDelete) {
        AccountingPeriodActions.resetAccountingPeriodHandler();
    }
}