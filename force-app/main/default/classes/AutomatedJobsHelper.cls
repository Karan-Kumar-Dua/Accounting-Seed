public with sharing class AutomatedJobsHelper {
//labels
    private static final Set<String> APEX_JOB_IN_PROGRESS_STATUSES = GlobalVariables.APEX_JOB_STATUSES;
    private static final Set<String> AUTO_POST_BATCH_CLASSES = new Set<String>{
        'BillingPostBatch',
        'BillingCashReceiptPostBatch',
        'CashReceiptPostBatch',
        'PayablePostBatch',
        'CashDisbursementPostBatch',
        'APDisbursementPostBatch',
        'TimeCardPostBatch',
        'JournalEntryPostBatch',
        'AmortizationPostBatch',
        'InboundInventoryMovementPostBatch',
        'OutboundInventoryMovementPostBatch',
        'ManufacturingInvMovementPostBatch',
        'PurchaseOrderInventoryPostBatch',
        'SalesOrderInventoryMovementPostBatch',
        'PaymentProposalBatch'
    };
    private static final String AJR_RETENTION_SCHEDULER_CLASS = 'AutomatedJobResultsRetentionScheduler';

    private static final String CRON_TEMPLATE = '0 0 {0} * * ?';
    private static final String CRON_AJR_RETENTION = '0 0 0 * * ?';

    @TestVisible
    private static final String RUNNING_POSTING_JOB_WARNING = Label.WRN_RUNNING_POSTING_JOB;
    @TestVisible
    private static final String RUNNING_POSTING_JOB_CONFIRM = Label.INF_AUTOMATED_JOBS_SCHEDULED_POST;
    @TestVisible
    private static final String RUNNING_TRANSACTION_IMPORT_JOB_CONFIRM = Label.INF_AUTOMATED_JOBS_SCHEDULED_BANK_DL;
    @TestVisible
    private static final String RUNNING_FT_POSTING_JOB_CONFIRM = Label.INF_AUTOMATED_JOBS_NPSP;
    @TestVisible
    private static final String JOB_NOT_FOUND_ERROR = Label.COMMON_ERR_JOB_NOT_FOUND;

    @TestVisible
    private static final String JOB_RECUR_BILLINGS = 'Recurring Billing Job';
    @TestVisible
    private static final String JOB_RECUR_PAYABLES = 'Recurring Payable Job';
    @TestVisible
    private static final String JOB_RECUR_JOURNAL_ENTRIES = 'Recurring Journal Entry Job';
    @TestVisible
    private static final String JOB_EMAIL_BILLING = 'Automated Email Billing Job';
    @TestVisible
    private static final String JOB_POST = 'Scheduled Post';
    @TestVisible
    private static final String JOB_BANK_DOWNLOAD = 'Scheduled Bank Download Job';
    @TestVisible
    private static final String JOB_RECUR_PERIOD_TASK = 'Recurring Period Task Job';
    @TestVisible
    private static final String JOB_NPSP_JOURNAL_ENTRIES = 'NPSP Opportunity Journal Entries Job';
    @TestVisible
    private static final String JOB_AJR_RETENTION = 'AJR Retention Job';

    @AuraEnabled
    public static String run(String jobName, List<String> schdPostTypes) {
        try {
            String msg;
            if (isAutoPostBatchJobRunning()) {
                throw new AutomatedJobsHelperException(Label.WRN_RUNNING_POSTING_JOB);
            }
            else if (Label.JOB_POST == jobName) {
                new AutomatedSourceRecordPostScheduler(new SourceRecordPostBatchChainController(schdPostTypes)).execute(null);
                msg = Label.INF_AUTOMATED_JOBS_SCHEDULED_POST;
            }
            else if (Label.JOB_BANK_DOWNLOAD == jobName) {
                try {
                    BDCService service = new BDCService();
                    service.getAllTransactionsBulk();
                    msg = RUNNING_TRANSACTION_IMPORT_JOB_CONFIRM;
                }
                catch (BDCService.BDCException ex) {
                    msg = ex.getMessage();
                }
            }
            else if (Label.JOB_NPSP_JOURNAL_ENTRIES == jobName) {
                new TrackFinancialTransactionsScheduler().execute(null);
                msg = Label.INF_AUTOMATED_JOBS_NPSP;
            }
            else if (Label.JOB_PAYMENT_ACTIVITY == jobName) {
                new PaymentActivityACHStatusScheduler().execute(null);
                msg = Label.INF_PAYMENT_ACTIVITY_JOB_RUNNING;
            }
            else if (Label.JOB_JOURNAL_ENTRIES == jobName) {
                new CxSettlementScheduler().execute(null);
                msg = Label.INF_JOURNAL_ENTRY_JOB_RUNNING;
            }
            else if (Label.JOB_PAYMENT_PROPOSAL == jobName) {
                new PaymentProposalScheduler().execute(null);
                msg = Label.INF_PAYMENT_PROPOSAL_BATCH_JOB_RUNNING;
            }
            else {
                throw new AutomatedJobsHelperException(Label.COMMON_ERR_JOB_NOT_FOUND);
            }
            return msg;
        }
        catch (AutomatedJobsHelperException ex) {
            throw ex;
        }
        catch (Exception ex) {
            throw new AutomatedJobsHelperException(ex.getMessage());
        }
    }

    @AuraEnabled
    public static void schedule(String jobName, String startTime, List<String> schdPostTypes) {
        try {
            stopAndRemoveJob(jobName);
            String cronExp = String.format(CRON_TEMPLATE, new String[]{startTime});
            if (Label.JOB_RECUR_BILLINGS == jobName) {
                RecurringBillingSchedulableBatch.startRecurringBillingSchedulableBatch(cronExp, jobName);
            }
            else if (Label.JOB_RECUR_PAYABLES == jobName) {
                RecurringPayableSchedulableBatch.startRecurringPayableSchedulableBatch(cronExp, jobName);
            }
            else if (Label.JOB_RECUR_JOURNAL_ENTRIES == jobName) {
                RecurringJournalEntrySchedulableBatch.startRecurringJournalEntrySchedulableBatch(cronExp, jobName);
            }
            else if (Label.JOB_EMAIL_BILLING == jobName) {
                // assign '/apex/' as base url so it can be resolved later in async context
                AutomatedEmailBillingScheduler.startAutomatedEmailBillingScheduler(
                    cronExp, jobName, GlobalVariables.APEX_URL_PATH
                );
            }
            else if (Label.JOB_POST == jobName) {
                AutomatedSourceRecordPostScheduler.startAutomatedSourceRecordPostScheduler(cronExp, schdPostTypes);
            }
            else if (Label.JOB_NPSP_JOURNAL_ENTRIES == jobName) {
                TrackFinancialTransactionsScheduler.startTrackFinancialTransactionsScheduler(cronExp, jobName);
            }
            else if (Label.JOB_BANK_DOWNLOAD == jobName) {
                BankTransactionsDownloadScheduler.startBankTransactionsDownloadScheduler(cronExp, jobName);
            }
            else if (Label.JOB_RECUR_PERIOD_TASK == jobName) {
                RecurringPeriodTaskSchedulableBatch.startRecurringPeriodTaskSchedulableBatch(cronExp, jobName);	
            }
            else if (Label.JOB_PAYMENT_ACTIVITY == jobName) {
                PaymentActivityACHStatusScheduler.startPaymentActivityACHStatusScheduler(cronExp, jobName);
            }
            else if (Label.JOB_PAYMENT_PROPOSAL == jobName) {
                PaymentProposalScheduler.startPaymentProposalScheduler(cronExp, jobName);
            }
            else if (Label.JOB_JOURNAL_ENTRIES == jobName) {
                CxSettlementScheduler.startCxSettlementScheduler(cronExp, jobName);
            }
            checkAJRRetentionPeriodJob();
        }
        catch (AutomatedJobsHelperException ex) {
            throw ex;
        }
        catch (Exception ex) {
            throw new AutomatedJobsHelperException(ex.getMessage());
        }
    }

    @AuraEnabled
    public static void remove(Id jobId){
        try {
            System.abortJob(jobId);
        } 
        catch (AutomatedJobsHelperException ex) {
            throw ex;
        }
        catch (Exception ex) {
            throw new AutomatedJobsHelperException(ex.getMessage());
        }
    }

    @AuraEnabled(Cacheable=true)
    public static List<ScheduledJobDescription> getAvailableJobs() {
        try {
            return getJobDescriptions();
        }
        catch (AutomatedJobsHelperException ex) {
            throw ex;
        }
        catch (Exception ex) {
            throw new AutomatedJobsHelperException(ex.getMessage());
        }
    }

    @AuraEnabled
    public static List<ScheduledJobWrapper> getSchedule() {
        try {
            List<ScheduledJobWrapper> jobs = new List<ScheduledJobWrapper>();
            for (CronTrigger ct : DomainUtils.getCronTriggerByJobName(getJobNames())) {
                jobs.add(new ScheduledJobWrapper(ct));
            }
            for (CronTrigger ct : DomainUtils.getCronTriggerByJobNamePrefix(Label.JOB_POST)) {
                jobs.add(new ScheduledJobWrapper(ct));
            }
            jobs.sort();
            return jobs;
        }
        catch (AutomatedJobsHelperException ex) {
            throw ex;
        }
        catch (Exception ex) {
            throw new AutomatedJobsHelperException(ex.getMessage());
        }
    }

    private static List<ScheduledJobDescription> getJobDescriptions() {
        // Base jobs
        List<ScheduledJobDescription> descriptions = new List<ScheduledJobDescription> {
            // label, value, onDemand, scheduled
            new ScheduledJobDescription('Recurring Billing', Label.JOB_RECUR_BILLINGS, false, true),
            new ScheduledJobDescription('Recurring Payable', Label.JOB_RECUR_PAYABLES, false, true),
            new ScheduledJobDescription('Recurring Journal Entry', Label.JOB_RECUR_JOURNAL_ENTRIES, false, true),
            new ScheduledJobDescription('Automated Email Billing', Label.JOB_EMAIL_BILLING, false, true),
            new ScheduledJobDescription('Scheduled Post', Label.JOB_POST, true, true),
            new ScheduledJobDescription('Scheduled Bank Download', Label.JOB_BANK_DOWNLOAD, true, true),
            new ScheduledJobDescription('Recurring Period Task', Label.JOB_RECUR_PERIOD_TASK, false, true),
            new ScheduledJobDescription('Payment Activity Status', Label.JOB_PAYMENT_ACTIVITY, true, true),
            new ScheduledJobDescription(Label.JOB_JOURNAL_ENTRIES, Label.JOB_JOURNAL_ENTRIES, true, true),
            new ScheduledJobDescription(Label.JOB_PAYMENT_PROPOSAL, Label.JOB_PAYMENT_PROPOSAL, true, true)
        };

        // NPSP jobs
        if (AccountingSettingsHandler.isNPSPEnabled()) {
            // label, value, onDemand, scheduled
            descriptions.add(
                new ScheduledJobDescription('NPSP Opp Journal Entries', Label.JOB_NPSP_JOURNAL_ENTRIES, true, true)
            );
        }

        return descriptions;
    }

    @TestVisible
    private static Set<String> getJobNames() {
        Set<String> names = new Set<String>();
        for (ScheduledJobDescription description : getJobDescriptions()) {
            names.add(description.value);
        }
        return names;
    }

    private static Boolean isAutoPostBatchJobRunning() {
        List<AsyncApexJob> jobsInProcess = DomainUtils.getAsyncApexJobByApexClassNameAndStatus(
            AUTO_POST_BATCH_CLASSES, APEX_JOB_IN_PROGRESS_STATUSES
        );
        return !jobsInProcess.isEmpty();
    }

    private static void stopAndRemoveJob(String jobName) {
        for (ScheduledJobWrapper job : getSchedule()) {
            if (job.jobType == jobName) {
                remove(job.jobId);
            }
        }
    }

    private static void checkAJRRetentionPeriodJob() {
        List<AsyncApexJob> apexJobInAction = DomainUtils.getAsyncApexJobByApexClassNameAndStatus(
            new Set<String> {AJR_RETENTION_SCHEDULER_CLASS}, APEX_JOB_IN_PROGRESS_STATUSES
        );
        List<CronTrigger> crons = DomainUtils.getCronTriggerByJobName(new Set<String>{ Label.JOB_AJR_RETENTION });
        if (AccountingSettingsHandler.isEnableRetentionPeriod() && apexJobInAction.isEmpty() && crons.isEmpty()) {
            AutomatedJobResultsRetentionScheduler.startAutomatedJobResultsRetentionScheduler(CRON_AJR_RETENTION, Label.JOB_AJR_RETENTION);
        }
    }

    public with sharing class ScheduledJobDescription {
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String value;
        @AuraEnabled
        public Boolean onDemand;
        @AuraEnabled
        public Boolean scheduled;

        public ScheduledJobDescription(String label, String value, Boolean onDemand, Boolean scheduled) {
            this.label = label;
            this.value = value;
            this.onDemand = onDemand;
            this.scheduled = scheduled;
        }
    }

    public with sharing class ScheduledJobWrapper implements Comparable {
        @AuraEnabled
        public Id jobId;
        @AuraEnabled
        public String jobType;
        @AuraEnabled
        public String startDate;
        @AuraEnabled
        public String nextRunDate;
        @AuraEnabled
        public String preferredStartTime;

        private CronTrigger ct;

        public ScheduledJobWrapper(CronTrigger ct) {
            if (ct != null) {
                this.ct = ct;
                this.jobId = ct.Id;
                this.jobType = ct.CronJobDetail?.Name;
                this.startDate = ct?.StartTime.date().format();
                this.nextRunDate = ct?.NextFireTime.date().format();
                this.preferredStartTime = ct?.NextFireTime.format().substringAfter(' ');
            }
        }

        public Integer compareTo(Object jobWrapper) {
            ScheduledJobWrapper that = (ScheduledJobWrapper) jobWrapper;
            if (this.ct.NextFireTime.hour() == that.ct.NextFireTime.hour()) { return 0; } 
            if (this.ct.NextFireTime.hour() > that.ct.NextFireTime.hour()) { return 1; }
            return -1;        
        }
    }

    public with sharing class AutomatedJobsHelperException extends Exception{}

}