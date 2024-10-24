/**
 * This class is used to make calls to the cardknox API.
 */
public with sharing class CardknoxService {
    /* Constants */
    public static final String UNPACKAGED = 'Unpackaged';
    public static final String SOFTWARE_NAME = 'Accounting Seed';
    public static final String XVERSION = GlobalVariables.cardknoxSettings.Value_3__c; 
    private static final String COMMON_NONE = 'None';
    private static final String CC_FLAT_FEE = PaymentProcessorActions.CC_FLAT_FEE;
    private static final String CC_PERCENT = PaymentProcessorActions.CC_PERCENT;
    private static final String METHOD_CREDIT_CARD = PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE;
    public static final String PAYMENT_METHOD_STATUS_ACTIVE = Label.COMMON_ACTIVE;
    public static final String PAYMENT_METHOD_STATUS_INACTIVE = Label.COMMON_INACTIVE;

    // cardknox api request/response options
    public static final String RESP_SUCCESS_CODE = 'S';
    public static final String RESP_ERROR_CODE = 'E';
    
    public static final String RESP_RESULT_APPROVED = 'Approved';
    public static final String RESP_RESULT_ERROR = 'Error';
    public static final String RESP_RESULT_DECLINED = 'Declined';

    public static final String COMMAND_CC_SALE = 'CC:Sale';
    public static final String COMMAND_CHECK_SALE = 'Check:Sale';

    public static final String STATUS_PENDING = '0';
    public static final String STATUS_AWAITING_RESPONSE = '6';
    public static final String STATUS_CHARGEBACK = '14';
    public static final String STATUS_SETTLED = '16';

    // if cardknox does not pass back a currency code for a transaction it means the currency is USD
    private static final String DEFAULT_CURRENCY = 'USD';
    //cc void 
    private static final String CC_VOID = 'cc:void';
    private static final String CHECK_VOID = 'check:void';

    public static String SOFTWARE_VERSION {
        get {
            if (SOFTWARE_VERSION == null) {
                if(!Test.isRunningTest()){
                    SOFTWARE_VERSION = AccountingHomeHelper.getPackageVersion();
                }else{
                    SOFTWARE_VERSION = UNPACKAGED;
                }
                return SOFTWARE_VERSION;
            }
            else {
                return SOFTWARE_VERSION;
            }
        }
        private set;
    }
    
    //cardknox host url
    @TestVisible
    private static final String CUSTOMER_ENDPOINT = 'https://api.cardknox.com/v2/';
    //cardknox reporting url
    public static final String REPORT_ENDPOINT = 'https://x1.cardknox.com/reportjson';
    //cardknox gatewayjoson url
    public static final String GATEWAY_ENDPOINT = 'https://x1.cardknox.com/gatewayjson';

    private static final String EST_TIMEZONE = 'America/New_York';
    private static final String REQUEST_DATETIME_FORMAT = 'yyyy-MM-dd HH:mm:ss';
    private static final String RESPONSE_DATETIME_REGEX = '(\\s|\\/|:)';
    private static final String MERIDIEM_AM = 'AM';
    private static final String MERIDIEM_PM = 'PM';

    /**
     * Create an cardknox customer with the provided metadata
    */
    public static Customer createCardknoxCustomer(Map<String, String> metadata,Payment_Processor__c pp) {
        String endpoint = CUSTOMER_ENDPOINT + 'CreateCustomer';
        Map<String, String> headers = headers(pp);

        Map<String, Object> data = body();

        data.put('BillCompany',metadata.get('Name'));
        data.put('BillPhone',metadata.get('BillPhone'));
        data.put('Email',metadata.get('BillEmail'));
        data.put('BillFirstName',metadata.get('BillFirstName'));
        data.put('BillLastName',metadata.get('BillLastName'));
        data.put('ShipPhone',metadata.get('ShipPhone'));
        data.put('ShipEmail',metadata.get('ShipEmail'));
        data.put('ShipFirstName',metadata.get('ShipFirstName'));
        data.put('ShipLastName',metadata.get('ShipLastName'));
        data.put('BillStreet',metadata.get('BillStreet'));
        data.put('BillCity',metadata.get('BillCity'));
        data.put('BillState',metadata.get('BillState'));
        data.put('BillZip',metadata.get('BillZip'));
        data.put('BillCountry',metadata.get('BillCountry'));
        data.put('ShipStreet',metadata.get('ShipStreet'));
        data.put('ShipCity',metadata.get('ShipCity'));
        data.put('ShipState',metadata.get('ShipState'));
        data.put('ShipZip',metadata.get('ShipZip'));
        data.put('ShipCountry',metadata.get('ShipCountry'));
        data.put('CustomerNumber',metadata.get('AccountId'));
        
        HttpResponse res = post(endpoint, headers, data);

        Customer newCustomer = (Customer) JSON.deserialize(res.getBody(), Customer.class);
        return newCustomer;
    }
    /**
     * gets a specific customer that matches to the provided customer Id
    */
    public static Customer getCardknoxCustomer(String customerId,Payment_Processor__c pp) {
        String endpoint = CUSTOMER_ENDPOINT + 'GetCustomer';
        Map<String, String> headers = headers(pp);
        

        Map<String, Object> data = body();

        data.put('CustomerId',customerId);
        
        HttpResponse res = post(endpoint, headers, data);

        Customer newCustomer = (Customer) JSON.deserialize(res.getBody(), Customer.class);
        return newCustomer;
    }
    /**
     * deletes a specific customer that matches to the provided customer Id
    */
    public static Customer deleteCardknoxCustomer(String customerId,Payment_Processor__c pp) {
        String endpoint = CUSTOMER_ENDPOINT + 'DeleteCustomer';
        Map<String, String> headers = headers(pp);
        
        Map<String, Object> data = body();

        data.put('CustomerId',customerId);
        
        HttpResponse res = post(endpoint, headers, data);

        Customer newCustomer = (Customer) JSON.deserialize(res.getBody(), Customer.class);
        return newCustomer;
    }
    /**
     * Create a payment method for the customer
     * testdatasuit
    */
    public static PaymentMethod createPaymentMethod(String customerId,Payment_Method__c payMethod,String token,Payment_Processor__c pp) {
        String endpoint = CUSTOMER_ENDPOINT + 'CreatePaymentMethod';
        Map<String, String> headers = headers(pp);
        
        String exp = '';
        if (payMethod.Payment_Method_Type__c != 'Bank' 
                && String.isNotBlank(payMethod.Expiration_Month__c) 
                && String.isNotBlank(payMethod.Expiration_Year__c)) {
                    
            String expMonth = payMethod.Expiration_Month__c.length() >= 2
                ? payMethod.Expiration_Month__c.right(2)
                : payMethod.Expiration_Month__c.leftPad(2,'0');
            String expYear = payMethod.Expiration_Year__c.right(2);
            exp = expMonth + expYear;
        }

        Map<String, Object> data = body();
        data.put('CustomerId',customerId);
        data.put('Token',token);
        data.put('TokenType',payMethod.Payment_Method_Type__c == 'Bank' ? 'check' : 'cc');
        data.put('Exp',exp);
        data.put('Routing',payMethod.Payment_Method_Type__c == 'Bank' ? payMethod.Routing_Number__c : '');
        data.put('Name',payMethod.Card_Holder_Name__c);
        
        HttpResponse res = post(endpoint, headers, data);

        PaymentMethod newPaymentMethod = (PaymentMethod) JSON.deserialize(res.getBody(), PaymentMethod.class);
        return newPaymentMethod;
    }
    /**
     * Delete a payment method for the customer
    */
    public static PaymentMethod deletePaymentMethod(String paymentMethodId,Payment_Processor__c pp) {
        String endpoint = CUSTOMER_ENDPOINT + 'DeletePaymentMethod';
        Map<String, String> headers = headers(pp);
        

        Map<String, Object> data = body();
        data.put('PaymentMethodId',paymentMethodId);
        
        HttpResponse res = post(endpoint, headers, data);

        PaymentMethod deletePaymentMethod = (PaymentMethod) JSON.deserialize(res.getBody(), PaymentMethod.class);
        return deletePaymentMethod;
    }
     /**
     * Get a payment method for the customer
    */
    public static PaymentMethod getPaymentMethod(String paymentMethodId,Payment_Processor__c pp) {
        String endpoint = CUSTOMER_ENDPOINT + 'GetPaymentMethod';
        Map<String, String> headers = headers(pp);
        

        Map<String, Object> data = body();
        data.put('PaymentMethodId',paymentMethodId);
        
        HttpResponse res = post(endpoint, headers, data);

        PaymentMethod newPaymentMethod = (PaymentMethod) JSON.deserialize(res.getBody(), PaymentMethod.class);
        return newPaymentMethod;
    }
    /**
     * Update a payment method for the customer
    */
    public static PaymentMethod updatePaymentMethod(Payment_Method__c paymentMethod,Map<String, String> payload,Payment_Processor__c pp) {
        String endpoint = CUSTOMER_ENDPOINT + 'UpdatePaymentMethod';
        Map<String, String> headers = headers(pp);
        
        PaymentMethod payMethod = CardknoxService.getPaymentMethod(paymentMethod.External_Id__c,pp);

        Map<String, Object> data = body();

        if (payload != NULL) {
            for (String key : payload.keySet()) {
                data.put(key, payload.get(key));
            }
        }
        data.put('Revision',payMethod.Revision);
        data.put('PaymentMethodId',paymentMethod.External_Id__c);
        data.put('SetAsDefault', paymentMethod.Default__c == true ? 'true' : 'false');

        
        HttpResponse res = post(endpoint, headers, data);

        PaymentMethod newPaymentMethod = (PaymentMethod) JSON.deserialize(res.getBody(), PaymentMethod.class);
        return newPaymentMethod;
    }
    /**
     * List Payment methods
    */
    public static ListPaymentMethod listPaymentMethods(String customerId,Payment_Processor__c pp) {
        String endpoint = CUSTOMER_ENDPOINT + 'ListPaymentMethods';
        Map<String, String> headers = headers(pp);
        
        Map<String, Object> data = body();
        Map<String, Object> filters = new Map<String, Object>();
        
        filters.put('CustomerId',customerId);
        filters.put('IsDeleted',false);
        
        data.put('Filters',filters);
        
        HttpResponse res = post(endpoint, headers, data);

        ListPaymentMethod newListPaymentMethod = (ListPaymentMethod) JSON.deserialize(res.getBody(), ListPaymentMethod.class);
        return newListPaymentMethod;
    }
    /**
     * process the transaction for the provided customer
    */
    public static PaymentTransaction doProcessTransaction(
            PaymentSaleItem saleItem,
            String currencyCode,
            Payment_Processor__c pp) {
        String endpoint = CUSTOMER_ENDPOINT + 'ProcessTransaction';
        Map<String, String> headers = headers(pp);
        
        Map<String, Object> data = body();


        if(pp.Convenience_Fee_Mapping__c != null 
                && pp.Original_Amount_Mapping__c != null
                && saleItem.cashReceipt.Convenience_Fees_Charged__c != null){
            // remove first character for this api call. i.e. xCustom09 => Custom09
            String convenienceFeeKey = pp.Convenience_Fee_Mapping__c.substring(1,pp.Convenience_Fee_Mapping__c.length());
            data.put(convenienceFeeKey, saleItem.cashReceipt.Convenience_Fees_Charged__c);
            
            String originalAmountKey = pp.Original_Amount_Mapping__c.substring(1,pp.Original_Amount_Mapping__c.length());
            data.put(originalAmountKey, saleItem.cashReceipt.Amount__c - saleItem.cashReceipt.Convenience_Fees_Charged__c);
        }
        data.put('Amount',saleItem.cashReceipt.Amount__c);
        data.put('PaymentMethodId',saleItem.paymentMethod.External_Id__c);
        data.put('Description',saleItem.cashReceipt.Description__c);
        data.put('Currency',currencyCode);
        
        if(saleItem.billings != null && saleItem.billings.size() == 1){
            data.put('Invoice', saleItem.billings[0].Name);
            data.put('Custom19', saleItem.billings[0].Id);
        }
        
        HttpResponse res = post(endpoint, headers, data);
        PaymentTransaction newProcessTransaction = (PaymentTransaction) JSON.deserialize(res.getBody(), PaymentTransaction.class);
        return newProcessTransaction;
    }
    /**
     * get the transaction for the provided transation
    */
    public static PaymentTransaction getTransaction(String transactionId,Payment_Processor__c pp) {
        String endpoint = CUSTOMER_ENDPOINT + 'GetTransaction';
        Map<String, String> headers = headers(pp);
        
        Map<String, Object> data = body();

        data.put('TransactionId',transactionId);
        
        HttpResponse res = post(endpoint, headers, data);

        PaymentTransaction newProcessTransaction = (PaymentTransaction) JSON.deserialize(res.getBody(), PaymentTransaction.class);
        return newProcessTransaction;
    }

    /**
     * to create a report of the responses
    */
    public static Report getTransactionReport(List<String> refNums,Payment_Processor__c pp) {
        String endpoint = REPORT_ENDPOINT;
        Map<String, String> headers = headers(pp);
        
        Map<String, Object> data = reportBody();

        data.put('xKey',getXKey(pp));
        data.put('xCommand','Report:Transactions');
        data.put('xVersion', XVERSION);
        data.put('xFields', 'xStatus,xName,xAmount,xEnteredDate,xResponseResult,xResponseError,xErrorCode,xProcessingFee,xResponseBatch,xInvoice,xCommand,xCustomerID,xCurrency,xRefNum,xCustom03,xCustom04,xCustom05,xCustom06,xCustom07,xCustom08,xCustom09,xCustom10,xCustom11,xCustom12,xCustom13,xCustom14,xCustom15,xCustom16,xCustom17,xCustom19');
        data.put('xRefnum', refNums == null ? '' : String.join(refNums, ','));
        
        HttpResponse res = post(endpoint, headers, data);

        Report newReport = (Report) JSON.deserialize(res.getBody(), Report.class);
        return newReport;
    }

    /**
     * Report Transactions
     */
    public static Report getTransactionsByInvoice(Set<Id> invoices,Payment_Processor__c pp) {
        String endpoint = REPORT_ENDPOINT;
        Map<String, String> headers = headers(pp);
        
        Map<String, Object> data = reportBody();
        data.put('xKey',getXKey(pp));
        data.put('xCommand','Report:Transactions');
        data.put('xVersion',XVERSION);
        data.put('xFields','xStatus,xName,xAmount,xEnteredDate,xResponseResult,xResponseError,xErrorCode,xProcessingFee,xResponseBatch,xInvoice,xCommand,xCustomerID,xCurrency,xRefNum,xCustom03,xCustom04,xCustom05,xCustom06,xCustom07,xCustom08,xCustom09,xCustom10,xCustom11,xCustom12,xCustom13,xCustom14,xCustom15,xCustom16,xCustom17,xCustom19');
        data.put('xInvoice',String.join(new List<Id>(invoices), ','));
        
        HttpResponse res = post(endpoint, headers, data);

        Report newReport = (Report) JSON.deserialize(res.getBody(), Report.class);
        return newReport;
    }

    /**
     * Report Transactions
     * 
     * startDate - UTC only
     * endDate - UTC only
     */
    public static Report getTransactions(Datetime startDate, Datetime endDate, Integer pageSize, Payment_Processor__c pp) {
        String endpoint = REPORT_ENDPOINT;
        Map<String, String> headers = headers(pp);
        
        Map<String, Object> data = reportBody();
        data.put('xKey',getXKey(pp));
        data.put('xCommand','Report:All');
        data.put('xVersion',XVERSION);
        data.put('xFields','xStatus,xName,xAmount,xEnteredDate,xResponseResult,xResponseError,xErrorCode,xProcessingFee,xResponseBatch,xInvoice,xCommand,xCustomerID,xCurrency,xRefNum,xCustom03,xCustom04,xCustom05,xCustom06,xCustom07,xCustom08,xCustom09,xCustom10,xCustom11,xCustom12,xCustom13,xCustom14,xCustom15,xCustom16,xCustom17,xCustom19,xBillFirstName,xBillLastName,xBillCompany,xBillStreet,xBillCity,xBillState,xBillZip,xBillCountry');
        data.put('xBeginDate',toEST(startDate));
        data.put('xEndDate',toEST(endDate));
        data.put('xMaxRecords',pageSize);   // max records to return
        data.put('xGetNewest',false);       // oldest first
        
        HttpResponse res = post(endpoint, headers, data);

        Report newReport = (Report) JSON.deserialize(res.getBody(), Report.class);
        return newReport;
    }

    /**
     * to create a batch report of the responses
     * 
     * startDate - UTC only
     * endDate - UTC only
     */
    public static BatchReport getTransactionBatchReport(DateTime startDate, DateTime endDate,Payment_Processor__c pp) {
        String endpoint = REPORT_ENDPOINT;
        Map<String, String> headers = headers(pp);
        Map<String, Object> data = reportBody();

        data.put('xKey',getXKey(pp));
        data.put('xCommand','Report:Batch');
        data.put('xVersion',XVERSION);
        data.put('xBeginDate',toEST(startDate));
        data.put('xEndDate',toEST(endDate));
        
        HttpResponse res = post(endpoint, headers, data);

        BatchReport newBatchReport = (BatchReport) JSON.deserialize(res.getBody(), BatchReport.class);
        return newBatchReport;
    }
    /**
     * To void a transaction in cardknox
     * 
     * refNum payment Id to match the payment in cardknox
     * pp payment processor to get the keys
     * return - VoidReport
     */
    public static VoidReport voidTransaction(Payment_Activity__c paymentActivity, Payment_Processor__c pp){
        String endpoint = GATEWAY_ENDPOINT;
        Map<String, String> headers = headers(pp);
        Map<String, Object> data = reportBody();

        data.put('xKey',getXKey(pp));
        data.put('xVersion',XVERSION);
        data.put('xCommand',paymentActivity.Payment_Method_Type__c == PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE ? CC_VOID : CHECK_VOID);
        data.put('xRefNum',paymentActivity.Merchant_Reference__c);
        
        HttpResponse res = post(endpoint, headers, data);

        VoidReport voidReportData = (VoidReport) JSON.deserialize(res.getBody(), VoidReport.class);
        return voidReportData;
    }
    
    private static Map<String, String> headers(Payment_Processor__c pp) {
        Map<String, String> headers = new Map<String, String>();
        headers.put('Authorization', getXKey(pp));
        headers.put('X-Recurring-Api-Version', '2.0');
        headers.put('Content-Type', 'application/json');
    
        return headers;
    }

    private static Map<String,Object> body() {
        Map<String,Object> body = new Map<String,Object>();
        body.put('SoftwareName', SOFTWARE_NAME);
        body.put('SoftwareVersion', SOFTWARE_VERSION);
        return body;
    }

    private static Map<String,Object> reportBody() {
        Map<String,Object> body = new Map<String,Object>();
        body.put('xSoftwareName', SOFTWARE_NAME);
        body.put('xSoftwareVersion', SOFTWARE_VERSION);
        return body;
    }

    @TestVisible
    private static HttpResponse post(String url, Map<String, String> headers, Map<String, Object> data) {
        return post(url, headers, JSON.serialize(data));
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

    //return the available x key in the Keys__c custom setting
    private static String getXKey(Payment_Processor__c pp){
        if(String.isBlank(pp.External_Key__c) == true){
            throw new CardknoxServiceException(Label.CRDKNX_INVALID_XKEY);
        }
        Keys__c key = Keys__c.getValues(pp.External_Key__c);
        if(key == null || String.isBlank(key.Value_1__c) == true){
            throw new CardknoxServiceException(Label.CRDKNX_NO_XKEY);
        }
        return key.Value_1__c;
    }

    // convert from Cardknox date/time format
    // expects EST/New_York datetime in format MM/DD/YYYY HH:MM:SS AM/PM
    @TestVisible
    private static Datetime toUTC(DateTimeParser parser) {
        // collect date parts
        Integer month = parser.month();
        Integer day = parser.day();
        Integer year = parser.year();
        Integer hour = parser.hours();
        Integer min = parser.minutes();
        Integer sec = parser.seconds();
        String meridiem = parser.meridiem();

        // convert to 24 hour time
        if (meridiem == MERIDIEM_AM && hour == 12) { // 12 AM is hour 0 hour
            hour = 0;
        } else if (meridiem == MERIDIEM_PM && (hour >= 1 && hour < 12)) { // 1-11 PM is hour 13-23
            hour += 12;
        }

        // create datetime
        // The input date is in EST but Salesforce does not provide any
        // method to specifiy timezone. Using the GMT factory method here 
        // because the alternative method assumes GMT input and converts 
        // to user timezone. Working in GMT is easier to reason about.
        Datetime dt = Datetime.newInstanceGmt(year, month, day, hour, min, sec);

        // convert to EST, the original input timezone
        Timezone tz = Timezone.getTimeZone(EST_TIMEZONE);
        Long est = dt.getTime() - tz.getOffset(dt);
        // get the true UTC time. This factory method returns GMT time
        Datetime utc = Datetime.newInstance(est);

        return utc;
    }

    // convert to Cardknox date/time format
    // expectes UTC timzone input outputs EST/New_York datetime in format yyyy-MM-dd HH:mm:ss
    @TestVisible
    private static String toEST(Datetime utc) {
        Timezone tz = Timezone.getTimeZone(EST_TIMEZONE);
        Long offset = utc.getTime() + tz.getOffset(utc);
        // factory method uses GMT, prevents conversion to user timezone
        Datetime est = Datetime.newInstance(offset);
        // convert to format expected by Cardknox
        return est.formatGMT(REQUEST_DATETIME_FORMAT);
    }

    public with sharing class Customer {
        public String CustomerId;
        public String RefNum;
        public String Result;
        public String Error;
        public String DefaultPaymentMethodId;
    }
    public with sharing class AllCustomers {
        public List<Customer> Customers;
    }
    public with sharing class ListPaymentMethod {
        public String Result;
        public String Error;
        public List<PaymentMethod> PaymentMethods;
    }
    public with sharing class PaymentMethod {
        public String PaymentMethodId;
        public String CustomerId;
        public String MaskedNumber;
        public String Issuer;
        public String Exp;
        public String Name;
        public String Result;
        public String Error;
        public String Token;
        public String TokenType;
        public Integer Revision;
        public String CardType;

    }
    public with sharing class PaymentTransaction {
        public String GatewayStatus;
        public String GatewayRefNum;
        public String Result;
        public String GatewayErrorMessage;
        public String Error;
        public String RefNum;
    }
    public with sharing class Report {
        public String xStatus;
        public String xRefNum;
        public String xResult;
        public String xError;
        public String xRecordsReturned;
        public List<ReportData> xReportData;
    }
    public with sharing class ReportData {
        public String xRefNum;
        public String xErrorCode;
        public String xResponseError;
        public String xResponseResult;
        public String xCommand;
        public String xStatus;
        public String xResponseBatch;
        public String xInvoice;
        public String xCustomerID;
        public String xCurrency {
            get {
                if (String.isBlank(xCurrency)) {
                    // Cardknox says blank indicates USD
                    return DEFAULT_CURRENCY;
                }
                return xCurrency;
            }
            set {
                xCurrency = value;
            }
        }
        public String xEnteredDate;
        public Decimal xAmount;
        public Decimal xProcessingFee;
        public String xCustom19;
        public String xBillFirstName;
        public String xBillLastName;
        public String xBillCompany;
        public String xBillStreet;
        public String xBillCity;
        public String xBillState;
        public String xBillZip;
        public String xBillCountry;
        public String xVoid;
        public String xCustom03;
        public String xCustom04;
        public String xCustom05;
        public String xCustom06;
        public String xCustom07;
        public String xCustom08;
        public String xCustom09;
        public String xCustom10;
        public String xCustom11;
        public String xCustom12;
        public String xCustom13;
        public String xCustom14;
        public String xCustom15;
        public String xCustom16;
        public String xCustom17;

        // cardknox provides xEnteredDate
        //  - in a non-standard format
        //  - in the EST timezone
        public DateTime xEnteredDateUTC() {
            return toUTC(new LongFormDateTimeParser(xEnteredDate));
        }

        public String getCustomField(String name) {
            switch on name.toLowerCase() {
                when 'xcustom03' { return xCustom03; }
                when 'xcustom04' { return xCustom04; }
                when 'xcustom05' { return xCustom05; }
                when 'xcustom06' { return xCustom06; }
                when 'xcustom07' { return xCustom07; }
                when 'xcustom08' { return xCustom08; }
                when 'xcustom09' { return xCustom09; }
                when 'xcustom10' { return xCustom10; }
                when 'xcustom11' { return xCustom11; }
                when 'xcustom12' { return xCustom12; }
                when 'xcustom13' { return xCustom13; }
                when 'xcustom14' { return xCustom14; }
                when 'xcustom15' { return xCustom15; }
                when 'xcustom16' { return xCustom16; }
                when 'xcustom17' { return xCustom17; }
                when else { return null; }
            }
        }

        public Boolean isVoid() {
            return xVoid == '1';
        }
    }
    public with sharing class BatchReport{
        public String xResult;	
        public String xStatus;	
        public String xError;	
        public String xErrorCode;	
        public String xRefNum;	
        public String xAvsResultCode;	
        public String xAvsResult;	
        public String xCvvResultCode;	
        public String xCvvResult;	
        public String xRecordsReturned;	
        public BatchReportData[] xReportData;
        public String xAdditionalData;	
        public String xDate;
    }
    public with sharing class BatchReportData{
        public String xBatch;
		public String xBatchDate;
		public String xBatchTime;
		public String xTotalCount;
		public String xTotalAmount;
		public String xSaleCount;
		public String xSaleAmount;
		public String xVisaSaleCount;
		public String xVisaSaleAmount;
		public String xMCSaleCount;
		public String xMCSaleAmount;
		public String xAchSaleCount;
		public String xAchSaleAmount;

        // cardknox provides xBatchDate and xBatchTime
        //  - in a non-standard format
        //  - in the EST timezone
        public DateTime xBatchDateTimeUTC() {
            return toUTC(new ShortFormDateTimeParser(xBatchDate + ' ' + xBatchTime));
        }
    }
    
    public class CardknoxServiceException extends Exception {}

    @TestVisible
    private interface DateTimeParser {
        Integer year();
        Integer month();
        Integer day();
        Integer hours();
        Integer minutes();
        Integer seconds();
        String meridiem();
    }

    //void report data wrapper
    public with sharing class VoidReport {
        public String xResult;
        public String xErrorCode;
        public String xError;
        public String xRefNum;
        public String xRefNumCurrent;
        public String xExp;
        public String xDate;
        public String xMaskedCardNumber;
        public String xCardType;
        public String xAvsResultCode;
        public String xAvsResult;
        public String xCvvResultCode;
        public String xCvvResult;
        public String xAuthAmount;
        public String xMID;
        public String xTID;
        public String xCurrency;
        public String xEntryMethod;
        public String xMaskedAccountNumber;
        public String xName;
    }
    @TestVisible
    private class ShortFormDateTimeParser implements DateTimeParser {
        // [Month, Day, Year, Hours, Minutes, Meridiem]
        private String[] parts;

        // input: MM/DD/YYYY HH:MM AM/PM
        public ShortFormDateTimeParser(String cxShortFormDateTime) {
            this.parts = cxShortFormDateTime.split(RESPONSE_DATETIME_REGEX);
        }
        public Integer year() {
            return Integer.valueOf(parts[2]);
        }
        public Integer month() {
            return Integer.valueOf(parts[0]);
        }
        public Integer day() {
            return Integer.valueOf(parts[1]);
        }
        public Integer hours() {
            return Integer.valueOf(parts[3]);
        }
        public Integer minutes() {
            return Integer.valueOf(parts[4]);
        }
        public Integer seconds() {
            return 0;
        }
        public String meridiem() {
            return parts[5];
        }
    }

    @TestVisible
    private class LongFormDateTimeParser implements DateTimeParser {
        // [Month, Day, Year, Hours, Minutes, Seconds, Meridiem]
        private String[] parts;

        // input: MM/DD/YYYY HH:MM:SS AM/PM
        public LongFormDateTimeParser(String cxLongFormDateTime) {
            this.parts = cxLongFormDateTime.split(RESPONSE_DATETIME_REGEX);
        }
        public Integer year() {
            return Integer.valueOf(parts[2]);
        }
        public Integer month() {
            return Integer.valueOf(parts[0]);
        }
        public Integer day() {
            return Integer.valueOf(parts[1]);
        }
        public Integer hours() {
            return Integer.valueOf(parts[3]);
        }
        public Integer minutes() {
            return Integer.valueOf(parts[4]);
        }
        public Integer seconds() {
            return Integer.valueOf(parts[5]);
        }
        public String meridiem() {
            return parts[6];
        }
    }

}