public with sharing class APDisbursementPostBatch extends AbstractSourceRecordPostBatch {

    public APDisbursementPostBatch(SourceRecordPostBatchChainController chainCon, List<ScheduledPostExecutionReport> priorExecReports) {
        Set<Id> genericIdSet = new Set<Id>();
        List<GL_Account_Default__c> apSpecs =  DomainUtils.gLAccountDefaultsBySpecification(new Set<String> {GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT});
        for (GL_Account_Default__c apSpec : apSpecs) {
            genericIdSet.add(apSpec.GL_Account__c);
        }

        String query =
            'SELECT Id, Name, ' +
                + PACKAGE_QUALIFIER + 'Cash_Disbursement__r.' + PACKAGE_QUALIFIER + 'Debit_GL_Account__c, ' +
                + PACKAGE_QUALIFIER + 'Cash_Disbursement__r.' + PACKAGE_QUALIFIER + 'Ledger__c ' +
                'FROM ' + PACKAGE_QUALIFIER + 'AP_Disbursement__c ' +
                'WHERE ' + PACKAGE_QUALIFIER + 'Status__c = \'' + POSTING_STATUS_VALUE + '\' ' +
                'AND ' + PACKAGE_QUALIFIER + 'Cash_Disbursement__r.' + PACKAGE_QUALIFIER + 'Debit_GL_Account__c != NULL '  +
                'AND ' + PACKAGE_QUALIFIER + 'Cash_Disbursement__r.' + PACKAGE_QUALIFIER + 'Debit_GL_Account__c NOT IN :genericIdSet ' +
                'ORDER BY Name ASC';
        setQuery(query);
        setRecordIDsToProcess(genericIdSet);
        processSingleSourceType = false;
        batchChainCtrl = chainCon;
        if (priorExecReports != null && !priorExecReports.isEmpty()) {
            executionReports.addAll(priorExecReports);
        }
    }

    public override void execute(Database.BatchableContext bc, List<SObject> scope) {
        doPostAndReport(new APDisbursementPostHandler(), scope);
    }

}