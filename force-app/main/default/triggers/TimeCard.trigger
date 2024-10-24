trigger TimeCard on Time_Card__c (before insert, after insert, before update, after update, before delete) {
    
    if (Trigger.isBefore && Trigger.isInsert) {
        SObjectActions.populateDefaultStatus(Trigger.new, true);
        SObjectActions.populateLedgerField(Trigger.new);
        TimeCardActions.setCloneTimeCardValues(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        TimeCardActions.validateRequiredFieldsOnTimeCard(Trigger.new);
        TimeCardActions.validateTimeCardPeriodIsOpen(Trigger.new);
        SObjectActions.validateLedgerType(Trigger.new);
        TimeCardActions.validateTimeCardDoesNotExistPeriod(Trigger.newMap, Trigger.oldMap);
        TimeCardActions.cloneTimeCardLines(Trigger.new);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        SObjectActions.populateDefaultStatus(Trigger.new, true);
        SObjectActions.updateLedgerField(Trigger.oldMap, Trigger.newMap);
        TimeCardActions.updateTypeField(Trigger.newMap, Trigger.oldMap);
        TriggerObserver.getInstance().watch(Trigger.new);
    }
         
    if (Trigger.isAfter && Trigger.isUpdate) {
        TimeCardActions.validateRequiredFieldsOnTimeCard(Trigger.new);
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, Trigger.newMap);
        TimeCardActions.validateTimeCardDoesNotExistPeriod(Trigger.newMap, Trigger.oldMap);
        TimeCardActions.preventUpdateDayCount(Trigger.new);
        TimeCardActions.preventUpdateTimeCardPeriod(Trigger.new, Trigger.oldMap);
        SObjectActions.validateLedgerType(Trigger.new);
        TriggerObserver.getInstance().validateObservedContent(Trigger.new);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
    }
    
    if (Trigger.isBefore && Trigger.isDelete) {
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, NULL);
    }
}