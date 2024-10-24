//DO NOT CHANGE THE COMMENT STYLE IN THIS CLASS FOR THE DEPRECATED ANNOTATION!
global with sharing class ScheduledRevenueExpensePostService {
    /*
    @Deprecated
    */
    global static List<PostResult> postScheduledReveneueExpenses(List<Scheduled_Revenue_Expense__c> scheduledRevenueExpenses) {
        return ScheduledRevenueExpensePostService.postScheduledRevenueExpenses(scheduledRevenueExpenses);
    }
    global static List<PostResult> postScheduledRevenueExpenses(List<Scheduled_Revenue_Expense__c> scheduledRevenueExpenses) {
        AbstractPostHandler postHandler = new ScheduledRevenueExpensePostHandler();
        return postHandler.post(scheduledRevenueExpenses);
    }
    /*
    @Deprecated
    */
    global static List<PostResult> unpostScheduledReveneueExpenses(List<Scheduled_Revenue_Expense__c> scheduledRevenueExpenses) {
        return ScheduledRevenueExpensePostService.unpostScheduledRevenueExpenses(scheduledRevenueExpenses);
    }
    global static List<PostResult> unpostScheduledRevenueExpenses(List<Scheduled_Revenue_Expense__c> scheduledRevenueExpenses) {
        AbstractPostHandler postHandler = new ScheduledRevenueExpensePostHandler();
        return postHandler.unpost(scheduledRevenueExpenses);
    }

}