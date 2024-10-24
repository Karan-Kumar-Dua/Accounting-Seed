@IsTest
private class xLookupHelperTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req){
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/xml');
            String body = '{"lookupResults":{"Account":{"records":[{"fields":{"Id":{"displayValue":null,"value" : "a086300000BiIHkAAN"},"Name":{"displayValue" : null,"value":"GL 3"}}}]}}}';
            res.setBody(body);
            
            res.setStatusCode(200);
            return res;
        }
    }

    private class MockHttpResponseErrorGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req){
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setStatus('Bad Request');
            return res;
        }
    }

    @IsTest static void search_nullOptions() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Exception expectedEx;
        
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            try {
                List<xLookupHelper.LookupSearchResult> response = xLookupHelper.searchRecent(null,null,null,'');
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();
        }
        System.assertNotEquals(null, expectedEx);
    }
    @IsTest static void search_blankOptions() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Exception expectedEx;

        MockHttpResponseGenerator mock = new MockHttpResponseGenerator();
        Test.setMock(HttpCalloutMock.class, mock);
        HTTPResponse res =null;

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            try {
                List<xLookupHelper.LookupSearchResult> response = xLookupHelper.searchRecent('', 'Opportunity','AccountId','');
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();
        }
        System.assertEquals(null, expectedEx);
    }

    @IsTest static void testGetSObjectValue() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            xLookupHelper.LookupSearchResult response = xLookupHelper.getSObjectValue(GlobalVariables.PACKAGE_QUALIFIER + 'Billing__c', testData.billings[0].Id);

            Billing__c bill = [SELECT Name FROM Billing__c WHERE Id = :testData.billings[0].Id];
            System.assertEquals('Billing', response.getSubtitle());
            System.assertEquals(false, String.isBlank(response.getIcon()));
            System.assertEquals(false, String.isBlank(response.getId()));
            System.assertEquals(false, String.isBlank(response.getCurrency()));
            System.assertEquals(bill.Name, response.getTitle());
        }
    }
    @IsTest static void testGetSObjectValue_nulldata() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
		Exception expectedEx;
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            try {
                xLookupHelper.LookupSearchResult response = xLookupHelper.getSObjectValue(null, null);
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();
        }
        System.assertEquals(null, expectedEx);
    }

    @IsTest static void testSearchRecentError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {

            MockHttpResponseErrorGenerator mock = new MockHttpResponseErrorGenerator();
            Test.setMock(HttpCalloutMock.class, mock);

            Exception expectedEx;
            Test.startTest();
            try {
                xLookupHelper.searchRecent('foo', 'Opportunity','AccountId','');
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();

            Assert.isNotNull(expectedEx);
        }
    }

}