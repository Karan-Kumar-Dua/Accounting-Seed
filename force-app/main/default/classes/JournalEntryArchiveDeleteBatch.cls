public with sharing class JournalEntryArchiveDeleteBatch extends AbstractArchiveDeleteBatch {

    public JournalEntryArchiveDeleteBatch(ArchiveDeleteChainController chainCon, List<ArchiveDeleteExecutionReport> priorExecReports) {
        init(chainCon, priorExecReports);
    }

    public override Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id FROM ' + PACKAGE_QUALIFIER + 'Journal_Entry__c WHERE ' + PACKAGE_QUALIFIER + 'Accounting_Period__c IN :periodIds AND ' + PACKAGE_QUALIFIER + 'Status__c = :postingStatus AND ' + PACKAGE_QUALIFIER + 'Line_Count__c = 0';
        return Database.getQueryLocator(query);                       
    }

}