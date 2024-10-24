trigger FinancialCubeTransaction on Financial_Cube_Transaction__c (before insert, before update, after insert, after update, before delete) {

    if (Trigger.isBefore && Trigger.isInsert) {
        FinancialCubeTransactionActions.setRequiredFields(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        FinancialCubeTransactionActions.setRequiredFields(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        FinancialCubeTransactionActions.preventDelete(Trigger.old);
    }
 
    if (Trigger.isAfter && Trigger.isInsert) {
        FinancialCubeTransactionActions.preventInsert(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        FinancialCubeTransactionActions.preventUpdate(Trigger.new);
    }

}