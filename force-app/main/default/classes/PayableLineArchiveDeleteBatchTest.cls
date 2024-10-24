@IsTest
private class PayableLineArchiveDeleteBatchTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    
    @IsTest
    private static void testPayableLineJob() {
        TestDataSuite testData = TestDataSuite.getInstance().disableAutoPostSourceDocuments().createPayables();
        
        System.runAs(testData.users[1]) {
            //Check total PayableLine Records
            System.assertEquals(
                15, [
                    SELECT Id FROM Account_Payable_Line__c
                ].size() 
            );
            
            //Check total PayableLine Records related to Period[0];
            System.assertEquals(
                11, [
                    SELECT Id FROM Account_Payable_Line__c WHERE Account_Payable__r.Accounting_Period__c = :testData.acctPeriods[0].Id
                ].size() 
            );

            List<Account_Payable__c> selPay = [SELECT Id FROM Account_Payable__c WHERE Accounting_Period__c = :testData.acctPeriods[0].Id];
            AccountPayablePostService.postAccountPayables(new List<Account_Payable__c> {selPay[0], selPay[1]});
            List<Transaction__c> transactionList = [SELECT Id FROM Transaction__c WHERE Account_Payable__c =:selPay[0].Id OR Account_Payable__c =:selPay[1].Id];
            TransactionActions.isPreventDeleteOverride = true;
            delete transactionList;

            Test.startTest();
            //Run batch job to delete PayableLine Records.
            AbstractArchiveDeleteBatch.executeBatchChain(new AbstractArchiveDeleteBatch.ArchiveDeleteChainController(testData.acctPeriods[0].Id), null);
            Test.stopTest();
            
            //Make sure PayableLine Records deleted.
            System.assertEquals(
                9, [
                    SELECT Id FROM Account_Payable_Line__c 
                ].size() 
            );      
        }
    }
}