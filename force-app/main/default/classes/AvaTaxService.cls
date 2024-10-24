public with sharing class AvaTaxService {

    /* Constants */
    public static final String PRODUCTION_ACTIVE_AVATAX_ENDPOINT = 'Production';

    public static final String SERVICE_URL = GlobalVariables.AVALARA_REST_ENDPOINT;
    public static final String AVALARA_ACCOUNT_ID = AccountingSettingsHandler.getAccountingSettings().Avalara_Account_Id__c;
    public static final String AVALARA_LICENSE_KEY = AccountingSettingsHandler.getAccountingSettings().Avalara_License_Key__c;

    private String avaTaxAccountId;
    private String avaTaxLicenseKey;
    private Boolean isProduction;
    private String serviceUrl;
    private String siteUrl;

    public AvaTaxService(String avaTaxAccountId, String avaTaxLicenseKey, Boolean isProduction) {
        this.avaTaxAccountId = avaTaxAccountId;
        this.avaTaxLicenseKey = avaTaxLicenseKey;
        this.isProduction = isProduction;

        this.serviceUrl = GlobalVariables.AVALARA_REST_ENDPOINT(isProduction);
        this.siteUrl = GlobalVariables.AVALARA_SITE_URL(isProduction);
    }

    /* Static Methods */
    public static PingResultModel ping() {
        return (new AvaTaxService(AvaTaxService.AVALARA_ACCOUNT_ID, AvaTaxService.AVALARA_LICENSE_KEY, AccountingSettingsHandler.getAccountingSettings()?.Avalara_Production_Endpoint__c)).pingInst();
    }

    public static FetchResultTransactionModel listTransactionsByCompany(String companyCode,
            List<String> docCodes,
            Date startDate,
            Date endDate,
            AvaTaxService.DocumentStatus status,
            List<String> includedNestedDataSets) {
        return (new AvaTaxService(AVALARA_ACCOUNT_ID, AVALARA_LICENSE_KEY, AccountingSettingsHandler.getAccountingSettings()?.Avalara_Production_Endpoint__c)).listTransactionsByCompanyInst(
                companyCode, docCodes, startDate, endDate, status, includedNestedDataSets
        );
    }

    public static AddressResolutionModel resolveAddress(AddressInfo addressToValidate) {
        return (new AvaTaxService(AVALARA_ACCOUNT_ID, AVALARA_LICENSE_KEY, AccountingSettingsHandler.getAccountingSettings()?.Avalara_Production_Endpoint__c)).resolveAddressInst(addressToValidate);
    }

    public static TransactionModel createOrAdjustTransaction(CreateOrAdjustTransactionModel requestObject) {
        return (new AvaTaxService(AVALARA_ACCOUNT_ID, AVALARA_LICENSE_KEY, AccountingSettingsHandler.getAccountingSettings()?.Avalara_Production_Endpoint__c)).createOrAdjustTransactionInst(requestObject);
    }

    public static void uncommitTransaction(String companyCode, String transactionCode, String accountId, String licenseKey) {
        (new AvaTaxService(accountId, licenseKey, AccountingSettingsHandler.getAccountingSettings()?.Avalara_Production_Endpoint__c)).uncommitTransactionInst(companyCode, transactionCode);
    }

    public PingResultModel pingInst() {
        String endpoint = serviceUrl + '/api/v2/utilities/ping';
        Map<String, String> headers = populateHeaderMap();
        PingResultModel pingResponse = (PingResultModel) JSON.deserialize(get(endpoint, headers).getBody(), PingResultModel.class);
        return pingResponse;
    }

    public FetchResultTransactionModel listTransactionsByCompanyInst(String companyCode,
                                                                        List<String> docCodes,
                                                                        Date startDate,
                                                                        Date endDate,
                                                                        AvaTaxService.DocumentStatus status,
                                                                        List<String> includedNestedDataSets) {


        String endpoint = serviceUrl + '/api/v2/companies/' + companyCode + '/transactions';

        String startDateStr = AvaTaxHelper.formatDate(startDate);
        String endDateStr = AvaTaxHelper.formatDate(endDate);

        String filterParam = '?$filter=';
        String includeParam = '&$include=';
        String filterParamValue =
            'code IN (' + String.join(docCodes, ',') + ') ' +
            'and date between ' + startDateStr + ' and ' + endDateStr + ' ' +
            'and status eq ' + status.name();
        String includeParamValue = (includedNestedDataSets != NULL) ? String.join(includedNestedDataSets, ',') : NULL;

        Map<String, String> headers = populateHeaderMap();

        String requestUrl = endpoint +
                            filterParam +
                            EncodingUtil.urlEncode(filterParamValue, 'UTF-8') +
                            ((includeParamValue != NULL) ? includeParam + includeParamValue : '');
        FetchResultTransactionModel result = (FetchResultTransactionModel) JSON.deserialize(get(requestUrl, headers).getBody(), FetchResultTransactionModel.class);
        return result;
    }

    public AddressResolutionModel resolveAddressInst(AddressInfo addressToValidate) {
        String endpoint = serviceUrl + '/api/v2/addresses/resolve';
        Map<String, String> headers = populateHeaderMap();
        AddressResolutionModel validationResponse =
            (AddressResolutionModel) JSON.deserialize(post(endpoint, headers, JSON.serialize(addressToValidate)).getBody(), AddressResolutionModel.class);
        return validationResponse;
    }

    public TransactionModel createOrAdjustTransactionInst(CreateOrAdjustTransactionModel requestObject) {
        //$include parameter: Lines
        String endpoint = serviceUrl + '/api/v2/transactions/createoradjust?$include=Lines';
        Map<String, String> headers = populateHeaderMap();
        TransactionModel transactionResponse =
            (TransactionModel) JSON.deserialize(cleanJsonResponse(post(endpoint, headers, cleanJsonRequest(JSON.serialize(requestObject))).getBody()), TransactionModel.class);
        return transactionResponse;
    }

    public TransactionModel addLines(AddLinesTransactionModel requestObject) {
        String endpoint = serviceUrl + '/api/v2/companies/transactions/lines/add?$include=Lines';
        Map<String, String> headers = populateHeaderMap();
        TransactionModel transactionResponse =
            (TransactionModel) JSON.deserialize(cleanJsonResponse(post(endpoint, headers, cleanJsonRequest(JSON.serialize(requestObject))).getBody()), TransactionModel.class);
        return transactionResponse;
    }

    public void uncommitTransactionInst(String companyCode, String transactionCode) {
        String endpoint = serviceUrl + '/api/v2/companies/' + companyCode + '/transactions/' + transactionCode + '/uncommit';
        Map<String, String> headers = populateHeaderMap();
        post(endpoint, headers, '');
        //Note: currently it is not necessary to return any data in this method
        //If such a need will arise:
        // - please take into account that response will contain full set of TransactionModel data
        // - including Lines with Details, Addresses, etc, so this will be potentially very long string
        // - currently there is no an ability to put $include parameter in this request
    }

    private Map<String, String> populateHeaderMap() {
        Map<String, String> headers = new Map<String, String>();
        headers.put('Content-Type', 'application/json');
        headers.put('Authorization', prepareAuthorizationHeader(this.avaTaxAccountId, this.avaTaxLicenseKey));
        headers.put('X-Avalara-Client', 'Accounting Seed Financial Suite');
        return headers;
    }

    private static void handleAvaTaxError(String response) {
        AvaTaxErrorResponse errorResponse = (AvaTaxErrorResponse) JSON.deserialize(response, AvaTaxErrorResponse.class);
        AvaTaxError atError = errorResponse.error;
        throw new AvaTaxException(atError);
    }

    private static String prepareAuthorizationHeader(String avaTaxAccountId, String avaTaxLicenseKey) {
        Blob headerValue = Blob.valueOf(avaTaxAccountId + ':' + avaTaxLicenseKey);
        String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
        return authorizationHeader;
    }

    @TestVisible
    private static HttpResponse get(String url, Map<String, String> headers) {
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setTimeout(120000);
        if (headers != NULL) {
            for (String key : headers.keySet()) {
                req.setHeader(key, headers.get(key));
            }
        }
        req.setEndpoint(url);
        return sendRequest(h, req);
    }

    @TestVisible
    private static HttpResponse post(String url, Map<String, String> headers, String body) {
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setTimeout(120000);
        if (headers != NULL) {
            for (String k : headers.keySet()) {
                req.setHeader(k, headers.get(k));
            }
        }
        req.setEndpoint(url);
        req.setBody(body);
        return sendRequest(h, req);
    }

    private static HttpResponse sendRequest(Http h, HttpRequest req) {
        HttpResponse response;
        Long beforeCall = System.now().getTime();
        response = HttpProxy.send(h, req);
        Long callTime = System.now().getTime() - beforeCall;
        if (!skipLogByHeapSizeLimit(req, response)) {
            keepCalloutLog(req.getMethod(), req.getBody(), response.getStatusCode(), response.getBody(), callTime);
        }
        validateResponseStatus(response);
        return response;
    }

    private static void validateResponseStatus(HttpResponse res) {
        if (res.getStatusCode() >= 400) {
            handleAvaTaxError(res.getBody());
        }
    }

    private static Boolean skipLogByHeapSizeLimit(HttpRequest req,  HttpResponse response) {
        Boolean skip = false;
        Integer estimatedHeapSize = (16 + 4 * req.getBody().length()) + (16 + 4 * response.getBody().length()) ;
        if ((Limits.getLimitHeapSize() - Limits.getHeapSize()) < estimatedHeapSize) {
            skip = true;
        }
        return skip;
    }

    private static void keepCalloutLog(String method, String requestBody, Integer statusCode, String responseBody, Long execTime) {
        String requestLogEntry = '';
        if (method.equalsIgnoreCase('POST')) {
            requestLogEntry = Label.INF_AVALARA_REQUEST + ': ' + requestBody;
        }

        String responseLogEntry = '\n' + Label.INF_AVALARA_RESPONSE + ': ' + responseBody;

        String logEntry =
            'Avalara Callout Log: \n' +
            'HTTP Method: ' + method + '\n' +
            'Call execution time: ' + execTime + 'ms\n' +
            'Response Status Code: ' + statusCode + '\n' +
                requestLogEntry + responseLogEntry;

        // System Debug required for Avalara - Support Callout Debugging. issue - FS-2360
        System.debug(logEntry);
    }

    private static String blankValue(String s1, String s2) {
        if (s1 == NULL || s1 == '') {
            return s2;
        }
        return s1;
    }

    //some of the JSON keys have names which are reserved keywords in APEX
    //that is why we need substitute some of them
    public static String cleanJsonResponse(String json) {
        json = json.replace('"date":', '"avaTaxDate":');
        return json;
    }

    public static String cleanJsonRequest(String json) {
        json = json.replace('"doCommit":', '"commit":');
        json = json.replace('"avaTaxDate":', '"date":');
        json = json.replace('"avaTaxNumber":', '"number":');
        return json;
    }

    public static final Map<String, String> STATE_ABBREVIATIONS = new Map<String, String>{
        'AL' => 'Alabama',
        'AK' => 'Alaska',
        'AS' => 'American Samoa',
        'AZ' => 'Arizona',
        'AR' => 'Arkansas',
        'CA' => 'California',
        'CO' => 'Colorado',
        'CT' => 'Connecticut',
        'DE' => 'Delaware',
        'DC' => 'District of Columbia',
        'FM' => 'Federated States of Micronesia',
        'FL' => 'Florida',
        'GA' => 'Georgia',
        'GU' => 'Guam',
        'HI' => 'Hawaii',
        'ID' => 'Idaho',
        'IL' => 'Illinois',
        'IN' => 'Indiana',
        'IA' => 'Iowa',
        'KS' => 'Kansas',
        'KY' => 'Kentucky',
        'LA' => 'Louisiana',
        'ME' => 'Maine',
        'MH' => 'Marshall Islands',
        'MD' => 'Maryland',
        'MA' => 'Massachusetts',
        'MI' => 'Michigan',
        'MN' => 'Minnesota',
        'MS' => 'Mississippi',
        'MO' => 'Missouri',
        'MT' => 'Montana',
        'NE' => 'Nebraska',
        'NV' => 'Nevada',
        'NH' => 'New Hampshire',
        'NJ' => 'New Jersey',
        'NM' => 'New Mexico',
        'NY' => 'New York',
        'NC' => 'North Carolina',
        'ND' => 'North Dakota',
        'MP' => 'Northern Mariana Islands',
        'OH' => 'Ohio',
        'OK' => 'Oklahoma',
        'OR' => 'Oregon',
        'PW' => 'Palau',
        'PA' => 'Pennsylvania',
        'PR' => 'Puerto Rico',
        'RI' => 'Rhode Island',
        'SC' => 'South Carolina',
        'SD' => 'South Dakota',
        'TN' => 'Tennessee',
        'TX' => 'Texas',
        'UT' => 'Utah',
        'VT' => 'Vermont',
        'VI' => 'Virgin Islands',
        'VA' => 'Virginia',
        'WA' => 'Washington',
        'WV' => 'West Virginia',
        'WI' => 'Wisconsin',
        'WY' => 'Wyoming'
    };


    public with sharing class PingResultModel {
        public String version {get; set;}
        public Boolean authenticated {get; set;}
        public String authenticationType {get; set;}
        public String authenticatedUserName {get; set;}
        public String authenticatedUserId {get; set;}
        public String authenticatedAccountId {get; set;}
        public String crmid {get; set;}
    }

    public with sharing class AddressResolutionModel {
        public AddressInfo address {get; set;}
        public List<AddressInfo> validatedAddresses {get; set;}
        public CoordinateInfo coordinates {get; set;}
        public List<TaxAuthorityInfo> taxAuthorities {get; set;}
        public List<AvaTaxMessage> messages {get; set;}
    }

    public with sharing class AddressInfo {
        public String addressType {get; set;}
        public String line1 {
            get;
            set {
                if (value != NULL && value.length() > 50) {
                    line1 = value.left(50);
                }
                else {
                    line1 = value;
                }
            }
        }

        public String line2 {get; set;}
        public String line3 {get; set;}
        public String city {get; set;}
        public String region {get; set;}
        public String country {get; set;}
        public String postalCode {get; set;}
        public Double latitude {get; set;}
        public Double longitude {get; set;}

        public AddressInfo() {

        }

        public AddressInfo(String street, String city, String state, String country, String postalCode) {
            this.line1 = street;
            this.city = city;
            this.region = state;
            this.country = String.isBlank(country) ? populateCountryByRegion() : country;
            this.postalCode = postalCode;
        }

        private String populateCountryByRegion() {
            if (!String.isBlank(region) && STATE_ABBREVIATIONS.get(region) != NULL) {
                return 'US';
            }

            return NULL;
        }

        public Boolean isIncomplete() {
            return String.isBlank(line1) || String.isBlank(city) || String.isBlank(region)|| String.isBlank(country);
        }

        public AddressPreliminaryCheckResult preliminaryCheck() {
            AddressPreliminaryCheckResult result = new AddressPreliminaryCheckResult();
            if (String.isBlank(line1) || String.isBlank(city) || String.isBlank(region)) {
                result.isValid = false;
                result.message = Label.WRN_ENTER_ADDRESS_INFORMATION;
            }
            else if (!String.isBlank(line1) && !String.isBlank(city) && !String.isBlank(region) && country != 'US') {
                result.isValid = false;
                result.message = Label.ERR_AVALARA_ADDRESS_VALIDATOR_SALES_TAX_CALC_NOT_SUPPORTED;
            }
            else {
                result.isValid = true;
            }

            return result;
        }
    }

    public with sharing class AddressPreliminaryCheckResult {
        public Boolean isValid {get; set;}
        public String message {get; set;}
    }

    public with sharing class AddressesModel {
        public AddressInfo singleLocation;
        public AddressInfo shipFrom;
        public AddressInfo shipTo;
        public AddressInfo pointOfOrderOrigin;
        public AddressInfo pointOfOrderAcceptance;
    }

    public with sharing class CoordinateInfo {
        public Double latitude {get; set;}
        public Double longitude {get; set;}
    }

    public with sharing class TaxAuthorityInfo {
        public String avalaraId {get; set;}
        public String jurisdictionName {get; set;}
        public JurisdictionType jurisdictionType {get; set;}
        public String signatureCode {get; set;}
    }

    public with sharing class AvaTaxMessage {
        public String summary {get; set;}
        public String details {get; set;}
        public String refersTo {get; set;}
        public String severity {get; set;}
        public String source {get; set;}
    }

    public with sharing class AddLinesTransactionModel {
        public String transactionCode;
        public List<LineItemModel> lines;
        public DocumentType type;
        public String companyCode;
        public Boolean renumber;
    }

    public with sharing class CreateOrAdjustTransactionModel {
        public CreateTransactionModel createTransactionModel {get; set;}
    }

    public with sharing class CreateTransactionModel {
        public String code;
        public List<LineItemModel> lines;
        public DocumentType type;
        public String companyCode;
        public Date avaTaxDate;
        public String customerCode;
        public AddressesModel addresses;
        public Boolean doCommit;
        public String currencyCode;
        public String purchaseOrderNo;
        public String businessIdentificationNo;
        public String entityUseCode;//Max Length: 25
        public String exemptionNo;//Max Length: 25
        public Double exchangeRate;
        public Date exchangeRateEffectiveDate;
        public String description;
    }

    public with sharing class LineItemModel {
        public String avaTaxNumber;//Max Length: 50
        public Double quantity;
        public Double amount;
        public String taxCode;//Max Length: 25
        public String itemCode;//Max Length: 50
        public String description;
        public AddressesModel addresses;
    }

    public with sharing class FetchResultTransactionModel {
        private List<TransactionModel> value;

        public List<TransactionModel> getTransactionList() {
            return value;
        }

        public Map<String, TransactionModel> getTransactionMap() {
            Map<String, TransactionModel> result = new Map<String, TransactionModel>();
            for (TransactionModel eachValue :  getTransactionList()) {
                result.put(eachValue.code, eachValue);
            }
            return result;
        }

        public void setValue(List<TransactionModel> trList) {
            value = trList;
        }
    }

    public with sharing class TransactionModel {
        public Long id;
        public String code;
        public Integer companyId;
        public Date avaTaxDate;
        public Date paymentDate;
        public DocumentStatus status;
        public DocumentType type;
        public String batchCode;
        public String currencyCode;
        public String entityUseCode;
        public String customerVendorCode;
        public String exemptNo;
        public Boolean reconciled;
        public String reportingLocationCode;
        public String purchaseOrderNo;
        public String referenceCode;
        public TaxOverrideTypeId taxOverrideType;
        public Double taxOverrideAmount;
        public String taxOverrideReason;
        public Double totalAmount;
        public Double totalExempt;
        public Double totalDiscount;
        public Double totalTax;
        public Double totalTaxable;//The portion of the total amount of this transaction that was taxable.
        public Double totalTaxCalculated;//If a tax override was applied to this transaction, indicates the amount of tax Avalara calculated for the transaction.
        public AdjustmentReason adjustmentReason;
        public Boolean locked;
        public Long originAddressId;
        public Long destinationAddressId;
        public String region;//The two-or-three character ISO region code of the region for this transaction. (ex. CA)
        public String country;//The two-character ISO 3166 code of the country for this transaction.
        public Date exchangeRateEffectiveDate;//If this transaction included foreign currency exchange, this is the date as of which the exchange rate was calculated.
        public Double exchangeRate;//If this transaction included foreign currency exchange, this is the exchange rate that was used.
        public List<TransactionLineModel> lines;
        public List<AvaTaxMessage> messages;
        public List<AddressInfo> addresses;
        //used in SF test context, represents base source record used to create this response model for mock callout in test context:
        //possible values: OPPORTUNITY, RECURRING_BILLING, BILLING
        public String modelSourcedFrom;
        private Map<String, TransactionLineModel> linesMap;

        public Map<String, TransactionLineModel> getLinesMap() {
            if (this.linesMap == NULL) {
                this.linesMap = new Map<String, TransactionLineModel>();
                if (this.lines != NULL && !this.lines.isEmpty()) {
                    for (TransactionLineModel line : lines) {
                        linesMap.put(line.lineNumber, line);
                    }
                }
            }
            return linesMap;
        }
    }

    public with sharing class TransactionLineModel {
        public Long id;
        public Long transactionId;
        public String lineNumber;
        public Double discountAmount;
        public Double quantity;
        public Double tax;
        public Double taxableAmount;
        public Double taxCalculated;
        public String taxCode;
        public Date taxDate;
    }

    public with sharing class AvaTaxResult {
        public Boolean isSuccess {get; set;}
        public AvaTaxError error {get; set;}

        public AvaTaxResult(Boolean isSuccess, AvaTaxError error) {
            this.isSuccess = isSuccess;
            this.error = error;
        }
    }

    public with sharing class AvaTaxErrorResponse {
        public AvaTaxError error;
    }

    public with sharing class AvaTaxError {
        public String code;
        public String message;
        public String target;
        public List<AvaTaxErrorDetail> details;

        public AvaTaxError() {}

        public AvaTaxError(String errMessage) {
            this.message = errMessage;
        }

        public String getMessage() {
            return message + ((details != NULL && !details.isEmpty()) ? ' ' + details[0].description : '');
        }
    }

    public with sharing class AvaTaxErrorDetail {
        public String code;
        public String message;
        public String description;
        public String faultCode;
        public String helpLink;
        public String severity;
    }

    public class AvaTaxException extends Exception {
        public AvaTaxError atError;

        public AvaTaxException(AvaTaxError atError) {
            this(atError.getMessage());//not "super" keyword because Exception is a special case
            this.atError = atError;
        }
    }

    public enum AdjustmentReason {
        NotAdjusted,
        SourcingIssue,
        ReconciledWithGeneralLedger,
        ExemptCertApplied,
        PriceAdjusted,
        ProductReturned,
        ProductExchanged,
        BadDebt,
        Other,
        Offline
    }

    public enum TaxOverrideTypeId {
        None,//No override
        TaxAmount,//Tax was overriden by the client
        Exemption,//Entity exemption was ignored (e.g. item was consumed)
        TaxDate,//Only the tax date was overriden
        AccruedTaxAmount,//To support Consumer Use Tax
        DeriveTaxable//Derive the taxable amount from the tax amount
    }

    public enum DocumentType {
        SalesOrder,
        SalesInvoice,
        PurchaseOrder,
        PurchaseInvoice,
        ReturnOrder,
        ReturnInvoice,
        InventoryTransferOrder,
        InventoryTransferInvoice,
        ReverseChargeOrder,
        ReverseChargeInvoice
    }

    public enum DocumentStatus {
        Temporary,//Temporary document not saved (SalesOrder, PurchaseOrder)
        Saved,//Saved document (SalesInvoice or PurchaseInvoice) ready to be posted
        Posted,//A posted document (not committed)
        Committed,//A posted document that has been committed
        Cancelled,//A Committed document that has been cancelled
        Adjusted,//A document that has been adjusted
        Queued,//A document which is in Queue status and processed later
        PendingApproval
    }

    public enum JurisdictionType {
        Country,
        Composite,
        State,
        County,
        City,
        Special
    }

    public enum TextCase {
        Upper,
        Mixed
    }

}