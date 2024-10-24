public with sharing class JournalEntryLineArchiveDeleteBatch extends AbstractArchiveDeleteBatch {

    public JournalEntryLineArchiveDeleteBatch(ArchiveDeleteChainController chainCon, List<ArchiveDeleteExecutionReport> priorExecReports) {
        init(chainCon, priorExecReports);
    }

    public override Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id FROM ' + PACKAGE_QUALIFIER + 'Journal_Entry_Line__c WHERE ' + PACKAGE_QUALIFIER
            + 'Journal_Entry__r.' + PACKAGE_QUALIFIER + 'Accounting_Period__c IN :periodIds AND '
            + PACKAGE_QUALIFIER + 'Journal_Entry__r.' + PACKAGE_QUALIFIER + 'Status__c = :postingStatus AND '
            + PACKAGE_QUALIFIER + 'Bank_Reconciliation__c = null AND ' + PACKAGE_QUALIFIER + 'Bank_Deposit__c = null';
        return Database.getQueryLocator(query);
    }

}