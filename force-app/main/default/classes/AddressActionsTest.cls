@IsTest
public class AddressActionsTest {
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testPostSQSMessageToBankAccount() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().
            createBankAccountsWithPaymentEnabled();
        
        System.runAs(testData.users[1]) {
             //Setting of mock
             SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.UPDATE_BANK_ACCOUNT_JSON , 
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, awsSuccess); 

            Address__c address = [SELECT Id,City__c FROM Address__c WHERE City__c = 'Odessa'][0];
            Test.startTest();
            Boolean isSuccess = true;
            try {
            address.City__c = 'MidLand';
            update address;
            }
            catch(Exception ex) {
                isSuccess = false;
            }
            Assert.areEqual(true,isSuccess);
            Test.stopTest();

        }
    }
    @IsTest
    private static void testPostSQSMessageToLedger() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().
                                        createLedgerWithPaymentEnabled();
        System.runAs(testData.users[1]) {
             //Setting of mock
             SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.UPDATE_COMPANY_JSON , 
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, awsSuccess); 

            Address__c address1 = [SELECT Id,Street__c FROM Address__c WHERE City__c = 'Odessa'][0];
            Test.startTest();
            Boolean isSuccess = true;
            try {
                address1.Street__c = 'MidLand';
                update address1;
            }
            catch(Exception ex) {
                isSuccess = false;
            }
            Assert.areEqual(true,isSuccess);
            Test.stopTest();

        }
    }
}