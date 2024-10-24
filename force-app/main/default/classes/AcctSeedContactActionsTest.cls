@isTest
public class AcctSeedContactActionsTest {
    @TestSetup
    private static void setupTestData(){
        TestDataSuite.getInstance(true);
        
    }

    @isTest
    public static void testapAutomationPostMessage(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True); 
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Boolean isSuccess = false;
            Test.startTest();   
    
            try{
                Account acct = testData.accounts[0].clone(false);
                acct.Enable_Payment_Services__c = true;
                insert acct;
                
                Contact con = testData.contacts[0].clone(false);
                con.LastName = 'TestCon';
                con.Email = 'test@gmail.com';
                con.AccountId = acct.Id;
                insert con;
    
                con.Email = 'test2@gmail.com';
                update con;

                SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.CREATE_VENDOR_JSON,
                new Map<String, String>{
                    'Content-Type' => 'application/json'
                }
            );

            Test.setMock(HttpCalloutMock.class, awsSuccess);

            }catch (Exception ex){
                isSuccess = false;
            }
            
            Test.stopTest();
        }
    }
}