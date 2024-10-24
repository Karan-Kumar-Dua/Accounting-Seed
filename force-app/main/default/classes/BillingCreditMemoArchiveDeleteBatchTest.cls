@IsTest
private class BillingCreditMemoArchiveDeleteBatchTest {
        
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    
    @IsTest
    private static void testBillingCreditMemoJob() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            
            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
            bcm.Billing_Invoice__c = testData.billings[0].Id;
            bcm.Billing_Credit_Memo__c = testData.billings[2].Id;
            bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
            bcm.Amount__c = -2;
            insert bcm;

            Test.startTest();
            //Run batch job to delete BillingCreditMemo Records.
            AbstractArchiveDeleteBatch.executeBatchChain(new AbstractArchiveDeleteBatch.ArchiveDeleteChainController(testData.acctPeriods[0].Id), null);
            Test.stopTest();
            
            //Make sure BillingCreditMemo Records deleted.
            System.assertEquals(
                0, [
                    SELECT Id FROM Billing_Credit_Memo__c 
                ].size() 
            );      
        }
    }
}