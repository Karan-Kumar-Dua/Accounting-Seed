trigger ExpenseLine on Expense_Line__c (before insert, after insert, before update, after update) {

    if (Trigger.isBefore && Trigger.isInsert) {
        ExpenseLineActions.populateCCVendorPayableField(Trigger.new);
        ExpenseLineActions.calculateMileage(Trigger.new);
        SObjectActions.setISOCodeFromParent(Trigger.new, 'Expense_Report__c');
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        ExpenseLineActions.requireFields(Trigger.new);
        GLAccountValidator.validateGlAccountLookups(Trigger.new, NULL);
        ExpenseLineActions.validateCreditCardVendor(Trigger.new);
        ExpenseLineActions.validateCCVendorField(Trigger.new);
        ExpenseLineActions.validateMandatoryMileageRate(Trigger.newMap);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        ExpenseLineActions.populateCCVendorPayableField(Trigger.new);
        ExpenseLineActions.calculateMileage(Trigger.new);
        SObjectActions.setISOCodeFromParent(Trigger.new, 'Expense_Report__c');
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        ExpenseLineActions.requireFields(Trigger.new);
        GLAccountValidator.validateGlAccountLookups(Trigger.new, Trigger.oldMap);
        ExpenseLineActions.validateCreditCardVendor(Trigger.new);
        ExpenseLineActions.validateCCVendorField(Trigger.new);
        ExpenseLineActions.validateMandatoryMileageRate(Trigger.newMap);
    }
}