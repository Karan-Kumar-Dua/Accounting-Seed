public with sharing class BillingCreditMemoArchiveDeleteBatch extends AbstractArchiveDeleteBatch {

    public BillingCreditMemoArchiveDeleteBatch(ArchiveDeleteChainController chainCon, List<ArchiveDeleteExecutionReport> priorExecReports) {
        init(chainCon, priorExecReports);
    }

    public override Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id FROM ' + PACKAGE_QUALIFIER + 'Billing_Credit_Memo__c WHERE ' + PACKAGE_QUALIFIER + 'Accounting_Period__c IN :periodIds';
        return Database.getQueryLocator(query);                       
    }

}