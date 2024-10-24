trigger BankTransaction on Bank_Transaction__c (after update) {

    if (Trigger.isAfter && Trigger.isUpdate) {
        BankTransactionActions.preventUpdate(Trigger.new);
    }

}