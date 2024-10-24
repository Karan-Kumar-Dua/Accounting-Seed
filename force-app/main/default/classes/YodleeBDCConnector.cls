public class YodleeBDCConnector extends AbstractBDCConnector {

    @TestVisible
    private static final String YODLEE_API_ENDPOINT = /*https://usyirestmaster.api.yodlee.com/ysl*/ getExternalSettings().Value_3__c;
    private static External_Settings__mdt externalSettings;
    private static final String ISS = /*'indentifier to public stored by Yodlee'*/ getExternalSettings().Value_1__c;
    private static final String AUD = /*'https://login.salesforce.com'*/ getExternalSettings().Value_2__c;
    private static final String SUB = 'asyd' + UserInfo.getOrganizationId();
    private static final String PKCS8 = getExternalSettings().Value_5__c;
    private static AuthToken USER_TOKEN;
    private static AuthToken AUTH_TOKEN;

    private static string handleYodleeError(String responseBody) {
        YodleeError errorResponse = (YodleeError) JSON.deserialize(
            responseBody,
            YodleeError.class
        );
        
        return errorResponse.errorMessage;
    }

    private static String formatDate(Date aDate) {
        return aDate.year()
            + '-'
            + FinancialSuiteUtils.leftPad(String.valueOf(aDate.month()), ((aDate.month() > 9) ? 0 : 1))
            + '-'
            + FinancialSuiteUtils.leftPad(String.valueOf(aDate.day()), ((aDate.day() > 9) ? 0 : 1));
    }

    public with sharing class YodleeError {
        //The error code follows the format YNNN. The error codes do not change.
        public String errorCode;
        //The descriptive message that explains the error scenario.
        public String errorMessage;
        //Unique Yodlee identifier used to troubleshoot issues at Yodlee’s end.
        public String referenceCode;
    }

    public with sharing class AuthToken {
        //The access token represents the authorization of a client to access Yodlee API v1.1 services.
        public String accessToken;
        //The date and time the accessToken was created in the system.
        public Datetime issuedAt;
        //The time in seconds after which the accessToken token created for users or admin expires.
        public Integer expiresIn;
    }

    public static String getAuthToken() {
        AuthToken authToken = YodleeBDCConnector.AUTH_TOKEN;
        if (authToken == null || isAuthTokenExpired()) {
            authToken = new AuthToken();
            authToken.issuedAt = DateTime.now();
            authToken.expiresIn = 1800;

            JWTHelper jwt = new JWTHelper('RS512');
            jwt.iss = ISS;
            jwt.aud = AUD;
            jwt.pkcs8 = PKCS8;
            authToken.accessToken = jwt.issue();
        }
        return authToken.accessToken;
    }

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

    @TestVisible
    private static Boolean isAuthTokenExpired() {
        return !(AUTH_TOKEN != null &&
        (AUTH_TOKEN.issuedAt.addSeconds(AUTH_TOKEN.expiresIn) > System.now()));
    }

    @TestVisible
    private static Boolean isUserTokenExpired() {
        return (USER_TOKEN != null && (USER_TOKEN.issuedAt.addSeconds(USER_TOKEN.expiresIn) < System.now()));
    }

    private static External_Settings__mdt getExternalSettings() {
        if (externalSettings == null) {
            externalSettings = DomainUtils.queryExternalSettingsByDeveloperName(
                'Yodlee_Settings'
            );
        }
        return externalSettings;
    }

    @TestVisible
    private String populateUrlParameters(
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

    @TestVisible
    private with sharing class UserModel {
        public String loginName;
        public String email;
        public PreferencesModel preferences;
    }

    @TestVisible
    private with sharing class UserPayload {
        public UserModel user;
    }

    public with sharing class PreferencesModel {
        public String currencyCode;
        public String timeZone;
        public String locale;
    }

    private Map<String, String> populateHeaderMap(
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
        return HttpHandler.post(url, headers, body);
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

    //a helper function to split a list into smaller lists of size pageSize. Could be in a list utility class for reuse?
    private List<List<String>> splitCollection(List<String> sourceCollection, Integer pageSize) {
        List<List<String>> pages = new List<List<String>>();
        List<String> singlePageContent = new List<String>();
        Integer counter = 0;
        for (String value : sourceCollection) {
            if (counter != 0 && Math.mod(counter, pageSize) == 0) {
                pages.add(singlePageContent);
                singlePageContent = new List<String>();
            }
            singlePageContent.add(value);
            counter++;
        }
        pages.add(singlePageContent);
        return pages;
    }

    private HttpResponse getAccountsRequest(
        String authToken,
        Map<String, String> requestParameters
    ) {
        String serviceEndpoint = YodleeBDCConnector.YODLEE_API_ENDPOINT + '/accounts';
        Map<String, String> headers = populateHeaderMap(
            authToken,
            'application/json'
        );
        String requestUrl = serviceEndpoint + populateUrlParameters(requestParameters);
        HttpResponse response = HttpHandler.get(requestUrl, headers);
        if (response.getStatusCode() >= 400) {
            throw new BDCService.BDCException(handleYodleeError(response.getBody()));
        }
        return response;
    }

    private HttpResponse deleteProviderAccount(
        String authToken,
        String providerAccountId
    ) {
        String serviceEndpoint =
            YodleeBDCConnector.YODLEE_API_ENDPOINT +
            '/providerAccounts/' +
            providerAccountId;
        Map<String, String> headers = populateHeaderMap(
            authToken,
            'application/json'
        );
        String requestUrl = serviceEndpoint;
        HttpResponse response = YodleeBDCConnector.deleteMethod(requestUrl, headers);
        if (response.getStatusCode() >= 400) {
            throw new BDCService.BDCException(handleYodleeError(response.getBody()));
        }
        return response;
    }

    private static Map<String, GL_Account_Mapping__c> queryGlAccountMappings() {
        return queryGlAccountMappings(NULL);
    }

    private static Map<String, GL_Account_Mapping__c> queryGlAccountMappings(Set<String> accountIds) {
        Map<String, GL_Account_Mapping__c> retVal = new Map<String, GL_Account_Mapping__c>();
        List<String> queryFields = new List<String> {
            'Id',
            'Account_Name__c',
            'Available_Balance__c',
            'Current_Balance__c',
            'External_Id__c',
            'Financial_Institution__c',
            'GL_Account__r.Name',
            'GL_Account__c',
            'Initial_Start_Date__c',
            'Last_Refreshed__c',
            'Ledger__r.Name',
            'Ledger__c',
            'Inactive__c',
            'Source__c',
            'FIA_Status__c'
        };

        if (AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED) {
            queryFields.add('CurrencyIsoCode');
        }

        String queryCondition = '';
        if (accountIds != NULL && accountIds.size()> 0) {
            queryCondition = 'External_Id__c IN :accountIds OR Financial_Institution_Id__c in :accountIds';
        } else {
            queryCondition = 'External_Id__c != NULL';
        }        

        SOQLBuilder theQuery = new SOQLBuilder(GL_Account_Mapping__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        for (GL_Account_Mapping__c glam :  (List<GL_Account_Mapping__c>)Database.query(theQuery.toSOQL())) {
            retVal.put(glam.External_Id__c, glam);
        }
        return retVal;
    }

    /*
    Used as an intermediary function to get financial institutions
    */
    public override List<HttpResponse> getFinancialInstitutionIdentities() {
        String token = YodleeBDCConnector.getUserToken();
        Map<string, string> params = new Map<String, String>();
        String serviceEndpoint = YODLEE_API_ENDPOINT + '/providerAccounts';
        Map<String, String> headers = populateHeaderMap(
            token,
            'application/json'
        );

        String requestUrl = serviceEndpoint + populateUrlParameters(params);
        HttpResponse response = HttpHandler.get(requestUrl, headers);
        if (response.getStatusCode() >= 400) {
            throw new BDCService.BDCException(handleYodleeError(response.getBody()));
        }
        List<HttpResponse> responses = new List<HttpResponse>();
        responses.add(response);
        
        return responses;   
    }

    public override List<HttpResponse> getTransactions(BDCServiceOptions options){
        //Build maps with request parameters
        Map<String, String> transactionsParameters = new Map<String, String>();
        transactionsParameters.put('accountId', String.join(options.bdcAccountIds, ','));
        transactionsParameters.put('fromDate', YodleeBDCConnector.formatDate(options.fromDate));
        transactionsParameters.put('toDate', YodleeBDCConnector.formatDate(options.toDate));
        transactionsParameters.put('skip', String.valueOf(options.offset));
        transactionsParameters.put('top', String.valueOf(options.maxRecords));
        //Execute callout to get transactions by given filter parameters
        String serviceEndpoint = YodleeBDCConnector.YODLEE_API_ENDPOINT + '/transactions';
        String authToken = YodleeBDCConnector.getUserToken();
        Map<String, String> headers = populateHeaderMap(
            authToken,
            'application/json'
        );
        String requestUrl = serviceEndpoint + populateUrlParameters(transactionsParameters);
        HttpResponse response = HttpHandler.get(requestUrl, headers);
        if (response.getStatusCode() >= 400) {
            throw new BDCService.BDCException(handleYodleeError(response.getBody()));
        }
        List<HttpResponse> transResponseList = new List<HttpResponse>();
        transResponseList.add(response);
        return transResponseList;
    }
       
    public override List<HttpResponse> getFinancialInstitutions(List<BDCFinancialInstitutionIdentity> finInstIdens){

        //extract the provider ids into a set to get all unique fin inst ids
        Set<String> uniqueProviderIds = new Set<String>();
        for (BDCFinancialInstitutionIdentity anIden : finInstIdens) {
            uniqueProviderIds.add(anIden.financialInstitutionId);
        }

        List<String> providerIds = new List<String>(uniqueProviderIds);

        //Because of "Max 5 Comma separated Provider Ids" limitation we have to split the original collection
        List<List<String>> providerIdPages = splitCollection(providerIds, 5);

        //Make the api call for the providers and return the response
        List<HttpResponse> responses = new List<HttpResponse>();
        String serviceEndpoint = YodleeBDCConnector.YODLEE_API_ENDPOINT + '/providers';
        for (List<String> page : providerIdPages) {
            Map<String, String> params = new Map<String, String>();
            String token = YodleeBDCConnector.getUserToken();
            String providerIdChunk = String.join(page, ',');
            params.put('providerId', providerIdChunk);
            Map<String, String> headers = populateHeaderMap(
                token,
                'application/json'
            );
            String requestUrl = serviceEndpoint + populateUrlParameters(params);
            HttpResponse response = HttpHandler.get(requestUrl, headers);
            if (response.getStatusCode() >= 400) {
                throw new BDCService.BDCException(handleYodleeError(response.getBody()));
            }
            responses.add(response);
        }
        return responses;
    }
    
    public override List<HttpResponse> getFinancialInstitution(string finInstID){
        String requestUrl =
            YodleeBDCConnector.YODLEE_API_ENDPOINT +
            '/providers/' +
            finInstID;
        String authToken = YodleeBDCConnector.getAuthToken();
        Map<String, String> headers = populateHeaderMap(
            authToken,
            'application/json'
        );
        HttpResponse response = HttpHandler.get(requestUrl, headers);
        if (response.getStatusCode() >= 400) {
            throw new BDCService.BDCException(handleYodleeError(response.getBody()));
        }
        List<HttpResponse> responses = new List<HttpResponse>();
        responses.add(response);
        return responses;
    }

    public override List<HttpResponse> deleteFinancialInstitutionIdentity(BDCFinancialInstitutionIdentity finInstIden){
        String token = YodleeBDCConnector.getUserToken();

        deleteProviderAccount(token, finInstIden.Id);
        
        Map<String, GL_Account_Mapping__c> glams = queryGlAccountMappings(new Set<String>{finInstIden.Id});
        List<GL_Account_Mapping__c> existingGLAMs = glams.values();            
        if (existingGLAMs.size() > 0) {
            for (GL_Account_Mapping__c glam : existingGLAMs) {
                glam.Inactive__c = true;
            }
            GLAccountMappingActions.isDmlRestrictionBypassEnabled = true;
            SFDCSecurityUtils.updateCheckCRUDAndFLS(existingGLAMs, new List<String>{'Inactive__c'});
            GLAccountMappingActions.isDmlRestrictionBypassEnabled = false;
        }
        return new List<HttpResponse>();
    }
    
    public override List<HttpResponse> getAccountsFromFinancialInstitutionIdentities(List<BDCFinancialInstitutionIdentity> finInstIdens){
        String token = YodleeBDCConnector.getUserToken();
        Map<String, String> params = new Map<String, String>();
        params.put('status', 'ACTIVE');
        params.put('container', 'bank');  
        params.put('include', 'autoRefresh');

        List<String> providerAccountIds = new List<String>();
        for (BDCFinancialInstitutionIdentity aFinInstIden : finInstIdens) {
            providerAccountIds.add(aFinInstIden.Id);
        }

        if (providerAccountIds.size() > 0) {
            params.put('providerAccountId', String.join(providerAccountIds, ','));
        }
        
        List<HttpResponse> allResponses = new List<HttpResponse>();
        
        try {
            allResponses.add(getAccountsRequest(token, params));
        } catch (Exception ex) {
            throw new BDCService.BDCException(ex.getMessage());
        }
        
        params.put('container', 'creditCard');        
        
        try {
            allResponses.add(getAccountsRequest(token, params));
        } catch (Exception ex) {
            throw new BDCService.BDCException(ex.getMessage());
        }

        return allResponses;
    }

    public override List<HttpResponse> getAccounts(List<string> bdcAccountIds){
        //Build maps with request parameters
        String token = YodleeBDCConnector.getUserToken();
        Map<String, String> accountsParameters = new Map<String, String>();
        accountsParameters.put('accountId', String.join(bdcAccountIds, ','));
        accountsParameters.put('include', 'autoRefresh');
        //Execute callout to get accounts from Yodlee
        HttpResponse response = getAccountsRequest(token, accountsParameters);
        if (response.getStatusCode() >= 400) {
            throw new BDCService.BDCException(handleYodleeError(response.getBody()));
        }
        List<HttpResponse> responses = new List<HttpResponse>{response};


        return responses;
    }
    
    public override List<HttpResponse> getCategories(){
        String requestUrl = YodleeBDCConnector.YODLEE_API_ENDPOINT + '/transactions/categories';
        String token = YodleeBDCConnector.getUserToken();
        Map<String, String> headers = populateHeaderMap(
            token,
            'application/json'
        );
        HttpResponse response = HttpHandler.get(requestUrl, headers);
        if (response.getStatusCode() >= 400) {
            throw new BDCService.BDCException(handleYodleeError(response.getBody()));
        }
        List<HttpResponse> responses = new List<HttpResponse>{response};
        return responses;
    }

    public BDCServiceResult getuserDetails(){
        BDCServiceResult result = new BDCServiceResult();
        String requestUrl = YodleeBDCConnector.YODLEE_API_ENDPOINT+'/user';
        String userToken = YodleeBDCConnector.getUserToken();
        Map<String, String> headers = populateHeaderMap(
            userToken,
            'application/json'
        );
        HttpResponse response = HttpHandler.get(requestUrl, headers);
        
        try {
            if(response.getStatusCode() ==200){ //means registered user found
                result.isSuccess = true; 
                return result;
            }else if (response.getStatusCode() >= 400) {
                throw new BDCService.BDCException(handleYodleeError(response.getBody()));
            }
        }catch(Exception except) {
            BDCServiceResult.BDCError error = new BDCServiceResult.BDCError();
            error.detail = except.getMessage();
            error.code = except.getMessage();
            result = new BDCServiceResult(NULL, false, new BDCServiceResult.BDCError[]{error});
        }
     
        return result;
    }
    
    public BDCServiceResult registerUser(){
        BDCServiceResult result = new BDCServiceResult();
        String requestUrl = YodleeBDCConnector.YODLEE_API_ENDPOINT + '/user/register';
        String authToken = YodleeBDCConnector.getAuthToken();
        Map<String, String> headers = populateHeaderMap(
            authToken,
            'application/json'
        );

        UserPayload userPayload = getUserpayLoad();
        
        HttpResponse response = post(requestUrl, headers, userPayload);
        try{
            if (response.getStatusCode() >= 400) {
                throw new BDCService.BDCException(handleYodleeError(response.getBody()));
            } else{
                result.isSuccess = true;
            }
        }catch(Exception except) {
            BDCServiceResult.BDCError error = new BDCServiceResult.BDCError();
            error.detail = except.getMessage();
            error.code = except.getMessage();
            result = new BDCServiceResult(NULL, false, new BDCServiceResult.BDCError[]{error});
        }

        return result;
    }

    public List<HttpResponse> getTransactionsCount(Date fromDate, Date toDate, list<string> bdcAccountIds){

        //Build maps with request parameters
        Map<String, String> transactionsCountParameters = new Map<String, String>();
        transactionsCountParameters.put('accountId', String.join(bdcAccountIds, ','));
        transactionsCountParameters.put('fromDate', YodleeBDCConnector.formatDate(fromDate));
        transactionsCountParameters.put('toDate', YodleeBDCConnector.formatDate(toDate));

        //Execute callout to get transactions count by given filter parameters
        String serviceEndpoint = YodleeBDCConnector.YODLEE_API_ENDPOINT + '/transactions/count';
        String token = YodleeBDCConnector.getUserToken();
        Map<String, String> headers = populateHeaderMap(
            token,
            'application/json'
        );
        String requestUrl = serviceEndpoint + populateUrlParameters(transactionsCountParameters);
        HttpResponse response = HttpHandler.get(requestUrl, headers);
        if (response.getStatusCode() >= 400) {
            throw new BDCService.BDCException(handleYodleeError(response.getBody()));
        }
        List<HttpResponse> countResponses = new List<HttpResponse>();
        countResponses.add(response);
        return countResponses;
    }

    private UserPayload getUserpayLoad(){
        UserPayload userPayload = new UserPayload();
        userPayload.user = new UserModel();
        userPayload.user.loginName = SUB;
        userPayload.user.email = SUB + '@as.com';
        userPayload.user.preferences = new PreferencesModel();
        userPayload.user.preferences.locale = UserInfo.getLocale();
        userPayload.user.preferences.timeZone = UserInfo.getTimeZone().getId();
        userPayload.user.preferences.currencyCode = MultiCurrencyHandler.CORPORATE_CURRENCY;

        return userPayload;
    }

    public override Integer maxTransactionRecordsPerCallout() {
        return 100;
    }

}