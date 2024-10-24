@IsTest
private class CashReceiptArchiveDeleteBatchTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    
    @IsTest
    static void testDeleteCashReceiptJob() {
        TestDataSuite testData = TestDataSuite.getInstance().disableAutoPostSourceDocuments().createCashReceipts();

        System.runAs(testData.users[1]) {
            //Check total CashReceipt Records
            List<Cash_Receipt__c> selCR = [SELECT Id FROM Cash_Receipt__c];
            System.assertEquals(3, selCR.size());

            CashReceiptPostService.postCashReceipts(new List<Cash_Receipt__c>{selCR[0], selCR[1]});
            List<Transaction__c> transactionList = [SELECT Id FROM Transaction__c WHERE Cash_Receipt__c =:selCR[0].Id OR Cash_Receipt__c =:selCR[1].Id];
            TransactionActions.isPreventDeleteOverride = true;
            delete transactionList;
            
            Test.startTest();
            //Run batch job to delete CashReceipt Records.
            AbstractArchiveDeleteBatch.executeBatchChain(new AbstractArchiveDeleteBatch.ArchiveDeleteChainController(testData.acctPeriods.get(1).Id), null);
            Test.stopTest();
            
            //Make sure CashReceipt Records deleted.
            System.assertEquals(
                1, [
                    SELECT Id FROM Cash_Receipt__c 
                ].size() 
            );      
        }
    }
}