@isTest
public with sharing class APAutomationServiceTest{

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    //This test method is required to have the code coverage
    @isTest
    public static void testPostMessage() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance();  
        Id vendorId = testData.accounts.get(0).Id;          
        
        System.runAs(testData.users[1]) {
        Test.startTest();
            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.CREATE_BANK_ACCOUNT_JSON ,  
                new Map<String, String>{'Content-Type' => 'application/json'}
            );
    
            Test.setMock(HttpCalloutMock.class, awsSuccess); 
            Boolean isSuccess = false;
            try {
                APAutomationService.postMessage(new List<Id>{vendorId}, APAutomationService.APAutomationActions.CREATE_BANK_ACCOUNT.name());
                Account acc = [SELECT Id,Payment_Services_Enrollment_Status__c from Account where Id = :vendorId];
                Assert.areEqual('Processing',acc.Payment_Services_Enrollment_Status__c);
                isSuccess = true;
            }
            catch(Exception ex) {
                isSuccess = false;
            }
            Assert.areEqual(true,isSuccess);
            
            
        Test.stopTest();
        }
    }
    @isTest
    public static void testPostMessageError() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance();  
        Id vendorId = testData.accounts.get(0).Id;          
        
        Test.startTest();
            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                400,
                'Complete',
                AwsServiceTest.ERROR_RESPONSE_JSON ,  
                new Map<String, String>{'Content-Type' => 'application/json'}
            );
    
            Test.setMock(HttpCalloutMock.class, awsSuccess); 
            Boolean isSuccess = false;
            try {
                APAutomationService.postMessage(new List<Id>{vendorId}, APAutomationService.APAutomationActions.CREATE_BANK_ACCOUNT.name());
                Account acc = [SELECT Id,Payment_Services_Enrollment_Status__c from Account where Id = :vendorId];
                Assert.areEqual('Denied',acc.Payment_Services_Enrollment_Status__c);
                isSuccess = true;
            }
            catch(Exception ex) {
                isSuccess = false;
            }
            Assert.areEqual(false,isSuccess);
            
            
        Test.stopTest();
    }
}