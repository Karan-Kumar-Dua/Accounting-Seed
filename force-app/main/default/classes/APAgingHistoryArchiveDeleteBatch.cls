public with sharing class APAgingHistoryArchiveDeleteBatch extends AbstractArchiveDeleteBatch {

    public APAgingHistoryArchiveDeleteBatch(ArchiveDeleteChainController chainCon, List<ArchiveDeleteExecutionReport> priorExecReports) {
        init(chainCon, priorExecReports);
    }

    public override Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id FROM ' + PACKAGE_QUALIFIER + 'AP_Aging_History__c WHERE ' + PACKAGE_QUALIFIER + 'Accounting_Period__c IN :periodIds';
        return Database.getQueryLocator(query);                       
    }

}