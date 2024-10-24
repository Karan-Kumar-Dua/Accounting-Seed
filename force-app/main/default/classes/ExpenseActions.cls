public with sharing class ExpenseActions {
    @TestVisible
    private static Set<Id> expenseLineIds;

    public static final Boolean isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;

    public static final List<String> nonUpdateFields {
        get {
            nonUpdateFields = new List<String>();
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                nonUpdateFields.add('CurrencyIsoCode');
            }
            return nonUpdateFields;
        }
        private set;
    }

    public static void checkRequiredFieldsOnExpenseReport(List<Expense_Report__c> expenseReports) {
        for (Expense_Report__c expReport : expenseReports) {
            if (expReport.Ledger__c == NULL) {
                expReport.Ledger__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }

            if (expReport.Employee__c == NULL) {
                expReport.Employee__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
        }
    }
}