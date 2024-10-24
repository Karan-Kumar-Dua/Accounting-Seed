@IsTest
private class CashReceiptPostBatchTest {
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testBatchPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            //Turn off auto posting of CRs
            testData.disableAutoPostSourceDocuments();
            //create CRs
            testData.createCashReceipts();

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, [
                    SELECT Id, Status__c FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].id
                ].Status__c
            );
            Test.startTest();
            //Run batch job to post CR with "Approved" Posting Status
            CashReceiptPostBatch batchInstance = new CashReceiptPostBatch(
                new SourceRecordPostBatchChainController(new List<String>{'Cash Receipts'}),
                new List<AbstractSourceRecordPostBatch.ScheduledPostExecutionReport>()
            );
            Database.executeBatch(batchInstance);
            Test.stopTest();
            //Make sure that CR has been posted successfully
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, [
                    SELECT Id, Status__c FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].id
                ].Status__c
            );

            Automated_Job_Results__c ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals('Scheduled Post', ajr.Schedule_Job_Type__c);
            System.assertEquals(3, ajr.Processed__c);
            System.assertEquals(3, ajr.Succeeded__c);
            System.assertEquals(0, ajr.Failed__c);
        }
    }

    @IsTest
    static void testBatchPostFailure() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            //Turn off auto posting of CRs
            testData.disableAutoPostSourceDocuments();
            //create CRs
            testData.createCashReceipts();

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, [
                    SELECT Id, Status__c FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id
                ].Status__c
            );
            //enable Cash Flow Statement to fire validation error during posting
            testData.createCashFlowCategories(true);

            Test.startTest();
            //Run batch job to post CR with "Approved" Posting Status
            CashReceiptPostBatch batchInstance = new CashReceiptPostBatch(
                new SourceRecordPostBatchChainController(new List<String>{'Cash Receipts'}),
                new List<AbstractSourceRecordPostBatch.ScheduledPostExecutionReport>()
            );
            Database.executeBatch(batchInstance);
            Test.stopTest();
            //Make sure that CRs have not been posted successfully and related tasks have been created
            List<Task> tasks = [SELECT Id, Status FROM Task WHERE WhatId IN :testData.cashReceipts];
            System.assertNotEquals(true, tasks.isEmpty());
            System.assertEquals(testData.cashReceipts.size(), tasks.size());
            for(Task t : tasks){
                System.AssertEquals('Completed', t.Status);
            }

            Automated_Job_Results__c ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals('Scheduled Post', ajr.Schedule_Job_Type__c);
            System.assertEquals(3, ajr.Processed__c);
            System.assertEquals(0, ajr.Succeeded__c);
            System.assertEquals(3, ajr.Failed__c);
        }
    }

}