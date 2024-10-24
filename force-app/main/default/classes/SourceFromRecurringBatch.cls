public abstract with sharing class SourceFromRecurringBatch implements Database.Batchable<SObject>, Database.Stateful {
    
    private String correlationId;
    private AJRLogger logger;
    private final Boolean doPost;
    private final Set<Id> recurringHeaderIds;

    /**
     * Constructor for running on all recurring lines ready to be processed.
     */
    public SourceFromRecurringBatch(AJRLogger logger) {
        this(logger, null, false, null);
    }

    /**
     * Constructor for running on recurring lines by header ids.
     */
    public SourceFromRecurringBatch(AJRLogger logger, Set<Id> recurringHeaderIds, Boolean doPost) {
        this(logger, recurringHeaderIds, doPost, null);
    }

    /**
     * Constructor for running on recurring lines by header ids when some transaction_group__c is already exist.
     */
    public SourceFromRecurringBatch(AJRLogger logger, Set<Id> recurringHeaderIds, Boolean doPost, String correlationId) {
        this.logger = logger;
        this.recurringHeaderIds = recurringHeaderIds;
        this.doPost = doPost ?? false;
        this.correlationId = correlationId;
    }

    public abstract SObjectType getRecurringLineType();
    public abstract SObjectType getSourceHeaderType();
    public abstract SObjectType getSourceLineType();
    public abstract void createSourceRecords(List<SObject> recurringLines, String batchId, AJRLogger logger);

    public Database.QueryLocator start(Database.BatchableContext ctx) {
        correlationId = correlationId ?? ctx.getJobId();
        // get the selector for the recurring lines
        RecurringLineSelector selector = SObjectSelectorFactory.getRecurringLineSelector(
            getRecurringLineType(), 
            System.AccessLevel.SYSTEM_MODE, 
            SObjectSelector.SharingMode.WITHOUT_SHARING
        );
        // select all recurring lines ready to be processed
        if (recurringHeaderIds == null) {
            return selector.queryLocatorByReadyToProcess();
        } 
        // select recurring lines by header ids       
        return selector.queryLocatorByHeaderId(recurringHeaderIds);
    }

    public void execute(Database.BatchableContext ctx, List<SObject> scope) {
        createSourceRecords(scope, correlationId, logger); // delegate work to abstract method implementation
        logger.save(); // save logs for this execution
    }

    public void finish(Database.BatchableContext ctx) {
        logger.save(); // save any remaining logs
        // if recurringHeaderIds is null, then this batch was launced from a scheduled job
        if (recurringHeaderIds == null) {
            // only send email for scheduled jobs
            logger.sendEmail(); // send the result email
        }
        Database.executeBatch(new SourceFromRecurringLineCleanupBatch(correlationId, getSourceLineType(), getSourceHeaderType(), doPost));
    }

}