/**
 * Updates Payment Activities which are not associated with a 
 * Bank Deposit (an indication the Cardknox batch is settled).
 * This will update the Payment Activities with the latest
 * status from Cardknox and create Source Documents for any
 * ACH transactions which have settled.
 */
public with sharing class CxTxnsStatusBatch implements Database.Batchable<SObject>,Database.AllowsCallouts,Database.Stateful  {

    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    // the job will process transactions up to this date 
    private DateTime endDate;
    // ajr logger
    private CxAJRLogger logger;
    // payment gateway - can be mocked for testing
    private PaymentGateway gtwy;
    // Set of payment processor ids which were processed successfully by the previous batch.
    // If any processors have errors in this job they will be removed from this set before being
    // passed to the next batch. This job will not restrict the records it processes based on this
    // set, but the next job will.
    private Set<Id> paymentProcessorIds;
    // A collection of Payment_Activity__c.Merchant_Batch_Id__c where Payment_Activity__c.Status__c = 'Pending'.
    // Keep track of payment batches that have pending payments. This information will 
    // be passed along to the next batch job so that those payment batches can be
    // excluded from further processing. This should not be a very large collection.
    // This information is being gathered in this batch job since it is visiting all of the
    // pending payment activities anyway. If this information were queried in the next batch
    // it would either place an upper limit on either the number of pending ACH payments
    // or the number of merchant batches that can be processed. 
    @TestVisible
    private Set<String> batchesWithPendingPayments;
    // Set of Cash_Receipt__c.Id which need to be voided.
    @TestVisible
    private Set<Id> voids;

    public CxTxnsStatusBatch(Datetime endDate, Set<Id> paymentProcessorIds, CxAJRLogger logger) {
        this(endDate, paymentProcessorIds, logger, new PaymentGateway());
    }

    // for testing - allows injection of mock payment gateway
    @TestVisible
    private CxTxnsStatusBatch(Datetime endDate, Set<Id> paymentProcessorIds, CxAJRLogger logger, PaymentGateway paymentGateway) {
        this.endDate = endDate == null ? Datetime.now() : endDate;
        this.paymentProcessorIds = paymentProcessorIds == null ? new Set<Id>() : paymentProcessorIds;
        this.logger = logger == null ? new CxAJRLogger() : logger;
        this.gtwy = paymentGateway == null ? new PaymentGateway() : paymentGateway;
        this.batchesWithPendingPayments = new Set<String>();
        this.voids = new Set<Id>();
    }

    private static String getQuery() {
        return 'SELECT ' +
            'Id, ' +
            'Name, ' +
            PACKAGE_QUALIFIER + 'Amount__c, ' +
            PACKAGE_QUALIFIER + 'Cash_Receipt__c, ' +
            PACKAGE_QUALIFIER + 'Convenience_Fee__c, ' +
            PACKAGE_QUALIFIER + 'Error_Message__c, ' +
            PACKAGE_QUALIFIER + 'Error_Type__c, ' +
            PACKAGE_QUALIFIER + 'Fee__c, ' +
            PACKAGE_QUALIFIER + 'Fee_Number__c, ' +
            PACKAGE_QUALIFIER + 'Merchant_Batch_Id__c, ' +
            PACKAGE_QUALIFIER + 'Merchant_Reference__c, ' +
            PACKAGE_QUALIFIER + 'Original_Amount__c, ' +
            PACKAGE_QUALIFIER + 'Payment_Method__c, ' +
            PACKAGE_QUALIFIER + 'Payment_Method_Type__c, ' +
            PACKAGE_QUALIFIER + 'Status__c, ' +
            PACKAGE_QUALIFIER + 'Type__c, ' +
            PACKAGE_QUALIFIER + 'Payment_Method__r.' + PACKAGE_QUALIFIER + 'Payment_Processor__c, ' +
            PACKAGE_QUALIFIER + 'Payment_Method__r.' + PACKAGE_QUALIFIER + 'Payment_Processor__r.' + PACKAGE_QUALIFIER + 'Type__c ' +
        'FROM ' + PACKAGE_QUALIFIER + 'Payment_Activity__c  ' +
        'WHERE ' + PACKAGE_QUALIFIER + 'Payment_Method__r.' + PACKAGE_QUALIFIER + 'Payment_Processor__r.' + PACKAGE_QUALIFIER + 'Type__c = \'' + PaymentProcessorActions.CARDKNOX_TYPE + '\' '+
        'AND ' + PACKAGE_QUALIFIER + 'Payment_Method__r.' + PACKAGE_QUALIFIER + 'Payment_Processor__r.' + PACKAGE_QUALIFIER + 'Active__c = TRUE ' +
        'AND ' + PACKAGE_QUALIFIER + 'Cash_Receipt__r.' + PACKAGE_QUALIFIER + 'Bank_Deposit__c = NULL ' +
        'AND ' + PACKAGE_QUALIFIER + 'Status__c IN (\'' + PaymentActivityHelper.PENDING_STATUS + '\', \'' + PaymentActivityHelper.SUCCESS_STATUS + '\') ' +
        'ORDER BY ' + PACKAGE_QUALIFIER + 'Payment_Method__r.' + PACKAGE_QUALIFIER + 'Payment_Processor__c'; 
        // the 'order by' should improve performance if there are multiple processors because it will require fewer http calls per batch of records
    }

    public Database.QueryLocator start(Database.BatchableContext ctx) {
        return DomainUtils.getQueryLocator(getQuery());
    }

    public void execute(Database.BatchableContext ctx, List<Payment_Activity__c> activities) {
        try {
            PaymentActivityUpdateUseCase useCase = new PaymentActivityUpdateUseCase(gtwy);
            PaymentActivityUpdateUseCase.UpdateResult[] results =  useCase.updatePaymentActivities(activities);
            handleResults(results);
        } catch (Exception e) {
            logException(e, activities);
        }
        
        // write log messages for this batch
        logger.write();
    }

    public void finish(Database.BatchableContext ctx) {
        // batch chain forks here

        // forked proc 1: initiate void processes for any records requiring voids
        startVoidProcess();

        // forked proc 2: start next job in merchant download batch chain
        startNextMerchantDownloadStep();

        // write any remaining messages
        logger.write();
    }

    private void handleResults(PaymentActivityUpdateUseCase.UpdateResult[] results) {
        for (PaymentActivityUpdateUseCase.UpdateResult result : results) {
            if (result.cashReceiptRequiresVoid) {
                voids.add(result.activity.Cash_Receipt__c);
            }
            if (result.activity.Status__c == PaymentActivityHelper.PENDING_STATUS && String.isNotBlank(result.activity.Merchant_Batch_Id__c)) {
                batchesWithPendingPayments.add(result.activity.Merchant_Batch_Id__c);
            }
            if (!result.ok) {
                if (paymentProcessorIds.remove(result.processorId)) {
                    String msg = '';
                    String fields;
                    for (Database.Error err : result.errors) {
                        fields = err.getFields() == null || err.getFields().isEmpty() ? '' : ' [' + String.join(err.getFields(), ', ') + ']';
                        msg += err.getMessage() + fields;
                    }
                    logger.logError(result.processorId, msg);
                }
            }
        }
    }

    private void logException(Exception e, List<Payment_Activity__c> activities) {
        // if there is an error, remove the processor so it won't be passed to the next batch
        Id processorId;
        for (Payment_Activity__c activity : activities) {
            processorId = activity.Payment_Method__r.Payment_Processor__c;
            if (paymentProcessorIds.remove(processorId)) {
                logger.logError(processorId, e.getMessage() + '\n' + e.getStackTraceString());
            }
        }
    }

    private void startVoidProcess() {
        if (voids.isEmpty()) {
            return;
        }

        // convert input to VoidData
        List<CashReceiptVoidHelper.VoidData> voidData = new List<CashReceiptVoidHelper.VoidData>();
        Date today = Date.today();
        for (Id cr : voids) {
            CashReceiptVoidHelper.VoidData data = new CashReceiptVoidHelper.VoidData();
            data.cashReceiptId = cr;
            data.voidReceiptDate = today;
            data.description = Label.INF_AUTO_VOIDED_BY_MERCHANT_DOWNLOAD;
            voidData.add(data);
        }

        CashReceiptVoid voidService = new CashReceiptVoid();
        if (!Test.isRunningTest()) {
            // starts a batch chain to void CRs in salesforce
            voidService.asyncVoidCashReceiptInternally(voidData);
        }
    }

    private void startNextMerchantDownloadStep() {
        // start next batch if there are any processors that completed successfully
        if (!paymentProcessorIds.isEmpty() && !Test.isRunningTest()) {
            // next job should only run for processors that completed successfully
            // and exclude any payment batches which have pending payments
            // also must pass endDate to next job so that it can be used to limit socpe
            CxTxnsUpdateBatch nextJob = new CxTxnsUpdateBatch(endDate, paymentProcessorIds, batchesWithPendingPayments, logger);
            Database.executeBatch(nextJob, 200);
        }
    }

}