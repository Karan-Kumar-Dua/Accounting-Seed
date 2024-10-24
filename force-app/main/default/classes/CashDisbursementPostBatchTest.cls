@IsTest
private class CashDisbursementPostBatchTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testBatchPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            //make sure that Posting Status is equal to "Approved" after CD creation
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, [
                    SELECT Id, Status__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[0].Id
                ].Status__c
            );

            Test.startTest();
            //Run batch job to post CD with "Approved" Posting Status
            CashDisbursementPostBatch batchInstance = new CashDisbursementPostBatch(
                new SourceRecordPostBatchChainController(new List<String>{'Cash Disbursements'}),
                new List<AbstractSourceRecordPostBatch.ScheduledPostExecutionReport>()
            );
            Database.executeBatch(batchInstance);
            Test.stopTest();
            //Make sure that CD has been posted successfully
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, [
                    SELECT Id, Status__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[0].Id
                ].Status__c
            );

            Automated_Job_Results__c ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals('Scheduled Post', ajr.Schedule_Job_Type__c);
            System.assertEquals(testData.cashDisbursements.size(), ajr.Processed__c);
            System.assertEquals(testData.cashDisbursements.size(), ajr.Succeeded__c);
            System.assertEquals(0, ajr.Failed__c);
        }
    }

    @IsTest
    static void testBatchPostListOfRecordIDsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            //make sure that Posting Status is equal to "Approved" after CD creation
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, [
                    SELECT Id, Status__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[0].Id
                ].Status__c
            );

            List<String> cashDisbursementIDs = new List<String>();
            for (Cash_Disbursement__c CD : testData.cashDisbursements) {
                cashDisbursementIDs.add(CD.Id);
            }

            Test.startTest();
            //Run batch job to post CD with "Approved" Posting Status
            CashDisbursementPostBatch batchInstance = new CashDisbursementPostBatch(
                cashDisbursementIDs, PostResultDispatcher.ExecutionContext.POST
            );
            Database.executeBatch(batchInstance);
            Test.stopTest();
            //Make sure that CD has been posted successfully
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, [
                    SELECT Id, Status__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[0].Id
                ].Status__c
            );

            Automated_Job_Results__c ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals('Async Post or Unpost', ajr.Schedule_Job_Type__c);
            System.assertEquals(testData.cashDisbursements.size(), ajr.Processed__c);
            System.assertEquals(testData.cashDisbursements.size(), ajr.Succeeded__c);
            System.assertEquals(0, ajr.Failed__c);
        }
    }

    @IsTest
    static void testBatchPostFailure() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            //make sure that Posting Status is equal to "Approved" after CD creation
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, [
                    SELECT Id, Status__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[0].Id
                ].Status__c
            );

            //enable Cash Flow Statement to fire validation error during posting
            testData.createCashFlowCategories(true);

            Test.startTest();
            //Run batch job to post CD with "Approved" Posting Status
            CashDisbursementPostBatch batchInstance = new CashDisbursementPostBatch(
                new SourceRecordPostBatchChainController(new List<String>{'Cash Disbursements'}),
                new List<AbstractSourceRecordPostBatch.ScheduledPostExecutionReport>()
            );
            Database.executeBatch(batchInstance);
            Test.stopTest();
            //Make sure that CDs have not been posted successfully and related tasks have been created
            List<Task> tasks = [SELECT Id, Description, Status FROM Task WHERE WhatId = :testData.cashDisbursements[0].Id];
            System.assertNotEquals(true, tasks.isEmpty());
            System.assertEquals(AbstractPostHandler.NO_CASH_FLOW_CATEGORY_HELP_TEXT, tasks[0].Description);
            for (Task t : tasks) {
                System.AssertEquals('Completed', t.Status);
            }

            Automated_Job_Results__c ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals('Scheduled Post', ajr.Schedule_Job_Type__c);
            System.assertEquals(testData.cashDisbursements.size(), ajr.Processed__c);
            System.assertEquals(0, ajr.Succeeded__c);
            System.assertEquals(testData.cashDisbursements.size(), ajr.Failed__c);
        }
    }

}