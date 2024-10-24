global with sharing class FinancialReportResult {
    @InvocableVariable
    global Boolean isSuccess;

    @InvocableVariable
    global String data;

    @InvocableVariable
    global List<String> errors = new List<String>();
}