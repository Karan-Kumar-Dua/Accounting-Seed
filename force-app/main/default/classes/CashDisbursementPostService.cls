global with sharing class CashDisbursementPostService {

    global static List<PostResult> postCashDisbursements(List<Cash_Disbursement__c> cashDisbursements) {
        AbstractPostHandler postHandler = new CashDisbursementPostHandler();
        return postHandler.post(cashDisbursements);
    }

    global static List<PostResult> unpostCashDisbursements(List<Cash_Disbursement__c> cashDisbursements) {
        AbstractPostHandler postHandler = new CashDisbursementPostHandler();
        return postHandler.unpost(cashDisbursements);
    }

}