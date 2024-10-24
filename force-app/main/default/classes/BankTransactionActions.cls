public with sharing class BankTransactionActions {
    
    public static final String BT_UPDATE_DML_RESTRICTION_ERROR = Label.ERR_BT_UPDATE_DML_RESTRICTION;

    public static Boolean isDmlRestrictionBypassEnabled = false;


    public static void preventUpdate(List<Bank_Transaction__c> bankTransactions) {
        if (!isDmlRestrictionBypassEnabled) {
            for (Bank_Transaction__c bt : bankTransactions) {
                bt.addError(BT_UPDATE_DML_RESTRICTION_ERROR);
            }
        }
    }

}