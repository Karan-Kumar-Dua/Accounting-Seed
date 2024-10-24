public with sharing class PaymentActivityHelper {

    public static final String SUCCESS_STATUS = 'Success';
    public static final String DECLINED_STATUS = 'Declined';
    public static final String ERROR_STATUS = 'Error';
    public static final String PENDING_STATUS = 'Pending';
    public static final String VOID_STATUS = 'Void';

    public static final String PAYMENT_TYPE = 'Payment';

    public static Payment_Activity__c createPaymentActivity(
        Id cashReceiptId,
        StripeService.StripeCharge charge,
        Id paymentMethodId
    ) {
        Payment_Activity__c result;
        try {
            result = new Payment_Activity__c(
                Type__c = 'Payment',
                Amount__c = charge.getAmountInDefaultCurrencyUnits(),
                Cash_Receipt__c = cashReceiptId,
                Payment_Method__c = paymentMethodId,
                Status__c = getPaymentActivityStatus(charge)
            );

            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                result.put('CurrencyIsoCode', charge.stripeCurrency.toUpperCase());
            }
        }
        catch (Exception ex) {
            throw ex;
        }
        return result;
    }

    public static Payment_Activity__c createPaymentActivity(
        PaymentSaleItem saleItem,
        CardknoxService.PaymentTransaction payment,
        Payment_Processor__c pp
    ) {
        Payment_Activity__c result;
        try {
            result = new Payment_Activity__c(
                Type__c = 'Payment',
                Amount__c = saleItem.cashReceipt.Amount__c,
                Cash_Receipt__c = saleItem.cashReceipt.Id,
                Payment_Method__c = saleItem.paymentMethod.Id,
                Status__c = (payment.GatewayStatus == 'Approved' && saleItem.paymentMethod.Payment_Method_Type__c == 'Credit Card')
                        ? 'Success' :  (payment.GatewayStatus == 'Approved' && saleItem.paymentMethod.Payment_Method_Type__c != 'Credit Card') 
                        ? 'Pending' : payment.GatewayStatus == 'Declined' ? 'Declined' : 'Error',
                Merchant_Reference__c = payment.GatewayRefNum,
                Error_Message__c =  payment.GatewayStatus == 'Approved' ? null :  
                                    payment.GatewayErrorMessage != null ? payment.GatewayErrorMessage : 
                                        payment.Error == Label.ERR_INVALID_XKEY_ERROR_MESSAGE_FROM_CARDKNOX || 
                                        payment.Error == Label.ERR_INVALID_XKEY_ERROR_MESSAGE_FROM_CARDKNOX_KEY_INACTIVE || 
                                        payment.Error == Label.ERR_INVALID_XKEY_ERROR_MESSAGE_FROM_CARDKNOX_ACCESS_DENIED ? 
                                        Label.ERR_INVALID_XKEY_VALUE : 
                                        payment.Error == Label.ERR_INVALID_XKEY_ERROR_MESSAGE_FROM_CARDKNOX ?
                                        Label.ERR_INVALID_XKEY_ERROR_MESSAGE_FROM_CARDKNOX : 
                                        payment.Error
            );

            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                result.put('CurrencyIsoCode', saleItem.cashReceipt.get('CurrencyIsoCode'));
            }
            if (saleItem.cashReceipt.Convenience_Fees_Charged__c != null) {
                result.Convenience_Fee__c = saleItem.cashReceipt.Convenience_Fees_Charged__c;
                result.Original_Amount__c = saleItem.cashReceipt.Amount__c - saleItem.cashReceipt.Convenience_Fees_Charged__c;
            }
        }
        catch (Exception ex) {
            throw ex;
        }
        return result;
    }
    public static Payment_Activity__c createPaymentActivity(
        Id paymentMethodId,
        Decimal amount,
        StripeService.StripeErrorDetails errorDetails
    ) {

        Payment_Activity__c result;
        try {
            result = new Payment_Activity__c(
                Type__c = 'Payment',
                Amount__c = amount,
                Payment_Method__c = paymentMethodId,
                Status__c = getPaymentActivityStatus(errorDetails),
                Error_Message__c = errorDetails.message,
                Error_Type__c = buildErrorDescriptionString(errorDetails)
            );
        }
        catch (Exception ex) {
            throw ex;
        }
        return result;
    }
    public static Payment_Activity__c createPaymentActivity(
        CardknoxService.PaymentTransaction payment,
        PaymentSaleItem saleItem,
        String error
    ) {

        Payment_Activity__c result;
        try {
            result = new Payment_Activity__c(
                Type__c = 'Payment',
                Amount__c = saleItem.cashReceipt.Amount__c,
                Payment_Method__c = saleItem.paymentMethod.Id,
                Status__c = 'Error',
                Error_Message__c = error,
                Merchant_Reference__c = payment?.GatewayRefNum
            );
        }
        catch (Exception ex) {
            throw ex;
        }
        return result;
    }
    private static String getPaymentActivityStatus(StripeService.StripeCharge charge) {
        String result;
        switch on charge.status {
            when 'succeeded' {
                result = SUCCESS_STATUS;
            }
            when 'pending' {
                result = PENDING_STATUS;
            }
            when else {
                result = ERROR_STATUS;
            }
        }
        return result;
    }

    private static String getPaymentActivityStatus(StripeService.StripeErrorDetails errorDetails) {
        String result;
        switch on errorDetails.code {
            when 'card_declined' {
                result = DECLINED_STATUS;
            }
            when else {
                result = ERROR_STATUS;
            }
        }
        return result;
    }

    private static String buildErrorDescriptionString(StripeService.StripeErrorDetails errorDetails) {
        String result = Label.COMMON_TYPE_VALUE + errorDetails.type + Label.COMMON_CODE_VALUE + errorDetails.code + '].';
        if (String.isNotBlank(errorDetails.decline_code)) {
            result += Label.COMMON_DECLINE_CODE + errorDetails.decline_code + '].';
        }
        return result;
    }

}