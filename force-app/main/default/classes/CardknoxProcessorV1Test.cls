@IsTest
public with sharing class CardknoxProcessorV1Test {
    public static final String XKEY = 'aowiern9w8ngbpoiwmbvpoan3ebn';
    public class MockCustomerResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Authorization', XKEY);
            res.setHeader('X-Recurring-Api-Version', '2.0');
            res.setBody('{"BillLastName" : "Piyu1","CustomerId" : "c11844844"}');
            res.setStatusCode(200);
            return res;
        }
    }
    public class MockCommonFailureResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Authorization', XKEY);
            res.setHeader('X-Recurring-Api-Version', '2.0');
            res.setBody('{"Error":"Invalid gateway key (Specified Key Not Found)","Result":"E"}');
            res.setStatusCode(200);
            return res;
        }
    }
    public class MockPaymentMethodResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Authorization', XKEY);
            res.setHeader('X-Recurring-Api-Version', '2.0');
            res.setBody('{"Result": "S","PaymentMethodId": "c123456_pm123456","CustomerId" : "c11844844","TokenType" : "cc","Exp" : "1224","Issuer" : "Visa","Token" : "4000000000004242;sut_02_1_cc_visa_keyed_01_20220822T145629Z_7200_hf-jrfg-2_f717484c4ac2416d92e44a84da607387_8c38926fd50b5759d4d7d61c1e536eed329afc29551998b7b9a47a6f1c9e992b"}');
            res.setStatusCode(200);
            return res;
        }
    }
    public class MockListPaymentMethodResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Authorization', XKEY);
            res.setHeader('X-Recurring-Api-Version', '2.0');
            res.setBody('{"Result": "S",'+
                '"PaymentMethods" : [{ "PaymentMethodId": "c123456_pm123456","CustomerId" : "c11844844","TokenType" : "CC","Exp" : "1224","MaskedNumber":"xxxxx9999","Name":"Test","CardType":"Visa"},{ "PaymentMethodId": "c123456_pm123456","CustomerId" : "c11844844","TokenType" : "Check","MaskedNumber":"xxxxx9999","Name":"Test"}]}');
            res.setStatusCode(200);
            return res;
        }
    }
    public class MockProcessTransactionResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Authorization', XKEY);
            res.setHeader('X-Recurring-Api-Version', '2.0');
            res.setBody('{"Result": "S","GatewayStatus":"Approved","PaymentMethodId": "c123456_pm123456","Amount": "1","RefNum":"1234","GatewayRefNum":"1234"}');
            res.setStatusCode(200);
            return res;
        }
    }
    public class MockProcessTransactionResponseDeclined implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Authorization', XKEY);
            res.setHeader('X-Recurring-Api-Version', '2.0');
            res.setBody('{"Result": "S","GatewayStatus":"Declined","PaymentMethodId": "c123456_pm123456","Amount": "1","RefNum":"1234","GatewayRefNum":"1234"}');
            res.setStatusCode(200);
            return res;
        }
    }
    private class MockReportingResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Authorization', 'concretiodev80eb19edb91340e5b62e852d1a32be8d');
            res.setHeader('X-Recurring-Api-Version', '2.0');
            res.setBody('{"SoftwareName" : "ACME Inc.","SoftwareVersion" : "2.0","xCommand" : "Report:Transaction","xReportData" : [{"xErrorCode":"Cardknox Error","xResponseError":"testerror","xRefNum":"1234","xStatus":"Success","xResponseBatch":"1234","xProcessingFee":"2"}]}');
            res.setStatusCode(200);
            return res;
        }
    }
    private class MockActivityStatusUpdateResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            String body = '{"xResult":"S","xStatus":"Success","xError":"","xRefNum":"10147562579","xReportingMaxTransactions":"5000","xRecordsReturned":"7","xReportData":[' +
                '{"xRefNum":"0","xStatus":"0","xResponseResult":"Approved","xResponseError":"","xErrorCode":"0","xResponseBatch":"25020810","xCommand":"CC:Sale","xCurrency":"USD","xVoid":"0","xVoidable":"1"},' +
                '{"xRefNum":"1","xStatus":"0","xResponseResult":"Declined","xResponseError":"","xErrorCode":"0","xResponseBatch":"25020810","xCommand":"CC:Sale","xCurrency":"USD","xVoid":"0","xVoidable":"1"},' +
                '{"xRefNum":"2","xStatus":"0","xResponseResult":"Error","xResponseError":"","xErrorCode":"0","xResponseBatch":"25020810","xCommand":"CC:Sale","xCurrency":"USD","xVoid":"0","xVoidable":"1"},' +
                '{"xRefNum":"3","xStatus":"0","xResponseResult":"Declined","xResponseError":"","xErrorCode":"0","xResponseBatch":"25020810","xCommand":"Check:Sale","xCurrency":"USD","xVoid":"0","xVoidable":"1"},' +
                '{"xRefNum":"4","xStatus":"0","xResponseResult":"Error","xResponseError":"","xErrorCode":"0","xResponseBatch":"25020810","xCommand":"Check:Sale","xCurrency":"USD","xVoid":"0","xVoidable":"1"},' +
                '{"xRefNum":"5","xStatus":"0","xResponseResult":"Approved","xResponseError":"","xErrorCode":"0","xResponseBatch":"25020810","xCommand":"Check:Sale","xCurrency":"USD","xVoid":"0","xVoidable":"1"},' +
                '{"xRefNum":"6","xStatus":"6","xResponseResult":"Approved","xResponseError":"","xErrorCode":"0","xResponseBatch":"25020810","xCommand":"Check:Sale","xCurrency":"USD","xVoid":"0","xVoidable":"1"},' +
                '{"xRefNum":"7","xStatus":"14","xResponseResult":"Approved","xResponseError":"","xErrorCode":"0","xResponseBatch":"25020810","xCommand":"Check:Sale","xCurrency":"USD","xVoid":"0","xVoidable":"1"},' +
                '{"xRefNum":"8","xStatus":"16","xResponseResult":"Approved","xResponseError":"","xErrorCode":"0","xResponseBatch":"25020810","xCommand":"Check:Sale","xCurrency":"USD","xVoid":"0","xVoidable":"1"},' +
                '{"xRefNum":"9","xStatus":"6","xResponseResult":"Approved","xResponseError":"","xErrorCode":"0","xResponseBatch":"25020810","xCommand":"Check:Sale","xCurrency":"USD","xVoid":"0","xVoidable":"1"},' +
                '{"xRefNum":"10","xStatus":"0","xResponseResult":"Approved","xResponseError":"","xErrorCode":"0","xResponseBatch":"25020810","xCommand":"Check:Sale","xCurrency":"USD","xVoid":"1","xVoidable":"1"},' +
                '{"xRefNum":"11","xStatus":"0","xResponseResult":"Approved","xResponseError":"","xErrorCode":"0","xResponseBatch":"25020810","xCommand":"CC:Sale","xCurrency":"USD","xVoid":"1","xVoidable":"1"}' +
            + ']}';
            HttpResponse res = new HttpResponse();
            res.setHeader('Authorization', 'concretiodev80eb19edb91340e5b62e852d1a32be8d');
            res.setHeader('X-Recurring-Api-Version', '2.0');
            res.setBody(body);
            res.setStatusCode(200);
            return res;
        }
    }
    public class MockVoidFailureInvalidKeyResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Authorization', XKEY);
            res.setHeader('X-Recurring-Api-Version', '2.0');
            res.setBody('{"xError":"Invalid gateway key (Specified Key Not Found)","xResult":"E"}');
            res.setStatusCode(200);
            return res;
        }
    }
    public class MockVoidFailureNoXKeySetupResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Authorization', XKEY);
            res.setHeader('X-Recurring-Api-Version', '2.0');
            res.setBody('{"xError":"No XKey is setup for the payment processor.","xResult":"E"}');
            res.setStatusCode(200);
            return res;
        }
    }
    public class MockVoidFailedAlreadyVoidedResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Authorization', XKEY);
            res.setHeader('X-Recurring-Api-Version', '2.0');
            res.setBody('{"xResult":"E","xStatus":"Error","xError":"Transaction Previously Voided.",'+
                    '"xErrorCode":"01462","xRefNum":"10185750732","xRefNumCurrent":"10187347515",'+
                    '"xExp":"1225","xDate":"5/6/2024 6:10:05 AM","xMaskedCardNumber":"4xxxxxxxxxxx4242",'+
                    '"xCardType":"Visa","xName":"Test"}');
            res.setStatusCode(200);
            return res;
        }
    }
    public class MockVoidFailedTransactionIsClearedResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Authorization', XKEY);
            res.setHeader('X-Recurring-Api-Version', '2.0');
            res.setBody('{"xResult":"E","xStatus":"Error","xError":"Transaction Cannot Be Modified: Cleared",' + 
                '"xErrorCode":"99999","xRefNum":"10144381621","xRefNumCurrent":"10187347180","xAvsResultCode":"",'+
                '"xAvsResult":"Unmapped AVS response","xCvvResultCode":"","xCvvResult":"No CVV data available",'+
                '"xMaskedAccountNumber":"xxxxx9999","xCardType":"Unknown","xName":"Test Check","xDate":"5/6/2024 6:07:34 AM",'+
                '"xFraudStatus":"16","xEntryMethod":"Unknown"}');
            res.setStatusCode(200);
            return res;
        }
    }
    public class MockVoidFailedInvalidRefNumResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Authorization', XKEY);
            res.setHeader('X-Recurring-Api-Version', '2.0');
            res.setBody('{"xResult":"E","xStatus":"Error","xAuthCode":"000000","xError":"Invalid xRefNum.",'+
                        '"xRefNum":"10187357058","xErrorCode":"99999"}');
            res.setStatusCode(200);
            return res;
        }
    }
    public class MockVoidFailedTransactionIssueRefund implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Authorization', XKEY);
            res.setHeader('X-Recurring-Api-Version', '2.0');
            res.setBody('{"xResult":"E","xStatus":"Error","xError":"Transaction can no longer be voided; issue refund",' + 
                '"xErrorCode":"99999","xRefNum":"10144381621","xRefNumCurrent":"10187347180","xAvsResultCode":"",'+
                '"xAvsResult":"Unmapped AVS response","xCvvResultCode":"","xCvvResult":"No CVV data available",'+
                '"xMaskedAccountNumber":"xxxxx9999","xCardType":"Unknown","xName":"Test Check","xDate":"5/6/2024 6:07:34 AM",'+
                '"xFraudStatus":"16","xEntryMethod":"Unknown"}');
            res.setStatusCode(200);
            return res;
        }
    }
    public class MockVoidSuccessResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Authorization', XKEY);
            res.setHeader('X-Recurring-Api-Version', '2.0');
            res.setBody('{"xResult":"A","xStatus":"Approved","xError":"","xErrorCode":"00000",'+
                    '"xRefNum":"10187358170","xRefNumCurrent":"10187358306","xExp":"1225",'+
                    '"xAvsResultCode":"NNN","xAvsResult":"Address:No Match & 5 Digit Zip: No Match",'+
                    '"xCvvResultCode":"","xCvvResult":"No CVV data available","xAuthAmount":"1.00",'+
                    '"xMaskedCardNumber":"4xxxxxxxxxxx4242","xCardType":"Visa","xMID":"xxxxxxxxxx9999",'+
                    '"xTID":"xxxxx6789","xCurrency":"USD","xDate":"5/6/2024 6:55:46 AM","xEntryMethod":"Unknown"}');
            res.setStatusCode(200);
            return res;
        }
    }
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
        Keys__c key = new Keys__c();
        key.Name = 'cardknox1';
        key.KeyId__c = 'cardknox1';
        key.Value_1__c = 'testxkey';
        key.Value_2__c = 'testifieldskey';
        INSERT key;
    }
    @IsTest
    public static void testCreateCustomer() {
        Test.setMock(HttpCalloutMock.class, new MockCustomerResponse());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

            Contact con1 = new Contact(LastName='Test 1');
            INSERT con1;
            Contact con2 = new Contact(LastName='Test 2');
            INSERT con2;

            Account acc = new Account(Name ='Test 1',Billing_Contact__c=con1.Id,Shipping_Contact__c=con2.Id);
            INSERT acc;

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = acc.Id, Processor__c = testData.paymentProcessors[2].Id, External_Id__c='123');
            
            Payment_Processor_Customer__c ppcResp;
            Test.startTest();
            CardknoxProcessorV1 cp = new CardknoxProcessorV1();
            try{
                ppcResp = cp.createCustomer(ppc);
            }catch(Exception exp){
                System.assertEquals(true, !String.isBlank(exp.getMessage()));
            }
            
            Test.stopTest();
    }
    @IsTest
    public static void testGetCustomer() {
        Test.setMock(HttpCalloutMock.class, new MockCustomerResponse());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = testData.paymentProcessors[2].Id, External_Id__c='123');
            INSERT ppc;


            Payment_Processor_Customer__c ppcResp;
            Test.startTest();
            CardknoxProcessorV1 cp = new CardknoxProcessorV1();
            ppcResp = cp.getCustomer(ppc);
            Test.stopTest();

            System.assertNotEquals(null,ppcResp);
            System.assertEquals('123',ppcResp.External_Id__c);
            System.assertEquals(testData.accounts.get(1).Id,ppcResp.Account__c);
        }
    }
    @IsTest
    public static void testGetCustomerFailure() {
        Test.setMock(HttpCalloutMock.class, new MockCommonFailureResponse());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = testData.paymentProcessors[2].Id, External_Id__c='123');
            INSERT ppc;

            Payment_Processor_Customer__c ppcResp;
            Test.startTest();
            CardknoxProcessorV1 cp = new CardknoxProcessorV1();
            try{
                ppcResp = cp.getCustomer(ppc);
                Assert.fail(Label.ERR_INVALID_XKEY_VALUE + ' Exception expected.');
            }catch(Exception exp){
                System.assertEquals(Label.ERR_INVALID_XKEY_VALUE, exp.getMessage());
            }
            Test.stopTest();

            System.assertEquals(null,ppcResp);
        }
    }
    @IsTest
    public static void testDeleteCustomer() {
        Test.setMock(HttpCalloutMock.class, new MockCustomerResponse());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = testData.paymentProcessors[2].Id, External_Id__c='123');
            INSERT ppc;

            Test.startTest();
            CardknoxProcessorV1 cp = new CardknoxProcessorV1();
            try{
                cp.deleteCustomer(ppc);
                Assert.fail('Id is required Exception expected.');
            }catch(Exception exp){
                System.assertEquals(false, exp.getMessage().contains('Id is required'));
            }
            Test.stopTest();
        }
    }
    @IsTest
    public static void testCreatePaymentMethod() {
        Test.setMock(HttpCalloutMock.class, new MockPaymentMethodResponse());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = testData.paymentProcessors[2].Id, External_Id__c='12345678;abcd',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Credit Card', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Type__c ='Visa');
            
            Test.startTest();
            Payment_Method__c pmResp;
            CardknoxProcessorV1 cp = new CardknoxProcessorV1();
            pmResp = cp.createPaymentMethod(pm,'12345678;abcd');
            Test.stopTest();

            System.assertNotEquals(null,pmResp);
            System.assertEquals('c123456_pm123456',pmResp.External_Id__c);
            System.assertEquals(testData.accounts.get(1).Id,pmResp.Customer__c);
        }
    }
    @IsTest
    public static void testGetPaymentMethod() {
        Test.setMock(HttpCalloutMock.class, new MockPaymentMethodResponse());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = testData.paymentProcessors[2].Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Credit Card', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Type__c ='Visa');
            INSERT pm;

            Test.startTest();
            Payment_Method__c pmResp;
            CardknoxProcessorV1 cp = new CardknoxProcessorV1();
            pmResp = cp.getPaymentMethod(pm);
            Test.stopTest();

            System.assertNotEquals(null,pmResp);
            System.assertEquals('123',pmResp.External_Id__c);
            System.assertEquals('4242',pmResp.Last_Four_Digits__c);
            System.assertEquals(testData.accounts.get(1).Id,pmResp.Customer__c);
        }
    }
    @IsTest
    public static void testDeletePaymentMethod() {
        Test.setMock(HttpCalloutMock.class, new MockPaymentMethodResponse());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = testData.paymentProcessors[2].Id, External_Id__c='123');
            INSERT ppc;
            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = testData.paymentProcessors[2].Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Credit Card', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Type__c ='Visa');
            INSERT pm;


            Test.startTest();
            CardknoxProcessorV1 cp = new CardknoxProcessorV1();

            try{
                cp.deletePaymentMethod(pm);
                Assert.fail('Delete Failed Exception expected.');
            }catch(Exception exp){
                System.assertEquals(true, exp.getMessage().contains('Delete failed'));
            }
            Test.stopTest();
        }
    }
    @IsTest
    public static void testUpdatePaymentMethod() {
        Test.setMock(HttpCalloutMock.class, new MockPaymentMethodResponse());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = testData.paymentProcessors[2].Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = testData.paymentProcessors[2].Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Credit Card', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Type__c ='Visa',Default__c=true);
            INSERT pm;

            Test.startTest();
            Payment_Method__c pmResp;
            CardknoxProcessorV1 cp = new CardknoxProcessorV1();
            try{
                pmResp = cp.updatePaymentMethod(pm);
            }catch(Exception ex){
                System.assertEquals(true,!String.isBlank(ex.getMessage()));
            }
            Test.stopTest();

            System.assertNotEquals(null,pmResp);
        }
    }

    //signature test cases
    @IsTest
    public static void testGetCutomers() {
        //Test.setMock(HttpCalloutMock.class, new MockPaymentMethodResponse());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            List<Payment_Processor_Customer__c> pmResp;
            Test.startTest();
            CardknoxProcessorV1 cp = new CardknoxProcessorV1();
            try{
                pmResp = cp.getCustomers(testData.paymentProcessors[2]);
                Assert.fail('Not Implemented Exception expected.');
            }catch(Exception e){
                System.assertEquals(true, e.getMessage().contains('Not Implemented'));
            }
            Test.stopTest();
        }
    }
    @IsTest
    public static void testUpdateCustomer() {
        //Test.setMock(HttpCalloutMock.class, new MockPaymentMethodResponse());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
           
            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = testData.paymentProcessors[2].Id, External_Id__c='123');
            INSERT ppc;

            Payment_Processor_Customer__c pmResp;
            Test.startTest();
            CardknoxProcessorV1 cp = new CardknoxProcessorV1();
            try{
                pmResp = cp.updateCustomer(ppc);
                Assert.fail('Not Implemented Exception expected.');
            }catch(Exception e){
                System.assertEquals(true, e.getMessage().contains('Not Implemented'));
            }
            Test.stopTest();
        }
    }
    @IsTest
    public static void testListPaymentMethods() {
        Test.setMock(HttpCalloutMock.class, new MockListPaymentMethodResponse());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
           
            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = testData.paymentProcessors[2].Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = testData.paymentProcessors[2].Id, External_Id__c='123',
            Last_Four_Digits__c = '4242',Payment_Method_Type__c='Credit Card', Status__c='Active',
            Expiration_Month__c='12',Expiration_Year__c='2224',Type__c ='Visa',Default__c=true);
            INSERT pm;

            Test.startTest();
            CardknoxProcessorV1 cp = new CardknoxProcessorV1();
            List<Payment_Method__c> pms = cp.getPaymentMethods(ppc);

            System.assertEquals(2,pms.size());
            Test.stopTest();
        }
    }
    @IsTest
    public static void testCCSale() {
        Test.setMock(HttpCalloutMock.class, new MockProcessTransactionResponse());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Cash_Receipt__c cReciept = new Cash_Receipt__c(
                        Account__c = testData.accounts.get(1).Id,
                        Amount__c = 400,
                        Status__c = 'Approved',
                        Receipt_Date__c = System.today(),
                        Purpose__c = 'Customer Receipt',
                        Payment_Reference__c = '12345',
                        Accounting_Period__c = testData.acctPeriods.get(0).Id,
                        Convenience_Fees_Charged__c = 10
                    );

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = testData.paymentProcessors[3].Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = testData.paymentProcessors[3].Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Credit Card', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Type__c ='Visa',Default__c=true);
            INSERT pm;

            Test.startTest();
            List<PaymentSaleItem> saleItems = new List<PaymentSaleItem>();
            saleItems.add(new PaymentSaleItem(pm,cReciept));

            CardknoxProcessorV1 cp = new CardknoxProcessorV1();

            List<PaymentSaleItem> responseSaleItems = cp.ccSale(saleItems);
            System.assertEquals(400,responseSaleItems[0].paymentActivity.Amount__c);
            System.assertEquals('Success',responseSaleItems[0].paymentActivity.Status__c);
            System.assertEquals(1,[SELECT Id FROM Payment_Activity__c].size());
            List<Cash_Receipt__c> cr = [SELECT Id, Bank_Account__c FROM Cash_Receipt__c];
            System.assertEquals(1, cr.size());
            System.assertEquals(testData.paymentProcessors[2].Merchant_GL_Account__c, cr[0].Bank_Account__c);
            Test.stopTest();
        }
    }
    @IsTest
    public static void testCCSalePSaleItems() {
        Test.setMock(HttpCalloutMock.class, new MockProcessTransactionResponse());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Cash_Receipt__c cReciept = new Cash_Receipt__c(
                        Account__c = testData.accounts.get(1).Id,
                        Amount__c = 400,
                        Status__c = 'Approved',
                        Receipt_Date__c = System.today(),
                        Purpose__c = 'Customer Receipt',
                        Payment_Reference__c = '12345',
                        Accounting_Period__c = testData.acctPeriods.get(0).Id,
                        Convenience_Fees_Charged__c = 10
                    );

            
            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c =testData.paymentProcessors[3].Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = testData.paymentProcessors[3].Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Credit Card', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Type__c ='Visa',Default__c=true);
            INSERT pm;

            Test.startTest();
            List<PaymentSaleItem> saleItems = new List<PaymentSaleItem>();
            saleItems.add(new PaymentSaleItem(pm,cReciept));
            CardknoxProcessorV1 cp = new CardknoxProcessorV1();
            List<PaymentSaleItem> responseSaleItems = cp.ccSale(saleItems);

            System.assertEquals(400,responseSaleItems[0].cashReceipt.Amount__c);
            System.assertEquals('Approved',responseSaleItems[0].cashReceipt.Status__c);
            System.assertEquals(1,[SELECT Id FROM Payment_Activity__c].size());
            System.assertEquals(1,[SELECT Id FROM Cash_Receipt__c].size());
            Test.stopTest();
        }
    }
    @IsTest
    public static void testCCSaleError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Cash_Receipt__c cReciept = new Cash_Receipt__c(
                        Account__c = testData.accounts.get(1).Id,
                        Amount__c = 400,
                        Status__c = 'Approved',
                        Receipt_Date__c = System.today(),
                        Purpose__c = 'Customer Receipt',
                        Payment_Reference__c = '12345',
                        Accounting_Period__c = testData.acctPeriods.get(0).Id
                    );

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = testData.paymentProcessors[2].Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = testData.paymentProcessors[2].Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Credit Card', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Type__c ='Visa',Default__c=true);
            INSERT pm;

            Test.startTest();
            List<PaymentSaleItem> pmResp;
            CardknoxProcessorV1 cp = new CardknoxProcessorV1();
            pmResp = cp.ccSale(new List<PaymentSaleItem> { new PaymentSaleItem(pm, cReciept)});

            System.assertEquals(400,pmResp[0].paymentActivity.Amount__c);
            System.assertEquals('Error',pmResp[0].paymentActivity.Status__c);
            System.assertEquals(1,[SELECT Id FROM Payment_Activity__c].size());
            Test.stopTest();
        }
    }
    @IsTest
    public static void testACHSale() {
        Test.setMock(HttpCalloutMock.class, new MockProcessTransactionResponse());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        Cash_Receipt__c cReciept = new Cash_Receipt__c(
                    Account__c = testData.accounts.get(1).Id,
                    Amount__c = 400,
                    Status__c = 'Approved',
                    Receipt_Date__c = System.today(),
                    Purpose__c = 'Customer Receipt',
                    Payment_Reference__c = '12345',
                    Accounting_Period__c = testData.acctPeriods.get(0).Id
                );
        System.runAs(testData.users.get(1)) {

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = testData.paymentProcessors[2].Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = testData.paymentProcessors[2].Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Bank Account', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Type__c ='Visa',Bank_Account_Type__c ='Individual',Default__c=true);
            INSERT pm;

            Test.startTest();
            List<PaymentSaleItem> pmResp;
            CardknoxProcessorV1 cp = new CardknoxProcessorV1();
            
            pmResp = cp.achSale(new List<PaymentSaleItem> { new PaymentSaleItem(pm, cReciept)});
            
            System.assertEquals(400,pmResp[0].paymentActivity.Amount__c);
            System.assertEquals('Pending',pmResp[0].paymentActivity.Status__c);
            System.assertEquals(1,[SELECT Id FROM Payment_Activity__c].size());
            System.assertEquals(1,[SELECT Id FROM Cash_Receipt__c].size());
            Test.stopTest();
        }
    }
    @IsTest
    public static void testACHSalePSaleItems() {
        Test.setMock(HttpCalloutMock.class, new MockProcessTransactionResponse());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Cash_Receipt__c cReciept = new Cash_Receipt__c(
                        Account__c = testData.accounts.get(1).Id,
                        Amount__c = 400,
                        Status__c = 'Approved',
                        Receipt_Date__c = System.today(),
                        Purpose__c = 'Customer Receipt',
                        Payment_Reference__c = '12345',
                        Accounting_Period__c = testData.acctPeriods.get(0).Id,
                        Convenience_Fees_Charged__c = 10
                    );

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = testData.paymentProcessors[2].Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = testData.paymentProcessors[2].Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Bank Account', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Type__c ='Visa',Default__c=true, Bank_Account_Type__c ='Individual');
            INSERT pm;

            Test.startTest();
            List<PaymentSaleItem> saleItems = new List<PaymentSaleItem>();
            saleItems.add(new PaymentSaleItem(pm,cReciept));
            CardknoxProcessorV1 cp = new CardknoxProcessorV1();
            List<PaymentSaleItem> responseSaleItems = cp.achSale(saleItems);

            System.assertEquals(400,responseSaleItems[0].cashReceipt.Amount__c);
            System.assertEquals('Approved',responseSaleItems[0].cashReceipt.Status__c);
            System.assertEquals(1,[SELECT Id FROM Payment_Activity__c].size());
            System.assertEquals(1,[SELECT Id FROM Cash_Receipt__c].size());
            Test.stopTest();
        }
    }
    @IsTest
    public static void testGetPaymentActivityStatus() {
        Test.setMock(HttpCalloutMock.class, new MockActivityStatusUpdateResponse());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Account customer = testData.accounts.get(1);
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];
            Accounting_Period__c period = testData.acctPeriods.get(0);

            List<Cash_Receipt__c> crs = new List<Cash_Receipt__c>{
                new Cash_Receipt__c(
                    Account__c = customer.Id,
                    Amount__c = 10,
                    Payment_Reference__c = '0',
                    Accounting_Period__c = period.Id
                ),
                new Cash_Receipt__c(
                    Account__c = customer.Id,
                    Amount__c = 10,
                    Payment_Reference__c = '1',
                    Accounting_Period__c = period.Id
                ),
                new Cash_Receipt__c(
                    Account__c = customer.Id,
                    Amount__c = 10,
                    Payment_Reference__c = '2',
                    Accounting_Period__c = period.Id
                ),
                new Cash_Receipt__c(
                    Account__c = customer.Id,
                    Amount__c = 10,
                    Payment_Reference__c = '3',
                    Accounting_Period__c = period.Id
                ),
                new Cash_Receipt__c(
                    Account__c = customer.Id,
                    Amount__c = 10,
                    Payment_Reference__c = '4',
                    Accounting_Period__c = period.Id
                ),
                new Cash_Receipt__c(
                    Account__c = customer.Id,
                    Amount__c = 10,
                    Payment_Reference__c = '5',
                    Accounting_Period__c = period.Id
                ),
                new Cash_Receipt__c(
                    Account__c = customer.Id,
                    Amount__c = 10,
                    Payment_Reference__c = '6',
                    Accounting_Period__c = period.Id
                ),
                new Cash_Receipt__c(
                    Account__c = customer.Id,
                    Amount__c = 10,
                    Payment_Reference__c = '7',
                    Accounting_Period__c = period.Id
                ),
                new Cash_Receipt__c(
                    Account__c = customer.Id,
                    Amount__c = 10,
                    Payment_Reference__c = '8',
                    Accounting_Period__c = period.Id
                ),
                new Cash_Receipt__c(
                    Account__c = customer.Id,
                    Amount__c = 10,
                    Payment_Reference__c = '9',
                    Accounting_Period__c = period.Id
                ),
                new Cash_Receipt__c(
                    Account__c = customer.Id,
                    Amount__c = 10,
                    Payment_Reference__c = '10',
                    Accounting_Period__c = period.Id
                ),
                new Cash_Receipt__c(
                    Account__c = customer.Id,
                    Amount__c = 10,
                    Payment_Reference__c = '11',
                    Accounting_Period__c = period.Id
                )
            };
            insert crs;

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(
                Account__c = customer.Id, 
                Processor__c = paymentProcessor.Id, 
                External_Id__c = '123'
            );
            insert ppc;

            Payment_Method__c paymentMethod = new Payment_Method__c(
                Customer__c = customer.Id, 
                Payment_Processor__c = paymentProcessor.Id, 
                External_Id__c = '123',
                Last_Four_Digits__c = '4242',
                Payment_Method_Type__c = 'Credit Card',
                Status__c='Active',
                Expiration_Month__c = '12',
                Expiration_Year__c = '2224',
                Type__c = 'Visa',
                Default__c = true
            );
            insert paymentMethod;

            List<Payment_Activity__c> activities = new List<Payment_Activity__c>();
            for (Integer i = 0; i < crs.size(); i++) {
                activities.add(new Payment_Activity__c(
                    Amount__c = crs[i].Amount__c,
                    Payment_Method__c = paymentMethod.Id,
                    Cash_Receipt__c = crs[i].Id,
                    Merchant_Reference__c = crs[i].Payment_Reference__c
                ));
            }
            insert activities;

            // query the activities using the batch query locator so we have all the relationship fields
            PaymentActivityACHStatusBatch batch = new PaymentActivityACHStatusBatch();
            activities = database.query((batch.start(null).getQuery()));
            
            Test.startTest();
            CardknoxProcessorV1 processor = new CardknoxProcessorV1();
            List<Payment_Activity__c> updatedActivities = processor.getPaymentActivityStatus(activities);
            Test.stopTest();

            for (Payment_Activity__c activity : updatedActivities) {
                if (activity.Merchant_Reference__c == '0') {
                    System.assertEquals('Success', activity.Status__c);
                } else if (activity.Merchant_Reference__c == '1') {
                    System.assertEquals('Declined', activity.Status__c);
                } else if (activity.Merchant_Reference__c == '2') {
                    System.assertEquals('Error', activity.Status__c);
                } else if (activity.Merchant_Reference__c == '3') {
                    System.assertEquals('Declined', activity.Status__c);
                } else if (activity.Merchant_Reference__c == '4') {
                    System.assertEquals('Error', activity.Status__c);
                } else if (activity.Merchant_Reference__c == '5') {
                    System.assertEquals('Pending', activity.Status__c);
                } else if (activity.Merchant_Reference__c == '6') {
                    System.assertEquals('Pending', activity.Status__c);
                } else if (activity.Merchant_Reference__c == '7') {
                    System.assertEquals('Success', activity.Status__c);
                } else if (activity.Merchant_Reference__c == '8') {
                    System.assertEquals('Success', activity.Status__c);
                } else if (activity.Merchant_Reference__c == '9') {
                    System.assertEquals('Pending', activity.Status__c);
                } else if (activity.Merchant_Reference__c == '10') {
                    System.assertEquals('Void', activity.Status__c);
                } else if (activity.Merchant_Reference__c == '11') {
                    System.assertEquals('Void', activity.Status__c);
                }
            }
        }
    }

    @IsTest
    public static void testNotImplemented() {
        TestDataSuite testData = TestDataSuite.getInstance();
        TestDataSuite testReciepts = TestDataSuite.getInstance().createCashReceipts().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            
            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = testData.paymentProcessors[2].Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Credit Card', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Type__c ='Visa',Default__c=true);
            INSERT pm;

            Payment_Activity__c pmResp;
            Test.startTest();
            CardknoxProcessorV1 cp = new CardknoxProcessorV1();
            try{
                pmResp = cp.ccAuthorization(pm);
                Assert.fail('Not Implemented Exception expected.');
            }catch(Exception e){
                System.assertEquals(true, e.getMessage().contains('Not Implemented'));
            }
            try{
                pmResp = cp.ccCapture(pm);
                Assert.fail('Not Implemented Exception expected.');
            }catch(Exception e){
                System.assertEquals(true, e.getMessage().contains('Not Implemented'));
            }
            try{
                pmResp = cp.ccCredit(pm);
                Assert.fail('Not Implemented Exception expected.');
            }catch(Exception e){
                System.assertEquals(true, e.getMessage().contains('Not Implemented'));
            }
            try{
                pmResp = cp.ccRefund(pm);
                Assert.fail('Not Implemented Exception expected.');
            }catch(Exception e){
                System.assertEquals(true, e.getMessage().contains('Not Implemented'));
            }
            try{
                pmResp = cp.achCredit(pm);
                Assert.fail('Not Implemented Exception expected.');
            }catch(Exception e){
                System.assertEquals(true, e.getMessage().contains('Not Implemented'));
            }
            try{
                pmResp = cp.achRefund(pm);
                Assert.fail('Not Implemented Exception expected.');
            }catch(Exception e){
                System.assertEquals(true, e.getMessage().contains('Not Implemented'));
            }
            Test.stopTest();
        }
    }
    @IsTest
    public static void testCreatePaymentMethodFailure() {
        Test.setMock(HttpCalloutMock.class, new MockCommonFailureResponse());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = testData.paymentProcessors[2].Id, External_Id__c='12345678;abcd',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Credit Card', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Type__c ='Visa');
            
            Test.startTest();
            Payment_Method__c pmResp;
            CardknoxProcessorV1 cp = new CardknoxProcessorV1();
            try{
                pmResp = cp.createPaymentMethod(pm,'12345678;abcd');
                Assert.fail(Label.ERR_INVALID_XKEY_VALUE + ' Exception expected.');
            }catch(Exception exp){
                System.assertEquals(Label.ERR_INVALID_XKEY_VALUE, exp.getMessage());
            }
            Test.stopTest();

            System.assertEquals(null,pmResp);
        }
    }
    @IsTest
    public static void testCCSaleWithCurrencyMismatchError() {
        TestDataSuite testData = TestDataSuite.getInstance();
        try {
            testData.enableMultiCurrency();
            MultiCurrencyHandler.isMultiCurrencyEnabled = true;
        } catch (TestDataSuite.TestDataSuiteException e) {
            // MC not enabled for org
            return;
        }
        testData.createBillings().createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            String ledgerCurrency = LedgerHandler.getLedgerCurrency(paymentProcessor.Default_Ledger__c);
            String nonLedgerCurrency;
            List<SObject> allCurrencies = Database.query('SELECT Id, IsoCode FROM CurrencyType LIMIT 2');
            for (SObject eachCurrency : allCurrencies) {
                if (eachCurrency.get('IsoCode') != ledgerCurrency) {
                    nonLedgerCurrency = (String) eachCurrency.get('IsoCode');
                    break;
                }
            }

            if (String.isBlank(nonLedgerCurrency)) {
                // only single currency available
                return;
            }
        
            Cash_Receipt__c cReciept = new Cash_Receipt__c(
                        Account__c = testData.accounts.get(1).Id,
                        Amount__c = 400,
                        Status__c = 'Approved',
                        Receipt_Date__c = System.today(),
                        Purpose__c = 'Customer Receipt',
                        Payment_Reference__c = '12345',
                        Accounting_Period__c = testData.acctPeriods.get(0).Id,
                        Convenience_Fees_Charged__c = 10
                    );
            cReciept.put('CurrencyIsoCode', nonLedgerCurrency);

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c =paymentProcessor.Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = paymentProcessor.Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Credit Card', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Type__c ='Visa',Default__c=true);
            INSERT pm;

            Test.startTest();
            List<PaymentSaleItem> saleItems = new List<PaymentSaleItem>();
            saleItems.add(new PaymentSaleItem(pm,cReciept));
            CardknoxProcessorV1 cp = new CardknoxProcessorV1();
            List<PaymentSaleItem> responseSaleItems = cp.ccSale(saleItems);

            Assert.areEqual(null,responseSaleItems[0].billings);
            Assert.areNotEqual(null,responseSaleItems[0].cashReceipt);
            Assert.areEqual(Label.ERR_CARDKNOX_PAYMENT_SHOULD_BE_IN_LEDGER_CURRENCY,
                    responseSaleItems[0].errors.errorsHolder[0].get('message'));
            Test.stopTest();
            
        }
    }
    @IsTest
    public static void testCCSaleFailure() {
        Test.setMock(HttpCalloutMock.class, new MockCommonFailureResponse());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Cash_Receipt__c cReciept = new Cash_Receipt__c(
                        Account__c = testData.accounts.get(1).Id,
                        Amount__c = 400,
                        Status__c = 'Approved',
                        Receipt_Date__c = System.today(),
                        Purpose__c = 'Customer Receipt',
                        Payment_Reference__c = '12345',
                        Accounting_Period__c = testData.acctPeriods.get(0).Id,
                        Convenience_Fees_Charged__c = 10
                    );

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = testData.paymentProcessors[3].Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = testData.paymentProcessors[3].Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Credit Card', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Type__c ='Visa',Default__c=true);
            INSERT pm;

            Test.startTest();
            List<PaymentSaleItem> saleItems = new List<PaymentSaleItem>();
            saleItems.add(new PaymentSaleItem(pm,cReciept));

            CardknoxProcessorV1 cp = new CardknoxProcessorV1();
            List<PaymentSaleItem> responseSaleItems;
            try{
                responseSaleItems = cp.ccSale(saleItems);
            }catch(Exception exp){
                System.assertEquals(Label.ERR_INVALID_XKEY_VALUE, exp.getMessage());
            }
            System.assertEquals(400,responseSaleItems[0].paymentActivity.Amount__c);
            System.assertEquals('Error',responseSaleItems[0].paymentActivity.Status__c);
            System.assertEquals(1,[SELECT Id FROM Payment_Activity__c].size());
            System.assertEquals(0,[SELECT Id FROM Cash_Receipt__c].size());
            System.assertEquals(Label.ERR_INVALID_XKEY_VALUE, responseSaleItems[0].paymentActivity.Error_Message__c);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testCCSaleBadBankGL() {
        Test.setMock(HttpCalloutMock.class, new MockProcessTransactionResponse());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Cash_Receipt__c cReciept = new Cash_Receipt__c(
                Account__c = testData.accounts.get(1).Id,
                Amount__c = 400,
                Status__c = 'Approved',
                Receipt_Date__c = System.today(),
                Purpose__c = 'Customer Receipt',
                Payment_Reference__c = '12345',
                Accounting_Period__c = testData.acctPeriods.get(0).Id,
                Bank_Account__c = testData.glAccounts[0].Id,
                Convenience_Fees_Charged__c = 10
            );

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = testData.paymentProcessors[2].Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = testData.paymentProcessors[2].Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Credit Card', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Type__c ='Visa',Default__c=true);
            INSERT pm;

            Test.startTest();
            List<PaymentSaleItem> saleItems = new List<PaymentSaleItem>();
            saleItems.add(new PaymentSaleItem(pm,cReciept));

            CardknoxProcessorV1 cp = new CardknoxProcessorV1();

            List<PaymentSaleItem> responseSaleItems = cp.ccSale(saleItems);
            
            Assert.areEqual(Label.ERR_CARDKNOX_PAYMENT_REQUIRES_MERCHANT_GL, responseSaleItems[0].errors.errorsHolder[0].get('message'));
            Test.stopTest();
        }
    }
 
    @IsTest
    public static void testCCSaleDeclined() {
        Test.setMock(HttpCalloutMock.class, new MockProcessTransactionResponseDeclined());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Cash_Receipt__c cReciept = new Cash_Receipt__c(
                        Account__c = testData.accounts.get(1).Id,
                        Amount__c = 400,
                        Status__c = 'Approved',
                        Receipt_Date__c = System.today(),
                        Purpose__c = 'Customer Receipt',
                        Payment_Reference__c = '12345',
                        Accounting_Period__c = testData.acctPeriods.get(0).Id
                    );

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = testData.paymentProcessors[2].Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = testData.paymentProcessors[2].Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Credit Card', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Type__c ='Visa',Default__c=true);
            INSERT pm;

            Test.startTest();
            List<PaymentSaleItem> saleItems = new List<PaymentSaleItem>();
            saleItems.add(new PaymentSaleItem(pm,cReciept));

            CardknoxProcessorV1 cp = new CardknoxProcessorV1();

            List<PaymentSaleItem> responseSaleItems = cp.ccSale(saleItems);
            System.assertEquals(400,responseSaleItems[0].paymentActivity.Amount__c);
            System.assertEquals('Error',responseSaleItems[0].paymentActivity.Status__c);
            System.assertEquals('1234',responseSaleItems[0].paymentActivity.Merchant_Reference__c);
            System.assertEquals(1,[SELECT Id FROM Payment_Activity__c].size());
            Test.stopTest();
        }
    }

    @IsTest
    public static void testCCSaleWithCnvFeeFlatFee() {
        Test.setMock(HttpCalloutMock.class, new MockProcessTransactionResponse());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Cash_Receipt__c cReciept = new Cash_Receipt__c(
                        Account__c = testData.accounts.get(1).Id,
                        Amount__c = 400,
                        Status__c = 'Approved',
                        Receipt_Date__c = System.today(),
                        Purpose__c = 'Customer Receipt',
                        Payment_Reference__c = '12345',
                        Accounting_Period__c = testData.acctPeriods.get(0).Id,
                        Convenience_Fees_Charged__c = 10
                    );

            Payment_Processor__c pp = testData.paymentProcessors[3];
            pp.Credit_Card_Convenience_Fee_Type__c = 'CC Flat Fee';
            pp.CC_Flat_Fee__c = 100;

            UPDATE pp;

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = pp.Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = pp.Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Credit Card', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Type__c ='Visa',Default__c=true);
            INSERT pm;

            Test.startTest();
            List<PaymentSaleItem> saleItems = new List<PaymentSaleItem>();
            saleItems.add(new PaymentSaleItem(pm,cReciept));

            CardknoxProcessorV1 cp = new CardknoxProcessorV1();

            List<PaymentSaleItem> responseSaleItems = cp.ccSale(saleItems);
            System.assertEquals(400,responseSaleItems[0].paymentActivity.Amount__c);
            System.assertEquals(390,responseSaleItems[0].paymentActivity.Original_Amount__c);
            System.assertEquals(10,responseSaleItems[0].paymentActivity.Convenience_Fee__c);
            System.assertEquals('Success',responseSaleItems[0].paymentActivity.Status__c);
            System.assertEquals(1,[SELECT Id FROM Payment_Activity__c].size());

            List<Cash_Receipt__c> cr = [SELECT Id, Bank_Account__c FROM Cash_Receipt__c];
            System.assertEquals(1, cr.size());
            System.assertEquals(testData.paymentProcessors[2].Merchant_GL_Account__c, cr[0].Bank_Account__c);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testCCSaleWithACHPaymentMethod() {
        Test.setMock(HttpCalloutMock.class, new MockProcessTransactionResponse());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Cash_Receipt__c cReciept = new Cash_Receipt__c(
                        Account__c = testData.accounts.get(1).Id,
                        Amount__c = 400,
                        Status__c = 'Approved',
                        Receipt_Date__c = System.today(),
                        Purpose__c = 'Customer Receipt',
                        Payment_Reference__c = '12345',
                        Accounting_Period__c = testData.acctPeriods.get(0).Id,
                        Convenience_Fees_Charged__c = 10
                    );

            Payment_Processor__c pp = testData.paymentProcessors[3];
            pp.Credit_Card_Convenience_Fee_Type__c = 'CC Percent';
            pp.CC_Flat_Fee__c = 10;

            UPDATE pp;
            
            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = pp.Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = pp.Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Bank Account', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Bank_Account_Type__c ='Individual',Default__c=true);
            INSERT pm;

            Test.startTest();
            List<PaymentSaleItem> saleItems = new List<PaymentSaleItem>();
            saleItems.add(new PaymentSaleItem(pm,cReciept));

            CardknoxProcessorV1 cp = new CardknoxProcessorV1();

            List<PaymentSaleItem> responseSaleItems = cp.ccSale(saleItems);
            System.assertEquals(400,responseSaleItems[0].paymentActivity.Amount__c);
            System.assertEquals('Pending',responseSaleItems[0].paymentActivity.Status__c);
            System.assertEquals(1,[SELECT Id FROM Payment_Activity__c].size());
            List<Cash_Receipt__c> cr = [SELECT Id, Bank_Account__c FROM Cash_Receipt__c];
            System.assertEquals(1, cr.size());
            System.assertEquals(testData.paymentProcessors[2].Merchant_GL_Account__c, cr[0].Bank_Account__c);
            Test.stopTest();
        }
    }
    @IsTest
    public static void testVoidInvalidKeys() {
        Test.setMock(HttpCalloutMock.class, new MockVoidFailureInvalidKeyResponse());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors().createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Payment_Processor__c pp = testData.paymentProcessors[3];

            Cash_Receipt__c cReciept = new Cash_Receipt__c(
                        Account__c = testData.accounts.get(1).Id,
                        Amount__c = 400,
                        Status__c = 'Approved',
                        Receipt_Date__c = System.today(),
                        Purpose__c = 'Customer Receipt',
                        Payment_Reference__c = '12345',
                        Accounting_Period__c = testData.acctPeriods.get(0).Id,
                        Convenience_Fees_Charged__c = 10,
                        Payment_Processor__c = pp.Id
                    );

            INSERT cReciept;

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = pp.Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = pp.Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Bank Account', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Bank_Account_Type__c ='Individual',Default__c=true);
            INSERT pm;

            Payment_Activity__c activity = new Payment_Activity__c(
                Amount__c = cReciept.Amount__c,
                Payment_Method__c = pm.Id,
                Cash_Receipt__c = cReciept.Id,
                Merchant_Reference__c = cReciept.Payment_Reference__c
            );

            insert activity;

            List<Payment_Activity__c> activites = [SELECT Id, Cash_Receipt__r.Payment_Processor__c,Cash_Receipt__c, Merchant_Reference__c,Payment_Method_Type__c FROM Payment_Activity__c WHERE Id = :activity.Id];
            Assert.areEqual(1, activites.size());

            Test.startTest();
            CardknoxProcessorV1 cp = new CardknoxProcessorV1();
            try{
                cp.ccVoid(activites[0]);
                Assert.fail(Label.ERR_INVALID_XKEY_VALUE + ' Exception expected');
            }catch(Exception exp){
                Assert.areEqual(Label.ERR_INVALID_XKEY_VALUE, exp.getMessage());
            }
            try{
                cp.achVoid(activites[0]);
                Assert.fail(Label.ERR_INVALID_XKEY_VALUE + ' Exception expected');
            }catch(Exception exp){
                Assert.areEqual(Label.ERR_INVALID_XKEY_VALUE, exp.getMessage());
            }
            Test.stopTest();
        }
    }
    @IsTest
    public static void testVoidNoXKeysAreSetupped() {
        Test.setMock(HttpCalloutMock.class, new MockVoidFailureNoXKeySetupResponse());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors().createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Payment_Processor__c pp = testData.paymentProcessors[0];

            Cash_Receipt__c cReciept = new Cash_Receipt__c(
                        Account__c = testData.accounts.get(1).Id,
                        Amount__c = 400,
                        Status__c = 'Approved',
                        Receipt_Date__c = System.today(),
                        Purpose__c = 'Customer Receipt',
                        Payment_Reference__c = '12345',
                        Accounting_Period__c = testData.acctPeriods.get(0).Id,
                        Convenience_Fees_Charged__c = 10,
                        Payment_Processor__c = pp.Id
                    );

            INSERT cReciept;

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = pp.Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = pp.Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Bank Account', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Bank_Account_Type__c ='Individual',Default__c=true);
            INSERT pm;

            Payment_Activity__c activity = new Payment_Activity__c(
                Amount__c = cReciept.Amount__c,
                Payment_Method__c = pm.Id,
                Cash_Receipt__c = cReciept.Id,
                Merchant_Reference__c = cReciept.Payment_Reference__c
            );

            insert activity;

            List<Payment_Activity__c> activites = [SELECT Id, Cash_Receipt__r.Payment_Processor__c,Cash_Receipt__c, Merchant_Reference__c,Payment_Method_Type__c FROM Payment_Activity__c WHERE Id = :activity.Id];
            Assert.areEqual(1, activites.size());

            Test.startTest();
            CardknoxProcessorV1 cp = new CardknoxProcessorV1();
            try{
                cp.ccVoid(activites[0]);
                Assert.fail(Label.CRDKNX_NO_XKEY + ' Exception expected');
            }catch(Exception exp){
                Assert.areEqual(Label.CRDKNX_NO_XKEY, exp.getMessage());
            }
            try{
                cp.achVoid(activites[0]);
                Assert.fail(Label.CRDKNX_NO_XKEY + ' Exception expected');
            }catch(Exception exp){
                Assert.areEqual(Label.CRDKNX_NO_XKEY, exp.getMessage());
            }
            Test.stopTest();
        }
    }
    @IsTest
    public static void testVoidAnVoidedCashReceipt() {
        Test.setMock(HttpCalloutMock.class, new MockVoidFailedAlreadyVoidedResponse());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors().createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Payment_Processor__c pp = testData.paymentProcessors[3];

            Cash_Receipt__c cReciept = new Cash_Receipt__c(
                        Account__c = testData.accounts.get(1).Id,
                        Amount__c = 400,
                        Status__c = 'Approved',
                        Receipt_Date__c = System.today(),
                        Purpose__c = 'Customer Receipt',
                        Payment_Reference__c = '12345',
                        Accounting_Period__c = testData.acctPeriods.get(0).Id,
                        Convenience_Fees_Charged__c = 10,
                        Payment_Processor__c = pp.Id
                    );

            INSERT cReciept;

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = pp.Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = pp.Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Bank Account', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Bank_Account_Type__c ='Individual',Default__c=true);
            INSERT pm;

            Payment_Activity__c activity = new Payment_Activity__c(
                Amount__c = cReciept.Amount__c,
                Payment_Method__c = pm.Id,
                Cash_Receipt__c = cReciept.Id,
                Merchant_Reference__c = cReciept.Payment_Reference__c
            );

            insert activity;

            List<Payment_Activity__c> activites = [SELECT Id, Cash_Receipt__r.Payment_Processor__c,Cash_Receipt__c, Merchant_Reference__c,Payment_Method_Type__c FROM Payment_Activity__c WHERE Id = :activity.Id];
            Assert.areEqual(1, activites.size());

            Test.startTest();
            CardknoxProcessorV1 cp = new CardknoxProcessorV1();
            try{
                cp.ccVoid(activites[0]);
                Assert.fail(Label.ERR_CARDKNOX_TRANSACTION_ALREADY_VOIDED + ' Exception expected');
            }catch(Exception exp){
                Assert.areEqual(Label.ERR_CARDKNOX_TRANSACTION_ALREADY_VOIDED, exp.getMessage());
            }
            try{
                cp.achVoid(activites[0]);
                Assert.fail(Label.ERR_CARDKNOX_TRANSACTION_ALREADY_VOIDED + ' Exception expected');
            }catch(Exception exp){
                Assert.areEqual(Label.ERR_CARDKNOX_TRANSACTION_ALREADY_VOIDED, exp.getMessage());
            }
            Test.stopTest();
        }
    }
    @IsTest
    public static void testVoidClearedTransactionCannotVoid() {
        Test.setMock(HttpCalloutMock.class, new MockVoidFailedTransactionIsClearedResponse());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors().createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Payment_Processor__c pp = testData.paymentProcessors[3];

            Cash_Receipt__c cReciept = new Cash_Receipt__c(
                        Account__c = testData.accounts.get(1).Id,
                        Amount__c = 400,
                        Status__c = 'Approved',
                        Receipt_Date__c = System.today(),
                        Purpose__c = 'Customer Receipt',
                        Payment_Reference__c = '12345',
                        Accounting_Period__c = testData.acctPeriods.get(0).Id,
                        Convenience_Fees_Charged__c = 10,
                        Payment_Processor__c = pp.Id
                    );

            INSERT cReciept;

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = pp.Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = pp.Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Bank Account', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Bank_Account_Type__c ='Individual',Default__c=true);
            INSERT pm;

            Payment_Activity__c activity = new Payment_Activity__c(
                Amount__c = cReciept.Amount__c,
                Payment_Method__c = pm.Id,
                Cash_Receipt__c = cReciept.Id,
                Merchant_Reference__c = cReciept.Payment_Reference__c
            );

            insert activity;

            List<Payment_Activity__c> activites = [SELECT Id, Cash_Receipt__r.Payment_Processor__c,Cash_Receipt__c, Merchant_Reference__c,Payment_Method_Type__c FROM Payment_Activity__c WHERE Id = :activity.Id];
            Assert.areEqual(1, activites.size());

            Test.startTest();
            CardknoxProcessorV1 cp = new CardknoxProcessorV1();
            try{
                cp.ccVoid(activites[0]);
                Assert.fail(Label.ERR_CARDKNOX_VOID_FAILED_PAYMENT_BATCH_CLOSED + ' Exception expected');
            }catch(Exception exp){
                Assert.areEqual(Label.ERR_CARDKNOX_VOID_FAILED_PAYMENT_BATCH_CLOSED, exp.getMessage());
            }
            try{
                cp.achVoid(activites[0]);
                Assert.fail(Label.ERR_CARDKNOX_VOID_FAILED_PAYMENT_BATCH_CLOSED + ' Exception expected');
            }catch(Exception exp){
                Assert.areEqual(Label.ERR_CARDKNOX_VOID_FAILED_PAYMENT_BATCH_CLOSED, exp.getMessage());
            }
            Test.stopTest();
        }
    }
    @IsTest
    public static void testVoidFailedInvalidReferenceNum() {
        Test.setMock(HttpCalloutMock.class, new MockVoidFailedInvalidRefNumResponse());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors().createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Payment_Processor__c pp = testData.paymentProcessors[3];

            Cash_Receipt__c cReciept = new Cash_Receipt__c(
                        Account__c = testData.accounts.get(1).Id,
                        Amount__c = 400,
                        Status__c = 'Approved',
                        Receipt_Date__c = System.today(),
                        Purpose__c = 'Customer Receipt',
                        Payment_Reference__c = '12345',
                        Accounting_Period__c = testData.acctPeriods.get(0).Id,
                        Convenience_Fees_Charged__c = 10,
                        Payment_Processor__c = pp.Id
                    );

            INSERT cReciept;

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = pp.Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = pp.Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Bank Account', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Bank_Account_Type__c ='Individual',Default__c=true);
            INSERT pm;

            Payment_Activity__c activity = new Payment_Activity__c(
                Amount__c = cReciept.Amount__c,
                Payment_Method__c = pm.Id,
                Cash_Receipt__c = cReciept.Id,
                Merchant_Reference__c = cReciept.Payment_Reference__c
            );

            insert activity;

            List<Payment_Activity__c> activites = [SELECT Id, Cash_Receipt__r.Payment_Processor__c,Cash_Receipt__c, Merchant_Reference__c,Payment_Method_Type__c FROM Payment_Activity__c WHERE Id = :activity.Id];
            Assert.areEqual(1, activites.size());

            Test.startTest();
            CardknoxProcessorV1 cp = new CardknoxProcessorV1();
            try{
                cp.ccVoid(activites[0]);
                Assert.fail(Label.ERR_CARDKNOX_INVALID_REFNUM + ' Exception expected');
            }catch(Exception exp){
                Assert.areEqual(Label.ERR_CARDKNOX_INVALID_REFNUM, exp.getMessage());
            }
            try{
                cp.achVoid(activites[0]);
                Assert.fail(Label.ERR_CARDKNOX_INVALID_REFNUM + ' Exception expected');
            }catch(Exception exp){
                Assert.areEqual(Label.ERR_CARDKNOX_INVALID_REFNUM, exp.getMessage());
            }
            Test.stopTest();
        }
    }
    @IsTest
    public static void testVoidSuccess() {
        Test.setMock(HttpCalloutMock.class, new MockVoidSuccessResponse());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors().createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Payment_Processor__c pp = testData.paymentProcessors[3];

            Cash_Receipt__c cReciept = new Cash_Receipt__c(
                        Account__c = testData.accounts.get(1).Id,
                        Amount__c = 400,
                        Status__c = 'Approved',
                        Receipt_Date__c = System.today(),
                        Purpose__c = 'Customer Receipt',
                        Payment_Reference__c = '12345',
                        Accounting_Period__c = testData.acctPeriods.get(0).Id,
                        Convenience_Fees_Charged__c = 10,
                        Payment_Processor__c = pp.Id
                    );

            INSERT cReciept;

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = pp.Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = pp.Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Bank Account', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Bank_Account_Type__c ='Individual',Default__c=true);
            INSERT pm;

            Payment_Activity__c activity = new Payment_Activity__c(
                Amount__c = cReciept.Amount__c,
                Payment_Method__c = pm.Id,
                Cash_Receipt__c = cReciept.Id,
                Merchant_Reference__c = cReciept.Payment_Reference__c
            );

            insert activity;

            List<Payment_Activity__c> activites = [SELECT Id, Cash_Receipt__r.Payment_Processor__c,Cash_Receipt__c, Merchant_Reference__c,Payment_Method_Type__c FROM Payment_Activity__c WHERE Id = :activity.Id];
            Assert.areEqual(1, activites.size());

            Test.startTest();
            CardknoxProcessorV1 cp = new CardknoxProcessorV1();
            try{
                cp.ccVoid(activites[0]);
            }catch(Exception exp){
                Assert.fail('No Exception expected');
            }
            try{
                cp.achVoid(activites[0]);
            }catch(Exception exp){
                Assert.fail('No Exception expected');
            }
            Test.stopTest();
        }
    }
    @IsTest
    public static void testVoidFailedBatchIsClosed() {
        Test.setMock(HttpCalloutMock.class, new MockVoidFailedTransactionIssueRefund());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors().createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Payment_Processor__c pp = testData.paymentProcessors[3];

            Cash_Receipt__c cReciept = new Cash_Receipt__c(
                        Account__c = testData.accounts.get(1).Id,
                        Amount__c = 400,
                        Status__c = 'Approved',
                        Receipt_Date__c = System.today(),
                        Purpose__c = 'Customer Receipt',
                        Payment_Reference__c = '12345',
                        Accounting_Period__c = testData.acctPeriods.get(0).Id,
                        Convenience_Fees_Charged__c = 10,
                        Payment_Processor__c = pp.Id
                    );

            INSERT cReciept;

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = pp.Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = pp.Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Bank Account', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Bank_Account_Type__c ='Individual',Default__c=true);
            INSERT pm;

            Payment_Activity__c activity = new Payment_Activity__c(
                Amount__c = cReciept.Amount__c,
                Payment_Method__c = pm.Id,
                Cash_Receipt__c = cReciept.Id,
                Merchant_Reference__c = cReciept.Payment_Reference__c
            );

            insert activity;

            List<Payment_Activity__c> activites = [SELECT Id, Cash_Receipt__r.Payment_Processor__c,Cash_Receipt__c, Merchant_Reference__c,Payment_Method_Type__c FROM Payment_Activity__c WHERE Id = :activity.Id];
            Assert.areEqual(1, activites.size());

            Test.startTest();
            CardknoxProcessorV1 cp = new CardknoxProcessorV1();
            try{
                cp.ccVoid(activites[0]);
                Assert.fail(Label.ERR_CARDKNOX_VOID_FAILED_PAYMENT_BATCH_CLOSED + ' Exception expected');
            }catch(Exception exp){
                Assert.areEqual(Label.ERR_CARDKNOX_VOID_FAILED_PAYMENT_BATCH_CLOSED, exp.getMessage());
            }
            try{
                cp.achVoid(activites[0]);
                Assert.fail(Label.ERR_CARDKNOX_VOID_FAILED_PAYMENT_BATCH_CLOSED + ' Exception expected');
            }catch(Exception exp){
                Assert.areEqual(Label.ERR_CARDKNOX_VOID_FAILED_PAYMENT_BATCH_CLOSED, exp.getMessage());
            }
            Test.stopTest();
        }
    }
}