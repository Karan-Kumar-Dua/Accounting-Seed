global with sharing class AmortizationPostService {

    global static List<PostResult> postAmortizationEntries(List<Scheduled_Revenue_Expense__c> amortizationEntries) {
        AbstractPostHandler postHandler = new ScheduledRevenueExpensePostHandler();
        return postHandler.post(amortizationEntries);
    }

    global static List<PostResult> unpostAmortizationEntries(List<Scheduled_Revenue_Expense__c> amortizationEntries) {
        AbstractPostHandler postHandler = new ScheduledRevenueExpensePostHandler();
        return postHandler.unpost(amortizationEntries);
    }
}