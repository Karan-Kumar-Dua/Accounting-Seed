/**
 * Detemines if a Payment Activity is included in a settled Cardknox batch.
 *      - For CC payments that means the Cardknox batch is closed.
 *      - For ACH payments that means the Cardknox batch is closed and has no pending Payment Activities.
 * For closed Cardknox batches.
 *      - Create Bank Deposits for each Cardknox batch.
 *      - Add Cash Receipts to Bank Deposits. Cash Receipts come from lookup on Payment Activities.
 */
public with sharing class CxTxnsUpdateBatch implements Database.Batchable<SObject>,Database.AllowsCallouts,Database.Stateful  {
    
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    // two different sets to keep succeeded and failed bank deposit separate
    // scenario 1 in first chunk one bank deposit gets passed
    //              add that into successfulBankDeposits 
    //            in second chunk if it fails
    //              remove that from the successfulBankDeposits
    // scenario 2 in first chunk one bank deposit gets failed
    //              add that into failedBankDeposits
    //            in second chunk if it paased
    //              no need to remove it from failedBankDeposits and add in successfulBankDeposits
    // wrapper instace to holds a success and failed items
    private CxTxnsUpdater.ProcessedBankDeposits processedBds;
    //use to keep  keep the end date 
    private DateTime endDate;
    // payment processor ids to limit the payment processor
    private Set<Id> paymentProcessorIds;
    // merchant batch ids to exclude because of pending payments.
    private Set<String> excludeMerchantBatchIds;
    // ajr logger
    private CxAJRLogger logger;

    /**
     * endDate is the cutoff for Payment Activities and any new Bank Deposits
     * when calling out to Cardknox only fetch batch reports.
     * paymentProcessorIds will be used to limit for which payment processors the job is running.
     * merchantBatchesWithPendingPayments will be used to exclude merchant batch ids with pending 
     * payments (see comments in previous job, CxTxnsStatusBatch, for explanation of why not queried here).
     */
    public CxTxnsUpdateBatch(Datetime endDate, Set<Id> paymentProcessorIds, Set<String> merchantBatchesWithPendingPayments, CxAJRLogger logger){
        this.endDate = endDate;
        this.paymentProcessorIds = paymentProcessorIds ?? new Set<Id>();
        this.excludeMerchantBatchIds = merchantBatchesWithPendingPayments ?? new Set<String>();
        this.logger = logger;
        this.processedBds = new CxTxnsUpdater.ProcessedBankDeposits();
    }

    public Database.QueryLocator start(Database.BatchableContext ctx) {
        return DomainUtils.getQueryLocatorForCxTxnsUpdateBatch(this.endDate, this.paymentProcessorIds, this.excludeMerchantBatchIds);
    }

    public void execute(Database.BatchableContext ctx, List<Payment_Activity__c> scope) {
        try {
            CxTxnsUpdater txnsUpdate = new CxTxnsUpdater(logger);
            CxTxnsUpdater.ProcessedBankDeposits results = txnsUpdate.updateActivities(scope, endDate);
            // combine previous batch results with this batch results
            this.processedBds.add(results);
        }
        catch (Exception ex) {
            for (Payment_Activity__c activity : scope) {
                if (activity.Payment_Method__r.Payment_Processor__c != null) {
                    Id processorId = activity.Payment_Method__r.Payment_Processor__c;
                    logger.logError(processorId, ex.getMessage() + '\n' + ex.getStackTraceString());
                }
            }
        }
        // write out this batch of logs
        logger.write();
    }

    public void finish(Database.BatchableContext ctx) {
        // if payment processor did not have any success or failed bank deposits, then it should 
        // be marked as success here, since it won't be passed to the next batch where the others 
        // will be marked successful
        for (Id processorId : this.paymentProcessorIds) {
            if (!this.processedBds.processedPPIds.contains(processorId)) {
                // no failed or successful bank deposits for this payment processor. 
                // for example, no new batch since last run
                logger.logSuccess(processorId);
            }
        }
        // write out this batch of logs
        logger.write();

        // execute the next batch with the endDate and succeeded bank deposits
        this.processedBds.successfulBDIds.removeAll(this.processedBds.failedBDIds);
        if (!Test.isRunningTest() && !this.processedBds.successfulBDIds.isEmpty()) {
           Database.executeBatch(new CxSettlementBatch(this.processedBds, this.endDate, logger), 1);
        }
    }
}