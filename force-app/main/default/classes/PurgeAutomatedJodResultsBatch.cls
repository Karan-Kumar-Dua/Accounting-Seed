public with sharing class PurgeAutomatedJodResultsBatch extends PurgeBaseBatch {

    private final Date toDate;

    public PurgeAutomatedJodResultsBatch(Date valueToDate, Boolean sendEmail) {
        isSendEmail = sendEmail;
        this.objectLabel = Automated_Job_Results__c.getsObjectType().getDescribe().getLabel();
        this.toDate = valueToDate;
    }

    public PurgeAutomatedJodResultsBatch(Date valueToDate) {
        this.objectLabel = Automated_Job_Results__c.getsObjectType().getDescribe().getLabel();
        this.toDate = valueToDate;
    }

    public override Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id FROM Automated_Job_Results__c WHERE DAY_ONLY(convertTimezone(CreatedDate)) < ' + String.escapeSingleQuotes(String.valueOf(toDate));
        return DomainUtils.getQueryLocator(query);
    }

}