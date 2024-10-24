public with sharing class SourceFromRecurringLineCleanupBatch implements Database.Batchable<SObject>, Database.Stateful {
    
    private String correlationId;
    private Schema.SObjectType lineSobject;
    private Schema.SObjectType headerSobject;
    private Boolean doPost;

    /**
     * Constructor for default values that are required to delete the source records
     * correlationId => the batch Id
     * lineSobject => line object reference 
     * headerSobject => header object reference
     * doPost => is need to post the billings
     */
    public SourceFromRecurringLineCleanupBatch(String correlationId, Schema.SObjectType lineSobject,Schema.SObjectType headerSobject, Boolean doPost) {
        this.correlationId = correlationId;
        this.lineSobject = lineSobject;
        this.headerSobject = headerSobject;
        this.doPost = doPost;
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        TransactionGroupSelector selector = new TransactionGroupSelector(System.AccessLevel.SYSTEM_MODE, SObjectSelector.SharingMode.WITHOUT_SHARING);
        return selector.queryLocatorForFailedSrcDocsByBatchId(correlationId, headerSobject, lineSobject);
    }

    public void execute(Database.BatchableContext context, List<SObject> scope) {
        // delete lines records
        SFDCSecurityUtils.deleteProxy(scope);
    }

    public void finish(Database.BatchableContext context) {
        //execute next batch to delete the groups and header records
        Database.executeBatch(new SourceFromRecurringHeaderCleanupBatch(correlationId,headerSobject,doPost));
    }
    public String getObjectApiName(Schema.SObjectType T){
        return T.getDescribe().getName();
    }
}