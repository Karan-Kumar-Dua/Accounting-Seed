public with sharing class CashDisbursementArchiveDeleteBatch extends AbstractArchiveDeleteBatch {

    public CashDisbursementArchiveDeleteBatch(ArchiveDeleteChainController chainCon, List<ArchiveDeleteExecutionReport> priorExecReports) {
        init(chainCon, priorExecReports);
    }

    public override Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id FROM ' + PACKAGE_QUALIFIER + 'Cash_Disbursement__c WHERE ' + PACKAGE_QUALIFIER + 'Accounting_Period__c IN :periodIds AND ' + PACKAGE_QUALIFIER + 'Status__c = :postingStatus AND '
            + PACKAGE_QUALIFIER + 'Bank_Reconciliation__c = null  AND ' + PACKAGE_QUALIFIER + 'AP_Voucher_Count__c = 0';
        return Database.getQueryLocator(query);                       
    }

}