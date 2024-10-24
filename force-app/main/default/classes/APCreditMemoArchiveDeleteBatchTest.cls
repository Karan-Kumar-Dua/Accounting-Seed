@IsTest
private class APCreditMemoArchiveDeleteBatchTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    
    @IsTest
    private static void testAPCreditMemoJob() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(false);
        
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            AP_Credit_Memo__c acm = new AP_Credit_Memo__c();
            acm.Account_Payable_Invoice__c = testData.payables[0].Id;
            acm.Account_Payable_Credit_Memo__c = testData.payables[4].Id;
            acm.Accounting_Period__c = testData.acctPeriods[1].Id;
            acm.Amount__c = -2;
            insert acm;
            
            acm = new AP_Credit_Memo__c();
            acm.Account_Payable_Invoice__c = testData.payables[0].Id;
            acm.Account_Payable_Credit_Memo__c = testData.payables[4].Id;
            acm.Accounting_Period__c = testData.acctPeriods[1].Id;
            acm.Amount__c = -1;
            insert acm;
            
            //Check total APCreditMemo Records
            System.assertEquals(
                2, [
                    SELECT Id FROM AP_Credit_Memo__c
                ].size() 
            );

            //Run batch job to delete APCreditMemoJob Records.
            AbstractArchiveDeleteBatch.executeBatchChain(new AbstractArchiveDeleteBatch.ArchiveDeleteChainController(testData.acctPeriods[1].Id), null);
            Test.stopTest();
            
            //Make sure APCreditMemoJob Records deleted.
            System.assertEquals(
                0, [
                    SELECT Id FROM AP_Credit_Memo__c 
                ].size() 
            );      
        }
    }
}