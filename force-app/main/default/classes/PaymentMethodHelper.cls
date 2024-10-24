public with sharing class PaymentMethodHelper {

    public static Payment_Method__c createPaymentMethod(PaymentMethodProvider pmProvider) {
       return pmProvider.getStripeSourceBySelectedSource();
    }

}