global with sharing class CashReceiptPostService {

    global static List<PostResult> postCashReceipts(List<Cash_Receipt__c> cashReceipts) {
        AbstractPostHandler postHandler = new CashReceiptPostHandler();
        return postHandler.post(cashReceipts);
    }
    global static List<PostResult> unpostCashReceipts(List<Cash_Receipt__c> cashReceipts) {
        AbstractPostHandler postHandler = new CashReceiptPostHandler();
        return postHandler.unpost(cashReceipts);
    }

}