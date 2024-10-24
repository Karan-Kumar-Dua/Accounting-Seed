public with sharing class BankReconciliationArchiveDeleteBatch extends AbstractArchiveDeleteBatch {
  
    public BankReconciliationArchiveDeleteBatch(ArchiveDeleteChainController chainCon, List<ArchiveDeleteExecutionReport> priorExecReports) {
        init(chainCon, priorExecReports);
    }
  
    public override Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id FROM ' + PACKAGE_QUALIFIER + 'Bank_Reconciliation2__c WHERE ' + PACKAGE_QUALIFIER + 'End_Date__c >= :startDate' +
            ' AND ' + PACKAGE_QUALIFIER + 'End_Date__c <= :endDate';
        return Database.getQueryLocator(query);
    }

}