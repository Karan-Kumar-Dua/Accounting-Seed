@IsTest
public with sharing class PaymentMethodProviderTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testNoPaymentProviders() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Account acct = testData.accounts[0];
            PaymentGateway gtwy = new PaymentGateway();
            PaymentMethodProvider provider = new PaymentMethodProvider(acct, gtwy);

            Exception expectedEx;
            try {
                provider.receiveStripeSources()
                    .leaveAvailableForSelectionOnly(true)
                    .bindWithSF()
                    .createSelectOption();
            } catch (Exception e) {
                expectedEx = e;
            }
            Test.stopTest();

            System.assertEquals(Label.ERR_PAYMENTS_NO_ACTIVE_PAYMENT_METHOD, expectedEx.getMessage());
            System.assertEquals(null, provider.selectedProcessorId);
            System.assertEquals(null, provider.selectedSourceId);
            System.assert(provider.processorSelectOptions.isEmpty());
            System.assert(provider.sourceIdsSelectOptions.isEmpty());
        }
    }

    @IsTest
    static void testNoPaymentMethods() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Account acct = testData.accounts[0];

            Payment_Processor_Customer__c customer =  new Payment_Processor_Customer__c(
                Account__c = acct.Id,
                Processor__c = testData.paymentProcessors[0].Id,
                External_Id__c = 'cust_984iIJkdfnLKH9843s'
            );
            insert customer;

            PaymentGateway gtwy = new PaymentGateway();
            PaymentMethodProvider provider = new PaymentMethodProvider(acct, gtwy);

            Exception expectedEx;
            try {
                provider.receiveStripeSources()
                    .leaveAvailableForSelectionOnly(true)
                    .bindWithSF()
                    .createSelectOption();
            } catch (Exception e) {
                expectedEx = e;
            }
            Test.stopTest();

            System.assertEquals(Label.ERR_PAYMENTS_NO_ACTIVE_PAYMENT_METHOD, expectedEx.getMessage());
            System.assertEquals(null, provider.selectedProcessorId);
            System.assertEquals(null, provider.selectedSourceId);
            System.assert(provider.processorSelectOptions.isEmpty());
            System.assert(provider.sourceIdsSelectOptions.isEmpty());
        }
    }

    @IsTest
    static void testPaymentMethodsDefaults() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Account acct = testData.accounts[0];

            Payment_Processor_Customer__c customer =  new Payment_Processor_Customer__c(
                Account__c = acct.Id,
                Processor__c = testData.paymentProcessors[0].Id,
                External_Id__c = 'cust_984iIJkdfnLKH9843s'
            );
            insert customer;

            Payment_Method__c defaultMethod = new Payment_Method__c(
                Payment_Processor__c = customer.Processor__c,
                Customer__c = customer.Account__c,
                External_Id__c = 'pm_vNNNUw849gfjawugn34h',
                Last_Four_Digits__c = '1234',
                Type__c = 'Visa',
                Expiration_Month__c = '01',
                Expiration_Year__c = '98',
                Payment_Method_Type__c = PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE,
                Default__c = true,
                Status__c = PaymentMethodActions.PAYMENT_METHOD_STATUS_ACTIVE
            );
            insert defaultMethod;

            Payment_Method__c notDefaultMethod = new Payment_Method__c(
                Payment_Processor__c = customer.Processor__c,
                Customer__c = customer.Account__c,
                External_Id__c = 'pm_vaero847df9KMIUo94',
                Last_Four_Digits__c = '1234',
                Type__c = 'Visa',
                Expiration_Month__c = '01',
                Expiration_Year__c = '99',
                Payment_Method_Type__c = PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE,
                Default__c = false,
                Status__c = PaymentMethodActions.PAYMENT_METHOD_STATUS_ACTIVE
            );
            insert notDefaultMethod;

            PaymentGatewayMock mock = new PaymentGatewayMock();
            mock.registerResponse('getPaymentMethods', new List<Payment_Method__c> {
                defaultMethod.clone(false,true,false,false),
                notDefaultMethod.clone(false,true,false,false)
            });
            PaymentGateway gtwy = (PaymentGateway) Test.createStub(PaymentGateway.class, mock);

            Test.startTest();
            PaymentMethodProvider provider = new PaymentMethodProvider(acct, gtwy);

            provider.receiveStripeSources()
                .leaveAvailableForSelectionOnly(true)
                .bindWithSF()
                .createSelectOption();
            Test.stopTest();

            System.assertEquals(defaultMethod.Payment_Processor__c, provider.selectedProcessorId);
            System.assertEquals(defaultMethod.External_Id__c, provider.selectedSourceId);
            System.assertEquals(1, provider.processorSelectOptions.size());
            System.assertEquals(2, provider.sourceIdsSelectOptions.size());
        }
    }

    @IsTest
    static void testPaymentMethodsFromMultipleSources() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Account acct = testData.accounts[0];

            Payment_Processor_Customer__c customer1 =  new Payment_Processor_Customer__c(
                Account__c = acct.Id,
                Processor__c = testData.paymentProcessors[0].Id,
                External_Id__c = 'cust_984iIJkdfnLKH9843s'
            );
            Payment_Processor_Customer__c customer2 =  new Payment_Processor_Customer__c(
                Account__c = acct.Id,
                Processor__c = testData.paymentProcessors[1].Id,
                External_Id__c = 'cust_9cn09ajdKJI984dOid'
            );
            insert new List<Payment_Processor_Customer__c>{ customer1, customer2 };

            Payment_Method__c pm1 = new Payment_Method__c(
                Payment_Processor__c = customer1.Processor__c,
                Customer__c = customer1.Account__c,
                External_Id__c = 'pm_vNNNUw849gfjawugn34h',
                Last_Four_Digits__c = '1234',
                Type__c = 'Visa',
                Expiration_Month__c = '01',
                Expiration_Year__c = '98',
                Payment_Method_Type__c = PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE,
                Status__c = PaymentMethodActions.PAYMENT_METHOD_STATUS_ACTIVE
            );

            Payment_Method__c pm2 = new Payment_Method__c(
                Payment_Processor__c = customer2.Processor__c,
                Customer__c = customer2.Account__c,
                External_Id__c = 'pm_vaero847df9KMIUo94',
                Last_Four_Digits__c = '1234',
                Type__c = 'Visa',
                Expiration_Month__c = '01',
                Expiration_Year__c = '99',
                Payment_Method_Type__c = PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE,
                Status__c = PaymentMethodActions.PAYMENT_METHOD_STATUS_ACTIVE
            );

            PaymentGatewayMock mock = new PaymentGatewayMock();
            mock.registerResponse('getPaymentMethods', new List<Payment_Method__c> { pm1 });
            mock.registerResponse('getPaymentMethods', new List<Payment_Method__c> { pm2 });
            PaymentGateway gtwy = (PaymentGateway) Test.createStub(PaymentGateway.class, mock);

            Test.startTest();
            PaymentMethodProvider provider = new PaymentMethodProvider(acct, gtwy);

            provider.receiveStripeSources()
                .leaveAvailableForSelectionOnly(true)
                .bindWithSF()
                .createSelectOption();
            Test.stopTest();

            provider.selectedProcessorId = customer1.Processor__c;
            provider.updateSelectedPaymentMethod();

            System.assertEquals(2, provider.processorSelectOptions.size());
            System.assertEquals(1, provider.sourceIdsSelectOptions.size());
            System.assertEquals(pm1.External_Id__c, provider.sourceIdsSelectOptions[0].getValue());

            provider.selectedProcessorId = customer2.Processor__c;
            provider.updateSelectedPaymentMethod();

            System.assertEquals(2, provider.processorSelectOptions.size());
            System.assertEquals(1, provider.sourceIdsSelectOptions.size());
            System.assertEquals(pm2.External_Id__c, provider.sourceIdsSelectOptions[0].getValue());
        }
    }

    @IsTest
    static void testPaymentMethodsFromExternalOnly() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Account acct = testData.accounts[0];

            Payment_Processor_Customer__c customer =  new Payment_Processor_Customer__c(
                Account__c = acct.Id,
                Processor__c = testData.paymentProcessors[0].Id,
                External_Id__c = 'cust_984iIJkdfnLKH9843s'
            );
            insert customer;

            Payment_Method__c pm1 = new Payment_Method__c(
                Payment_Processor__c = customer.Processor__c,
                Customer__c = customer.Account__c,
                External_Id__c = 'pm_vNNNUw849gfjawugn34h',
                Last_Four_Digits__c = '1234',
                Type__c = 'Visa',
                Expiration_Month__c = '01',
                Expiration_Year__c = '98',
                Payment_Method_Type__c = PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE,
                Status__c = PaymentMethodActions.PAYMENT_METHOD_STATUS_ACTIVE
            );

            Payment_Method__c pm2 = new Payment_Method__c(
                Payment_Processor__c = customer.Processor__c,
                Customer__c = customer.Account__c,
                External_Id__c = 'pm_vaero847df9KMIUo94',
                Last_Four_Digits__c = '1234',
                Type__c = 'Visa',
                Expiration_Month__c = '01',
                Expiration_Year__c = '99',
                Payment_Method_Type__c = PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE,
                Status__c = PaymentMethodActions.PAYMENT_METHOD_STATUS_ACTIVE
            );

            PaymentGatewayMock mock = new PaymentGatewayMock();
            mock.registerResponse('getPaymentMethods', new List<Payment_Method__c> { pm1, pm2 });
            PaymentGateway gtwy = (PaymentGateway) Test.createStub(PaymentGateway.class, mock);

            Test.startTest();
            PaymentMethodProvider provider = new PaymentMethodProvider(acct, gtwy);

            provider.receiveStripeSources()
                .leaveAvailableForSelectionOnly(true)
                .bindWithSF()
                .createSelectOption();
            Test.stopTest();

            System.assertEquals(1, provider.processorSelectOptions.size());
            System.assertEquals(2, provider.sourceIdsSelectOptions.size());
        }
    }

    @IsTest
    static void testPaymentMethodsFilterInactive() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Account acct = testData.accounts[0];

            Payment_Processor_Customer__c customer =  new Payment_Processor_Customer__c(
                Account__c = acct.Id,
                Processor__c = testData.paymentProcessors[0].Id,
                External_Id__c = 'cust_984iIJkdfnLKH9843s'
            );
            insert customer;

            Payment_Method__c pm1 = new Payment_Method__c(
                Payment_Processor__c = customer.Processor__c,
                Customer__c = customer.Account__c,
                External_Id__c = 'pm_vNNNUw849gfjawugn34h',
                Last_Four_Digits__c = '1234',
                Type__c = 'Visa',
                Expiration_Month__c = '01',
                Expiration_Year__c = '98',
                Payment_Method_Type__c = PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE,
                Status__c = PaymentMethodActions.PAYMENT_METHOD_STATUS_INACTIVE
            );

            Payment_Method__c pm2 = new Payment_Method__c(
                Payment_Processor__c = customer.Processor__c,
                Customer__c = customer.Account__c,
                External_Id__c = 'pm_vaero847df9KMIUo94',
                Last_Four_Digits__c = '1234',
                Type__c = 'Visa',
                Expiration_Month__c = '01',
                Expiration_Year__c = '99',
                Payment_Method_Type__c = PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE,
                Status__c = PaymentMethodActions.PAYMENT_METHOD_STATUS_ACTIVE
            );

            PaymentGatewayMock mock = new PaymentGatewayMock();
            mock.registerResponse('getPaymentMethods', new List<Payment_Method__c> { pm1, pm2 });
            PaymentGateway gtwy = (PaymentGateway) Test.createStub(PaymentGateway.class, mock);

            Test.startTest();
            PaymentMethodProvider provider = new PaymentMethodProvider(acct, gtwy);

            provider.receiveStripeSources()
                .leaveAvailableForSelectionOnly(true)
                .bindWithSF()
                .createSelectOption();
            Test.stopTest();

            System.assertEquals(1, provider.processorSelectOptions.size());
            System.assertEquals(1, provider.sourceIdsSelectOptions.size());
        }
    }

    @IsTest
    static void testPaymentMethodsFilterUnverrified() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Account acct = testData.accounts[0];

            Payment_Processor_Customer__c customer =  new Payment_Processor_Customer__c(
                Account__c = acct.Id,
                Processor__c = testData.paymentProcessors[0].Id,
                External_Id__c = 'cust_984iIJkdfnLKH9843s'
            );
            insert customer;

            Payment_Method__c pm1 = new Payment_Method__c(
                Payment_Processor__c = customer.Processor__c,
                Customer__c = customer.Account__c,
                External_Id__c = 'pm_vNNNUw849gfjawugn34h',
                Last_Four_Digits__c = '1234',
                Type__c = 'Visa',
                Expiration_Month__c = '01',
                Expiration_Year__c = '98',
                Payment_Method_Type__c = PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE,
                Status__c = PaymentMethodActions.PAYMENT_METHOD_STATUS_ACTIVE,
                Verification_Status__c = 'unverified'
            );

            Payment_Method__c pm2 = new Payment_Method__c(
                Payment_Processor__c = customer.Processor__c,
                Customer__c = customer.Account__c,
                External_Id__c = 'pm_vaero847df9KMIUo94',
                Last_Four_Digits__c = '1234',
                Type__c = 'Visa',
                Expiration_Month__c = '01',
                Expiration_Year__c = '99',
                Payment_Method_Type__c = PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE,
                Status__c = PaymentMethodActions.PAYMENT_METHOD_STATUS_ACTIVE
            );

            PaymentGatewayMock mock = new PaymentGatewayMock();
            mock.registerResponse('getPaymentMethods', new List<Payment_Method__c> { pm1, pm2 });
            PaymentGateway gtwy = (PaymentGateway) Test.createStub(PaymentGateway.class, mock);

            Test.startTest();
            PaymentMethodProvider provider = new PaymentMethodProvider(acct, gtwy);

            provider.receiveStripeSources()
                .leaveAvailableForSelectionOnly(true)
                .bindWithSF()
                .createSelectOption();
            Test.stopTest();

            System.assertEquals(1, provider.processorSelectOptions.size());
            System.assertEquals(1, provider.sourceIdsSelectOptions.size());
        }
    }

    private class PaymentGatewayMock implements System.StubProvider {
        // method_name => [first_resp, second_resp, third_resp]
        private Map<String,List<Object>> resps;

        public PaymentGatewayMock() {
            this.resps = new Map<String,List<Object>>();
        }

        public void registerResponse(String methodName, Object response) {
            if (!resps.containsKey(methodName)) {
                resps.put(methodName, new List<Object>());
            }
            resps.get(methodName).add(response);
        }

        public Object handleMethodCall(
                Object stubbedObject,
                String stubbedMethodName,
                Type returnType,
                List<Type> listOfParamTypes,
                List<String> listOfParamNames,
                List<Object> listOfArgs) {

            if (resps.containsKey(stubbedMethodName) && !resps.get(stubbedMethodName).isEmpty()) {
                return resps.get(stubbedMethodName).remove(0);
            }
            return null;
        }
    }

}