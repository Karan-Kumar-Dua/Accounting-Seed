public with sharing class AmortizationEntryArchiveDeleteBatch extends AbstractArchiveDeleteBatch {

    public AmortizationEntryArchiveDeleteBatch(ArchiveDeleteChainController chainCon, List<ArchiveDeleteExecutionReport> priorExecReports) {
        init(chainCon, priorExecReports);
    }

    public override Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id FROM ' + PACKAGE_QUALIFIER + 'Scheduled_Revenue_Expense__c WHERE ' + PACKAGE_QUALIFIER + 'Accounting_Period__c IN :periodIds AND ' + PACKAGE_QUALIFIER + 'Status__c = :postingStatus';
        return Database.getQueryLocator(query);
    }

}