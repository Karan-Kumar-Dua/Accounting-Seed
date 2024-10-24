@IsTest
private class AbstractArchiveDeleteBatchTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testCreateAutomatedJobResult() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createPayables(true)
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            AbstractArchiveDeleteBatch.executeBatchChain(new AbstractArchiveDeleteBatch.ArchiveDeleteChainController(testData.acctPeriods[0].Id), null);
            Test.stopTest();

            Automated_Job_Results__c ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals('Delete Source Documents', ajr.Schedule_Job_Type__c);
            System.assertEquals(17, ajr.Processed__c);
            System.assertEquals(11, ajr.Succeeded__c);
            System.assertEquals(6, ajr.Failed__c);
        }
    }

    @isTest
    private static void testDeleteAllPreviousSource() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.createBillings(true);
            Billing__c newOne = testData.billings[0].clone(false, true);
            newOne.Accounting_Period__c = testData.acctPeriods[1].Id;
            insert newOne;

            Billing_Line__c newLine = testData.billingLines[0].clone(false, true);
            newLine.Billing__c = newOne.Id;
            insert newLine;

            BillingPostService.postBillings(new List<Billing__c> {newOne});

            System.assert(![SELECT Id FROM Account_Payable__c WHERE Accounting_Period__c = :testData.acctPeriods[0].Id].isEmpty());
            System.assert(![SELECT Id FROM Account_Payable__c WHERE Accounting_Period__c = :testData.acctPeriods[1].Id].isEmpty());
            System.assert(![SELECT Id FROM Billing__c WHERE Accounting_Period__c = :testData.acctPeriods[0].Id].isEmpty());
            System.assert(![SELECT Id FROM Billing__c WHERE Accounting_Period__c = :testData.acctPeriods[1].Id].isEmpty());

            List<Transaction__c> transactionList = [SELECT Id FROM Transaction__c WHERE Accounting_Period__c = :testData.acctPeriods[0].Id OR Accounting_Period__c = :testData.acctPeriods[1].Id];
            TransactionActions.isPreventDeleteOverride = true;
            delete transactionList;

            testData.acctPeriods[0].Status__c = AccountingPeriodActions.ARCHIVED_STATUS;
            testData.acctPeriods[0].Source_Docs_Deleted__c = true;
            AccountingPeriodActions.isDelarcInProgress = true;
            AccountingPeriodActions.isFirstRun = false;
            update testData.acctPeriods[0];
            AccountingPeriodActions.isFirstRun = true;
            AccountingPeriodActions.isDelarcInProgress = false;

            AbstractArchiveDeleteBatch.executeBatchChain(new AbstractArchiveDeleteBatch.ArchiveDeleteChainController(testData.acctPeriods[1].Id), null);
            Test.stopTest();

            System.assert([SELECT Id FROM Account_Payable__c WHERE Accounting_Period__c = :testData.acctPeriods[0].Id].isEmpty());
            System.assert([SELECT Id FROM Account_Payable__c WHERE Accounting_Period__c = :testData.acctPeriods[1].Id].isEmpty());
            System.assert([SELECT Id FROM Billing__c WHERE Accounting_Period__c = :testData.acctPeriods[0].Id].isEmpty());
            System.assert([SELECT Id FROM Billing__c WHERE Accounting_Period__c = :testData.acctPeriods[1].Id].isEmpty());
        }
    }

    @isTest
    private static void testCreateFailedActivityLog() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createPayables(true)
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            AbstractArchiveDeleteBatch.executeBatchChain(new AbstractArchiveDeleteBatch.ArchiveDeleteChainController(testData.acctPeriods[0].Id), null);
            Test.stopTest();

            List<Task> tasks = [SELECT Id, Subject, Description FROM Task];

            System.assertEquals(6, tasks.size());
        }
    }
}