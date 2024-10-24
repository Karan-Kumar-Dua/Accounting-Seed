public with sharing class AutomatedSourceRecordPostScheduler implements Schedulable {

    private SourceRecordPostBatchChainController batchChainCtrl;

    public AutomatedSourceRecordPostScheduler(SourceRecordPostBatchChainController batchChainCtrl) {
        this.batchChainCtrl = batchChainCtrl;
    }

    public void execute(SchedulableContext sc) {
        AbstractSourceRecordPostBatch.executeBatchChain(batchChainCtrl, null);
    }

    public static String startAutomatedSourceRecordPostScheduler(String cronExp, List<String> sourceRecordTypesToProcess) {
        String jobId = '';
        SourceRecordPostBatchChainController chainController = new SourceRecordPostBatchChainController(sourceRecordTypesToProcess);

        if (String.isNotBlank(cronExp)) {
            jobId = System.schedule(
                getUniqScheduledJobName(chainController.getScheduledJobName()),
                cronExp,
                new AutomatedSourceRecordPostScheduler(chainController)
            );
        }
        return jobId;
    }

    private static String getUniqScheduledJobName(String originalName) {
        String result = originalName;
        List<CronTrigger> similarJobs = DomainUtils.getCronTriggerByJobNamePrefix(result);
        Integer countExistedJobs = 0;
        for (CronTrigger ct : similarJobs) {
            String rawJobName = ct.CronJobDetail.Name.substringBeforeLast('#').trim();
            if (rawJobName.equals(originalName)) {
                countExistedJobs++;
            }
        }
        if (countExistedJobs > 0) {
            result += ' #' + String.valueOf(++countExistedJobs);
        }
        return result;
    }

}