global with sharing class AccountPayablePostService {

    //not used; still there because of global qualifier
    global static final Integer ACCOUNT_PAYABLE_LINE_COUNT_LIMIT =
        AccountPayablePostHandler.PAYABLE_LINE_COUNT_PRODUCT_COSTING_LIMIT;

    global static List<PostResult> postAccountPayables(List<Account_Payable__c> acctPayables) {
        AbstractPostHandler postHandler = new AccountPayablePostHandler();
        return postHandler.post(acctPayables);
    }    

    global static List<PostResult> unpostAccountPayables(List<Account_Payable__c> acctPayables) {
        AbstractPostHandler postHandler = new AccountPayablePostHandler();
        return postHandler.unpost(acctPayables);
    }

}