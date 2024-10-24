public with sharing class RecurringPeriodTaskSchedulableBatch extends AbstractRecurringSchedulableBatch implements Database.AllowsCallouts {	

    private String query =	
        'SELECT Id ' +	
        'FROM ' + PACKAGE_QUALIFIER + 'Period_Task__c ' +	
        'WHERE ' + PACKAGE_QUALIFIER + 'Exclude_From_Automation__c = false ' +	
        'AND (' + PACKAGE_QUALIFIER + 'Next_Accounting_Period_Task_Date__c <= :TODAY ' +	
            'OR (' + PACKAGE_QUALIFIER + 'Create_Date__c <= :TODAY ' + 	
                'AND ' + PACKAGE_QUALIFIER + 'Next_Accounting_Period_Task_Date__c = null ))' +	
        'AND ' + PACKAGE_QUALIFIER + 'Active__c = true';	

    public RecurringPeriodTaskSchedulableBatch(String scheduledJobType) {	
        setQuery(query);	
        jobName = scheduledJobType;	
    }	

    public override void execute(Database.BatchableContext BC, List<SObject> scope) {	
        TaskFromRecurringPeriodTask taskFromPeriodTask = new TaskFromRecurringPeriodTask((List<Period_Task__c>) scope);	
        taskFromPeriodTask.createTasks();	
        if (!taskFromPeriodTask.resultStatusMap.values().isEmpty()) {	
            handleErrors(taskFromPeriodTask.resultStatusMap.values());	
        }	


    }	

    public override void execute(SchedulableContext sc) {	
        Database.executeBatch(new RecurringPeriodTaskSchedulableBatch(jobName), BATCH_CHUNK_SIZE);	
    }	

    public static void startRecurringPeriodTaskSchedulableBatch(String cronExp, String scheduledJobType) {	
        if (cronExp == NULL) {	
            Database.executeBatch(new RecurringPeriodTaskSchedulableBatch(scheduledJobType));	
        }	
        else {	
            System.schedule(scheduledJobType, cronExp, new RecurringPeriodTaskSchedulableBatch(scheduledJobType));	
        }	
    }	

}