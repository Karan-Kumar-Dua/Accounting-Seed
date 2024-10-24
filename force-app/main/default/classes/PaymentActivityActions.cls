public with sharing class PaymentActivityActions {
    public static final Map<SObjectField, Integer> currencyAndNumberFields = new Map<SObjectField, Integer> {
        Payment_Activity__c.Fee__c => 2
    };

    public static void setDefaultValues(List<Payment_Activity__c> activities){
        for(Payment_Activity__c activity : activities){
            if (activity.Payment_Date__c == null){
                activity.Payment_Date__c = System.Now();
            }
        }
    }
}