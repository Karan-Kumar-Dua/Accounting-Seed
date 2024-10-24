@IsTest
private class BillingCashReceiptArchiveDeleteBatchTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    
    @IsTest
    static void testDeleteCashReceiptJob() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings(false)
            .createCashReceipts();
        
        System.runAs(testData.users[1]) {
            Test.startTest();
            Cash_Receipt__c testCR1 = testData.cashReceipts[0];
            Billing__c testBilling = testData.billings[0];

            //Create BCR
            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c(
                Billing__c = testBilling.Id,
                Cash_Receipt__c = testCR1.Id,
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Applied_Amount__c = 450
            );

            DmlException dmlEx;
            try {
                insert bcr;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(null, dmlEx);

            //Check total billingCashReceipt Records
            System.assertEquals(
                1, [
                    SELECT Id FROM Billing_Cash_Receipt__c
                ].size() 
            );
            
            //Run batch job to delete billingCashReceipt Records.
            AbstractArchiveDeleteBatch.executeBatchChain(new AbstractArchiveDeleteBatch.ArchiveDeleteChainController(testData.acctPeriods[1].Id), null);
            Test.stopTest();
            
            //Make sure billingCashReceipt Records deleted.
            System.assertEquals(
                0, [
                    SELECT Id FROM Billing_Cash_Receipt__c
                ].size() 
            );
        }
    }
}