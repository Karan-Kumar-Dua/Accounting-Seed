@IsTest
public with sharing class PaymentProcessorFactoryTest {
    
    @TestSetup
    static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testGetPaymentProcessorNull() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            MdtBindingHandlerMock mock = new MdtBindingHandlerMock(new StripeProcessorV1());
            MdtBindingHandler.instance = (MdtBindingHandler) Test.createStub(MdtBindingHandler.class, mock);
            
            Payment_Processor__c pmtProc = null;
            PaymentProcessorFactory factory = new PaymentProcessorFactory();
            PaymentProcessor processor = factory.getPaymentProcessor(pmtProc);

            System.assertEquals(null, processor);
        }
    }

    @IsTest
    public static void testGetPaymentProcessorNone() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            MdtBindingHandlerMock mock = new MdtBindingHandlerMock(new StripeProcessorV1());
            MdtBindingHandler.instance = (MdtBindingHandler) Test.createStub(MdtBindingHandler.class, mock);

            Payment_Processor__c pmtProc = new Payment_Processor__c(
                Id = FinancialSuiteUtils.getFakeId(Payment_Processor__c.SObjectType)
            );

            PaymentProcessorFactory factory = new PaymentProcessorFactory();
            PaymentProcessor processor = factory.getPaymentProcessor(pmtProc);

            System.assertEquals(null, processor);
        }
    }

    @IsTest
    public static void testGetPaymentProcessor() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            MdtBindingHandlerMock mock = new MdtBindingHandlerMock(new StripeProcessorV1());
            MdtBindingHandler.instance = (MdtBindingHandler) Test.createStub(MdtBindingHandler.class, mock);

            PaymentProcessorFactory factory = new PaymentProcessorFactory();
            StripeProcessorV1 processor = (StripeProcessorV1) factory.getPaymentProcessor(testData.paymentProcessors[0]);

            System.assertNotEquals(null, processor);
        }
    }

    @IsTest
    public static void testGetPaymentProcessorCardknox() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            MdtBindingHandlerMock mock = new MdtBindingHandlerMock(new CardknoxProcessorV1());
            MdtBindingHandler.instance = (MdtBindingHandler) Test.createStub(MdtBindingHandler.class, mock);

            PaymentProcessorFactory factory = new PaymentProcessorFactory();
            PaymentProcessor processor = (PaymentProcessor) factory.getPaymentProcessor(testData.paymentProcessors[2]);

            Assert.isInstanceOfType(processor, CardknoxProcessorV1.class);
        }
    }

    // -----

    @IsTest
    public static void testGetPaymentProcessorBillingNull() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPaymentProcessors()
            .createBillings();

        System.runAs(testData.users.get(1)) {
            MdtBindingHandlerMock mock = new MdtBindingHandlerMock(new StripeProcessorV1());
            MdtBindingHandler.instance = (MdtBindingHandler) Test.createStub(MdtBindingHandler.class, mock);
            
            Billing__c billing = null;
            PaymentProcessorFactory factory = new PaymentProcessorFactory();
            PaymentProcessor processor = factory.getPaymentProcessor(billing);

            System.assertEquals(null, processor);
        }
    }

    @IsTest
    public static void testGetPaymentProcessorBillingNone() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPaymentProcessors()    
            .createBillings();

        System.runAs(testData.users.get(1)) {
            MdtBindingHandlerMock mock = new MdtBindingHandlerMock(new StripeProcessorV1());
            MdtBindingHandler.instance = (MdtBindingHandler) Test.createStub(MdtBindingHandler.class, mock);
            
            Billing__c billing = new Billing__c(
                Id = FinancialSuiteUtils.getFakeId(Billing__c.SObjectType)
            );
            PaymentProcessorFactory factory = new PaymentProcessorFactory();
            PaymentProcessor processor = factory.getPaymentProcessor(billing);

            System.assertEquals(null, processor);
        }
    }

    @IsTest
    public static void testGetPaymentProcessorBilling() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPaymentProcessors()
            .createBillings();

        System.runAs(testData.users.get(1)) {
            MdtBindingHandlerMock mock = new MdtBindingHandlerMock(new StripeProcessorV1());
            MdtBindingHandler.instance = (MdtBindingHandler) Test.createStub(MdtBindingHandler.class, mock);

            Billing__c billing = testData.billings[0];
            billing.Payment_Processor__c = testData.paymentProcessors[0].Id;
            update billing;

            PaymentProcessorFactory factory = new PaymentProcessorFactory();
            StripeProcessorV1 processor = (StripeProcessorV1) factory.getPaymentProcessor(billing);

            System.assertNotEquals(null, processor);
        }
    }

    // -----

    @IsTest
    public static void testGetPaymentProcessorPmtActivityNull() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            MdtBindingHandlerMock mock = new MdtBindingHandlerMock(new StripeProcessorV1());
            MdtBindingHandler.instance = (MdtBindingHandler) Test.createStub(MdtBindingHandler.class, mock);
            
            Payment_Activity__c pmtActivity = null;
            PaymentProcessorFactory factory = new PaymentProcessorFactory();
            PaymentProcessor processor = factory.getPaymentProcessor(pmtActivity);

            System.assertEquals(null, processor);
        }
    }

    @IsTest
    public static void testGetPaymentProcessorPmtActivityNone() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            MdtBindingHandlerMock mock = new MdtBindingHandlerMock(new StripeProcessorV1());
            MdtBindingHandler.instance = (MdtBindingHandler) Test.createStub(MdtBindingHandler.class, mock);
            
            Payment_Activity__c pmtActivity = new Payment_Activity__c(
                Id = FinancialSuiteUtils.getFakeId(Payment_Activity__c.SObjectType)
            );
            PaymentProcessorFactory factory = new PaymentProcessorFactory();
            PaymentProcessor processor = factory.getPaymentProcessor(pmtActivity);

            System.assertEquals(null, processor);
        }
    }

    @IsTest
    public static void testGetPaymentProcessorPmtActivity() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            MdtBindingHandlerMock mock = new MdtBindingHandlerMock(new StripeProcessorV1());
            MdtBindingHandler.instance = (MdtBindingHandler) Test.createStub(MdtBindingHandler.class, mock);

            Payment_Method__c pmtMethod = new Payment_Method__c(
                Payment_Processor__c = testData.paymentProcessors[0].Id,
                Customer__c = testData.accounts[0].Id,
                External_Id__c = 'abc123',
                Last_Four_Digits__c = '4444',
                Type__c = 'Visa',
                Expiration_Month__c = '11',
                Expiration_Year__c = '2099'
            );
            insert pmtMethod;

            Payment_Activity__c pmtActivity = new Payment_Activity__c(
                Payment_Method__c = pmtMethod.Id,
                Amount__c = 100
            );
            insert pmtActivity;

            PaymentProcessorFactory factory = new PaymentProcessorFactory();
            StripeProcessorV1 processor = (StripeProcessorV1) factory.getPaymentProcessor(pmtActivity);

            System.assertNotEquals(null, processor);
        }
    }

    // -----

    @IsTest
    public static void testGetPaymentProcessorPmtMethodNull() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            MdtBindingHandlerMock mock = new MdtBindingHandlerMock(new StripeProcessorV1());
            MdtBindingHandler.instance = (MdtBindingHandler) Test.createStub(MdtBindingHandler.class, mock);
            
            Payment_Method__c pmtMethod = null;
            PaymentProcessorFactory factory = new PaymentProcessorFactory();
            PaymentProcessor processor = factory.getPaymentProcessor(pmtMethod);

            System.assertEquals(null, processor);
        }
    }

    @IsTest
    public static void testGetPaymentProcessorPmtMethodNone() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            MdtBindingHandlerMock mock = new MdtBindingHandlerMock(new StripeProcessorV1());
            MdtBindingHandler.instance = (MdtBindingHandler) Test.createStub(MdtBindingHandler.class, mock);
            
            Payment_Method__c pmtMethod = new Payment_Method__c(
                Id = FinancialSuiteUtils.getFakeId(Payment_Method__c.SObjectType)
            );
            PaymentProcessorFactory factory = new PaymentProcessorFactory();
            PaymentProcessor processor = factory.getPaymentProcessor(pmtMethod);

            System.assertEquals(null, processor);
        }
    }

    @IsTest
    public static void testGetPaymentProcessorPmtMethod() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            MdtBindingHandlerMock mock = new MdtBindingHandlerMock(new StripeProcessorV1());
            MdtBindingHandler.instance = (MdtBindingHandler) Test.createStub(MdtBindingHandler.class, mock);

            Payment_Method__c pmtMethod = new Payment_Method__c(
                Payment_Processor__c = testData.paymentProcessors[0].Id,
                Customer__c = testData.accounts[0].Id,
                External_Id__c = 'abc123',
                Last_Four_Digits__c = '4444',
                Type__c = 'Visa',
                Expiration_Month__c = '11',
                Expiration_Year__c = '2099'
            );
            insert pmtMethod;

            PaymentProcessorFactory factory = new PaymentProcessorFactory();
            StripeProcessorV1 processor = (StripeProcessorV1) factory.getPaymentProcessor(pmtMethod);

            System.assertNotEquals(null, processor);
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