public with sharing class RecurringJournalEntryLineActions {

    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final Map<SObjectField, Integer> currencyAndNumberFields = new Map<SObjectField, Integer> {
        Recurring_Journal_Entry_Line__c.Debit__c => 2,
        Recurring_Journal_Entry_Line__c.Credit__c => 2,
        Recurring_Journal_Entry_Line__c.Quantity__c => 6
    };
    public static Boolean bypassGLAccountValidation = false;

    public static void requireFields(List<Recurring_Journal_Entry_Line__c> recurringJournalEntryLines) {
        for (Recurring_Journal_Entry_Line__c recurringJournalEntryLine : recurringJournalEntryLines) {
            if (recurringJournalEntryLine.GL_Account__c == NULL) {
                recurringJournalEntryLine.GL_Account__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
        }
    }

}