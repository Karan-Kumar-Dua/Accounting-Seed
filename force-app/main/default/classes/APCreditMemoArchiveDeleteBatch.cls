public with sharing class APCreditMemoArchiveDeleteBatch extends AbstractArchiveDeleteBatch {

    public APCreditMemoArchiveDeleteBatch(ArchiveDeleteChainController chainCon, List<ArchiveDeleteExecutionReport> priorExecReports) {
        init(chainCon, priorExecReports);
    }

    public override Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id FROM ' + PACKAGE_QUALIFIER + 'AP_Credit_Memo__c WHERE ' + PACKAGE_QUALIFIER + 'Accounting_Period__c IN :periodIds';
        return Database.getQueryLocator(query);                       
    }

}