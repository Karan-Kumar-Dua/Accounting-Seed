public with sharing class FastLinkHandler {
    public String fastLinkProperties {get; private set;} 
    public static final String FASTLINK_URL = GlobalVariables.fastLinkSettings.Value_1__c + GlobalVariables.fastLinkSettings.Value_2__c;
    public String jwt {get; private set;}

    public FastLinkHandler() {
        jwt = YodleeBDCConnector.getUserToken();    
        FastLinkConfigModel fastLinkConfig = new FastLinkConfigModel();
        fastLinkConfig.jwtToken = 'Bearer ' + jwt;  
        fastLinkConfig.fastLinkURL = FASTLINK_URL;  
        fastLinkConfig.params = new ParamsModel();
        String providerAccountId = ApexPages.currentPage().getParameters().get('params');
        if (providerAccountId != NULL) {
            fastLinkConfig.params.providerAccountId = providerAccountId.escapeHtml4();
            String flow = ApexPages.currentPage().getParameters().get('action');
            fastLinkConfig.params.flow = flow != NULL ? flow : 'edit';
        }
        this.fastLinkProperties = JSON.serialize(fastLinkConfig, true);            
    } 

    @TestVisible
    private class FastLinkConfigModel {
        @TestVisible
        String fastLinkURL;
        @TestVisible
        String jwtToken;
        @TestVisible
		ParamsModel params;			
    }

    @TestVisible
    private class ParamsModel {
        @TestVisible
        String flow;
        @TestVisible
        String providerAccountId;
    }
    
}