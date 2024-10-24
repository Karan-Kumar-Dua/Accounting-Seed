global with sharing class BillingPostService {

    //not used; still there because of global qualifier
    global static final Integer BILLING_LINE_COUNT_LIMIT =
        BillingPostHandler.BILLING_LINE_COUNT_PRODUCT_COSTING_AND_KITTING_LIMIT;

    global static List<PostResult> postBillings(List<Billing__c> billings) {
        AbstractPostHandler postHandler = new BillingPostHandler();
        return postHandler.post(billings);
    }
    global static List<PostResult> unpostBillings(List<Billing__c> billings) {
        AbstractPostHandler postHandler = new BillingPostHandler();
        return postHandler.unpost(billings);
    }

}