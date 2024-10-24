public with sharing class PaymentActivityACHStatusScheduler implements Schedulable{
    
    public void execute(SchedulableContext sc) {
        PaymentActivityACHStatusBatch batch = new PaymentActivityACHStatusBatch();
        Database.executeBatch(batch, 100);
    }

    public static String startPaymentActivityACHStatusScheduler(String cronExp, String scheduledJobType) {
        String jobId = '';
        if (String.isNotBlank(cronExp)) {
            jobId = System.schedule(scheduledJobType, cronExp, new PaymentActivityACHStatusScheduler());
        }
        return jobId;
    }
}