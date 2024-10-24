@IsTest
private class CashDisbursementPostHandlerTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testPurgeUnlockedPostingStatusFieldOnly() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches();

        System.runAs(testData.users.get(1)) {

            //Put some field into set of unlocked fields just to check it later
            TriggerObserver.getInstance().unlockField(Account.GL_Account_Variable_1__c);
            //create and post records
            testData.createCashDisbursements(true);
            //Validate that Posting Status field was removed from the set of unlocked fields after the end of posting routine
            System.assertEquals(false, TriggerObserver.getInstance().isUnlockedField(Cash_Disbursement__c.Status__c));
            //Validate that originally unlocked field is still unlocked
            System.assertEquals(true, TriggerObserver.getInstance().isUnlockedField(Account.GL_Account_Variable_1__c));
        }
    }

    @IsTest
    private static void testPartialPosting() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Cash_Disbursement__c testCD1 = testData.cashDisbursements.get(0);
            Cash_Disbursement__c testCD2 = testData.cashDisbursements.get(1);

            TriggerObserver.getInstance().unlockField(Cash_Disbursement__c.Payment_Status__c);
            testCD2.Payment_Status__c = 'Void';
            update testCD2;

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            postHandler.post(new List<Cash_Disbursement__c>{testCD1, testCD2});

            System.assertEquals(1, [SELECT count() FROM Cash_Disbursement__c WHERE Status__c = 'Posted']);
        } 
    }
    
    @IsTest
    private static void testPostCDWithContactMapping() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Account testAccount = [SELECT Id FROM Account LIMIT 1];
            Accounting_Period__c testAcctPeriod = [
                SELECT Id, Start_Date__c, End_Date__c
                FROM Accounting_Period__c
                ORDER BY Start_Date__c DESC LIMIT 1
            ];
            Contact testContact = [SELECT Id FROM Contact WHERE FirstName = 'John'];
            GL_Account__c testBankGlAccount = [SELECT Id FROM GL_Account__c WHERE Bank__c = true LIMIT 1];

            Cash_Disbursement_Batch__c testCDB = [SELECT Id FROM Cash_Disbursement_Batch__c LIMIT 1];
            Cash_Disbursement__c testCD = new Cash_Disbursement__c(
                Cash_Disbursement_Batch__c = testCDB.Id,
                Disbursement_Date__c = testAcctPeriod.Start_Date__c,
                Type__c = 'Check',
                Amount__c = 12,
                Source__c = 'Manual',
                Bank_Account__c = testBankGlAccount.Id,
                Contact__c = testContact.Id,
                Accounting_Period__c = testAcctPeriod.Id,
                Status__c = 'Approved',
                Reference__c = 'the-ref-xxx'
            );

            insert testCD;

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Cash_Disbursement__c>{testCD});

            System.assertEquals(true, postResults[0].isSuccess);

            List<Transaction__c> controlledTrans = [
                SELECT Id, Contact__c
                FROM Transaction__c
                WHERE Cash_Disbursement__c = :testCD.Id
                AND GL_Account__c = :testBankGlAccount.Id
            ];

            System.assertEquals(false, controlledTrans.isEmpty());
            System.assertEquals(testCD.Contact__c, controlledTrans[0].Contact__c);
        }
    }

    @IsTest
    private static void testCashDisbursementPostClosedAccountingPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            //all test Cash Disbursement records belong to Accounting Period "1991-10" which is first in list of created periods
            //let's try to close this Accounting Period to reproduce currently tested error
            Accounting_Period__c testAcctPeriod = testData.acctPeriods[0];
            testAcctPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testAcctPeriod;
            Test.stopTest();
            //Let's make it sure
            System.assertEquals(AccountingPeriodActions.CLOSED_STATUS, [SELECT Status__c FROM Accounting_Period__c WHERE Id = :testAcctPeriod.Id].Status__c);
            //Try to post all cash disbursements
            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> results = postHandler.post(testData.cashDisbursements);

            System.assertEquals(testData.cashDisbursements.size(), results.size());
            System.assertEquals(AbstractPostHandler.ACCOUNTING_PERIOD_CLOSED_ERROR_MESSAGE, results[0].errors[0].message);
        }

    }

    @IsTest
    private static void testCashDisbursementPostSoftClosedAccountingPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            //all test Cash Disbursement records belong to Accounting Period "1991-10" which is first in list of created periods
            //let's try to close this Accounting Period to reproduce currently tested error
            Accounting_Period__c testAcctPeriod = testData.acctPeriods[0];
            testAcctPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
            testAcctPeriod.close_AP__c = true;
            update testAcctPeriod;

            Test.stopTest();
      
            System.assertEquals(true, [SELECT close_AP__c FROM Accounting_Period__c WHERE Id = :testAcctPeriod.Id].close_AP__c);
            
            //Try to post all cash disbursements
            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> results = postHandler.post(testData.cashDisbursements);

            System.assertEquals(testData.cashDisbursements.size(), results.size());
            System.assertEquals(AbstractPostHandler.ACCOUNTING_PERIOD_CLOSED_ERROR_MESSAGE, results[0].errors[0].message);
        }

    }

    @IsTest
    private static void testCashDisbursementPostAlreadyPostedError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            //Try to post all cash disbursements
            CashDisbursementPostService.postCashDisbursements(testData.cashDisbursements);
            //Let's make sure that we dont have non-posted records anymore
            List<Cash_Disbursement__c> unpostedCDs = [
                SELECT Id FROM Cash_Disbursement__c WHERE Status__c = 'In Process'
            ];

            System.assertEquals(true, unpostedCDs.isEmpty());

            //And now we will try to post records which are already posted and ...
            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> results = postHandler.post(testData.cashDisbursements);
            Test.stopTest();
            //Getting expected error message
            System.assertEquals(AbstractPostHandler.POSTED_ERROR_MESSAGE, results[0].errors[0].message);
        }

    }

    @IsTest
    private static void testCashDisbursementPostVoidedError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            //Set Payment Status as "Void" for every Cash Disbursement
            for (Cash_Disbursement__c cd : testData.cashDisbursements) {
                cd.Payment_Status__c = 'Void';
            }
            TriggerObserver.getInstance().unlockField(Cash_Disbursement__c.Payment_Status__c);
            update testData.cashDisbursements;

            System.assertEquals('Void', testData.cashDisbursements[0].Payment_Status__c);
            //And now we will try to post records which have "Void" Payment Status and ...
            Test.startTest();
            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> results = postHandler.post(testData.cashDisbursements);
            Test.stopTest();
            //Getting expected error message
            System.assertEquals(CashDisbursementPostHandler.POSTED_VOID_ERROR_MESSAGE, results[0].errors[0].message);
        }

    }

    @IsTest
    private static void testCashDisbursementPostAPControlAccountError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        delete [SELECT Id FROM GL_Account_Default__c WHERE GL_Account_Specification__c = :GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT];
        GLAccountDefaultsHandler.instance = null;

        System.runAs(testData.users[1]) {
            List<Cash_Disbursement__c> unpostedCDs = [
                SELECT Id FROM Cash_Disbursement__c WHERE Status__c = 'Posted'
            ];

            System.assertEquals(true, unpostedCDs.isEmpty());

            Test.startTest();
            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> results = postHandler.post(testData.cashDisbursements);
            Test.stopTest();

            List<Cash_Disbursement__c> postedCDs = [
                SELECT Id FROM Cash_Disbursement__c WHERE Status__c = 'Posted'
            ];
            System.assertEquals(CashDisbursementPostHandler.NO_CONTROL_ACCOUNT_MESSAGE, results[0].errors[0].message);
        }

    }

    @IsTest
    private static void testCashDisbursementValidateDebitGLAccountError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Cash_Disbursement__c testCd = [SELECT Id, Debit_GL_Account__c, AP_Voucher_Count__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[0].Id LIMIT 1][0].clone(true,true);
            testCd.Debit_GL_Account__c = NULL;

            System.assertEquals(NULL, testCd.Debit_GL_Account__c);

            //And now we will execute validation method which has a null debit gl account value ...
            CashDisbursementPostHandler postHandler = new CashDisbursementPostHandler();
            postHandler.sourceRecords = new Cash_Disbursement__c[]{testCd};

            postHandler.validateDebitGLAccount(false);

            //Getting expected error message
            System.assertEquals(CashDisbursementPostHandler.DEBIT_GL_ACCOUNT_ERROR_MESSAGE, postHandler.dispatcher.getPostResults()[0].errors[0].message);
        }
    }

    @IsTest
    private static void tesCashDisbursementPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {

            Test.startTest();
            List<Cash_Disbursement__c> unpostedCDs = [
                SELECT Id FROM Cash_Disbursement__c WHERE Status__c = 'Posted'
            ];

            System.assertEquals(true, unpostedCDs.isEmpty());

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> results = postHandler.post(testData.cashDisbursements);

            List<Cash_Disbursement__c> postedCDs = [
                SELECT Id FROM Cash_Disbursement__c WHERE Status__c = 'Posted'
            ];

            System.assertEquals(false, postedCDs.isEmpty());

            postHandler.dispatcher.clearResultsMap();
            results = postHandler.unpost(testData.cashDisbursements);

            List<Cash_Disbursement__c> unPostedViaServiceCDs = [
                SELECT Id FROM Cash_Disbursement__c WHERE Status__c = 'Posted'
            ];

            System.assertEquals(true, unPostedViaServiceCDs.isEmpty());
        }
    }

    @IsTest
    private static void tesCashDisbursementPostDescriptionAndCheckNumberTransfer() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches();

        System.runAs(testData.users[1]) {
            //Create Cash Disbursement
            Cash_Disbursement__c testCD = new Cash_Disbursement__c(
                Cash_Disbursement_Batch__c = testData.cashDisbursementBatch[0].Id,
                Disbursement_Date__c = testData.acctPeriods[0].Start_Date__c,
                Type__c = 'Check',
                Amount__c = 10,
                Source__c = 'Manual',
                Bank_Account__c = testData.glAccounts[0].Id,
                Debit_GL_Account__c = testData.glAccounts[23].Id,
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                Reference__c = 'the reference 0',
                Check_Number__c = 112
            );
            insert testCD;

            Test.startTest();
            List<Cash_Disbursement__c> unpostedCDs = [
                SELECT Id FROM Cash_Disbursement__c WHERE Status__c = :AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED
            ];
            System.assertEquals(true, unpostedCDs.isEmpty());

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            postHandler.post(new List<Cash_Disbursement__c>{testCD});

            List<Cash_Disbursement__c> postedCDs = [
                SELECT Id FROM Cash_Disbursement__c WHERE Status__c = :AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED
            ];
            System.assertEquals(false, postedCDs.isEmpty());

            List<Transaction__c> cdTransactions = [
                SELECT Id, Description__c, Check_Number__c
                FROM Transaction__c
                WHERE Cash_Disbursement__c = :testCD.Id
            ];
            System.assertEquals(false, cdTransactions.isEmpty());
            System.assertEquals(testCD.Description__c, cdTransactions[0].Description__c);
            System.assertEquals(testCD.Check_Number__c, cdTransactions[0].Check_Number__c);
        }
    }

    @IsTest
    private static void testCashDisbursementUnpostClosedAccountingPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            //Post all cash disbursements
            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> results = postHandler.post(testData.cashDisbursements);
            //all test Cash Disbursement records belong to Accounting Period "1991-10" which is first in list of created periods
            //let's try to close this Accounting Period to reproduce currently tested error
            Accounting_Period__c testAcctPeriod = testData.acctPeriods[0];
            testAcctPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testAcctPeriod;
            Test.stopTest();
            //Let's make it sure
            System.assertEquals(AccountingPeriodActions.CLOSED_STATUS, [SELECT Status__c FROM Accounting_Period__c WHERE Id = :testAcctPeriod.Id].Status__c);
            //Now let's try to Unpost these records
            postHandler.dispatcher.clearResultsMap();
            results = postHandler.unpost(testData.cashDisbursements);
            //Check for expected error
            System.assertEquals(AbstractPostHandler.ACCOUNTING_PERIOD_CLOSED_ERROR_MESSAGE, results[0].errors[0].message);
        }
    }

    @IsTest
    private static void testCashDisbursementUnpostClearedBankRecError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createBankReconciliations();

        System.runAs(testData.users[1]) {
            Test.startTest();
            //Post all cash disbursements
            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> results = postHandler.post(testData.cashDisbursements);

            Cash_Disbursement__c testCD = [
                SELECT Id, Status__c, Bank_Reconciliation__c
                FROM Cash_Disbursement__c
                WHERE Id = :testData.cashDisbursements[0].Id
                LIMIT 1
            ];

            testCD.Bank_Reconciliation__c = testData.bankReconciliations[0].Id;

            TriggerObserver.getInstance().unlockField(Cash_Disbursement__c.Bank_Reconciliation__c);
            update testCD;

            postHandler.dispatcher.clearResultsMap();
            results = postHandler.unpost(new List<Cash_Disbursement__c>{testCD});

            System.assertEquals(PostResult.StatusCode.CLEARED_BANK_RECONCILIATION, results[0].errors[0].statusCode);
        }
    }

    @IsTest
    private static void testCashDisbursementUnpostAppliedError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createPayables();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Cash_Disbursement__c testCD = testData.cashDisbursements[5];

            //Post CD
            AbstractPostHandler cdPostHandler = new CashDisbursementPostHandler();
            List<PostResult> cdResults = cdPostHandler.post(new List<Cash_Disbursement__c>{testCD});
            System.assertEquals(true, cdResults[0].isSuccess);

            Account_Payable__c testAcctPayable = testData.payables[0];
            testAcctPayable.Status__c = 'Approved';
            update testAcctPayable;

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

            System.assertEquals(1, [SELECT count() FROM AP_Disbursement__c WHERE Account_Payable__c = :testAcctPayable.Id]);

            List<AP_Disbursement__c> apdsForCheck = [SELECT Id FROM AP_Disbursement__c WHERE Account_Payable__c = :testAcctPayable.Id];
            System.assertEquals(2, [SELECT count() FROM Transaction__c WHERE AP_Disbursement__c IN :apdsForCheck]);

            //Unpost CD and check error
            cdPostHandler.dispatcher.clearResultsMap();
            cdResults = cdPostHandler.unpost(new List<Cash_Disbursement__c>{testCD});

            System.assertEquals(false, cdResults[0].isSuccess);
            System.assertEquals(CashDisbursementPostHandler.UNPOST_APPLIED_ERROR_MESSAGE, cdResults[0].errors[0].message);
        }
    }

    @IsTest
    private static void tesCashDisbursementUnpostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Cash_Disbursement__c> unpostedCDs = [
                SELECT Id FROM Cash_Disbursement__c WHERE Status__c = 'Posted'
            ];

            System.assertEquals(true, unpostedCDs.isEmpty());

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> results = postHandler.post(testData.cashDisbursements);

            List<Cash_Disbursement__c> postedCDs = [
                SELECT Id FROM Cash_Disbursement__c WHERE Status__c = 'Posted'
            ];

            System.assertEquals(false, postedCDs.isEmpty());

            postHandler.dispatcher.clearResultsMap();
            results = postHandler.unpost(testData.cashDisbursements);
            Test.stopTest();

            List<Cash_Disbursement__c> unPostedViaServiceCDs = [
                SELECT Id FROM Cash_Disbursement__c WHERE Status__c = 'Posted'
            ];

            System.assertEquals(true, unPostedViaServiceCDs.isEmpty());
        }
    }

    @IsTest
    private static void testProductInTransaction() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createCashDisbursementBatches()
                .createCashDisbursements()
                .createProducts();

        System.runAs(testData.users[1]) {
            Cash_Disbursement__c testCD1 = testData.cashDisbursements.get(0);

            testCD1.Product__c = testData.products.get(0).Id;
            update testCD1;

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            postHandler.post(new List<Cash_Disbursement__c>{testCD1});

            System.assertEquals(true, [SELECT count() FROM Transaction__c WHERE Product__c =: testData.products.get(0).Id] > 0);
        }
    }

    @IsTest
    private static void tesCashDisbursementPostZeroAmountSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        Cash_Disbursement__c cashDisbursement = testData.cashDisbursements.get(6);

        System.runAs(testData.users[1]) {
            Test.startTest();
            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> results = postHandler.post(new List<Cash_Disbursement__c>{cashDisbursement});
            Test.stopTest();
  
            System.assertEquals(true, results.get(0).isSuccess);
        }
    }

    @IsTest
    public static void testCashDisbursementManualPostPartial() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(false)
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            AbstractPostHandler apPostHandler = new AccountPayablePostHandler();
            List<PostResult> postResults = apPostHandler.post(testData.payables);
            System.assertEquals(true, postResults[0].isSuccess);

            AP_Disbursement__c apDisbursement = new AP_Disbursement__c();
            apDisbursement.Account_Payable__c = testData.payables[0].Id;
            apDisbursement.Cash_Disbursement__c = testData.cashDisbursements[5].Id;
            apDisbursement.Paid_Amount__c = testData.cashDisbursements[5].Amount__c - 5;
            apDisbursement.Accounting_Period__c = testData.cashDisbursements[5].Accounting_Period__c;
            insert apDisbursement;

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> results = postHandler.post(new List<Cash_Disbursement__c>{testData.cashDisbursements[5]});

            System.assertEquals(true, results.get(0).isSuccess);
            List<Transaction__c> controlledTrans = [
                SELECT Id, Amount__c
                FROM Transaction__c
                WHERE Cash_Disbursement__c = :testData.cashDisbursements[5].Id
            ];

            System.assertEquals(testData.cashDisbursements[5].Amount__c, controlledTrans[0].Amount__c);
            Test.stopTest();
        }
    }

    @IsTest
    static void testCashDisbursementManual_Post_NoCurrencyGainLoss() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance();

            System.runAs(testData.users[1]) {
                Test.startTest();
                testData.enableMultiCurrency()
                        .createPayables()
                        .createCashDisbursementBatches()
                        .createCashDisbursements();
                AccountingSettingsHandler.acctSeedSettings = NULL;//To refresh Account Setting for the current APEX transaction

                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Cash_Disbursement_Batch__c testCDB = testData.cashDisbursementBatch[1].clone(false, true);
                testCDB.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert testCDB;

                Cash_Disbursement__c testCD = testData.cashDisbursements[5].clone(false, true);
                testCD.Cash_Disbursement_Batch__c = testCDB.Id;
                testCD.Debit_GL_Account__c = testData.glAccounts[1].Id;
                testCD.put('CurrencyIsoCode', newCurrencyIsoCode);
                testCD.Currency_Conversion_Rate__c = 1.2;
                insert testCD;

                //Post CD
                AbstractPostHandler cdPostHandler = new CashDisbursementPostHandler();
                List<PostResult> cdResults = cdPostHandler.post(new List<Cash_Disbursement__c>{testCD});
                System.assertEquals(true, cdResults[0].isSuccess);

                //Expected: Only two transactions will be posted.
                //currency gain loss transactions are not created for CD when source = manual and currency is diff from ledger
                List<Transaction__c> transactions = [
                    SELECT Id, GL_Account__c, Amount__c, Foreign_Amount__c
                    FROM Transaction__c
                    WHERE Cash_Disbursement__c = :testCD.Id
                ];
                System.assertEquals(2, transactions.size());

                for (Transaction__c trans : transactions) {
                    //Check regular debit & credit transactions
                    System.assertEquals((60/1.2).setScale(2, System.RoundingMode.HALF_UP), trans.Amount__c.abs());
                    System.assertEquals(60, trans.Foreign_Amount__c.abs());
                }
            }

        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
        } 
    } 



    @IsTest
    static void testCashDisbursementManual_Apply_Post_NoCurrencyGainLoss() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance();

            System.runAs(testData.users[1]) {
                Test.startTest();
                testData.enableMultiCurrency()
                        .createPayables()
                        .createCashDisbursementBatches()
                        .createCashDisbursements();
                AccountingSettingsHandler.acctSeedSettings = NULL;//To refresh Account Setting for the current APEX transaction

                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Cash_Disbursement_Batch__c testCDB = testData.cashDisbursementBatch[1].clone(false, true);
                testCDB.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert testCDB;

                Cash_Disbursement__c testCD = testData.cashDisbursements[5].clone(false, true);
                testCD.Cash_Disbursement_Batch__c = testCDB.Id;
                testCD.Debit_GL_Account__c = testData.glAccounts[1].Id;
                testCD.put('CurrencyIsoCode', newCurrencyIsoCode);
                testCD.Currency_Conversion_Rate__c = 1.2;
                insert testCD;

                Account_Payable__c newCurrencyAP = testData.payables[0].clone();
                newCurrencyAP.Payee_Reference__c = 'newCurrencyAP';
                newCurrencyAP.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert newCurrencyAP;

                Account_Payable_Line__c newCurrencyAPLine = 
                    new Account_Payable_Line__c(
                        Account_Payable__c = newCurrencyAP.Id,
                        Amount__c = 60,
                        Date__c = testData.acctPeriods[0].Start_Date__c,
                        Expense_GL_Account__c = testData.glAccounts[16].Id
                    );
                insert newCurrencyAPLine;

                //fully apply the CD to payable
                AP_Disbursement__c testApDisbursement = new AP_Disbursement__c(
                    Account_Payable__c = newCurrencyAP.Id,
                    Cash_Disbursement__c = testCD.Id,
                    Paid_Amount__c = 60
                );
                insert testApDisbursement;

                //Assert three transactions exist credit, debit, gain/loss for APD
                List<Transaction__c> apdTransactions = [SELECT Id FROM Transaction__c WHERE AP_Disbursement__c = :testApDisbursement.Id];
                System.assertEquals(3, apdTransactions.size());

                //Post CD
                AbstractPostHandler cdPostHandler = new CashDisbursementPostHandler();
                List<PostResult> cdResults = cdPostHandler.post(new List<Cash_Disbursement__c>{testCD});
                System.assertEquals(true, cdResults[0].isSuccess);

                //Expected: Only two transactions will be posted.
                //currency gain loss transactions are not created for CD when source = manual and currency is diff from ledger
                List<Transaction__c> transactions = [
                    SELECT Id, GL_Account__c, Amount__c, Foreign_Amount__c
                    FROM Transaction__c
                    WHERE Cash_Disbursement__c = :testCD.Id
                ];
                System.assertEquals(2, transactions.size());

                for (Transaction__c trans : transactions) {
                    //Check regular debit & credit transactions
                    System.assertEquals((60/1.2).setScale(2, System.RoundingMode.HALF_UP), trans.Amount__c.abs());
                    System.assertEquals(60, trans.Foreign_Amount__c.abs());
                }
            }
        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
        } 
    }

    @IsTest
    private static void testCDvalidatePostingStatus() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Cash_Disbursement__c> listCDsToInsert = new List<Cash_Disbursement__c>();
            
            Cash_Disbursement__c testCD = testData.cashDisbursements[5].clone(false, true);
            testCD.Status__c = 'In Process';
            listCDsToInsert.add(testCD);
            insert listCDsToInsert;
            
            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> results = postHandler.post(listCDsToInsert);

            System.assertEquals(Label.POSTING_STATUS_NOT_APPROVED_ERR,results[0].errors[0].message);
    
            Test.stopTest();
        }
    }

    @IsTest
    public static void tesCashDisbursementForAPAutomation() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();
            System.runAs(testData.users[1]) {

            Test.startTest();
  
                //Setting of mock
                SingleRequestMock awsSuccess = new SingleRequestMock(
                    200,
                    'Complete',
                    AwsServiceTest.CREATE_PAYMENTS_JSON , 
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );
                
                        Test.setMock(HttpCalloutMock.class, awsSuccess); 
            //Get all the cash disbursements
            List<Cash_Disbursement__c> cds = [SELECT Id, Type__c , Payment_Service_Status__c FROM Cash_Disbursement__c            ];
           

            Assert.areEqual(false, cds.isEmpty());
            
            cds[0].Type__c = 'AS Pay';
            update cds;
            
            //Try to post a cash disbursement
            CashDisbursementPostHandler cashDisbursementPostHandler = new CashDisbursementPostHandler();
            cashDisbursementPostHandler.apAutomationPostMessage(new List<Id>{cds[0].Id});

            Test.stopTest();
            Cash_Disbursement__c cd1 = [
                SELECT Id, Payment_Service_Status__c,Type__c FROM Cash_Disbursement__c
                where Id= :cds[0].Id
            ];

            Assert.areEqual('Pending', cd1.Payment_Service_Status__c);
        }
    } 
    
    @IsTest
    private static void testCDvalidateASPayBankAccount() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankAccounts()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.CREATE_PAYMENTS_JSON ,
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, awsSuccess);

            List<Cash_Disbursement__c> listCDsToInsert = new List<Cash_Disbursement__c>();
            
            Account testAcc = new Account(
                Id = testData.accounts[0].Id,
                AcctSeed__Billing_Contact__c = testData.contacts[0].Id);
            update testAcc;
            
            AcctSeed__GL_Account__c feesGL = new AcctSeed__GL_Account__c(
                Id = testData.glAccounts[0].Id,
                Bank_Account__c = testData.bankAccounts[0].Id
            );
            update feesGL;
            
            Cash_Disbursement__c testCD = testData.cashDisbursements[5].clone(false, true);
            testCD.Bank_Account__c = feesGL.Id;
            testCD.AcctSeed__Type__c = 'AS Pay';
            listCDsToInsert.add(testCD);
            insert listCDsToInsert;
            
            List<AcctSeed__Cash_Disbursement__c> listOfCDs = [Select Id,Bank_Account__r.Name FROM AcctSeed__Cash_Disbursement__c WHERE Id =: listCDsToInsert[0].Id];
            
            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> results = postHandler.post(listCDsToInsert);

            System.assertEquals(String.format(Label.ERR_REQUIRED_APPROVED_BANK_ACC_ON_GLACCOUNT_OF_CD, new List<String>{String.valueOf(listOfCDs[0].Bank_Account__r.Name)}),
                results[0].errors[0].message);
            Test.stopTest();
			
        }
    }
    
    @IsTest
    private static void testValidateLedgerFields() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createLedgerWithPaymentEnabled()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.CREATE_PAYMENTS_JSON ,
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, awsSuccess);

            List<Cash_Disbursement__c> listCDsToInsert = new List<Cash_Disbursement__c>();
            Account acc = testData.accounts[0];
            acc.Billing_Contact__c = testData.contacts[0].Id;
            update acc;
            
            Cash_Disbursement__c testCD = testData.cashDisbursements[5].clone(false, true);
            testCD.AcctSeed__Type__c = 'AS Pay';
            testCD.Ledger__c = testData.ledgers[0].Id;
            listCDsToInsert.add(testCD);
            insert listCDsToInsert;
            
            List<AcctSeed__Cash_Disbursement__c> listOfCDs = [Select Id,AcctSeed__Ledger__r.Name FROM AcctSeed__Cash_Disbursement__c WHERE Id =: listCDsToInsert[0].Id];
            
            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> results = postHandler.post(listCDsToInsert);

            System.assertEquals(String.format(Label.ERROR_LEDGER_NOT_ENROLLED, new List<String>{String.valueOf(listOfCDs[0].AcctSeed__Ledger__r.Name)}),
                                 results[0].errors[0].message);
    
            Test.stopTest();
        }
    }

    @IsTest
    private static void testCurrencyIsoCode() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency();

            Test.startTest();
            System.runAs(testData.users[1]) {

                //Setting of mock
                SingleRequestMock awsSuccess = new SingleRequestMock(
                    200,
                    'Complete',
                    AwsServiceTest.CREATE_PAYMENTS_JSON , 
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );

                Test.setMock(HttpCalloutMock.class, awsSuccess); 

                FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True); 
                String theNewCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();

                if (String.isBlank(theNewCurrencyIsoCode)) {
                    return;
                }

                Cash_Disbursement_Batch__c testCDBatch = new Cash_Disbursement_Batch__c(
                        Starting_Check_Number__c = 1,
                        Name = 'Test Batch'
                );
                testCDBatch.put('CurrencyIsoCode', theNewCurrencyIsoCode);
                insert testCDBatch;

                TestDataSuite testCashDisbursements = testData.createLedgerWithPaymentEnabled();
                List<Cash_Disbursement__c> listCDsToUpdate = new List<Cash_Disbursement__c>();

                Account acc = testData.accounts[0];
                acc.Billing_Contact__c = testData.contacts[0].Id;
                acc.AP_Remittance_Email__c = 'test@accountingseed.com';
                update acc;

                Ledger__c ledgerRec = testData.ledgers[0];
                ledgerRec.Enrolled_in_Payment_Services__c = true;
                ledgerRec.Payment_Services_Company_Code__c = 'Test101017';
                update ledgerRec;

                Cash_Disbursement__c testCD = 
                new Cash_Disbursement__c(
                    Cash_Disbursement_Batch__c = testCDBatch.Id,
                    Disbursement_Date__c = testData.acctPeriods[1].Start_Date__c,
                    Type__c = 'AS Pay',
                    Source__c = 'Manual',
                    Amount__c = 60,
                    Ledger__c = ledgerRec.Id,
                    Bank_Account__c = testData.glAccounts[0].Id,
                    Debit_GL_Account__c = testData.glAccounts[23].Id,
                    Vendor__c = testData.accounts[0].Id,
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                    Reference__c = 'the reference 6'
                );
                testCD.put('CurrencyIsoCode', theNewCurrencyIsoCode);

                listCDsToUpdate.add(testCD);
                insert listCDsToUpdate;

                AbstractPostHandler postHandler = new CashDisbursementPostHandler();
                List<PostResult> results = postHandler.post(listCDsToUpdate);
				System.assertEquals(Label.ERR_CD_CANNOT_POST_CURRENCY_NOT_EQUALS_USD,results[0].errors[0].message);
            }
            Test.stopTest();
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    private static void validateFieldsForVCard() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createLedgerWithPaymentEnabled()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();

            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.CREATE_PAYMENTS_JSON , 
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, awsSuccess); 

            List<Cash_Disbursement__c> listCDsToInsert = new List<Cash_Disbursement__c>();

            Contact conRec = testData.contacts[0];
            conRec.Email = 'test@accountingSeed.com';
            update conRec;

            Account accountRec = testData.accounts[0];
            accountRec.Billing_Contact__c = testData.contacts[0].Id;
            update accountRec;

            Ledger__c ledgerRec = testData.ledgers[0];
            ledgerRec.Enrolled_in_Payment_Services__c = true;
            ledgerRec.Payment_Services_Company_Code__c = 'Test101017';
            update ledgerRec;

            Cash_Disbursement__c testCD = testData.cashDisbursements[5].clone(false, true);
            testCD.AcctSeed__Type__c = 'AS Pay';
            testCD.AS_Pay_Type__c = 'Virtual Card';
            testCD.Ledger__c = testData.ledgers[0].Id;

            listCDsToInsert.add(testCD);
            insert listCDsToInsert;

            List<AcctSeed__Cash_Disbursement__c> listOfCDs = [Select Id,AcctSeed__Vendor__r.Name FROM AcctSeed__Cash_Disbursement__c WHERE Id =: listCDsToInsert[0].Id];

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> results = postHandler.post(listCDsToInsert);

            System.assertEquals(String.format(Label.ERR_AP_REMITTANCE_EMAIL_BLANK_FOR_VCARD_PAYMENT_SERVICE, new List<String>{String.valueOf(listOfCDs[0].AcctSeed__Vendor__r.Name)}),results[0].errors[0].message);

            Test.stopTest();
        }
    }

    @IsTest
    private static void validateFieldsForVCardASPayTypeOnVendor() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createLedgerWithPaymentEnabled()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();

            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.CREATE_PAYMENTS_JSON , 
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, awsSuccess); 

            List<Cash_Disbursement__c> listCDsToInsert = new List<Cash_Disbursement__c>();

            Contact conRec = testData.contacts[0];
            conRec.Email = 'test@accountingSeed.com';
            update conRec;

            Account accountRec = testData.accounts[0];
            accountRec.Billing_Contact__c = testData.contacts[0].Id;
            accountRec.AS_Pay_Type__c = 'Virtual Card';
            update accountRec;

            Ledger__c ledgerRec = testData.ledgers[0];
            ledgerRec.Enrolled_in_Payment_Services__c = true;
            ledgerRec.Payment_Services_Company_Code__c = 'Test101017';
            update ledgerRec;

            Cash_Disbursement__c testCD = testData.cashDisbursements[5].clone(false, true);
            testCD.AcctSeed__Type__c = 'AS Pay';
            testCD.Ledger__c = testData.ledgers[0].Id;

            listCDsToInsert.add(testCD);
            insert listCDsToInsert;

            List<AcctSeed__Cash_Disbursement__c> listOfCDs = [Select Id,AcctSeed__Vendor__r.Name FROM AcctSeed__Cash_Disbursement__c WHERE Id =: listCDsToInsert[0].Id];

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> results = postHandler.post(listCDsToInsert);

            System.assertEquals(String.format(Label.ERR_AP_REMITTANCE_EMAIL_BLANK_FOR_VCARD_PAYMENT_SERVICE, new List<String>{String.valueOf(listOfCDs[0].AcctSeed__Vendor__r.Name)}),results[0].errors[0].message);

            Test.stopTest();
        }
    }

    @IsTest
    private static void validateFieldsForCheck(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createLedgerWithPaymentEnabled()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();

            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.CREATE_PAYMENTS_JSON , 
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, awsSuccess); 

            List<Cash_Disbursement__c> listCDsToInsert = new List<Cash_Disbursement__c>();

            Account accountRec = testData.accounts[0];
            accountRec.AP_Remittance_Email__c = 'test@accountingseed.com';
            update accountRec;

            Ledger__c ledgerRec = testData.ledgers[0];
            ledgerRec.Enrolled_in_Payment_Services__c = true;
            ledgerRec.Payment_Services_Company_Code__c = 'Test101017';
            update ledgerRec;

            Cash_Disbursement__c testCD = testData.cashDisbursements[5].clone(false, true);
            testCD.AcctSeed__Type__c = 'AS Pay';
            testCD.AS_Pay_Type__c = 'Check';
            testCD.Ledger__c = testData.ledgers[0].Id;
            listCDsToInsert.add(testCD);
            insert listCDsToInsert;

            List<AcctSeed__Cash_Disbursement__c> listOfCDs = [Select Id,AcctSeed__Vendor__r.Name FROM AcctSeed__Cash_Disbursement__c WHERE Id =: listCDsToInsert[0].Id];

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> results = postHandler.post(listCDsToInsert);

            System.assertEquals(String.format(Label.ERR_CD_VENDOR_BILLING_ADDRESS_BLANK_FOR_CHECK_PAYMENT_SERVICE, new List<String>{String.valueOf(listOfCDs[0].AcctSeed__Vendor__r.Name)}),
                                 results[0].errors[0].message);

            Test.stopTest();
        }
    }

    @IsTest
    private static void validateFieldsForACH(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createLedgerWithPaymentEnabled()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();

            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.CREATE_PAYMENTS_JSON , 
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, awsSuccess); 

            List<Cash_Disbursement__c> listCDsToInsert = new List<Cash_Disbursement__c>();

            Account accountRec = testData.accounts[0];
            accountRec.Billing_Contact__c = testData.contacts[0].Id;
            accountRec.AP_Remittance_Email__c = 'test@accountingseed.com';
            update accountRec;

            Ledger__c ledgerRec = testData.ledgers[0];
            ledgerRec.Enrolled_in_Payment_Services__c = true;
            ledgerRec.Payment_Services_Company_Code__c = 'Test101017';
            update ledgerRec;

            Cash_Disbursement__c testCD = testData.cashDisbursements[5].clone(false, true);
            testCD.AcctSeed__Type__c = 'AS Pay';
            testCD.AS_Pay_Type__c = 'ACH';
            testCD.Ledger__c = testData.ledgers[0].Id;
            testCD.Amount__c = 0;
            listCDsToInsert.add(testCD);
            insert listCDsToInsert;

            List<AcctSeed__Cash_Disbursement__c> listOfCDs = [Select Id,AcctSeed__Vendor__r.Name FROM AcctSeed__Cash_Disbursement__c WHERE Id =: listCDsToInsert[0].Id];

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> results = postHandler.post(listCDsToInsert);

            System.assertEquals(String.format(Label.ERR_CD_NO_DEFAULT_PAYMENT_METHOD_ON_VENDOR_FOR_ACH_PAYMENT_SERVICE, new List<String>{String.valueOf(listOfCDs[0].AcctSeed__Vendor__r.Name)}),
                                 results[0].errors[0].message);

            Test.stopTest();
        }
    }
    
    @IsTest
    private static void validateFieldsForACHVendor(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createLedgerWithPaymentEnabled()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();

            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.CREATE_PAYMENTS_JSON , 
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, awsSuccess); 

            List<Cash_Disbursement__c> listCDsToInsert = new List<Cash_Disbursement__c>();

            Account accountRec = testData.accounts[0];
            accountRec.Billing_Contact__c = testData.contacts[0].Id;
            accountRec.AS_Pay_Type__c = 'ACH';
            update accountRec;

            Ledger__c ledgerRec = testData.ledgers[0];
            ledgerRec.Enrolled_in_Payment_Services__c = true;
            ledgerRec.Payment_Services_Company_Code__c = 'Test101017';
            update ledgerRec;

            Cash_Disbursement__c testCD = testData.cashDisbursements[5].clone(false, true);
            testCD.AcctSeed__Type__c = 'AS Pay';
            testCD.Ledger__c = testData.ledgers[0].Id;
            testCD.Amount__c = 0;
            listCDsToInsert.add(testCD);
            insert listCDsToInsert;

            List<AcctSeed__Cash_Disbursement__c> listOfCDs = [Select Id,AcctSeed__Vendor__r.Name FROM AcctSeed__Cash_Disbursement__c WHERE Id =: listCDsToInsert[0].Id];

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> results = postHandler.post(listCDsToInsert);

            System.assertEquals(String.format(Label.ERR_CD_NO_DEFAULT_PAYMENT_METHOD_ON_VENDOR_FOR_ACH_PAYMENT_SERVICE, new List<String>{String.valueOf(listOfCDs[0].AcctSeed__Vendor__r.Name)}),
                                 results[0].errors[0].message);

            Test.stopTest();
        }
    }

    @IsTest
    private static void validatePaymentServiceRelatedFields() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.CREATE_PAYMENTS_JSON ,
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, awsSuccess);

            List<Cash_Disbursement__c> listCDsToInsert = new List<Cash_Disbursement__c>();
            
            Ledger__c ledgerRec = testData.ledgers[0];
            ledgerRec.Enrolled_in_Payment_Services__c = true;
            ledgerRec.Payment_Services_Company_Code__c = 'Test101017';
            update ledgerRec;
            
            Cash_Disbursement__c testCD = testData.cashDisbursements[5].clone(false, true);
            testCD.Vendor__c = null;
            testCD.AcctSeed__Contact__c = testData.contacts[0].Id;
            testCD.AcctSeed__Type__c = 'AS Pay';
            listCDsToInsert.add(testCD);
            insert listCDsToInsert;
            
            
            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> results = postHandler.post(listCDsToInsert);

            System.assertEquals(Label.ERR_CD_CANNOT_BE_POSTED_FOR_CONTACT_OR_EMPLOYEE,
                                 results[0].errors[0].message);
    
            Test.stopTest();
        }
    }

    @IsTest
    private static void validateFieldsForACHSuccess(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
			testData.createCashDisbursementBatches()
            .createLedgerWithPaymentEnabled()
            .createCashDisbursements()
            .createPaymentProcessors();

            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.CREATE_PAYMENTS_JSON , 
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, awsSuccess); 

            List<Cash_Disbursement__c> listCDsToInsert = new List<Cash_Disbursement__c>();

            Account accountRec = testData.accounts[0];
            accountRec.Billing_Contact__c = testData.contacts[0].Id;
            accountRec.AP_Remittance_Email__c = 'test@accountingseed.com';
            update accountRec;

            Ledger__c ledgerRec = testData.ledgers[0];
            ledgerRec.Enrolled_in_Payment_Services__c = true;
            ledgerRec.Payment_Services_Company_Code__c = 'Test101017';
            update ledgerRec;

            Payment_Method__c paymentMethod = new Payment_Method__c(
                Type__c = 'Visa',
                Status__c = 'Active',
                Expiration_Month__c = '12',
                Expiration_Year__c = '2099',
                Last_Four_Digits__c = '4444',
                External_Id__c = 'edenred-test',
                Routing_Number__c = '999999999',
                Account_Number__c = '999999999',
                Vendor__c = testData.accounts[0].Id,
                Default__c = true,
                Payment_Processor__c = testData.paymentProcessors.get(0).Id,
                Verification_Status__c = 'ACTIVE'

            );
            insert paymentMethod;


            Cash_Disbursement__c testCD = testData.cashDisbursements[5].clone(false, true);
            testCD.AcctSeed__Type__c = 'AS Pay';
            testCD.AS_Pay_Type__c = 'ACH';
            testCD.Ledger__c = testData.ledgers[0].Id;
            testCD.Vendor__c = testData.accounts[0].Id;
            testCD.Amount__c = 0;
            listCDsToInsert.add(testCD);
            insert listCDsToInsert;

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> results = postHandler.post(listCDsToInsert);

           	AcctSeed__Cash_Disbursement__c cd = [Select Id,AcctSeed__Vendor__r.Name, Payment_Method__c FROM AcctSeed__Cash_Disbursement__c WHERE Status__c = 'Posted' LIMIT 1];
            System.assertEquals(paymentMethod.Id, cd.Payment_Method__c);

            Test.stopTest();
        }
    }
	
    @IsTest
    private static void validateCDForInactivePaymentService(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createLedgerWithPaymentEnabled()
            .createCashDisbursements()
            .createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Test.startTest();

            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.CREATE_PAYMENTS_JSON , 
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, awsSuccess); 

            List<Cash_Disbursement__c> listCDsToInsert = new List<Cash_Disbursement__c>();

            Account accountRec = testData.accounts[0];
            accountRec.Billing_Contact__c = testData.contacts[0].Id;
            accountRec.AP_Remittance_Email__c = 'test@accountingseed.com';
            update accountRec;

            Ledger__c ledgerRec = testData.ledgers[0];
            ledgerRec.Enrolled_in_Payment_Services__c = true;
            ledgerRec.Payment_Services_Company_Code__c = 'Test101017';
            update ledgerRec;

            Payment_Method__c paymentMethod = new Payment_Method__c(
                Type__c = 'Visa',
                Status__c = 'Inactive',
                Expiration_Month__c = '12',
                Expiration_Year__c = '2099',
                Last_Four_Digits__c = '4444',
                External_Id__c = 'edenred-test',
                Routing_Number__c = '999999999',
                Account_Number__c = '999999999',
                Vendor__c = testData.accounts[0].Id,
                Default__c = true,
                Payment_Processor__c = testData.paymentProcessors.get(0).Id
            );
            insert paymentMethod;


            Cash_Disbursement__c testCD = testData.cashDisbursements[5].clone(false, true);
            testCD.AcctSeed__Type__c = 'AS Pay';
            testCD.AS_Pay_Type__c = 'ACH';
            testCD.Ledger__c = testData.ledgers[0].Id;
            testCD.Vendor__c = testData.accounts[0].Id;
            testCD.Amount__c = 0;
            listCDsToInsert.add(testCD);
            insert listCDsToInsert;

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> results = postHandler.post(listCDsToInsert);

            System.assertEquals(Label.CD_CANNOT_BE_POSTED_DEFAULT_PAYMENT_SERVICE_INACTIVE, results[0].errors[0].message);

            Test.stopTest();
        }
    }
    
    @IsTest
    private static void validateCDForInactivePaymentServiceForACHVendor(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createLedgerWithPaymentEnabled()
            .createCashDisbursements()
            .createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Test.startTest();

            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.CREATE_PAYMENTS_JSON , 
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, awsSuccess); 

            List<Cash_Disbursement__c> listCDsToInsert = new List<Cash_Disbursement__c>();

            Account accountRec = testData.accounts[0];
            accountRec.Billing_Contact__c = testData.contacts[0].Id;
            accountRec.AS_Pay_Type__c = 'ACH';
            update accountRec;

            Ledger__c ledgerRec = testData.ledgers[0];
            ledgerRec.Enrolled_in_Payment_Services__c = true;
            ledgerRec.Payment_Services_Company_Code__c = 'Test101017';
            update ledgerRec;

            Payment_Method__c paymentMethod = new Payment_Method__c(
                Type__c = 'Visa',
                Status__c = 'Inactive',
                Expiration_Month__c = '12',
                Expiration_Year__c = '2099',
                Last_Four_Digits__c = '4444',
                External_Id__c = 'edenred-test',
                Routing_Number__c = '999999999',
                Account_Number__c = '999999999',
                Vendor__c = testData.accounts[0].Id,
                Default__c = true,
                Payment_Processor__c = testData.paymentProcessors.get(0).Id
            );
            insert paymentMethod;


            Cash_Disbursement__c testCD = testData.cashDisbursements[5].clone(false, true);
            testCD.AcctSeed__Type__c = 'AS Pay';
            testCD.Ledger__c = testData.ledgers[0].Id;
            testCD.Vendor__c = testData.accounts[0].Id;
            testCD.Amount__c = 0;
            listCDsToInsert.add(testCD);
            insert listCDsToInsert;

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> results = postHandler.post(listCDsToInsert);

            System.assertEquals(Label.CD_CANNOT_BE_POSTED_DEFAULT_PAYMENT_SERVICE_INACTIVE, results[0].errors[0].message);

            Test.stopTest();
        }
    }


    @IsTest
    private static void testCashDisbursementBalanceError() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createLedgerWithPaymentEnabled()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();

            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.CREATE_PAYMENTS_JSON , 
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, awsSuccess); 

            List<Cash_Disbursement__c> listCDsToInsert = new List<Cash_Disbursement__c>();


            Account accountRec = testData.accounts[0];
            accountRec.Billing_Contact__c = testData.contacts[0].Id;
            accountRec.AP_Remittance_Email__c = 'test@abc.com';
            update accountRec;

            Ledger__c ledgerRec = testData.ledgers[0];
            ledgerRec.Enrolled_in_Payment_Services__c = true;
            ledgerRec.Payment_Services_Company_Code__c = 'Test101017';
            update ledgerRec;

            Cash_Disbursement__c testCD = testData.cashDisbursements[5].clone(false, true);
            testCD.AcctSeed__Type__c = 'AS Pay';
            testCD.AS_Pay_Type__c = 'Virtual Card';
            testCD.Ledger__c = testData.ledgers[0].Id;
            testCD.Amount__c = 1099;
            testCD.Payment_Status__c = 'Paid';

            listCDsToInsert.add(testCD);
            insert listCDsToInsert;

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> results = postHandler.post(listCDsToInsert);

            System.assertEquals(Label.CD_BALANCE_MUST_BE_ZERO_BEFORE_POSTING,results[0].errors[0].message);

            Test.stopTest();
        }
    }

    @IsTest
    public static void testCDPostPaymentMethodVerificationStatusIsNotActive() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createPaymentProcessors()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {

            Payment_Method__c testPaymentMethod = new Payment_Method__c(
                Type__c = 'Visa',
                Status__c = 'Active',
                Expiration_Month__c = '12',
                Expiration_Year__c = '2099',
                Last_Four_Digits__c = '4444',
                External_Id__c = 'stripe-card-1',
                Default__c = true,
                Vendor__c = testData.accounts[0].Id,
                Payment_Processor__c = testData.paymentProcessors.get(0).Id,
                Verification_Status__c = 'new',
                Account_Number__c = '123456787654',
                Routing_Number__c= '62442'
            );
            insert testPaymentMethod;

            Account testAcc = testData.accounts[0];
            testAcc.Billing_Contact__c = testData.contacts[0].Id;
            testAcc.AP_Remittance_Email__c = 'test@accountingseed.com';
            update testAcc;

            Ledger__c testLedger= testData.ledgers[0];
            testLedger.Enrolled_in_Payment_Services__c = true;
            testLedger.Payment_Services_Company_Code__c = '123';
            update testLedger;

            Cash_Disbursement__c testCD = testData.cashDisbursements[1];
            testCD.AS_Pay_Type__c = 'ACH';
            testCD.Type__c = 'AS Pay';
            testCD.Ledger__c = testData.ledgers[0].Id;
            testCD.Contact__c = null;
            testCD.Vendor__c =testData.accounts[0].Id;

            update testCD;

            ApexPages.StandardController controller = new ApexPages.StandardController(testCD);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();
            cdp.post();

            System.assertEquals(Label.CD_CANNOT_BE_POSTED_DEFAULT_PAYMENT_METHOD_VERIFICATION_STATUS_IS_NOT_ACTIVE, ApexPages.getMessages()[0].getSummary());
        }
    }
    
    @IsTest
    public static void testCDPmVerificationStatusIsNotActiveForACHVendor() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createPaymentProcessors()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {

            Payment_Method__c testPaymentMethod = new Payment_Method__c(
                Type__c = 'Visa',
                Status__c = 'Active',
                Expiration_Month__c = '12',
                Expiration_Year__c = '2099',
                Last_Four_Digits__c = '4444',
                External_Id__c = 'stripe-card-1',
                Default__c = true,
                Vendor__c = testData.accounts[0].Id,
                Payment_Processor__c = testData.paymentProcessors.get(0).Id,
                Verification_Status__c = 'new',
                Account_Number__c = '123456787654',
                Routing_Number__c= '62442'
            );
            insert testPaymentMethod;

            Account testAcc = testData.accounts[0];
            testAcc.AS_Pay_Type__c = 'ACH';
            testAcc.Billing_Contact__c = testData.contacts[0].Id;
            update testAcc;

            Ledger__c testLedger= testData.ledgers[0];
            testLedger.Enrolled_in_Payment_Services__c = true;
            testLedger.Payment_Services_Company_Code__c = '123';
            update testLedger;

            Cash_Disbursement__c testCD = testData.cashDisbursements[1];
            testCD.Type__c = 'AS Pay';
            testCD.Ledger__c = testData.ledgers[0].Id;
            testCD.Contact__c = null;
            testCD.Vendor__c =testData.accounts[0].Id;

            update testCD;

            ApexPages.StandardController controller = new ApexPages.StandardController(testCD);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();
            cdp.post();

            System.assertEquals(Label.CD_CANNOT_BE_POSTED_DEFAULT_PAYMENT_METHOD_VERIFICATION_STATUS_IS_NOT_ACTIVE, ApexPages.getMessages()[0].getSummary());
        }
    }

    @IsTest
    public static void testCDPostPMVerificationStatusForACHVendorIsNotActive() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createPaymentProcessors()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {

            Payment_Method__c testPaymentMethod = new Payment_Method__c(
                Type__c = 'Visa',
                Status__c = 'Active',
                Expiration_Month__c = '12',
                Expiration_Year__c = '2099',
                Last_Four_Digits__c = '4444',
                External_Id__c = 'stripe-card-1',
                Default__c = true,
                Vendor__c = testData.accounts[0].Id,
                Payment_Processor__c = testData.paymentProcessors.get(0).Id,
                Verification_Status__c = 'new',
                Account_Number__c = '123456787654',
                Routing_Number__c= '62442'
            );
            insert testPaymentMethod;

            Account testAcc = testData.accounts[0];
            testAcc.Billing_Contact__c = testData.contacts[0].Id;
            testAcc.AS_Pay_Type__c = 'ACH';
            testAcc.AP_Remittance_Email__c = 'test@accountingseed.com';
            update testAcc;

            Ledger__c testLedger= testData.ledgers[0];
            testLedger.Enrolled_in_Payment_Services__c = true;
            testLedger.Payment_Services_Company_Code__c = '123';
            update testLedger;

            Cash_Disbursement__c testCD = testData.cashDisbursements[1];
            testCD.AS_Pay_Type__c = '';
            testCD.Type__c = 'AS Pay';
            testCD.Ledger__c = testData.ledgers[0].Id;
            testCD.Contact__c = null;
            testCD.Vendor__c =testData.accounts[0].Id;

            update testCD;

            ApexPages.StandardController controller = new ApexPages.StandardController(testCD);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();
            cdp.post();

            System.assertEquals(Label.CD_CANNOT_BE_POSTED_DEFAULT_PAYMENT_METHOD_VERIFICATION_STATUS_IS_NOT_ACTIVE, ApexPages.getMessages()[0].getSummary());
        }
    }
}