@IsTest
private class BillingsArchiveDeleteBatchTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    
    @IsTest
    private static void testBillingReceiptJob() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings(false);
        
        System.runAs(testData.users[1]) {
            List<Billing__c> selBill = testData.billings;

            //Check total Billings Records
            System.assertEquals(5, selBill.size());

            BillingPostService.postBillings(new List<Billing__c> {selBill[0], selBill[1]});
            List<Transaction__c> transactionList = [
                SELECT
                    Id
                FROM Transaction__c
                WHERE Billing__c =:selBill[0].Id
                OR Billing__c =:selBill[1].Id
            ];

            TransactionActions.isPreventDeleteOverride = true;
            delete transactionList;
            
            Test.startTest();
            //Run batch job to delete Billings Records.
            AbstractArchiveDeleteBatch.executeBatchChain(
                new AbstractArchiveDeleteBatch.ArchiveDeleteChainController(
                    testData.acctPeriods[0].Id
                ),
                null
            );
            Test.stopTest();
            
            //Make sure only Posted Billings Records deleted.
            System.assertEquals(
                3, [
                    SELECT Id FROM Billing__c 
                ].size() 
            );
        }
    }
}