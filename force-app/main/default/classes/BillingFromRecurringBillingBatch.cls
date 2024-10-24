public with sharing class BillingFromRecurringBillingBatch extends SourceFromRecurringBatch {
    
    public static final Integer BATCH_SIZE = 500;
    public static final String JOB_NAME = 'Recurring Billing';
    private static final String REPORT_NAME = 'Recurring Billing Job';

    private static AJRLogger getLogger() {
        AJRLogger.TaskOptions taskOpts = new AJRLogger.TaskOptions();
        taskOpts.subject = String.format(Label.ERR_CREATING_RECURRING_OBJECT, new String[] { SObjectType.Billing__c.getLabel() });
        AJRLogger.Config config = new AJRLogger.Config();
        config.jobName = JOB_NAME;
        config.reportName = REPORT_NAME;
        config.taskOptions = taskOpts;
        return new AJRLogger(config);
    }

    public BillingFromRecurringBillingBatch() {
        super(getLogger());
    }

    public BillingFromRecurringBillingBatch(Set<Id> recurringHeaderIds, Boolean doPost) {
        super(getLogger(), recurringHeaderIds, doPost);
    }

    public BillingFromRecurringBillingBatch(Set<Id> recurringHeaderIds, Boolean doPost, String correlationId) {
        super(getLogger(), recurringHeaderIds, doPost, correlationId);
    }

    public override SObjectType getRecurringLineType() {
        return Recurring_Billing_Line__c.SObjectType;
    }

    public override SObjectType getSourceHeaderType() {
        return Billing__c.SObjectType;
    }

    public override SObjectType getSourceLineType() {
        return Billing_Line__c.SObjectType;
    }

    public override void createSourceRecords(List<SObject> recurringLines, String correlationId, AJRLogger logger) {
        new BillingsFromRecurringBillingsHelper(recurringLines, correlationId, logger).createSourceRecords();
    }

}