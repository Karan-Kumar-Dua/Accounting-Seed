@IsTest
public with sharing class LookupServiceTest {
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testSearchOk() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            // setup callout mock
            String body = '{"lookupResults":{"Account":{"records":[{"fields":{"Id":{"displayValue":null,"value" : "a086300000BiIHkAAN"},"Name":{"displayValue" : null,"value":"GL 3"}}}]}}}';
            MockHttpResponseGenerator mock = new MockHttpResponseGenerator(
                body, 
                'application/json', 
                200,
                'OK'
            );
            Test.setMock(HttpCalloutMock.class, mock);

            // run the test
            Test.startTest();
            LookupService srvc = new LookupService('   cawep4g8poiw4glkjsdngv?vaoei8wnvpi.avnp9iw83h4gvp   ');
            String result = srvc.search('Account', 'Name', 'foo', null);
            Test.stopTest();

            // verify the results
            Assert.areEqual(body, result);
        }
    }

    @IsTest
    static void testSearchNullTerm() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            // setup callout mock
            String body = '{"lookupResults":{"Account":{"records":[{"fields":{"Id":{"displayValue":null,"value" : "a086300000BiIHkAAN"},"Name":{"displayValue" : null,"value":"GL 3"}}}]}}}';
            MockHttpResponseGenerator mock = new MockHttpResponseGenerator(
                body, 
                'application/json', 
                200,
                'OK'
            );
            Test.setMock(HttpCalloutMock.class, mock);

            // run the test
            Test.startTest();
            LookupService srvc = new LookupService('cawep4g8poiw4glkjsdngv?vaoei8wnvpi.avnp9iw83h4gvp');
            String result = srvc.search('Account', 'Name', null, null);
            Test.stopTest();

            // verify the results
            Assert.areEqual(body, result);
        }
    }

    @IsTest
    static void testSearchError() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            // setup callout mock
            Integer httpCode = 400;
            String httpStatus = 'Bad Request';
            MockHttpResponseGenerator mock = new MockHttpResponseGenerator(
                null, 
                null, 
                httpCode,
                httpStatus
            );
            Test.setMock(HttpCalloutMock.class, mock);
 
            // run the test
            Test.startTest();
            Exception expectedException;
            LookupService srvc = new LookupService('bad_session_id');
            try {
                String result = srvc.search('Account', 'Name', 'foo', null);
            } catch (LookupService.LookupServiceException e) {
                expectedException = e;
            }
            Test.stopTest();
 
            // verify the results
            Assert.isNotNull(expectedException);
            Assert.areEqual(Label.ERR_LOOKUP_CALLOUT_NOT_OK + ' ' + httpCode + ' ' + httpStatus + ' ', expectedException.getMessage());
        }
    }

    private class MockHttpResponseGenerator implements HttpCalloutMock {
        private String body;
        private String contentType;
        private String httpStatus;
        private Integer httpCode;
        public MockHttpResponseGenerator(String body, String contentType, Integer httpCode, String httpStatus) {
            this.body = body;
            this.contentType = contentType;
            this.httpStatus = httpStatus;
            this.httpCode = httpCode;
        }
        public HTTPResponse respond(HTTPRequest req){
            HttpResponse res = new HttpResponse();
            if (String.isNotEmpty(this.contentType)) {
                res.setHeader('Content-Type', contentType);
            }
            if (String.isNotEmpty(this.body)) {
                res.setBody(this.body);
            }
            if (String.isNotEmpty(this.httpStatus)) {
                res.setStatus(this.httpStatus);
            }
            if (this.httpCode != null) {
                res.setStatusCode(this.httpCode);
            }
            return res;
        }
    }
}