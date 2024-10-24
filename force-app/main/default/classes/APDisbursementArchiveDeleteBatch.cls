public with sharing class APDisbursementArchiveDeleteBatch extends AbstractArchiveDeleteBatch {

    public APDisbursementArchiveDeleteBatch(ArchiveDeleteChainController chainCon, List<ArchiveDeleteExecutionReport> priorExecReports) {
        init(chainCon, priorExecReports);
    }

    public override Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id, ' + PACKAGE_QUALIFIER + 'Cash_Disbursement__r.' + PACKAGE_QUALIFIER + 'Accounting_Period__c FROM ' +
            PACKAGE_QUALIFIER + 'AP_Disbursement__c WHERE (' +
            PACKAGE_QUALIFIER + 'Accounting_Period__c != null AND ' + PACKAGE_QUALIFIER + 'Accounting_Period__c IN :periodIds) ' +
            'OR (' + PACKAGE_QUALIFIER + 'Cash_Disbursement__r.' + PACKAGE_QUALIFIER + 'Accounting_Period__c IN :periodIds)';
        return Database.getQueryLocator(query);
    }

}