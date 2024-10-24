@IsTest
private class APDisbursementArchiveDeleteBatchTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    
    @IsTest
    private static void testDeleteAPDisbursementJob() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(false)
            .createCashDisbursementBatches()
            .createCashDisbursements(false);

        Test.startTest();
        testData.createApDisbursements();

        System.runAs(testData.users[1]) {
            //Check total AP Disbursement Records
            System.assertEquals(
                6, [
                    SELECT Id FROM AP_Disbursement__c
                ].size() 
            );

            List<Transaction__c> transactionList = [SELECT Id FROM Transaction__c];
            TransactionActions.isPreventDeleteOverride = true;
            delete transactionList;

            //Run batch job to delete AP Disbursement Records.
            AbstractArchiveDeleteBatch.executeBatchChain(new AbstractArchiveDeleteBatch.ArchiveDeleteChainController(testData.acctPeriods.get(0).Id), null);
            Test.stopTest();
            
            //Make sure AP Disbursement Records deleted.
            System.assertEquals(
                1, [
                    SELECT Id FROM AP_Disbursement__c 
                ].size() 
            );      
        }
    }
}