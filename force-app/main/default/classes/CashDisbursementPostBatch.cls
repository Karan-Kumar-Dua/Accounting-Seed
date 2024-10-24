public with sharing class CashDisbursementPostBatch extends AbstractSourceRecordPostBatch {

    private static String asyncJobName = 'Async Post or Unpost Job';
    private static String asyncJobTypeName = 'posting/unposting';

    private String query =
        'SELECT Id ' +
        'FROM ' + PACKAGE_QUALIFIER + 'Cash_Disbursement__c ' +
        'WHERE ' + PACKAGE_QUALIFIER + 'Status__c = \'' + POSTING_STATUS_VALUE + '\'';

    public CashDisbursementPostBatch(SourceRecordPostBatchChainController chainCon, List<ScheduledPostExecutionReport> priorExecReports) {
        setQuery(query);
        batchChainCtrl = chainCon;
        if (priorExecReports != null && !priorExecReports.isEmpty()) {
            executionReports.addAll(priorExecReports);
        }
    }

    public CashDisbursementPostBatch(List<String> cashDisbursementIDs, PostResultDispatcher.ExecutionContext exeContext) {
        Set<Id> genericIdSet = new Set<Id>();
        this.dispatcher.setExecutionContext(exeContext);
        for (String cashDisbursementID : cashDisbursementIDs) {
            genericIdSet.add(cashDisbursementID);
        }
        query += ' AND Id IN :genericIdSet';
        if (this.dispatcher.getExecutionContext() == PostResultDispatcher.ExecutionContext.UNPOST) {
            query = query.replace(POSTING_STATUS_VALUE, AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED);
        }
        setQuery(query);
        setRecordIDsToProcess(genericIdSet);
        jobName = asyncJobName;
        jobTypeName = asyncJobTypeName;
        batchChainCtrl = new SourceRecordPostBatchChainController(new List<String>{'Cash Disbursements'});
        batchChainCtrl.setAJR(jobName);
    }

    public override void execute(Database.BatchableContext bc, List<SObject> scope) {
        doPostAndReport(new CashDisbursementPostHandler(), scope);
    }

}