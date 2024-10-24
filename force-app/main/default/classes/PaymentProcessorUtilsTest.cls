@IsTest
public with sharing class PaymentProcessorUtilsTest {
   
    @TestSetup
    public static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testGetPaymentProcessorSome() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Payment_Processor__c p = testData.paymentProcessors[0];

            Test.startTest();
            Payment_Processor__c result = PaymentProcessorUtils.getPaymentProcessor(p.Id);
            Test.stopTest();
            
            System.assertEquals(p.Id, result.Id);
        }
    }

    @IsTest
    static void testGetPaymentProcessorNone() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Payment_Processor__c result = PaymentProcessorUtils.getPaymentProcessor(null);
            Test.stopTest();
            
            System.assertEquals(null, result);
        }
    }

    @IsTest
    static void testGetAccountSome() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Account a = testData.accounts[0];

            Test.startTest();
            Account result = PaymentProcessorUtils.getAccount(a.Id);
            Test.stopTest();
            
            System.assertEquals(a.Id, result.Id);
        }
    }

    @IsTest
    static void testGetAccountNone() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Account result = PaymentProcessorUtils.getAccount(null);
            Test.stopTest();
            
            System.assertEquals(null, result);
        }
    }
}