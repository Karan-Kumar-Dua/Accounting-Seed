public with sharing class RecurringAccountPayableAction {
    public static final Integer MAX_LINE_COUNT = 500;
    public static final String REQUIRED_PAYEEE_ERROR = Label.ERR_REQUIRED_PAYEEE;
    public static final String MULTIPLE_PAYEEE_ERROR = Label.ERR_MULTIPLE_PAYEEE;
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

    public static void requireFields(List<Recurring_Account_Payable__c> recurringPayables) {
        for (Recurring_Account_Payable__c rPay : recurringPayables) {
            if (rPay.Ledger__c == NULL) {
                rPay.Ledger__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
        }
    }

    public static void validateVendorContactEmployee(List<Recurring_Account_Payable__c> acctPayables) {
        for (Recurring_Account_Payable__c rap : acctPayables) {
            if (rap.Vendor__c == NULL && rap.Contact__c == NULL && rap.Employee__c == NULL) {
                rap.Vendor__c.addError(REQUIRED_PAYEEE_ERROR);
                rap.Contact__c.addError(REQUIRED_PAYEEE_ERROR);
                rap.Employee__c.addError(REQUIRED_PAYEEE_ERROR);
            }
            else if ((rap.Vendor__c != NULL && (rap.Contact__c != NULL || rap.Employee__c != NULL))
                    || (rap.Contact__c != NULL && (rap.Vendor__c != NULL || rap.Employee__c != NULL))
                    || (rap.Employee__c != NULL && (rap.Vendor__c != NULL || rap.Contact__c != NULL))) {

                rap.addError(MULTIPLE_PAYEEE_ERROR);
            }
        }
    }

    public static void setStatusInactiveEndDateExceeded(List<Recurring_Account_Payable__c> recurringAccountPayables){
        for (Recurring_Account_Payable__c recurringAccountPayable : recurringAccountPayables) {
            if(recurringAccountPayable.End_Date__c != NULL && recurringAccountPayable.Next_Account_Payable_Date__c != null &&
                    recurringAccountPayable.Next_Account_Payable_Date__c >= recurringAccountPayable.End_Date__c){
                recurringAccountPayable.Status__c = RecurringBillingActions.RECURRING_STATUS_INACTIVE;
            }
        }
    }
}