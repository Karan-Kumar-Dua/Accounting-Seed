public with sharing class PaymentLink {

  /* static variables */
    public static final String PAYMENT_LINK_NOT_ENABLED_ERROR_MESSAGE  =
        Label.ERR_PAYMENT_LINK_NOT_ENABLED;

    @TestVisible
    private static Boolean paymentLinkEnabled;
    private static String paymentEndpoint;
    private static String paymentUsername;
    private static Blob paymentEncryptionKey;
    private static External_Settings__mdt paymentLinkSettings;
    private static Accounting_Settings__c accountingSettings;

  /* member variables */

    private Id billingId;
    private String paymentLinkUrl;

  /* static methods */

    public static Boolean isEnabled() {
        if (PaymentLink.paymentLinkEnabled == NULL) {
            PaymentLink.initPaymentLinkData();
        }
        return PaymentLink.paymentLinkEnabled;
    }

    private static void initPaymentLinkData() {

        if (paymentLinkEnabled != NULL) {
            return;
        }

        accountingSettings = AccountingSettingsHandler.getAccountingSettings();

        if (accountingSettings == NULL) {
            accountingSettings = new Accounting_Settings__c();
        }

        paymentLinkSettings = GlobalVariables.paymentLinkSettings;

        if (paymentLinkSettings == NULL) {
            paymentLinkSettings = new External_Settings__mdt();
        }

        PaymentLink.paymentEndpoint = paymentLinkSettings.Value_1__c;
        PaymentLink.paymentLinkEnabled =
            (accountingSettings.Payment_Link_Username__c != NULL) ? true : false;
        PaymentLink.paymentUsername = accountingSettings.Payment_Link_Username__c;

        if (paymentLinkSettings.Value_2__c != NULL) {
            PaymentLink.paymentEncryptionKey = EncodingUtil.base64Decode(paymentLinkSettings.Value_2__c);
        }
    }

    public static String getUrl(Id billingId){
        if(PaymentLink.isEnabled()) {
            PaymentLink link = new PaymentLink(billingId);
            return link.getStripeUrl();            
        }
        return null;
    }

    public static String getUrl(Billing__c billing, Decimal balance, Account relatedAcc, Map<Id,Contact> contactMap, Payment_Processor__c processor) {
        if(String.isNotBlank(processor?.PaymentSite_URL__c)){
            PaymentLink link = new PaymentLink();
            return link.getCardknoxUrl(billing, balance, relatedAcc, contactMap, processor);
        }
        return null;
    }


   /* constructor */
    public PaymentLink(){}

    public PaymentLink(Id billingId) {
        if (!PaymentLink.isEnabled()) {
            throw new PaymentLinkException(PAYMENT_LINK_NOT_ENABLED_ERROR_MESSAGE);
        }
        this.billingId = billingId;
    }

    public String getCardknoxUrl(Billing__c billing, Decimal balance, Account relatedAcc, Map<Id,Contact> contactMap,  Payment_Processor__c processor) {
        if (this.paymentLinkUrl == NULL) {
            Map<String, String> addressMap = new Map<String, String>();
            if(billing.Billing_Street__c != null){
                addressMap.put('BillStreet', billing.Billing_Street__c);
                addressMap.put('BillCity', billing.Billing_City__c);
                addressMap.put('BillZip', billing.Billing_PostalCode__c);
                addressMap.put('BillState', billing.Billing_State__c); 
                addressMap.put('BillCountry', billing.Billing_Country__c);
            }else{
                addressMap.put('BillStreet', relatedAcc?.BillingStreet);
                addressMap.put('BillCity', relatedAcc?.BillingCity);
                addressMap.put('BillZip', relatedAcc?.BillingPostalCode);
                addressMap.put('BillState', relatedAcc?.BillingState); 
                addressMap.put('BillCountry', relatedAcc?.BillingCountry);
            }
            if(billing.Shipping_Street__c != null){
                addressMap.put('ShipStreet', billing.Shipping_Street__c);
                addressMap.put('ShipCity', billing.Shipping_City__c);
                addressMap.put('ShipZip', billing.Shipping_PostalCode__c);
                addressMap.put('ShipState', billing.Shipping_State__c); 
                addressMap.put('ShipCountry', billing.Shipping_Country__c);
            }else{
                addressMap.put('ShipStreet', relatedAcc?.ShippingStreet);
                addressMap.put('ShipCity', relatedAcc?.ShippingCity);
                addressMap.put('ShipZip', relatedAcc?.ShippingPostalCode);
                addressMap.put('ShipState', relatedAcc?.ShippingState); 
                addressMap.put('ShipCountry', relatedAcc?.ShippingCountry); 
            }
            
            this.paymentLinkUrl = processor.PaymentSite_URL__c + 
                '?xInvoice=' + encodeValue(String.valueOf(billing.Name)) + 
                '&xBillFirstName=' + encodeValue(contactMap.get(billing.Billing_Contact__c)?.FirstName) + 
                '&xBillLastName=' + encodeValue(contactMap.get(billing.Billing_Contact__c)?.LastName) + 
                '&xBillCompany=' + encodeValue(relatedAcc?.Name) + 
                '&xBillPhone=' + encodeValue(relatedAcc?.Phone) + 
                '&xBillMobile=' + encodeValue(contactMap.get(billing.Billing_Contact__c)?.MobilePhone) + 
                '&xBillStreet=' + encodeValue(addressMap.get('BillStreet')) + 
                '&xBillCity=' + encodeValue(addressMap.get('BillCity')) + 
                '&xBillState=' + encodeValue(addressMap.get('BillState')) + 
                '&xBillZip=' + encodeValue(addressMap.get('BillZip')) + 
                '&xBillCountry=' + encodeValue(addressMap.get('BillCountry')) + 
                '&xEmail=' + encodeValue(contactMap.get(billing.Billing_Contact__c)?.Email) + 
                '&xShipFirstName=' + encodeValue(contactMap.get(billing.Shipping_Contact__c)?.FirstName) + 
                '&xShipLastName=' + encodeValue(contactMap.get(billing.Shipping_Contact__c)?.LastName) + 
                '&xShipCompany=' + encodeValue(relatedAcc?.Name) + 
                '&xShipPhone=' + encodeValue(relatedAcc?.Phone) + 
                '&xShipMobile=' + encodeValue(contactMap.get(billing.Shipping_Contact__c)?.MobilePhone) + 
                '&xShipStreet=' + encodeValue(addressMap.get('ShipStreet')) +
                '&xShipCity=' + encodeValue(addressMap.get('ShipCity')) + 
                '&xShipState=' + encodeValue(addressMap.get('ShipState')) + 
                '&xShipZip=' + encodeValue(addressMap.get('ShipZip')) + 
                '&xShipCountry=' + encodeValue(addressMap.get('ShipCountry')) + 
                '&xShipEmail=' + encodeValue(contactMap.get(billing.Shipping_Contact__c)?.Email) + 
                (processor.Enable_PaymentSITE_Partial_Payment__c == true
                    ? '&xCustom18=' + encodeValue(String.valueOf(balance))
                    : '&xAmount=' + encodeValue(String.valueOf(balance))) + 
                '&xPONum=' + encodeValue(billing.PO_Number__c) + 
                '&xDescription=' + encodeValue(billing.Billing_Comment__c) +
                '&xCustom19=' + encodeValue(String.valueOf(billing.Id));
        }
        return this.paymentLinkUrl;
    }

    private string encodeValue(String fieldValue){
        if(String.isBlank(fieldValue)){
            return '';
        }
        return EncodingUtil.urlEncode(fieldValue, 'UTF-8');
    }

    public String getStripeUrl() {
        if (this.paymentLinkUrl == NULL) {
            try {
                PaymentLinkJSON paymentJSON = new PaymentLinkJSON(PaymentLink.paymentUsername, this.billingId, UserInfo.getDefaultCurrency());
                Blob paymentJSONBlob = paymentJSON.toBlob();
                String b64encoded = base64UrlEncode(paymentJSONBlob);
                this.paymentLinkUrl = PaymentLink.paymentEndpoint + '/v2/payment/' + b64encoded;
            }
            catch (Exception ex) {
                throw new PaymentLinkException (ex.getMessage());
            }
        }
        return this.paymentLinkUrl;
    }

    @TestVisible
    private static String base64UrlEncode(Blob data) {
        String b64data = EncodingUtil.base64Encode(data);
        b64data = b64data.replaceAll('\\+', '-');
        b64data = b64data.replaceAll('/', '_');
        b64data = b64data.remove('=');
        return b64data;
    }

  /* payment link JSON inner class */

    public with sharing class PaymentLinkJSON {
        public String username;
        public Id billingId;
        public String userCurrencyIsoCode;

        public PaymentLinkJSON(String username, Id billingId, String userCurrencyIsoCode) {
            this.username = username;
            this.billingId = billingId;
            this.userCurrencyIsoCode = userCurrencyIsoCode;
        }

        public String serialize() {
            return JSON.serialize(this);
        }

        public Blob toBlob() {
            return Blob.valueOf(this.serialize());
        }
    }

    public class PaymentLinkException extends Exception {}
}