@IsTest
private class TimeCardPostBatchTest {
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testBatchPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createTimeCards();

        System.runAs(testData.users[1]) {
            
            //Make sure that TC was approved
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, [
                    SELECT Id, Status__c FROM Time_Card__c WHERE Id = :testData.timeCards[0].Id
                ].Status__c
            );
            Test.startTest();
            //Run batch job to post TC with "Approved" Posting Status
            TimeCardPostBatch batchInstance = new TimeCardPostBatch(
                new SourceRecordPostBatchChainController(new List<String>{'Time Cards'}),
                new List<AbstractSourceRecordPostBatch.ScheduledPostExecutionReport>()
            );
            Database.executeBatch(batchInstance);
            Test.stopTest();
            //Make sure that TC has been posted successfully
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, [
                    SELECT Id, Status__c FROM Time_Card__c WHERE Id = :testData.timeCards[0].Id
                ].Status__c
            );

            Automated_Job_Results__c ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals('Scheduled Post', ajr.Schedule_Job_Type__c);
            System.assertEquals(2, ajr.Processed__c);
            System.assertEquals(2, ajr.Succeeded__c);
            System.assertEquals(0, ajr.Failed__c);
        }
    }

    @IsTest
    static void testBatchPostOnlyActualTCs() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createTimeCards();

        System.runAs(testData.users[1]) {
            //Create "Budget Time Card"
            Time_Card__c budgetTimeCard = new Time_Card__c();
            budgetTimeCard.Time_Card_Period__c = testData.periods[0].Id;
            budgetTimeCard.Employee__c = testData.users[0].Id;
            budgetTimeCard.Ledger__c = testData.ledgers[0].Id;
            budgetTimeCard.Type__c = TimeCardActions.TYPE_VALUE_BUDGET;
            insert budgetTimeCard;
            //Make sure that TCs were approved initially
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, [
                    SELECT Id, Status__c FROM Time_Card__c WHERE Id = :testData.timeCards[0].Id
                ].Status__c
            );
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, [
                    SELECT Id, Status__c FROM Time_Card__c WHERE Id = :budgetTimeCard.Id
                ].Status__c
            );

            Test.startTest();
            //Run batch job to post TC with "Approved" Posting Status
            TimeCardPostBatch batchInstance = new TimeCardPostBatch(
                new SourceRecordPostBatchChainController(new List<String>{'Time Cards'}),
                new List<AbstractSourceRecordPostBatch.ScheduledPostExecutionReport>()
            );
            Database.executeBatch(batchInstance);
            Test.stopTest();
            //Make sure that TC has been posted successfully
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, [
                    SELECT Id, Status__c FROM Time_Card__c WHERE Id = :testData.timeCards[0].Id
                ].Status__c
            );
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, [
                    SELECT Id, Status__c FROM Time_Card__c WHERE Id = :budgetTimeCard.Id
                ].Status__c
            );
        }
    }

}