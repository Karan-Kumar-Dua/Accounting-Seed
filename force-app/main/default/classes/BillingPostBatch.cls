public with sharing class BillingPostBatch extends AbstractSourceRecordPostBatch implements Database.AllowsCallouts {

    private String query =
        'SELECT Id ' +
        'FROM ' + PACKAGE_QUALIFIER + 'Billing__c ' +
        'WHERE ' + PACKAGE_QUALIFIER + 'Status__c = \'' + POSTING_STATUS_VALUE + '\'';

    public BillingPostBatch(SourceRecordPostBatchChainController chainCon, List<ScheduledPostExecutionReport> priorExecReports) {
        setQuery(query);
        batchChainCtrl = chainCon;
        if (priorExecReports != null && !priorExecReports.isEmpty()) {
            executionReports.addAll(priorExecReports);
        }
    }

    public override void execute(Database.BatchableContext bc, List<SObject> scope) {
        doPostAndReport(new BillingPostHandler(), scope);
    }

}