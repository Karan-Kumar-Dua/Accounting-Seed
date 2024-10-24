public with sharing class PurgeFinancialReportResultBatch extends PurgeBaseBatch {

    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    public PurgeFinancialReportResultBatch() {
        this.objectLabel = Financial_Report_Result__c.getsObjectType().getDescribe().getLabel();
    }

    public override Database.QueryLocator start(Database.BatchableContext bc) {
        String queryString = 'SELECT Id FROM ' + PACKAGE_QUALIFIER + 'Financial_Report_Result__c';
        return DomainUtils.getQueryLocator(queryString);
    }

}