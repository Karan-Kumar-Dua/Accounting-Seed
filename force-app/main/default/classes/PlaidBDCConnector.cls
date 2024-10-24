public class PlaidBDCConnector extends AbstractBDCConnector {

    //the developer name of the custom metadata containing plaid settings
    private final String plaidSettingsDevName = 'Plaid_Settings';
    private final String plaidSandboxSettingsDevName = 'Plaid_Sandbox_Settings';
    @TestVisible
    private static final Integer MAX_TXNS_PER_CALLOUT = 50;
    private static List<BDC_Access_Tokens__c> allAccessTokens;

    @testVisible private String PLAID_API_ENDPOINT;
    private String clientId;
    private String secretKey;

    private static Set<String> availablePlaidCountries = PlaidLinkHandler.getSupportedPlaidCountryCodes();
    
    //string helper function. Specifically, for converting countries codes to a format Plaid receives
    private static String commaQuoteList(Set<String> stringsForList) {
        //create a comma separated list
        String fullString = '';
        for (String aString : stringsForList) {
            fullString += '"' + aString + '"' + ',';
        }
        //remove the trailing comma
        fullString = fullString.mid(0, fullString.length() - 1);
        return fullString;
    }

    public PlaidBDCConnector() {

        //the protected custom setting should only ever have one record of this type
        Plaid_Sandbox_Mode__c sandboxMode;
        for (Plaid_Sandbox_Mode__c csSandboxMode : Plaid_Sandbox_Mode__c.getAll().values()) {
            sandboxMode = csSandboxMode;
        }
  
        External_Settings__mdt plaidSettings = new External_Settings__mdt();
        if(sandboxMode != null && sandboxMode.Active__c){
            plaidSettings = External_Settings__mdt.getInstance(plaidSandboxSettingsDevName);
        }else{
            plaidSettings = External_Settings__mdt.getInstance(plaidSettingsDevName);
        }

        PLAID_API_ENDPOINT = plaidSettings.Value_1__c;
        clientId = plaidSettings.Value_2__c;
        secretKey = plaidSettings.Value_3__c;
       
    }

    private static List<BDC_Access_Tokens__c> getAccessTokens() {
        if (allAccessTokens == null) {
            allAccessTokens =  BDC_Access_Tokens__c.getAll().values();
        }
        return allAccessTokens;
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

    private Map<String, String> populateHeaderMap(String contentType) {
        Map<String, String> headers = new Map<String, String>();
        headers.put('Content-Type', contentType);
        return headers;
    }

    //this function changes single digit days or months to include the preceding 0.
    //Plaid requires this format. Used for dates in getTransactions
    private String formatDateForPlaid(String dayOrMonth) {
        if (dayOrMonth.length() == 1) {
            return '0' + dayOrMonth;
        }
        return dayOrMonth;
    }


    public List<HttpResponse> getLinkToken(String finIdentityId, Set<String> countryCodes) {
        String accessToken = '';
        Map<string, string> params = new Map<String, String>();
        String serviceEndpoint = PLAID_API_ENDPOINT + '/link/token/create';
        Map<String, String> headers = populateHeaderMap(
            'application/json'
        );
        String requestUrl = serviceEndpoint + populateUrlParameters(params);
        String clientId = this.clientId;
        String secretKey = this.secretKey;

        String countryString = PlaidBDCConnector.commaQuoteList(countryCodes);

        String httpRequestBody = 
        '{"client_id": "' + clientId + 
        '","secret": "' + secretKey + 
        '","client_name": "' + 'Accounting Seed Banking Direct Connect'+ 
        '","country_codes": [' + countryString +
        ']' +
        ',"language": "' + 'en'+ 
          '","user": {' + 
            '"client_user_id": "' + UserInfo.getUserId() + 
            '"}' + 
        ',"products": ["' + 
            'transactions'+ 
        '"]'+
        '}';

        if(String.IsNotBlank(finIdentityId)){
            for(BDC_Access_Tokens__c bdcToken: PlaidBDCConnector.getAccessTokens()){
                if(bdcToken.Financial_Institution_Identity_Id__c == finIdentityId){
                    accessToken = bdcToken.Token__c;
                } 
            }
            String updatedHttpRequestBody = httpRequestBody.remove(',"products": ["transactions"]}');
            updatedHttpRequestBody += ',"access_token": "' + accessToken + '"}' ;
            httpRequestBody = updatedHttpRequestBody;
        }
         
        HttpResponse response = HttpHandler.post(requestUrl, headers, httpRequestBody);
        List<HttpResponse> responses = new List<HttpResponse>();
        responses.add(response);

        return responses;
    }

    //Link will do this in production, but this can be useful for testing.
    public List<HttpResponse> getPublicToken(String institutionId) {

        Map<string, string> params = new Map<String, String>();
        String serviceEndpoint = PLAID_API_ENDPOINT + '/sandbox/public_token/create';
        Map<String, String> headers = populateHeaderMap('application/json');
        String requestUrl = serviceEndpoint + populateUrlParameters(params);
        String clientId = this.clientId;
        String secretKey = this.secretKey;
        String httpRequestBody = 
        '{"client_id": "' + clientId + 
        '","secret": "' + secretKey + 
        '","institution_id": "' + institutionId+ 
        '","initial_products": ["' + 'auth'+ 
        '"]}';
        HttpResponse response = HttpHandler.post(requestUrl, headers, httpRequestBody);
        List<HttpResponse> responses = new List<HttpResponse>();
        responses.add(response);

        return responses;
    }

    //Exchanges a public token for an access Token
    public List<HttpResponse> exchangeForAccessToken(String publicToken) {
        Map<string, string> params = new Map<String, String>();
        String serviceEndpoint = PLAID_API_ENDPOINT + '/item/public_token/exchange';
        Map<String, String> headers = populateHeaderMap(
            'application/json'
        );
        String requestUrl = serviceEndpoint + populateUrlParameters(params);
        String clientId = this.clientId;
        String secretKey = this.secretKey;
        String httpRequestBody = 
        '{"client_id": "' + clientId + 
        '","secret": "' + secretKey + 
        '","public_token": "' + publicToken + 
        '"}';
        HttpResponse response = HttpHandler.post(requestUrl, headers, httpRequestBody);
        List<HttpResponse> responses = new List<HttpResponse>();
        responses.add(response);

        return responses;

    }

    public override List<HttpResponse> getFinancialInstitutionIdentities() {
        List<HttpResponse> responses = new List<HttpResponse>();
        for (BDC_Access_Tokens__c accToken : PlaidBDCConnector.getAccessTokens()) {
            Map<string, string> params = new Map<String, String>();
            String serviceEndpoint = PLAID_API_ENDPOINT + '/item/get';
            Map<String, String> headers = populateHeaderMap(
                'application/json'
            );
            String requestUrl = serviceEndpoint + populateUrlParameters(params);
            String clientId = this.clientId;
            String secretKey = this.secretKey;
            String accessToken = accToken.Token__c;
            String httpRequestBody = 
            '{"client_id": "' + clientId + 
            '","secret": "' + secretKey + 
            '","access_token": "' + accessToken + 
            '"}';
            HttpResponse response = HttpHandler.post(requestUrl, headers, httpRequestBody);

            //the following code appends text to the body of the httpResponse to allow the connector to pass additional info to the converter
            //the converter must accordingly parse this information from the body responses.
            //This allows a connector/converter pair to pass information without modifying the method signatures, which are global and immutable

            String delimiter = ';';
            //check to make sure delimter is not used is the actual identity
            if (accToken.Financial_Institution_Identity_Id__c.contains(delimiter)) {
                throw new BDCService.BDCException(Label.ERR_BDC_IDENTITY_DELIMITER_ERROR);
            }
            response.setBody(response.getBody() + delimiter + accToken.Financial_Institution_Identity_Id__c);

            responses.add(response);
        }

        

        return responses;
        
        
    }

    /*
    * The BDCServiceOptions should have the following values populated
    * toDate
    * fromDate
    * offset
    * maxRecordstransactions 
    * bdcFinancialInstitutionIdentities - there must be at least one financial institution identity
    */
    public override List<HttpResponse> getTransactions(BDCServiceOptions options){ 

        List<HttpResponse> responses = new List<HttpResponse>();
        for (BDC_Access_Tokens__c accToken : PlaidBDCConnector.getAccessTokens()) {

        
            Map<string, string> params = new Map<String, String>();
            String serviceEndpoint = PLAID_API_ENDPOINT + '/transactions/get';
            Map<String, String> headers = populateHeaderMap(
                'application/json'
            );
            String requestUrl = serviceEndpoint + populateUrlParameters(params);
            String clientId = this.clientId;
            String accessToken = accToken.Token__c;
            String secretKey = this.secretKey;
            String fromDateString = options.fromDate.year() + '-' + formatDateForPlaid(String.valueOf(options.fromDate.month())) + '-' + formatDateForPlaid(String.valueOf(options.fromDate.day()));
            String toDateString = options.toDate.year() + '-' + formatDateForPlaid(String.valueOf(options.toDate.month())) + '-' + formatDateForPlaid(String.valueOf(options.toDate.day()));
            String countAsString = '';
            if (options.maxRecords > maxTransactionRecordsPerCallout()) {
                throw new BDCService.BDCException(Label.ERR_TOO_MANY_TRANSACTIONS_REQUESTED + String.valueOf(maxTransactionRecordsPerCallout()));
            }
            else {
                countAsString = string.valueOf(options.maxRecords);
            }
            String offsetAsString = string.valueOf(options.offset);
            
            String httpRequestBody = 
            '{ "client_id": "' + clientId + 
            '", "secret": "' + secretKey + 
            '", "access_token": "' + accessToken + 
            '", "start_date": "' + fromDateString + 
            '", "end_date": "' + toDateString +
            '", "options": {' + 
                '"count": '+ countAsString + ',' +
                '"offset": ' + offsetAsString +
            ' }' +
            ' }';
            HttpResponse response = HttpHandler.post(requestUrl, headers, httpRequestBody);
            //the following code appends text to the body of the httpResponse to allow the connector to pass additional info to the converter
            //the converter must accordingly parse this information from the body responses.
            //This allows a connector/converter pair to pass information without modifying the method signatures, which are global and immutable

            String delimiter = ';';
            //check to make sure delimter is not used is the actual identity
            if (accToken.Financial_Institution_Identity_Id__c.contains(delimiter)) {
                throw new BDCService.BDCException(Label.ERR_BDC_IDENTITY_DELIMITER_ERROR);
            }
            response.setBody(response.getBody() + delimiter + accToken.Financial_Institution_Identity_Id__c);
            responses.add(response);
        }
        return responses;
    }


    public override List<HttpResponse> getFinancialInstitutions(List<BDCFinancialInstitutionIdentity> finInstIdens){
        List<HttpResponse> allResponses = new List<HttpResponse>();
        for (BDCFinancialInstitutionIdentity anIden : finInstIdens) {
            allResponses.addAll(getFinancialInstitution(anIden.financialInstitutionId));
        }
        return allResponses;
    }

    public override List<HttpResponse> getFinancialInstitution(string finInstId){
        Map<string, string> params = new Map<String, String>();
        String serviceEndpoint = PLAID_API_ENDPOINT + '/institutions/get_by_id';
        Map<String, String> headers = populateHeaderMap(
            'application/json'
        );
        String requestUrl = serviceEndpoint + populateUrlParameters(params);
        String clientId = this.clientId;
        String secretKey = this.secretKey;
        
        String countryCodes = PlaidBDCConnector.commaQuoteList(PlaidBDCConnector.availablePlaidCountries);
        String httpRequestBody = 
        '{' + 
            '"institution_id": "' + finInstID + '",' +
            '"country_codes": [' + countryCodes + '],' + 
            '"client_id": "' + clientId + '",' + 
            '"secret": "' + secretKey + '"' +
        '}';
        HttpResponse response = HttpHandler.post(requestUrl, headers, httpRequestBody);
        List<HttpResponse> responses = new List<HttpResponse>();
        responses.add(response);
        return responses;
    }

    //Method to delete Financial Institution Identity from Plaid
    public override List<HttpResponse> deleteFinancialInstitutionIdentity(BDCFinancialInstitutionIdentity finInstIden){
        Map<String, String> params = new Map<String, String>();
        String accessToken = '';

        //Get access token from custom metadata from given financial Institution Identity
        for (BDC_Access_Tokens__c accToken : PlaidBDCConnector.getAccessTokens()) {
            if(accToken.Financial_Institution_Identity_Id__c == finInstIden.Id) {
                accessToken = accToken.Token__c;
            }
        }

        //Create Endpoint
        String serviceEndpoint = PLAID_API_ENDPOINT + '/item/remove';
        Map<String, String> headers = populateHeaderMap(
            'application/json'
        );
        String requestUrl = serviceEndpoint + populateUrlParameters(params);
        String clientId = this.clientId;
        String secretKey = this.secretKey;

        //Encorporate the acces token in body
        String httpRequestBody = 
        '{"client_id": "' + clientId + 
        '","secret": "' + secretKey + 
        '","access_token": "' + accessToken + 
        '"}';

        //Get the response
        HttpResponse response = HttpHandler.post(requestUrl, headers, httpRequestBody);
        List<HttpResponse> responses = new List<HttpResponse>();
        responses.add(response);

        return responses;
    }

    /*
    * Retrieves a List of responses of all accounts, one response per given identity in finInstIdens
    * Using too many identities may hit limits
    */
    public override List<HttpResponse> getAccountsFromFinancialInstitutionIdentities(List<BDCFinancialInstitutionIdentity> finInstIdens){
        //Get the access tokens and put them into a map of financial institution identities instead
        Map<String, BDC_Access_Tokens__c> finInstIdenToAccToken = new Map<String, BDC_Access_Tokens__c>();
        for (BDC_Access_Tokens__c accToken : PlaidBDCConnector.getAccessTokens()) {
            finInstIdenToAccToken.put(accToken.Financial_Institution_Identity_Id__c, accToken);
        }
        List<HttpResponse> responses = new List<HttpResponse>();
        for (BDCFinancialInstitutionIdentity finInstIden: finInstIdens) {
            Map<string, string> params = new Map<String, String>();
            String serviceEndpoint = PLAID_API_ENDPOINT + '/accounts/get';
            Map<String, String> headers = populateHeaderMap(
                'application/json'
            );
            String requestUrl = serviceEndpoint + populateUrlParameters(params);
            String clientId = this.clientId;
            String secretKey = this.secretKey;

            String httpRequestBody = 
            '{' +
                '"client_id": "' + clientId + '",' + 
                '"secret": "' + secretKey + '",' + 
                '"access_token": "' + finInstIdenToAccToken.get(finInstIden.Id).Token__c + '"' + 
            '}';

            HttpResponse response = HttpHandler.post(requestUrl, headers, httpRequestBody);
            responses.add(response);
        }
        return responses;
    }

    /*
    * Accounts that disappear from Plaid are probably closed. 
    */
    public override List<HttpResponse> getAccounts(List<string> bdcAccountIds){
        Map<string, string> params = new Map<String, String>();
        String serviceEndpoint = PLAID_API_ENDPOINT + '/accounts/get';
        Map<String, String> headers = populateHeaderMap(
            'application/json'
        );
        String requestUrl = serviceEndpoint + populateUrlParameters(params);
        String clientId = this.clientId;
        String secretKey = this.secretKey;
        String accessToken = 'testToken';

        //concatenate the account ids and put them in quotes per api format
        String concatAcctIds = String.join(bdcAccountIds, '","');
        concatAcctIds = '"' + concatAcctIds + '"';

        String httpRequestBody = 
        '{' +
	        '"client_id": "' + clientId + '",' + 
	        '"secret": "' + secretKey + '",' + 
	        '"access_token": "' + accessToken + '",' + 
            '"options": {' +
            '"account_ids": [' + concatAcctIds+ ']' +
            '}' +
        '}';

        HttpResponse response = HttpHandler.post(requestUrl, headers, httpRequestBody);
        List<HttpResponse> responses = new List<HttpResponse>();
        responses.add(response);

        return responses;
    }

    public override List<HttpResponse> getCategories(){
        Map<string, string> params = new Map<String, String>();
        String serviceEndpoint = PLAID_API_ENDPOINT + '/categories/get';
        Map<String, String> headers = populateHeaderMap(
            'application/json'
        );
        String requestUrl = serviceEndpoint + populateUrlParameters(params);
        String httpRequestBody =  '{}';
        HttpResponse response = HttpHandler.post(requestUrl, headers, httpRequestBody);
        List<HttpResponse> responses = new List<HttpResponse>();
        responses.add(response);
        return responses;
    }

    //A constant set by Plaid
    public override Integer maxTransactionRecordsPerCallout(){return MAX_TXNS_PER_CALLOUT;}
}