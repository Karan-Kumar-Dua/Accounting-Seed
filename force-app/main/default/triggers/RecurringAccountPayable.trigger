trigger RecurringAccountPayable on Recurring_Account_Payable__c (before insert, after insert, before update, after update) {

    if (Trigger.isBefore && Trigger.isInsert) {
        SObjectActions.populateLedgerField(Trigger.new);
        RecurringAccountPayableAction.setStatusInactiveEndDateExceeded(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        RecurringAccountPayableAction.requireFields(Trigger.new);
        SObjectActions.validateLedgerType(Trigger.new);
        RecurringAccountPayableAction.validateVendorContactEmployee(Trigger.new);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);

    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        SObjectActions.updateLedgerField(Trigger.oldMap, Trigger.newMap);
        RecurringAccountPayableAction.setStatusInactiveEndDateExceeded(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        SObjectActions.preventUpdateAction(Trigger.oldMap, Trigger.new, RecurringAccountPayableAction.nonUpdateFields, RecurringAccountPayableAction.isPreventUpdateOverride);
        RecurringAccountPayableAction.requireFields(Trigger.new);
        SObjectActions.validateLedgerType(Trigger.new);
        RecurringAccountPayableAction.validateVendorContactEmployee(Trigger.new);
        SobjectActions.preventUpdateLineCount(Trigger.new, Recurring_Account_Payable__c.Line_Count__c, FeatureManagementHandler.isLargeDataVolumeModeEnabled() != true ? RecurringAccountPayableAction.MAX_LINE_COUNT : null);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
    }

}