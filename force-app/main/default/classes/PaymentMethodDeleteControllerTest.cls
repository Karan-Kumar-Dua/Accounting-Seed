@IsTest
public with sharing class PaymentMethodDeleteControllerTest {

    @TestSetup
    static void createTestData() {
        TestDataSuite testData =TestDataSuite.getInstance(true).createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Payment_Processor_Customer__c customer = new Payment_Processor_Customer__c(
                Processor__c = testData.paymentProcessors[0].Id,
                Account__c = testData.accounts[0].Id,
                External_Id__c = 'STRIPECUSTOMERID'
            );
            insert customer;

            Payment_Method__c testPM = new Payment_Method__c();
            testPM.Customer__c = customer.Account__c;
            testPM.Type__c = 'Visa';
            testPM.Card_Holder_Name__c = 'Mr. Yellow';
            testPM.Last_Four_Digits__c = '7878';
            testPM.Default__c = true;
            testPM.Expiration_Month__c = '05';
            testPM.Expiration_Year__c = '2020';
            testPM.External_Id__c = 'STRIPECARDID';
            testPM.Status__c = 'Active';
            testPM.Payment_Processor__c = customer.Processor__c;
            insert testPM;

            System.assertNotEquals(NULL, testPM.Id);
        }

    }

    @IsTest
    static void testDeleteFromUI() {
        TestDataSuite testData =TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            MdtBindingHandlerMock mock = new MdtBindingHandlerMock(new StripeProcessorV1());
            MdtBindingHandler.instance = (MdtBindingHandler) Test.createStub(MdtBindingHandler.class, mock);

            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new MockStripeCalloutsHandler());
            Payment_Method__c pm = [SELECT Id, AcctSeed__Customer__c FROM Payment_Method__c WHERE Type__c = 'Visa' LIMIT 1];
            ApexPages.StandardController stdController = new ApexPages.StandardController(pm);
            PaymentMethodDeleteController controller = new PaymentMethodDeleteController(stdController);
            PageReference pr = controller.deleteViaUI();
            System.assertEquals(0, [SELECT count() FROM Payment_Method__c LIMIT 1]);
        }
    }

    @IsTest
    static void testDeleteFromAPI() {
        TestDataSuite testData =TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            MdtBindingHandlerMock mock = new MdtBindingHandlerMock(new StripeProcessorV1());
            MdtBindingHandler.instance = (MdtBindingHandler) Test.createStub(MdtBindingHandler.class, mock);
            
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new MockStripeCalloutsHandler());
            Payment_Method__c pm = [SELECT Id FROM Payment_Method__c WHERE Type__c = 'Visa' LIMIT 1];
            ApexPages.StandardController stdController = new ApexPages.StandardController(pm);
            PaymentMethodDeleteController controller = new PaymentMethodDeleteController(stdController);
            PaymentMethodDeleteController.OperationResult result = controller.deleteViaAPI();
            System.assertEquals(0, [SELECT count() FROM Payment_Method__c LIMIT 1]);
            System.assertEquals(true, result.status);
            System.assertEquals(NULL, result.message);
        }
    }

    public class MockStripeCalloutsHandler implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            String endpoint = req.getEndpoint();
            HttpResponse res = new HttpResponse();
            String jsonResponse;
            jsonResponse =
                '{' +
                    '"deleted": true, ' +
                    '"id": "card_17xI45EbJdMP0Nek0pVwk7BF" ' +
                '}';

            res.setHeader('Content-Type', 'application/json');
            res.setBody(jsonResponse);
            res.setStatusCode(200);
            return res;
        }
    }

    public class MdtBindingHandlerMock implements System.StubProvider {
        private PaymentProcessor pmtProc;

        public MdtBindingHandlerMock(PaymentProcessor pmtProc) {
            this.pmtProc = pmtProc;
        }

        public Object handleMethodCall(
                Object stubbedObject,
                String stubbedMethodName,
                Type returnType,
                List<Type> listOfParamTypes,
                List<String> listOfParamNames,
                List<Object> listOfArgs) {

            if (stubbedMethodName == 'resolve') {
                return pmtProc;
            }
            return null;
        }
    }

}