@IsTest
private class APDisbursementPostBatchTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testBatchPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements();

        System.runAs(testData.users[1]) {
            //Turn off auto posting of APDs
            testData.disableAutoPostSourceDocuments();
            //create new APD record (will not be auto posted on creation)
            AP_Disbursement__c testAPD = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[0].Id,
                Cash_Disbursement__c = testData.cashDisbursements[5].Id,
                Paid_Amount__c = 10
            );
            insert testAPD;
            
            //make sure that Posting Status is equal to "Approved" after APD creation
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, [
                    SELECT Id, Status__c FROM AP_Disbursement__c WHERE Id = :testAPD.Id
                ].Status__c
            );

            //Run batch job to post APDs with "Approved" Posting Status
            APDisbursementPostBatch batchInstance = new APDisbursementPostBatch(
                new SourceRecordPostBatchChainController(new List<String>{'AP Disbursements'}),
                new List<AbstractSourceRecordPostBatch.ScheduledPostExecutionReport>()
            );
            Database.executeBatch(batchInstance);
            Test.stopTest();
            //Make sure that APD has been posted successfully
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, [
                    SELECT Id, Status__c FROM AP_Disbursement__c WHERE Id = :testAPD.Id
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
    private static void testBatchPostLegacySuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements();

        System.runAs(testData.users[1]) {
            //Turn off auto posting of APDs
            testData.disableAutoPostSourceDocuments();

            //create new APD record (will not be auto posted on creation)
            AP_Disbursement__c testAPD = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[0].Id,
                Cash_Disbursement__c = testData.cashDisbursements[5].Id,
                Paid_Amount__c = 10
            );
            insert testAPD;
            //make sure that Posting Status is equal to "Approved" after APD creation
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, [
                    SELECT Id, Status__c FROM AP_Disbursement__c WHERE Id = :testAPD.Id
                ].Status__c
            );

            Transaction__c trans = new Transaction__c(
                AP_Disbursement__c = testAPD.Id,
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Date__c = testData.acctPeriods[1].Start_Date__c,
                Ledger__c = testData.ledgers[0].Id,
                GL_Account__c = testData.glAccounts[0].Id,
                Amount__c = testAPD.Paid_Amount__c
            );
            TransactionActions.createTransactions(new List<Transaction__c>{trans});

            
            //Run batch job to post APDs with "Approved" Posting Status
            APDisbursementPostBatch batchInstance = new APDisbursementPostBatch(
                new SourceRecordPostBatchChainController(new List<String>{'AP Disbursements'}),
                new List<AbstractSourceRecordPostBatch.ScheduledPostExecutionReport>()
            );
            Database.executeBatch(batchInstance);
            Test.stopTest();
            
            //Make sure that APD has been posted successfully
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, [
                    SELECT Id, Status__c FROM AP_Disbursement__c WHERE Id = :testAPD.Id
                ].Status__c
            );
            //make sure existed Transaction is still in place -> means only the Posting Status of the record has been changed
            System.assertNotEquals(true, DomainUtils.getTransactionsByApd(new List<AP_Disbursement__c>{testAPD}).isEmpty());
        }
    }

    @IsTest
    private static void testBatchPostFilterOutNotValidForPosting() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();

        System.runAs(testData.users[1]) {
            Test.startTest();
            //create new CD record equal to CD created from Payable Pay screen
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers[0].Id);
            Cash_Disbursement__c testCD = new Cash_Disbursement__c(
                Cash_Disbursement_Batch__c = testData.cashDisbursementBatch[1].Id,
                Disbursement_Date__c = testData.acctPeriods[0].Start_Date__c,
                Type__c = 'Check',
                Amount__c = 40,
                Source__c = 'Payable',
                Bank_Account__c = testData.glAccounts[0].Id,
                Debit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Vendor__c = testData.accounts[0].Id,
                Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                Reference__c = 'uniq ref'
            );
            CashDisbursementActions.isSourcedFromPayables = true;
            insert testCD;
            CashDisbursementActions.isSourcedFromPayables = false;

            //create new APD record equal to APD created from Payable Pay screen
            AP_Disbursement__c testAPD = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[0].Id,
                Cash_Disbursement__c = testCD.Id,
                Paid_Amount__c = 10
            );
            insert testAPD;

            //make sure that Posting Status is equal to "Approved" after APD creation
            //It's expected because the APD record is not valid for posting and must not be posted by trigger after creation
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, [
                    SELECT Id, Status__c FROM AP_Disbursement__c WHERE Id = :testAPD.Id
                ].Status__c
            );

            //Run batch job to post valid for posting APDs with "Approved" Posting Status
            APDisbursementPostBatch batchInstance = new APDisbursementPostBatch(
                new SourceRecordPostBatchChainController(new List<String>{'AP Disbursements'}),
                new List<AbstractSourceRecordPostBatch.ScheduledPostExecutionReport>()
            );
            Database.executeBatch(batchInstance);
            Test.stopTest();
            //Make sure that APD has not been posted
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, [
                    SELECT Id, Status__c FROM AP_Disbursement__c WHERE Id = :testAPD.Id
                ].Status__c
            );
        }
    }

    @IsTest
    private static void testBatchPostAPDWhenPeriodIsAlreadyClosed() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            //Turn off auto posting of APDs
            testData.disableAutoPostSourceDocuments();
            testData.cashDisbursements[5].Accounting_Period__c = testData.acctPeriods[0].Id;
            update testData.cashDisbursements[5];

            List<AP_Disbursement__c> testAPDs = new List<AP_Disbursement__c>();
            AP_Disbursement__c testAPDForClosedPeriod = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[0].Id,
                Cash_Disbursement__c = testData.cashDisbursements[5].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Paid_Amount__c = 5
            );
            testAPDs.add(testAPDForClosedPeriod);

            AP_Disbursement__c testAPDForOpenPeriod = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[0].Id,
                Cash_Disbursement__c = testData.cashDisbursements[5].Id,
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Paid_Amount__c = 5
            );
            testAPDs.add(testAPDForOpenPeriod);
            insert testAPDs;

            testAPDs = [SELECT Id, Status__c FROM AP_Disbursement__c];
            System.assertEquals(2, testAPDs.size());
            //make sure that Posting Status is equal to "Approved" after APDs creation
            System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, testAPDs[0].Status__c);
            System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, testAPDs[1].Status__c);

            //Close first accounting period
            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];

            //Run batch job to post valid for posting APDs with "Approved" Posting Status
            APDisbursementPostBatch batchInstance = new APDisbursementPostBatch(
                new SourceRecordPostBatchChainController(new List<String>{'AP Disbursements'}),
                new List<AbstractSourceRecordPostBatch.ScheduledPostExecutionReport>()
            );
            Database.executeBatch(batchInstance);
            Test.stopTest();
            //Make sure that APD has been posted
            testAPDs = [SELECT Id, Status__c FROM AP_Disbursement__c];
            System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, testAPDs[0].Status__c);
            System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, testAPDs[1].Status__c);
            //Make sure that Task was created for APD related to the Closed Period
            List<Task> tasks = [SELECT Id, WhatId, Description, Status FROM Task WHERE WhatId = :testAPDs[0].Id];
            System.assertEquals(false, tasks.isEmpty());
            System.assertEquals(AbstractPostHandler.ACCOUNTING_PERIOD_CLOSED_ERROR_MESSAGE, tasks[0].Description);
            for(Task t : tasks){
                System.AssertEquals('Completed', t.Status);
            }
        }
    }

}