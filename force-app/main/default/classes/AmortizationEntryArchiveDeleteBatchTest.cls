@IsTest
private class AmortizationEntryArchiveDeleteBatchTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    
    @IsTest
    private static void testAmortizationEntryJob() {
        TestDataSuite testData = TestDataSuite.getInstance().disableAutoPostSourceDocuments();

        System.runAs(testData.users[1]) {
            Scheduled_Revenue_Expense__c testAmortization = new Scheduled_Revenue_Expense__c(
                Name = 'Test Rev 1',
                Amount__c = 400,
                Credit_GL_Account__c = testData.glAccounts[6].Id,
                Debit_GL_Account__c = testData.glAccounts[16].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Status__c = 'Approved'
            );
            insert testAmortization;

            Scheduled_Revenue_Expense__c testAmortization2 = new Scheduled_Revenue_Expense__c(
                Name = 'Test Rev 2',
                Amount__c = 400,
                Credit_GL_Account__c = testData.glAccounts[6].Id,
                Debit_GL_Account__c = testData.glAccounts[16].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Status__c = 'Approved'
            );
            insert testAmortization2;

            //Check BankTransaction Records
            System.assertEquals(
                2, [
                    SELECT Id FROM Scheduled_Revenue_Expense__c
                ].size()
            );

            AmortizationPostService.postAmortizationEntries(new List<Scheduled_Revenue_Expense__c>{testAmortization});
            Test.startTest();

            List<Transaction__c> transactionList = [SELECT Id FROM Transaction__c WHERE Scheduled_Revenue_Expense__c =:testAmortization.Id];
            TransactionActions.isPreventDeleteOverride = true;
            delete transactionList;

            //Run batch job to delete AmortizationEntry Records.
            AbstractArchiveDeleteBatch.executeBatchChain(new AbstractArchiveDeleteBatch.ArchiveDeleteChainController(testData.acctPeriods[0].Id), null);
            Test.stopTest();

            //Make sure only Posted AmortizationEntry Records deleted.
            System.assertEquals(
                1, [
                    SELECT Id FROM Scheduled_Revenue_Expense__c
                ].size()
            );
        }
    }
}