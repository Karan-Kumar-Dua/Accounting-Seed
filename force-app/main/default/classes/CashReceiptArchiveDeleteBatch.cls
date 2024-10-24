public with sharing class CashReceiptArchiveDeleteBatch extends AbstractArchiveDeleteBatch {

    public CashReceiptArchiveDeleteBatch(ArchiveDeleteChainController chainCon, List<ArchiveDeleteExecutionReport> priorExecReports) {
        init(chainCon, priorExecReports);
    }

    public override Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id FROM ' + PACKAGE_QUALIFIER + 'Cash_Receipt__c WHERE ' + PACKAGE_QUALIFIER + 'Accounting_Period__c IN :periodIds AND ' + PACKAGE_QUALIFIER + 'Status__c = :postingStatus AND '
                        + PACKAGE_QUALIFIER + 'Bank_Reconciliation__c = null AND ' + PACKAGE_QUALIFIER + 'Bank_Deposit__c = null AND ' +  PACKAGE_QUALIFIER + 'Number_of_Billing_Cash_Receipts__c = 0';
        return Database.getQueryLocator(query);
    }

}