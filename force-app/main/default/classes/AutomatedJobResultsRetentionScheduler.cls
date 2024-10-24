public with sharing class AutomatedJobResultsRetentionScheduler implements Schedulable {

    private static final Integer BATCH_CHUNK_SIZE = 100;

    public void execute(SchedulableContext sc) {
        Decimal retentionDays = AccountingSettingsHandler.getAutomatedJobResultsRetentionDays();
        Date dateValue = System.today().addDays(-retentionDays.intValue());
        PurgeAutomatedJodResultsBatch pur = new PurgeAutomatedJodResultsBatch(dateValue, false);
        Database.executeBatch(pur, BATCH_CHUNK_SIZE);
    }

    public static String startAutomatedJobResultsRetentionScheduler(String cronExp, String scheduledJobType) {
        String jobId = '';
        if (String.isNotBlank(cronExp)) {
            jobId = System.schedule(scheduledJobType, cronExp, new AutomatedJobResultsRetentionScheduler());
        }
        return jobId;
    }

}