@IsTest
public with sharing class PaymentProcessorHelperTest {
   
    @TestSetup
    static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testGetPaymentProcessorAuthorizationURLTestMode(){
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Payment_Processor__c proc = testData.paymentProcessors[0].clone(false, true, false, false);
            proc.Test_Mode__c = true;
            insert proc;

            Test.startTest();
            String uri = PaymentProcessorHelper.getPaymentProcessorAuthorizationURL(proc.Id);
            Test.stopTest();

            List<External_Settings__mdt> settings = [
                    SELECT Value_1__c, Value_2__c, Value_3__c, Value_4__c
                    FROM External_Settings__mdt
                    WHERE DeveloperName = 'Stripe_Test_Settings' LIMIT 1
            ];

            System.assertEquals(1, settings.size());

            String expectedURI =
                'https://connect.stripe.com/oauth/authorize?response_type=code&client_id=' 
                + settings[0].Value_3__c 
                + '&scope=read_write&state=' 
                + 'test-session-id'
                + '%7C' 
                + URL.getOrgDomainUrl().toExternalForm()
                + '%7C'
                + proc.Id;
            System.assertEquals(expectedURI, uri);
            
        }
    }

    @IsTest
    static void testGetPaymentProcessorAuthorizationURLLiveMode(){
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Payment_Processor__c proc = testData.paymentProcessors[0];
            proc.Test_Mode__c = false;
            update proc;

            Test.startTest();
            String uri = PaymentProcessorHelper.getPaymentProcessorAuthorizationURL(proc.Id);
            Test.stopTest();

            List<External_Settings__mdt> settings = [
                    SELECT Value_1__c, Value_2__c, Value_3__c, Value_4__c
                    FROM External_Settings__mdt
                    WHERE DeveloperName = 'Stripe_Settings' LIMIT 1
            ];

            System.assertEquals(1, settings.size());

            String expectedURI =
                'https://connect.stripe.com/oauth/authorize?response_type=code&client_id=' 
                + settings[0].Value_3__c 
                + '&scope=read_write&state=' 
                + 'test-session-id'
                + '%7C' 
                + URL.getOrgDomainUrl().toExternalForm()
                + '%7C'
                + proc.Id;
            System.assertEquals(expectedURI, uri);
        }
    }

}