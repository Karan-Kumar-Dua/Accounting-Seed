public with sharing class TimeCardPostBatch extends AbstractSourceRecordPostBatch {

    private String query =
        'SELECT Id ' +
        'FROM ' + PACKAGE_QUALIFIER + 'Time_Card__c ' +
        'WHERE ' + PACKAGE_QUALIFIER + 'Status__c = \'' + POSTING_STATUS_VALUE + '\' ' +
        'AND ' + PACKAGE_QUALIFIER + 'Type__c = \'' + TimeCardActions.TYPE_VALUE_ACTUAL + '\'';

    public TimeCardPostBatch(SourceRecordPostBatchChainController chainCon, List<ScheduledPostExecutionReport> priorExecReports) {
        setQuery(query);
        batchChainCtrl = chainCon;
        if (priorExecReports != null && !priorExecReports.isEmpty()) {
            executionReports.addAll(priorExecReports);
        }
    }

    public override void execute(Database.BatchableContext bc, List<SObject> scope) {
        doPostAndReport(new TimeCardPostHandler(), scope);
    }

}