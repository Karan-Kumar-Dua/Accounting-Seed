@IsTest
private class JournalEntryPostBatchTest {
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testBatchPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDeposits()
            .createCashReceipts()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users[1]) {
            
            //Make sure that JE was approved
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, [
                    SELECT Id, Status__c FROM Journal_Entry__c WHERE Id = :testData.journalEntries[0].id
                ].Status__c
            );
            Test.startTest();
            //Run batch job to post JE with "Approved" Posting Status
            JournalEntryPostBatch batchInstance = new JournalEntryPostBatch(
                new SourceRecordPostBatchChainController(new List<String>{'Journal Entries'}),
                new List<AbstractSourceRecordPostBatch.ScheduledPostExecutionReport>()
            );
            Database.executeBatch(batchInstance);
            Test.stopTest();
            //Make sure that JE has been posted successfully
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, [
                    SELECT Id, Status__c FROM Journal_Entry__c WHERE Id = :testData.journalEntries[0].id
                ].Status__c
            );

            Automated_Job_Results__c ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals('Scheduled Post', ajr.Schedule_Job_Type__c);
            System.assertEquals(3, ajr.Processed__c);
            System.assertEquals(3, ajr.Succeeded__c);
            System.assertEquals(0, ajr.Failed__c);
        }
    }
}