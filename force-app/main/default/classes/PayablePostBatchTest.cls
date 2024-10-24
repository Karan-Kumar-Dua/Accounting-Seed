@IsTest
private class PayablePostBatchTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testBatchPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users[1]) {
            //Make sure that Payable was approved
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, [
                    SELECT Id, Status__c FROM Account_Payable__c WHERE Id = :testData.payables[0].Id
                ].Status__c
            );
            Test.startTest();
            //Run batch job to post Payable with "Approved" Posting Status
            PayablePostBatch batchInstance = new PayablePostBatch(
                new SourceRecordPostBatchChainController(new List<String>{'Payables'}),
                new List<AbstractSourceRecordPostBatch.ScheduledPostExecutionReport>()
            );
            Database.executeBatch(batchInstance);
            Test.stopTest();
            //Make sure that Payable has been posted successfully
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, [
                    SELECT Id, Status__c FROM Account_Payable__c WHERE Id = :testData.payables[0].Id
                ].Status__c
            );

            Automated_Job_Results__c ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals('Scheduled Post', ajr.Schedule_Job_Type__c);
            System.assertEquals(8, ajr.Processed__c);
            System.assertEquals(8, ajr.Succeeded__c);
            System.assertEquals(0, ajr.Failed__c);
        }
    }

    @IsTest
    static void testBatchPostFailure() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users[1]) {
            //Make sure that Payable was approved
            System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, testData.payables[0].Status__c);

            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
            testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            AccountingPeriodActions.isFirstRun = false;
            update testAccountingPeriod;
            AccountingPeriodActions.isFirstRun = true;

            Test.startTest();
            //Run batch job to post Payable with "Approved" Posting Status
            PayablePostBatch batchInstance = new PayablePostBatch(
                new SourceRecordPostBatchChainController(new List<String>{'Payables'}),
                new List<AbstractSourceRecordPostBatch.ScheduledPostExecutionReport>()
            );
            Database.executeBatch(batchInstance);
            Test.stopTest();
            //Make sure that Payable has not been posted successfully and related task has been created
            List<Task> tasks = [SELECT Id, Description, Status FROM Task WHERE WhatId = :testData.payables[0].Id];
            System.assertNotEquals(true, tasks.isEmpty());
            System.assertEquals(AbstractPostHandler.ACCOUNTING_PERIOD_CLOSED_ERROR_MESSAGE, tasks[0].Description);
            for(Task t : tasks){
                System.AssertEquals('Completed', t.Status);
            }

            Automated_Job_Results__c ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals('Scheduled Post', ajr.Schedule_Job_Type__c);
            System.assertEquals(8, ajr.Processed__c);
            System.assertEquals(3, ajr.Succeeded__c);
            System.assertEquals(5, ajr.Failed__c);
        }
    }

}