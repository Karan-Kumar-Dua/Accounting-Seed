@IsTest
public class CashReceiptPostHandlerTest {

    @TestSetup
    public static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testPurgeUnlockedPostingStatusFieldOnly() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {

            //Put some field into set of unlocked fields just to check it later
            TriggerObserver.getInstance().unlockField(Account.GL_Account_Variable_1__c);
            //create and post records
            testData.createCashReceipts();
            //Validate that Posting Status field was removed from the set of unlocked fields after the end of posting routine
            System.assertEquals(false, TriggerObserver.getInstance().isUnlockedField(Cash_Receipt__c.Status__c));
            //Validate that originally unlocked field is still unlocked
            System.assertEquals(true, TriggerObserver.getInstance().isUnlockedField(Account.GL_Account_Variable_1__c));
        }
    }

    @IsTest
    private static void testPartialPosting() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            Cash_Receipt__c testCR1 = testData.cashReceipts.get(1);
            Cash_Receipt__c testCR2 = testData.cashReceipts.get(2);

            System.assertEquals(
                2, [
                    SELECT count()
                    FROM Cash_Receipt__c
                    WHERE Status__c = 'Posted'
                    AND (Id = :testCR1.Id OR Id = :testCR2.Id)
                ]
            ); 

            AbstractPostHandler postHandler = new CashReceiptPostHandler();
            postHandler.unpost(new List<Cash_Receipt__c>{testCR1, testCR2});

            System.assertEquals(
                0, [
                    SELECT count()
                    FROM Cash_Receipt__c
                    WHERE Status__c = 'Posted'
                    AND (Id = :testCR1.Id OR Id = :testCR2.Id)
                ]
            );

            //close first period
            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods.get(0).Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods.get(0);

            postHandler = new CashReceiptPostHandler();
            postHandler.post(new List<Cash_Receipt__c>{testCR1, testCR2});

            System.assertEquals(
                1, [
                SELECT count()
                FROM Cash_Receipt__c
                WHERE Status__c = 'Posted'
                AND (Id = :testCR1.Id OR Id = :testCR2.Id)
            ]);
        }
    }
    
    @IsTest
    public static void testCashReceiptPostWhenThereIsCashFlowNonConformity() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Cash_Receipt__c testCR = testData.cashReceipts[0];

            AbstractPostHandler postHandler = new CashReceiptPostHandler();
            List<PostResult> results = postHandler.unpost(new List<Cash_Receipt__c>{testCR});

            System.assertEquals('Approved', [SELECT Status__c FROM Cash_Receipt__c WHERE Id = :testCR.Id].Status__c);
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Cash_Receipt__c = :testCR.Id]);

            //populate Cash Flow Category
            testData.createCashFlowCategories(false);
            testCR.Cash_Flow_Category__c = testData.cashFlowCategories[0].Id;
            update testCR;

            postHandler.dispatcher.clearResultsMap();
            results = postHandler.post(new List<Cash_Receipt__c>{testCR});

            System.assertEquals(false, results[0].isSuccess);
        }

    }

    @IsTest
    public static void testCashReceiptPostControlAccountError() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Cash_Receipt__c testCR = testData.cashReceipts[0];

            AbstractPostHandler postHandler = new CashReceiptPostHandler();
            List<PostResult> results = postHandler.unpost(new List<Cash_Receipt__c>{testCR});

            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Cash_Receipt__c = :testCR.Id]);

            delete [SELECT Id FROM GL_Account_Default__c WHERE GL_Account_Specification__c = :GLAccountDefaultsHandler.UNAPPLIED_CASH_GL_ACCOUNT];
            GLAccountDefaultsHandler.instance = null;

            Test.startTest();
            postHandler.dispatcher.clearResultsMap();
            results = postHandler.post(new List<Cash_Receipt__c>{testCR});
            Test.stopTest();

            System.assertEquals(PostResult.StatusCode.NO_UNAPPLIED_CASH_CONTROL_ACCOUNT_DEFINED, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testCashReceiptPostPeriodClosedError() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Cash_Receipt__c testCR = testData.cashReceipts[0];

            AbstractPostHandler postHandler = new CashReceiptPostHandler();
            List<PostResult> results = postHandler.unpost(new List<Cash_Receipt__c>{testCR});

            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Cash_Receipt__c = :testCR.Id]);

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[1].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[1];

            Test.startTest();
            postHandler.dispatcher.clearResultsMap();
            results = postHandler.post(new List<Cash_Receipt__c>{testCR});
            Test.stopTest();

            System.assertEquals(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testCashReceiptPostPeriodSoftClosedError() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Cash_Receipt__c testCR = testData.cashReceipts[0];

            AbstractPostHandler postHandler = new CashReceiptPostHandler();
            List<PostResult> results = postHandler.unpost(new List<Cash_Receipt__c>{testCR});

            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Cash_Receipt__c = :testCR.Id]);

            Accounting_Period__c testAcctPeriod = testData.acctPeriods[1];
            testAcctPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
            testAcctPeriod.close_AR__c = true;
            update testAcctPeriod;

            Test.startTest();
            postHandler.dispatcher.clearResultsMap();
            results = postHandler.post(new List<Cash_Receipt__c>{testCR});
            Test.stopTest();

            System.assertEquals(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testCashReceiptUnpostPeriodClosedError() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[1].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[1];

            Cash_Receipt__c testCR = testData.cashReceipts[0];
            Test.startTest();
            AbstractPostHandler postHandler = new CashReceiptPostHandler();
            List<PostResult> results = postHandler.unpost(new List<Cash_Receipt__c>{testCR});
            Test.stopTest();

            System.assertEquals(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testCashReceiptUnpostBillingCashReceiptError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Accounting_Period__c = testData.acctPeriods[1].Id;
            bcr.Billing__c = testData.billings[0].Id;
            bcr.Cash_Receipt__c = testData.cashReceipts[0].Id;
            bcr.Applied_Amount__c = 5;
            insert bcr;

            Cash_Receipt__c testCR = testData.cashReceipts[0];
            AbstractPostHandler postHandler = new CashReceiptPostHandler();
            List<PostResult> results = postHandler.unpost(new List<Cash_Receipt__c>{testCR});
            Test.stopTest();

            System.assertEquals(PostResult.StatusCode.BILLING_CASH_RECEIPTS_EXIST, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testCashReceiptUnpostBankReconciliationError() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts().createBankReconciliations();

        System.runAs(testData.users[1]) {
            testData.cashReceipts[0].Bank_Reconciliation__c = testData.bankReconciliations[0].Id;
            testData.cashReceipts[0].Status__c = 'Posted';
            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Bank_Reconciliation__c,
                    Cash_Receipt__c.Status__c
                }
            );
            update testData.cashReceipts[0];

            Cash_Receipt__c testCR = testData.cashReceipts[0];
            Test.startTest();
            AbstractPostHandler postHandler = new CashReceiptPostHandler();
            List<PostResult> results = postHandler.unpost(new List<Cash_Receipt__c>{testCR});
            Test.stopTest();

            System.assertEquals(PostResult.StatusCode.CLEARED_BANK_RECONCILIATION, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testCashReceiptUnpostBankDepositError() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts().createBankDeposits();

        System.runAs(testData.users[1]) {
            testData.cashReceipts[0].Bank_Deposit__c = testData.bankDeposits[0].Id;
            testData.cashReceipts[0].Status__c = 'Posted';

            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Bank_Deposit__c,
                    Cash_Receipt__c.Status__c
                }
            );
            update testData.cashReceipts[0];

            Cash_Receipt__c testCR = testData.cashReceipts[0];
            Test.startTest();
            AbstractPostHandler postHandler = new CashReceiptPostHandler();
            List<PostResult> results = postHandler.unpost(new List<Cash_Receipt__c>{testCR});
            Test.stopTest();

            System.assertEquals(PostResult.StatusCode.CLEARED_BANK_DEPOSIT, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testCashReceiptInsertPost() {
        // Cash receipts must be posted when inserted
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.assertEquals(2, [SELECT count() FROM Transaction__c WHERE Cash_Receipt__c = :testData.cashReceipts[0].Id]);
        System.assertEquals('Posted', [SELECT Status__c FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id].Status__c);
    }

    @IsTest
    public static void testCashReceiptPost() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Cash_Receipt__c testCR = testData.cashReceipts[0];

            AbstractPostHandler postHandler = new CashReceiptPostHandler();
            List<PostResult> results = postHandler.unpost(new List<Cash_Receipt__c>{testCR});

            System.assertEquals('Approved', [SELECT Status__c FROM Cash_Receipt__c WHERE Id = :testCR.Id].Status__c);
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Cash_Receipt__c = :testCR.Id]);

            postHandler.dispatcher.clearResultsMap();
            results = postHandler.post(new List<Cash_Receipt__c>{testCR});
            Test.stopTest();

            System.assertEquals(2, [SELECT count() FROM Transaction__c WHERE Cash_Receipt__c = :testCR.Id]);
            System.assertEquals('Posted', [SELECT Status__c FROM Cash_Receipt__c WHERE Id = :testCR.Id].Status__c);
        }

    }

    @IsTest
    public static void testCashReceiptUnpost() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Cash_Receipt__c testCR = testData.cashReceipts[0];
            Test.startTest();
            AbstractPostHandler postHandler = new CashReceiptPostHandler();
            List<PostResult> results = postHandler.unpost(new List<Cash_Receipt__c>{testCR});
            Test.stopTest();

            System.assertEquals('Approved', [SELECT Status__c FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id].Status__c);
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Cash_Receipt__c = :testData.cashReceipts[0].Id]);
        }

    }

    @IsTest
    public static void testCashReceiptBatchPostNoSelectionClosedPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Cash_Receipt__c testCR = testData.cashReceipts[0];

            AbstractPostHandler postHandler = new CashReceiptPostHandler();
            List<PostResult> results = postHandler.unpost(new List<Cash_Receipt__c>{testCR});

            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Cash_Receipt__c = :testCR.Id]);

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[1].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[1];

            Test.startTest();
            postHandler.dispatcher.clearResultsMap();
            results = postHandler.post(new List<Cash_Receipt__c>{testCR});
            Test.stopTest();

            System.assertEquals(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testCashReceiptBatchPostNoSelectionNoControlAccountError() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Cash_Receipt__c testCR = testData.cashReceipts[0];

            AbstractPostHandler postHandler = new CashReceiptPostHandler();
            List<PostResult> results = postHandler.unpost(new List<Cash_Receipt__c>{testCR});

            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Cash_Receipt__c = :testCR.Id]);

            delete [SELECT Id FROM GL_Account_Default__c WHERE GL_Account_Specification__c = :GLAccountDefaultsHandler.UNAPPLIED_CASH_GL_ACCOUNT];
            GLAccountDefaultsHandler.instance = null;

            Test.startTest();
            postHandler.dispatcher.clearResultsMap();
            results = postHandler.post(new List<Cash_Receipt__c>{testCR});
            Test.stopTest();

            System.assertEquals(PostResult.StatusCode.NO_UNAPPLIED_CASH_CONTROL_ACCOUNT_DEFINED, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testCashReceiptBatchPost() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            AbstractPostHandler postHandler = new CashReceiptPostHandler();
            List<PostResult> results = postHandler.unpost(testData.cashReceipts);

            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Cash_Receipt__c IN :testData.cashReceipts]);

            Test.startTest();
            postHandler.dispatcher.clearResultsMap();
            results = postHandler.post(testData.cashReceipts);
            Test.stopTest();

            System.assertEquals(6, [SELECT count() FROM Transaction__c WHERE Cash_Receipt__c IN :testData.cashReceipts]);
        }

    }

    @IsTest
    public static void testCashReceiptBatchUnpostNoSelectionClosedPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[1].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[1];

            Test.startTest();
            AbstractPostHandler postHandler = new CashReceiptPostHandler();
            List<PostResult> results = postHandler.unpost(testData.cashReceipts);
            Test.stopTest();

            System.assertEquals(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testCashReceiptBatchUnpostNoSelectionBankReconciliationError() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts().createBankReconciliations();

        System.runAs(testData.users[1]) {
            testData.cashReceipts[0].Bank_Reconciliation__c = testData.bankReconciliations[0].Id;
            testData.cashReceipts[0].Status__c = 'Posted';

            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Bank_Reconciliation__c,
                    Cash_Receipt__c.Status__c
                }
            );
            update testData.cashReceipts[0];

            Test.startTest();
            AbstractPostHandler postHandler = new CashReceiptPostHandler();
            List<PostResult> results = postHandler.unpost(testData.cashReceipts);
            Test.stopTest();

            System.assertEquals(PostResult.StatusCode.CLEARED_BANK_RECONCILIATION, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testCashReceiptBatchUnpostNoSelectionBankDepositError() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts().createBankDeposits();

        System.runAs(testData.users[1]) {
            testData.cashReceipts[0].Bank_Deposit__c = testData.bankDeposits[0].Id;
            testData.cashReceipts[0].Status__c = 'Posted';

            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Bank_Deposit__c,
                    Cash_Receipt__c.Status__c
                }
            );
            update testData.cashReceipts[0];

            Test.startTest();
            AbstractPostHandler postHandler = new CashReceiptPostHandler();
            List<PostResult> results = postHandler.unpost(testData.cashReceipts);
            Test.stopTest();

            System.assertEquals(PostResult.StatusCode.CLEARED_BANK_DEPOSIT, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testCashReceiptBatchUnpost() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            AbstractPostHandler postHandler = new CashReceiptPostHandler();
            List<PostResult> results = postHandler.unpost(testData.cashReceipts);
            Test.stopTest();

            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Cash_Receipt__c IN :testData.cashReceipts]);
        }

    }

    @IsTest
    public static void testCashReceiptPostZeroAmountSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Cash_Receipt__c cashReceipt = new Cash_Receipt__c(
                Account__c = testData.accounts.get(0).Id,
                Amount__c = 0,
                Payment_Reference__c = '0000000432',
                Status__c = 'In Process',
                Receipt_Date__c = testData.acctPeriods.get(0).Start_Date__c,
                Accounting_Period__c = testData.acctPeriods.get(0).Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = testData.glAccounts.get(0).Id
            );
            insert cashReceipt;
            Test.stopTest();

            System.assertEquals('In Process', [SELECT Status__c FROM Cash_Receipt__c WHERE Id = :cashReceipt.Id LIMIT 1].Status__c);
        }

    }

    //=============================================================================
    //===== Group of test methods related to the Multi Currency functionality =====
    //=============================================================================

    @IsTest
    public static void testCashReceiptPost_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createCashReceipts();

            System.runAs(testData.users[1]) {
                Test.startTest();
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                // Need to unpost to start test as cash receipts are auto posted when created
                Cash_Receipt__c testCR = [
                    SELECT  Id,
                            Accounting_Period__r.Status__c,
                            Status__c,
                            Number_of_Billing_Cash_Receipts__c
                    FROM Cash_Receipt__c
                    WHERE Id = :testData.cashReceipts[0].Id LIMIT 1
                ];

                AbstractPostHandler postHandler = new CashReceiptPostHandler();
                List<PostResult> results = postHandler.unpost(new List<Cash_Receipt__c>{testCR});

                System.assertEquals(true, results[0].isSuccess);
                System.assertEquals(
                    AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                    [SELECT Status__c FROM Cash_Receipt__c WHERE Id = :testCR.Id].Status__c
                );
                System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Cash_Receipt__c = :testCR.Id]);

                //set currency not equal to Default Ledger currency
                testCR = [SELECT Id FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id LIMIT 1];
                testCR.put('CurrencyIsoCode', newCurrencyIsoCode);
                update testCR;

                //Check new currency was set up properly
                String crCurrencyISOCode = (String) Database.query(
                    'SELECT CurrencyIsoCode ' +
                    'FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Cash_Receipt__c ' +
                    'WHERE Id = \'' + String.escapeSingleQuotes(testCR.Id) + '\' '
                )[0].get('CurrencyIsoCode');
                System.assertEquals(newCurrencyIsoCode, crCurrencyISOCode);

                //Check if currency Conversion Rate was set properly
                testCR = [SELECT Id, Currency_Conversion_Rate__c FROM Cash_Receipt__c WHERE Id = :testCR.Id LIMIT 1];
                System.assertEquals(false, testCR.Currency_Conversion_Rate__c == NULL);

                // Test post cash receipts
                postHandler.dispatcher.clearResultsMap();
                results = postHandler.post(new List<Cash_Receipt__c>{testCR});

                //check results
                List<Transaction__c> newTransactions = [
                    SELECT Id, Foreign_Amount__c, Foreign_Currency__c, Currency_Conversion_Rate__c, Amount__c
                    FROM Transaction__c
                    WHERE Cash_Receipt__c = :testCR.Id
                    AND Foreign_Amount__c != NULL
                    AND Foreign_Currency__c != NULL
                    AND Currency_Conversion_Rate__c != NULL
                ];
                Test.stopTest();

                System.assertEquals(2, newTransactions.size());
                System.assertEquals('Posted', [SELECT Status__c FROM Cash_Receipt__c WHERE Id = :testCR.Id].Status__c);
                System.assertEquals(0, [SELECT sum(Amount__c) sum FROM Transaction__c WHERE Cash_Receipt__c = :testCR.Id GROUP BY Cash_Receipt__c][0].get('sum'));
                System.assertEquals(newCurrencyIsoCode, [SELECT Foreign_Currency__c FROM Transaction__c WHERE Cash_Receipt__c = :testCR.Id][0].Foreign_Currency__c);
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    private static void testProductInTransaction() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createCashReceipts()
                .createProducts();

        System.runAs(testData.users[1]) {
            Cash_Receipt__c testCR1         = testData.cashReceipts.get(1);
            AbstractPostHandler postHandler = new CashReceiptPostHandler();

            postHandler.unpost(new List<Cash_Receipt__c>{testCR1});

            testCR1.Product__c = testData.products.get(0).Id;
            update testCR1;

            postHandler.post(new List<Cash_Receipt__c>{testCR1});

            System.assertEquals(
                    true,
                    [SELECT count() FROM Transaction__c WHERE Product__c =: testData.products.get(0).Id] > 0
            );
        }
    }

    @IsTest
    public static void testNoteInTransactionWithCheckNumber() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Integer checkNo = 1001;
            Cash_Receipt__c testCashReceipt = new Cash_Receipt__c(
                Account__c = testData.accounts.get(0).Id,
                Amount__c = 0,
                Payment_Reference__c = '0000000432',
                Status__c = 'In Process',
                Receipt_Date__c = testData.acctPeriods.get(0).Start_Date__c,
                Accounting_Period__c = testData.acctPeriods.get(0).Id,
                Purpose__c = 'Customer Receipt',
                Check_Number__c = checkNo,
                Bank_Account__c = testData.glAccounts.get(0).Id 
            );
            insert testCashReceipt;

            Test.startTest();
            AbstractPostHandler postHandler = new CashReceiptPostHandler();
            postHandler.post(new List<Cash_Receipt__c>{testCashReceipt});

            Test.stopTest();
            List<Transaction__c> trans = [SELECT Id, Note__c, Cash_Receipt__c FROM Transaction__c WHERE Cash_Receipt__c =: testCashReceipt.Id];
            for(Transaction__c tran : trans){
                System.assertEquals(String.valueOf(checkNo), tran.Note__c, 'Note value is not matching with Check Number for transaction with Id :'+tran.Id);
            }
        }
    }

    @IsTest
    public static void testNoteInTransactionWithReference() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            String payReference = '0000000432';
            Cash_Receipt__c testCashReceipt = new Cash_Receipt__c(
                Account__c = testData.accounts.get(0).Id,
                Amount__c = 0,
                Payment_Reference__c = payReference,
                Status__c = 'In Process',
                Receipt_Date__c = testData.acctPeriods.get(0).Start_Date__c,
                Accounting_Period__c = testData.acctPeriods.get(0).Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = testData.glAccounts.get(0).Id 
            );
            insert testCashReceipt;

            Test.startTest();
            AbstractPostHandler postHandler = new CashReceiptPostHandler();
            postHandler.post(new List<Cash_Receipt__c>{testCashReceipt});

            Test.stopTest();
            List<Transaction__c> trans = [SELECT Id, Note__c, Cash_Receipt__c FROM Transaction__c WHERE Cash_Receipt__c =: testCashReceipt.Id];
            for(Transaction__c tran : trans){
                System.assertEquals(payReference, tran.Note__c, 'Note value is not matching with Reference for transaction with Id :'+tran.Id);
            }
        }
    }

    @IsTest
    public static void testNoteInTransactionWithReferenceAndCheckNumber() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            String payReference = '0000000432';
            Integer checkNo = 1001;
            Cash_Receipt__c testCashReceipt = new Cash_Receipt__c(
                Account__c = testData.accounts.get(0).Id,
                Amount__c = 0,
                Payment_Reference__c = payReference,
                Status__c = 'In Process',
                Receipt_Date__c = testData.acctPeriods.get(0).Start_Date__c,
                Accounting_Period__c = testData.acctPeriods.get(0).Id,
                Purpose__c = 'Customer Receipt',
                Check_Number__c = checkNo,
                Bank_Account__c = testData.glAccounts.get(0).Id 
            );
            insert testCashReceipt;

            Test.startTest();
            AbstractPostHandler postHandler = new CashReceiptPostHandler();
            postHandler.post(new List<Cash_Receipt__c>{testCashReceipt});

            Test.stopTest();
            List<Transaction__c> trans = [SELECT Id, Note__c, Cash_Receipt__c FROM Transaction__c WHERE Cash_Receipt__c =: testCashReceipt.Id];
            for(Transaction__c tran : trans){
                System.assertEquals(String.valueOf(checkNo), tran.Note__c, 'Note value is not matching with Check Number for transaction with Id :'+tran.Id);
            }
        }
    }
}