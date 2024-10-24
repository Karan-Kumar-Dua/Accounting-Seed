public with sharing class BillingCashReceiptPostBatch extends AbstractSourceRecordPostBatch {

    private String query =
        'SELECT Id, Name ' +
        'FROM ' + PACKAGE_QUALIFIER + 'Billing_Cash_Receipt__c ' +
        'WHERE ' + PACKAGE_QUALIFIER + 'Status__c = \'' + POSTING_STATUS_VALUE + '\' ' +
        'ORDER BY Name ASC';

    public BillingCashReceiptPostBatch(SourceRecordPostBatchChainController chainCon, List<ScheduledPostExecutionReport> priorExecReports) {
        setQuery(query);
        batchChainCtrl = chainCon;
        if (priorExecReports != null && !priorExecReports.isEmpty()) {
            executionReports.addAll(priorExecReports);
        }
    }

    public override void execute(Database.BatchableContext bc, List<SObject> scope) {
        doPostAndReport(new BillingCashReceiptPostHandler(), scope);
    }

}