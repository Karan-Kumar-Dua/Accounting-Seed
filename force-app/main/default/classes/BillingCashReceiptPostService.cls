global with sharing class BillingCashReceiptPostService {

    global static List<PostResult> postBillingCashReceipts(List<Billing_Cash_Receipt__c> billingCashReceipts) {
        AbstractPostHandler postHandler = new BillingCashReceiptPostHandler();
        return postHandler.post(billingCashReceipts);
    }

}