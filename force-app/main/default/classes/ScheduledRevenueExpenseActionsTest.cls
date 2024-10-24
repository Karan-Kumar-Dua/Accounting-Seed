@IsTest
private class ScheduledRevenueExpenseActionsTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testDebitGLAccountIsRequired() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Scheduled_Revenue_Expense__c testAmortizationEntry = new Scheduled_Revenue_Expense__c(
                Name = 'Test Rev 1',
                Amount__c = 400,
                Credit_GL_Account__c = testData.glAccounts[6].Id,
                Debit_GL_Account__c = NULL,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Status__c = 'Approved'
            );

            //INSERT scenario
            DmlException dmlEx;
            try {
                insert testAmortizationEntry;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));

            //INSERT with no errors
            testAmortizationEntry.Debit_GL_Account__c = testData.glAccounts[16].Id;
            dmlEx = NULL;
            try {
                insert testAmortizationEntry;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);

            //UPDATE scenario
            dmlEx = NULL;
            try {
                testAmortizationEntry.Debit_GL_Account__c = NULL;
                update testAmortizationEntry;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testCreditGLAccountIsRequired() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Scheduled_Revenue_Expense__c testAmortizationEntry = new Scheduled_Revenue_Expense__c(
                Name = 'Test Rev 1',
                Amount__c = 400,
                Credit_GL_Account__c = NULL,
                Debit_GL_Account__c = testData.glAccounts[16].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Status__c = 'Approved'
            );

            //INSERT scenario
            DmlException dmlEx;
            try {
                insert testAmortizationEntry;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));

            //INSERT with no errors
            testAmortizationEntry.Credit_GL_Account__c = testData.glAccounts[6].Id;
            dmlEx = NULL;
            try {
                insert testAmortizationEntry;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);

            //UPDATE scenario
            dmlEx = NULL;
            try {
                testAmortizationEntry.Credit_GL_Account__c = NULL;
                update testAmortizationEntry;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testPreventMoreThanOneSourceLookup() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings()
            .createPayables()
            .createScheduledRevenueExpense()
            .createFixedAssets();

        System.runAs(testData.users.get(1)) {
            Scheduled_Revenue_Expense__c sre = [
                SELECT Id, Billing__c, Fixed_Asset__c, Account_Payable__c, Status__c
                FROM Scheduled_Revenue_Expense__c
                WHERE Id = :testData.scheduledRevenues[0].Id
            ];

            System.assertEquals('Posted', sre.Status__c);

            AbstractPostHandler postHandler = new ScheduledRevenueExpensePostHandler();
            List<PostResult> postResults = postHandler.unpost(new List<Scheduled_Revenue_Expense__c>{sre});
            System.assertEquals(true, postResults[0].isSuccess);

            sre.Billing__c = testData.billings[0].Id;
            sre.Account_Payable__c = testData.payables[0].Id;
            sre.Fixed_Asset__c = testData.fixedAssets[0].Id;

            DMLException dmlEx;
            try {
                update sre;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(ScheduledRevenueExpenseActions.MULTIPLE_SOURCE_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testPreventUpdateActionPostedChangeSourceLookup() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, [
                    SELECT Accounting_Period__r.Status__c, Status__c
                    FROM Scheduled_Revenue_Expense__c
                    WHERE Id = :testData.scheduledRevenues[0].Id
                ].Status__c
            );
            // Test update with error since Billing Lookup field was changed.
            Scheduled_Revenue_Expense__c sre = [
                SELECT Billing__c
                FROM Scheduled_Revenue_Expense__c
                WHERE Id = :testData.scheduledRevenues[0].Id
            ];
            sre.Billing__c = testData.billings[1].Id;

            DMLException dmlEx;
            try {
                update sre;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            SourceDocumentUpdateFieldValidator sfu = new ScheduledRevExpenseFieldUpdateValidator();
            System.assertEquals(
                String.format(
                    SourceDocumentUpdateFieldValidator.POSTED_UPDATE_ERROR,
                    new List<String>{
                        sfu.formatFieldStrings(sfu.lockedUpdateFieldsPosted),
                        AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED
                    }
                ),
                dmlEx.getDMLMessage(0)
            );
        }

    }

    @IsTest
    private static void testPreventUpdateActionPostedNoChangeSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            System.assertEquals(
                'Posted', [
                    SELECT Accounting_Period__r.Status__c, Status__c
                    FROM Scheduled_Revenue_Expense__c
                    WHERE Id = :testData.scheduledRevenues[0].Id
                ].Status__c
            );

            DMLException dmlEx;

            // Test update no error since no fields changed.
            Scheduled_Revenue_Expense__c sre = [
                SELECT Accounting_Period__r.Status__c, Status__c
                FROM Scheduled_Revenue_Expense__c
                WHERE Id = :testData.scheduledRevenues[0].Id
            ];

            try {
                update sre;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
        }

    }
    
    @IsTest
    private static void testPreventUpdateActionPostedNoChangeSetScaleSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            AbstractPostHandler postHandler = new ScheduledRevenueExpensePostHandler();
            List<PostResult> postResults =
                postHandler.unpost(new List<Scheduled_Revenue_Expense__c>{testData.scheduledRevenues[0]});
            System.assertEquals(true, postResults[0].isSuccess);
            testData.scheduledRevenues[0].Amount__c = 100.45678945;
            update testData.scheduledRevenues[0];

            postResults =
                postHandler.post(new List<Scheduled_Revenue_Expense__c>{testData.scheduledRevenues[0]});

            System.assertEquals(true, postResults[0].isSuccess);

            // Test update no error since no fields changed.
            Scheduled_Revenue_Expense__c sre = [
                SELECT Accounting_Period__r.Status__c, Status__c
                FROM Scheduled_Revenue_Expense__c
                WHERE Id = :testData.scheduledRevenues[0].Id
            ];

            DMLException dmlEx;
            try {
                sre.Amount__c = 100.46;
                update sre;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
        }

    }
    
    @IsTest
    private static void testPreventDeleteLineActionPosted() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createJournalEntries(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            DMLException dmlEx;
            try {
                delete testData.journalEntryLines;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.POSTED_DELETE_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testScheduledRevenueExpensePostedDeleteError() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            System.assertEquals(
                'Posted', [
                    SELECT Accounting_Period__r.Status__c, Status__c
                    FROM Scheduled_Revenue_Expense__c
                    WHERE Id = :testData.scheduledRevenues[0].Id
                ].Status__c
            );

            DMLException dmlEx;
            try {
                delete testData.scheduledRevenues[0];
            }
            catch(DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.POSTED_DELETE_ERROR, dmlEx.getDmlMessage(0));
        }

    }
    
    @IsTest
    private static void testScheduleRevenueExpensePostedDeleteSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT  Accounting_Period__c,
                        Accounting_Period__r.Name,
                        Name,
                        Description__c,
                        GL_Account_Variable_1__c,
                        GL_Account_Variable_2__c,
                        GL_Account_Variable_3__c,
                        Project__c,
                        Project_Task__c,
                        Credit_GL_Account__c,
                        Debit_GL_Account__c,
                        GL_Account_Variable_4__c,
                        Amount__c
                FROM Scheduled_Revenue_Expense__c
                WHERE Id IN :testData.scheduledRevenues
            ]);
            setController.setSelected(setController.getRecords());

            ScheduledRevenueExpensePostTransaction sce = new ScheduledRevenueExpensePostTransaction(setController);
            // Test post functionality
            sce.unpost();

            System.assertEquals(
                'Approved', [
                    SELECT Accounting_Period__r.Status__c, Status__c
                    FROM Scheduled_Revenue_Expense__c
                    WHERE Id = :testData.scheduledRevenues[0].Id
                ].Status__c
            );

            delete testData.scheduledRevenues;

            System.assertEquals(
                0,
                [SELECT count() FROM Scheduled_Revenue_Expense__c WHERE Id = :testData.scheduledRevenues[0].Id]
            );
        }

    }

    @IsTest
    private static void testNotDefaultProductFieldsForNonFixedAsset() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProducts()
            .createAccountingVariables()
            .createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.products[0].GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            testData.products[0].GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            testData.products[0].GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            testData.products[0].GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update testData.products[0];

            Scheduled_Revenue_Expense__c sre = testData.scheduledRevenues[0].clone(false, true);
            sre.Product__c = testData.products[0].Id;
            insert sre;

            System.assertNotEquals(
                testData.products[0].GL_Account_Variable_1__c, [
                    SELECT GL_Account_Variable_1__c
                    FROM Scheduled_Revenue_Expense__c
                    WHERE Id = :sre.Id
                ].GL_Account_Variable_1__c
            );

            System.assertNotEquals(
                testData.products[0].GL_Account_Variable_2__c, [
                    SELECT GL_Account_Variable_2__c
                    FROM Scheduled_Revenue_Expense__c
                    WHERE Id = :sre.Id
                ].GL_Account_Variable_2__c
            );

            System.assertNotEquals(
                testData.products[0].GL_Account_Variable_3__c, [
                    SELECT GL_Account_Variable_3__c
                    FROM Scheduled_Revenue_Expense__c
                    WHERE Id = :sre.Id
                ].GL_Account_Variable_3__c
            );

            System.assertNotEquals(
                testData.products[0].GL_Account_Variable_4__c, [
                    SELECT GL_Account_Variable_4__c
                    FROM Scheduled_Revenue_Expense__c
                    WHERE Id = :sre.Id
                ].GL_Account_Variable_4__c
            );
        }

    }

    @IsTest
    private static void testDefaultProductFieldsDefaultForFixedAsset() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProducts()
            .createAccountingVariables()
            .createScheduledRevenueExpense()
            .createFixedAssets();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.products[0].GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            testData.products[0].GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            testData.products[0].GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            testData.products[0].GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update testData.products[0];

            Scheduled_Revenue_Expense__c sre = testData.scheduledRevenues[0].clone(false, true);
            sre.Product__c = testData.products[0].Id;
            sre.Fixed_Asset__c = testData.fixedAssets[0].Id;
            insert sre;

            System.assertEquals(
                testData.products[0].GL_Account_Variable_1__c, [
                    SELECT GL_Account_Variable_1__c
                    FROM Scheduled_Revenue_Expense__c
                    WHERE Id = :sre.Id
                ].GL_Account_Variable_1__c
            );

            System.assertEquals(
                testData.products[0].GL_Account_Variable_2__c, [
                    SELECT GL_Account_Variable_2__c
                    FROM Scheduled_Revenue_Expense__c
                    WHERE Id = :sre.Id
                ].GL_Account_Variable_2__c
            );

            System.assertEquals(
                testData.products[0].GL_Account_Variable_3__c, [
                    SELECT GL_Account_Variable_3__c
                    FROM Scheduled_Revenue_Expense__c
                    WHERE Id = :sre.Id
                ].GL_Account_Variable_3__c
            );

            System.assertEquals(
                testData.products[0].GL_Account_Variable_4__c, [
                    SELECT GL_Account_Variable_4__c
                    FROM Scheduled_Revenue_Expense__c
                    WHERE Id = :sre.Id
                ].GL_Account_Variable_4__c
            );
        }

    }

    @IsTest
    private static void testDefaultProductFieldsNoDefault() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProducts()
            .createAccountingVariables()
            .createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.products[0].GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            testData.products[0].GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            testData.products[0].GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            testData.products[0].GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update testData.products[0];

            Scheduled_Revenue_Expense__c sre = testData.scheduledRevenues[0].clone(false, true);
            sre.GL_Account_Variable_1__c=testData.accountingVariables1[1].Id;
            sre.GL_Account_Variable_2__c=testData.accountingVariables2[1].Id;
            sre.GL_Account_Variable_3__c=testData.accountingVariables3[1].Id;
            sre.GL_Account_Variable_4__c=testData.accountingVariables4[1].Id;
            sre.Product__c = testData.products[0].Id;
            insert sre;

            System.assertEquals(
                testData.accountingVariables1[1].Id, [
                    SELECT GL_Account_Variable_1__c
                    FROM Scheduled_Revenue_Expense__c
                    WHERE Id = :sre.Id
                ].GL_Account_Variable_1__c
            );

            System.assertEquals(
                testData.accountingVariables2[1].Id, [
                    SELECT GL_Account_Variable_2__c
                    FROM Scheduled_Revenue_Expense__c
                    WHERE Id = :sre.Id
                ].GL_Account_Variable_2__c
            );

            System.assertEquals(
                testData.accountingVariables3[1].Id, [
                    SELECT GL_Account_Variable_3__c
                    FROM Scheduled_Revenue_Expense__c
                    WHERE Id = :sre.Id
                ].GL_Account_Variable_3__c
            );

            System.assertEquals(
                testData.accountingVariables4[1].Id, [
                    SELECT GL_Account_Variable_4__c
                    FROM Scheduled_Revenue_Expense__c
                    WHERE Id = :sre.Id
                ].GL_Account_Variable_4__c
            );
        }

    }

    @IsTest
    private static void testNotPopulateDefaultGlavsFromAccountForNonFixedAsset() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables()
            .createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Account testAccount = new Account(
                Name = 'Test Account With GLAVs',
                Accounting_Active__c = true,
                Accounting_Type__c = 'Customer and Vendor',
                GL_Account_Variable_1__c = testData.accountingVariables1[0].Id,
                GL_Account_Variable_2__c = testData.accountingVariables2[0].Id,
                GL_Account_Variable_3__c = testData.accountingVariables3[0].Id,
                GL_Account_Variable_4__c = testData.accountingVariables4[0].Id
            );

            insert testAccount;

            Scheduled_Revenue_Expense__c sre = testData.scheduledRevenues[0].clone(false, true);
            sre.Account2__c = testAccount.Id;

            insert sre;

            System.assertNotEquals(
                testData.accountingVariables1[0].Id, [
                    SELECT GL_Account_Variable_1__c
                    FROM Scheduled_Revenue_Expense__c
                    WHERE Id = :sre.Id
                ].GL_Account_Variable_1__c
            );

            System.assertNotEquals(
                testData.accountingVariables2[0].Id, [
                    SELECT GL_Account_Variable_2__c
                    FROM Scheduled_Revenue_Expense__c
                    WHERE Id = :sre.Id
                ].GL_Account_Variable_2__c
            );

            System.assertNotEquals(
                testData.accountingVariables3[0].Id, [
                    SELECT GL_Account_Variable_3__c
                    FROM Scheduled_Revenue_Expense__c
                    WHERE Id = :sre.Id
                ].GL_Account_Variable_3__c
            );

            System.assertNotEquals(
                testData.accountingVariables4[0].Id, [
                    SELECT GL_Account_Variable_4__c
                    FROM Scheduled_Revenue_Expense__c
                    WHERE Id = :sre.Id
                ].GL_Account_Variable_4__c
            );
        }

    }

    @IsTest
    private static void testPopulateDefaultGlavsFromAccountForFixedAsset() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables()
            .createScheduledRevenueExpense()
            .createFixedAssets();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Account testAccount = new Account(
                Name = 'Test Account With GLAVs',
                Accounting_Active__c = true,
                Accounting_Type__c = 'Customer and Vendor',
                GL_Account_Variable_1__c = testData.accountingVariables1[0].Id,
                GL_Account_Variable_2__c = testData.accountingVariables2[0].Id,
                GL_Account_Variable_3__c = testData.accountingVariables3[0].Id,
                GL_Account_Variable_4__c = testData.accountingVariables4[0].Id
            );

            insert testAccount;

            Scheduled_Revenue_Expense__c sre = testData.scheduledRevenues[0].clone(false, true);
            sre.Account2__c = testAccount.Id;
            sre.Fixed_Asset__c = testData.fixedAssets[0].Id;

            insert sre;

            System.assertEquals(
                testData.accountingVariables1[0].Id, [
                    SELECT GL_Account_Variable_1__c
                    FROM Scheduled_Revenue_Expense__c
                    WHERE Id = :sre.Id
                ].GL_Account_Variable_1__c
            );

            System.assertEquals(
                testData.accountingVariables2[0].Id, [
                    SELECT GL_Account_Variable_2__c
                    FROM Scheduled_Revenue_Expense__c
                    WHERE Id = :sre.Id
                ].GL_Account_Variable_2__c
            );

            System.assertEquals(
                testData.accountingVariables3[0].Id, [
                    SELECT GL_Account_Variable_3__c
                    FROM Scheduled_Revenue_Expense__c
                    WHERE Id = :sre.Id
                ].GL_Account_Variable_3__c
            );

            System.assertEquals(
                testData.accountingVariables4[0].Id, [
                    SELECT GL_Account_Variable_4__c
                    FROM Scheduled_Revenue_Expense__c
                    WHERE Id = :sre.Id
                ].GL_Account_Variable_4__c
            );
        }

    }

    @IsTest
    private static void testSetPreventUpdateStatusFieldPostedError() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            AbstractPostHandler postHandler = new ScheduledRevenueExpensePostHandler();
            List<PostResult> postResults =
                postHandler.unpost(new List<Scheduled_Revenue_Expense__c>{testData.scheduledRevenues[0]});

            System.assertEquals(true, postResults[0].isSuccess);

            DMLException dmlEx = NULL;
            try {
                testData.scheduledRevenues[0].Status__c = 'Posted';
                update testData.scheduledRevenues[0];
            }
            catch(DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.UPDATE_STATUS_ERROR, dmlEx.getDMLMessage(0));
        }

    }

    @IsTest
    private static void testSetLedgerFromSourceRecord() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Scheduled_Revenue_Expense__c sre = [
                SELECT Id, Billing__c, Fixed_Asset__c, Account_Payable__c, Status__c
                FROM Scheduled_Revenue_Expense__c
                WHERE Id = :testData.scheduledRevenues[0].Id
            ];

            System.assertEquals('Posted', sre.Status__c);

            AbstractPostHandler postHandler = new ScheduledRevenueExpensePostHandler();
            List<PostResult> postResults = postHandler.unpost(new List<Scheduled_Revenue_Expense__c>{sre});
            System.assertEquals(true, postResults[0].isSuccess);

            sre = [
                SELECT Id, Billing__c, Fixed_Asset__c, Account_Payable__c, Status__c
                FROM Scheduled_Revenue_Expense__c
                WHERE Id = :testData.scheduledRevenues[0].Id
            ];
            sre.Billing__c = testData.billings[0].Id;
            update sre;

            System.assertEquals(
                testData.ledgers[0].Id,
                [SELECT Id, Ledger__c FROM Scheduled_Revenue_Expense__c WHERE Id = :sre.Id].Ledger__c
            );
        }

    }

    @IsTest
    private static void testSetLedgerDifferentSourceLedgerError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Scheduled_Revenue_Expense__c sre = [
                SELECT Id, Billing__c, Fixed_Asset__c, Account_Payable__c, Status__c
                FROM Scheduled_Revenue_Expense__c
                WHERE Id = :testData.scheduledRevenues[0].Id
            ];

            System.assertEquals('Posted', sre.Status__c);

            AbstractPostHandler postHandler = new ScheduledRevenueExpensePostHandler();
            List<PostResult> postResults = postHandler.unpost(new List<Scheduled_Revenue_Expense__c>{sre});
            System.assertEquals(true, postResults[0].isSuccess);

            DMLException dmlEx;

            sre = [
                SELECT Id, Billing__c, Fixed_Asset__c, Account_Payable__c, Status__c, Ledger__c
                FROM Scheduled_Revenue_Expense__c
                WHERE Id = :testData.scheduledRevenues[0].Id
            ];
            sre.Billing__c = testData.billings[0].Id;
            sre.Ledger__c = testData.ledgers[2].Id;
            try {
                update sre;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(
                    ScheduledRevenueExpenseActions.SAME_SOURCE_LEDGER_ERROR,
                    new List<String> {SObjectType.Billing__c.getLabel()}
                ),
                dmlEx.getDmlMessage(0)
            );
        }

    }

    @IsTest
    private static void testScheduledRevenueExpenseNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            try {
                Scheduled_Revenue_Expense__c scr = new Scheduled_Revenue_Expense__c();
                insert scr;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

    @IsTest
    private static void testScheduledRevenueExpenseNoNullPointerExceptionInsert_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency();

                System.runAs(testData.users.get(1)) {
                DMLException dmlEx;
                try {
                    Scheduled_Revenue_Expense__c scr = new Scheduled_Revenue_Expense__c();
                    insert scr;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }
                System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    private static void testNormalizeNumericAndCurrencyFieldsInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {

            Scheduled_Revenue_Expense__c sre = new Scheduled_Revenue_Expense__c(
                Name = 'Test Rev 1',
                Credit_GL_Account__c = testData.glAccounts[11].Id,
                Debit_GL_Account__c = testData.glAccounts[16].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Status__c = 'Scheduled',
                Amount__c = 20.989342348934,
                Quantity__c = 10.236746723674344
            );

            insert sre;

            Scheduled_Revenue_Expense__c newSre = [
                SELECT Id,
                    Amount__c,
                    Quantity__c
                FROM Scheduled_Revenue_Expense__c
                WHERE Id = : sre.Id];

            System.assertEquals(20.99, newSre.Amount__c);
            System.assertEquals(10.236747, newSre.Quantity__c);
        }

    }

    @IsTest
    private static void testNormalizeNumericAndCurrencyFieldsUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Scheduled_Revenue_Expense__c.Amount__c,
                    Scheduled_Revenue_Expense__c.Quantity__c,
                    Scheduled_Revenue_Expense__c.Status__c
                }
            );
            testData.scheduledRevenues[0].Amount__c = 20.989342348934;
            testData.scheduledRevenues[0].Quantity__c = 10.236746723674344;

            update testData.scheduledRevenues[0];

            Scheduled_Revenue_Expense__c newSre = [
                SELECT Id, Amount__c, Quantity__c
                FROM Scheduled_Revenue_Expense__c
                WHERE Id = : testData.scheduledRevenues[0].Id
            ];

            System.assertEquals(20.99, newSre.Amount__c);
            System.assertEquals(10.236747, newSre.Quantity__c);
        }

    }

    @IsTest
    private static void testPostOnInsertSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Scheduled_Revenue_Expense__c testAE = new Scheduled_Revenue_Expense__c(
                Name = 'Test Rev 1',
                Amount__c = 400,
                Credit_GL_Account__c = testData.glAccounts[6].Id,
                Debit_GL_Account__c = testData.glAccounts[16].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Status__c = 'Approved'
            );

            DmlException dmlEx;
            try {
                insert testAE;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Scheduled_Revenue_Expense__c WHERE Id = :testAE.Id].Status__c
            );
        }

    }

    @IsTest
    private static void testSetDefaultFieldsStatus() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            String defaultStatus = FinancialSuiteUtils.getDefaultPostingStatus(Scheduled_Revenue_Expense__c.Status__c);

            // test In Process
            Scheduled_Revenue_Expense__c ae = new Scheduled_Revenue_Expense__c(
                Status__c = 'In Process'
            );
            ScheduledRevenueExpenseActions.setDefaultFields(new List<Scheduled_Revenue_Expense__c>{ae});
            Assert.areEqual('In Process', ae.Status__c);

            // test Approved
            ae.Status__c = 'Approved';
            ScheduledRevenueExpenseActions.setDefaultFields(new List<Scheduled_Revenue_Expense__c>{ae});
            Assert.areEqual('Approved', ae.Status__c);

            // test Posted
            ae.Status__c = 'Posted';
            ScheduledRevenueExpenseActions.setDefaultFields(new List<Scheduled_Revenue_Expense__c>{ae});
            Assert.areEqual(defaultStatus, ae.Status__c);

            // test blank
            ae.Status__c = '';
            ScheduledRevenueExpenseActions.setDefaultFields(new List<Scheduled_Revenue_Expense__c>{ae});
            Assert.areEqual(defaultStatus, ae.Status__c);

            // test null
            ae.Status__c = null;
            ScheduledRevenueExpenseActions.setDefaultFields(new List<Scheduled_Revenue_Expense__c>{ae});
            Assert.areEqual(defaultStatus, ae.Status__c);

            // test other
            ae.Status__c = 'Other';
            ScheduledRevenueExpenseActions.setDefaultFields(new List<Scheduled_Revenue_Expense__c>{ae});
            Assert.areEqual('Other', ae.Status__c);
        }
    }

}