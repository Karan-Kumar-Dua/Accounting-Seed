public with sharing abstract class AbstractRecurringSchedulableBatch implements Database.Batchable<sObject>, Database.Stateful, Schedulable {

    public static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final Integer BATCH_CHUNK_SIZE = 1;
    protected String query;
    protected String jobName;
    protected Integer processedRecords = 0;
    protected Integer succeededRecords = 0;
    protected Integer failedRecords = 0;
    protected List<Task> tasks = new List<Task>();
    private User recipientUser;
    private String objectName;
    private Id ajrId;

    protected void setQuery(String query) {
        this.query = query;
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        Date today = System.today();
        //create AJR record in advance to populate its ID on all created Tasks
        AutomatedJobResultsHandler.setJobType(jobName);
        this.ajrId = AutomatedJobResultsHandler.saveAutomatedJobResults();
        return DomainUtils.getQueryLocator(query, today);
    }

    public abstract void execute(Database.BatchableContext BC, List<SObject> scope);
    public abstract void execute(SchedulableContext sc);

    public void finish(Database.BatchableContext BC) {
        addAutomatedJobResults();
        getRecipientUser();
        sendEmail();
        if (!tasks.isEmpty()) {
            SFDCSecurityUtils.insertProxy(tasks);
        }
    }

    protected void handleErrors(List<AbstractSourceFromRecurring.RecurringRecordResult> results) {
        objectName = results[0].objectName;
        String recurringObjectCreationError = String.format(Label.ERR_CREATING_RECURRING_OBJECT, new List<Object>{objectName});
        for (AbstractSourceFromRecurring.RecurringRecordResult res : results) {
            processedRecords += res.totalRecords;
            succeededRecords += res.getSuccessRecordsCount();
            failedRecords += res.getFailedRecordsCount();

            for (AbstractSourceFromRecurring.RecurringRecordErrorResult err : res.getFailedRecords()) {
                tasks.add(
                    FinancialSuiteUtils.setTask(
                        res.recurringRecordId,
                        'Completed',
                        'Normal',
                        recurringObjectCreationError,
                        err.message,
                        recipientUser != NULL ? recipientUser.Id : UserInfo.getUserId(),
                        this.ajrId
                    )
                );
            }
        }

    }

    protected virtual String buildNote() {
        return AutomatedJobResultsHandler.getReportLink(jobName);
    }

    private void addAutomatedJobResults() {
        if (String.isNotBlank(this.ajrId)) {
            AutomatedJobResultsHandler.presetJobResultRecord(this.ajrId);
        }
        AutomatedJobResultsHandler.setJobType(jobName);
        AutomatedJobResultsHandler.setProcessed(processedRecords);
        AutomatedJobResultsHandler.setSucceeded(succeededRecords);
        AutomatedJobResultsHandler.setFailed(failedRecords);
        AutomatedJobResultsHandler.setError(buildNote());
        if (String.isNotBlank(this.ajrId)) {
            AutomatedJobResultsHandler.updateAutomatedJobResults();
        }
    }

    private void sendEmail() {
        if (!AccountingSettingsHandler.isEmailConfirmationsDisabled() && !Test.isRunningTest() && FinancialSuiteUtils.canSendEmail()) {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            List<String> toAddresses = new List<String>{recipientUser != NULL ? recipientUser.Email : UserInfo.getUserEmail()};
            mail.setToAddresses(toAddresses);
            mail.setSenderDisplayName(Label.COMMON_ACCOUNTING_SEED);
            mail.setSubject(Label.COMMON_ACCOUNTING_SEED + ': ' + Label.COMMON_YOUR + ' ' + jobName + ' ' + Label.COMMON_HAS_BEEN_PROCESSED);
            mail.setPlainTextBody(Label.COMMON_RECORDS_PROCESSED + ': ' + String.valueOf(processedRecords)
                + '\n' + Label.COMMON_RECORDS_SUCCEEDED + ': ' + String.valueOf(succeededRecords)
                + '\n' + Label.COMMON_RECORDS_FAILED + ': ' + String.valueOf(failedRecords));
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail});
        }
    }

    private void getRecipientUser() {
        if (!String.isBlank(jobName)) {
            CronTrigger selectedJob;
            for (CronTrigger ct : DomainUtils.getCronTriggerByJobName(new Set<String> {jobName})) {
                selectedJob = ct;
                break;
            }
            List<User> recipientUsers;
            if (selectedJob != NULL) {
                recipientUsers = DomainUtils.getUserById(new Set<Id> {selectedJob.CreatedById});
            }

            if (recipientUsers != NULL && !recipientUsers.isEmpty()) {
                recipientUser = recipientUsers[0];
            }
        }

    }


}