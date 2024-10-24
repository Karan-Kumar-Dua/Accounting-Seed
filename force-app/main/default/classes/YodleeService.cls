public with sharing class YodleeService {
    @TestVisible
    private static final String YODLEE_API_ENDPOINT = /*https://usyirestmaster.api.yodlee.com/ysl*/ getExternalSettings()
        .Value_3__c;

    private static External_Settings__mdt externalSettings;

    private static final String ISS = /*'indentifier to public stored by Yodlee'*/ getExternalSettings()
        .Value_1__c;
    private static final String AUD = /*'https://login.salesforce.com'*/ getExternalSettings()
        .Value_2__c;
    private static final String SUB = 'asyd' + UserInfo.getOrganizationId();
    private static final String PKCS8 = getExternalSettings().Value_5__c;

    private static AuthToken USER_TOKEN;
    private static AuthToken AUTH_TOKEN;

    public static String getUserToken() {
        if (USER_TOKEN == null || isUserTokenExpired()) {
            USER_TOKEN = new AuthToken();
            USER_TOKEN.issuedAt = DateTime.now();
            USER_TOKEN.expiresIn = 1800;

            JWTHelper jwt = new JWTHelper('RS512');
            jwt.iss = ISS;
            jwt.sub = SUB;
            jwt.aud = AUD;
            jwt.pkcs8 = PKCS8;
            USER_TOKEN.accessToken = jwt.issue();
        }
        return USER_TOKEN.accessToken;
    }

    public static String getAuthToken() {
        if (AUTH_TOKEN == null || isAuthTokenExpired()) {
            AUTH_TOKEN = new AuthToken();
            AUTH_TOKEN.issuedAt = DateTime.now();
            AUTH_TOKEN.expiresIn = 1800;

            JWTHelper jwt = new JWTHelper('RS512');
            jwt.iss = ISS;
            jwt.aud = AUD;
            jwt.pkcs8 = PKCS8;
            AUTH_TOKEN.accessToken = jwt.issue();
        }
        return AUTH_TOKEN.accessToken;
    }

    @TestVisible
    private static Boolean isUserTokenExpired() {
        return !(USER_TOKEN != null &&
        (USER_TOKEN.issuedAt.addSeconds(USER_TOKEN.expiresIn) > System.now()));
    }

    @TestVisible
    private static Boolean isAuthTokenExpired() {
        return !(AUTH_TOKEN != null &&
        (AUTH_TOKEN.issuedAt.addSeconds(AUTH_TOKEN.expiresIn) > System.now()));
    }

    /*
     * Request parameters:
     * Format: String => String
     * required: 'accountId' => accountId
     * required: 'container' => bank | creditCard | investment | insurance | loan | reward | bill | realEstate | otherAssets | otherLiabilities
     * optional: 'include' => [profile,holder,fullAccountNumber,paymentProfile,autoRefresh]
     * */
    public static AccountModel getAccountById(
        String authToken,
        String accountId,
        Map<String, String> requestParameters
    ) {
        String serviceEndpoint = YODLEE_API_ENDPOINT + '/accounts/';
        Map<String, String> headers = populateHeaderMap(
            authToken,
            'application/json'
        );
        String requestUrl =
            serviceEndpoint +
            accountId +
            populateUrlParameters(requestParameters);
        HttpResponse response = get(requestUrl, headers);
        if (response.getStatusCode() >= 400) {
            handleYodleeError(response.getBody());
        }
         
        AccountsResponse accountsResponse = (AccountsResponse) JSON.deserialize(
            response.getBody(),
            AccountsResponse.class
        );
        if (
            accountsResponse.account == null ||
            accountsResponse.account.isEmpty()
        ) {
            throw new YodleeException(
                Label.ERR_ACCOUNT_RECEIVING_PROCESS
            );
        }
        return accountsResponse.account.get(0);
    }

    /*
     * Request parameters:
     * Format: String => String
     * optional: 'status' => [ACTIVE,INACTIVE,TO_BE_CLOSED,CLOSED]
     * optional: 'container' => [bank | creditCard | investment | insurance | loan | reward | bill | realEstate | otherAssets | otherLiabilities]
     * optional: 'accountId' => [Comma separated accountIds.]
     * optional: 'include' => [profile,holder,fullAccountNumber,paymentProfile,autoRefresh]
     * optional: 'providerAccountId' => [Comma separated providerAccountIds]
     * */
    public static List<AccountModel> getAccounts(
        String authToken,
        Map<String, String> requestParameters
    ) {
        String serviceEndpoint = YODLEE_API_ENDPOINT + '/accounts';
        Map<String, String> headers = populateHeaderMap(
            authToken,
            'application/json'
        );
        String requestUrl =
            serviceEndpoint + populateUrlParameters(requestParameters);
        HttpResponse response = get(requestUrl, headers);
        if (response.getStatusCode() >= 400) {
            handleYodleeError(response.getBody());
        }
        
        AccountsResponse accountsResponse = (AccountsResponse) JSON.deserialize(
            cleanJsonResponse(response.getBody()),
            AccountsResponse.class
        );
        if (
            accountsResponse.account == null ||
            accountsResponse.account.isEmpty()
        ) {
            throw new YodleeException(
                Label.ERR_ACCOUNT_RECEIVING_PROCESS
            );
        }
        return accountsResponse.account;
    }

    /*
     * Request parameters:
     * Format: String => String
     * optional: 'providerIds' => [Comma separated providerIds.]
     * optional: 'include' => [credentials,questions,preferences]
     * */
    public static List<ProviderAccountModel> getProviderAccounts(
        String authToken,
        Map<String, String> requestParameters
    ) {
        String serviceEndpoint = YODLEE_API_ENDPOINT + '/providerAccounts';
        Map<String, String> headers = populateHeaderMap(
            authToken,
            'application/json'
        );
        String requestUrl =
            serviceEndpoint + populateUrlParameters(requestParameters);
        HttpResponse response = get(requestUrl, headers);
        if (response.getStatusCode() >= 400) {
            handleYodleeError(response.getBody());
        }
        
        ProviderAccountsResponse providerAccountsResponse = (ProviderAccountsResponse) JSON.deserialize(
            response.getBody(),
            ProviderAccountsResponse.class
        );
        if (
            providerAccountsResponse.providerAccount == null ||
            providerAccountsResponse.providerAccount.isEmpty()
        ) {
            throw new YodleeException(
                Label.ERR_PROVIDER_ACCOUNT_RECEIVING_PROCESS
            );
        }
        return providerAccountsResponse.providerAccount;
    }

    /*
     * Request parameters:
     * Format: String => String
     * */
    public static List<ProviderModel> getProviders(
        String authToken,
        Map<String, String> requestParameters
    ) {
        String serviceEndpoint = YODLEE_API_ENDPOINT + '/providers';
        Map<String, String> headers = populateHeaderMap(
            authToken,
            'application/json'
        );
        String requestUrl =
            serviceEndpoint + populateUrlParameters(requestParameters);
        HttpResponse response = get(requestUrl, headers);
        if (response.getStatusCode() >= 400) {
            handleYodleeError(response.getBody());
        }
        ProvidersResponse providersResponse = (providersResponse) JSON.deserialize(
            response.getBody(),
            ProvidersResponse.class
        );
        if (
            providersResponse.provider == null ||
            providersResponse.provider.isEmpty()
        ) {
            throw new YodleeException(
                Label.ERR_PROVIDER_RECEIVING_PROCESS
            );
        }
        return providersResponse.provider;
    }

    public static List<ProviderModel> getProvider(
        String authToken,
        String providerId
    ) {
        String serviceEndpoint =
            YODLEE_API_ENDPOINT +
            '/providers/' +
            providerId;
        Map<String, String> headers = populateHeaderMap(
            authToken,
            'application/json'
        );
        String requestUrl = serviceEndpoint;
        HttpResponse response = get(requestUrl, headers);
        if (response.getStatusCode() >= 400) {
            handleYodleeError(response.getBody());
        }
        ProvidersResponse providersResponse = (providersResponse) JSON.deserialize(
            response.getBody(),
            ProvidersResponse.class
        );
        if (
            providersResponse.provider == null ||
            providersResponse.provider.isEmpty()
        ) {
            throw new YodleeException(
                Label.ERR_PROVIDER_RECEIVING_PROCESS
            );
        }
        return providersResponse.provider;
    }

    public static void deleteProviderAccount(
        String authToken,
        String providerAccountId
    ) {
        String serviceEndpoint =
            YODLEE_API_ENDPOINT +
            '/providerAccounts/' +
            providerAccountId;
        Map<String, String> headers = populateHeaderMap(
            authToken,
            'application/json'
        );
        String requestUrl = serviceEndpoint;
        HttpResponse response = deleteMethod(requestUrl, headers);
        if (response.getStatusCode() >= 400) {
            handleYodleeError(response.getBody());
            throw new YodleeException(
                Label.ERR_PROVIDER_ACCOUNT_DELETE_PROCESS
            );
        }
    }

    /*
     * Request parameters:
     * Format: String => String
     * optional: 'container' => [bank | creditCard | investment | insurance | loan | reward | bill | realEstate | otherAssets | otherLiabilities]
     * optional: 'baseType' => [DEBIT | CREDIT]
     * optional: 'keyword' => [Transaction search text]
     * optional: 'accountId' => [Comma separated accountIds.]
     * optional: 'fromDate' => [Transaction from date(YYYY-MM-DD)]
     * optional: 'toDate' => [Transaction end date (YYYY-MM-DD)]
     * optional: 'categoryId' => [Comma separated categoryIds]
     * optional: 'highLevelCategoryId' => [Comma separated highLevelCategoryIds]
     * optional: 'detailCategoryId' => [Comma separated detailCategoryIds]
     * */
    public static Integer getTransactionsCount(
        String authToken,
        Map<String, String> requestParameters
    ) {
        String serviceEndpoint = YODLEE_API_ENDPOINT + '/transactions/count';
        Map<String, String> headers = populateHeaderMap(
            authToken,
            'application/json'
        );
        String requestUrl =
            serviceEndpoint + populateUrlParameters(requestParameters);
        HttpResponse response = get(requestUrl, headers);
        if (response.getStatusCode() >= 400) {
            handleYodleeError(response.getBody());
        }
        TransactionsCountResponse tcResponse = (TransactionsCountResponse) JSON.deserialize(
            cleanJsonResponse(response.getBody()),
            TransactionsCountResponse.class
        );
        return tcResponse.yodleeTransaction.TOTAL.count;
    }

    /*
     * Request parameters:
     * Format: String => String
     * optional: 'container' => [bank | creditCard | investment | insurance | loan | reward | bill | realEstate | otherAssets | otherLiabilities]
     * optional: 'baseType' => [DEBIT | CREDIT]
     * optional: 'keyword' => [Transaction search text]
     * optional: 'accountId' => [Comma separated accountIds.]
     * optional: 'fromDate' => [Transaction from date(YYYY-MM-DD)]
     * optional: 'toDate' => [Transaction end date (YYYY-MM-DD)]
     * optional: 'categoryId' => [Comma separated categoryIds]
     * optional: 'highLevelCategoryId' => [Comma separated highLevelCategoryIds]
     * optional: 'detailCategoryId' => [Comma separated detailCategoryIds]
     * optional: 'skip' => [skip (Min 0)]
     * optional: 'top' => [top (Max 500)]
     * */
    public static List<YodleeService.TransactionModel> getTransactions(
        String authToken,
        Map<String, String> requestParameters,
        Boolean onlyPosted
    ) {
        String serviceEndpoint = YODLEE_API_ENDPOINT + '/transactions';
        Map<String, String> headers = populateHeaderMap(
            authToken,
            'application/json'
        );
        String requestUrl =
            serviceEndpoint + populateUrlParameters(requestParameters);
        HttpResponse response = get(requestUrl, headers);
        if (response.getStatusCode() >= 400) {
            handleYodleeError(response.getBody());
        }
        TransactionsResponse tResponse = (TransactionsResponse) JSON.deserialize(
            cleanJsonResponse(response.getBody()),
            TransactionsResponse.class
        );
        return tResponse.getTransactionModels(onlyPosted);
    }

    public static List<TransactionCategoryModel> getCategories(
        String authToken
    ) {
        String serviceEndpoint =
            YODLEE_API_ENDPOINT + '/transactions/categories';
        Map<String, String> headers = populateHeaderMap(
            authToken,
            'application/json'
        );
        String requestUrl = serviceEndpoint;
        HttpResponse response = get(requestUrl, headers);
        if (response.getStatusCode() >= 400) {
            handleYodleeError(response.getBody());
        }
        TransactionCategoriesResponse resp = (TransactionCategoriesResponse) JSON.deserialize(
            cleanJsonResponse(response.getBody()),
            TransactionCategoriesResponse.class
        );
        return resp.transactionCategory;
    }

    public static void registerUser(String authToken) {
        String serviceEndpoint = YODLEE_API_ENDPOINT + '/user/register';
        Map<String, String> headers = populateHeaderMap(
            authToken,
            'application/json'
        );
        String requestUrl = serviceEndpoint;

        YodleeService.UserPayload userPayload = new YodleeService.UserPayload();
        userPayload.user = new UserModel();
        userPayload.user.loginName = SUB;
        userPayload.user.email = SUB + '@as.com';
        userPayload.user.preferences = new PreferencesModel();
        userPayload.user.preferences.locale = UserInfo.getLocale();
        userPayload.user.preferences.timeZone = UserInfo.getTimeZone().getId();
        userPayload.user.preferences.currencyCode = MultiCurrencyHandler.CORPORATE_CURRENCY;

        //make the REST call
        HttpResponse response = post(requestUrl, headers, userPayload);
        if (response.getStatusCode() >= 400) {
            handleYodleeError(response.getBody());
            throw new YodleeException(
                Label.ERR_USER_REGISTRATION_PROCESS
            );
        }
    }

    @TestVisible
    private static String populateUrlParameters(
        Map<String, String> requestParameters
    ) {
        String urlParams = '';
        if (requestParameters != null && !requestParameters.isEmpty()) {
            urlParams = '?';
            for (String paramKey : requestParameters.keySet()) {
                urlParams +=
                    paramKey +
                    '=' +
                    EncodingUtil.urlEncode(
                        requestParameters.get(paramKey),
                        'UTF-8'
                    ) +
                    '&';
            }
        }
        return urlParams;
    }

    private static Map<String, String> populateHeaderMap(
        String authToken,
        String contentType
    ) {
        Map<String, String> headers = new Map<String, String>();
        if (String.isNotEmpty(authToken)) {
            headers.put(
                'Authorization',
                'Bearer ' + EncodingUtil.urlEncode(authToken, 'UTF-8')
            );
        }
        headers.put('Api-Version', '1.1');
        headers.put('Accept-Encoding', 'gzip');
        headers.put('Content-Type', contentType);
        return headers;
    }

    @TestVisible
    private static HttpResponse post(
        String url,
        Map<String, String> headers,
        UserPayload user
    ) {
        String body = JSON.serialize(user)
            .replaceAll('"currencyCode":', '"currency":');
        return post(url, headers, body);
    }

    @TestVisible
    private static HttpResponse post(
        String url,
        Map<String, String> headers,
        String body
    ) {
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        try {
            req.setMethod('POST');
            if (headers != null) {
                for (String k : headers.keySet()) {
                    req.setHeader(k, headers.get(k));
                }
            }
            req.setEndpoint(url);
            req.setBody(body);
            req.setTimeout(120000);
        } catch (Exception ex) {
        }

        return h.send(req);
    }

    @TestVisible
    private static HttpResponse deleteMethod(
        String url,
        Map<String, String> headers
    ) {
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        try {
            req.setMethod('DELETE');
            if (headers != null) {
                for (String k : headers.keySet()) {
                    req.setHeader(k, headers.get(k));
                }
            }
            req.setEndpoint(url);
            req.setTimeout(120000);
        } catch (Exception ex) {
        }

        return h.send(req);
    }

    @TestVisible
    private static HttpResponse get(String url, Map<String, String> headers) {
        Http h = new Http();
        HttpRequest req = new HttpRequest();

        try {
            req.setMethod('GET');
            if (headers != null) {
                for (String k : headers.keySet()) {
                    req.setHeader(k, headers.get(k));
                }
            }
            req.setEndpoint(url);
            req.setCompressed(true);
            req.setTimeout(120000);
        } catch (Exception ex) {
        }
        return h.send(req);
    }

    private static void handleYodleeError(String response) {
        YodleeError errorResponse = (YodleeError) JSON.deserialize(
            response,
            YodleeError.class
        );
        throw new YodleeException(errorResponse.errorMessage);
    }

    private static External_Settings__mdt getExternalSettings() {
        if (externalSettings == null) {
            try {
                externalSettings = DomainUtils.queryExternalSettingsByDeveloperName(
                    'Yodlee_Settings'
                );
            } catch (Exception ex) {
            }
        }
        return externalSettings;
    }

    //some of the JSON keys have names which are reserved keywords in APEX
    //that is why we need substitute some of them
    private static String cleanJsonResponse(String json) {
        json = json.replaceAll('"transaction":', '"yodleeTransaction":');
        json = json.replaceAll('"date":', '"yodleeDate":');
        json = json.replaceAll('"currency":', '"yodleeCurrency":');
        return json;
    }

    public class YodleeException extends Exception {
    }

    public with sharing class AuthTokenResponse {
        public AuthToken token;
    }

    public with sharing class UserPayload {
        public UserModel user;
    }

    public with sharing class UserModel {
        public String loginName;
        public String email;
        public PreferencesModel preferences;
    }

    public with sharing class PreferencesModel {
        public String currencyCode;
        public String timeZone;
        public String locale;
    }

    public with sharing class AuthToken {
        //The access token represents the authorization of a client to access Yodlee API v1.1 services.
        public String accessToken;
        //The date and time the accessToken was created in the system.
        public Datetime issuedAt;
        //The time in seconds after which the accessToken token created for users or admin expires.
        public Integer expiresIn;
    }

    public with sharing class ProvidersResponse {
        public List<ProviderModel> provider;
    }

    public with sharing class ProviderModel {
        public String id;
        public String name;
        public DateTime lastModified;
        public string status;
    }

    public with sharing class ProviderAccountsResponse {
        public List<ProviderAccountModel> providerAccount;
    }

    public with sharing class AutoRefreshModel {
        public String status;
        public String additionalStatus;
        public DateTime asOfDate;

        public AutoRefreshModel(String status, String additionalStatus, DateTime asOfDate) {
            this.status = status;
            this.additionalStatus = additionalStatus;
            this.asOfDate = asOfDate;
        }

        public Boolean isAutoRefreshEnabled() {
            return this.status == 'ENABLED';
        }
    }
    public with sharing class DatasetModel {
        public String name;
        public DateTime nextUpdateScheduled;
        public String additionalStatus;
        public DateTime lastUpdateAttempt;

        public DatasetModel(String name, DateTime nextUpdateScheduled, DateTime lastupdateAttempt, String additionalStatus) {
            this.name = name;
            this.nextUpdateScheduled = nextUpdateScheduled;
            this.lastUpdateAttempt = lastUpdateAttempt;
            this.additionalStatus = additionalStatus;
        }

        public Boolean isAdditionalAuthenticationRequired() {
            return this.additionalStatus == 'ADDL_AUTHENTICATION_REQUIRED';
        }

        public Boolean isTokenExpired() {
            //nextUpdateScheduled does not update immediately when someone refreshes their credentials
            //so, if nextUpdateScheduled is NULL or in the past, check to see if the lastUpdateAttempt is greater than 48 hours ago            
            Boolean retVal;
            Boolean lastUpdateAttemptTooFarBack = this.lastUpdateAttempt != NULL ?
                ((DateTime.now().getTime() - this.lastUpdateAttempt.getTime()) / 3600000) > 24 :
                true;
            
            if (this.nextUpdateScheduled == NULL) {
                retVal = lastUpdateAttemptTooFarBack;                
            } else if (this.nextUpdateScheduled.getTime() > DateTime.now().getTime()){
                retVal = false;
            } else {
                retVal = lastUpdateAttemptTooFarBack;
            }
            return retVal;
        }
    }

    public with sharing class ProviderAccountModel {
        public String id;
        public String providerId;
        public DateTime createdDate;
        public String status;
        public String name;
        public DateTime lastUpdated;
        public List<DatasetModel> dataset;
    }

    public with sharing class AccountsResponse {
        public List<AccountModel> account;
    }

    public with sharing class AccountModel {
        public String id;
        public String providerAccountId;
        public String providerName;
        /*
        CONTAINER:
        bank, creditCard, investment, insurance, loan, otherAssets, otherLiabilities, realEstate, reward, bill
        */
        public String container;
        public String accountName;
        public String nickname;
        public String accountNumber;
        public DateTime lastUpdated;
        public String accountType;
        public Money balance;
        public Money runningBalance;
        public Money availableBalance;
        public Money availableCredit;
        public Money currentBalance;
        public String accountStatus; //ACTIVE,INACTIVE,TO_BE_CLOSED,CLOSED
        public AutoRefreshModel autoRefresh;
        public List<DatasetModel> dataset;

        public String getMaskedAccountNumber() {
            return accountNumber != NULL ? 'xxxx' + accountNumber.right(4) : '';
        }

        public Money getCurrentBalanceMoney() {
            Money result;
            switch on container {
                when 'bank' {
                    result = currentBalance;
                }
                when 'creditCard' {
                    result = runningBalance;
                }
                when else {
                    result = balance;
                }
            }
            return result;
        }

        public Decimal getCurrentBalanceDecimal() {
            Money result = getCurrentBalanceMoney();
            return (result != null) ? result.amount : null;
        }

        public Money getAvailableBalanceMoney() {
            Money result;
            switch on container {
                when 'bank' {
                    result = availableBalance;
                }
                when 'creditCard' {
                    result = availableCredit;
                }
                when else {
                    result = balance;
                }
            }
            return result;
        }

        public Decimal getAvailableBalanceDecimal() {
            Money result = getAvailableBalanceMoney();
            return (result != null) ? result.amount : null;
        }
    }

    public with sharing class TransactionsCountResponse {
        public TransactionModel yodleeTransaction;
    }

    public with sharing class TransactionsResponse {
        public List<TransactionModel> yodleeTransaction;

        public List<TransactionModel> getTransactionModels(Boolean onlyPosted) {
            if (onlyPosted) {
                List<TransactionModel> onlyPostedTransactionModels = new List<YodleeService.TransactionModel>();
                for (TransactionModel tm : yodleeTransaction) {
                    if (tm.status == 'POSTED') {
                        onlyPostedTransactionModels.add(tm);
                    }
                }
                return onlyPostedTransactionModels;
            } else {
                return yodleeTransaction;
            }
        }
    }

    public with sharing class TransactionModel {
        //used for GET /transactions/count response
        public TransactionsTotal TOTAL;
        //used in GET /transactions response
        @AuraEnabled
        public String accountId;
        @AuraEnabled
        public Money amount;
        @AuraEnabled
        public String baseType;
        @AuraEnabled
        public String container;
        @AuraEnabled
        public Date yodleeDate;
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String memo;
        public Date postDate;
        public Date transactionDate;
        public String type;
        @AuraEnabled
        public TransactionDescription description;
        public Money runningBalance;
        public String parentCategoryId;
        public String subType;
        public String merchantType;
        public Merchant merchant;
        public String categoryType;
        public String categoryId;
        public String category;
        public String highLevelCategoryId;
        public String detailCategoryId;
        public String checkNumber;
        public String status;

        public TransactionModel() {
        }

        //Used during Financial File parsing
        public TransactionModel(
            String id,
            Date transDate,
            Money amount,
            String baseType,
            String accountId,
            String accountType,
            String description,
            String memo,
            String checkNumber
        ) {
            this.id = id;
            this.yodleeDate = transDate;
            this.amount = amount;
            this.baseType = baseType;
            this.accountId = accountId;
            this.container = accountType;
            this.description = new TransactionDescription(description);
            this.memo = memo;
            this.checkNumber = checkNumber;
        }
    }

    public with sharing class TransactionDescription {
        @AuraEnabled
        public String original;
        public String simple;

        public TransactionDescription(String description) {
            this.original = description;
        }
        public TransactionDescription(
            String description,
            String simpleDescription
        ) {
            this(description);
            this.simple = simpleDescription;
        }
    }

    public with sharing class Merchant {
        public String id;
        public String name;
        public List<String> categoryLabel;
        public Address address;
    }

    public with sharing class Address {
        public String country; //two letter valid ISO code
        public String address1;
        public String address2;
        public String address3;
        public String street;
        public String fullAddress;
        public String state;
        public String city;
        public String ZIP;
        public String type;
        public String sourceType;
    }

    public with sharing class Money {
        @AuraEnabled
        public Decimal amount;
        @AuraEnabled
        public String yodleeCurrency;

        public Money() {
        }
        public Money(Decimal amount, String isoCode) {
            this.amount = amount;
            this.yodleeCurrency = (isoCode != null) ? isoCode : 'USD';
        }
    }

    public with sharing class TransactionsTotal {
        public Integer count;

        public TransactionsTotal() {
        }
        public TransactionsTotal(Integer count) {
            this.count = count;
        }
    }

    public with sharing class YodleeError {
        //The error code follows the format YNNN. The error codes do not change.
        public String errorCode;
        //The descriptive message that explains the error scenario.
        public String errorMessage;
        //Unique Yodlee identifier used to troubleshoot issues at Yodlee’s end.
        public String referenceCode;
    }

    public with sharing class TransactionCategoriesResponse {
        public List<TransactionCategoryModel> transactionCategory;
    }

    public with sharing class TransactionCategoryModel {
        public Integer id;
        public String category;
        public Integer highLevelCategoryId;
        public String highLevelCategoryName;
        public String source;
        public String classification;
        public String type;
        public List<TransactionDetailCategory> detailCategory;
    }

    public with sharing class TransactionDetailCategory {
        public Integer id;
        public String name;
    }
}