public with sharing class AmortizationPostBatch extends AbstractSourceRecordPostBatch {

    private String query =
        'SELECT Id ' +
        'FROM ' + PACKAGE_QUALIFIER + 'Scheduled_Revenue_Expense__c ' +
        'WHERE ' + PACKAGE_QUALIFIER + 'Status__c = \'' + POSTING_STATUS_VALUE + '\'';

    public AmortizationPostBatch(SourceRecordPostBatchChainController chainCon, List<ScheduledPostExecutionReport> priorExecReports) {
        setQuery(query);
        batchChainCtrl = chainCon;
        if (priorExecReports != null && !priorExecReports.isEmpty()) {
            executionReports.addAll(priorExecReports);
        }
    }

    public override void execute(Database.BatchableContext bc, List<SObject> scope) {
        doPostAndReport(new ScheduledRevenueExpensePostHandler(), scope);
    }

}