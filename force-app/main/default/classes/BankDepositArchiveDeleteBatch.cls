public with sharing class BankDepositArchiveDeleteBatch extends AbstractArchiveDeleteBatch {

    public BankDepositArchiveDeleteBatch(ArchiveDeleteChainController chainCon, List<ArchiveDeleteExecutionReport> priorExecReports) {
        init(chainCon, priorExecReports);
    }
    
    public override Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id FROM ' + PACKAGE_QUALIFIER + 'Bank_Deposit__c WHERE ' + PACKAGE_QUALIFIER + 'Deposit_Date__c >= :startDate' +
            ' AND ' + PACKAGE_QUALIFIER + 'Deposit_Date__c <= :endDate AND ' + PACKAGE_QUALIFIER + 'Bank_Reconciliation__c = null';

        return Database.getQueryLocator(query);
    }

}