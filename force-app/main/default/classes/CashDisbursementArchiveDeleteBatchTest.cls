@IsTest
private class CashDisbursementArchiveDeleteBatchTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    
    @IsTest
    private static void testDeleteCashDisbursementJob() {
        TestDataSuite testData = TestDataSuite.getInstance().disableAutoPostSourceDocuments().createCashDisbursementBatches().createCashDisbursements();
        
        System.runAs(testData.users[1]) {
            //Check total CashDisbursements Records
            List<Cash_Disbursement__c> selCD = [SELECT Id FROM Cash_Disbursement__c];
            System.assertEquals(9, selCD.size());

            CashDisbursementPostService.postCashDisbursements(new List<Cash_Disbursement__c>{selCD[0], selCD[1]});
            List<Transaction__c> transactionList = [SELECT Id FROM Transaction__c WHERE Cash_Disbursement__c =:selCD[0].Id OR Cash_Disbursement__c =:selCD[1].Id];
            TransactionActions.isPreventDeleteOverride = true;
            delete transactionList;

            Test.startTest();
            //Run batch job to delete CashDisbursements Records.
            AbstractArchiveDeleteBatch.executeBatchChain(new AbstractArchiveDeleteBatch.ArchiveDeleteChainController(testData.acctPeriods[0].Id), null);
            Test.stopTest();
            
            //Make sure only Posted CashDisbursements Records deleted.
            System.assertEquals(
                7, [
                    SELECT Id FROM Cash_Disbursement__c 
                ].size() 
            );      
        }
    }
}