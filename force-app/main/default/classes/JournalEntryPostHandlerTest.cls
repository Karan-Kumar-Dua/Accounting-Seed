@IsTest
public class JournalEntryPostHandlerTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testPurgeUnlockedPostingStatusFieldOnly() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks();

        System.runAs(testData.users.get(1)) {
            //Put some field into set of unlocked fields just to check it later
            TriggerObserver.getInstance().unlockField(Account.GL_Account_Variable_1__c);
            //create and post records
            testData.createJournalEntries(true);
            //Validate that Posting Status field was removed from the set of unlocked fields after the end of posting routine
            System.assertEquals(false, TriggerObserver.getInstance().isUnlockedField(Journal_Entry__c.Status__c));
            //Validate that originally unlocked field is still unlocked
            System.assertEquals(true, TriggerObserver.getInstance().isUnlockedField(Account.GL_Account_Variable_1__c));
        }
    }

    @IsTest
    public static void testPartialPosting() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Journal_Entry__c testJE1 = testData.journalEntries[0];
            Journal_Entry__c testJE2 = testData.journalEntries[1];

            testJE1.Status__c = 'In Progress';
            update testJE1;

            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> results = postHandler.post(new List<Journal_Entry__c>{testJE1, testJE2});

            System.assertEquals(1, postHandler.dispatcher.getSuccessfulResults().size());
            System.assertEquals(1, postHandler.dispatcher.getFailedResults().size());
            System.assertEquals(1, [SELECT count() FROM Journal_Entry__c WHERE Status__c = :AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED]);
        } 

    }

    @IsTest
    public static void testJournalEntryPostWithCashFlowFailed() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            //Create Cash Flow Categories and enable this in Accounting Settings
            testData.createCashFlowCategories(false);
            //Create Journal Entry
            Journal_Entry__c testJE = new Journal_Entry__c(
                Name = 'Test Journal Entry',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Journal_Date__c = System.today(),
                Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED
            );
            insert testJE;
            //Create Journal Entry Debit and Credit Lines
            //Debit line will act as Cash Flow line
            Journal_Entry_Line__c testDebitJeLine = new Journal_Entry_Line__c(
                Journal_Entry__c = testJE.Id,
                Debit__c = 100,
                GL_Account__c = testData.glAccounts[0].Id,//1000-Cash Bank GL Account
                Cash_Flow_Category__c = NULL,//it will not be populated by trigger since CFS is not enabled yet,
                Units__c = 10,
                Reference__c = 'test ref xxx'
            );
            insert testDebitJeLine;
            //Credit line without cash flow category specified
            Journal_Entry_Line__c testCreditJeLine = new Journal_Entry_Line__c(
                Journal_Entry__c = testJE.Id,
                Credit__c = 100,
                GL_Account__c = testData.glAccounts[17].Id,//'7000-Facilities Expense'
                Cash_Flow_Category__c = NULL,//value not needed since GL Account is not Cash Bank Account
                Units__c = 10,
                Reference__c = 'test ref yyy'
            );
            insert testCreditJeLine;
            //enable Cash Flow Statement
            testData.settings.Enable_Cash_Flow_Statement__c = true;
            update testData.settings;
            //reset settings in static variable
            AccountingSettingsHandler.acctSeedSettings = NULL;

            //Post this Journal Entry
            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Journal_Entry__c>{testJE});
            //Posting procedure will fail because of missing CFC value on debit JE Line
            System.assertEquals(false, postResults[0].isSuccess);
            //But in any case we must be sure that no any new transactions were created during posting procedure
            List<Transaction__c> newTransactions = [
                SELECT Id
                FROM Transaction__c
                WHERE Journal_Entry_Line__c = :testDebitJeLine.Id
                OR Journal_Entry_Line__c = :testCreditJeLine.Id
            ];
            System.assertEquals(true, newTransactions.isEmpty());
        }
    }
    
    @IsTest
    public static void testJournalEntryPostWithCashFlowSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            //Create Cash Flow Categories and enable this in Accounting Settings
            testData.createCashFlowCategories(true);
            //Create Journal Entry
            Journal_Entry__c testJE = new Journal_Entry__c(
                Name = 'Test Journal Entry',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Journal_Date__c = System.today(),
                Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED
            );
            insert testJE;
            //Create Journal Entry Debit and Credit Lines
            //Debit line will act as Cash Flow line
            Journal_Entry_Line__c testDebitJeLine = new Journal_Entry_Line__c(
                Journal_Entry__c = testJE.Id,
                Debit__c = 100,
                GL_Account__c = testData.glAccounts[0].Id,
                Cash_Flow_Category__c = testData.cashFlowCategories[4].Id,
                Units__c = 10,
                Reference__c = 'test ref xxx'
            );
            insert testDebitJeLine;
            //Credit line without cash flow category specified
            Journal_Entry_Line__c testCreditJeLine = new Journal_Entry_Line__c(
                Journal_Entry__c = testJE.Id,
                Credit__c = 100,
                GL_Account__c = testData.glAccounts[17].Id,//'7000-Facilities Expense'
                Cash_Flow_Category__c = NULL,//value not needed since GL Account is not Cash Bank Account
                Units__c = 10,
                Reference__c = 'test ref yyy'
            );
            insert testCreditJeLine;
            //enable Cash Flow Statement
            testData.settings.Enable_Cash_Flow_Statement__c = true;
            update testData.settings;
            //reset settings in static variable
            AccountingSettingsHandler.acctSeedSettings = NULL;

            //Post this Journal Entry
            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Journal_Entry__c>{testJE});

            System.assertEquals(true, postResults[0].isSuccess);

            List<Financial_Cube__c> cashFlowFinCubes = [
                SELECT Id, GL_Account__c, (SELECT Id FROM Financial_Cube_Transactions__r)
                FROM Financial_Cube__c
                WHERE Cube_Type__c = 'Cash Flow'
            ];
            System.assertNotEquals(true, cashFlowFinCubes.isEmpty());
            System.assertEquals(1, cashFlowFinCubes.size());
            System.assertEquals(1, cashFlowFinCubes[0].Financial_Cube_Transactions__r.size());
            System.assertEquals(testData.cashFlowCategories[4].Id, cashFlowFinCubes[0].GL_Account__c);
        }
    }

    @IsTest
    public static void testJournalEntryPostIsPostedError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Journal_Entry__c testJE = testData.journalEntries[0];
            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> results = postHandler.post(new List<Journal_Entry__c>{testJE});
            postHandler.dispatcher.clearResultsMap();
            results = postHandler.post(new List<Journal_Entry__c>{testJE});
            System.assertEquals(PostResult.StatusCode.ALREADY_POSTED, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testJournalEntryPostNoJournalLinesError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Journal_Entry__c testJE = testData.journalEntries[0];

            delete [SELECT Id FROM Journal_Entry_Line__c WHERE Journal_Entry__c = :testJE.Id];

            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> results = postHandler.post(new List<Journal_Entry__c>{testJE});
            System.assertEquals(PostResult.StatusCode.NO_LINES, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testJournalEntryPostDebitAndCreditsError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Journal_Entry__c testJE = testData.journalEntries[0];

            List<Journal_Entry_Line__c> journalEntryLines = new List<Journal_Entry_Line__c>();

            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testJE.Id,
                    Project__c = testData.projects[0].Id,
                    Project_Task__c = testData.projectTasks[0].Id,
                    Credit__c = 100,
                    GL_Account__c = testData.glAccounts[0].Id,
                    Units__c = 10
                )
            );
            insert journalEntryLines;

            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> results = postHandler.post(new List<Journal_Entry__c>{testJE});
            System.assertEquals(PostResult.StatusCode.CREDITS_DEBITS_NOT_EQUAL, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testJournalEntryPostDebitAndCreditsLargeScaleSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Journal_Entry__c testJE = testData.journalEntries[0];

            List<Journal_Entry_Line__c> journalEntryLines = new List<Journal_Entry_Line__c>();

            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testJE.Id,
                    Project__c = testData.projects[0].Id,
                    Project_Task__c = testData.projectTasks[0].Id,
                    Credit__c = 100.456346346436436464,
                    GL_Account__c = testData.glAccounts[0].Id,
                    Units__c = 10
                )
            );

            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testJE.Id,
                    Project__c = testData.projects[0].Id,
                    Project_Task__c = testData.projectTasks[0].Id,
                    Debit__c = 100.456346346436436463,
                    GL_Account__c = testData.glAccounts[0].Id,
                    Units__c = 10
                )
            );
            insert journalEntryLines;

            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> results = postHandler.post(new List<Journal_Entry__c>{testJE});
            System.assertEquals(true, results[0].isSuccess);
        }

    }

    @IsTest
    public static void testJournalEntryPostIsAccountingPeriodClosedError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Journal_Entry__c testJE = testData.journalEntries[0];

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];

            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> results = postHandler.post(new List<Journal_Entry__c>{testJE});
            System.assertEquals(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testJournalEntryPostNotApprovedError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Journal_Entry__c testJE = testData.journalEntries[0];
            testJE.Status__c = 'In Progress';
            update testJE;

            Test.startTest();
            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> results = postHandler.post(new List<Journal_Entry__c>{testJE});
            Test.stopTest();
            System.assertEquals(PostResult.StatusCode.STATUS_NOT_APPROVED, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testJournalEntryPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Journal_Entry__c testJE = testData.journalEntries[0];

            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> results = postHandler.post(new List<Journal_Entry__c>{testJE});

            System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, [SELECT Status__c FROM Journal_Entry__c WHERE Id = :testJE.Id].Status__c);
            System.assertNotEquals(0, [SELECT count() FROM Transaction__c WHERE Journal_Entry_Line__r.Journal_Entry__c = :testJE.Id]);
            System.assertEquals(
                0,
                [
                    SELECT SUM(Amount__c) sum
                    FROM Transaction__c
                    WHERE Journal_Entry_Line__r.Journal_Entry__c = :testJE.Id
                    GROUP BY Journal_Entry_Line__r.Journal_Entry__c
                ][0].get('sum')
            );
        }

    }

    @IsTest
    public static void testJournalEntryUnpostIsNotPostedSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Journal_Entry__c testJE = testData.journalEntries[0];

            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> results = postHandler.unpost(new List<Journal_Entry__c>{testJE});

            System.assertEquals(false, results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.ALREADY_UNPOSTED, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testJournalEntryUnpostIsAccountingPeriodClosedError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Journal_Entry__c testJE = testData.journalEntries[0];

            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> results = postHandler.post(new List<Journal_Entry__c>{testJE});

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];

            postHandler.dispatcher.clearResultsMap();
            results = postHandler.unpost(new List<Journal_Entry__c>{testJE});
            System.assertEquals(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testJournalEntryUnpostClearedBankReconciliationError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Journal_Entry__c testJE = testData.journalEntries[0];

            testData.journalEntryLines[0].Bank_Reconciliation__c = testData.bankReconciliations[0].Id;
            TriggerObserver.getInstance().unlockField(Journal_Entry_Line__c.Bank_Reconciliation__c);
            update testData.journalEntryLines[0];
            TriggerObserver.purgeUnlockedFields(Journal_Entry_Line__c.Bank_Reconciliation__c);

            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> results = postHandler.post(new List<Journal_Entry__c>{testJE});

            postHandler.dispatcher.clearResultsMap();
            results = postHandler.unpost(new List<Journal_Entry__c>{testJE});
            System.assertEquals(PostResult.StatusCode.CLEARED_BANK_RECONCILIATION, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testJournalEntryUnpostClearedBankDepositError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries()
            .createBankDeposits();

        System.runAs(testData.users.get(1)) {
            testData.bankDeposits[0].Deposit_Date__c = System.today();
            update testData.bankDeposits[0];
            Test.startTest();
            Journal_Entry__c testJE = testData.journalEntries[0];
            testData.journalEntryLines[0].Bank_Deposit__c = testData.bankDeposits[0].Id;
            TriggerObserver.getInstance().unlockField(Journal_Entry_Line__c.Bank_Deposit__c);
            update testData.journalEntryLines[0];
            TriggerObserver.purgeUnlockedFields(Journal_Entry_Line__c.Bank_Deposit__c);

            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> results = postHandler.post(new List<Journal_Entry__c>{testJE});

            postHandler.dispatcher.clearResultsMap();
            results = postHandler.unpost(new List<Journal_Entry__c>{testJE});
            System.assertEquals(PostResult.StatusCode.CLEARED_BANK_DEPOSIT, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testJournalEntryUnpostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Journal_Entry__c testJE = testData.journalEntries[0];

            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> results = postHandler.post(new List<Journal_Entry__c>{testJE});

            System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, [SELECT Status__c FROM Journal_Entry__c WHERE Id = :testJE.Id].Status__c);
            System.assertNotEquals(0, [SELECT count() FROM Transaction__c WHERE Journal_Entry_Line__r.Journal_Entry__c = :testJE.Id]);
            System.assertEquals(
                0,
                [
                    SELECT SUM(Amount__c) sum
                    FROM Transaction__c
                    WHERE Journal_Entry_Line__r.Journal_Entry__c = :testJE.Id
                    GROUP BY Journal_Entry_Line__r.Journal_Entry__c
                ][0].get('sum')
            );

            postHandler.dispatcher.clearResultsMap();
            results = postHandler.unpost(new List<Journal_Entry__c>{testJE});

            System.assertEquals(true, results[0].isSuccess);
            System.assertNotEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, [SELECT Status__c FROM Journal_Entry__c WHERE Id = :testJE.Id].Status__c);
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Journal_Entry_Line__r.Journal_Entry__c = :testJE.Id]);
        }

    }

    @IsTest
    public static void testBatchUnpostValidAndNonValidRecords() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Journal_Entry__c testJE1 = testData.journalEntries[0];
            Journal_Entry__c testJE2 = testData.journalEntries[1];

            //Associate the Journal Entry Line from the first Journal Entry record with Bank Reconciliation
            //This will make first Journal Entry record non-valid for the unposting
            testData.journalEntryLines[0].Bank_Reconciliation__c = testData.bankReconciliations[0].Id;
            TriggerObserver.getInstance().unlockField(Journal_Entry_Line__c.Bank_Reconciliation__c);
            update testData.journalEntryLines[0];
            TriggerObserver.purgeUnlockedFields(Journal_Entry_Line__c.Bank_Reconciliation__c);
            //Post both JE records
            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> results = postHandler.post(new List<Journal_Entry__c>{testJE1, testJE2});
            System.assertEquals(true, results[0].isSuccess);
            System.assertEquals(true, results[1].isSuccess);

            postHandler.dispatcher.clearResultsMap();
            //try to unpost both JE records
            results = postHandler.unpost(new List<Journal_Entry__c>{testJE1, testJE2});
            System.assertEquals(false, results[0].isSuccess);//still posted
            System.assertEquals(true, results[1].isSuccess);//unposted
        }

    }

    @IsTest
    public static void testJournalEntryPostZeroDebitOrCreditSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Journal_Entry__c journalEntry = testData.journalEntries[2];
            journalEntry = [SELECT Id, Total_Credits__c, Total_Debits__c FROM Journal_Entry__c WHERE Id = :journalEntry.Id];
            System.assertEquals(0.0, journalEntry.Total_Credits__c);
            System.assertEquals(0.0, journalEntry.Total_Debits__c);

            Test.startTest();
            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> results = postHandler.post(new List<Journal_Entry__c>{journalEntry});
            Test.stopTest();

            System.assertEquals(true, results[0].isSuccess);
        }
    }

    @IsTest
    public static void testCashBasisPostBothLedgerSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Journal_Entry__c journalEntry = testData.journalEntries[0];
            journalEntry.Ledger__c = testData.ledgers[4].Id;
            journalEntry.Status__c = 'Approved';
            journalEntry.Accrual_and_or_Cash__c = 'Accrual and Cash';
            update journalEntry;

            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> results = postHandler.post(new List<Journal_Entry__c>{journalEntry});

            System.assertEquals(true, results[0].isSuccess);
            System.assertEquals(2, [SELECT Id FROM Transaction__c WHERE Journal_Entry_Line__c = :testData.journalEntryLines[0].Id].size());
            System.assertEquals(2, [SELECT Id FROM Transaction__c WHERE Journal_Entry_Line__c = :testData.journalEntryLines[1].Id].size());
        }
    }

    @IsTest
    public static void testCashBasisPostAccrualLedgerSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Journal_Entry__c journalEntry = testData.journalEntries[0];
            journalEntry.Ledger__c = testData.ledgers[4].Id;
            journalEntry.Status__c = 'Approved';
            journalEntry.Accrual_and_or_Cash__c = 'Accrual';
            update journalEntry;

            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> results = postHandler.post(new List<Journal_Entry__c>{journalEntry});

            List<Transaction__c> res1 = [SELECT Id, Ledger__c FROM Transaction__c WHERE Journal_Entry_Line__c = :testData.journalEntryLines[0].Id];
            List<Transaction__c> res2 = [SELECT Id, Ledger__c FROM Transaction__c WHERE Journal_Entry_Line__c = :testData.journalEntryLines[0].Id];
            System.assertEquals(true, results[0].isSuccess);
            System.assertEquals(1, res1.size());
            System.assertEquals(1, res2.size());
            System.assertEquals(testData.ledgers[4].Id, res1[0].Ledger__c);
            System.assertEquals(testData.ledgers[4].Id, res2[0].Ledger__c);
        }
    }

    @IsTest
    public static void testCashBasisPostCashLedgerSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Journal_Entry__c journalEntry = testData.journalEntries[0];
            journalEntry.Ledger__c = testData.ledgers[4].Id;
            journalEntry.Status__c = 'Approved';
            journalEntry.Accrual_and_or_Cash__c = 'Cash';
            update journalEntry;

            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> results = postHandler.post(new List<Journal_Entry__c>{journalEntry});

            List<Transaction__c> res1 = [SELECT Id, Ledger__c FROM Transaction__c WHERE Journal_Entry_Line__c = :testData.journalEntryLines[0].Id];
            List<Transaction__c> res2 = [SELECT Id, Ledger__c FROM Transaction__c WHERE Journal_Entry_Line__c = :testData.journalEntryLines[0].Id];
            System.assertEquals(true, results[0].isSuccess);
            System.assertEquals(1, res1.size());
            System.assertEquals(1, res2.size());
            System.assertEquals(
                LedgerHandler.getInstanceWithoutSharing().getShadowLedgerByParent(testData.ledgers[4].Id).Id,
                res1[0].Ledger__c
            );
            System.assertEquals(
                LedgerHandler.getInstanceWithoutSharing().getShadowLedgerByParent(testData.ledgers[4].Id).Id,
                res2[0].Ledger__c
            );
        }
    }

}