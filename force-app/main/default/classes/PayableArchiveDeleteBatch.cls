public with sharing class PayableArchiveDeleteBatch extends AbstractArchiveDeleteBatch {

    public PayableArchiveDeleteBatch(ArchiveDeleteChainController chainCon, List<ArchiveDeleteExecutionReport> priorExecReports) {
        init(chainCon, priorExecReports);
    }

    public override Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id FROM ' + PACKAGE_QUALIFIER + 'Account_Payable__c WHERE ' + PACKAGE_QUALIFIER + 'Accounting_Period__c IN :periodIds AND ' + PACKAGE_QUALIFIER + 'Status__c = :postingStatus AND ' + PACKAGE_QUALIFIER + 'AP_Disbursement_Count__c = 0';
        return Database.getQueryLocator(query);                       
    }

}