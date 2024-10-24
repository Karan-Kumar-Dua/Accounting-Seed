global with sharing class AmortizationResult {
    @InvocableVariable
    global Boolean isSuccess;

    @InvocableVariable
    global List<String> errors = new List<String>();

    @InvocableVariable
    global List<Scheduled_Revenue_Expense__c> amortizationEntries;
}