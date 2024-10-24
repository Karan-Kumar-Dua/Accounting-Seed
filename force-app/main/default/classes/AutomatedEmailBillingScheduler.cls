public with sharing class AutomatedEmailBillingScheduler implements Schedulable {

    private static final Integer BATCH_CHUNK_SIZE = 40;
    private String baseURL;

    public AutomatedEmailBillingScheduler(String baseURL) {
        this.baseURL = baseURL;
    }

    public void execute(SchedulableContext sc) {
        Map<Id, Billing__c> bills = DomainUtils.getAutomatedEmailBillings();

        StatementPDFSaveMailBatch pdfStatement = new StatementPDFSaveMailBatch(
            new List<Id>(bills.keySet()), true, this.baseURL, AbstractStatementManager.StatementBase.BILLING
        );
        Database.executeBatch(pdfStatement, BATCH_CHUNK_SIZE);
    }

    public static String startAutomatedEmailBillingScheduler(String cronExp, String scheduledJobType, String baseURL) {
        String jobId = '';
        if (String.isNotBlank(cronExp)) {
            jobId = System.schedule(scheduledJobType, cronExp, new AutomatedEmailBillingScheduler(baseURL));
        }
        return jobId;
    }

}