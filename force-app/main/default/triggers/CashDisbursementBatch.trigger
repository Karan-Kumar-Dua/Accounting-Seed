trigger CashDisbursementBatch on Cash_Disbursement_Batch__c (after update, before delete, after delete) {

    if (Trigger.isDelete && Trigger.isBefore) {
        CashDisbursementBatchActions.preventDeleteAction(Trigger.oldMap);
        CashDisbursementActions.deleteCashDisbursementUpdateAPStatus(Trigger.old);
        CashDisbursementBatchActions.deleteSourceRecordUpdateBTStatus(Trigger.oldMap);
    }
    else if (Trigger.isDelete && Trigger.isAfter) {
        Database.emptyRecycleBin(Trigger.old);
    }
    else if (Trigger.isUpdate) {
        SObjectActions.preventUpdateLineCount(Trigger.new, Cash_Disbursement_Batch__c.Line_Count__c, NULL);
        CashDisbursementBatchActions.preventUpdateCurrency(Trigger.newMap, Trigger.oldMap);
    }
}