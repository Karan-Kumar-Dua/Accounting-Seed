@isTest
public class PaymentMethodManagerTest {

    public class MockPaymentMethodManager implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            String endpoint = req.getEndpoint();
            HttpResponse res = new HttpResponse();
            String jsonResponse;
            if (endpoint.contains(StripeService.CUSTOMER_URL) && endpoint.contains('sources')) {
                jsonResponse = '{' +
                    '"id": "card_17xI45EbJdMP0Nek0pVwk7BF",' +
                    '"object": "card",' +
                    '"address_city": null,' +
                    '"address_country": null,' +
                    '"address_line1": null,' +
                    '"address_line1_check": null,' +
                    '"address_line2": null,' +
                    '"address_state": null,' +
                    '"address_zip": null,' +
                    '"address_zip_check": null,' +
                    '"brand": "Visa",' +
                    '"country": "US",' +
                    '"customer": "cus_8DjRY9S7d7OKqp",' +
                    '"cvc_check": "pass",' +
                    '"dynamic_last4": null,' +
                    '"exp_month": 2,' +
                    '"exp_year": 2017,' +
                    '"fingerprint": "fhORtH5xRqsWTHH2",' +
                    '"funding": "credit",' +
                    '"last4": "4242",' +
                    '"metadata": {' +
                        '"status": "' + StripeService.PAYMENT_METHOD_STATUS_INACTIVE + '"' +
                    '},' +
                    '"name": "TestName",' +
                    '"tokenization_method": null' +
                    '}';
            }
            else if (endpoint.contains(StripeService.CUSTOMER_URL)) {
                jsonResponse = '{' +
                    '"id": "cus_8DjRY9S7d7OKqp",' +
                    '"object": "customer",' +
                    '"account_balance": 0,' +
                    '"created": 1459954185,' +
                    '"currency": null,' +
                    '"default_source": "card_17xHyXEbJdMP0NekLllIObtV",' +
                    '"delinquent": false,' +
                    '"description": "test_description",' +
                    '"discount": null,' +
                    '"email": null,' +
                    '"livemode": false,' +
                    '"metadata": {},' +
                    '"shipping": null,' +
                    '"sources": {' +
                    '"object": "list",' +
                    '"data": [' +
                    '{'  +
                    '"id": "card_17xHyXEbJdMP0NekLllIObtV",' +
                    '"object": "card",' +
                    '"address_city": null,' +
                    '"address_country": null,' +
                    '"address_line1": null,' +
                    '"address_line1_check": null,' +
                    '"address_line2": null,' +
                    '"address_state": null,' +
                    '"address_zip": null,' +
                    '"address_zip_check": null,' +
                    '"brand": "Visa",' +
                    '"country": "US",' +
                    '"customer": "cus_8DjRY9S7d7OKqp",' +
                    '"cvc_check": "pass",' +
                    '"dynamic_last4": null,' +
                    '"exp_month": 2,' +
                    '"exp_year": 2017,' +
                    '"fingerprint": "fhORtH5xRqsWTHH2",' +
                    '"funding": "credit",' +
                    '"last4": "4242",' +
                    '"metadata": {},' +
                    '"name": "TestName",' +
                    '"tokenization_method": null' +
                    '}' +
                    '],' +
                    '"has_more": false,' +
                    '"total_count": 1,' +
                    '"url": "/v1/customers/cus_8DjRY9S7d7OKqp/sources"' +
                    '},' +
                    '"subscriptions": {' +
                    '"object": "list",' +
                    '"data": [],' +
                    '"has_more": false,' +
                    '"total_count": 0,' +
                    '"url": "/v1/customers/cus_8DjRY9S7d7OKqp/subscriptions"' +
                    '}' +
                    '}';
            }
            else if (endpoint.contains(StripeService.TOKEN_URL)) {
                jsonResponse = '{"id": "tok_18lHAUBRnEsS31Wqkf7zMY6e"}';
            }
            res.setHeader('Content-Type', 'application/json');
            res.setBody(jsonResponse);
            res.setStatusCode(200);
            return res;
        }
    }

    public class MockPaymentMethodManagerWithError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            String endpoint = req.getEndpoint();
            HttpResponse res = new HttpResponse();
            String jsonResponse = '{' +
                '"error": {' +
                '"type": "invalid_request_error",' +
                '"message": "You did not provide an API key.",' +
                '"param": "amount"' +
                '}' +
                '}';
            res.setHeader('Content-Type', 'application/json');
            res.setBody(jsonResponse);
            res.setStatusCode(200);
            return res;
        }
    }

    public static String getStripeCardTokenJSON(String brand, String expMonth, String expYear, String last4) {
        return
            '{' +
                '"id": "tok_1B7kcpGKbd1fBtzkOWde2lz5",' +
                '"object": "token",' +
                '"card": {' +
                    '"id": "card_1B7kcpGKbd1fBtzkj4K0PQbA",' +
                    '"object": "card",' +
                    '"brand": "' + brand + '",' +
                    '"country": "US",' +
                    '"exp_month": ' + expMonth + ',' +
                    '"exp_year": ' + expYear + ',' +
                    '"fingerprint": "nRKGxxY6kI5FOyQn",' +
                    '"funding": "credit",' +
                    '"last4": "' + last4 + '",' +
                    '"metadata": {},' +
                    '"name": "TestCardHolderName"' +
                '},' +
                '"client_ip": null,' +
                '"created": 1506776603,' +
                '"livemode": false,' +
                '"type": "card",' +
                '"used": false' +
            '}';
    }

    //==========================================================================================================
    //============ Unit tests for PaymentMethodManager.createPayment method ====================================
    //============ Unit tests for PaymentMethodManager.createStripeCustomer method =============================
    //============ Unit tests for PaymentMethodManager.createPaymentMethods method =============================
    //============ Unit tests for PaymentMethodManager.createStripeCard method =================================
    //==========================================================================================================

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testCreateCustomerWithPaymentMethod() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            MdtBindingHandlerMock mock = new MdtBindingHandlerMock(new StripeProcessorV1());
            MdtBindingHandler.instance = (MdtBindingHandler) Test.createStub(MdtBindingHandler.class, mock);

            Account acct = prepareCreatePaymentTest(new MockPaymentMethodManager(), null);
            Payment_Processor__c proc = testData.paymentProcessors.get(0);

            Test.startTest();
            ApexPages.StandardController stdController = new ApexPages.StandardController(acct);
            PaymentMethodManager controller = new PaymentMethodManager(stdController);

            //populate test Stripe Card Token
            controller.serializedStripeSourceToken = getStripeCardTokenJSON('Visa', '2', '2017', '4242');
            controller.selectedProcessor = proc.Id;

            controller.createPaymentMethod();
            //Expected results:
            System.assertEquals(
                'cus_8DjRY9S7d7OKqp',
                [
                    SELECT External_Id__c 
                    FROM Payment_Processor_Customer__c 
                    WHERE Account__c = :acct.Id 
                    AND Processor__c = :proc.Id
                    LIMIT 1
                ].External_Id__c
            );
            System.assertEquals(1, [SELECT COUNT() FROM Payment_Method__c WHERE Customer__c = :acct.Id]);

            Test.stopTest();
        }

    }

    @IsTest
    public static void testCreateCardForExistingCustomer() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            MdtBindingHandlerMock mock = new MdtBindingHandlerMock(new StripeProcessorV1());
            MdtBindingHandler.instance = (MdtBindingHandler) Test.createStub(MdtBindingHandler.class, mock);

            Account acct = prepareCreatePaymentTest(new MockPaymentMethodManager(), 'cus_testgRdoZP08pT');
            Payment_Processor__c proc = testData.paymentProcessors.get(0);

            Test.startTest();
            ApexPages.StandardController stdController = new ApexPages.StandardController(acct);
            PaymentMethodManager controller = new PaymentMethodManager(stdController);

            controller.serializedStripeSourceToken = getStripeCardTokenJSON('Visa', '2', '2017', '4242');
            controller.selectedProcessor = proc.Id;

            controller.createPaymentMethod();
            System.assertEquals(1, [SELECT COUNT() FROM Payment_Method__c WHERE Customer__c = :acct.Id]);
            Test.stopTest();
        }

    }

    @IsTest
    public static void testCreateCustomerWithPaymentMethodWithErrorResponse() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            MdtBindingHandlerMock mock = new MdtBindingHandlerMock(new StripeProcessorV1());
            MdtBindingHandler.instance = (MdtBindingHandler) Test.createStub(MdtBindingHandler.class, mock);

            Account acct = prepareCreatePaymentTest(new MockPaymentMethodManagerWithError(), null);
            Payment_Processor__c proc = testData.paymentProcessors.get(0);

            createPaymentMethodForTest(acct, proc);

            Test.startTest();

            ApexPages.StandardController stdController = new ApexPages.StandardController(acct);
            PaymentMethodManager controller = new PaymentMethodManager(stdController);

            controller.serializedStripeSourceToken = getStripeCardTokenJSON('Visa', '2', '2017', '4242');
            controller.selectedProcessor = proc.Id;
            controller.createPaymentMethod();

            List<Apexpages.Message> msgs = ApexPages.getMessages();
            Boolean isErrorExistOnPage = false;
            for (Apexpages.Message msg : msgs) {
                if (msg.getDetail().contains('You did not provide an API key.')) {
                    isErrorExistOnPage = true;
                }
            }
            System.assert(isErrorExistOnPage); //Assert the Page Message was Properly Displayed

            Test.stopTest();
        }

    }

    @IsTest
    public static void testCreateCardForExistingCustomerWithErrorResponse() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            MdtBindingHandlerMock mock = new MdtBindingHandlerMock(new StripeProcessorV1());
            MdtBindingHandler.instance = (MdtBindingHandler) Test.createStub(MdtBindingHandler.class, mock);

            Account acct = prepareCreatePaymentTest(new MockPaymentMethodManagerWithError(), 'cus_testgRdoZP08pT');
            Payment_Processor__c proc = testData.paymentProcessors.get(0);

            Payment_Method__c paymentMethod = createPaymentMethodForTest(acct, proc);

            Test.startTest();
            ApexPages.StandardController stdController = new ApexPages.StandardController(acct);
            PaymentMethodManager controller = new PaymentMethodManager(stdController);

            controller.serializedStripeSourceToken = getStripeCardTokenJSON('Visa', '12', '2017', '4242');
            controller.selectedProcessor = proc.Id;
            controller.createPaymentMethod();

            List<Apexpages.Message> msgs = ApexPages.getMessages();
            Boolean isErrorExistOnPage = false;
            for (Apexpages.Message msg : msgs) {
                if (msg.getDetail().contains('You did not provide an API key.')) {
                    isErrorExistOnPage = true;
                }
            }
            System.assert(isErrorExistOnPage); //Assert the Page Message was Properly Displayed

            Test.stopTest();
        }

    }

    @IsTest
    public static void testAttemptToCreateDuplicatedStripeCard() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            MdtBindingHandlerMock mock = new MdtBindingHandlerMock(new StripeProcessorV1());
            MdtBindingHandler.instance = (MdtBindingHandler) Test.createStub(MdtBindingHandler.class, mock);

            Account acct = prepareCreatePaymentTest(new MockPaymentMethodManagerWithError(), 'cus_testgRdoZP08pT');
            
            Payment_Processor__c proc = testData.paymentProcessors.get(0);

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(
                Account__c = acct.Id,
                Processor__c = proc.Id,
                External_Id__c = 'cus_testgRdoZP08pT'
            );
            insert ppc;

            Payment_Method__c paymentMethod = createPaymentMethodForTest(acct, proc);

            Test.startTest();
            ApexPages.StandardController stdController = new ApexPages.StandardController(acct);
            PaymentMethodManager controller = new PaymentMethodManager(stdController);

            controller.selectedProcessor = proc.Id;
            controller.serializedStripeSourceToken = getStripeCardTokenJSON('Visa', '1', '2019', '4444');

            controller.createPaymentMethod();

            List<Apexpages.Message> msgs = ApexPages.getMessages();
            Boolean isErrorExistOnPage = false;
            for (Apexpages.Message msg : msgs) {
                if (msg.getDetail().contains(PaymentMethodActions.DUPLICATED_PAYMENT_METHOD_ERROR)) {
                    isErrorExistOnPage = true;
                }
            }
            System.assert(isErrorExistOnPage); //Assert the Page Message was Properly Displayed

            Test.stopTest();
        }

    }

    private static Account prepareCreatePaymentTest(HttpCalloutMock mockCallout, String stripeCustomerId) {
        Account acct = new Account(
            Name = 'Test Account 1234',
            Stripe_Customer_Id__c = stripeCustomerId
        );
        insert acct;

        PageReference pageRef = Page.PaymentMethodManager;
        pageRef.getParameters().put('id', acct.Id);
        Test.setCurrentPage(pageRef);
        Test.setMock(HttpCalloutMock.class, mockCallout);
        return acct;
    }

    private static Payment_Method__c createPaymentMethodForTest(Account acct, Payment_Processor__c proc) {
        Payment_Method__c paymentMethod = new Payment_Method__c(
            Type__c = 'Visa',
            Status__c = 'Active',
            Expiration_Month__c = '1',
            Expiration_Year__c = '2019',
            Last_Four_Digits__c = '4444',
            External_Id__c = 'card_17ujweEbJdMP0Nek8KiKMUiW',
            Customer__c = acct.Id,
            Payment_Processor__c = proc.Id
        );
        insert paymentMethod;
        return paymentMethod;
    }

    //==========================================================================================================
    //============ Unit tests for PaymentMethodManager.switchStatusOfPaymentMethod method ======================
    //==========================================================================================================
    @IsTest
    public static void testSwitchStatusOfPaymentMethodActive() {
        testSwitchStatusOfPaymentMethod(
            StripeService.PAYMENT_METHOD_STATUS_ACTIVE,
            StripeService.PAYMENT_METHOD_STATUS_INACTIVE,
            false
        );
    }

    @IsTest
    public static void testSwitchStatusOfPaymentMethodInactive() {
        testSwitchStatusOfPaymentMethod(
            StripeService.PAYMENT_METHOD_STATUS_INACTIVE,
            StripeService.PAYMENT_METHOD_STATUS_ACTIVE,
            false
        );

    }

    @IsTest
    public static void testSwitchStatusOfPaymentMethodError() {
        testSwitchStatusOfPaymentMethod(
            StripeService.PAYMENT_METHOD_STATUS_INACTIVE,
            StripeService.PAYMENT_METHOD_STATUS_ACTIVE,
            true
        );

    }

    private static void testSwitchStatusOfPaymentMethod(String startStatus, String statusAfterSwitch, Boolean triggerError) {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            MdtBindingHandlerMock mock = new MdtBindingHandlerMock(new StripeProcessorV1());
            MdtBindingHandler.instance = (MdtBindingHandler) Test.createStub(MdtBindingHandler.class, mock);
            
            Payment_Processor__c proc = testData.paymentProcessors.get(0);

            Accounting_Settings__c settings = testData.settings;
            settings.Stripe_Connected_Account_Id__c = 'acct_vaowiert9p8qwgn';
            update settings;

            Account acct = new Account(
                Name = 'Test Account 1234',
                Stripe_Customer_Id__c = 'cus_8DjRY9S7d7OKqp'
            );
            insert acct;

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(
                Account__c = acct.Id,
                Processor__c = proc.Id,
                External_Id__c = 'cus_8DjRY9S7d7OKqp'
            );
            insert ppc;

            Payment_Method__c paymentMethod = new Payment_Method__c(
                Type__c = 'Visa',
                Status__c = startStatus,
                Expiration_Month__c = '2',
                Expiration_Year__c = '2017',
                Last_Four_Digits__c = '4242',
                External_Id__c = 'card_17xI45EbJdMP0Nek0pVwk7BF',
                Customer__c = acct.Id,
                Payment_Processor__c = proc.Id
            );
            insert paymentMethod;

            PageReference pageRef = Page.PaymentMethodManager;
            pageRef.getParameters().put('id', acct.Id);
            Test.setCurrentPage(pageRef);
            Test.setMock(HttpCalloutMock.class, new MockPaymentMethodManager());

            Test.startTest();

            ApexPages.StandardController stdController = new ApexPages.StandardController(acct);
            PaymentMethodManager controller = new PaymentMethodManager(stdController);

            List<Payment_Method__c> paymentMethods = controller.ccPaymentMethods;
            controller.payMethodIdForChangeStatus = triggerError ? 'no-id' : paymentMethod.Id;
            PageReference pageReference = controller.switchStatusOfPaymentMethod();
            if (triggerError) {
                // return value is null
                System.assert(pageReference == null);
                // status didn't change
                System.assertEquals(
                    startStatus,
                    [SELECT Status__c FROM Payment_Method__c WHERE Id = :paymentMethod.Id].Status__c
                );
                // one error message
                ApexPages.Message[] pageMessages = ApexPages.getMessages();
                System.assertEquals(1, pageMessages.size());
                System.assertEquals(ApexPages.SEVERITY.ERROR, pageMessages[0].getSeverity());
            } else {
                System.assertEquals(
                    statusAfterSwitch,
                    [SELECT Status__c FROM Payment_Method__c WHERE Id = :paymentMethod.Id].Status__c
                );
            }

            Test.stopTest();
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