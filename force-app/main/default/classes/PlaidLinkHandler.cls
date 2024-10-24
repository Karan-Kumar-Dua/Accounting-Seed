public with sharing class PlaidLinkHandler {
    
    public String linkToken{get;set;}
    public String financialInstitutionIdentityId{get;set;}    
    private static Set<String> availablePlaidCountries = getSupportedPlaidCountryCodes();

    public static Set<String> getSupportedPlaidCountryCodes() {
        if (availablePlaidCountries == null) {
            availablePlaidCountries = new Set<String>();
            List<BDC_Supported_Country__mdt> countryObjs = [SELECT Id, Country_Code__c FROM BDC_Supported_Country__mdt WHERE Interface__c = 'Plaid'];
            for (BDC_Supported_Country__mdt aCountry : countryObjs) {
                availablePlaidCountries.add(aCountry.Country_Code__c);

            }
        }
        return availablePlaidCountries;
    }
    
    public PlaidLinkHandler() {
        String param = ApexPages.currentPage().getParameters().get('params');

        Set<String> unSupportedCountries = new Set<String>();
        Set<String> supportedCountries = new Set<String>();
        Set<String> parsedCountries = new Set<String>();

        //if no countries were passed or param doesn't exist default to US only
        String countriesParam = ApexPages.currentPage().getParameters().get('countries');
        parsedCountries = countriesParam == null ? new Set<String>{'US'} : new Set<String>(countriesParam.split(',')); 
        if (parsedCountries.size() == 1 && new List<String>(parsedCountries)[0] == '') {
            supportedCountries.add('US');
        }
        else {
            //assure that any input countries are in the list of available countries
            for (String potentialCountry: parsedCountries) {
                if (availablePlaidCountries.contains(potentialCountry)) {
                    supportedCountries.add(potentialCountry);
                } else {
                    unSupportedCountries.add(potentialCountry);
                }
            }

        }

        if(String.isNotBlank(param)){
            financialInstitutionIdentityId = String.escapeSingleQuotes(param);
        }
        PlaidBDCConnector p = new PlaidBDCConnector();
        List<httpResponse> responses = p.getLinkToken(financialInstitutionIdentityId, supportedCountries);
        Map<String, String> mTokenResponse = (Map<String,String>) JSON.deserialize(responses[0].getBody(), Map<String,String>.class);
        linkToken = mTokenResponse.get('link_token');        
    }

    @AuraEnabled
    public static Object exchangeAccessToken(String publicToken, String finId){
        Map<String, HttpResponse> finIdToResponse = new Map<String, HttpResponse>();  
        try {
            PlaidBDCConnector connector = new PlaidBDCConnector();
            List<HttpResponse> resp =  connector.exchangeForAccessToken(publicToken);
            finIdToResponse.put(finId, resp[0]);
            // if to make sure that we have accesstoken then only use it for other purpose
            if(finIdToResponse.values().size() > 0){
                PlaidBDCConverter convertor = new PlaidBDCConverter();
                convertor.convertAccessTokens(finIdToResponse);
            }
            return JSON.serializePretty(resp[0].getBody()+'--'+finId);
        } catch (Exception e) {
            return e;
        }
    }

}