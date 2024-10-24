@IsTest
private class CashDisbursementApplyAccountPayableTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testInitialPageLoadSoftClose() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Cash_Disbursement__c testCD = testData.cashDisbursements[5];
            
            testData.acctPeriods[1].Close_AP__c = true;
            testData.acctPeriods[0].Close_AP__c = true;
            UPDATE testData.acctPeriods;

            //Post CD
            AbstractPostHandler cdPostHandler = new CashDisbursementPostHandler();
            List<PostResult> cdResults = cdPostHandler.post(new List<Cash_Disbursement__c>{testCD});
            Assert.areEqual(false, cdResults[0].isSuccess, 'Not Posted Because related Period is closed');

            Account_Payable__c testAcctPayable = testData.payables[0];
            testAcctPayable.Status__c = 'Approved';
            update testData.payables;

            //Post AP
            AbstractPostHandler apPostHandler = new AccountPayablePostHandler();
            List<PostResult> apResults = apPostHandler.post(new List<Account_Payable__c>{testAcctPayable});
            for (PostResult result : apResults) {
                Assert.areEqual(false, result.isSuccess, 'Not Posted Because related Period is closed');
            }

            ApexPages.StandardController stdController = new ApexPages.StandardController(testCD);
            CashDisbursementApplyAccountPayable controller = new CashDisbursementApplyAccountPayable(stdController);

            Assert.areEqual(true, controller.wrappedRecords.isEmpty());
            Assert.areEqual(false, controller.execStatusDispatcher.getCanShowSaveButton());
            Assert.areEqual(false, controller.execStatusDispatcher.getCanShowHeaderSection());
            Assert.areEqual(false, controller.execStatusDispatcher.getCanShowTableSection());
            Assert.areEqual(true, controller.execStatusDispatcher.getIsErrorState());
        }
    }

    @IsTest
    private static void testInitialPageLoadSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Cash_Disbursement__c testCD = testData.cashDisbursements[5];

            //Post CD
            AbstractPostHandler cdPostHandler = new CashDisbursementPostHandler();
            List<PostResult> cdResults = cdPostHandler.post(new List<Cash_Disbursement__c>{testCD});
            System.assertEquals(true, cdResults[0].isSuccess);

            Account_Payable__c testAcctPayable = testData.payables[0];
            testAcctPayable.Status__c = 'Approved';
            update testData.payables;

            //Post AP
            AbstractPostHandler apPostHandler = new AccountPayablePostHandler();
            List<PostResult> apResults = apPostHandler.post(new List<Account_Payable__c>{testAcctPayable});
            for (PostResult result : apResults) {
                System.assertEquals(true, result.isSuccess);
            }

            ApexPages.StandardController stdController = new ApexPages.StandardController(testCD);
            CashDisbursementApplyAccountPayable controller = new CashDisbursementApplyAccountPayable(stdController);

            System.assertNotEquals(true, controller.wrappedRecords.isEmpty());
            System.assertEquals(true, controller.execStatusDispatcher.getCanShowSaveButton());
            System.assertEquals(true, controller.execStatusDispatcher.getCanShowHeaderSection());
            System.assertEquals(true, controller.execStatusDispatcher.getCanShowTableSection());
            System.assertEquals(false, controller.execStatusDispatcher.getIsErrorState());
        }

    }

    @IsTest
    private static void testInitialPageLoadCDNotPosted() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Cash_Disbursement__c testCD = testData.cashDisbursements[5];

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
            System.assert(ApexPages.getMessages().isEmpty());
        }

    }

    @IsTest
    private static void testInitialPageLoadCDIsVoided() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Cash_Disbursement__c testCD = testData.cashDisbursements[5];
            //Post CD
            AbstractPostHandler cdPostHandler = new CashDisbursementPostHandler();
            List<PostResult> cdResults = cdPostHandler.post(new List<Cash_Disbursement__c>{testCD});
            System.assertEquals(true, cdResults[0].isSuccess);
            //Void CD
            ApexPages.StandardController stdController = new ApexPages.StandardController(testCD);
            CashDisbursementVoid voidController = new CashDisbursementVoid(stdController);
            voidController.cashDisbursementVoid.Disbursement_Date__c = testData.acctPeriods[1].Start_Date__c.addDays(10);
            voidController.voidCashDisbursement();
            System.assertEquals('Void', [SELECT Id, Payment_Status__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id LIMIT 1].Payment_Status__c);

            CashDisbursementApplyAccountPayable controller = new CashDisbursementApplyAccountPayable(stdController);
            System.assertEquals(
                CashDisbursementApplyAccountPayable.VOIDED_CD_ERROR, ApexPages.getMessages()[0].getSummary()
            );
        }

    }

    @IsTest
    private static void testInitialPageLoadNonValidDebitGLAccount() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            
            Test.startTest();
            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.cashDisbursements[0]);
            CashDisbursementApplyAccountPayable controller = new CashDisbursementApplyAccountPayable(stdController);
            Test.stopTest();

            System.assertEquals(
                APDisbursementPostHandler.DEBIT_GL_ACCOUNT_VALIDATION_ON_INSERT_ERROR_MESSAGE,
                ApexPages.getMessages()[0].getSummary()
            );
        }

    }

    @IsTest
    private static void testInitialPageLoadNoRecordsFound() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Cash_Disbursement__c testCD = testData.cashDisbursements[5];

            //Post CD
            AbstractPostHandler cdPostHandler = new CashDisbursementPostHandler();
            List<PostResult> cdResults = cdPostHandler.post(new List<Cash_Disbursement__c>{testCD});
            System.assertEquals(true, cdResults[0].isSuccess);

            ApexPages.StandardController stdController = new ApexPages.StandardController(testCD);
            CashDisbursementApplyAccountPayable controller = new CashDisbursementApplyAccountPayable(stdController);

            System.assertNotEquals(
                CashDisbursementApplyAccountPayable.NO_MATCHING_ACCOUNT_PAYABLE_RECORDS_FOUND_ERROR,
                ApexPages.getMessages()[0].getSummary()
            );
        }

    }

    @IsTest
    private static void testSaveProcessSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
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
            System.assertEquals(
                1,
                [SELECT count() FROM AP_Disbursement__c WHERE Account_Payable__c = :testAcctPayable.Id]
            );

            List<AP_Disbursement__c> apdsForCheck =
                [SELECT Id FROM AP_Disbursement__c WHERE Account_Payable__c = :testAcctPayable.Id];

            System.assertEquals(2, [SELECT count() FROM Transaction__c WHERE AP_Disbursement__c IN :apdsForCheck]);
        }

    }

    @IsTest
    private static void testReapplyProcessSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
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
            controller.wrappedRecords[0].apDisbursement.Paid_Amount__c = 5;
            controller.saveAndRefresh();
            System.assertEquals(
                1,
                [SELECT COUNT() FROM AP_Disbursement__c WHERE Account_Payable__c = :testAcctPayable.Id]
            );

            List<AP_Disbursement__c> apdsForCheck =
                [SELECT Id FROM AP_Disbursement__c WHERE Account_Payable__c = :testAcctPayable.Id];

            List<Transaction__c> transactions =
                [SELECT Id, Amount__c FROM Transaction__c WHERE AP_Disbursement__c IN :apdsForCheck];
            System.assertEquals(2, transactions.size());

            Transaction__c debitLine;
            Transaction__c creditLine;
            for (Transaction__c trans : transactions) {
                if (trans.Amount__c > 0) {
                    debitLine = trans;
                }
                else if (trans.Amount__c < 0) {
                    creditLine = trans;
                }
            }
            System.assertEquals(5, debitLine.Amount__c);
            System.assertEquals(-5, creditLine.Amount__c);

            //Reapply
            controller.wrappedRecords[0].apDisbursement.Paid_Amount__c = 9;
            controller.save();
            System.assertEquals(
                1,
                [SELECT COUNT() FROM AP_Disbursement__c WHERE Account_Payable__c = :testAcctPayable.Id]
            );

            apdsForCheck = [SELECT Id FROM AP_Disbursement__c WHERE Account_Payable__c = :testAcctPayable.Id];
            transactions = [SELECT Id, Amount__c FROM Transaction__c WHERE AP_Disbursement__c IN :apdsForCheck];
            System.assertEquals(2, transactions.size());

            for (Transaction__c trans : transactions) {
                if (trans.Amount__c > 0) {
                    debitLine = trans;
                }
                else if (trans.Amount__c < 0) {
                    creditLine = trans;
                }
            }
            System.assertEquals(9, debitLine.Amount__c);
            System.assertEquals(-9, creditLine.Amount__c);
        }

    }

    @IsTest
    private static void testUnapplyWhenAccountingPeriodWasClosedAfterInitialPageLoad() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Cash_Disbursement__c testCD = testData.cashDisbursements[5];
            testCD.Accounting_Period__c = testData.acctPeriods[0].Id;
            update testCD;

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
            //update Accounting Period
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];
            AccountingPeriodHandler.reset();
            //=======================
            controller.save();

            System.assertEquals(
                CashDisbursementApplyAccountPayable.ACCOUNT_PERIOD_NOT_VALID_ERROR,
                ApexPages.getMessages()[0].getSummary()
            );
        }

    }

    @IsTest
    private static void testAccountingPeriodWasNotSet() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();

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
            controller.wrappedRecords[0].apDisbursement.Accounting_Period__c = NULL;//Accounting Period was not set
            controller.save();

            System.assertEquals(true, controller.execStatusDispatcher.requiredValueIsNotSet);
        }

    }

    @IsTest
    private static void testPaidAmountLessThenZero() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();

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
            controller.wrappedRecords[0].apDisbursement.Paid_Amount__c = - 10;
            controller.save();

            System.assertEquals(
                CashDisbursementApplyAccountPayable.AMOUNT_LESS_THAN_ZERO_ERROR,
                ApexPages.getMessages()[0].getSummary()
            );
        }

    }

    @IsTest
    private static void testAccountPayableBalanceLessThenZero() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();

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
            controller.wrappedRecords[0].apDisbursement.Paid_Amount__c = 500;
            controller.save();

            System.assertEquals(
                CashDisbursementApplyAccountPayable.ACCOUNT_PAYABLE_BALANCE_LESS_THAN_ZERO_ERROR,
                ApexPages.getMessages()[0].getSummary()
            );
        }

    }

    @IsTest
    private static void testSaveProcessSuccess_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createPayables()
                .createCashDisbursementBatches()
                .createCashDisbursements();

            System.runAs(testData.users[1]) {
                Test.startTest();
                AccountingSettingsHandler.acctSeedSettings = NULL;//To refresh Account Setting for the current APEX transaction

                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Cash_Disbursement_Batch__c testCDB = testData.cashDisbursementBatch[0].clone(false, true);
                testCDB.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert testCDB;

                //update CD
                Cash_Disbursement__c testCD = testData.cashDisbursements[5].clone(false, true);
                testCD.Cash_Disbursement_Batch__c = testCDB.Id;
                testCD.put('CurrencyIsoCode', newCurrencyIsoCode);
                testCD.Currency_Conversion_Rate__c = 1.2;
                insert testCD;

                //Post CD
                AbstractPostHandler cdPostHandler = new CashDisbursementPostHandler();
                List<PostResult> cdResults = cdPostHandler.post(new List<Cash_Disbursement__c>{testCD});
                System.assertEquals(true, cdResults[0].isSuccess);

                //Update AP
                TriggerObserver.getInstance().unlockFields(
                    new Set<SObjectField>{Schema.SObjectType.Account_Payable__c.fields.getMap().get('CurrencyIsoCode')}
                );
                Account_Payable__c testAP = testData.payables[0];
                testAP.put('CurrencyIsoCode', newCurrencyIsoCode);
                testAP.Status__c = 'Approved';
                testAP.Currency_Conversion_Rate__c = 1.2;

                update testAP;

                //Post AP
                AbstractPostHandler payablePostHandler = new AccountPayablePostHandler();
                List<PostResult> apResults = payablePostHandler.post(new List<Account_Payable__c>{testAP});
                System.assertEquals(true, apResults[0].isSuccess);

                ApexPages.StandardController stdController = new ApexPages.StandardController(testCD);
                CashDisbursementApplyAccountPayable controller = new CashDisbursementApplyAccountPayable(stdController);

                System.assertEquals(1, controller.wrappedRecords.size());
                controller.wrappedRecords[0].apDisbursement.Paid_Amount__c = 2;

                controller.save();

                List<AP_Disbursement__c> newApDisbursements = [
                    SELECT Id
                    FROM AP_Disbursement__c
                    WHERE Cash_Disbursement__c = :testCD.Id
                    AND Account_Payable__c = :testAP.Id
                ];

                System.assertEquals(false, newApDisbursements.isEmpty());
                System.assertEquals(1, newApDisbursements.size());
                System.assertEquals(
                    2,
                    [SELECT Id, Applied_Amount__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id].Applied_Amount__c
                );
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }

    }

    @IsTest
    public static void testSelectAppliedPayables() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(false)
            .createCashDisbursementBatches()
            .createCashDisbursements(false);

        System.runAs(testData.users.get(1)) {
            testData.payables[1].Vendor__c = testData.accounts[0].Id;
            testData.payables[1].Contact__c = null;

            testData.payables[2].Vendor__c = testData.accounts[0].Id;
            testData.payables[2].Employee__c = null;

            update testData.payables;

            Test.startTest();

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[5]})) {
                System.assertEquals(true, result.isSuccess);
            }

            List<AP_Disbursement__c> apdList = new List<AP_Disbursement__c>();
            AP_Disbursement__c testAPD = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[0].Id,
                Cash_Disbursement__c = testData.cashDisbursements[5].Id,
                Paid_Amount__c = 2
            );
            apdList.add(testAPD);

            AP_Disbursement__c testAPD2 = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[1].Id,
                Cash_Disbursement__c = testData.cashDisbursements[5].Id,
                Paid_Amount__c = 2
            );
            apdList.add(testAPD2);

            AP_Disbursement__c testAPD3 = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[2].Id,
                Cash_Disbursement__c = testData.cashDisbursements[5].Id,
                Paid_Amount__c = 2
            );
            apdList.add(testAPD3);

            AP_Disbursement__c testAPD4 = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[7].Id,
                Cash_Disbursement__c = testData.cashDisbursements[5].Id,
                Paid_Amount__c = 2
            );
            apdList.add(testAPD4);
            insert apdList;

            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.cashDisbursements[5]);
            CashDisbursementApplyAccountPayable controller = new CashDisbursementApplyAccountPayable(stdController);
            System.assertEquals(5, controller.wrappedRecords.size());
        }
    }

}