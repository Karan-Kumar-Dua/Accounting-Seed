@IsTest
public class BankDepositManagerTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testInitialPageLoadWithReconciliationWarning() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankDeposits().createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Deposit__c testBD = testData.bankDeposits[0];
            Bank_Reconciliation2__c testBankRecon = testData.bankReconciliations[0];
            testBD.Bank_Reconciliation__c = testBankRecon.Id;
            TriggerObserver.getInstance().unlockField(Bank_Deposit__c.Bank_Reconciliation__c);
            update testBD;
            TriggerObserver.reset();
            PageReference testPage = Page.BankDepositManager;
            Test.setCurrentPage(testPage);
            BankDepositManager bdm = new BankDepositManager(new ApexPages.StandardController(testBD));
            System.assertEquals(true, bdm.isError);
        }

    }

    @IsTest
    public static void testGetUnassociatedRecords() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDeposits()
            .createCashReceipts()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            String startDate = Date.newInstance(1991, 9, 30).format();
            String endDate = Date.newInstance(1991, 12, 1).format();
            //Cash Receipts are posted already so we have to post only Journal Entries
            for (Journal_Entry__c je : testData.journalEntries) {
                je.Status__c = 'Approved';
                je.Journal_Date__c = Date.parse(startDate).addDays(10);
            }
            update testData.journalEntries;

            List<Journal_Entry_Line__c> linesToUpdate = new List<Journal_Entry_Line__c>();
            for (Journal_Entry_Line__c jel : [  SELECT Id, Date__c, Journal_Entry__r.Journal_Date__c 
                                                FROM Journal_Entry_Line__c 
                                                WHERE Journal_Entry__c IN :testData.journalEntries]) {
                
                jel.Date__c = jel.Journal_Entry__r.Journal_Date__c;
                linesToUpdate.add(jel);
            }
            update linesToUpdate;

            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> postResults = postHandler.post(testData.journalEntries);
            System.assertEquals(true, postResults[0].isSuccess);

            List<BankDepositManager.AssociableRecordWrapper> result = BankDepositManager.getUnassociatedRecords(
                BankDepositManager.ANY_TYPE, 
                startDate, 
                endDate, 
                (String)testData.glAccounts[0].Id,
                '', '', '', '', 
                4000, 
                'usd', 
                testData.ledgers[0].Id
            );
            System.assertEquals(testData.cashReceipts.size() + testData.journalEntryLines.size(), result.size());

            result = BankDepositManager.getUnassociatedRecords(
                BankDepositManager.CASH_RECEIPT_TYPE, 
                startDate, 
                endDate, 
                (String)testData.glAccounts[0].Id,
                '', '', '', '', 
                4000, 
                'usd', 
                testData.ledgers[0].Id
            );
            System.assertEquals(testData.cashReceipts.size(), result.size());

            result = BankDepositManager.getUnassociatedRecords(
                BankDepositManager.JOURNAL_ENTRY_LINE_TYPE, 
                startDate, 
                endDate, 
                (String)testData.glAccounts[0].Id,
                '', '', '', '', 
                4000,
                'usd', 
                testData.ledgers[0].Id
            );
            System.assertEquals(testData.journalEntryLines.size(), result.size());
        }

    }

    @IsTest
    public static void testGetUnassociatedRecordsWithGLAVS() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDeposits()
            .createCashReceipts()
            .createAccountingVariables()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            String startDate = Date.newInstance(1991, 9, 30).format();
            String endDate = Date.newInstance(1991, 12, 1).format();

            List<Cash_Receipt__c> crList = new List<Cash_Receipt__c>();
            Cash_Receipt__c cr = testData.cashReceipts[0].clone(false,true);
            cr.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            crList.add(cr);

            cr = testData.cashReceipts[0].clone(false,true);
            cr.GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            crList.add(cr);

            cr = testData.cashReceipts[0].clone(false,true);
            cr.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            cr.GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            crList.add(cr);

            cr = testData.cashReceipts[0].clone(false,true);
            cr.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            cr.GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            crList.add(cr);

            insert crList;

            for (Cash_Receipt__c cr1 : [SELECT Id, Status__c FROM Cash_Receipt__c WHERE Id IN :crList]) {
                System.assertEquals('Posted', cr1.Status__c);
            }

            List<BankDepositManager.AssociableRecordWrapper> result = BankDepositManager.getUnassociatedRecords(
                BankDepositManager.ANY_TYPE,
                startDate,
                endDate,
                (String)testData.glAccounts[0].Id,
                testData.accountingVariables1[0].Id,
                '', '', '',
                4000,
                'usd',
                testData.ledgers[0].Id
            );
            System.assertEquals(3, result.size());

            result = BankDepositManager.getUnassociatedRecords(
                BankDepositManager.ANY_TYPE,
                startDate,
                endDate,
                (String)testData.glAccounts[0].Id,
                testData.accountingVariables1[0].Id,
                '', '',
                testData.accountingVariables4[0].Id,
                4000,
                'usd',
                testData.ledgers[0].Id
            );
            System.assertEquals(1, result.size());

            result = BankDepositManager.getUnassociatedRecords(
                BankDepositManager.CASH_RECEIPT_TYPE,
                startDate,
                endDate,
                (String)testData.glAccounts[0].Id,
                '',
                testData.accountingVariables2[0].Id,
                '', '',
                4000,
                'usd',
                testData.ledgers[0].Id
            );
            System.assertEquals(1, result.size());

            result = BankDepositManager.getUnassociatedRecords(
                BankDepositManager.CASH_RECEIPT_TYPE,
                startDate, endDate,
                (String)testData.glAccounts[0].Id,
                '', '',
                testData.accountingVariables3[0].Id,
                '',
                4000,
                'usd',
                testData.ledgers[0].Id
            );
            System.assertEquals(1, result.size());

            result = BankDepositManager.getUnassociatedRecords(
                BankDepositManager.CASH_RECEIPT_TYPE,
                startDate,
                endDate,
                (String)testData.glAccounts[0].Id,
                '', '', '',
                testData.accountingVariables4[0].Id,
                4000,
                'usd',
                testData.ledgers[0].Id
            );
            System.assertEquals(1, result.size());

            for (Journal_Entry__c je : testData.journalEntries) {
                je.Status__c = 'Approved';
                je.Journal_Date__c = Date.parse(startDate).addDays(10);
            }
            update testData.journalEntries;

            delete [SELECT Id FROM Journal_Entry_Line__c WHERE Journal_Entry__c IN :testData.journalEntries];

            List<Journal_Entry_Line__c> linesToUpdate = new List<Journal_Entry_Line__c>();
            for (Integer i = 0; i < testData.journalEntries.size(); i++) {
                Journal_Entry_Line__c jel = new Journal_Entry_Line__c();
                jel.Journal_Entry__c = testData.journalEntries[i].Id;
                jel.Date__c = testData.journalEntries[i].Journal_Date__c;
                jel.GL_Account__c = testData.glAccounts[0].Id;
                jel.Debit__c = 1;
                jel.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
                linesToUpdate.add(jel);

                jel = new Journal_Entry_Line__c();
                jel.Journal_Entry__c = testData.journalEntries[i].Id;
                jel.Date__c = testData.journalEntries[i].Journal_Date__c;
                jel.GL_Account__c = testData.glAccounts[0].Id;
                jel.Credit__c = 1;
                jel.GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
                linesToUpdate.add(jel);
            }

            linesToUpdate[0].GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            linesToUpdate[1].GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            insert linesToUpdate;

            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> postResults = postHandler.post(testData.journalEntries);
            System.assertEquals(true, postResults[0].isSuccess);

            result = BankDepositManager.getUnassociatedRecords(
                    BankDepositManager.ANY_TYPE,
                    startDate,
                    endDate,
                    (String)testData.glAccounts[0].Id,
                    testData.accountingVariables1[0].Id,
                    '', '', '',
                    4000,
                    'usd',
                    testData.ledgers[0].Id
            );
            System.assertEquals(6, result.size());

            result = BankDepositManager.getUnassociatedRecords(
                    BankDepositManager.JOURNAL_ENTRY_LINE_TYPE,
                    startDate,
                    endDate,
                    (String)testData.glAccounts[0].Id,
                    testData.accountingVariables1[0].Id,
                    '', '', '',
                    4000,
                    'usd',
                    testData.ledgers[0].Id
            );
            System.assertEquals(3, result.size());

            result = BankDepositManager.getUnassociatedRecords(
                BankDepositManager.JOURNAL_ENTRY_LINE_TYPE,
                startDate,
                endDate,
                (String)testData.glAccounts[0].Id,
                '',
                testData.accountingVariables2[0].Id,
                '', '',
                4000,
                'usd',
                testData.ledgers[0].Id
            );
            System.assertEquals(3, result.size());

            result = BankDepositManager.getUnassociatedRecords(
                BankDepositManager.JOURNAL_ENTRY_LINE_TYPE,
                startDate,
                endDate,
                (String)testData.glAccounts[0].Id,
                '', '',
                testData.accountingVariables3[0].Id,
                '',
                4000,
                'usd',
                testData.ledgers[0].Id
            );
            System.assertEquals(1, result.size());

            result = BankDepositManager.getUnassociatedRecords(
                BankDepositManager.JOURNAL_ENTRY_LINE_TYPE,
                startDate,
                endDate,
                (String)testData.glAccounts[0].Id,
                '', '', '',
                testData.accountingVariables4[0].Id,
                4000,
                'usd',
                testData.ledgers[0].Id
            );
            System.assertEquals(1, result.size());
        }

    }

    @IsTest
    public static void testGetAssociatedCashReceipts() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDeposits()
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Bank_Deposit__c testBD = testData.bankDeposits[0];
            Cash_Receipt__c testCR = testData.cashReceipts[0];
            testCR.Bank_Deposit__c = testBD.Id;
            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Bank_Deposit__c,
                    Cash_Receipt__c.Status__c
                }
            );
            update testCR;

            List<BankDepositManager.AssociableRecordWrapper> result = BankDepositManager.getAssociatedRecords(
                (String)testBD.Id, 'usd', testData.ledgers[0].Id
            );
            System.assertEquals(1, result.size());
        }

    }

    @IsTest
    public static void testProcessAssociatedWithReceipts() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDeposits()
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Bank_Deposit__c testBD = testData.bankDeposits[0];
            Cash_Receipt__c testCR = testData.cashReceipts[0];
            testCR.Bank_Deposit__c = testBD.Id;
            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Bank_Deposit__c,
                    Cash_Receipt__c.Status__c
                }
            );
            update testCR;

            String startDate = Date.newInstance(1991, 9, 30).format();
            String endDate = Date.newInstance(1991, 12, 1).format();

            List<BankDepositManager.AssociableRecordWrapper> wrappedRowsToUnassociation = BankDepositManager.getAssociatedRecords(
                (String)testBD.Id, 'usd', testData.ledgers[0].Id
            );

            System.assertEquals(1, wrappedRowsToUnassociation.size());

            BankManagerHelper.Money result1 = BankDepositManager.processAssociation(wrappedRowsToUnassociation, (String)testBD.Id, false);

            System.assertEquals(0, result1.recordAmount);
            System.assertEquals(NULL, [SELECT Id, Bank_Deposit__c FROM Cash_Receipt__c WHERE Id = :wrappedRowsToUnassociation[0].obj.Id].Bank_Deposit__c);

            List<BankDepositManager.AssociableRecordWrapper> wrappedRowsToAssociation =
                BankDepositManager.getUnassociatedRecords(
                    BankDepositManager.CASH_RECEIPT_TYPE, 
                    startDate, 
                    endDate, 
                    (String)testData.glAccounts[0].Id,
                    '', '', '', '',
                    4000,
                    'usd', 
                    testData.ledgers[0].Id
                );

            System.assertEquals(2, wrappedRowsToAssociation.size());
            BankManagerHelper.Money result2 = BankDepositManager.processAssociation(wrappedRowsToAssociation, (String)testBD.Id, true);
            System.assertEquals(800, result2.recordAmount);
        }

    }

    @IsTest
    public static void testProcessAssociatedWithJournalEntryLines() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDeposits()
            .createCashReceipts()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Bank_Deposit__c testBD = testData.bankDeposits[0];
            testBD.Deposit_Date__c = Date.today();
            update testBD;
            Journal_Entry__c testJE = testData.journalEntries[0];

            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Journal_Entry__c>{testJE});
            System.assertEquals(true, postResults[0].isSuccess);

            String startDate = System.today().addDays(-10).format();
            String endDate = System.today().addDays(10).format();

            List<BankDepositManager.AssociableRecordWrapper> associableRecords =
                BankDepositManager.getUnassociatedRecords(
                    BankDepositManager.ANY_TYPE, 
                    startDate, 
                    endDate, 
                    (String)testData.glAccounts[0].Id,
                    '', '', '', '',
                    4000,
                    'usd', 
                    testData.ledgers[0].Id
                );
            System.assertEquals(2, associableRecords.size());

            BankManagerHelper.Money result1 = BankDepositManager.processAssociation(associableRecords, (String) testBD.Id, true);

            System.assertEquals(0, result1.recordAmount);
            System.assertEquals(
                testBD.Id, [
                    SELECT Id, Bank_Deposit__c 
                    FROM Journal_Entry_Line__c 
                    WHERE Id = :associableRecords[0].obj.Id
                ].Bank_Deposit__c
            );

            List<BankDepositManager.AssociableRecordWrapper> associatedRecords = BankDepositManager.getAssociatedRecords(
                testBD.Id, 'usd', testData.ledgers[0].Id
            );
            System.assertEquals(2, associatedRecords.size());
            BankManagerHelper.Money result2 = BankDepositManager.processAssociation(associatedRecords, (String)testBD.Id, false);
            System.assertEquals(0, result2.recordAmount);
            Test.stopTest();
        }

    }

    @IsTest
    public static void testProcessAssociatedWithJournalEntryLines_MC() {
        // Test post functionality
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createBankDeposits()
                .createProjects()
                .createProjectTasks()
                .createJournalEntries();

            System.runAs(testData.users.get(1)) {
                AccountingSettingsHandler.acctSeedSettings = NULL;

                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();

                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Bank_Deposit__c testBD = testData.bankDeposits[0].clone(false, true);
                testBD.Deposit_Date__c = Date.today();
                insert testBD;

                Journal_Entry__c testJE = testData.journalEntries[0].clone(false, true);
                testJE.put('CurrencyIsoCode', newCurrencyIsoCode);
                testJE.Currency_Conversion_Rate__c = 0.80;
                insert testJE;

                List<Journal_Entry_Line__c> testJeLines = new List<Journal_Entry_Line__c>{
                    new Journal_Entry_Line__c(
                        Journal_Entry__c = testJE.Id,
                        Project__c = testData.projects[0].Id,
                        Project_Task__c = testData.projectTasks[0].Id,
                        Credit__c = 100,
                        GL_Account__c = testData.glAccounts[0].Id,
                        Units__c = 10,
                        Reference__c = 'testRef1'
                    ),
                    new Journal_Entry_Line__c(
                        Journal_Entry__c = testJE.Id,
                        Project__c = testData.projects[0].Id,
                        Project_Task__c = testData.projectTasks[0].Id,
                        Debit__c = 100,
                        GL_Account__c = testData.glAccounts[0].Id,
                        Units__c = 10,
                        Reference__c = 'testRef2'
                    )
                };

                insert testJeLines;

                AbstractPostHandler postHandler = new JournalEntryPostHandler();
                List<PostResult> postResults = postHandler.post(new List<Journal_Entry__c>{testJE});
                System.assertEquals(true, postResults[0].isSuccess);

                String startDate = System.today().addDays(-10).format();
                String endDate = System.today().addDays(10).format();

                List<BankDepositManager.AssociableRecordWrapper> associableRecords =
                    BankDepositManager.getUnassociatedRecords(
                        BankDepositManager.ANY_TYPE, 
                        startDate, 
                        endDate, 
                        (String)testData.glAccounts[0].Id,
                        '', '', '', '',
                        4000,
                        newCurrencyIsoCode, 
                        testData.ledgers[0].Id
                    );
                System.assertEquals(2, associableRecords.size());

                BankManagerHelper.Money result1 = BankDepositManager.processAssociation(associableRecords, (String) testBD.Id, true);

                System.assertEquals(0, result1.recordAmount);//debit - credit
                System.assertEquals(
                    testBD.Id, [
                        SELECT Id, Bank_Deposit__c 
                        FROM Journal_Entry_Line__c 
                        WHERE Id = :associableRecords[0].obj.Id
                    ].Bank_Deposit__c
                );

                List<BankDepositManager.AssociableRecordWrapper> associatedRecords = BankDepositManager.getAssociatedRecords(
                    testBD.Id, newCurrencyIsoCode, testData.ledgers[0].Id
                );
                System.assertEquals(2, associatedRecords.size());
                BankManagerHelper.Money result2 = BankDepositManager.processAssociation(associatedRecords, (String)testBD.Id, false);
                System.assertEquals(0, result2.recordAmount);
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }

    }

    @IsTest
    public static void testBankDepositSearchWithSameCurrencyLedgerAndBD_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createCashReceipts()
                .createBankDeposits();

            System.runAs(testData.users.get(1)) {

                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }
                Cash_Receipt__c[] cashReceiptList = new List<Cash_Receipt__c>();
                Cash_Receipt__c receipt = testData.cashReceipts[0].clone(false, true);
                receipt.Ledger__c = testData.ledgers[2].Id;
                receipt.put('CurrencyIsoCode', newCurrencyIsoCode);
                cashReceiptList.add(receipt);

                receipt = testData.cashReceipts[0].clone(false, true);
                receipt.Ledger__c = testData.ledgers[2].Id;
                cashReceiptList.add(receipt);
                insert cashReceiptList;

                testData.bankDeposits[0].Ledger__c = testData.ledgers[2].Id;
                update testData.bankDeposits[0];

                AccountingSettingsHandler.acctSeedSettings = NULL;

                String bankDepositId = testData.bankDeposits[0].Id;
                String bankDepositCurrency = (String) Database.query(
                    'SELECT Id, CurrencyIsoCode FROM Bank_Deposit__c WHERE Id = :bankDepositId'
                )[0].get('CurrencyIsoCode');

                List<BankDepositManager.AssociableRecordWrapper> associableRecords =
                    BankDepositManager.getUnassociatedRecords(
                        BankDepositManager.ANY_TYPE,
                        testData.acctPeriods[1].Start_Date__c.format(),
                        (testData.acctPeriods[1].Start_Date__c + 100).format(),
                        (String) testData.glAccounts[0].Id,
                        '', '', '', '',
                        4000,
                        bankDepositCurrency,
                        testData.ledgers[2].Id
                    );

                System.assertEquals(2, associableRecords.size());
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }

    }

    @IsTest
    public static void testBankDepositSearchWithDiffCurrencyLedgerAndBD_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createCashReceipts()
                .createBankDeposits();

            System.runAs(testData.users.get(1)) {

                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }
                Cash_Receipt__c[] cashReceiptList = new List<Cash_Receipt__c>();
                Cash_Receipt__c receipt = testData.cashReceipts[0].clone(false, true);
                receipt.Ledger__c = testData.ledgers[2].Id;
                receipt.put('CurrencyIsoCode', newCurrencyIsoCode);
                cashReceiptList.add(receipt);

                receipt = testData.cashReceipts[0].clone(false, true);
                receipt.Ledger__c = testData.ledgers[2].Id;
                cashReceiptList.add(receipt);
                insert cashReceiptList;

                testData.bankDeposits[0].Ledger__c = testData.ledgers[2].Id;
                testData.bankDeposits[0].put('CurrencyIsoCode', newCurrencyIsoCode);
                update testData.bankDeposits[0];

                AccountingSettingsHandler.acctSeedSettings = NULL;

                List<BankDepositManager.AssociableRecordWrapper> associableRecords =
                    BankDepositManager.getUnassociatedRecords(
                        BankDepositManager.ANY_TYPE,
                        testData.acctPeriods[1].Start_Date__c.format(),
                        (testData.acctPeriods[1].Start_Date__c + 100).format(),
                        (String) testData.glAccounts[0].Id,
                        '', '', '', '',
                        4000,
                        newCurrencyIsoCode,
                        testData.ledgers[2].Id
                    );

                System.assertEquals(1, associableRecords.size());
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }

    }

    @IsTest
    public static void testInitialPageLoadWithMatchedBTWarning() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankDeposits().createBankTransactions();

        System.runAs(testData.users.get(1)) {
            Bank_Deposit__c testBD = testData.bankDeposits[0].clone(false,true,false,false);
            testBD.Bank_Transaction__c = testData.bankTransactions[0].Id;
            insert testBD;
            PageReference testPage = Page.BankDepositManager;
            Test.setCurrentPage(testPage);
            BankDepositManager bdm = new BankDepositManager(new ApexPages.StandardController(testBD));
            System.assertEquals(true, bdm.isMatchedBD);
        }

    }

    @IsTest
    public static void testAssociateRecordWithMatchedBT() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankDeposits().createCashReceipts().createBankTransactions();

        System.runAs(testData.users.get(1)) {
            Bank_Deposit__c testBD = testData.bankDeposits[0].clone(false,true,false,false);
            testBD.Bank_Transaction__c = testData.bankTransactions[0].Id;
            testBD.Cleared_Date__c = System.today();
            insert testBD;

            Cash_Receipt__c testCR = testData.cashReceipts[0];
            testCR.Bank_Deposit__c = testBD.Id;
            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Bank_Deposit__c,
                    Cash_Receipt__c.Status__c
                }
            );
            update testCR;

            BankTransactionsHelper.updateBankTransactionsStatus(
                DomainUtils.getBankTransactionsById(new Set<Id> {testData.bankTransactions[0].Id}),
                BankTransactionsHelper.BT_MATCHED_STATUS
            );

            List<BankDepositManager.AssociableRecordWrapper> wrappedRowsToUnassociation = BankDepositManager.getAssociatedRecords(
                (String)testBD.Id, 'usd', testData.ledgers[0].Id
            );

            System.assertEquals(1, wrappedRowsToUnassociation.size());

            BankDepositManager.processAssociation(wrappedRowsToUnassociation, (String)testBD.Id, false);

            Bank_Deposit__c resultBD = [SELECT Cleared_Date__c, Bank_Transaction__c FROM Bank_Deposit__c WHERE Id = :testBD.Id];
            Bank_Transaction__c resultBT = [SELECT Status__c FROM Bank_Transaction__c WHERE Id = :testData.bankTransactions[0].Id];
            System.assertEquals(NULL, resultBD.Cleared_Date__c);
            System.assertEquals(NULL, resultBD.Bank_Transaction__c);
            System.assertEquals(BankTransactionsHelper.BT_UNMATCHED_STATUS, resultBT.Status__c);
        }

    }

}