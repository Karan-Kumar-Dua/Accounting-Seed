trigger ExchangeRate on Exchange_Rate__c (before insert, before delete, after insert, after update) {

    if (Trigger.isBefore && Trigger.isInsert) {
        ExchangeRateActions.setDefaultFields(Trigger.new);
        ExchangeRateActions.getExistedTables(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        ExchangeRateActions.setRelatedTableToDate(Trigger.newMap);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, Trigger.newMap);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        ExchangeRateActions.updateRelatedNextTable(Trigger.oldMap);
    }

}