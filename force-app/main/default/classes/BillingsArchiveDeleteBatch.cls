public with sharing class BillingsArchiveDeleteBatch extends AbstractArchiveDeleteBatch {

    public BillingsArchiveDeleteBatch(ArchiveDeleteChainController chainCon, List<ArchiveDeleteExecutionReport> priorExecReports) {
        init(chainCon, priorExecReports);
    }

    public override Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id FROM ' + PACKAGE_QUALIFIER + 'Billing__c WHERE ' + PACKAGE_QUALIFIER + 'Accounting_Period__c IN :periodIds AND ' + PACKAGE_QUALIFIER + 'Status__c = :postingStatus AND ' + PACKAGE_QUALIFIER+ 'Billing_Cash_Receipt_Count__c = 0';
        return Database.getQueryLocator(query);
    }
}