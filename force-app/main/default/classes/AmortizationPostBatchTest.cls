@IsTest
private class AmortizationPostBatchTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testBatchPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            //Turn off auto posting of Amortizations
            testData.disableAutoPostSourceDocuments();

            //Create test Amortization record
            Scheduled_Revenue_Expense__c testAmortization = new Scheduled_Revenue_Expense__c(
                Name = 'Test Rev 1',
                Amount__c = 400,
                Credit_GL_Account__c = testData.glAccounts[6].Id,
                Debit_GL_Account__c = testData.glAccounts[16].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Status__c = 'Approved'
            );
            insert testAmortization;

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, [
                    SELECT Id, Status__c FROM Scheduled_Revenue_Expense__c WHERE Id = :testAmortization.Id
                ].Status__c
            );

            Test.startTest();
            //Run batch job to post Amortization with "Approved" Posting Status
            AmortizationPostBatch batchInstance = new AmortizationPostBatch(
                new SourceRecordPostBatchChainController(new List<String>{'Amortization Entries'}),
                new List<AbstractSourceRecordPostBatch.ScheduledPostExecutionReport>()
            );
            Database.executeBatch(batchInstance);
            Test.stopTest();
            //Make sure that Amortization has been posted successfully
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, [
                    SELECT Id, Status__c FROM Scheduled_Revenue_Expense__c WHERE Id = :testAmortization.Id
                ].Status__c
            );

            Automated_Job_Results__c ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals('Scheduled Post', ajr.Schedule_Job_Type__c);
            System.assertEquals(1, ajr.Processed__c);
            System.assertEquals(1, ajr.Succeeded__c);
            System.assertEquals(0, ajr.Failed__c);
        }
    }

}