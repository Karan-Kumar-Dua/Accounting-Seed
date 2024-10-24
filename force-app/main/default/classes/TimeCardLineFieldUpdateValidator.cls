public with sharing class TimeCardLineFieldUpdateValidator extends SourceDocumentUpdateFieldValidator {

    public Set<SObjectField> lockedUpdateFieldsPostedTimeCardLine = new Set<SObjectField> {
        Time_Card_Line__c.Project__c,
        Time_Card_Line__c.Project_Task__c,
        Time_Card_Line__c.Time_Card_Variable_1__c,
        Time_Card_Line__c.Time_Card_Variable_2__c
    };

    public SObjectField statusFieldName = Time_Card_Line__c.Parent_Status__c;

    public TimeCardLineFieldUpdateValidator() {
        statusField = statusFieldName;
        lockedUpdateFieldsPosted = lockedUpdateFieldsPostedTimeCardLine;
    }

    public override void setValidationRules() {
        preventUpdateActionPosted();
        preventDeleteActionPosted();
    }

}