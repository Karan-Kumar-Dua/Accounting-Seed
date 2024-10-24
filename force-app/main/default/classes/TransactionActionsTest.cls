@IsTest
public class TransactionActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testValidateOriginalState() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .createCashReceipts()
            .createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            //create 450 Transactions to simulate 3 trigger chunks
            List<Transaction__c> transactions = new List<Transaction__c>();
            for (Integer i = 0; i < 450; i++) {
                Transaction__c tempTransaction = new Transaction__c(
                    Cash_Receipt__c = testData.cashReceipts.get(0).Id,
                    Amount__c = 10,
                    Ledger__c = testData.ledgers.get(0).Id,
                    Accounting_Period__c = testData.acctPeriods.get(0).Id,
                    GL_Account_Variable_1__c = testData.accountingVariables1.get(0).Id
                );
                transactions.add(tempTransaction);
            }

            TransactionActions.originalRecords = transactions;

            Test.startTest();
            List<Transaction__c> firstChunk = new List<Transaction__c>();
            List<Transaction__c> secondChunk = new List<Transaction__c>();
            List<Transaction__c> thirdChunk = new List<Transaction__c>();

            for (Integer i = 0; i < 200; i++) {
                firstChunk.add(transactions.get(i));
            }
            for (Integer i = 200; i < 400; i++) {
                secondChunk.add(transactions.get(i));
            }
            for (Integer i = 400; i < 450; i++) {
                thirdChunk.add(transactions.get(i));
            }

            TransactionActions.originalRecords.remove(449);
            TransactionActions.originalRecords.add(
                new Transaction__c(
                    Cash_Receipt__c = testData.cashReceipts.get(0).Id,
                    Amount__c = 10,
                    Ledger__c = testData.ledgers.get(0).Id,
                    Accounting_Period__c = testData.acctPeriods.get(0).Id,
                    GL_Account_Variable_1__c = NULL
                )
            );

            System.assertEquals(0, TransactionActions.triggerChunkNmb);
            TransactionActions.validateOriginalState(firstChunk);
            System.assertEquals(1, TransactionActions.triggerChunkNmb);
            TransactionActions.validateOriginalState(secondChunk);
            System.assertEquals(2, TransactionActions.triggerChunkNmb);
            TransactionActions.validateOriginalState(thirdChunk);
            System.assertEquals(3, TransactionActions.triggerChunkNmb);
        }
    }

    @IsTest
    public static void testInsertGLAccountEmpty() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Transaction__c testTransaction = new Transaction__c(
                Journal_Entry_Line__c = testData.journalEntryLines[0].Id,
                Amount__c = 100,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Ledger__c = testData.ledgers[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                GL_Account__c = NULL
            );

            DmlException dmlEx;
            try {
                TransactionActions.isPreventInsertOverride = true;
                insert testTransaction;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testInsertAccountingPeriodEmpty() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Transaction__c testTransaction = new Transaction__c(
                Journal_Entry_Line__c = testData.journalEntryLines[0].Id,
                Amount__c = 100,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Ledger__c = testData.ledgers[0].Id,
                Accounting_Period__c = NULL,
                GL_Account__c = testData.glAccounts[0].Id
            );

            DmlException dmlEx;
            try {
                TransactionActions.isPreventInsertOverride = true;
                insert testTransaction;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testInsertLedgerEmpty() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Transaction__c testTransaction = new Transaction__c(
                Journal_Entry_Line__c = testData.journalEntryLines[0].Id,
                Amount__c = 100,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Ledger__c = NULL,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                GL_Account__c = testData.glAccounts[0].Id
            );

            DmlException dmlEx;
            try {
                TransactionActions.isPreventInsertOverride = true;
                insert testTransaction;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testUpdateGLAccountEmpty() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Transaction__c testTransaction = new Transaction__c(
                Journal_Entry_Line__c = testData.journalEntryLines[0].Id,
                Amount__c = 100,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Ledger__c = testData.ledgers[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                GL_Account__c = testData.glAccounts[0].Id
            );

            DmlException dmlExOnInsert;
            try {
                TransactionActions.isPreventInsertOverride = true;
                insert testTransaction;
                TransactionActions.isPreventInsertOverride = false;
            }
            catch (DmlException ex) {
                dmlExOnInsert = ex;
            }
            System.assertEquals(NULL, dmlExOnInsert);

            DmlException dmlExOnUpdate;
            try {
                testTransaction.GL_Account__c = NULL;
                update testTransaction;
            }
            catch (DmlException ex) {
                dmlExOnUpdate = ex;
            }
            System.assertNotEquals(NULL, dmlExOnUpdate);
            System.assertEquals(TransactionActions.UPDATE_ERROR, dmlExOnUpdate.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testUpdateAccountingPeriodEmpty() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Transaction__c testTransaction = new Transaction__c(
                Journal_Entry_Line__c = testData.journalEntryLines[0].Id,
                Amount__c = 100,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Ledger__c = testData.ledgers[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                GL_Account__c = testData.glAccounts[0].Id
            );

            DmlException dmlExOnInsert;
            try {
                TransactionActions.isPreventInsertOverride = true;
                insert testTransaction;
                TransactionActions.isPreventInsertOverride = false;
            }
            catch (DmlException ex) {
                dmlExOnInsert = ex;
            }
            System.assertEquals(NULL, dmlExOnInsert);

            DmlException dmlExOnUpdate;
            try {
                testTransaction.Accounting_Period__c = NULL;
                update testTransaction;
            }
            catch (DmlException ex) {
                dmlExOnUpdate = ex;
            }
            System.assertNotEquals(NULL, dmlExOnUpdate);
            System.assertEquals(TransactionActions.UPDATE_ERROR, dmlExOnUpdate.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testUpdateLedgerEmpty() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Transaction__c testTransaction = new Transaction__c(
                Journal_Entry_Line__c = testData.journalEntryLines[0].Id,
                Amount__c = 100,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Ledger__c = testData.ledgers[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                GL_Account__c = testData.glAccounts[0].Id
            );

            DmlException dmlExOnInsert;
            try {
                TransactionActions.isPreventInsertOverride = true;
                insert testTransaction;
                TransactionActions.isPreventInsertOverride = false;
            }
            catch (DmlException ex) {
                dmlExOnInsert = ex;
            }
            System.assertEquals(NULL, dmlExOnInsert);

            DmlException dmlExOnUpdate;
            try {
                //delete FinCube to prevent auto-population of Ledger from FCT
                FinancialCubeActions.isPreventOverride = true;
                delete [SELECT Id FROM Financial_Cube__c];
                FinancialCubeActions.isPreventOverride = true;
                //update Transaction with empty Ledger field
                testTransaction.Ledger__c = NULL;
                update testTransaction;
            }
            catch (DmlException ex) {
                dmlExOnUpdate = ex;
            }
            System.assertNotEquals(NULL, dmlExOnUpdate);
            System.assertEquals(TransactionActions.UPDATE_ERROR, dmlExOnUpdate.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testPreventInsertNoSourceDocumentNoSource() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(true);

        System.runAs(testData.users.get(1)) {

            Transaction__c trans = [
                SELECT Id, Date__c, Accounting_Period__c, Amount__c, GL_Account__c, Foreign_Amount__c, Ledger__c
                FROM Transaction__c
                WHERE Journal_Entry_Line__r.Journal_Entry__c = :testData.journalEntries[0].Id
                LIMIT 1
            ];

            Transaction__c newTrans = trans.clone(false, true);
            newTrans.Journal_Entry_Line__c = NULL;
            //try to insert record without source document
            DMLException dmlEx;
            try {
                TransactionActions.createTransactions(new List<Transaction__c>{newTrans});
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(TransactionActions.ONE_SOURCE_DOCUMENT_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    public static void testPreventInsertNoSourceDocumentMoreThanOneSource() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();
        Test.startTest();
        testData.createBillings()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(true);

        System.runAs(testData.users.get(1)) {
            Transaction__c trans = [
                SELECT Id, Date__c, Accounting_Period__c, Amount__c, GL_Account__c, Journal_Entry_Line__c, Foreign_Amount__c, Ledger__c
                FROM Transaction__c
                WHERE Journal_Entry_Line__r.Journal_Entry__c = :testData.journalEntries[0].Id
                LIMIT 1
            ];

            Transaction__c newTrans = trans.clone(false, true);
            newTrans.Account_Payable_Line__c = testData.payableLines[0].Id;
            newTrans.Billing_Line__c = testData.billingLines[0].Id;
            
            DMLException dmlEx;
            try {
                TransactionActions.createTransactions(new List<Transaction__c>{newTrans});
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(TransactionActions.ONE_SOURCE_DOCUMENT_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    public static void testPreventInsertAction() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(true);

        System.runAs(testData.users.get(1)) {

            Transaction__c trans = [
                SELECT Id, Date__c
                FROM Transaction__c
                WHERE  Journal_Entry_Line__r.Journal_Entry__c = :testData.journalEntries[0].Id
                LIMIT 1
            ];
            Transaction__c newTrans = trans.clone(false,true);

            DMLException dmlEx;

            try {
                insert newTrans;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(TransactionActions.INSERT_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest    
    public static void testPreventUpdateAction() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(true);

        System.runAs(testData.users.get(1)) {

            Transaction__c trans = [
                SELECT Id, Date__c
                FROM Transaction__c
                WHERE  Journal_Entry_Line__r.Journal_Entry__c = :testData.journalEntries[0].Id LIMIT 1
            ];
            trans.Date__c = System.today() + 120;

            DMLException dmlEx;
            try {
                update trans;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(TransactionActions.UPDATE_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testPreventUpdateAPDisbursementSource() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Cash_Disbursement__c testCD = testData.cashDisbursements[5];

            //Post CD
            AbstractPostHandler cdPostHandler = new CashDisbursementPostHandler();
            List<PostResult> cdResults = cdPostHandler.post(new List<Cash_Disbursement__c>{testCD});
            System.assertEquals(true, cdResults[0].isSuccess);

            Account_Payable__c testAcctPayable = new Account_Payable__c(
                Payee_Reference__c = '2345sdfghtwsrehfdhdfhdfh',
                Status__c = 'Approved',
                Payment_Status__c = 'Unpaid',
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Due_Date__c = testData.acctPeriods[0].End_Date__c,
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Ledger__c = testData.ledgers[0].Id
            );
            insert testAcctPayable;

            Account_Payable_Line__c testAPLine = new Account_Payable_Line__c(
                Account_Payable__c = testAcctPayable.Id,
                Amount__c = 45,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Expense_GL_Account__c = testData.glAccounts[16].Id
            );
            insert testAPLine;

            //Post AP
            AbstractPostHandler apPostHandler = new AccountPayablePostHandler();
            List<PostResult> apResults = apPostHandler.post(new List<Account_Payable__c>{testAcctPayable});
            for (PostResult result : apResults) {
                System.assertEquals(true, result.isSuccess);
            }

            ApexPages.StandardController stdController = new ApexPages.StandardController(testCD);
            CashDisbursementApplyAccountPayable controller = new CashDisbursementApplyAccountPayable(stdController);
            System.assertNotEquals(true, controller.wrappedRecords.isEmpty());
            controller.wrappedRecords[0].apDisbursement.Paid_Amount__c = 10;
            controller.save();

            //Asserts
            List<AP_Disbursement__c> apDisbursements = [
                SELECT Id FROM AP_Disbursement__c WHERE Account_Payable__c = :testAcctPayable.Id
            ];
            System.assertEquals(1, apDisbursements.size());

            List<Transaction__c> newTransactions = [
                SELECT Id, AP_Disbursement__c
                FROM Transaction__c
                WHERE AP_Disbursement__c IN :apDisbursements
            ];
            System.assertEquals(2, newTransactions.size());

            //try to update AP_Disbursement lookup field on the first transaction
            newTransactions[0].AP_Disbursement__c = NULL;

            DMLException dmlEx;
            try {
                update newTransactions;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(TransactionActions.UPDATE_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testPreventDeleteTransactionWhenAPDisbursementAsSource() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Cash_Disbursement__c testCD = testData.cashDisbursements[5];

            //Post CD
            AbstractPostHandler cdPostHandler = new CashDisbursementPostHandler();
            List<PostResult> cdResults = cdPostHandler.post(new List<Cash_Disbursement__c>{testCD});
            System.assertEquals(true, cdResults[0].isSuccess);

            Account_Payable__c testAcctPayable = new Account_Payable__c(
                Payee_Reference__c = '2345sdfghtwsrehfdhdfhdfh',
                Status__c = 'Approved',
                Payment_Status__c = 'Unpaid',
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Due_Date__c = testData.acctPeriods[0].End_Date__c,
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Ledger__c = testData.ledgers[0].Id
            );
            insert testAcctPayable;

            Account_Payable_Line__c testAPLine = new Account_Payable_Line__c(
                Account_Payable__c = testAcctPayable.Id,
                Amount__c = 45,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Expense_GL_Account__c = testData.glAccounts[16].Id
            );
            insert testAPLine;

            //Post AP
            AbstractPostHandler apPostHandler = new AccountPayablePostHandler();
            List<PostResult> apResults = apPostHandler.post(new List<Account_Payable__c>{testAcctPayable});
            for (PostResult result : apResults) {
                System.assertEquals(true, result.isSuccess);
            }

            ApexPages.StandardController stdController = new ApexPages.StandardController(testCD);
            CashDisbursementApplyAccountPayable controller = new CashDisbursementApplyAccountPayable(stdController);
            System.assertNotEquals(true, controller.wrappedRecords.isEmpty());
            controller.wrappedRecords[0].apDisbursement.Paid_Amount__c = 10;
            controller.save();
            //Asserts
            List<AP_Disbursement__c> apDisbursements = [
                SELECT Id FROM AP_Disbursement__c WHERE Account_Payable__c = :testAcctPayable.Id
            ];
            System.assertEquals(1, apDisbursements.size());

            List<Transaction__c> newTransactions = [
                SELECT Id, AP_Disbursement__c
                FROM Transaction__c
                WHERE AP_Disbursement__c IN :apDisbursements
            ];
            System.assertEquals(2, newTransactions.size());

            //try to update AP_Disbursement lookup field on the first transaction
            DMLException dmlEx;
            try {
                delete newTransactions;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(TransactionActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }

    }
    
    @IsTest
    public static void testPreventUpdateActionNonCriticalField() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(true);

        System.runAs(testData.users.get(1)) {

            Transaction__c trans = [
                SELECT Id, Date__c
                FROM Transaction__c
                WHERE Journal_Entry_Line__r.Journal_Entry__c = :testData.journalEntries[0].Id LIMIT 1
            ];
            trans.Note__c = 'blah blah blah';

            DMLException dmlEx;
            try {
                update trans;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
        }

    }

    @IsTest
    public static void testPreventUpdateOverrideAction() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(true);

        System.runAs(testData.users.get(1)) {

            Transaction__c trans = [
                SELECT Id, Date__c
                FROM Transaction__c
                WHERE Journal_Entry_Line__r.Journal_Entry__c = :testData.journalEntries[0].Id LIMIT 1
            ];
            trans.Date__c = System.today() + 120;

            testData.settings.Financial_Suite_Key__c = EncodingUtil.base64Encode(
                Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.TRANSACTION_UPDATE_DELETE_KEY))
            );
            update testData.settings;
            AccountingSettingsHandler.acctSeedSettings = NULL;

            update trans;
            System.assertEquals(
                System.today() + 120,
                [
                    SELECT Id, Date__c
                    FROM Transaction__c
                    WHERE Journal_Entry_Line__r.Journal_Entry__c = :testData.journalEntries[0].Id LIMIT 1
                ].Date__c
            );
        }

    }

    @IsTest    
    public static void testPreventDeleteAction() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(true);

        System.runAs(testData.users.get(1)) {

            Transaction__c trans = [
                SELECT Id, Date__c
                FROM Transaction__c
                WHERE Journal_Entry_Line__r.Journal_Entry__c = :testData.journalEntries[0].Id LIMIT 1
            ];

            DMLException dmlEx;
            try {
                delete trans;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(TransactionActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    public static void testPreventDeleteOverrideAction() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(true);

        System.runAs(testData.users.get(1)) {

            Transaction__c[] trans = [
                SELECT Id, Date__c
                FROM Transaction__c
                WHERE Journal_Entry_Line__r.Journal_Entry__c = :testData.journalEntries[0].Id
            ];

            testData.settings.Financial_Suite_Key__c = EncodingUtil.base64Encode(
                Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.TRANSACTION_UPDATE_DELETE_KEY))
            );
            update testData.settings;
            AccountingSettingsHandler.acctSeedSettings = NULL;

            delete trans;
            System.assertEquals(
                0,
                [
                    SELECT count()
                    FROM Transaction__c
                    WHERE Journal_Entry_Line__r.Journal_Entry__c = :testData.journalEntries[0].Id LIMIT 1
                ]
            );
        }

    }

    @IsTest
    public static void testQueryTransactionsAccountPayableLine() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .setLineLevelPost();

        System.runAs(testData.users.get(1)) {
            ApexPages.StandardController controller = new ApexPages.StandardController(testData.payables[0]);
            AccountPayablePostTransaction app = new AccountPayablePostTransaction(controller);

            System.assertEquals(0, TransactionActions.queryTransactions(new Account_Payable_Line__c[]{testData.payableLines[0]}).size());
            app.post();
            System.assertNotEquals(0, TransactionActions.queryTransactions(new Account_Payable_Line__c[]{testData.payableLines[0]}).size());
        }

    }

    @IsTest
    public static void testQueryTransactionsBillingLine() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings()
            .setLineLevelPost();

        System.runAs(testData.users.get(1)) {
            ApexPages.StandardController controller = new ApexPages.StandardController(testData.billings[0]);
            BillingPostTransaction app = new BillingPostTransaction(controller);

            System.assertEquals(0, TransactionActions.queryTransactions(new Billing_Line__c[]{testData.billingLines[0]}).size());
            app.post();
            System.assertNotEquals(0, TransactionActions.queryTransactions(new Billing_Line__c[]{testData.billingLines[0]}).size());
        }

    }

    @IsTest
    public static void testQueryTransactionsCashDisbursement() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements(true);

        System.runAs(testData.users.get(1)) {

            System.assertNotEquals(0,TransactionActions.queryTransactions(new Cash_Disbursement__c[]{testData.cashDisbursements[0]}).size());
        }

    }
 
    @IsTest
    public static void testQueryTransactionsCashReceipt() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            System.assertNotEquals(0, TransactionActions.queryTransactions(new Cash_Receipt__c[]{testData.cashReceipts[0]}).size());

            ApexPages.Standardcontroller controller = new ApexPages.Standardcontroller(testData.cashReceipts[0]);
            CashReceiptPost cdb = new CashReceiptPost(controller);
            cdb.unpost();

            System.assertEquals(0, TransactionActions.queryTransactions(new Cash_Receipt__c[]{testData.cashReceipts[0]}).size());
        }

    }

    @IsTest
    public static void testQueryTransactionsJournalEntryLine() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(true);

        System.runAs(testData.users.get(1)) {

            System.assertNotEquals(
                0,
                TransactionActions.queryTransactions(
                    new List<Journal_Entry_Line__c>{testData.journalEntryLines[0]}
                ).size()
            );
        }

    }
 
    @IsTest
    public static void testQueryTransactionsScheduledRevenueExpense() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {

            System.assertNotEquals(
                0,
                TransactionActions.queryTransactions(
                    new List<Scheduled_Revenue_Expense__c>{testData.scheduledRevenues[0]}
                ).size()
            );

            ApexPages.Standardcontroller controller = new ApexPages.Standardcontroller(testData.scheduledRevenues[0]);
            ScheduledRevenueExpensePostTransaction scr = new ScheduledRevenueExpensePostTransaction(controller);
            scr.unpost();

            System.assertEquals(
                0,
                TransactionActions.queryTransactions(
                    new List<Scheduled_Revenue_Expense__c>{testData.scheduledRevenues[0]}
                ).size()
            );
        }

    }

    @IsTest
    public static void testQueryTransactionsTimeCardDay() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createTimeCards(true);

        System.runAs(testData.users.get(1)) {

            System.assertNotEquals(
                0,
                TransactionActions.queryTransactions(
                    new List<Time_Card_Day__c>{[
                        SELECT Id
                        FROM Time_Card_Day__c
                        WHERE Time_Card_Line__r.Time_Card__c = :testData.timeCards[0].Id LIMIT 1
                    ]}
                ).size()
            );
        }

    }

    @IsTest
    public static void testIsOrphanedTransaction() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(true);

        System.runAs(testData.users.get(1)) {

            Transaction__c trans = [
                SELECT  Id,
                        Billing__c,
                        Billing_Line__c,
                        Account_Payable__c,
                        Account_Payable_Line__c,
                        Billing_Cash_Receipt__c,
                        Cash_Receipt__c,
                        Cash_Disbursement__c,
                        Journal_Entry_Line__c,
                        Scheduled_Revenue_Expense__c,
                        Time_Card_Day__c,
                        AP_Disbursement__c
                FROM Transaction__c
                WHERE Journal_Entry_Line__r.Journal_Entry__c = :testData.journalEntries[0].Id LIMIT 1
            ];
            System.assertEquals(false, TransactionActions.isOrphaned(trans, TransactionActions.fsSourceDocumentFields));

            trans.Journal_Entry_Line__c = NULL;
            TransactionActions.isPreventUpdateOverride = true;
            update trans;

            System.assertEquals(true, TransactionActions.isOrphaned(trans, TransactionActions.fsSourceDocumentFields));
        }

    }

    @IsTest
    public static void testTransactionCurrencyIsAlwaysLedgerCurrency() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency(); //will throw an exception in case of non-MC org
            Test.startTest();
            testData.createBillings(true);

            System.runAs(testData.users.get(1)) {
                String newCurrency = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrency)) {
                    return;
                }
                String ledgerCurrency = (String) Database.query('SELECT Id, CurrencyIsoCode FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Ledger__c WHERE Id = \'' + String.escapeSingleQuotes(testData.ledgers[0].Id) + '\'')[0].get('CurrencyIsoCode');

                Billing__c newBilling = testData.billings[0].clone();
                newBilling.put('CurrencyIsoCode', newCurrency);
                newBilling.Status__c = 'Approved';

                insert newBilling;

                Billing_Line__c newBillingLine = testData.billingLines[0].clone();
                newBillingLine.Billing__c = newBilling.Id;

                insert newBillingLine;

                ApexPages.Standardcontroller controller = new ApexPages.Standardcontroller(newBilling);
                BillingPostTransaction app = new BillingPostTransaction(controller);

                System.assertEquals(
                    0,
                    TransactionActions.queryTransactions(new List<Billing_Line__c>{newBillingLine}).size()
                );
                app.post();

                Id billingLineId = newBillingLine.Id;

                for (Transaction__c tr : (List<Transaction__c>) Database.query(
                                            'SELECT CurrencyIsoCode ' +
                                            'FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Transaction__c ' +
                                            'WHERE ' + GlobalVariables.PACKAGE_QUALIFIER + 'Billing_Line__c = :billingLineId')) {

                    System.assertEquals(ledgerCurrency, tr.get('CurrencyIsoCode'));
                }
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testTransactionNoNullPointerExceptionInsert() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency();

            System.runAs(testData.users.get(1)) {
                DMLException dmlEx;

                Transaction__c tr = new Transaction__c();

                try {
                    insert tr;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }

                System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));

            }
        }
        catch (Exception ex) {

        }
    }

    @IsTest
    public static void testNormalizeNumericAndCurrencyFieldsInsert() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(true);

        System.runAs(testData.users[1]) {
            Transaction__c trans = [
                SELECT Id, Amount__c, Foreign_Amount__c, Accounting_Period__c, Date__c, GL_Account__c, Ledger__c, Journal_Entry_Line__c
                FROM Transaction__c
                WHERE  Journal_Entry_Line__r.Journal_Entry__c = :testData.journalEntries[0].Id
                LIMIT 1
            ];
            Transaction__c newTrans = trans.clone(false,true);

            newTrans.Amount__c = 2.3456838849;
            newTrans.Foreign_Amount__c = 4.5787268768478;

            TransactionActions.createTransactions(new List<Transaction__c> {newTrans});

            Transaction__c insertedTrans = [
                SELECT Id, Amount__c, Foreign_Amount__c
                FROM Transaction__c
                WHERE Id = :newTrans.Id
                LIMIT 1
            ];

            System.assertEquals(2.35, insertedTrans.Amount__c);
            System.assertEquals(4.58, insertedTrans.Foreign_Amount__c);
        }
    }

    @IsTest
    public static void testBillingLineLLPDescription() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .setLineLevelPost();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            ApexPages.StandardController controller = new ApexPages.StandardController(testData.billings[0]);
            BillingPostTransaction app = new BillingPostTransaction(controller);

            System.assertEquals(0, TransactionActions.queryTransactions(new Billing_Line__c[]{testData.billingLines[0]}).size());
            app.post();
            List<Transaction__c> trans = TransactionActions.queryTransactions(new Billing_Line__c[]{testData.billingLines[0]});

            Transaction__c res = [SELECT Id, Description__c, Note__c FROM Transaction__c WHERE Id = :trans[0].Id];
            Billing__c bill = [SELECT Id, Name FROM Billing__c WHERE Id = :testData.billings[0].Id];

            System.assertNotEquals(0, TransactionActions.queryTransactions(new Billing_Line__c[]{testData.billingLines[0]}).size());
            System.assertEquals(NULL, res.Description__c);
            System.assertEquals(bill.Name, res.Note__c);
        }

    }

    @IsTest
    public static void testBillingHLPDescription() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings(true);

        System.runAs(testData.users.get(1)) {
            Transaction__c res = [SELECT Id, Description__c, Note__c FROM Transaction__c WHERE Billing__c = :testData.billings[0].Id LIMIT 1];
            Billing__c bill = [SELECT Id, Name FROM Billing__c WHERE Id = :testData.billings[0].Id];

            System.assertEquals(bill.Name, res.Description__c);
            System.assertEquals(bill.Name, res.Note__c);
        }

    }

    @IsTest
    public static void testPayableLineLLPDescription() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .setLineLevelPost();

        System.runAs(testData.users.get(1)) {
            ApexPages.StandardController controller = new ApexPages.StandardController(testData.payables[0]);
            AccountPayablePostTransaction app = new AccountPayablePostTransaction(controller);

            System.assertEquals(0, TransactionActions.queryTransactions(new Account_Payable_Line__c[]{testData.payableLines[0]}).size());
            app.post();
            List<Transaction__c> trans = TransactionActions.queryTransactions(new Account_Payable_Line__c[]{testData.payableLines[0]});

            Transaction__c res = [SELECT Id, Description__c, Note__c FROM Transaction__c WHERE Id = :trans[0].Id];
            Account_Payable__c pay = [SELECT Id, Payee_Reference__c FROM Account_Payable__c WHERE Id = :testData.payables[0].Id];

            System.assertNotEquals(0, TransactionActions.queryTransactions(new Account_Payable_Line__c[]{testData.payableLines[0]}).size());
            System.assertEquals(NULL, res.Description__c);
            System.assertEquals(pay.Payee_Reference__c, res.Note__c);
        }

    }

    @IsTest
    public static void testPayableHLPDescription() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true);

        System.runAs(testData.users.get(1)) {
            Transaction__c res = [SELECT Id, Description__c, Note__c FROM Transaction__c WHERE Account_Payable__c = :testData.payables[0].Id LIMIT 1];
            Account_Payable__c pay = [SELECT Id, Payee_Reference__c FROM Account_Payable__c WHERE Id = :testData.payables[0].Id];

            System.assertEquals(pay.Payee_Reference__c, res.Description__c);
            System.assertEquals(pay.Payee_Reference__c, res.Note__c);
        }

    }

}