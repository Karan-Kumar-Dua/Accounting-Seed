public with sharing class UBReconLineArchiveDeleteBatch extends AbstractArchiveDeleteBatch {
    
    public UBReconLineArchiveDeleteBatch(ArchiveDeleteChainController chainCon, List<ArchiveDeleteExecutionReport> priorExecReports) {
        init(chainCon, priorExecReports);
    }

    public override Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id FROM ' + PACKAGE_QUALIFIER + 'Uncleared_Bank_Reconciliation_Line__c WHERE ' + PACKAGE_QUALIFIER + 'Bank_Reconciliation__r.' + PACKAGE_QUALIFIER + 'End_Date__c >= :startDate ' +
        ' AND ' + PACKAGE_QUALIFIER + 'Bank_Reconciliation__r.' + PACKAGE_QUALIFIER + 'End_Date__c <= :endDate';
        return Database.getQueryLocator(query);                           
    }

}