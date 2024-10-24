public with sharing abstract class AbstractSourceRecordPostBatch implements Database.Batchable<SObject>, Database.Stateful {

    private static final Integer COMMON_BATCH_CHUNK_SIZE = 100;
    private static final Integer SPECIAL_BATCH_CHUNK_SIZE = 1;
    public static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final String POSTING_STATUS_VALUE = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED;

    public static final String JOB_NAME = 'Scheduled Post Job';
    protected String jobName = JOB_NAME;
    protected String jobTypeName = Label.COMMON_POSTING;
    protected String query;
    protected Set<Id> recordIDsToProcess;
    protected Boolean processSingleSourceType = false;
    protected PostResultDispatcher dispatcher = new PostResultDispatcher();
    protected List<ScheduledPostExecutionReport> executionReports = new List<ScheduledPostExecutionReport>();
    protected SourceRecordPostBatchChainController batchChainCtrl;

    public enum SourceRecordType {
        BILLING,
        BILLING_CASH_RECEIPT,
        CASH_RECEIPT,
        PAYABLE,
        CASH_DISBURSEMENT,
        AP_DISBURSEMENT,
        TIME_CARD,
        JOURNAL_ENTRY,
        AMORTIZATION,
        IIM,
        OIM,
        SIM,
        PIM,
        MIM
    }

    public static final Map<SourceRecordType, String> BATCHES_BY_SOBJECT_TYPES = new Map<AbstractSourceRecordPostBatch.SourceRecordType, String> {
        SourceRecordType.BILLING => BillingLDVPostBatch.class.getName(),
        SourceRecordType.PAYABLE => AccountPayableLDVPostBatch.class.getName(),
        SourceRecordType.JOURNAL_ENTRY => JournalEntryLDVPostBatch.class.getName(),
        SourceRecordType.BILLING_CASH_RECEIPT => BillingCashReceiptLDVPostBatch.class.getName(),
        SourceRecordType.AP_DISBURSEMENT => APDisbursementLDVPostBatch.class.getName()
    };

    protected void setQuery(String query) {
        this.query = query;
    }

    protected void setRecordIDsToProcess(Set<Id> recordIDs) {
        this.recordIDsToProcess = recordIDs;
        this.processSingleSourceType = true;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        batchChainCtrl.setAJR(jobName);
        return this.recordIDsToProcess != NULL && !this.recordIDsToProcess.isEmpty() ?
            DomainUtils.getQueryLocator(query, this.recordIDsToProcess) : DomainUtils.getQueryLocator(query);
    }

    public abstract void execute(Database.BatchableContext bc, List<SObject> scope);

    public void finish(Database.BatchableContext bc) {

        //add Execution Reports
        executionReports.add(
            new ScheduledPostExecutionReport(
                this.batchChainCtrl.getCurrentSobjectType().getDescribe().getLabelPlural(),
                dispatcher.getAllResultsQuantity(),
                dispatcher.getErrorResultsQuantity()
            )
        );

        //run next batch job in chain if it is not completed yet
        if (batchChainCtrl.hasNext() && !processSingleSourceType) {
            batchChainCtrl.next();
            executeBatchChain(batchChainCtrl, executionReports);
        }
        else {
            if (String.isNotBlank(batchChainCtrl.getAjrId())) {
                AutomatedJobResultsHandler.presetJobResultRecord(batchChainCtrl.getAjrId());
            }
            AutomatedJobResultsHandler.setJobType(jobName);
            String report = buildPostExecutionReport();
            sendEmail(report);
            if (String.isNotBlank(batchChainCtrl.getAjrId())) {
                AutomatedJobResultsHandler.updateAutomatedJobResults();
            }
        }
    }

    public static void executeBatchChain(SourceRecordPostBatchChainController chainCon, List<ScheduledPostExecutionReport> executionReports) {
        if (chainCon.hasLDVTypes()) {
            Set<SourceRecordType> ldvTypes = new Set<AbstractSourceRecordPostBatch.SourceRecordType>();
            for (SourceRecordType ldvType : chainCon.currentLdv()) {
                ldvTypes.add(ldvType);
            }
            if (!ldvTypes.isEmpty()) {
                executeLDVBatch(new List<SourceRecordType>(ldvTypes)[0], ldvTypes);
            }
            chainCon.clearLDVTypes();
        }

        try {
            SourceRecordType recordType = chainCon.current();
            switch on recordType {
                when BILLING {
                    Database.executeBatch(new BillingPostBatch(chainCon, executionReports), SPECIAL_BATCH_CHUNK_SIZE);
                }
                when CASH_RECEIPT {
                    Database.executeBatch(new CashReceiptPostBatch(chainCon, executionReports), COMMON_BATCH_CHUNK_SIZE);
                }
                when BILLING_CASH_RECEIPT {
                    Database.executeBatch(new BillingCashReceiptPostBatch(chainCon, executionReports), SPECIAL_BATCH_CHUNK_SIZE);
                }
                when PAYABLE {
                    Database.executeBatch(new PayablePostBatch(chainCon, executionReports), SPECIAL_BATCH_CHUNK_SIZE);
                }
                when CASH_DISBURSEMENT {
                    Database.executeBatch(new CashDisbursementPostBatch(chainCon, executionReports), COMMON_BATCH_CHUNK_SIZE);
                }
                when AP_DISBURSEMENT {
                    Database.executeBatch(new APDisbursementPostBatch(chainCon, executionReports), SPECIAL_BATCH_CHUNK_SIZE);
                }
                when TIME_CARD {
                    Database.executeBatch(new TimeCardPostBatch(chainCon, executionReports), COMMON_BATCH_CHUNK_SIZE);
                }
                when JOURNAL_ENTRY {
                    Database.executeBatch(new JournalEntryPostBatch(chainCon, executionReports), SPECIAL_BATCH_CHUNK_SIZE);
                }
                when AMORTIZATION {
                    Database.executeBatch(new AmortizationPostBatch(chainCon, executionReports), COMMON_BATCH_CHUNK_SIZE);
                }
                when else {
                    FinancialSuiteService.executeInventoryMovementsPostBatchChain(chainCon.getERPTypes(), executionReports);
                }
            }
        } catch (Exception ex) {}
    }

    public static void executeLDVBatch(SourceRecordType ldvType, Set<SourceRecordType> ldvTypes) {
        String batchName = BATCHES_BY_SOBJECT_TYPES.get(ldvType);
        SourceDocumentBatchBase batchBase = ((SourceDocumentBatchBase) Type.forName(batchName)?.newInstance())
                .isScheduledPostJob(true)
                .currentSourceRecordType(ldvType)
                .schedSourceRecordTypes(ldvTypes);
        Database.executeBatch(
            batchBase,
            ldvType == SourceRecordType.BILLING ? PostProcessor.BATCH_CHUNK_SIZE_WITH_API_CALLOUT : PostProcessor.BATCH_CHUNK_SIZE
        );
    }

    protected void doPostAndReport(AbstractPostHandler postHandler, List<SObject> scope) {
        if (dispatcher.getExecutionContext() == PostResultDispatcher.ExecutionContext.UNPOST) {
            postHandler.unpost(scope);
        }
        else {
            postHandler.post(scope);
        }
        //Check posting results and create task records if needed
        logOnActivity(postHandler.dispatcher);
        dispatcher.mergeWith(postHandler.dispatcher);
    }

    protected void logOnActivity(PostResultDispatcher dispatcher) {
        List<Task> tasks = new List<Task>();
        for (PostResult postResult : dispatcher.getPostResults()) {
            if (!postResult.isSuccess) {
                tasks.add(
                    FinancialSuiteUtils.setTask(
                        postResult.id,
                        'Completed',
                        null,
                        (this.dispatcher.getExecutionContext() == PostResultDispatcher.ExecutionContext.UNPOST
                            ? Label.ERR_CANNOT_UNPOST_RECORD
                            : Label.COMMON_ERR_CANNOT_POST_RECORD),
                        postResult.errors.get(0).message,
                        null,
                        batchChainCtrl.getAjrId()
                    )
                );
            }
        }

        if (!tasks.isEmpty()) {
            SFDCSecurityUtils.insertProxy(tasks);
        }
    }

    private void sendEmail(String report) {
        sendEmail(report, jobName);
    }

    public static void sendEmail(String report, String jobName) {
        if (!AccountingSettingsHandler.isEmailConfirmationsDisabled() && !Test.isRunningTest() && FinancialSuiteUtils.canSendEmail()) {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            List<String> toAddresses = new List<String>{UserInfo.getUserEmail()};
            mail.setToAddresses(toAddresses);
            mail.setSenderDisplayName(Label.COMMON_ACCOUNTING_SEED);
            mail.setSubject(Label.COMMON_ACCOUNTING_SEED + ': ' + Label.COMMON_YOUR + ' ' + jobName + ' ' + Label.COMMON_HAS_BEEN_COMPLETED);

            mail.setPlainTextBody(jobName + ' ' + Label.COMMON_DETAILS + report);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail});
        }
    }

    private String buildPostExecutionReport() {
        String result = '';
        for (ScheduledPostExecutionReport report : executionReports) {
            String reportsProcessed = String.format(Label.ERR_AUTOMATED_JOB_RESULT_PROCESSED, new List<Object>{report.objName, report.total});
            String reportsFailed = String.format(Label.ERR_AUTOMATED_JOB_RESULT_FAILED, new List<Object>{report.objName, report.failed});
            result += report.getReport(jobTypeName);
            AutomatedJobResultsHandler.addProcessed(report.total);
            Integer succeeded = report.total - report.failed;
            AutomatedJobResultsHandler.addSucceeded(succeeded);
            AutomatedJobResultsHandler.addFailed(report.failed);
            AutomatedJobResultsHandler.setError(reportsProcessed);
            AutomatedJobResultsHandler.setError(
                Label.COMMON_NUMBER_OF + ' ' + report.objName + ' ' +
                    (this.dispatcher.getExecutionContext() == PostResultDispatcher.ExecutionContext.UNPOST ? Label.COMMON_UNPOSTED : Label.COMMON_SMALL_POSTED) + ' ' + Label.COMMON_SUCCESSFULLY
                +': ' + succeeded
            );
            AutomatedJobResultsHandler.setError(reportsFailed);
            AutomatedJobResultsHandler.setError(AutomatedJobResultsHandler.getReportLink(jobName + report.objName));
        }
        return result;
    }

    public class ScheduledPostExecutionReport {
        final String objName;
        final Integer total;
        final Integer failed;

        public ScheduledPostExecutionReport(String objName, Integer total, Integer failed) {
            this.objName = objName;
            this.total = total;
            this.failed = failed;
        }

        public String getReport(String jobTypeName) {
            return AbstractSourceRecordPostBatch.buildExecutionReport(jobTypeName, objName, total, failed);
        }
    }

    public static String buildExecutionReport(String jobTypeName, String objName, Integer total, Integer failed) {
        return '\n\n' + objName + ' ' + jobTypeName + ' ' + Label.COMMON_SMALL_RESULTS + ' :\n\n' + Label.COMMON_RECORDS_PROCESSED + ': ' + total + '\n' + Label.COMMON_RECORDS_FAILED + ': ' + failed;
    }
}