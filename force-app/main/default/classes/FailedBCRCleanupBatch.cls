public with sharing class FailedBCRCleanupBatch implements Database.Batchable<sObject> {
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    //all failed bcr ids to be deleted
    private Set<Id> failedBCRIds;
    private String query;

    public FailedBCRCleanupBatch(Set<Id> failedBCRIds) {
        this.failedBCRIds = failedBCRIds;
        //prepare query
        this.query = 'SELECT Id '+
                    'FROM ' + PACKAGE_QUALIFIER + 'Billing_Cash_Receipt__c ' +
                    'WHERE Id IN  :genericIdSet';
    }
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return DomainUtils.getQueryLocator(query, failedBCRIds);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        //delete records
        SFDCSecurityUtils.deleteProxy(scope);
    }
    public void finish (Database.BatchableContext BC) {
        
    }
}