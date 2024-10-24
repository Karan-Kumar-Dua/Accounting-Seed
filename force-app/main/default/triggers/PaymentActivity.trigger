trigger PaymentActivity on Payment_Activity__c(before insert, before update) {
    switch on Trigger.operationType {
        when BEFORE_INSERT {
            PaymentActivityActions.setDefaultValues(Trigger.new);
            SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, PaymentActivityActions.currencyAndNumberFields);
        }
        when BEFORE_UPDATE {
            SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, PaymentActivityActions.currencyAndNumberFields);
        }
    }
}