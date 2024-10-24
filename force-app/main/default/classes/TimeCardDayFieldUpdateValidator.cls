public with sharing class TimeCardDayFieldUpdateValidator extends SourceDocumentUpdateFieldValidator {

    public Set<SObjectField> lockedUpdateFieldsPostedTCD = new Set<SObjectField> {
        Time_Card_Day__c.Date__c,
        Time_Card_Day__c.Hours__c
    };

    public SObjectField statusFieldName = Time_Card_Day__c.Parent_Status__c;

    public TimeCardDayFieldUpdateValidator() {
        statusField = statusFieldName;
        lockedUpdateFieldsPosted = lockedUpdateFieldsPostedTCD;
    }

    public override void setValidationRules() {
        preventUpdateActionPosted();
        preventDeleteActionPosted();
    }
}