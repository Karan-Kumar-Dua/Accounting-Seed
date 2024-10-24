public with sharing class PaymentProposalScheduler implements Schedulable{
    public void execute(SchedulableContext sc) {
        PaymentProposalBatch batch = new PaymentProposalBatch();
        Database.executeBatch(batch, 200); 
    }

    public static String startPaymentProposalScheduler(String cronExp, String scheduledJobType) {
        String jobId = '';
        if (String.isNotBlank(cronExp)) {
            jobId = System.schedule(scheduledJobType, cronExp, new PaymentProposalScheduler());
        }
        return jobId;
    }
}