public with sharing class RecurringBillingSchedulableBatch extends AbstractRecurringSchedulableBatch implements Database.AllowsCallouts {

    private String query =
        'SELECT Id ' +
        'FROM ' + PACKAGE_QUALIFIER + 'Recurring_Billing__c ' +
        'WHERE ' + PACKAGE_QUALIFIER + 'Exclude_From_Automation__c = false ' +
        'AND ' + PACKAGE_QUALIFIER + 'Status__c = \'Active\' ' +
        'AND ' + PACKAGE_QUALIFIER + 'Next_Billing_Date__c <= :today';

    public RecurringBillingSchedulableBatch(String scheduledJobType) {
        setQuery(query);
        jobName = scheduledJobType;
    }

    public override void execute(Database.BatchableContext BC, List<SObject> scope) {
        BillingFromRecurringBilling brb = new BillingFromRecurringBilling((List<Recurring_Billing__c>) scope);
        brb.createBilling();
        if (!brb.resultStatusMap.values().isEmpty()) {
            handleErrors(brb.resultStatusMap.values());
        }

    }

    public override void execute(SchedulableContext sc) {
        if(FeatureManagementHandler.isLargeDataVolumeModeEnabled()) {
            Database.executeBatch(new BillingFromRecurringBillingBatch(), BillingFromRecurringBillingBatch.BATCH_SIZE);
        } else {
            Database.executeBatch(new RecurringBillingSchedulableBatch(jobName), BATCH_CHUNK_SIZE);
        }
    }

    public static void startRecurringBillingSchedulableBatch(String cronExp, String scheduledJobType) {
        if (cronExp == NULL) {
            if(FeatureManagementHandler.isLargeDataVolumeModeEnabled()) {
                Database.executeBatch(new BillingFromRecurringBillingBatch(), BillingFromRecurringBillingBatch.BATCH_SIZE);
            } else {
                Database.executeBatch(new RecurringBillingSchedulableBatch(scheduledJobType));
            }
        }
        else {
            System.schedule(scheduledJobType, cronExp, new RecurringBillingSchedulableBatch(scheduledJobType));
        }
    }

}