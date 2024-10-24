@IsTest
private class JWTHelperTest {
    @isTest
    private static void testGetAuthToken() {
        Test.startTest();
        JWTHelper jwtToken = new JWTHelper('RS512');
        jwtToken.iss = '234';
        jwtToken.aud = '123';
        jwtToken.sub = '012';
        jwtToken.pkcs8 = getExternalSettings().Value_5__c;

        String jwt = jwtToken.issue(); 
        System.assertNotEquals('', jwt);        
    }

    private static External_Settings__mdt getExternalSettings() {
        return DomainUtils.queryExternalSettingsByDeveloperName('Yodlee_Settings');                    
    }
}