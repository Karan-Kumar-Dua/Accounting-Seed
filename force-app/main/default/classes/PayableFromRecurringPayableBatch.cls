public with sharing class PayableFromRecurringPayableBatch extends SourceFromRecurringBatch {
    
    public static final Integer BATCH_SIZE = 1000;
    public static final String JOB_NAME = 'Recurring Payable';
    private static final String REPORT_NAME = 'Recurring Payable Job';

    private static AJRLogger getLogger() {
        AJRLogger.TaskOptions taskOpts = new AJRLogger.TaskOptions();
        taskOpts.subject = String.format(Label.ERR_CREATING_RECURRING_OBJECT, new String[] { SObjectType.Account_Payable__c.getLabel() });
        AJRLogger.Config config = new AJRLogger.Config();
        config.jobName = JOB_NAME;
        config.reportName = REPORT_NAME;
        config.taskOptions = taskOpts;
        return new AJRLogger(config);
    }
    
    public PayableFromRecurringPayableBatch() {
        super(getLogger());
    }

    public PayableFromRecurringPayableBatch(Set<Id> recurringHeaderIds, Boolean doPost) {
        super(getLogger(), recurringHeaderIds, doPost);
    }

    public PayableFromRecurringPayableBatch(Set<Id> recurringHeaderIds, Boolean doPost, String correlationId) {
        super(getLogger(), recurringHeaderIds, doPost, correlationId);
    }

    public override SObjectType getRecurringLineType() {
        return Recurring_Account_Payable_Line__c.SObjectType;
    }

    public override SObjectType getSourceHeaderType() {
        return Account_Payable__c.SObjectType;
    }

    public override SObjectType getSourceLineType() {
        return Account_Payable_Line__c.SObjectType;
    }

    public override void createSourceRecords(List<SObject> recurringLines, String correlationId, AJRLogger logger) {
        new AccountPayableFromRecrAccPayableHelper(recurringLines, correlationId, logger).createSourceRecords();
    }

}