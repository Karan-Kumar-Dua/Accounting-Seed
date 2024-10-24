@IsTest
private class BillingAgHistoryArchiveDeleteBatchTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    
    @IsTest
    static void testBillingAgingHistoryReceiptJob() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings().createBillingAgingHistories();
        
        System.runAs(testData.users[1]) {
            //Check total BillingAgingHistory Records
            System.assertEquals(
                3, [
                    SELECT Id FROM Billing_Aging_History__c
                ].size() 
            );
            
            Test.startTest();
            //Run batch job to delete BillingAgingHistory Records.
            AbstractArchiveDeleteBatch.executeBatchChain(new AbstractArchiveDeleteBatch.ArchiveDeleteChainController(testData.acctPeriods[0].Id), null);
            Test.stopTest();
            
            //Make sure BillingAgingHistory Records for acctPeriods[0] is deleted.
            System.assertEquals(
                2, [
                    SELECT Id FROM Billing_Aging_History__c 
                ].size() 
            );      
        }
    }
}