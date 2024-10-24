public with sharing class RecurringPayableSchedulableBatch extends AbstractRecurringSchedulableBatch {

    private String query =
        'SELECT Id ' +
        'FROM ' + PACKAGE_QUALIFIER + 'Recurring_Account_Payable__c ' +
        'WHERE ' + PACKAGE_QUALIFIER + 'Exclude_From_Automation__c = false ' +
        'AND ' + PACKAGE_QUALIFIER + 'Status__c = \'Active\' ' +
        'AND ' + PACKAGE_QUALIFIER + 'Next_Account_Payable_Date__c <= :today';

    public RecurringPayableSchedulableBatch(String scheduledJobType) {
        setQuery(query);
        jobName = scheduledJobType;
    }

    public override void execute(Database.BatchableContext BC, List<SObject> scope) {
        AccountPayableFromRecrAccountPayable prp = new AccountPayableFromRecrAccountPayable((List<Recurring_Account_Payable__c>) scope);
        prp.createPayable();
        if (!prp.resultStatusMap.values().isEmpty()) {
            handleErrors(prp.resultStatusMap.values());
        }
    }

    public override void execute(SchedulableContext sc) {
        if(FeatureManagementHandler.isLargeDataVolumeModeEnabled()) {
            Database.executeBatch(new PayableFromRecurringPayableBatch(), PayableFromRecurringPayableBatch.BATCH_SIZE);
        } else {
            Database.executeBatch(new RecurringPayableSchedulableBatch(jobName), BATCH_CHUNK_SIZE);
        }
    }

    public static void startRecurringPayableSchedulableBatch(String cronExp, String scheduledJobType) {
        if (cronExp == NULL) {
            if(FeatureManagementHandler.isLargeDataVolumeModeEnabled()) {
                Database.executeBatch(new PayableFromRecurringPayableBatch(), PayableFromRecurringPayableBatch.BATCH_SIZE);
            } else {
                Database.executeBatch(new RecurringPayableSchedulableBatch(scheduledJobType));
            }
        }
        else {
            System.schedule(scheduledJobType, cronExp, new RecurringPayableSchedulableBatch(scheduledJobType));
        }
    }

}