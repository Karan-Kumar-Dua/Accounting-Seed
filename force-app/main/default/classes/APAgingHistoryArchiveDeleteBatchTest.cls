@IsTest
private class APAgingHistoryArchiveDeleteBatchTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    
    @IsTest
    static void testAPAgingJob() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createAPAgingHistories();
        
        System.runAs(testData.users[1]) {
            //Check total apAgingHistories Records
            System.assertEquals(3, [SELECT Id FROM AP_Aging_History__c].size());
            
            Test.startTest();
            //Run batch job to delete apAgingHistories Records.
            AbstractArchiveDeleteBatch.executeBatchChain(
                new AbstractArchiveDeleteBatch.ArchiveDeleteChainController(testData.acctPeriods[0].Id),
                null
            );
            Test.stopTest();
            
            //Make sure apAgingHistories Records for acctPeriods[0] is deleted.
            System.assertEquals(2, [SELECT Id FROM AP_Aging_History__c].size());
        }
    }

}