public with sharing class TrackFinancialTransactionsScheduler implements Schedulable{
    
    public void execute(SchedulableContext sc) {
        FinancialSuiteService.executeFinancialTransactionsBatchChain();
    }

    public static String startTrackFinancialTransactionsScheduler(String cronExp, String scheduledJobType) {
        String jobId = '';
        
        if (String.isNotBlank(cronExp)) {
            jobId = System.schedule(scheduledJobType, cronExp, new TrackFinancialTransactionsScheduler());
        }
        
        return jobId;
    }
}