trigger PaymentMethod on Payment_Method__c (before insert, before update, before delete, after insert, after update, after delete) {

    if (Trigger.isBefore && Trigger.isInsert) {
        PaymentMethodActions.onlyOneDefaultPaymentMethodBefore(Trigger.new);
        PaymentMethodActions.onlyOneDefaultAPPaymentMethod(Trigger.new);
        PaymentMethodActions.validationOnCustomerAndVendorField(Trigger.new);
        PaymentMethodActions.setAPExternalID(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        PaymentMethodActions.onlyOneDefaultPaymentMethodAfter(Trigger.new);
        PaymentMethodActions.preventDuplicatePaymentMethod(Trigger.new);
        PaymentMethodActions.requireFields(Trigger.new);
        PaymentMethodActions.apAutomationPostMessage(Trigger.new, null);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        PaymentMethodActions.setDefaultFields(Trigger.new);
        PaymentMethodActions.onlyOneDefaultPaymentMethodBefore(Trigger.new);
        PaymentMethodActions.onlyOneDefaultAPPaymentMethod(Trigger.new);
        PaymentMethodActions.validationOnCustomerAndVendorField(Trigger.new);
        PaymentMethodActions.setAPExternalID(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        PaymentMethodActions.preventUpdateOnExtUse(Trigger.new);
        PaymentMethodActions.requireFields(Trigger.new);
        PaymentMethodActions.onlyOneDefaultPaymentMethodAfter(Trigger.new);
        PaymentMethodActions.preventStandardUpdate(Trigger.new, Trigger.oldMap);
        PaymentMethodActions.preventDuplicatePaymentMethod(Trigger.new);
        PaymentMethodActions.apAutomationPostMessage(Trigger.new, Trigger.oldMap);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        PaymentMethodActions.preventStandardDeletion(Trigger.old);
    }

    if(Trigger.isAfter && Trigger.isDelete){
        PaymentMethodActions.apAutomationPostMessage(Trigger.old, Trigger.oldMap);
    }
}