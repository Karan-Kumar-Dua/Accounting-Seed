public with sharing class BankTransactionArchiveDeleteBatch extends AbstractArchiveDeleteBatch {

    public BankTransactionArchiveDeleteBatch(ArchiveDeleteChainController chainCon, List<ArchiveDeleteExecutionReport> priorExecReports) {
        init(chainCon, priorExecReports);
    }

    public override Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id FROM ' + PACKAGE_QUALIFIER + 'Bank_Transaction__c WHERE ' + PACKAGE_QUALIFIER + 'Transaction_Date__c >= :startDate' +
            ' AND ' + PACKAGE_QUALIFIER + 'Transaction_Date__c <= :endDate';
        return Database.getQueryLocator(query);                       
    }

}