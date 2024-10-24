@IsTest
private class PayableArchiveDeleteBatchTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    
    @IsTest
    private static void testPayablesJob() {
        TestDataSuite testData = TestDataSuite.getInstance().disableAutoPostSourceDocuments().createPayables();
        
        System.runAs(testData.users[1]) {
            //Check total Payables Records
            System.assertEquals(
                8, [
                    SELECT Id FROM Account_Payable__c
                ].size() 
            );

            List<Account_Payable__c> selPay = [SELECT Id FROM Account_Payable__c WHERE Accounting_Period__c = :testData.acctPeriods[0].Id];

            //Check total Payables Records related to Period[0];
            System.assertEquals(5, selPay.size());

            AccountPayablePostService.postAccountPayables(new List<Account_Payable__c> {selPay[0], selPay[1]});
            List<Transaction__c> transactionList = [SELECT Id FROM Transaction__c WHERE Account_Payable__c =:selPay[0].Id OR Account_Payable__c =:selPay[1].Id];
            TransactionActions.isPreventDeleteOverride = true;
            delete transactionList;
            
            Test.startTest();
            //Run batch job to delete only Posted Payables Records.
            AbstractArchiveDeleteBatch.executeBatchChain(new AbstractArchiveDeleteBatch.ArchiveDeleteChainController(testData.acctPeriods[0].Id), null);
            Test.stopTest();
            
            //Make sure Payables Records deleted.
            System.assertEquals(
                6, [
                    SELECT Id FROM Account_Payable__c 
                ].size() 
            );      
        }
    }
}