@isTest
private class AccountPayablePostHandlerTest {

    @testSetup
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
            testData.createPayables(true);
            //Validate that Posting Status field was removed from the set of unlocked fields after the end of posting routine
            System.assertEquals(false, TriggerObserver.getInstance().isUnlockedField(Account_Payable__c.Status__c));
            //Validate that originally unlocked field is still unlocked
            System.assertEquals(true, TriggerObserver.getInstance().isUnlockedField(Account.GL_Account_Variable_1__c));
        }
    }

    @IsTest
    private static void testPartialPosting() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Account_Payable__c testPayable1 = testData.payables.get(0);
            Account_Payable__c testPayable2 = testData.payables.get(1);

            testPayable1.Status__c = 'In Process';
            update testPayable1;

            Test.startTest();
            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            postHandler.post(new List<Account_Payable__c>{testPayable1, testPayable2});
            Test.stopTest();

            System.assertEquals(1, [SELECT count() FROM Account_Payable__c WHERE Status__c = 'Posted']);
        }
    } 
    
    @isTest
    private static void testPostPayableWithContactMapping() {
        TestDataSuite testData = TestDataSuite.getInstance().setLineLevelPost();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Account testAccount = [SELECT Id FROM Account LIMIT 1];
            Accounting_Period__c testAcctPeriod = [SELECT Id, Start_Date__c, End_Date__c FROM Accounting_Period__c ORDER BY Start_Date__c DESC LIMIT 1];
            Contact testContact = [SELECT Id FROM Contact WHERE FirstName = 'John'];
            GL_Account__c testGlAccount = [SELECT Id FROM GL_Account__c WHERE Type__c = 'Expense' LIMIT 1];

            Account_Payable__c testPayable = new Account_Payable__c(
                Payee_Reference__c = 'random-ref-xxx',
                Status__c = 'Approved',
                Payment_Status__c = 'Unpaid',
                Date__c = testAcctPeriod.Start_Date__c,
                Due_Date__c = testAcctPeriod.End_Date__c,
                Contact__c = testContact.Id,
                Accounting_Period__c = testAcctPeriod.Id
            );
            insert testPayable;

            Account_Payable_Line__c testAccountPayableLine = new Account_Payable_Line__c(
                Account_Payable__c = testPayable.Id,
                Amount__c = 100,
                Date__c = testAcctPeriod.Start_Date__c,
                Expense_GL_Account__c = testGlAccount.Id
            );
            insert testAccountPayableLine;

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> postResults = postHandler.post(new List<Account_Payable__c>{testPayable});

            Test.stopTest();

            System.assertEquals(
                true,
                postResults.get(0).isSuccess
            );

            List<Transaction__c> controlledTrans = [
                SELECT Id, Contact__c
                FROM Transaction__c
                WHERE Account_Payable_Line__c = :testAccountPayableLine.Id
                    AND GL_Account__c = :testGlAccount.Id
            ];

            System.assertEquals(
                false,
                controlledTrans.isEmpty()
            );

            System.assertEquals(
                testPayable.Contact__c,
                controlledTrans.get(0).Contact__c
            );
        }
    }

    @isTest
    private static void testNoPayableLinesPostError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            update testData.payables.get(0);
            delete testData.payableLines;

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new Account_Payable__c[]{testData.payables.get(0)});

            Test.stopTest();

            System.assertEquals(
                false,
                results.get(0).isSuccess
            );

            System.assertEquals(
                PostResult.StatusCode.NO_LINES,
                results.get(0).errors.get(0).statusCode
            );
        }
    }

    @isTest
    private static void testAccountingPeriodClosedPostError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            update testData.payables.get(0);

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods.get(0).Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods.get(0);

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new Account_Payable__c[]{testData.payables.get(0)});

            Test.stopTest();

            System.assertEquals(false, results.get(0).isSuccess);

            System.assertEquals(
                PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD,
                results.get(0).errors.get(0).statusCode
            );
        }
    }
    @isTest
    private static void testAccountingPeriodCloseInProgressPostError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            update testData.payables.get(0);

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods.get(0).Status__c = AccountingPeriodActions.CLOSE_INTERIM_STATUS;
            update testData.acctPeriods.get(0);

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new Account_Payable__c[]{testData.payables.get(0)});

            Test.stopTest();

            System.assertEquals(false, results.get(0).isSuccess);

            System.assertEquals(
                PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD,
                results.get(0).errors.get(0).statusCode
            );
        }
    }


    @isTest
    private static void testAlreadyPostedPostError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            update testData.payables.get(0);

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new Account_Payable__c[]{testData.payables.get(0)});

            System.assertEquals(
                true,
                results.get(0).isSuccess
            );

            postHandler.dispatcher.clearResultsMap();
            results = postHandler.post(new Account_Payable__c[]{testData.payables.get(0)});

            Test.stopTest();

            System.assertEquals(false, results.get(0).isSuccess);

            System.assertEquals(
                PostResult.StatusCode.ALREADY_POSTED,
                results.get(0).errors.get(0).statusCode
            );
        }
    }

    @isTest
    private static void testStatusNotApprovedPostError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        Account_Payable__c payable = testData.payables.get(0);
        payable.Status__c = 'In Process';
        update payable;

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new Account_Payable__c[]{payable});
            Test.stopTest();

            System.assertEquals(
                false,
                results.get(0).isSuccess
            );
            System.assertEquals(
                PostResult.StatusCode.STATUS_NOT_APPROVED,
                results.get(0).errors.get(0).statusCode
            );
        }
    }

    @isTest
    private static void testPostNoControlAPGLAccountError() {
        TestDataSuite testData = TestDataSuite.getInstance();
        delete [SELECT Id FROM GL_Account_Default__c WHERE GL_Account_Specification__c = :GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT];
        testData.createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            delete testData.settings;
            AccountingSettingsHandler.acctSeedSettings = null;

            testData.payables.get(0).Status__c = 'Approved';
            update testData.payables.get(0);

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new Account_Payable__c[]{testData.payables.get(0)});

            Test.stopTest();

            System.assertEquals(
                false,
                results.get(0).isSuccess
            );

            System.assertEquals(
                PostResult.StatusCode.NO_CONTROL_AP_ACCOUNT_DEFINED,
                results.get(0).errors.get(0).statusCode
            );
        }
    }

    @IsTest
    private static void testUnpostPayableInLLPModeSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Account_Payable__c testPayable = testData.payables[0];
            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> postResults = postHandler.unpost(new List<Account_Payable__c>{testPayable});
            System.assertEquals(true, postResults[0].isSuccess);
            List<Account_Payable_Line__c> testPayableLines = [
                SELECT Id, Account_Payable__c FROM Account_Payable_Line__c WHERE Account_Payable__c = :testPayable.Id
            ];
            System.assertEquals(true, TransactionActions.queryTransactions(testPayableLines).isEmpty());
        }
    }

    @IsTest
    private static void testUnpostPayableInHLPModeSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost()
            .createPayables(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Account_Payable__c testPayable = testData.payables[0];
            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> postResults = postHandler.unpost(new List<Account_Payable__c>{testPayable});
            System.assertEquals(true, postResults[0].isSuccess);
            List<Account_Payable_Line__c> testPayableLines = [
                SELECT Id, Account_Payable__c FROM Account_Payable_Line__c WHERE Account_Payable__c = :testPayable.Id
            ];
            System.assertEquals(true, TransactionActions.queryTransactions(testPayableLines, true).isEmpty());
        }
    }

    @IsTest
    private static void testPostHLPAndUnpostLLPSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost()
            .createPayables(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.setLineLevelPost();

            Account_Payable__c testPayable = testData.payables[0];
            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> postResults = postHandler.unpost(new List<Account_Payable__c>{testPayable});
            System.assertEquals(true, postResults[0].isSuccess);
            List<Account_Payable_Line__c> testPayableLines = [
                SELECT Id, Account_Payable__c FROM Account_Payable_Line__c WHERE Account_Payable__c = :testPayable.Id
            ];
            System.assertEquals(true, TransactionActions.queryTransactions(testPayableLines, true).isEmpty());
        }
    }

    @isTest
    private static void testUnpostAccountingPeriodCloseInProgressError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            update testData.payables.get(0);

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new Account_Payable__c[]{testData.payables.get(0)});

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods.get(0).Status__c = AccountingPeriodActions.CLOSE_INTERIM_STATUS;
            update testData.acctPeriods.get(0);

            postHandler.dispatcher.clearResultsMap();
            results = postHandler.unpost(new Account_Payable__c[]{testData.payables.get(0)});

            Test.stopTest();

            System.assertEquals(false, results.get(0).isSuccess);

            System.assertEquals(
                PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD,
                results.get(0).errors.get(0).statusCode
            );
        }
    }

    @isTest
    private static void testUnpostAccountingPeriodClosedError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            update testData.payables.get(0);

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new Account_Payable__c[]{testData.payables.get(0)});

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods.get(0).Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods.get(0);

            postHandler.dispatcher.clearResultsMap();
            results = postHandler.unpost(new Account_Payable__c[]{testData.payables.get(0)});

            Test.stopTest();

            System.assertEquals(false, results.get(0).isSuccess);

            System.assertEquals(
                PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD,
                results.get(0).errors.get(0).statusCode
            );
        }
    }

    @isTest
    private static void testNotPostedUnpostError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            testData.payables.get(0).Status__c = 'Approved';
            update testData.payables.get(0);

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.unpost(new List<Account_Payable__c>{testData.payables.get(0)});

            System.assertEquals(false, results.get(0).isSuccess);

            System.assertEquals(
                testData.payables.get(0).Status__c,
                [SELECT Id, Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Status__c
            );
        }
    }

    @isTest
    private static void testUnpostAPDisbursementsExist() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();
        Test.startTest();
        testData
            .createCashDisbursements()
            .createAPDisbursements();

        System.runAs(testData.users.get(1)) {
            AbstractPostHandler postHandler = new AccountPayablePostHandler();

            List<PostResult> results = postHandler.unpost(new Account_Payable__c[]{testData.payables.get(7)});
            System.assertEquals(true, results.get(0).isSuccess);
        }
        Test.stopTest();
    }

    @isTest
    private static void testUnpostAPCreditMemosExist() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Account_Payable__c testPayable = testData.payables.get(0);

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new List<Account_Payable__c>{testPayable});

            System.assertEquals(true, results.get(0).isSuccess);

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Id, Status__c FROM Account_Payable__c WHERE Id = :testPayable.Id].Status__c
            );

            AP_Credit_Memo__c apCreditMemo =  new AP_Credit_Memo__c();
            apCreditMemo.Accounting_Period__c = testData.acctPeriods.get(1).Id;
            apCreditMemo.Account_Payable_Invoice__c = testData.payables.get(0).Id;
            apCreditMemo.Account_Payable_Credit_Memo__c = testData.payables.get(4).Id;
            apCreditMemo.Amount__c = -10;
            insert apCreditMemo;

            postHandler.dispatcher.clearResultsMap();
            results = postHandler.unpost(new List<Account_Payable__c>{testData.payables.get(0)});

            System.assertEquals(true, results.get(0).isSuccess);

        }

    }


    @isTest
    private static void testUnpostPayableDiscountAmountPlusTotalZeroSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(3).Discount_Amount__c = [
                SELECT Id, Total__c
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(3).Id
            ].Total__c;
            update testData.payables.get(3);

            // post account payables
            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new Account_Payable__c[]{testData.payables.get(3)});

            System.assertEquals(
                true,
                results.get(0).isSuccess
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Id, Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(3).Id].Status__c
            );

            System.assertEquals(
                AccountPayableActions.PAYMENT_STATUS_UNPAID,
                [SELECT Id, Payment_Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(3).Id].Payment_Status__c
            );

            postHandler.dispatcher.clearResultsMap();
            results = postHandler.unpost(new Account_Payable__c[]{testData.payables.get(3)});

            Test.stopTest();

            System.assertEquals(
                true,
                results.get(0).isSuccess
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                [SELECT Id, Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(3).Id].Status__c
            );
        }
    }

    @isTest
    private static void testPostPayableNotApprovedError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
        
        Account_Payable__c payable = testData.payables.get(0);
        payable.Status__c = 'In Process';
        update payable;

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new Account_Payable__c[]{payable});
            Test.stopTest();

            System.assertEquals(
                PostResult.StatusCode.STATUS_NOT_APPROVED,
                results.get(0).errors.get(0).statusCode
            );
        }
    }

    @isTest
    private static void testPayablePostClosedAccountignPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            delete testData.payableLines;

            testData.payables.get(0).Status__c = 'Approved';
            update testData.payables.get(0);

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods.get(0).Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods.get(0);

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new List<Account_Payable__c>{testData.payables.get(0)});

            Test.stopTest();

            System.assertEquals(
                PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD,
                results.get(0).errors.get(0).statusCode
            );
        }
    }

    @isTest
    private static void testPayablePostInventoryVarianceNotExcludeAPCreditMemoSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setInventoryValuationStandardCost()
            .setLineLevelPost()
            .createPayables()
            .createProducts()
            .setERPEnabled();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            update testData.payables.get(0);

            delete testData.payableLines.get(1);
            delete testData.payableLines.get(2);
            testData.payableLines.get(0).Product__c = testData.products.get(0).Id;
            testData.payableLines.get(0).Amount__c = -5000;
            update testData.payableLines.get(0);
            System.assertEquals(TRUE,AccountingSettingsHandler.isInventoryValuationStandardCost());

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new List<Account_Payable__c>{testData.payables.get(0)});

            Test.stopTest();

            System.assertEquals(
                'Credit Memo',
                [SELECT Id, Type__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Type__c
            );

            System.assertEquals(
                3,
                [SELECT COUNT() FROM Transaction__c WHERE Account_Payable_Line__r.Account_Payable__c = :testData.payables.get(0).Id]
            );

            System.assertEquals(
                'Posted',
                [SELECT Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Status__c
            );

            System.assertEquals(
                0,
                [SELECT SUM(Amount__c) sum FROM Transaction__c WHERE Account_Payable_Line__r.Account_Payable__c = :testData.payables.get(0).Id GROUP BY Account_Payable_Line__r.Account_Payable__c].get(0).get('sum')
            );
        }
    }

    @isTest
    private static void testPayablePostInventoryVarianceStandardCostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setInventoryValuationStandardCost()
            .setLineLevelPost()
            .createPayables()
            .createProducts()
            .setERPEnabled();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            update testData.payables.get(0);

            delete testData.payableLines.get(1);
            delete testData.payableLines.get(2);
            testData.payableLines.get(0).Product__c = testData.products.get(0).Id;
            update testData.payableLines.get(0);

            System.assertEquals(true, AccountingSettingsHandler.isInventoryValuationStandardCost());
            System.assertEquals(true, AccountingSettingsHandler.isERPEnabled());

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new List<Account_Payable__c>{testData.payables.get(0)});

            Test.stopTest();

            System.assertEquals(
                3,
                [SELECT COUNT() FROM Transaction__c WHERE Account_Payable_Line__r.Account_Payable__c = :testData.payables.get(0).Id]
            );

            System.assertEquals(
                'Posted',
                [SELECT Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Status__c
            );

            System.assertEquals(
                0,
                [SELECT SUM(Amount__c) sum FROM Transaction__c WHERE Account_Payable_Line__r.Account_Payable__c = :testData.payables.get(0).Id GROUP BY Account_Payable_Line__r.Account_Payable__c].get(0).get('sum')
            );
        }
    }

    @isTest
    private static void testPayablePostInventoryVarianceStandardCostProductCostingDisabled() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableProductCosting()
            .setInventoryValuationStandardCost()
            .setLineLevelPost()
            .createPayables()
            .createProducts()
            .setERPEnabled();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            update testData.payables.get(0);

            delete testData.payableLines.get(1);
            delete testData.payableLines.get(2);
            testData.payableLines.get(0).Product__c = testData.products.get(0).Id;
            update testData.payableLines.get(0);

            System.assertEquals(true, AccountingSettingsHandler.isInventoryValuationStandardCost());
            System.assertEquals(true, AccountingSettingsHandler.isERPEnabled());
            System.assertEquals(false, AccountingSettingsHandler.isProductCostingEnabled());

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new List<Account_Payable__c>{testData.payables.get(0)});

            Test.stopTest();

            System.assertEquals(
                2,
                [SELECT COUNT() FROM Transaction__c WHERE Account_Payable_Line__r.Account_Payable__c = :testData.payables.get(0).Id]
            );

            System.assertEquals(
                'Posted',
                [SELECT Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Status__c
            );

            System.assertEquals(
                0,
                [SELECT SUM(Amount__c) sum FROM Transaction__c WHERE Account_Payable_Line__r.Account_Payable__c = :testData.payables.get(0).Id GROUP BY Account_Payable_Line__r.Account_Payable__c].get(0).get('sum')
            );
        }
    }

    @isTest
    private static void testPayablePostNoInventoryVarianceAverageCostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createPayables()
            .createProducts()
            .setInventoryValuationAverageCost()
            .setERPEnabled();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            update testData.payables.get(0);

            delete testData.payableLines.get(1);
            delete testData.payableLines.get(2);
            testData.payableLines.get(0).Product__c = testData.products.get(0).Id;
            update testData.payableLines.get(0);

            System.assertEquals(TRUE,AccountingSettingsHandler.isInventoryValuationAverageCost());
            System.assertEquals(TRUE,AccountingSettingsHandler.isERPEnabled());
            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new List<Account_Payable__c>{testData.payables.get(0)});

            Test.stopTest();

            System.assertEquals(
                2,
                [SELECT COUNT() FROM Transaction__c WHERE Account_Payable_Line__r.Account_Payable__c = :testData.payables.get(0).Id]
            );

            System.assertEquals(
                'Posted',
                [SELECT Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Status__c
            );

            System.assertEquals(
                0,
                [SELECT SUM(Amount__c) sum FROM Transaction__c WHERE Account_Payable_Line__r.Account_Payable__c = :testData.payables.get(0).Id GROUP BY Account_Payable_Line__r.Account_Payable__c].get(0).get('sum')
            );
        }
    }

    @isTest
    private static void testPayablePostVouchersPayableTransactionStandardCostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setInventoryValuationStandardCost()
            .setLineLevelPost()
            .createPayables()
            .createProducts()
            .setERPEnabled();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            update testData.payables.get(0);

            delete testData.payableLines.get(1);
            delete testData.payableLines.get(2);
            testData.payableLines.get(0).Product__c = testData.products.get(0).Id;
            update testData.payableLines.get(0);

            System.assertEquals(TRUE,AccountingSettingsHandler.isInventoryValuationStandardCost());
            System.assertEquals(TRUE,AccountingSettingsHandler.isERPEnabled());
            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new List<Account_Payable__c>{testData.payables.get(0)});

            Test.stopTest();

            System.assertEquals(
                3,
                [SELECT COUNT() FROM Transaction__c WHERE Account_Payable_Line__r.Account_Payable__c = :testData.payables.get(0).Id]
            );
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers[0].Id);
            System.assertEquals(
                defaultsBySpecDevNames.get(GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT)?.GL_Account__c,
                [SELECT GL_Account__c FROM Transaction__c WHERE Account_Payable_Line__c = :testData.payableLines.get(0).Id AND Amount__c > 0].GL_Account__c
            );

            System.assertEquals(
                'Posted',
                [SELECT Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Status__c
            );

            System.assertEquals(
                0,
                [SELECT SUM(Amount__c) sum FROM Transaction__c WHERE Account_Payable_Line__r.Account_Payable__c = :testData.payables.get(0).Id GROUP BY Account_Payable_Line__r.Account_Payable__c].get(0).get('sum')
            );
        }
    }

    @isTest
    private static void testPayablePostVouchersPayableTransactionAverageCostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createPayables()
            .createProducts()
            .setInventoryValuationAverageCost()
            .setERPEnabled();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            update testData.payables.get(0);

            delete testData.payableLines.get(1);
            delete testData.payableLines.get(2);
            testData.payableLines.get(0).Product__c = testData.products.get(0).Id;
            update testData.payableLines.get(0);

            System.assertEquals(TRUE,AccountingSettingsHandler.isInventoryValuationAverageCost());
            System.assertEquals(TRUE,AccountingSettingsHandler.isERPEnabled());
            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new List<Account_Payable__c>{testData.payables.get(0)});

            Test.stopTest();

            System.assertEquals(
                2,
                [SELECT COUNT() FROM Transaction__c WHERE Account_Payable_Line__r.Account_Payable__c = :testData.payables.get(0).Id]
            );
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers[0].Id);
            System.assertEquals(
                defaultsBySpecDevNames.get(GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT)?.GL_Account__c,
                [SELECT GL_Account__c FROM Transaction__c WHERE Account_Payable_Line__c = :testData.payableLines.get(0).Id AND Amount__c > 0].GL_Account__c
            );

            System.assertEquals(
                'Posted',
                [SELECT Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Status__c
            );

            System.assertEquals(
                0,
                [SELECT SUM(Amount__c) sum FROM Transaction__c WHERE Account_Payable_Line__r.Account_Payable__c = :testData.payables.get(0).Id GROUP BY Account_Payable_Line__r.Account_Payable__c].get(0).get('sum')
            );
        }
    }

    @isTest
    private static void testPayablePostAverageCostPayableLineAmountPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createPayables()
            .createProducts()
            .setInventoryValuationAverageCost()
            .setERPEnabled();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            delete testData.payableLines.get(1);
            delete testData.payableLines.get(2);
            testData.payableLines.get(0).Product__c = testData.products.get(0).Id;
            testData.payableLines.get(0).Amount__c = 30000;
            update testData.payableLines.get(0);

            System.assertEquals(true, AccountingSettingsHandler.isInventoryValuationAverageCost());
            System.assertEquals(true, AccountingSettingsHandler.isERPEnabled());

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new List<Account_Payable__c>{testData.payables.get(0)});
            System.assertEquals(true, results[0].isSuccess, (results[0].errors != NULL && !results[0].errors.isEmpty() ? results[0].errors[0].message : 'Payable has been posted'));

            System.assertNotEquals(
                [SELECT Unit_Cost__c FROM Product2 WHERE Id = :testData.products.get(0).Id].Unit_Cost__c,
                [SELECT Amount__c FROM Transaction__c WHERE Account_Payable_Line__c = :testData.payableLines.get(0).Id AND Amount__c > 0].Amount__c
            );

            System.assertEquals(
                30000,
                [SELECT Amount__c FROM Transaction__c WHERE Account_Payable_Line__c = :testData.payableLines.get(0).Id AND Amount__c > 0].Amount__c
            );

            System.assertEquals(
                2,
                [SELECT COUNT() FROM Transaction__c WHERE Account_Payable_Line__r.Account_Payable__c = :testData.payables.get(0).Id]
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Status__c
            );

            System.assertEquals(
                0,
                [SELECT SUM(Amount__c) sum FROM Transaction__c WHERE Account_Payable_Line__r.Account_Payable__c = :testData.payables.get(0).Id GROUP BY Account_Payable_Line__r.Account_Payable__c].get(0).get('sum')
            );
        }
    }

    @isTest
    private static void testPostBatchLineLimitWithoutInventoryVarianceError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().createProducts();
        testData.setInventoryValuationAverageCost();
        testData.setERPEnabled();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            List<Account_Payable__c> testPayables = new List<Account_Payable__c>();

            Account_Payable__c firstTestPayable = new Account_Payable__c(
                Id = testData.payables.get(0).Id,
                Status__c = 'Approved',
                Date__c = testData.payables.get(0).Date__c
            );
            testPayables.add(firstTestPayable);

            Account_Payable__c secondTestPayable = new Account_Payable__c(
                Id = testData.payables.get(1).Id,
                Status__c = 'Approved',
                Date__c = testData.payables.get(1).Date__c
            );
            testPayables.add(secondTestPayable);

            update testPayables;

            List<Account_Payable_Line__c> newLineList = new List<Account_Payable_Line__c>();
            Integer newLinesQuantity = AccountPayablePostHandler.PAYABLE_LINE_COUNT_NO_PRODUCT_COSTING_LIMIT / 2 + 1;//more than half

            String expenseGLAccountId = testData.glAccounts.get(16).Id;

            newLineList.addAll(createPayableLines(firstTestPayable.Id, null, firstTestPayable.Date__c, expenseGLAccountId, newLinesQuantity));
            newLineList.addAll(createPayableLines(secondTestPayable.Id, null, secondTestPayable.Date__c, expenseGLAccountId, newLinesQuantity));
            
            AccountPayableLineActions.isBypassGLAccountValidations = true;
            insert newLineList;
            AccountPayableLineActions.isBypassGLAccountValidations = false;

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(testPayables);

            Test.stopTest();

            String expectedErrorMessage = String.format(
                AccountPayablePostHandler.PAYABLE_LINE_COUNT_LIMIT_EXCEEDED_ERROR_MESSAGE,
                new List<String>{
                    String.valueOf(AccountPayablePostHandler.PAYABLE_LINE_COUNT_NO_PRODUCT_COSTING_LIMIT)
                }
            );

            System.assertEquals(
                expectedErrorMessage,
                results.get(0).errors.get(0).message
            );

            System.assertEquals(
                expectedErrorMessage,
                results.get(1).errors.get(0).message
            );
        }
    }

    @isTest
    private static void testPostBatchLineLimitWithInventoryVarianceError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().createProducts();
        testData.setInventoryValuationStandardCost();
        testData.setERPEnabled();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            List<Account_Payable__c> testPayables = new List<Account_Payable__c>();

            Account_Payable__c firstTestPayable = new Account_Payable__c(
                Id = testData.payables.get(0).Id,
                Status__c = 'Approved',
                Date__c = testData.payables.get(0).Date__c
            );
            testPayables.add(firstTestPayable);

            Account_Payable__c secondTestPayable = new Account_Payable__c(
                Id = testData.payables.get(1).Id,
                Status__c = 'Approved',
                Date__c = testData.payables.get(1).Date__c
            );
            testPayables.add(secondTestPayable);

            update testPayables;

            List<Account_Payable_Line__c> newLineList = new List<Account_Payable_Line__c>();
            Integer newLinesQuantity = AccountPayablePostHandler.PAYABLE_LINE_COUNT_PRODUCT_COSTING_LIMIT / 2 + 1;//more than half

            Product2 testProduct = testData.products.get(0);
            String expenseGLAccountId = testData.glAccounts.get(16).Id;

            newLineList.addAll(createPayableLines(firstTestPayable.Id, testProduct.Id, firstTestPayable.Date__c, expenseGLAccountId, newLinesQuantity));
            newLineList.addAll(createPayableLines(secondTestPayable.Id, testProduct.Id, secondTestPayable.Date__c, expenseGLAccountId, newLinesQuantity));

            AccountPayableLineActions.isBypassGLAccountValidations = true;
            insert newLineList;
            AccountPayableLineActions.isBypassGLAccountValidations = false;

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(testPayables);

            Test.stopTest();

            String expectedErrorMessage = String.format(
                AccountPayablePostHandler.PAYABLE_LINE_COUNT_LIMIT_EXCEEDED_ERROR_MESSAGE,
                new List<String>{
                    String.valueOf(AccountPayablePostHandler.PAYABLE_LINE_COUNT_PRODUCT_COSTING_LIMIT)
                }
            );

            System.assertEquals(
                expectedErrorMessage,
                results.get(0).errors.get(0).message
            );

            System.assertEquals(
                expectedErrorMessage,
                results.get(1).errors.get(0).message
            );
        }
    }

    @IsTest
    private static void testPostZeroTotalSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        Account_Payable__c payable = testData.payables[6];
        payable.Status__c = 'Approved';
        update payable;

        System.assertEquals(
            0.0,
            [SELECT Total__c FROM Account_Payable__c WHERE Id = :payable.Id].Total__c
        );

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new List<Account_Payable__c>{payable});
            Test.stopTest();

            System.assertEquals(true, results[0].isSuccess);
        }
    }

    //===================== Header Level Posting ===========================================

    @isTest
    private static void testPayableHeaderLevelPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new List<Account_Payable__c>{testData.payables.get(0)});

            System.assertEquals(true, results[0].isSuccess, (results[0].errors != NULL && !results[0].errors.isEmpty() ? results[0].errors[0].message : 'Payable has been posted'));

            System.assertEquals(
                2,
                [SELECT COUNT() FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id]
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Status__c
            );

            System.assertEquals(
                -165,
                [SELECT Amount__c FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id][0].Amount__c
            );

            System.assertEquals(
                165,
                [SELECT Amount__c FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id][1].Amount__c
            );
        }
    }

    @isTest
    private static void testPayableHeaderLevelPostRounding() {
        TestDataSuite testData = TestDataSuite.getInstance().setHeaderLevelPost();
        Test.startTest();
        testData.createPayables();
            
            //rounds to 1.24
            testData.payableLines.get(0).Amount__c = 1.244;
            update testData.payableLines.get(0);

            //rounds to 1.25
            testData.payableLines.get(1).Amount__c = 1.245;
            update testData.payableLines.get(1);

            testData.payableLines.get(2).Amount__c = 0;
            update testData.payableLines.get(2);

        System.runAs(testData.users.get(1)) {
            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new List<Account_Payable__c>{testData.payables.get(0)});
            Test.stopTest();

            System.assertEquals(
                2.49.abs(),
                [SELECT Amount__c FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id][0].Amount__c.abs()
            );

        }
    }

    @IsTest
    private static void testPayableHeaderLevelBatchPosting() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().setHeaderLevelPost();

        System.runAs(testData.users.get(1)) {
            Account_Payable__c testPayable1 = testData.payables.get(0);
            Account_Payable__c testPayable2 = testData.payables.get(1);

            Test.startTest();
            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            postHandler.post(new List<Account_Payable__c>{testPayable1, testPayable2});
            Test.stopTest();

            System.assertEquals(2, [SELECT count() FROM Account_Payable__c WHERE Status__c = 'Posted']);
            System.assertEquals(
                2,
            [SELECT COUNT() FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id]
            );

            System.assertEquals(
                2,
            [SELECT COUNT() FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(1).Id]
            );
        }
    }

    @isTest
    private static void testPayableHeaderLevelPostSeparateTransactionsByProduct() {
        TestDataSuite testData = TestDataSuite.getInstance().setHeaderLevelPost().createPayables().createProducts();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payableLines.get(0).Product__c = testData.products[0].Id;
            update testData.payableLines.get(0);

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new List<Account_Payable__c>{testData.payables.get(0)});

            System.assertEquals(true, results[0].isSuccess, (results[0].errors != NULL && !results[0].errors.isEmpty() ? results[0].errors[0].message : 'Payable has been posted'));

            System.assertEquals(
                3,
            [SELECT COUNT() FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id]
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Status__c
            );

            System.assertEquals(
                0,
                [SELECT SUM(Amount__c) sum FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id GROUP BY Account_Payable__c].get(0).get('sum')
            );
        }
    }

    @isTest
    private static void testPayableHeaderLevelPostSeparateTransactionsByProject() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost()
            .createPayables()
            .createProjects()
            .createProjectTasks();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payableLines.get(0).Project__c = testData.projects[0].Id;
            testData.payableLines.get(0).Project_Task__c = testData.projectTasks[0].Id;
            update testData.payableLines.get(0);

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new List<Account_Payable__c>{testData.payables.get(0)});

            System.assertEquals(true, results[0].isSuccess, (results[0].errors != NULL && !results[0].errors.isEmpty() ? results[0].errors[0].message : 'Payable has been posted'));

            System.assertEquals(
                3,
            [SELECT COUNT() FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id]
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Status__c
            );
            System.assertEquals(
                0,
                [SELECT SUM(Amount__c) sum FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id GROUP BY Account_Payable__c].get(0).get('sum')
            );
        }
    }

    @isTest
    private static void testPayableHeaderLevelPostSeparateTransactionsByProjectTask() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost()
            .createPayables()
            .createProjects()
            .createProjectTasks();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payableLines.get(0).Project__c = testData.projects[0].Id;
            testData.payableLines.get(0).Project_Task__c = testData.projectTasks[0].Id;
            testData.payableLines.get(1).Project__c = testData.projects[0].Id;
            testData.payableLines.get(1).Project_Task__c = testData.projectTasks[0].Id;
            testData.payableLines.get(2).Project__c = testData.projects[0].Id;
            testData.payableLines.get(2).Project_Task__c = testData.projectTasks[1].Id;
            update testData.payableLines;

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new List<Account_Payable__c>{testData.payables.get(0)});

            System.assertEquals(true, results[0].isSuccess, (results[0].errors != NULL && !results[0].errors.isEmpty() ? results[0].errors[0].message : 'Payable has been posted'));

            System.assertEquals(
                3,
            [SELECT COUNT() FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id]
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Status__c
            );
            System.assertEquals(
                0,
                [SELECT SUM(Amount__c) sum FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id GROUP BY Account_Payable__c].get(0).get('sum')
            );
        }
    }

    @isTest
    private static void testPayableHeaderLevelPostSeparateTransactionsByGLAccount() {
        TestDataSuite testData = TestDataSuite.getInstance().setHeaderLevelPost().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payableLines.get(0).Expense_GL_Account__c = testData.glAccounts[18].Id;
            testData.payableLines.get(1).Expense_GL_Account__c = testData.glAccounts[27].Id;
            update testData.payableLines;

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new List<Account_Payable__c>{testData.payables.get(0)});

            System.assertEquals(true, results[0].isSuccess, (results[0].errors != NULL && !results[0].errors.isEmpty() ? results[0].errors[0].message : 'Payable has been posted'));

            System.assertEquals(
                4,
            [SELECT COUNT() FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id]
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Status__c
            );
            System.assertEquals(
                0,
                [SELECT SUM(Amount__c) sum FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id GROUP BY Account_Payable__c].get(0).get('sum')
            );
        }
    }

    @isTest
    private static void testPayableHeaderLevelPostSeparateTransactionsByGLAV() {
        TestDataSuite testData = TestDataSuite.getInstance().setHeaderLevelPost().createPayables().createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payableLines.get(0).GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            testData.payableLines.get(1).GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            testData.payableLines.get(2).GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            update testData.payableLines;

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new List<Account_Payable__c>{testData.payables.get(0)});

            System.assertEquals(true, results[0].isSuccess, (results[0].errors != NULL && !results[0].errors.isEmpty() ? results[0].errors[0].message : 'Payable has been posted'));

            System.assertEquals(
                4,
            [SELECT COUNT() FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id]
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Status__c
            );
            System.assertEquals(
                0,
                [SELECT SUM(Amount__c) sum FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id GROUP BY Account_Payable__c].get(0).get('sum')
            );
        }
    }

    @isTest
    private static void testPayableHeaderLevelPostSuccessWithTax() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost();
        Test.startTest();
        testData.createTaxGroups()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            testData.payableLines.get(0).Tax_Group__c = testData.taxGroups[1].Id;
            testData.payableLines.get(1).Tax_Group__c = testData.taxGroups[1].Id;
            testData.payableLines.get(2).Tax_Group__c = testData.taxGroups[1].Id;
            update testData.payableLines;

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new List<Account_Payable__c>{testData.payables.get(0)});

            System.assertEquals(true, results[0].isSuccess, (results[0].errors != NULL && !results[0].errors.isEmpty() ? results[0].errors[0].message : 'Payable has been posted'));

            System.assertEquals(
                3,
            [SELECT COUNT() FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id]
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Status__c
            );

            System.assertEquals(
                -173.25,
                [SELECT Amount__c FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id][0].Amount__c
            );

            System.assertEquals(
                165,
                [SELECT Amount__c FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id][1].Amount__c
            );
            System.assertEquals(
                8.25,
                [SELECT Amount__c FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id][2].Amount__c
            );
        }
    }

    @isTest
    private static void testPayableHeaderLevelPostSuccessWithSeparateTaxTransactionByGLAccount() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost();
        Test.startTest();
        testData.createTaxGroups()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            testData.taxRates[1].Purchase_Tax_Expense_GL_Account__c = testData.glAccounts[6].Id;
            update testData.taxRates[1];

            testData.payableLines.get(0).Tax_Group__c = testData.taxGroups[1].Id;
            testData.payableLines.get(1).Tax_Group__c = testData.taxGroups[1].Id;
            testData.payableLines.get(2).Tax_Group__c = testData.taxGroups[2].Id;
            update testData.payableLines;

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new List<Account_Payable__c>{testData.payables.get(0)});

            System.assertEquals(true, results[0].isSuccess, (results[0].errors != NULL && !results[0].errors.isEmpty() ? results[0].errors[0].message : 'Payable has been posted'));

            System.assertEquals(
                4,
            [SELECT COUNT() FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id]
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Status__c
            );

            System.assertEquals(
                -171.95,
                [SELECT Amount__c FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id][0].Amount__c
            );

            System.assertEquals(
                165,
                [SELECT Amount__c FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id][1].Amount__c
            );
            System.assertEquals(
                5,
                [SELECT Amount__c FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id][2].Amount__c
            );
            System.assertEquals(
                1.95,
                [SELECT Amount__c FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id][3].Amount__c
            );
        }
    }

    @isTest
    private static void testPayableHeaderLevelPostSuccessWithSeparateTaxTransactionByGLAV() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost();
        Test.startTest();
        testData.createTaxGroups()
            .createAccountingVariables()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            testData.payableLines.get(0).Tax_Group__c = testData.taxGroups[1].Id;
            testData.payableLines.get(1).Tax_Group__c = testData.taxGroups[1].Id;
            testData.payableLines.get(2).Tax_Group__c = testData.taxGroups[1].Id;

            testData.payableLines.get(0).GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            testData.payableLines.get(1).GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            testData.payableLines.get(2).GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            update testData.payableLines;

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new List<Account_Payable__c>{testData.payables.get(0)});

            System.assertEquals(true, results[0].isSuccess, (results[0].errors != NULL && !results[0].errors.isEmpty() ? results[0].errors[0].message : 'Payable has been posted'));

            System.assertEquals(
                7,
            [SELECT COUNT() FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id]
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Status__c
            );

            System.assertEquals(
                -173.25,
                [SELECT Amount__c FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id][0].Amount__c
            );

            System.assertEquals(
                45,
                [SELECT Amount__c FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id][1].Amount__c
            );
            System.assertEquals(
                55,
                [SELECT Amount__c FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id][2].Amount__c
            );
            System.assertEquals(
                65,
                [SELECT Amount__c FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id][3].Amount__c
            );
            System.assertEquals(
                2.25,
                [SELECT Amount__c FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id][4].Amount__c
            );
            System.assertEquals(
                2.75,
                [SELECT Amount__c FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id][5].Amount__c
            );
            System.assertEquals(
                3.25,
                [SELECT Amount__c FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id][6].Amount__c
            );
        }
    }

    @isTest
    private static void testPayableHeaderLevelPostSuccessWithTaxReverseCharge() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost();
        Test.startTest();
        testData.createTaxGroups()
            .createPayables()
            .setAvaVATSelected();

        System.runAs(testData.users.get(1)) {
            testData.payableLines.get(0).Tax_Group__c = testData.taxGroups[3].Id;
            testData.payableLines.get(1).Tax_Group__c = testData.taxGroups[3].Id;
            testData.payableLines.get(2).Tax_Group__c = testData.taxGroups[3].Id;
            update testData.payableLines;

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new List<Account_Payable__c>{testData.payables.get(0)});

            System.assertEquals(true, results[0].isSuccess, (results[0].errors != NULL && !results[0].errors.isEmpty() ? results[0].errors[0].message : 'Payable has been posted'));

            System.assertEquals(
                4,
            [SELECT COUNT() FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id]
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Status__c
            );

            System.assertEquals(
                -165,
                [SELECT Amount__c FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id][0].Amount__c
            );

            System.assertEquals(
                165,
                [SELECT Amount__c FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id][1].Amount__c
            );
            System.assertEquals(
                -33.00,
                [SELECT Amount__c FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id][2].Amount__c
            );
            System.assertEquals(
                33.00,
                [SELECT Amount__c FROM Transaction__c WHERE Account_Payable__c = :testData.payables.get(0).Id][3].Amount__c
            );
        }
    }

    @isTest
    private static void testLedgerWithEmptyTaxSettingError() {
        TestDataSuite testData = TestDataSuite.getInstance().setHeaderLevelPost().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Ledger__c selectedLedger = LedgerHandler.getInstanceWithSharing(true).getLedgerById(testData.ledgers[0].Id);
            selectedLedger.Tax_Settings__c = null;
            update selectedLedger;

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new List<Account_Payable__c>{testData.payables.get(0)});

            System.assertEquals(false, results[0].isSuccess, TaxService.getNoTaxSettingErrorMessage(false));
        }
    }

    @isTest
    private static void testPostWithSoftClosedAcctPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            update testData.payables.get(0);

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods.get(0).Close_AP__c = true;
            update testData.acctPeriods.get(0);

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new Account_Payable__c[]{testData.payables.get(0)});

            Test.stopTest();

            Assert.isFalse(results.get(0).isSuccess);
            Assert.areEqual(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD, results.get(0).errors.get(0).statusCode );
            
        }
    }

    @isTest
    private static void testRoundingTaxAmountAdjustment() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost();
        Test.startTest();
        testData.createTaxGroups()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            Tax_Group__c tg = new Tax_Group__c (
                Name = 'TaxGroupNew',
                Tax_Type__c = 'Sales and Purchase'
            );
            insert tg;

            List<Tax_Rate__c> taxRates = new List<Tax_Rate__c>();
            taxRates.add(
                new Tax_Rate__c(
                    Name = 'TR1',
                    Tax_Group__c = tg.Id,
                    Tax_Rate__c = 4.9,
                    Sales_Tax_Liability_GL_Account__c = testData.glAccounts[7].Id,
                    Purchase_Tax_Expense_GL_Account__c = testData.glAccounts[24].Id
                )
            );

            taxRates.add(
                new Tax_Rate__c(
                    Name = 'TR2',
                    Tax_Group__c = tg.Id,
                    Tax_Rate__c = 5.1,
                    Sales_Tax_Liability_GL_Account__c = testData.glAccounts[6].Id,
                    Purchase_Tax_Expense_GL_Account__c = testData.glAccounts[23].Id
                )
            );
            insert taxRates;

            Account_Payable__c newPay = testData.payables[0].clone();
            newPay.Payee_Reference__c = 'test2';
            insert newPay;

            Account_Payable_Line__c newPayLine =  testData.payableLines.get(0).clone();
            newPayLine.Account_Payable__c = newPay.Id;
            newPayLine.Tax_Group__c = tg.Id;
            newPayLine.Amount__c = 455;
            newPayLine.Quantity__c = 1;
            insert newPayLine;

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new List<Account_Payable__c>{newPay});

            System.assertEquals(true, results[0].isSuccess, (results[0].errors != NULL && !results[0].errors.isEmpty() ? results[0].errors[0].message : 'Payable has been posted'));

            System.assertEquals(
                4,
                [SELECT COUNT() FROM Transaction__c WHERE Account_Payable__c = :newPay.Id]
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Account_Payable__c WHERE Id = :newPay.Id].Status__c
            );

            System.assertEquals(
                -500.5,
                [SELECT Amount__c FROM Transaction__c WHERE Account_Payable__c = :newPay.Id][0].Amount__c
            );

            System.assertEquals(
                455,
                [SELECT Amount__c FROM Transaction__c WHERE Account_Payable__c = :newPay.Id][1].Amount__c
            );
            System.assertEquals(
                22.30,
                [SELECT Amount__c FROM Transaction__c WHERE Account_Payable__c = :newPay.Id][2].Amount__c
            );
            System.assertEquals(
                23.20,
                [SELECT Amount__c FROM Transaction__c WHERE Account_Payable__c = :newPay.Id][3].Amount__c
            );
        }
    }

    @IsTest
    private static void testTaxInclusiveTaxGroupRounding() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost();
        Test.startTest();
        testData.createTaxGroups()
            .createPayables(false);

        System.runAs(testData.users[1]) {
            // setup tax groups
            Tax_Group__c taxGroup = testData.taxGroups[1].clone(false, true, false, false);
            taxGroup.Tax_Inclusive__c = true;
            insert taxGroup;

            GL_Account__c taxAccount1 = testData.glAccounts[23].clone(false, true, false, false);
            taxAccount1.Name = '11111-Purchase Tax 1';
            GL_Account__c taxAccount2 = testData.glAccounts[23].clone(false, true, false, false);
            taxAccount1.Name = '11112-Purchase Tax 2';
            List<GL_Account__c> taxAccounts = new List<GL_Account__c>{ taxAccount1, taxAccount2 };
            insert taxAccounts;

            Tax_Rate__c taxRate1 = testData.taxRates[1].clone(false, true, false, false);
            taxRate1.Name = 'TaxRate1';
            taxRate1.Tax_Group__c = taxGroup.Id;
            taxRate1.Tax_Rate__c = 9.031;
            taxRate1.Purchase_Tax_Expense_GL_Account__c = taxAccounts[0].Id;
            Tax_Rate__c taxRate2 = testData.taxRates[1].clone(false, true, false, false);
            taxRate2.Name = 'TaxRate2';
            taxRate2.Tax_Group__c = taxGroup.Id;
            taxRate2.Tax_Rate__c = 5.468;
            taxRate2.Purchase_Tax_Expense_GL_Account__c = taxAccounts[1].Id;
            insert new List<Tax_Rate__c>{ taxRate1, taxRate2 };

            taxGroup = [SELECT Id, Combined_Tax_Rate__c, (SELECT Purchase_Tax_Expense_GL_Account__c FROM Tax_Rates__r) FROM Tax_Group__c WHERE Id = :taxGroup.Id];

            // setup payable and lines
            Account_Payable__c payable = testData.payables[0];
            Account_Payable_Line__c line = testData.payableLines[0];

            line.Quantity__c = 70;
            line.Unit_Cost__c = 3.35;
            line.Tax_Group__c = taxGroup.Id;

            update line;
            delete new List<Account_Payable_Line__c>{ testData.payableLines[1], testData.payableLines[2] };
            
            line = [SELECT Id, Tax_Amount__c, Amount__c, Sub_Total__c, Expense_GL_Account__c FROM Account_Payable_Line__c WHERE Id = :line.Id];

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new List<Account_Payable__c>{payable});
            
            // payable posted successfully
            Assert.isTrue(results[0].isSuccess);

            // payable total tax should be sum of tax from all lines
            payable = [SELECT Id, Purchase_Tax3__c, Total__c, Sub_Total__c FROM Account_Payable__c WHERE Id = :payable.Id];
            Assert.areEqual(line.Tax_Amount__c, payable.Purchase_Tax3__c);

            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            Id apControlAccount = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;

            List<Transaction__c> txns = [SELECT Amount__c, GL_Account__c, GL_Account__r.Name FROM Transaction__c WHERE Account_Payable__c = :payable.Id];
            Decimal txnTax = 0;
            for (Transaction__c txn : txns) {
                if  (txn.GL_Account__c == taxGroup.Tax_Rates__r[0].Purchase_Tax_Expense_GL_Account__c 
                        || txn.GL_Account__c == taxGroup.Tax_Rates__r[1].Purchase_Tax_Expense_GL_Account__c) {
                    txnTax += txn.Amount__c;
                } else if (txn.GL_Account__c == line.Expense_GL_Account__c) {
                    Assert.areEqual(payable.Sub_Total__c, txn.Amount__c);
                } else if (txn.GL_Account__c == apControlAccount) {
                    Assert.areEqual(payable.Total__c * -1, txn.Amount__c);
                } else {
                    Assert.fail('Unexpected GL Account: ' + txn.GL_Account__r.Name);
                }
            }
            // total taxes from payable should equal total taxes from txns
            Assert.areEqual(payable.Purchase_Tax3__c, txnTax);

            Test.stopTest();
        }
    }

    @IsTest
    private static void testTaxInclusiveTaxGroupRounding_MC() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        try {
            testData.enableMultiCurrency();
        } catch(TestDataSuite.TestDataSuiteException ex) {
            //skip this test if MC is not enabled
            return;
        }

        testData.setHeaderLevelPost()
            .createTaxGroups()
            .createPayables(false);

        System.runAs(testData.users[1]) {
            String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
            if (String.isBlank(newCurrencyIsoCode)) {
                return;
            }

            // setup tax groups
            Tax_Group__c taxGroup = testData.taxGroups[1].clone(false, true, false, false);
            taxGroup.Tax_Inclusive__c = true;
            insert taxGroup;

            GL_Account__c taxAccount1 = testData.glAccounts[23].clone(false, true, false, false);
            taxAccount1.Name = '11111-Purchase Tax 1';
            GL_Account__c taxAccount2 = testData.glAccounts[23].clone(false, true, false, false);
            taxAccount1.Name = '11112-Purchase Tax 2';
            List<GL_Account__c> taxAccounts = new List<GL_Account__c>{ taxAccount1, taxAccount2 };
            insert taxAccounts;

            Tax_Rate__c taxRate1 = testData.taxRates[1].clone(false, true, false, false);
            taxRate1.Name = 'TaxRate1';
            taxRate1.Tax_Group__c = taxGroup.Id;
            taxRate1.Tax_Rate__c = 9.031;
            taxRate1.Purchase_Tax_Expense_GL_Account__c = taxAccounts[0].Id;
            Tax_Rate__c taxRate2 = testData.taxRates[1].clone(false, true, false, false);
            taxRate2.Name = 'TaxRate2';
            taxRate2.Tax_Group__c = taxGroup.Id;
            taxRate2.Tax_Rate__c = 5.468;
            taxRate2.Purchase_Tax_Expense_GL_Account__c = taxAccounts[1].Id;
            insert new List<Tax_Rate__c>{ taxRate1, taxRate2 };

            taxGroup = [SELECT Id, Combined_Tax_Rate__c, (SELECT Purchase_Tax_Expense_GL_Account__c FROM Tax_Rates__r) FROM Tax_Group__c WHERE Id = :taxGroup.Id];

            // setup payable and lines
            Account_Payable__c payable = testData.payables[0].clone(false, true, false, false);
            payable.Payee_Reference__c = 'p92w48gflaiouhgfp9w';
            payable.put('CurrencyIsoCode', newCurrencyIsoCode);
            insert payable;

            Account_Payable_Line__c line = testData.payableLines[0].clone(false, true, false, false);
            line.Account_Payable__c = payable.Id;
            line.Quantity__c = 70;
            line.Unit_Cost__c = 3.35;
            line.Tax_Group__c = taxGroup.Id;
            line.put('CurrencyIsoCode', newCurrencyIsoCode);
            insert line;
            
            line = [SELECT Id, Tax_Amount__c, Amount__c, Sub_Total__c FROM Account_Payable_Line__c WHERE Id = :line.Id];

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new List<Account_Payable__c>{payable});
            
            // payable posted successfully
            Assert.isTrue(results[0].isSuccess);

            // payable total tax should be sum of tax from all lines
            payable = [SELECT Id, Purchase_Tax3__c, Total__c FROM Account_Payable__c WHERE Id = :payable.Id];
            Assert.areEqual(line.Tax_Amount__c, payable.Purchase_Tax3__c);

            List<Transaction__c> txns = [SELECT Amount__c, GL_Account__c, Currency_Conversion_Rate__c FROM Transaction__c WHERE Account_Payable__c = :payable.Id];
            Decimal txnTotal = 0;
            Decimal txnTax = 0;
            Decimal conversionRate = 1;
            for (Transaction__c txn : txns) {
                if  (txn.GL_Account__c == taxGroup.Tax_Rates__r[0].Purchase_Tax_Expense_GL_Account__c 
                        || txn.GL_Account__c == taxGroup.Tax_Rates__r[1].Purchase_Tax_Expense_GL_Account__c) {
                    txnTax += txn.Amount__c;
                    conversionRate = txn.Currency_Conversion_Rate__c;
                }
                txnTotal += Math.abs(txn.Amount__c);
            }
            // total taxes from payable should equal total taxes from txns
            Assert.areEqual((payable.Purchase_Tax3__c / conversionRate).setScale(2, RoundingMode.HALF_UP), txnTax);

            Test.stopTest();
        }
    }

    @IsTest
    private static void testCashBasisPostHLPSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Account_Payable__c testPayable = testData.payables[0];
            testPayable.Ledger__c = testData.ledgers[3].Id;
            testPayable.Status__c = 'Approved';
            update testPayable;

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> postResults = postHandler.post(new List<Account_Payable__c>{testPayable});
            System.assertEquals(true, postResults[0].isSuccess);
            System.assert([SELECT Id FROM Transaction__c WHERE Account_Payable__c = :testPayable.Id].isEmpty());
        }
    }

    //======================================================================================
    //===================== UTILITY METHODS =================================================
    //======================================================================================

    private static List<Account_Payable_Line__c> createPayableLines(String masterId, String productId, Date masterDate, String glAccountId, Integer quantity) {
        List<Account_Payable_Line__c> result = new List<Account_Payable_Line__c>();

        for (Integer i = 0; i < quantity; i++) {
            Account_Payable_Line__c tempPL = new Account_Payable_Line__c(
                Account_Payable__c = masterId,
                Amount__c = 10 + i,
                Date__c = masterDate,
                Expense_GL_Account__c = glAccountId,
                Product__c = productId
            );
            result.add(tempPL);
        }

        return result;
    }

}