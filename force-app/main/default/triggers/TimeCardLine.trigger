trigger TimeCardLine on Time_Card_Line__c (after update, before delete) {

    if (Trigger.isAfter && Trigger.isUpdate) {
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, Trigger.newMap);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, NULL);
    }
}