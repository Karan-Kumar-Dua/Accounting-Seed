trigger AccountingVariable on Accounting_Variable__c (after insert, after update, before delete) {

    if (Trigger.isAfter && Trigger.isInsert) {
        AccountingVariableActions.validateTotalLimit(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        AccountingVariableActions.preventChangeTypeField(Trigger.new, Trigger.oldMap);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        AccountingVariableActions.preventDeleteIfRelatedRecordsExist(Trigger.oldMap);
    }

}