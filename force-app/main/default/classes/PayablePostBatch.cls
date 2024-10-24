public with sharing class PayablePostBatch extends AbstractSourceRecordPostBatch {

    private String query =
        'SELECT Id ' +
        'FROM ' + PACKAGE_QUALIFIER + 'Account_Payable__c ' +
        'WHERE ' + PACKAGE_QUALIFIER + 'Status__c = \'' + POSTING_STATUS_VALUE + '\'';

    public PayablePostBatch(SourceRecordPostBatchChainController chainCon, List<ScheduledPostExecutionReport> priorExecReports) {
        setQuery(query);
        batchChainCtrl = chainCon;
        if (priorExecReports != null && !priorExecReports.isEmpty()) {
            executionReports.addAll(priorExecReports);
        }
    }

    public override void execute(Database.BatchableContext bc, List<SObject> scope) {
        doPostAndReport(new AccountPayablePostHandler(), scope);
    }

}