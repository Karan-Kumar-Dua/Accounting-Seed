public with sharing class StripeService {

    /* Constants */
    public static final String CUSTOMER_URL = 'https://api.stripe.com/v1/customers';
    public static final String CHARGE_URL = 'https://api.stripe.com/v1/charges';
    public static final String TOKEN_URL = 'https://api.stripe.com/v1/tokens';

    public static Integer RECEIVE_STRIPE_SOURCES_LIMIT = 100;

    public static final String PLATFORM_PUBLISHABLE_KEY = GlobalVariables.stripeSettings.Value_1__c;
    public static final String PLATFORM_SECRET_KEY = GlobalVariables.stripeSettings.Value_2__c;
    public static final String CONNECT_CLIENT_ID = GlobalVariables.stripeSettings.Value_3__c;

    public static final String TEST_PLATFORM_PUBLISHABLE_KEY = GlobalVariables.stripeTestSettings.Value_1__c;
    public static final String TEST_PLATFORM_SECRET_KEY = GlobalVariables.stripeTestSettings.Value_2__c;
    public static final String TEST_CONNECT_CLIENT_ID = GlobalVariables.stripeTestSettings.Value_3__c;

    public static final String PAYMENT_SUCCESSFUL = Label.INF_PAYMENT_SUCCESSFUL;
    public static final String PAYMENT_METHOD_STATUS_ACTIVE = 'Active';
    public static final String PAYMENT_METHOD_STATUS_INACTIVE = 'Inactive';
    public static final String PAYMENT_METHOD_CREATE_SUCCESS = Label.INF_PAYMENT_METHOD_CREATE_SUCCESS;
    public static final String PAYMENT_METHOD_UPDATE_ERROR = Label.ERR_PAYMENT_METHOD_UPDATE;
    public static final String PAYMENT_METHOD_SET_DEFAULT_ERROR = Label.ERR_PAYMENT_METHOD_SET_DEFAULT;

    public static final Set<String> ZERO_DECIMAL_CURRENCIES = new Set<String>{
        'JPY', 'BIF', 'CLP', 'DJF', 'GNF', 'KMF', 'KRW', 'MGA', 'PYG', 'RWF', 'UGX', 'VND', 'VUV', 'XAF', 'XOF', 'XPF'
    };

    private static final String IDEMPOTENCY_ERROR = 'idempotency_error';

    /* Static Methods */

    /**
     * @deprecated
     * Runs in live mode.
     */
    public static List<StripeSource> getListAllCustomerCards(String stripeCustomerId) {
        return getListAllCustomerCards(stripeCustomerId, getLegacyPaymentProcessor());
    }

    public static List<StripeSource> getListAllCustomerCards(String stripeCustomerId, Payment_Processor__c processor) {
        String endpoint = CUSTOMER_URL + '/' + stripeCustomerId + '/sources?object=card&limit=' + RECEIVE_STRIPE_SOURCES_LIMIT;
        Map<String, String> headers = populateHeaderMap(processor);
        HttpResponse res = get(endpoint, headers);
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
        List<StripeSource> cards = new List<StripeSource>();
        if (responseMap.get('data') != NULL) {
            cards = (List<StripeSource>) JSON.deserialize(cleanJson(JSON.serialize(responseMap.get('data'))), List<StripeSource>.class);
        }
        else if (responseMap.get('error') != NULL) {
            handleStripeError(res.getBody());
        }

        return cards;
    }

    /**
     * @deprecated
     * Runs in live mode.
     */
    public static List<StripeSource> getListAllCustomerBankAccounts(String stripeCustomerId) {
        return getListAllCustomerBankAccounts(stripeCustomerId, getLegacyPaymentProcessor());
    }

    public static List<StripeSource> getListAllCustomerBankAccounts(String stripeCustomerId, Payment_Processor__c processor) {
        String endpoint = CUSTOMER_URL + '/' + stripeCustomerId + '/sources?object=bank_account&limit=' + RECEIVE_STRIPE_SOURCES_LIMIT;
        Map<String, String> headers = populateHeaderMap(processor);
        HttpResponse res = get(endpoint, headers);
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
        List<StripeSource> bankAccounts = new List<StripeSource>();
        if (responseMap.get('data') != NULL) {
            bankAccounts = (List<StripeSource>) JSON.deserialize(cleanJson(JSON.serialize(responseMap.get('data'))), List<StripeSource>.class);
        }
        else if (responseMap.get('error') != NULL) {
            handleStripeError(res.getBody());
        }

        return bankAccounts;
    }

    /**
     * @deprecated
     * Runs in live mode.
     */
    public static StripeSource getDuplicatedStripeSourceIfExists(String stripeCustomerId, StripeSourceToken sToken) {
        return getDuplicatedStripeSourceIfExists(stripeCustomerId, sToken, getLegacyPaymentProcessor());
    }

    public static StripeSource getDuplicatedStripeSourceIfExists(
            String stripeCustomerId, 
            StripeSourceToken sToken, 
            Payment_Processor__c processor) {

        List<StripeService.StripeSource> existedSources;
        StripeService.StripeSourceToken stripeSourceToken = getStripeSourceToken(sToken.id, processor);
        if (stripeSourceToken.card != NULL) {//Source is a Card
            existedSources = getListAllCustomerCards(stripeCustomerId, processor);
            for (StripeService.StripeSource existedCard : existedSources) {
                if (stripeSourceToken.card.fingerprint == existedCard.fingerprint
                        && stripeSourceToken.card.exp_month == existedCard.exp_month
                        && stripeSourceToken.card.exp_year == existedCard.exp_year) {

                    //if the same fingerprint and expiration date - return existed Stripe card
                    return existedCard;
                }
            }
        }
        else if (stripeSourceToken.bank_account != NULL) {//Source is a Bank Account
            existedSources = getListAllCustomerBankAccounts(stripeCustomerId, processor);
            for (StripeService.StripeSource existedBankAccount : existedSources) {
                if (stripeSourceToken.bank_account.fingerprint == existedBankAccount.fingerprint) {
                    //if the same fingerprint - return existed Stripe Bank Account
                    return existedBankAccount;
                }
            }
        }

        return NULL;
    }

    /**
     * @deprecated
     * Runs in live mode.
     */
    public static StripeSourceToken getStripeSourceToken(String stripeSourceTokenId) {
        return getStripeSourceToken(stripeSourceTokenId, getLegacyPaymentProcessor());
    }

    public static StripeSourceToken getStripeSourceToken(String stripeSourceTokenId, Payment_Processor__c processor) {
        String endpoint = TOKEN_URL + '/' + stripeSourceTokenId;
        Map<String, String> headers = populateHeaderMap(processor);
        HttpResponse res = get(endpoint, headers);
        StripeSourceToken token = (StripeSourceToken) JSON.deserialize(cleanJson(res.getBody()), StripeSourceToken.class);
        if (token.id == NULL) {
            handleStripeError(res.getBody());
        }

        return token;
    }

    /**
     * @deprecated
     * Runs in live mode.
     */
    public static StripeService.StripeCharge createCharge(  
            String stripeCustomerId,
            String stripeSourceId,
            Decimal amount,
            String currencyISOCode,
            String description,
            String idempotencyKey) {

        return createCharge(
            stripeCustomerId, 
            stripeSourceId, 
            amount,
            currencyISOCode, 
            description, 
            idempotencyKey, 
            getLegacyPaymentProcessor()
        );
    }

    public static StripeService.StripeCharge createCharge(  
            String stripeCustomerId,
            String stripeSourceId,
            Decimal amount,
            String currencyISOCode,
            String description,
            String idempotencyKey,
            Payment_Processor__c processor) {

        StripeService.StripeCharge result;

        String endpoint = CHARGE_URL;
        Map<String, String> headers = populateHeaderMap(processor);
        setHeaderIdempotencyKey(headers, idempotencyKey);

        Map<String, String> data = new Map<String, String>{
            'customer' => stripeCustomerId,
            'source' => stripeSourceId,
            'amount' => String.valueOf(prepareAmountForStripe(amount, currencyISOCode)),
            'description' => description
        };
        // set the default currency to USD if it's not specified
        data.put('currency', currencyISOCode.toLowerCase());

        HttpResponse res = post(endpoint, headers, data);
        Map<String, Object> chargeMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        if (chargeMap.get('id') != NULL) {
            result = (StripeService.StripeCharge) JSON.deserialize(
                cleanJson(res.getBody()),
                StripeService.StripeCharge.class
            );
        }
        else if (chargeMap.get('error') != NULL) {
            handleStripeError(res.getBody());
        }

        return result;
    }

    /**
     * @deprecated
     * Runs in live mode.
     */
    public static StripeService.StripeCharge getStripeCharge(String stripeSourceId) {
        return getStripeCharge(stripeSourceId, getLegacyPaymentProcessor());
    }

    public static StripeService.StripeCharge getStripeCharge(String stripeSourceId, Payment_Processor__c processor) {
        StripeService.StripeCharge result;

        String endpoint = CHARGE_URL + '/' + stripeSourceId;
        Map<String, String> headers = populateHeaderMap(processor);

        HttpResponse res = get(endpoint, headers);
        Map<String, Object> chargeMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        if (chargeMap.get('id') != NULL) {
            result = (StripeService.StripeCharge) JSON.deserialize(
                cleanJson(res.getBody()),
                StripeService.StripeCharge.class
            );
        }
        else if (chargeMap.get('error') != NULL) {
            handleStripeError(res.getBody());
        }

        return result;
    }

    /**
     * @deprecated
     * Runs in live mode.
     */
    public static StripeService.StripeCustomer createStripeCustomer(StripeSourceToken sToken, Map<String, String> metadataMap, String idempotencyKey) {
        return createStripeCustomer(sToken, metadataMap,idempotencyKey, getLegacyPaymentProcessor());
    }

    public static StripeService.StripeCustomer createStripeCustomer(
            StripeSourceToken sToken, 
            Map<String, String> metadataMap, 
            String idempotencyKey, 
            Payment_Processor__c processor) {

        String endpoint = CUSTOMER_URL;
        Map<String, String> headers = populateHeaderMap(processor);

        //required params
        Map<String, String> data = new Map<String, String>();

        if (sToken !=  null && sToken.id != null) {
            data.put('source', sToken.id);
        }

        //optional params
        if (metadataMap != NULL) {
            if(metadataMap.containsKey('Name')){
                data.put('name',metadataMap.get('Name'));
            }
            for (String metadataMapKey : metadataMap.keySet()) {
                data.put('metadata[' + metadataMapKey + ']', metadataMap.get(metadataMapKey));
            }
        }

        HttpResponse res = post(endpoint, headers, data);
        //convert response to Apex representation of Stripe Customer
        StripeService.StripeCustomer newCustomer =
            (StripeService.StripeCustomer) JSON.deserialize(cleanJson(res.getBody()), StripeService.StripeCustomer.class);

        if (newCustomer.Id == NULL) {
            handleStripeError(res.getBody());
        }

        return newCustomer;
    }

    /**
     * @deprecated
     * Runs in live mode.
     */
    public static StripeService.StripeCustomer updateStripeCustomer(String stripeCustomerId, Map<String, String> customerData) {
        return updateStripeCustomer(stripeCustomerId, customerData, getLegacyPaymentProcessor());
    }

    public static StripeService.StripeCustomer updateStripeCustomer(
            String stripeCustomerId, 
            Map<String, String> customerData, 
            Payment_Processor__c processor) {

        String endpoint = CUSTOMER_URL + '/' + stripeCustomerId;
        Map<String, String> headers = populateHeaderMap(processor);
        HttpResponse res = post(endpoint, headers, customerData);
        //convert response to Apex representation of Stripe Customer
        StripeService.StripeCustomer updatedCustomer = (StripeService.StripeCustomer) JSON.deserialize(cleanJson(res.getBody()), StripeService.StripeCustomer.class);

        if (updatedCustomer.Id == NULL) {
            handleStripeError(res.getBody());
        }

        return updatedCustomer;
    }

    /**
     * @deprecated
     * Runs in live mode.
     */
    public static StripeSourceToken createStripeSourceToken(Map<String, String> creditCardInfo) {
        return createStripeSourceToken(creditCardInfo, getLegacyPaymentProcessor());
    }

    public static StripeSourceToken createStripeSourceToken(Map<String, String> creditCardInfo, Payment_Processor__c processor) {
        String endpoint = TOKEN_URL;
        Map<String, String> headers = populateHeaderMap(processor);

        Map<String, String> data = new Map<String, String>();
        data.put('card[name]', creditCardInfo.get('name'));
        data.put('card[number]', creditCardInfo.get('number'));
        data.put('card[exp_month]', creditCardInfo.get('exp_month'));
        data.put('card[exp_year]', creditCardInfo.get('exp_year'));
        data.put('card[cvc]', creditCardInfo.get('cvc'));

        HttpResponse res = post(endpoint, headers, data);
        StripeSourceToken token = (StripeSourceToken) JSON.deserialize(cleanJson(res.getBody()), StripeSourceToken.class);
        if (token.id == NULL) {
            handleStripeError(res.getBody());
        }
        return token;
    }

    /**
     * @deprecated
     * Runs in live mode.
     */
    public static StripeSource createStripeSource(String stripeCustomerId, StripeSourceToken sToken, String idempotencyKey) {
        return createStripeSource(stripeCustomerId, sToken, idempotencyKey, getLegacyPaymentProcessor());
    }

    public static StripeSource createStripeSource(
            String stripeCustomerId, 
            StripeSourceToken sToken, 
            String idempotencyKey, 
            Payment_Processor__c processor) {

        String endpoint = CUSTOMER_URL + '/' + stripeCustomerId + '/sources';
        Map<String, String> headers = populateHeaderMap(processor);
        
        Map<String, String> data = new Map<String, String>();
        data.put('source', sToken.id);
        HttpResponse res = post(endpoint, headers, data);
        StripeSource newStripeSource = (StripeSource) JSON.deserialize(cleanJson(res.getBody()), StripeSource.class);

        if (newStripeSource.id == NULL) {
            handleStripeError(res.getBody());
        }

        return newStripeSource;
    }

    /**
     * @deprecated
     * Runs in live mode.
     */
    public static StripeSource verifyStripeBankAccount(String stripeCustomerId, String bankAccountId, String firstDeposit, String secondDeposit) {
        return verifyStripeBankAccount(
            stripeCustomerId, 
            bankAccountId, 
            firstDeposit, 
            secondDeposit, 
            getLegacyPaymentProcessor()
        );
    }

    public static StripeSource verifyStripeBankAccount(
            String stripeCustomerId, 
            String bankAccountId, 
            String firstDeposit, 
            String secondDeposit, 
            Payment_Processor__c processor) {

        String endpoint = CUSTOMER_URL + '/' + stripeCustomerId + '/sources/' + bankAccountId + '/verify';
        Map<String, String> headers = populateHeaderMap(processor);

        String requestBody =
            '&' +
                EncodingUtil.urlEncode('amounts[]', 'UTF-8') + '=' + EncodingUtil.urlEncode(firstDeposit, 'UTF-8') +
                '&' +
                EncodingUtil.urlEncode('amounts[]', 'UTF-8') + '=' + EncodingUtil.urlEncode(secondDeposit, 'UTF-8');

        HttpResponse res = post(endpoint, headers, requestBody);
        StripeSource verifiedBankAccount = (StripeSource) JSON.deserialize(cleanJson(res.getBody()), StripeSource.class);

        if (verifiedBankAccount.id == NULL) {
            handleStripeError(res.getBody());
        }

        return verifiedBankAccount;
    }

    /**
     * @deprecated
     * Runs in live mode.
     */
    public static StripeSource updateStripeSource(String stripeCustomerId, String stripeSourceId, Map<String, String> updParams, Map<String, String> metadataMap) {
        return updateStripeSource( stripeCustomerId, stripeSourceId, updParams, metadataMap, getLegacyPaymentProcessor());
    }

    public static StripeSource updateStripeSource(
            String stripeCustomerId, 
            String stripeSourceId, 
            Map<String, String> updParams, 
            Map<String, String> metadataMap, 
            Payment_Processor__c processor) {

        String endpoint = CUSTOMER_URL + '/' + stripeCustomerId + '/sources/' + stripeSourceId;
        Map<String, String> headers = populateHeaderMap(processor);

        Map<String, String> data = new Map<String, String>();
        //optional params
        if (updParams != NULL) {
            for (String key : updParams.keySet()) {
                data.put(key, updParams.get(key));
            }
        }
        //metadata params
        if (metadataMap != NULL) {
            for (String metadataMapKey : metadataMap.keySet()) {
                data.put('metadata[' + metadataMapKey + ']', metadataMap.get(metadataMapKey));
            }
        }

        HttpResponse res = post(endpoint, headers, data);

        StripeSource updatedSource = (StripeSource) JSON.deserialize(cleanJson(res.getBody()), StripeSource.class);

        if (updatedSource.id == NULL) {
            handleStripeError(res.getBody());
        }

        return updatedSource;
    }

    /**
     * @deprecated
     * Runs in live mode.
     */
    public static StripeSource deleteStripeSource(String stripeCustomerId, String stripeSourceId) {
        return deleteStripeSource(stripeCustomerId, stripeSourceId, getLegacyPaymentProcessor());
    }

    public static StripeSource deleteStripeSource(String stripeCustomerId, String stripeSourceId, Payment_Processor__c processor) {
        String endpoint = CUSTOMER_URL + '/' + stripeCustomerId + '/sources/' + stripeSourceId;
        Map<String, String> headers = populateHeaderMap(processor);
        HttpResponse res = del(endpoint, headers);
        StripeSource deletedSource = (StripeSource) JSON.deserialize(cleanJson(res.getBody()), StripeSource.class);
        if (deletedSource.id == NULL) {
            handleStripeError(res.getBody());
        }
        return deletedSource;
    }

    /**
     * @deprecated
     * Reads from accounting settings. Instead read from payment_processor__c record.
     */
    public static String getConnectedAccountId() {
        return AccountingSettingsHandler.getAccountingSettings().Stripe_Connected_Account_Id__c;
    }

    public static Payment_Processor__c getLegacyPaymentProcessor() {
        if (checkStripeConnectedId()) {
            throw new StripeServiceException('Stripe Connected Account Id is not set in Accounting Settings.');
        }
        return new Payment_Processor__c(
            Test_Mode__c = false,
            Connected_Account_Token__c = getConnectedAccountId()
        );
    }

    private static void handleStripeError(String response) {
        StripeError stripeError = (StripeError) JSON.deserialize(response, StripeService.StripeError.class);
        throw new StripeServiceException(stripeError);
    }
    
    private static Map<String, String> populateHeaderMap(Payment_Processor__c processor) {
        Map<String, String> headers = new Map<String, String>();
        String connectedAccountId = getConnectedAccountId();
        
        if (processor.Test_Mode__c) {
            headers.put('Authorization', prepareAuthorizationHeader(TEST_PLATFORM_SECRET_KEY));
        } 
        else {
            headers.put('Authorization', prepareAuthorizationHeader(PLATFORM_SECRET_KEY));
        }

        if (String.isNotBlank(processor.Connected_Account_Token__c)) {
            headers.put('Stripe-Account', processor.Connected_Account_Token__c);
        }

        return headers;
    }
    private static String prepareAuthorizationHeader(String apiKey) {
        Blob headerValue = Blob.valueOf(apiKey + ':');
        String authorizationHeader = 'BASIC ' + EncodingUtil.base64Encode(headerValue);
        return authorizationHeader;
    }
    private static void setHeaderIdempotencyKey(Map<String, String> headers, String idempotencyKey) {
        if (!String.isBlank(idempotencyKey)) {
            headers.put('Idempotency-Key', idempotencyKey);
        }
    }
    private static String blankValue(String s1, String s2) {
        if (s1 == NULL || s1 == '') {
            return s2;
        }
        return s1;
    }

    @TestVisible
    private static HttpResponse post(String url, Map<String, String> headers, Map<String, String> data) {
        String body = '&';
        for (String key : data.keySet()) {
            body += EncodingUtil.urlEncode(key, 'UTF-8') + '=' + EncodingUtil.urlEncode(blankValue(data.get(key), ''), 'UTF-8') + '&';
        }
        return post(url, headers, body);
    }

    @TestVisible
    private static HttpResponse post(String url, Map<String, String> headers, String body) {
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        if (headers != NULL) {
            for (String k : headers.keySet()) {
                req.setHeader(k, headers.get(k));
            }
        }
        req.setEndpoint(url);
        req.setBody(body);
        return h.send(req);
    }

    @TestVisible
    private static HttpResponse get(String url, Map<String, String> headers) {
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        if (headers != NULL) {
            for (String key : headers.keySet()) {
                req.setHeader(key, headers.get(key));
            }
        }
        req.setEndpoint(url);
        return h.send(req);
    }

    @TestVisible
    private static HttpResponse del(String url, Map<String, String> headers) {
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setMethod('DELETE');
        if (headers != NULL) {
            for (String key : headers.keySet()) {
                req.setHeader(key, headers.get(key));
            }
        }
        req.setEndpoint(url);
        return h.send(req);
    }

    //some of the JSON keys have names which are reserved keywords in APEX
    //that is why we need substitute some of them
    public static String cleanJson(String json) {
        json = json.replaceAll('"object":', '"stripeObject":');
        json = json.replaceAll('"data":', '"stripeData":');
        json = json.replaceAll('"currency":', '"stripeCurrency":');
        return json;
    }

    /**
     * @deprecated
     * Checks `Accounting_Settings__c.Stripe_Connected_Account_Id__c`.
     * Should check `Payment_Processor__c.Connected_Account_Token__c`.
     */
    public static Boolean checkStripeConnectedId() {
        return String.isBlank(getConnectedAccountId());
    }

    public static Integer prepareAmountForStripe(Decimal sfAmount, String currencyIsoCode) {
        Integer result;
        //check if given amount belongs to the "Zero-decimal currencies" group
        if (!ZERO_DECIMAL_CURRENCIES.contains(currencyIsoCode)) {
            //convert amount to a currency’s smallest unit
            result = Integer.valueOf(sfAmount * 100);
        }
        else {
            result = Integer.valueOf(sfAmount);
        }
        return result;
    }


    //Inner classes
    public with sharing class StripeSourceMetadata {
        public String status;
    }

    public with sharing class StripeCustomer {
        public String id;
        public String stripeObject;
        public String default_source;
        public String description;
        public StripeCustomerSources sources;
    }

    public with sharing class StripeCustomerSources {
        public String stripeObject;
        public List<StripeSource> stripeData;
    }

    //This inner class represents unified Stripe source object which can be either Stripe Card or Stripe Bank Account
    public with sharing class StripeSource {
        public String id;
        public String stripeObject;
        public String account_holder_name;
        public String account_holder_type;
        public String bank_name;
        public String country;
        public String fingerprint;
        public String last4;
        public String status;//Possible values are new, validated, verified, verification_failed, or errored.
        public String routing_number;
        public String customer;
        public String brand;
        public Integer exp_month;
        public Integer exp_year;
        public String name;
        public StripeSourceMetadata metadata;

        public String getCompositeKey(String sfAccountId) {
            String pmCompositeKey;

            if (stripeObject == 'card') {
                pmCompositeKey = sfAccountId + brand + ((String.valueOf(exp_month).length() < 2) ? '0' + String.valueOf(exp_month) : String.valueOf(exp_month)) + exp_year + last4;
            }
            else if (stripeObject == 'bank_account') {
                pmCompositeKey = sfAccountId + bank_name + last4;
            }

            return pmCompositeKey;
        }

        public String getCombinedSourceName() {
            String namePart = (String.isNotBlank(this.name)) ? this.name + ' ' : '';
            String brandPart = '';
            switch on stripeObject {
                when 'card' {
                    brandPart += (String.isNotBlank(this.brand) ? this.brand + ' ' : '');
                }
                when 'bank_account' {
                    brandPart += (String.isNotBlank(this.bank_name) ? this.bank_name + ' ' : '');
                }
            }
            return namePart + brandPart + (String.isNotBlank(this.last4) ? this.last4 : '');
        }
    }

    public with sharing class StripeCharge {
        public String id;
        public Decimal amount;/*
        A positive integer representing how much to charge in the smallest currency unit
        (e.g., 100 cents to charge $1.00 or 100 to charge ¥100, a zero-decimal currency).
        */
        public String stripeCurrency;
        public String description;
        public String status;//The status of the payment is either succeeded, pending, or failed
        public String failure_code;
        public String failure_message;
        public StripeSource source;

        public Decimal getAmountInDefaultCurrencyUnits() {
            Decimal result;
            //check if current currency belongs to the "Zero-decimal currencies" group
            if (!ZERO_DECIMAL_CURRENCIES.contains(stripeCurrency.toUpperCase())) {
                //convert amount to a currency’s smallest unit
                result = amount / 100;
            }
            else {
                result = amount;
            }
            return result;
        }
    }

    public with sharing class StripeError {
        public StripeErrorDetails error;

        public String getMessage() {
            if (error.param == 'currency'
                    && error.type == 'invalid_request_error'
                    && !String.isBlank(error.message)
                    && error.message.startsWith('Invalid currency:')) {

                return Label.ERR_CURRENCY_NOT_SUPPORTED_BY_STRIPE;
            } else if (error.type == IDEMPOTENCY_ERROR) {
                String msg = Label.ERR_PAYMENTS_DUPLICATE_FOUND;
                msg += String.isBlank(error.request_log_url) ? '' : ' ' + error.request_log_url;
                return msg;
            }
            return error.message;
        }
    }

    public with sharing class StripeErrorDetails {
        public String type;
        public String message;
        public String code;
        public String param;
        public String decline_code;
        public String request_log_url;
    }

    public with sharing class StripeSourceToken {
        public String id;
        public String type;//Type of the token: account, bank_account, card, or pii
        public StripeService.StripeSource card;
        public StripeService.StripeSource bank_account;
    }

    public class StripeServiceException extends Exception {
        public StripeError stripeErrorObj;

        public StripeServiceException(StripeError stripeErrorObj) {
            this(stripeErrorObj.getMessage());//not "super" keyword because Exception is a special case
            this.stripeErrorObj = stripeErrorObj;
        }
    }

}