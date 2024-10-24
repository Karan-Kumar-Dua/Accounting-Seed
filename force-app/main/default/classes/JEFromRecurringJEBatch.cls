public with sharing class JEFromRecurringJEBatch extends SourceFromRecurringBatch {
    public static final Integer BATCH_SIZE = 1000;
    public static final String JOB_NAME = 'Recurring Journal Entry';
    private static final String REPORT_NAME = 'Recurring Journal Entry Job';

    private static AJRLogger getLogger() {
        AJRLogger.TaskOptions taskOpts = new AJRLogger.TaskOptions();
        taskOpts.subject = String.format(Label.ERR_CREATING_RECURRING_OBJECT, new String[] { SObjectType.Journal_Entry__c.getLabel() });
        AJRLogger.Config config = new AJRLogger.Config();
        config.jobName = JOB_NAME;
        config.reportName = REPORT_NAME;
        config.taskOptions = taskOpts;
        return new AJRLogger(config);
    }

    public JEFromRecurringJEBatch() {
        super(getLogger());
    }

    public JEFromRecurringJEBatch(Set<Id> recurringHeaderIds, Boolean doPost) {
        super(getLogger(), recurringHeaderIds, doPost);
    }

    public JEFromRecurringJEBatch(Set<Id> recurringHeaderIds, Boolean doPost, String correlationId) {
        super(getLogger(), recurringHeaderIds, doPost, correlationId);
    }

    public override SObjectType getRecurringLineType() {
        return Recurring_Journal_Entry_Line__c.SObjectType;
    }

    public override SObjectType getSourceHeaderType() {
        return Journal_Entry__c.SObjectType;
    }

    public override SObjectType getSourceLineType() {
        return Journal_Entry_Line__c.SObjectType;
    }

    public override void createSourceRecords(List<SObject> recurringLines, String correlationId, AJRLogger logger) {
        new JournalEntryFromRecurJournalEntryHelper(recurringLines, correlationId, logger).createSourceRecords();
    }

}