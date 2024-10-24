public with sharing class SourceFromRecurringHeaderCleanupBatch implements Database.Batchable<sObject>, Database.Stateful {
    
    private String correlationId;
    private Schema.SObjectType T;
    private Boolean doPost;
    //collect all record ids which will be posted
    private Set<Id> idsToPost;

    /**
     * Constructor for default values that are required to delete the groups and related records
     * correlationId => the batch Id
     * T => header object reference
     * doPost => is need to post the billings
     */
    public SourceFromRecurringHeaderCleanupBatch(String correlationId, Schema.SObjectType T,Boolean doPost) {
        this.correlationId = correlationId;
        this.T = T;
        this.doPost = doPost;
        this.idsToPost = new Set<Id>();
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        TransactionGroupSelector selector = new TransactionGroupSelector(System.AccessLevel.SYSTEM_MODE, SObjectSelector.SharingMode.WITHOUT_SHARING);
        return selector.queryLocatorByBatchId(correlationId);
    }

    public void execute(Database.BatchableContext context, List<Transaction_Group__c> scope) {
        // collect failed headers
        Set<Id> failedHeaderIds = new Set<Id>();
        Id sObjectId;
        for (Transaction_Group__c txnGroup : scope) {
            //dynamically get the record Id
            sObjectId = (Id)txnGroup.get(getHeadrObjectName());

            //collect failed and postable records
            if (txnGroup.Status__c == TransactionGroupActions.STATUS_FAILED && sObjectId != null) {
                failedHeaderIds.add(sObjectId);
            } else if (doPost && sObjectId != null) {
                idsToPost.add(sObjectId);           
            }
        }
        // if there are headers to cleanup
        if (!failedHeaderIds.isEmpty()) {
            // query and delete related header records
            SObjectSelector selector = SObjectSelectorFactory.getSelector(T, System.AccessLevel.SYSTEM_MODE, SObjectSelector.SharingMode.WITHOUT_SHARING);
            SFDCSecurityUtils.deleteProxy(selector.selectSObjectsById(failedHeaderIds));
        }
        // then delete the transaction group
        SFDCSecurityUtils.deleteProxy(scope);
    }

    public void finish(Database.BatchableContext context) {
        if (doPost && !idsToPost.isEmpty()) {
             // execute post batch with idsToPost
             new PostProcessor().post(new List<Id>(idsToPost)); 
        }
    }
    //get header sobject api name
    private String getHeadrObjectName(){
        return T.getDescribe().getName();
    }
}