public with sharing class CxSettlementScheduler implements Schedulable{

    public void execute(SchedulableContext sc) {
        CxTxnsImportBatch batch = new CxTxnsImportBatch();
        Database.executeBatch(batch, 1); // ONLY RUN WITH BATCH SIZE OF 1
    }

    public static String startCxSettlementScheduler(String cronExp, String scheduledJobType) {
        String jobId = '';
        if (String.isNotBlank(cronExp)) {
            jobId = System.schedule(scheduledJobType, cronExp, new CxSettlementScheduler());
        }
        return jobId;
    }
}