trigger TimeCardDay on Time_Card_Day__c (after insert, after update, before delete) {
    
    if (Trigger.isAfter && Trigger.isInsert) {
        TimeCardDayActions.checkDuplicateTimeCardDay(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        TimeCardDayActions.checkDuplicateTimeCardDay(Trigger.new);
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, Trigger.newMap);
    }
    if (Trigger.isDelete) {
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, NULL);
    }
}