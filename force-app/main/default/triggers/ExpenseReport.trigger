trigger ExpenseReport on Expense_Report__c (before insert, after insert, before update, after update) {

    if (Trigger.isBefore && Trigger.isInsert) {
        SObjectActions.populateLedgerField(Trigger.new);
        SObjectActions.populateDefaultStatus(Trigger.new, false);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        ExpenseActions.checkRequiredFieldsOnExpenseReport(Trigger.new);
        SObjectActions.validateLedgerType(Trigger.new);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        SObjectActions.updateLedgerField(Trigger.oldMap, Trigger.newMap);
        SObjectActions.populateDefaultStatus(Trigger.new, false);
        SObjectActions.preventUpdateAction(Trigger.oldMap, Trigger.new, ExpenseActions.nonUpdateFields, false);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        ExpenseActions.checkRequiredFieldsOnExpenseReport(Trigger.new);
        SObjectActions.validateLedgerType(Trigger.new);
        SobjectActions.preventUpdateLineCount(Trigger.new, Expense_Report__c.Line_Count__c, NULL);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
    }
}