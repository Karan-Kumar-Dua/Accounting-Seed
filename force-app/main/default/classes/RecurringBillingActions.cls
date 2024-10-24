public with sharing class RecurringBillingActions {
    public static final Integer MAX_LINE_COUNT = 500;
    public static final String RECURRING_STATUS_INACTIVE = 'Inactive';
    public static final String RECURRING_STATUS_ACTIVE = 'Active';
    public static final List<String> nonUpdateFields {
        get {
            nonUpdateFields = new List<String> {};
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                nonUpdateFields.add('CurrencyIsoCode');
            }
            return nonUpdateFields;
        }
        private set;
    }
    public static Boolean isPreventUpdateOverride = false;

    public static void requireFields(List<Recurring_Billing__c> recurringBillings) {
        for (Recurring_Billing__c rBill : recurringBillings) {
            if (String.isBlank(rBill.Status__c)) {
                rBill.Status__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
            if (String.isBlank(rBill.Ledger__c)) {
                rBill.Ledger__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
        }
    }

    public static void setStatusInactiveEndDateExceeded(List<Recurring_Billing__c> recurringBillings){
        for (Recurring_Billing__c rBill : recurringBillings) {
            if(rBill.End_Date__c != NULL && rBill.Next_Billing_Date__c != null && rBill.Next_Billing_Date__c >= rBill.End_Date__c){
                rBill.Status__c = RECURRING_STATUS_INACTIVE;
            }  
        }
    }
}