@IsTest
private class BillingCashReceiptPostBatchTest {
     @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testBatchPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users[1]) {
            testData.disableAutoPostSourceDocuments();

            Billing_Cash_Receipt__c testBillingCR = new Billing_Cash_Receipt__c(
                Cash_Receipt__c = testData.cashReceipts[0].Id,
                Billing__c = testData.billings[0].Id,
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Applied_Amount__c = 12
            );
            insert testBillingCR;

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, [
                    SELECT Id, Status__c FROM Billing_Cash_Receipt__c WHERE Id = :testBillingCR.Id
                ].Status__c
            );

            BillingCashReceiptPostBatch batchInstance = new BillingCashReceiptPostBatch(
                new SourceRecordPostBatchChainController(new List<String>{'Billing Cash Receipts'}),
                new List<AbstractSourceRecordPostBatch.ScheduledPostExecutionReport>()
            );
            Database.executeBatch(batchInstance);
            Test.stopTest();
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, [
                    SELECT Id, Status__c FROM Billing_Cash_Receipt__c WHERE Id = :testBillingCR.Id
                ].Status__c
            );

            Automated_Job_Results__c ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals('Scheduled Post', ajr.Schedule_Job_Type__c);
            System.assertEquals(1, ajr.Processed__c);
            System.assertEquals(1, ajr.Succeeded__c);
            System.assertEquals(0, ajr.Failed__c);
        }
    }

    @IsTest
    static void testBatchPostLegacySuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users[1]) {
            testData.disableAutoPostSourceDocuments();

            Billing_Cash_Receipt__c testBillingCR = new Billing_Cash_Receipt__c(
                Cash_Receipt__c = testData.cashReceipts[0].Id,
                Billing__c = testData.billings[0].Id,
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Applied_Amount__c = 12
            );
            insert testBillingCR;

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, [
                    SELECT Id, Status__c FROM Billing_Cash_Receipt__c WHERE Id = :testBillingCR.Id
                ].Status__c
            );

            Transaction__c trans = new Transaction__c(
                Billing_Cash_Receipt__c = testBillingCR.Id,
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Date__c = testData.acctPeriods[1].Start_Date__c,
                Ledger__c = testData.ledgers[0].Id,
                GL_Account__c = testData.glAccounts[0].Id,
                Amount__c = testBillingCR.Applied_Amount__c
            );
            TransactionActions.createTransactions(new List<Transaction__c>{trans});

            BillingCashReceiptPostBatch batchInstance = new BillingCashReceiptPostBatch(
                new SourceRecordPostBatchChainController(new List<String>{'Billing Cash Receipts'}),
                new List<AbstractSourceRecordPostBatch.ScheduledPostExecutionReport>()
            );
            Database.executeBatch(batchInstance);
            Test.stopTest();
            //check Posting Status -> must be "Posted"
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, [
                    SELECT Id, Status__c FROM Billing_Cash_Receipt__c WHERE Id = :testBillingCR.Id
                ].Status__c
            );
            //make sure existed Transaction is still in place -> means only the Posting Status of the record has been changed
            System.assertNotEquals(true, DomainUtils.getTransactionsByBcr(new List<Billing_Cash_Receipt__c>{testBillingCR}).isEmpty());
        }
    }

    @IsTest
    static void testBatchPostFailure() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users[1]) {
            testData.disableAutoPostSourceDocuments();

            Billing_Cash_Receipt__c testBillingCR = new Billing_Cash_Receipt__c(
                Cash_Receipt__c = testData.cashReceipts[2].Id,
                Billing__c = testData.billings[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Applied_Amount__c = 12
            );
            insert testBillingCR;

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, [
                    SELECT Id, Status__c FROM Billing_Cash_Receipt__c WHERE Id = :testBillingCR.Id
                ].Status__c
            );

            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
            testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            AccountingPeriodActions.isFirstRun = false;
            update testAccountingPeriod;
            AccountingPeriodActions.isFirstRun = true;

            BillingCashReceiptPostBatch batchInstance = new BillingCashReceiptPostBatch(
                new SourceRecordPostBatchChainController(new List<String>{'Billing Cash Receipts'}),
                new List<AbstractSourceRecordPostBatch.ScheduledPostExecutionReport>()
            );
            Database.executeBatch(batchInstance);
            Test.stopTest();
            //Make sure that Billing has not been posted successfully and related task has been created
            List<Task> tasks = [SELECT Id, Description, Status FROM Task WHERE WhatId = :testBillingCR.Id];
            System.assertNotEquals(true, tasks.isEmpty());
            System.assertEquals(AbstractPostHandler.ACCOUNTING_PERIOD_CLOSED_ERROR_MESSAGE, tasks[0].Description);
            for(Task t : tasks){
                System.AssertEquals('Completed', t.Status);
            }

            Automated_Job_Results__c ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals('Scheduled Post', ajr.Schedule_Job_Type__c);
            System.assertEquals(1, ajr.Processed__c);
            System.assertEquals(0, ajr.Succeeded__c);
            System.assertEquals(1, ajr.Failed__c);
        }
    }

}