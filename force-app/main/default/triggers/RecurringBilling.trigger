trigger RecurringBilling on Recurring_Billing__c (before insert, after insert, before update, after update) {

    if (Trigger.isBefore && Trigger.isInsert) {
        SObjectActions.populateLedgerField(Trigger.new);
        RecurringBillingActions.setStatusInactiveEndDateExceeded(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        RecurringBillingActions.requireFields(Trigger.new);
        SObjectActions.validateLedgerType(Trigger.new);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        SObjectActions.updateLedgerField(Trigger.oldMap, Trigger.newMap);
        RecurringBillingActions.setStatusInactiveEndDateExceeded(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        SObjectActions.preventUpdateAction(Trigger.oldMap, Trigger.new, RecurringBillingActions.nonUpdateFields, RecurringBillingActions.isPreventUpdateOverride);
        RecurringBillingActions.requireFields(Trigger.new);
        SObjectActions.validateLedgerType(Trigger.new);
        SobjectActions.preventUpdateLineCount(Trigger.new, Recurring_Billing__c.Line_Count__c, FeatureManagementHandler.isLargeDataVolumeModeEnabled() == true ? null : RecurringBillingActions.MAX_LINE_COUNT);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
    }
}