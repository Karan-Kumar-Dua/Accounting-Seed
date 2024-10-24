@IsTest
public class ScheduledRevenueExpensePostHandlerTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testPurgeUnlockedPostingStatusFieldOnly() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {

            //Put some field into set of unlocked fields just to check it later
            TriggerObserver.getInstance().unlockField(Account.GL_Account_Variable_1__c);
            //create and post records
            testData.createScheduledRevenueExpense();
            //Validate that Posting Status field was removed from the set of unlocked fields after the end of posting routine
            System.assertEquals(false, TriggerObserver.getInstance().isUnlockedField(Scheduled_Revenue_Expense__c.Status__c));
            //Validate that originally unlocked field is still unlocked
            System.assertEquals(true, TriggerObserver.getInstance().isUnlockedField(Account.GL_Account_Variable_1__c));
        }
    }

    @IsTest
    public static void testPartialPosting() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            Scheduled_Revenue_Expense__c testSRE = testData.scheduledRevenues[0];

            Scheduled_Revenue_Expense__c newTestSRE = new Scheduled_Revenue_Expense__c(
                Name = 'Test Rev 5',
                Amount__c = 200,
                Credit_GL_Account__c = testData.glAccounts[11].Id,
                Debit_GL_Account__c = testData.glAccounts[16].Id,
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Status__c = 'Scheduled'
            ); 

            insert newTestSRE;

            AbstractPostHandler postHandler = new ScheduledRevenueExpensePostHandler();
            List<PostResult> results = postHandler.unpost(new List<Scheduled_Revenue_Expense__c>{testSRE, newTestSRE});

            System.assertEquals(true, results[0].isSuccess);
            System.assertEquals(true, results[1].isSuccess);

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];

            Test.startTest();
            postHandler.dispatcher.clearResultsMap();
            results = postHandler.post(new List<Scheduled_Revenue_Expense__c>{testSRE, newTestSRE});
            Test.stopTest();

            System.assertEquals(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD, results[0].errors[0].statusCode);
            System.assertEquals(
                1, [
                SELECT count()
                FROM Scheduled_Revenue_Expense__c
                WHERE Status__c = 'Posted'
                AND (Id = :testSRE.Id OR Id = :newTestSRE.Id)
            ]);
        }

    }

    @IsTest
    public static void testScheduledRevenueExpensePostClosedPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            Scheduled_Revenue_Expense__c testSRE = testData.scheduledRevenues[0];

            AbstractPostHandler postHandler = new ScheduledRevenueExpensePostHandler();
            List<PostResult> results = postHandler.unpost(new List<Scheduled_Revenue_Expense__c>{testSRE});

            System.assertEquals(true, results[0].isSuccess);

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];

            Test.startTest();
            postHandler.dispatcher.clearResultsMap();
            results = postHandler.post(new List<Scheduled_Revenue_Expense__c>{testSRE});
            Test.stopTest();

            System.assertEquals(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testScheduledRevenueExpensePostAlreadyPostedError() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            AbstractPostHandler postHandler = new ScheduledRevenueExpensePostHandler();
            List<PostResult> results = postHandler.post(testData.scheduledRevenues);
            Test.stopTest();

            System.assertEquals(PostResult.StatusCode.ALREADY_POSTED, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testScheduledRevenueExpensePostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Scheduled_Revenue_Expense__c testSRE = testData.scheduledRevenues[0];
            AbstractPostHandler postHandler = new ScheduledRevenueExpensePostHandler();
            List<PostResult> results = postHandler.unpost(new List<Scheduled_Revenue_Expense__c>{testSRE});
            System.assertEquals(true, results[0].isSuccess);

            postHandler.dispatcher.clearResultsMap();
            results = postHandler.post(new List<Scheduled_Revenue_Expense__c>{testSRE});

            List<Transaction__c> newTransactions = [
                SELECT Id, Accounting_Period__c, Date__c, Amount__c
                FROM Transaction__c
                WHERE Scheduled_Revenue_Expense__c = :testSRE.Id
            ];

            System.assertEquals(false, newTransactions.isEmpty());
            System.assertEquals(2, newTransactions.size());
            System.assertEquals(
                'Posted',
                [SELECT Status__c FROM Scheduled_Revenue_Expense__c WHERE Id = :testSRE.Id].Status__c
            );
            System.assertEquals(0, newTransactions[0].Amount__c + newTransactions[1].Amount__c);

            //Check Date field
            AccountingPeriodHandler.reset();
            Accounting_Period__c transactionPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodById(newTransactions[0].Accounting_Period__c);

            System.assertEquals(transactionPeriod.Start_Date__c, newTransactions[0].Date__c);
        }

    }

    @IsTest
    public static void testScheduledRevenueExpenseUnpostClosedPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            Scheduled_Revenue_Expense__c testSRE = testData.scheduledRevenues[0];

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];

            Test.startTest();
            AbstractPostHandler postHandler = new ScheduledRevenueExpensePostHandler();
            List<PostResult> results = postHandler.unpost(new List<Scheduled_Revenue_Expense__c>{testSRE});
            Test.stopTest();

            System.assertEquals(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testScheduledRevenueExpenseUnpostAlreadyUnposted() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            Scheduled_Revenue_Expense__c testSRE = testData.scheduledRevenues[0];

            AbstractPostHandler postHandler = new ScheduledRevenueExpensePostHandler();
            List<PostResult> results = postHandler.unpost(new List<Scheduled_Revenue_Expense__c>{testSRE});

            System.assertEquals(true, results[0].isSuccess);

            System.assertNotEquals('Posted', [SELECT Status__c From Scheduled_Revenue_Expense__c WHERE Id = :testSRE.Id].Status__c);

            Test.startTest();
            postHandler.dispatcher.clearResultsMap();
            results = postHandler.unpost(new List<Scheduled_Revenue_Expense__c>{testSRE});
            Test.stopTest();

            System.assertEquals(false, results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.ALREADY_UNPOSTED, results[0].errors[0].statusCode);
            System.assertEquals(
                'Approved', [
                    SELECT Status__c
                    FROM Scheduled_Revenue_Expense__c
                    WHERE Id = :testSRE.Id
                ].Status__c
            );
        }

    }

    @IsTest
    public static void testScheduledRevenueExpenseUnpostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            Scheduled_Revenue_Expense__c testSRE = testData.scheduledRevenues[0];

            AbstractPostHandler postHandler = new ScheduledRevenueExpensePostHandler();
            List<PostResult> results = postHandler.unpost(new List<Scheduled_Revenue_Expense__c>{testSRE});

            System.assertEquals(true, results[0].isSuccess);

            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Scheduled_Revenue_Expense__c = :testSRE.Id]);
            System.assertNotEquals('Posted', [SELECT Status__c FROM Scheduled_Revenue_Expense__c WHERE Id = :testSRE.Id].Status__c);
        }

    }

    @IsTest
    public static void testScheduledRevenueExpensePostBatchNoSelectionClosedPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.scheduledRevenues);
            setController.setSelected(setController.getRecords());

            AbstractPostHandler postHandler = new ScheduledRevenueExpensePostHandler();
            List<PostResult> results = postHandler.unpost(testData.scheduledRevenues);

            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Scheduled_Revenue_Expense__c IN :testData.scheduledRevenues]);
            System.assertEquals('Approved', [SELECT Status__c FROM Scheduled_Revenue_Expense__c WHERE Id = :testData.scheduledRevenues[0].Id].Status__c);

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];

            Test.startTest();
            postHandler.dispatcher.clearResultsMap();
            results = postHandler.post(testData.scheduledRevenues);
            Test.stopTest();

            System.assertEquals(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testScheduledRevenueExpensePostBacthNoSelectionError() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            AbstractPostHandler postHandler = new ScheduledRevenueExpensePostHandler();
            List<PostResult> results = postHandler.post(testData.scheduledRevenues);
            Test.stopTest();

            System.assertEquals(PostResult.StatusCode.ALREADY_POSTED, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testScheduledRevenueExpenseUnpostBatchNoSelectionClosedPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];

            Test.startTest();
            AbstractPostHandler postHandler = new ScheduledRevenueExpensePostHandler();
            List<PostResult> results = postHandler.unpost(testData.scheduledRevenues);
            Test.stopTest();

            System.assertEquals(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testScheduledRevenueExpenseUnpostBatchNoSelectionError() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            AbstractPostHandler postHandler = new ScheduledRevenueExpensePostHandler();
            List<PostResult> results = postHandler.unpost(testData.scheduledRevenues);
            Test.stopTest();
            System.assertEquals(true, results[0].isSuccess);
        }

    }

    @IsTest
    public static void testScheduledRevenueExpensePostBatchTransaction() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            AbstractPostHandler postHandler = new ScheduledRevenueExpensePostHandler();
            List<PostResult> results = postHandler.unpost(testData.scheduledRevenues);

            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Scheduled_Revenue_Expense__c IN :testData.scheduledRevenues]);
            System.assertEquals('Approved', [SELECT Status__c FROM Scheduled_Revenue_Expense__c WHERE Id = :testData.scheduledRevenues[0].Id].Status__c);

            postHandler.dispatcher.clearResultsMap();
            results = postHandler.post(testData.scheduledRevenues);
            Test.stopTest();

            System.assertEquals(4, [SELECT count() FROM Transaction__c WHERE Scheduled_Revenue_Expense__c IN :testData.scheduledRevenues]);
            System.assertEquals('Posted', [SELECT Status__c FROM Scheduled_Revenue_Expense__c WHERE Id = :testData.scheduledRevenues[0].Id].Status__c);
            System.assertEquals(0, [SELECT SUM(Amount__c) sum FROM Transaction__c WHERE Scheduled_Revenue_Expense__c = :testData.scheduledRevenues[0].Id GROUP BY Scheduled_Revenue_Expense__c][0].get('sum'));
        }

    }

    @IsTest
    public static void testScheduledRevenueExpensePostInsert() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            // Test post functionality
            System.assertEquals(4, [SELECT count() FROM Transaction__c WHERE Scheduled_Revenue_Expense__c In :testData.scheduledRevenues]);
            System.assertEquals('Posted', [SELECT Status__c FROM Scheduled_Revenue_Expense__c WHERE Id = :testData.scheduledRevenues[0].Id].Status__c);
            System.assertEquals(0, [SELECT SUM(Amount__c) sum FROM Transaction__c WHERE Scheduled_Revenue_Expense__c = :testData.scheduledRevenues[0].Id GROUP BY Scheduled_Revenue_Expense__c][0].get('sum'));
        }
    }

    @IsTest
    public static void testCashBasisPostBothLedgerSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Scheduled_Revenue_Expense__c ae = testData.scheduledRevenues[0].clone();
            ae.Ledger__c = testData.ledgers[4].Id;
            ae.Status__c = 'Approved';
            ae.Accrual_and_or_Cash__c = 'Accrual and Cash';
            insert ae;
            System.assertEquals(4, [SELECT Id FROM Transaction__c WHERE Scheduled_Revenue_Expense__c = :ae.Id].size());
        }
    }

    @IsTest
    public static void testCashBasisPostAccrualLedgerSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Scheduled_Revenue_Expense__c ae = testData.scheduledRevenues[0].clone();
            ae.Ledger__c = testData.ledgers[4].Id;
            ae.Status__c = 'Approved';
            ae.Accrual_and_or_Cash__c = 'Accrual';
            insert ae;

            List<Transaction__c> res = [SELECT Id, Ledger__c FROM Transaction__c WHERE Scheduled_Revenue_Expense__c = :ae.Id];
            System.assertEquals(2, res.size());
            System.assertEquals(testData.ledgers[4].Id, res[0].Ledger__c);
            System.assertEquals(testData.ledgers[4].Id, res[1].Ledger__c);
        }
    }

    @IsTest
    public static void testCashBasisPostCashLedgerSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Scheduled_Revenue_Expense__c ae = testData.scheduledRevenues[0].clone();
            ae.Ledger__c = testData.ledgers[4].Id;
            ae.Status__c = 'Approved';
            ae.Accrual_and_or_Cash__c = 'Cash';
            insert ae;

            List<Transaction__c> res = [SELECT Id, Ledger__c FROM Transaction__c WHERE Scheduled_Revenue_Expense__c = :ae.Id];
            System.assertEquals(2, res.size());
            System.assertEquals(
                LedgerHandler.getInstanceWithoutSharing().getShadowLedgerByParent(testData.ledgers[4].Id).Id,
                res[0].Ledger__c
            );
            System.assertEquals(
                LedgerHandler.getInstanceWithoutSharing().getShadowLedgerByParent(testData.ledgers[4].Id).Id,
                res[1].Ledger__c
            );
        }
    }

}