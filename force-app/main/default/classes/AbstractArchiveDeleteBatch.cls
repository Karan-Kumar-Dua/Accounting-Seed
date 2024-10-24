public with sharing abstract class AbstractArchiveDeleteBatch implements Database.Batchable<sObject>, Database.Stateful {

    public static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static final Integer COMMON_BATCH_CHUNK_SIZE = 100;
    private Boolean isPreviousPeriodGap = false;
    protected String jobName = 'Delete Source Documents Job';
    protected String postingStatus = AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED;
    protected String currentPeriodName;
    protected String query;
    protected Accounting_Period__c currentPeriod;
    protected List<Accounting_Period__c> previousPeriods = new List<Accounting_Period__c>();
    protected Set<Id> periodIds = new Set<Id>();
    protected List<ArchiveDeleteExecutionReport> executionReports = new List<ArchiveDeleteExecutionReport>();
    protected ArchiveDeleteChainController chainCtrl;
    protected Date startDate;
    protected Date endDate;
    protected Integer currentExecutionTotal = 0;
    protected Integer currentExecutionFailed = 0;
    protected Map<String,String> reportNameBySource = new Map<String,String>{
                                'UNCLEARED_BANK_RECONCILIATION' => 'Uncleared Bank Rec Deletion',
                                'BANK_RECONCILIATION' => 'Bank Rec Deletion Job',
                                'BANK_DEPOSIT' => 'Bank Deposits Deletion Job',
                                'BILLING_CASH_RECEIPT' => 'BCR Deletion Job',
                                'AP_DISBURSEMENT' => 'AP Disbursements Deletion',
                                'BILLING_CREDIT_MEMO' => 'Billing Credit Memos Del Job',
                                'CASH_RECEIPT' => 'Cash Receipts\' Deletion Job',
                                'AP_CREDIT_MEMO' => 'AP Credit Memos Deletion Job',
                                'CASH_DISBURSEMENT' => 'Cash Disbursements Deletion',
                                'AMORTIZATION_ENTRY' => 'Amort Entries Deletion Job',
                                'BILLING_LINE' => 'Billing Lines Deletion Job',
                                'BILLING_AGING_HISTORY' => 'Billing AH Del Job',
                                'BILLING' => 'Billings Deletion Job',
                                'PAYABLE_LINE' => 'Payable Lines Deletion Job',
                                'PAYABLE_AGING_HISTORY' => 'AP Aging History Delete Job',
                                'PAYABLE' => 'Payables Deletion Job',
                                'JOURNAL_ENTRY_LINE' => 'JE Line Deletion Job',
                                'JOURNAL_ENTRY' => 'Journal Entries Deletion Job',
                                'BANK_TRANSACTION' => 'Bank Transactions Delete Job'
    };

    public enum SourceRecordType {
        UNCLEARED_BANK_RECONCILIATION,
        BANK_RECONCILIATION,
        BANK_DEPOSIT,
        BILLING_CASH_RECEIPT,
        AP_DISBURSEMENT,
        BILLING_CREDIT_MEMO,
        AP_CREDIT_MEMO,
        CASH_RECEIPT,
        CASH_DISBURSEMENT,
        AMORTIZATION_ENTRY, 
        BILLING_LINE,
        BILLING_AGING_HISTORY,
        BILLING,
        PAYABLE_LINE,
        PAYABLE_AGING_HISTORY,
        PAYABLE,
        JOURNAL_ENTRY_LINE,
        JOURNAL_ENTRY,
        BANK_TRANSACTION
    }

    public abstract Database.QueryLocator start(Database.BatchableContext bc);

    public void init(ArchiveDeleteChainController chainCon, List<ArchiveDeleteExecutionReport> priorExecReports) {
        currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodById(chainCon.periodId);
        getPreviousPeriods(currentPeriod);
        currentPeriodName = currentPeriod.Name;
        startDate = previousPeriods.isEmpty() || isPreviousPeriodGap ? currentPeriod.Start_Date__c : getStartDate();
        endDate =  currentPeriod.End_Date__c;
        chainCtrl = chainCon;
        if (priorExecReports != null && !priorExecReports.isEmpty()) {
            executionReports.addAll(priorExecReports);
        }
    }

    private void getPreviousPeriods(Accounting_Period__c period) {
        List<Accounting_Period__c> selectedPeriods = AccountingPeriodHandler.getInstance()
            .getPreviousAccountingPeriods(period, new Set<String> {AccountingPeriodActions.ARCHIVED_STATUS}, false);
        for (Accounting_Period__c selectedPeriod : selectedPeriods) {
            if (selectedPeriod.Source_Docs_Deleted__c) {
                periodIds.add(selectedPeriod.Id);
                previousPeriods.add(selectedPeriod);
            }
        }
        isPreviousPeriodGap = previousPeriods.size() != selectedPeriods.size();
        periodIds.add(currentPeriod.Id);
    }

    private Date getStartDate() {
        return previousPeriods.size() > 12 ? previousPeriods[previousPeriods.size() - 11].Start_Date__c : previousPeriods[0].Start_Date__c;
    }

    public void execute(Database.BatchableContext context, List<SObject> scope) {
        List<DeleteResultWrapper> failedDeleteResults = new List<DeleteResultWrapper>();
        AccountingPeriodActions.isDelarcInProgress = true;
        if (scope[0].getSObjectType() == AP_Disbursement__c.SObjectType) {
            TriggerObserver.bypassDeleteApDisbursement = true;
        }
        for (Database.DeleteResult dr : Database.delete(scope, false)) {
            currentExecutionTotal ++;
            if (!dr.isSuccess()) {
                currentExecutionFailed ++;
                failedDeleteResults.add(new DeleteResultWrapper(dr));
            }
        }
        AccountingPeriodActions.isDelarcInProgress = false;
        if (scope[0].getSObjectType() == AP_Disbursement__c.SObjectType) {
            TriggerObserver.bypassDeleteApDisbursement = false;
        }

        if (!failedDeleteResults.isEmpty()) {
            logOnActivity(String.valueOf(chainCtrl.current()), failedDeleteResults);
        }
    }

    public void finish(Database.BatchableContext bc) {
        //add Execution Reports
        ArchiveDeleteExecutionReport report = new ArchiveDeleteExecutionReport(
            String.valueOf(chainCtrl.current()),
            currentExecutionTotal,
            currentExecutionFailed
        );
        executionReports.add(report);

        //run next batch job in chain if it is not completed yet
        if (chainCtrl.hasNext()) {
            chainCtrl.next();
            executeBatchChain(chainCtrl, executionReports);
        }
        else {
            AutomatedJobResultsHandler.setJobType(jobName);
            buildPostExecutionReport();
            sendEmail();
            AutomatedJobResultsHandler.saveAutomatedJobResults();
        }

    }

    private void sendEmail() {
        if (!AccountingSettingsHandler.isEmailConfirmationsDisabled() && !Test.isRunningTest() && FinancialSuiteUtils.canSendEmail()) {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            List<String> toAddresses = new List<String>{UserInfo.getUserEmail()};
            mail.setToAddresses(toAddresses);
            mail.setSenderDisplayName(Label.COMMON_ACCOUNTING_SEED);
            mail.setSubject(Label.COMMON_ACCOUNTING_SEED + ': ' + Label.COMMON_YOUR + ' ' + jobName + ' '+ Label.COMMON_FOR + ' ' + currentPeriodName + ' ' + Label.COMMON_HAS_BEEN_COMPLETED);

            mail.setPlainTextBody(Label.INF_YOUR_DELETE_SOURCE_DOCUMENTS_JOB_FOR + ' ' + currentPeriodName + ' '+ Label.COMMON_HAS_BEEN_COMPLETED +'. '+ Label.INF_REVIEW_AUTOMATED_JOB_RESULTS);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail});
        }
    }

    private void buildPostExecutionReport() {
        for (ArchiveDeleteExecutionReport report : executionReports) {
            AutomatedJobResultsHandler.addProcessed(report.total);
            Integer succeeded = report.total - report.failed;
            String formatObjName =  report.objName.toLowerCase().replace('_', ' ');
            String PROCESSED_DELETED = String.format(Label.ERR_AUTOMATED_JOB_RESULT_DELETE_PROCESSED, new List<Object>{formatObjName, report.total});
            String SUCCESSFULLY_DELETED = String.format(Label.ERR_AUTOMATED_JOB_RESULT_DELETE_SUCCEEDED, new List<Object>{formatObjName, succeeded});
            String FAILED_DELETED = String.format(Label.ERR_AUTOMATED_JOB_RESULT_DELETE_FAILED, new List<Object>{formatObjName, report.failed});
            AutomatedJobResultsHandler.addSucceeded(succeeded);
            AutomatedJobResultsHandler.addFailed(report.failed);
            
            AutomatedJobResultsHandler.setError(PROCESSED_DELETED);
            AutomatedJobResultsHandler.setError(SUCCESSFULLY_DELETED);
            AutomatedJobResultsHandler.setError(FAILED_DELETED);
            AutomatedJobResultsHandler.setError(AutomatedJobResultsHandler.getReportLink(reportNameBySource.get(report.objName)));
        }
    }

    protected void logOnActivity(String objName, List<DeleteResultWrapper> failedDeleteResults) {
        List<Task> tasks = new List<Task>();
        String formatObjName =  objName.toLowerCase().replace('_', ' ');
        for (DeleteResultWrapper dr : failedDeleteResults) {
            tasks.add(
                FinancialSuiteUtils.setTask(
                    dr.recordId,
                    'Completed',
                    NULL,
                    String.format(Label.ERROR_COULD_NOT_DELETE_RECORD, new List<String>{formatObjName}),
                    dr.errorMsg,
                    NULL
                )
            );
        }

        if (!tasks.isEmpty()) {
            SFDCSecurityUtils.insertProxy(tasks);
        }
    }

    public static void executeBatchChain(ArchiveDeleteChainController chainCon, List<ArchiveDeleteExecutionReport> executionReports) {
        SourceRecordType recordType = chainCon.current();
        switch on recordType {
            when UNCLEARED_BANK_RECONCILIATION {
                Database.executeBatch(new UBReconLineArchiveDeleteBatch(chainCon, executionReports), COMMON_BATCH_CHUNK_SIZE);
            }
            when BANK_RECONCILIATION {
                Database.executeBatch(new BankReconciliationArchiveDeleteBatch(chainCon, executionReports), COMMON_BATCH_CHUNK_SIZE);
            }
            when BANK_DEPOSIT {
                Database.executeBatch(new BankDepositArchiveDeleteBatch(chainCon, executionReports), COMMON_BATCH_CHUNK_SIZE);
            }
            when BILLING_CASH_RECEIPT {
                Database.executeBatch(new BillingCashReceiptArchiveDeleteBatch(chainCon, executionReports), COMMON_BATCH_CHUNK_SIZE);
            }
            when AP_DISBURSEMENT {
                Database.executeBatch(new APDisbursementArchiveDeleteBatch(chainCon, executionReports), COMMON_BATCH_CHUNK_SIZE);
            }
            when BILLING_CREDIT_MEMO {
                Database.executeBatch(new BillingCreditMemoArchiveDeleteBatch(chainCon, executionReports), COMMON_BATCH_CHUNK_SIZE);
            }
            when AP_CREDIT_MEMO {
                Database.executeBatch(new APCreditMemoArchiveDeleteBatch(chainCon, executionReports), COMMON_BATCH_CHUNK_SIZE);
            }
            when CASH_RECEIPT {
                Database.executeBatch(new CashReceiptArchiveDeleteBatch(chainCon, executionReports), COMMON_BATCH_CHUNK_SIZE);
            }
            when CASH_DISBURSEMENT {
                Database.executeBatch(new CashDisbursementArchiveDeleteBatch(chainCon, executionReports), COMMON_BATCH_CHUNK_SIZE);
            }
            when BILLING_LINE {
                Database.executeBatch(new BillingLineArchiveDeleteBatch(chainCon, executionReports), COMMON_BATCH_CHUNK_SIZE);
            }
            when BILLING_AGING_HISTORY {
                Database.executeBatch(new BillingAgingHistoryArchiveDeleteBatch(chainCon, executionReports), COMMON_BATCH_CHUNK_SIZE);
            }
            when BILLING {
                Database.executeBatch(new BillingsArchiveDeleteBatch(chainCon, executionReports), COMMON_BATCH_CHUNK_SIZE);
            }
            when PAYABLE_LINE {
                Database.executeBatch(new PayableLineArchiveDeleteBatch(chainCon, executionReports), COMMON_BATCH_CHUNK_SIZE);
            }
            when PAYABLE_AGING_HISTORY {
                Database.executeBatch(new APAgingHistoryArchiveDeleteBatch(chainCon, executionReports), COMMON_BATCH_CHUNK_SIZE);
            }
            when PAYABLE {
                Database.executeBatch(new PayableArchiveDeleteBatch(chainCon, executionReports), COMMON_BATCH_CHUNK_SIZE);
            }
            when JOURNAL_ENTRY_LINE {
                Database.executeBatch(new JournalEntryLineArchiveDeleteBatch(chainCon, executionReports), COMMON_BATCH_CHUNK_SIZE);
            }
            when JOURNAL_ENTRY {
                Database.executeBatch(new JournalEntryArchiveDeleteBatch(chainCon, executionReports), COMMON_BATCH_CHUNK_SIZE);
            }
            when BANK_TRANSACTION {
                Database.executeBatch(new BankTransactionArchiveDeleteBatch(chainCon, executionReports), COMMON_BATCH_CHUNK_SIZE);
            }
            when AMORTIZATION_ENTRY {
                Database.executeBatch(new AmortizationEntryArchiveDeleteBatch(chainCon, executionReports), COMMON_BATCH_CHUNK_SIZE);
            }
        }
    }

    public with sharing class ArchiveDeleteChainController {
        public Id periodId;
        public Integer currentIndex = 0;

        public ArchiveDeleteChainController(Id periodId) {
            this.periodId = periodId;
        }

        public Boolean hasNext() {
            return currentIndex < AbstractArchiveDeleteBatch.SourceRecordType.values().size() - 1;
        }

        public AbstractArchiveDeleteBatch.SourceRecordType next() {
            currentIndex++;
            return AbstractArchiveDeleteBatch.SourceRecordType.values()[currentIndex];
        }

        public AbstractArchiveDeleteBatch.SourceRecordType current() {
            return AbstractArchiveDeleteBatch.SourceRecordType.values()[currentIndex];
        }

    }

    public with sharing class ArchiveDeleteExecutionReport {
        String objName;
        Integer total;
        Integer failed;

        public ArchiveDeleteExecutionReport(String objName, Integer total, Integer failed) {
            this.objName = objName;
            this.total = total;
            this.failed = failed;
        }
    }

    public with sharing class DeleteResultWrapper {
        Boolean isSuccess;
        Id recordId;
        String errorMsg;

        public DeleteResultWrapper(Database.DeleteResult dr) {
            this.isSuccess = dr.isSuccess();
            this.recordId = dr.getId();
            this.errorMsg = !dr.isSuccess() ? dr.getErrors()[0].getMessage() : '';
        }
    }

}