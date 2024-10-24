trigger TransactionTrigger on Transaction__c (before insert, after insert, before update, after update, before delete, after delete) {
    
    if (Trigger.isBefore && Trigger.isInsert) {
        TransactionActions.preventTransactionInsert(Trigger.new);
        MultiCurrencyHandler.setCurrencyIsoCodeByLedger(Trigger.new);
        TransactionActions.setTransactionKey(Trigger.new);
        TransactionActions.requireFields(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        TransactionActions.validateOriginalState(Trigger.new);
        CubeBuilder.handleAfterInsert(Trigger.new);
        TransactionActions.preventInsertNoSourceDocument(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        TransactionActions.updateTransaction(Trigger.oldMap, Trigger.newMap);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        TransactionActions.preventTransactionUpdate(Trigger.oldMap, Trigger.newMap);
    }
 
    if (Trigger.isBefore && Trigger.isDelete) {
       TransactionActions.preventTransactionDelete(Trigger.old);
    }

    if (Trigger.isAfter && Trigger.isDelete) {
        CubeBuilder.handleAfterDelete(Trigger.old);
    }

}