/**
 *  Transactions created through Cardknox PaymentSITE or the Cardknox Dashboard 
 *  occur outside of Salesforce. As such, the transactions must be routinely 
 *  retrieved from Cardknox.
 * 
 *  ONLY RUN WITH BATCH SIZE 1. 
 */
public with sharing class CxTxnsImportBatch implements Database.Batchable<Integer>, Database.AllowsCallouts, Database.Stateful {
    // number of days of historical data to fetch from cardknox if this is the first sync
    public static final Integer FIRST_SYNC_DAYS = 30;


    // max number of transactions to fetch per callout
    @TestVisible
    private static final Integer PAGE_SIZE = CxTxnsImporter.MAX_PAGE_SIZE;
    // used exclusively to inject mock for testing
    // Note: storing in a static variable because this is a stateful batch job. There is
    //       no need to include this in the state. This var will be null during normal 
    //       execution, we would expect only one word of memory to be allocated (memory address of object) 
    //       and no memory needed for the object itself since it will never be instantiated.
    @TestVisible
    private static CxTxnsImporter mockImporter;
    
    // the date up to which transactions should be imported.
    // ensures we have a fixed end date. 
    // if Datetime.now() was used in the execute method the end time would keep moving.
    @TestVisible
    private Datetime endDate;
    // because last sync filed is only updated after the last batch job in this chain completes
    // the data load progress must be tracked in memory.
    // processor_id => syncd_to_date
    @TestVisible
    private Map<Id,Datetime> syncProgress;
    // we need to record which processors completed successfully so that the 
    // next job in the chain can skip processors with errors, otherwise it will 
    // appear that the processor is up to date when not all txns have been imported
    @TestVisible
    private Set<Id> processorsCompletedNormally;
    // used for batch chain AJR logging
    @TestVisible
    private CxAJRLogger logger;

    public CxTxnsImportBatch() {
        this.endDate = Datetime.now();
        this.syncProgress = new Map<Id,Datetime>();
        this.processorsCompletedNormally = new Set<Id>();
        this.logger = new CxAJRLogger();
    }

    /**
     * Called when the batch re-schedules itself. Used to persist state across batch jobs.
     * 
     * The job is loading data from another system which doesn't provide a way to
     * get a count of records to import. Because of this the start method
     * can only make an approximation of how many batches of data will be
     * needed. If more are needed the job will re-schedule itself until all
     * processors are up to date.
     */
    @TestVisible
    private CxTxnsImportBatch(Datetime endDate, Map<Id,Datetime> syncProgress, Set<Id> processorsCompletedNormally, CxAJRLogger logger) {
        this.endDate = endDate;
        this.syncProgress = syncProgress;
        this.processorsCompletedNormally = processorsCompletedNormally;
        this.logger = logger;
    }

    public Iterable<Integer> start(Database.BatchableContext ctx) {
        if (syncProgress.isEmpty()) {
            // first run of this job. if job has been scheduled using private constructor
            // then syncProgress will already be populated
            initSyncProgress();
        }

        Integer expectedCallouts = projectCallouts();
        return new RangeIterable(expectedCallouts);
    }

    public void execute(Database.BatchableContext ctx, List<Integer> scope) {
        if (syncProgress.isEmpty()) {
            // no more transactions to import
            return;
        }

        // get a processor which still has transactions to import
        Payment_Processor__c processor = DomainUtils.getPaymentProcessorById(new List<Id>(syncProgress.keySet())[0]);
        
        // if the end date is more than 99 days from the start date the date range needs to be scaled down
        Datetime startDate = syncProgress.get(processor.Id);
        Datetime adjustedEndDate = endDate;
        Integer days = startDate.date().daysBetween(endDate.date());
        if (days > CxTxnsImporter.MAX_REPORTING_DAYS) {
            adjustedEndDate = startDate.addDays(CxTxnsImporter.MAX_REPORTING_DAYS);
        }

        try {
            // import transactions from cardknox and create source documents
            CxTxnsImporter cx = getCxTxnsImporter(processor, logger);
            Datetime syncdTo = cx.import(PAGE_SIZE, startDate, endDate);
            if (syncdTo >= endDate) {
                // transactions fully imported for this processor
                syncProgress.remove(processor.Id);
                processorsCompletedNormally.add(processor.Id);
            } else {
                // more transactions to import for this processor
                syncProgress.put(processor.Id, syncdTo);
            }
        } catch (CxTxnsImporter.CxTxnsImporterException e) {
            // remove from syncProgress so that the job doesn't keep trying to import transactions for this processor
            syncProgress.remove(processor.Id);
            // these have already been logged by CxTxnImporter
        } catch (Exception e) { // catch top level exception to ensure all exceptions are handled
            // remove from syncProgress so that the job doesn't keep trying to import transactions for this processor
            syncProgress.remove(processor.Id);
            logger.logError(processor.Id, e.getMessage() + '\n' + e.getStackTraceString());
        }
        // write log messages for this batch
        logger.write();
    }

    public void finish(Database.BatchableContext ctx) {
        if (syncProgress.isEmpty()) {
            // if all import work complete 
            // update last sync date for processors which completed successfully
            updateLastSync();
            // schedule next job to run for processors which completed successfully
            Set<Id> processorsWithoutErrors = getProcessorsWithoutErrors();
            if (!processorsWithoutErrors.isEmpty() && !Test.isRunningTest()) {
                // next job should only run for processors that completed successfully without associated error objects
                // also must pass endDate to next job so that it can be used to limit socpe
                CxTxnsStatusBatch nextJob = new CxTxnsStatusBatch(endDate, processorsWithoutErrors, logger);
                Database.executeBatch(nextJob, 200);
            }
        } else if (!Test.isRunningTest()) {
            // there are more transactions to import
            CxTxnsImportBatch job = new CxTxnsImportBatch(endDate, syncProgress, processorsCompletedNormally, logger);
            Database.executeBatch(job, 1);
        }
    }

    // updates the last sync date for all processors which successfully completed
    private void updateLastSync() {
        Set<Id> processorsWithoutErrors = getProcessorsWithoutErrors();
        List<Payment_Processor__c> processors = new List<Payment_Processor__c>();
        for (Id processorId : processorsWithoutErrors) {
            processors.add(new Payment_Processor__c(Id = processorId, Last_Sync__c = endDate));
        }

        // update processors' last_sync field, partial success is allowed
        List<Database.SaveResult> results = SFDCSecurityUtils.updateProxy(processors, false);

        // if update failed discard processor from list of successfuly completed processors
        for (Database.SaveResult result : results) {
            if (!result.isSuccess()) {
                processorsCompletedNormally.remove(result.getId());
                String message = String.format(Label.ERR_LAST_SYNC_UPDATE_FAILED, new List<String>{result.getId()});
                for (Database.Error e : result.getErrors()) {
                    message += '\n' + e.getMessage() + ': ' + e.getFields();
                }
                logger.logError(result.getId(), message);
            }
        }
    }

    // determines which processors will be passed to next chained batch job
    private Set<Id> getProcessorsWithoutErrors() {
        Set<Id> processorsWithoutErrors = new Set<Id>(processorsCompletedNormally);
        for (Payment_Processor__c processor : DomainUtils.getActivePaymentProcessorsWithErrors()) {
            processorsWithoutErrors.remove(processor.Id);
        }
        return processorsWithoutErrors;
    }

    // facilitates test mocking
    private CxTxnsImporter getCxTxnsImporter(Payment_Processor__c processor, CxAJRLogger logger) {
        if (Test.isRunningTest() && mockImporter != null) {
            return mockImporter;
        }
        return new CxTxnsImporter(processor, logger);
    }

    // initializes the syncProgress map with each processors last_sync__c datetime
    private void initSyncProgress() {
        for (Payment_Processor__c processor : DomainUtils.getActivePaymentProcessorsByType(PaymentProcessorActions.CARDKNOX_TYPE)) {
            Datetime lastSync = processor.Last_Sync__c == null ? endDate.addDays(-1 * FIRST_SYNC_DAYS) : processor.Last_Sync__c;
            if (lastSync < endDate) {
                // the processor is not up to date
                syncProgress.put(
                    processor.Id, 
                    lastSync
                );
            }
        }
    }

    // projects the number of callouts needed to import all transactions based on historical data
    // cardknox does not provide a way to get a count of transactions so this is the best we can do
    private Integer projectCallouts() {
        // check last 30 day volume for each processor
        List<AggregateResult> volumes = DomainUtils.getPaymentProcessorsHistoricalVolume(PaymentProcessorActions.CARDKNOX_TYPE);

        // get days since last run
        Integer deltaDays = 1;
        Integer days;
        for (Datetime startDate : syncProgress.values()) {
            days = startDate.date().daysBetween(endDate.date());
            if (days > deltaDays) {
                deltaDays = days;
            }
        }

        // get max volume processed by a single processor in a single day
        Integer max;
        if (!volumes.isEmpty() && (Integer)volumes[0].get('cnt') > 0) {
            max = (Integer)volumes[0].get('cnt');
        } else { // no historical data
            max = PAGE_SIZE;
        }

        // calculate number of callouts needed to fetch a single day of transactions per processor
        Integer calloutsPerDay = Math.max(1, Integer.valueOf(Math.ceil(max / PAGE_SIZE)));

        // total callouts required to bring all processors up to date
        Integer totalCallouts = calloutsPerDay * deltaDays * syncProgress.size();

        return totalCallouts;
    }

    public with sharing class RangeIterator implements Iterator<Integer>{ 
        private Integer last;
        private Integer idx;
        public RangeIterator(Integer n) {
            this.last = n;
            this.idx = 0;
        }
        public Boolean hasNext() { 
            return idx < last;
        }    
        public Integer next() {
            if (hasNext()) {
                return idx++;
            }
            return null;
        } 
    }

    public class RangeIterable implements Iterable<Integer> {
        private Integer n;
        public RangeIterable(Integer n) {
            this.n = n;
        }
        public Iterator<Integer> iterator() {
           return new RangeIterator(n);
        }
    }

}