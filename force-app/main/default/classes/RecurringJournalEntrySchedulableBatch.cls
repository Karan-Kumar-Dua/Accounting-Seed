public with sharing class RecurringJournalEntrySchedulableBatch extends AbstractRecurringSchedulableBatch{

    private String query =
        'SELECT Id ' +
        'FROM ' + PACKAGE_QUALIFIER + 'Recurring_Journal_Entry__c ' +
        'WHERE ' + PACKAGE_QUALIFIER + 'Exclude_From_Automation__c = false ' +
        'AND ' + PACKAGE_QUALIFIER + 'Status__c = \'Active\' ' +
        'AND ' + PACKAGE_QUALIFIER + 'Next_Journal_Entry_Date__c <= :today';

    public RecurringJournalEntrySchedulableBatch(String scheduledJobType) {
        setQuery(query);
        jobName = scheduledJobType;
    }

    public override void execute(Database.BatchableContext BC, List<SObject> scope) {
        JournalEntryFromRecurringJournalEntry jer = new JournalEntryFromRecurringJournalEntry((List<Recurring_Journal_Entry__c>) scope);
        if (!jer.isError) {
            jer.createJE();
        }
        if (!jer.resultStatusMap.values().isEmpty()) {
            handleErrors(jer.resultStatusMap.values());
        }
    }

    public override void execute(SchedulableContext sc) {
        if(FeatureManagementHandler.isLargeDataVolumeModeEnabled()) {
            Database.executeBatch(new JEFromRecurringJEBatch(), JEFromRecurringJEBatch.BATCH_SIZE);
        } else {
            Database.executeBatch(new RecurringJournalEntrySchedulableBatch(jobName), BATCH_CHUNK_SIZE);
        }
    }

    public static void startRecurringJournalEntrySchedulableBatch(String cronExp, String scheduledJobType) {
        if (cronExp == NULL) {
            if(FeatureManagementHandler.isLargeDataVolumeModeEnabled()) {
                Database.executeBatch(new JEFromRecurringJEBatch(), JEFromRecurringJEBatch.BATCH_SIZE);
            } else {
                Database.executeBatch(new RecurringJournalEntrySchedulableBatch(scheduledJobType));
            }
        }
        else {
            System.schedule(scheduledJobType, cronExp, new RecurringJournalEntrySchedulableBatch(scheduledJobType));
        }
    }

    protected override String buildNote() {
        return String.join(new List<String>{
                String.format(Label.ERR_AUTOMATED_JOB_RESULT_FAILED, new List<Object>{Journal_Entry__c.getSObjectType().getDescribe().labelPlural, failedRecords}),
                super.buildNote()
        }, '\n');
    }

}