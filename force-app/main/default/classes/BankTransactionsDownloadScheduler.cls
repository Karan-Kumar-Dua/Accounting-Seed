public with sharing class BankTransactionsDownloadScheduler implements Schedulable {

    public void execute(SchedulableContext sc) {
        BDCService service = new BDCService();
        service.getAllTransactionsBulk();
    }

    public static String startBankTransactionsDownloadScheduler(String cronExp, String scheduledJobType) {
        String jobId = '';
        if (String.isNotBlank(cronExp)) {
            jobId = System.schedule(scheduledJobType, cronExp, new BankTransactionsDownloadScheduler());
        }
        return jobId;
    }

}