/**
 * CardknoxService contains static methods, so it can't be mocked.
 * This class is a wrapper around the static methods, so it can be mocked.
 * CardknoxService methods were not updated to be non-static, because
 * they are used in other places in the codebase.
 */
public with sharing class CxClient {
    public CardknoxService.Report getTransactions(Datetime startDate, Datetime endDate, Integer pageSize, Payment_Processor__c processor) {
        return CardknoxService.getTransactions(startDate, endDate, pageSize, processor);
    }
    public CardknoxService.BatchReport getTransactionBatchReport(DateTime startDate, DateTime endDate, Payment_Processor__c processor) {
        return CardknoxService.getTransactionBatchReport(startDate, endDate, processor);
    }
    public CardknoxService.Report getTransactionReport(List<String> refNums, Payment_Processor__c processor) {
        return CardknoxService.getTransactionReport(refNums, processor);
    }
}