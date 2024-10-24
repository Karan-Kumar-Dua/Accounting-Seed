@IsTest
private class BillingLineArchiveDeleteBatchTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    
    @IsTest
    private static void testBillingLineReceiptJob() {
        TestDataSuite testData = TestDataSuite.getInstance().disableAutoPostSourceDocuments().createBillings();
        
        System.runAs(testData.users[1]) {
            //Check total BillingLines Records
            System.assertEquals(
                7, [
                    SELECT Id FROM Billing_Line__c
                ].size() 
            );
            List<Billing__c> selBill = [SELECT Id FROM Billing__c];

            //Check total Billings Records
            System.assertEquals(5, selBill.size());

            BillingPostService.postBillings(new List<Billing__c> {selBill[0], selBill[1]});
            List<Transaction__c> transactionList = [SELECT Id FROM Transaction__c WHERE Billing__c =:selBill[0].Id OR Billing__c =:selBill[1].Id];
            TransactionActions.isPreventDeleteOverride = true;
            delete transactionList;

            Test.startTest();
            //Run batch job to delete BillingLines Records.
            AbstractArchiveDeleteBatch.executeBatchChain(new AbstractArchiveDeleteBatch.ArchiveDeleteChainController(testData.acctPeriods[0].Id), null);
            Test.stopTest();
            
            //Make sure BillingLines Records deleted.
            System.assertEquals(
                3, [
                    SELECT Id FROM Billing_Line__c 
                ].size() 
            );      
        }
    }
}