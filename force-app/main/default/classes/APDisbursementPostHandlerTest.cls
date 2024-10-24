@IsTest
public class APDisbursementPostHandlerTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testPurgeUnlockedPostingStatusFieldOnly() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches();

        System.runAs(testData.users.get(1)) {

            Test.startTest();
            //Put some field into set of unlocked fields just to check it later
            TriggerObserver.getInstance().unlockField(Account.GL_Account_Variable_1__c);
            //create and post records
            testData.createPayables(true);
            testData.createCashDisbursements(true);
            AP_Disbursement__c apd = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[0].Id,
                Cash_Disbursement__c = testData.cashDisbursements[5].Id,
                Paid_Amount__c = 10
            );
            insert apd;
            //Validate that Posting Status field was removed from the set of unlocked fields after the end of posting routine
            System.assertEquals(false, TriggerObserver.getInstance().isUnlockedField(Account_Payable__c.Status__c));
            System.assertEquals(false, TriggerObserver.getInstance().isUnlockedField(Cash_Disbursement__c.Status__c));
            System.assertEquals(false, TriggerObserver.getInstance().isUnlockedField(AP_Disbursement__c.Status__c));
            //Validate that originally unlocked field is still unlocked
            System.assertEquals(true, TriggerObserver.getInstance().isUnlockedField(Account.GL_Account_Variable_1__c));
        }
    }

    @IsTest
    static void testNoControlAccountDefined() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(false)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements(false);

        System.runAs(testData.users[1]) {
            Cash_Disbursement__c testCD = testData.cashDisbursements[0];
            testCD.Debit_GL_Account__c = testData.glAccounts[12].Id;
            update testCD;
            delete [SELECT Id FROM GL_Account_Default__c WHERE GL_Account_Specification__c = :GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT];
            GLAccountDefaultsHandler.instance = null;

            testData.createApDisbursements();

            AbstractPostHandler postHandler = new APDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(new List<AP_Disbursement__c>{testData.apDisbursements[0]});

            System.assertEquals(PostResult.StatusCode.NO_CONTROL_AP_ACCOUNT_DEFINED, postResults[0].errors[0].statusCode);
        }

    }
    
    @IsTest
    static void testDebitGLAccountNotSet() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(false)
            .createCashDisbursementBatches()
            .createCashDisbursements(false);

        Test.startTest();
        testData.createCashDisbursements().createApDisbursements();

        System.runAs(testData.users[1]) {
            Cash_Disbursement__c cashDisbursement = testData.cashDisbursements[0].clone(true,true);
            cashDisbursement.Debit_GL_Account__c = null;

            AP_Disbursement__c apDisburse = testData.apDisbursements[0].clone(true,true);
            apDisburse.Cash_Disbursement__r = cashDisbursement;


            APDisbursementPostHandler postHandler = new APDisbursementPostHandler();
            postHandler.sourceRecords = new AP_Disbursement__c[]{apDisburse};
            postHandler.validateDebitGLAccount(false);

            System.assertEquals(
                PostResult.StatusCode.DEBIT_GL_ACCOUNT_IS_NULL_OR_SET_TO_AP_CONTROL_ACCOUNT,
                postHandler.dispatcher.getPostResults()[0].errors[0].statusCode
            );
        }
    }
    
    @IsTest
    static void testDebitGLAccountSetToAPControlAccount() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(false)
            .createCashDisbursementBatches()
            .createCashDisbursements(false);

        System.runAs(testData.users[1]) {
            Test.startTest();

            System.runAs(testData.users[1]) {
                Cash_Disbursement__c testCD = testData.cashDisbursements[0].clone(false, true);
                testCD.Debit_GL_Account__c = NULL;
                testCD.Source__c = 'Manual';
                insert testCD;

                //we have to clear Debit GL Account on related CD to get the validation error from post handler
                testCD.Debit_GL_Account__c = NULL;
                update testCD;

                AP_Disbursement__c testApDisbursement = new AP_Disbursement__c(
                    Account_Payable__c = testData.payables[0].Id,
                    Cash_Disbursement__c = testCD.Id,
                    Paid_Amount__c = 1
                );
                insert testApDisbursement;

                AbstractPostHandler postHandler = new APDisbursementPostHandler();
                List<PostResult> postResults = postHandler.post(new List<AP_Disbursement__c>{
                    testApDisbursement
                });
                System.assertEquals(PostResult.StatusCode.DEBIT_GL_ACCOUNT_IS_NULL_OR_SET_TO_AP_CONTROL_ACCOUNT, postResults[0].errors[0].statusCode);
            }
        }
    }

    @IsTest
    static void testPostAPDisbursementsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(false)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements(false);

        System.runAs(testData.users[1]) {
            AP_Disbursement__c testApDisbursement = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[0].Id,
                Cash_Disbursement__c = testData.cashDisbursements[5].Id,
                Paid_Amount__c = 10
            );
            insert testApDisbursement;

            List<Transaction__c> transactions = [SELECT Id, Amount__c FROM Transaction__c WHERE AP_Disbursement__c = :testApDisbursement.Id];
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
            System.assertEquals(10, debitLine.Amount__c);
            System.assertEquals(-10, creditLine.Amount__c);
        }
    }

    @IsTest
    static void testUnPostAPDisbursementsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(false)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements(false);

        System.runAs(testData.users[1]) {
            Cash_Disbursement__c testCD = testData.cashDisbursements[5].clone(false, true);
            insert testCD;

            AP_Disbursement__c testApDisbursement = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[0].Id,
                Cash_Disbursement__c = testCD.Id,
                Paid_Amount__c = 1.89
            );
            insert testApDisbursement;

            List<Transaction__c> transactions = [SELECT Id, Amount__c FROM Transaction__c WHERE AP_Disbursement__c = :testApDisbursement.Id];
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
            System.assertEquals(1.89, debitLine.Amount__c);
            System.assertEquals(-1.89, creditLine.Amount__c);

            //Test unpost functionality
            AbstractPostHandler apdPostHandler = new APDisbursementPostHandler();
            List<PostResult> apdPostResults = apdPostHandler.unpost(new List<AP_Disbursement__c>{testApDisbursement});

            System.assertEquals(true, apdPostResults[0].isSuccess);
            transactions = [SELECT Id, Amount__c FROM Transaction__c WHERE AP_Disbursement__c = :apdPostResults[0].id];
            System.assertEquals(true, transactions.isEmpty());
        }

    }

    @IsTest
    static void testPostAPDisbursementsSuccess_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createPayables()
                .createCashDisbursementBatches();
            Test.startTest();
            testData.createCashDisbursements();

            System.runAs(testData.users[1]) {
                AccountingSettingsHandler.acctSeedSettings = NULL;//To refresh Account Setting for the current APEX transaction

                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Cash_Disbursement_Batch__c testCDB = testData.cashDisbursementBatch[0].clone(false, true);
                testCDB.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert testCDB;

                Cash_Disbursement__c testCD = testData.cashDisbursements[0].clone(false, true);
                testCD.Cash_Disbursement_Batch__c = testCDB.Id;
                testCD.Debit_GL_Account__c = testData.glAccounts[1].Id;
                testCD.put('CurrencyIsoCode', newCurrencyIsoCode);
                testCD.Currency_Conversion_Rate__c = 1.2;
                insert testCD;

                //Post CD
                AbstractPostHandler cdPostHandler = new CashDisbursementPostHandler();
                List<PostResult> cdResults = cdPostHandler.post(new List<Cash_Disbursement__c>{testCD});
                System.assertEquals(true, cdResults[0].isSuccess);

                Account_Payable__c testAcctPayable = testData.payables[0];
                testAcctPayable.Status__c = 'Approved';
                testAcctPayable.put('CurrencyIsoCode', newCurrencyIsoCode);
                testAcctPayable.Currency_Conversion_Rate__c = 1.2;
                update testData.payables;

                //Post AP
                AbstractPostHandler payablePostHandler = new AccountPayablePostHandler();
                List<PostResult> apResults = payablePostHandler.post(new List<Account_Payable__c>{testAcctPayable});
                System.assertEquals(true, apResults[0].isSuccess);

                AP_Disbursement__c testApDisbursement = new AP_Disbursement__c(
                    Account_Payable__c = testAcctPayable.Id,
                    Cash_Disbursement__c = testCD.Id,
                    Paid_Amount__c = 145
                );
                testApDisbursement.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert testApDisbursement;

                //Expected: The new AP Disbursement record will be posted by trigger
                List<Transaction__c> transactions = [
                    SELECT Id, GL_Account__c, Amount__c, Foreign_Amount__c
                    FROM Transaction__c
                    WHERE AP_Disbursement__c = :testApDisbursement.Id
                ];
                System.assertEquals(3, transactions.size());

                for (Transaction__c trans : transactions) {
                    Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(trans.Ledger__c);
                    //Check regular debit & credit transactions
                    if (trans.GL_Account__c != defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CURRENCY_GAIN_LOSS_GL_ACCOUNT)?.GL_Account__c) {
                        //Expected: +/-(APD's Paid Amount / Currency Conversion Rate from CD)
                        System.assertEquals((145/1.2).setScale(2, System.RoundingMode.HALF_UP), trans.Amount__c.abs());
                        System.assertEquals(145, trans.Foreign_Amount__c.abs());
                    }
                    //check Foreign Exchange Gain & Loss transaction
                    else {
                        System.assertEquals(0, trans.Amount__c);
                    }

                }
            }
        }
        catch (Exception ex) {

        }

    }



    @IsTest
    static void testPostAPDisbursementsClosedPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(false)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements(false);

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods.get(1).Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods.get(1);

        System.runAs(testData.users[1]) {
            AP_Disbursement__c testApDisbursement = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[0].Id,
                Cash_Disbursement__c = testData.cashDisbursements[5].Id,
                Paid_Amount__c = 10
            );

            Exception customException;
            try {
                insert testApDisbursement;
            } catch (Exception e) {
                customException = e;
            }

            System.assert(customException.getMessage().contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'));
        }
    }

    @IsTest
    static void testPostAPDisbursementSoftClosedPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(false)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements(false);

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods.get(1).AcctSeed__Close_AP__c = true;
            update testData.acctPeriods.get(1);

        System.runAs(testData.users[1]) {
            AP_Disbursement__c testApDisbursement = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[0].Id,
                Cash_Disbursement__c = testData.cashDisbursements[5].Id,
                Paid_Amount__c = 10
            );

            Exception customException;
            try {
                insert testApDisbursement;
            } catch (Exception e) {
                customException = e;
            }

            System.assert(customException.getMessage().contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'));
        }
    }

    @IsTest
    static void testValidateNotPosted() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables(false)
                .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements(false);

        System.runAs(testData.users[1]) {
            AP_Disbursement__c testApDisbursement = new AP_Disbursement__c(
                    Account_Payable__c = testData.payables[0].Id,
                    Cash_Disbursement__c = testData.cashDisbursements[5].Id,
                    Paid_Amount__c = 10
            );
            insert testApDisbursement;

            List<PostResult> postResults = new APDisbursementPostHandler().post(new List<AP_Disbursement__c>{testApDisbursement});
            System.assert(postResults[0].errors[0].message == Label.ERR_RECORD_ALREADY_POSTED);
        }
    }

    @IsTest
    static void testInactiveLedger() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .disableAutoPostSourceDocuments()
                .createPayables(false)
                .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements(false);

        System.runAs(testData.users[1]) {
            AP_Disbursement__c testApDisbursement = new AP_Disbursement__c(
                    Account_Payable__c = testData.payables[0].Id,
                    Cash_Disbursement__c = testData.cashDisbursements[5].Id,
                    Paid_Amount__c = 10
            );
            insert testApDisbursement;
            TriggerObserver.getInstance().unlockField(Ledger__c.Active__c);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(new List<Ledger__c>{
                    new Ledger__c(Id = testData.payables[0].Ledger__c, Active__c = false)
            }, new List<String>{});
            TriggerObserver.purgeUnlockedFields(Ledger__c.Active__c);

            List<PostResult> postResults = new APDisbursementPostHandler().post(new List<AP_Disbursement__c>{testApDisbursement});
            System.assert(postResults[0].errors[0].message == Label.AcctSeed.ERR_LEDGER_ACTIVE_ONLY);
        }
    }

    @IsTest
    static void testHLPCashPostAPDisbursementsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables(false)
                .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements(false);

        System.runAs(testData.users[1]) {
            Cash_Disbursement__c testCD = testData.cashDisbursements[0].clone(false, true);
            testCD.Cash_Disbursement_Batch__c = testData.cashDisbursementBatch[0].Id;
            testCD.Debit_GL_Account__c = testData.glAccounts[1].Id;
            testCD.Ledger__c = testData.ledgers[3].Id;
            insert testCD;

            //Post CD
            AbstractPostHandler cdPostHandler = new CashDisbursementPostHandler();
            List<PostResult> cdResults = cdPostHandler.post(new List<Cash_Disbursement__c>{testCD});
            System.assertEquals(true, cdResults[0].isSuccess);

            Account_Payable__c testAcctPayable = testData.payables[0];
            testAcctPayable.Ledger__c = testData.ledgers[3].Id;
            testAcctPayable.Status__c = 'Approved';
            update testData.payables;

            //Post AP
            AbstractPostHandler payablePostHandler = new AccountPayablePostHandler();
            List<PostResult> apResults = payablePostHandler.post(new List<Account_Payable__c>{testAcctPayable});
            System.assertEquals(true, apResults[0].isSuccess);

            AP_Disbursement__c testApDisbursement = new AP_Disbursement__c(
                    Account_Payable__c = testAcctPayable.Id,
                    Cash_Disbursement__c = testCD.Id,
                    Paid_Amount__c = 145
            );
            insert testApDisbursement;

            //Expected: The new AP Disbursement record will be posted by trigger
            List<Transaction__c> transactions = [
                    SELECT Id, GL_Account__c, Amount__c
                    FROM Transaction__c
                    WHERE AP_Disbursement__c = :testApDisbursement.Id
            ];
            for (Transaction__c transactionItem : transactions) {
                if (transactionItem.GL_Account__c == testData.glAccounts[16].Id) {
                    System.assertEquals(145, transactionItem.Amount__c);
                } else {
                    System.assertEquals(-145, transactionItem.Amount__c);
                }
            }
            System.assertEquals(2, transactions.size());
        }
    }

    @IsTest
    static void testHLPAccrualCashPostAPDisbursementsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables(false)
                .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements(false);

        System.runAs(testData.users[1]) {
            List<GL_Account_Default__c> glAccountDefaults = new List<GL_Account_Default__c>{
                    new GL_Account_Default__c(
                            GL_Account_Specification__c = GLAccountDefaultsHandler.UNAPPLIED_EXPENSE_GL_ACCOUNT,
                            GL_Account__c = testData.glAccounts[27].Id,
                            Ledger__c = LedgerHandler.getShadowLedger(testData.ledgers[4].Id).Id
                    )
            };
            insert glAccountDefaults;
            GLAccountDefaultsHandler.instance = null;

            Cash_Disbursement__c testCD = testData.cashDisbursements[0].clone(false, true);
            testCD.Cash_Disbursement_Batch__c = testData.cashDisbursementBatch[0].Id;
            testCD.Debit_GL_Account__c = testData.glAccounts[1].Id;
            testCD.Ledger__c = testData.ledgers[4].Id;
            insert testCD;

            //Post CD
            AbstractPostHandler cdPostHandler = new CashDisbursementPostHandler();
            List<PostResult> cdResults = cdPostHandler.post(new List<Cash_Disbursement__c>{testCD});
            System.assertEquals(true, cdResults[0].isSuccess);

            Account_Payable__c testAcctPayable = testData.payables[0];
            testAcctPayable.Ledger__c = testData.ledgers[4].Id;
            testAcctPayable.Status__c = 'Approved';
            update testData.payables;

            //Post AP
            AbstractPostHandler payablePostHandler = new AccountPayablePostHandler();
            List<PostResult> apResults = payablePostHandler.post(new List<Account_Payable__c>{testAcctPayable});
            System.assertEquals(true, apResults[0].isSuccess);

            AP_Disbursement__c testApDisbursement = new AP_Disbursement__c(
                    Account_Payable__c = testAcctPayable.Id,
                    Cash_Disbursement__c = testCD.Id,
                    Paid_Amount__c = 145
            );
            insert testApDisbursement;

            //Expected: The new AP Disbursement record will be posted by trigger
            List<Transaction__c> transactions = [
                    SELECT Id, GL_Account__c, GL_Account__r.Name, Amount__c, Ledger__r.Is_Shadow__c
                    FROM Transaction__c
                    WHERE AP_Disbursement__c = :testApDisbursement.Id
            ];

            for (Transaction__c transactionItem : transactions) {
                if (transactionItem.Ledger__r.Is_Shadow__c) {
                    if (transactionItem.GL_Account__c == testData.glAccounts[16].Id) {
                        System.assertEquals(145, transactionItem.Amount__c);
                    } else {
                        System.assertEquals(-145, transactionItem.Amount__c);
                    }
                }
            }
            System.assertEquals(4, transactions.size());
        }
    }

    @IsTest
    static void testLLPCashPostAPDisbursementsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .setLineLevelPost()
                .createPayables(false)
                .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements(false);

        System.runAs(testData.users[1]) {
            Cash_Disbursement__c testCD = testData.cashDisbursements[0].clone(false, true);
            testCD.Cash_Disbursement_Batch__c = testData.cashDisbursementBatch[0].Id;
            testCD.Debit_GL_Account__c = testData.glAccounts[1].Id;
            testCD.Ledger__c = testData.ledgers[3].Id;
            insert testCD;

            //Post CD
            AbstractPostHandler cdPostHandler = new CashDisbursementPostHandler();
            List<PostResult> cdResults = cdPostHandler.post(new List<Cash_Disbursement__c>{testCD});
            System.assertEquals(true, cdResults[0].isSuccess);

            Account_Payable__c testAcctPayable = testData.payables[0];
            testAcctPayable.Ledger__c = testData.ledgers[3].Id;
            testAcctPayable.Status__c = 'Approved';
            update testData.payables;

            //Post AP
            AbstractPostHandler payablePostHandler = new AccountPayablePostHandler();
            List<PostResult> apResults = payablePostHandler.post(new List<Account_Payable__c>{testAcctPayable});
            System.assertEquals(true, apResults[0].isSuccess);

            AP_Disbursement__c testApDisbursement = new AP_Disbursement__c(
                    Account_Payable__c = testAcctPayable.Id,
                    Cash_Disbursement__c = testCD.Id,
                    Paid_Amount__c = 145
            );
            insert testApDisbursement;

            //Expected: The new AP Disbursement record will be posted by trigger
            List<Transaction__c> transactions = [
                    SELECT Id, GL_Account__c, Amount__c, Account_Payable_Line__c
                    FROM Transaction__c
                    WHERE AP_Disbursement__c = :testApDisbursement.Id
            ];


            //lines sum: 165
            //paid amount: 145 - 87.8% from 165
            for (Transaction__c transactionItem : transactions) {
                if (transactionItem.Account_Payable_Line__c == testData.payableLines[0].Id) {
                    if (transactionItem.GL_Account__c == testData.payableLines[0].Expense_GL_Account__c) {
                        System.assertEquals(39.55, transactionItem.Amount__c); //87.8% from 45
                    } else {
                        System.assertEquals(-39.55, transactionItem.Amount__c);
                    }
                }

                if (transactionItem.Account_Payable_Line__c == testData.payableLines[1].Id) {
                    if (transactionItem.GL_Account__c == testData.payableLines[1].Expense_GL_Account__c) {
                        System.assertEquals(48.33, transactionItem.Amount__c); //87.8% from 55
                    } else {
                        System.assertEquals(-48.33, transactionItem.Amount__c);
                    }
                }

                if (transactionItem.Account_Payable_Line__c == testData.payableLines[2].Id) {
                    if (transactionItem.GL_Account__c == testData.payableLines[2].Expense_GL_Account__c) {
                        System.assertEquals(57.12, transactionItem.Amount__c); //87.8% from 65
                    } else {
                        System.assertEquals(-57.12, transactionItem.Amount__c);
                    }
                }
            }
            System.assertEquals(6, transactions.size());
        }
    }

    @IsTest
    static void testLLPAccrualCashPostAPDisbursementsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .setLineLevelPost()
                .createPayables(false)
                .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements(false);

        System.runAs(testData.users[1]) {
            List<GL_Account_Default__c> glAccountDefaults = new List<GL_Account_Default__c>{
                    new GL_Account_Default__c(
                            GL_Account_Specification__c = GLAccountDefaultsHandler.UNAPPLIED_EXPENSE_GL_ACCOUNT,
                            GL_Account__c = testData.glAccounts[27].Id,
                            Ledger__c = LedgerHandler.getShadowLedger(testData.ledgers[4].Id).Id
                    )
            };
            insert glAccountDefaults;
            GLAccountDefaultsHandler.instance = null;

            Cash_Disbursement__c testCD = testData.cashDisbursements[0].clone(false, true);
            testCD.Cash_Disbursement_Batch__c = testData.cashDisbursementBatch[0].Id;
            testCD.Debit_GL_Account__c = testData.glAccounts[1].Id;
            testCD.Ledger__c = testData.ledgers[4].Id;
            insert testCD;

            //Post CD
            AbstractPostHandler cdPostHandler = new CashDisbursementPostHandler();
            List<PostResult> cdResults = cdPostHandler.post(new List<Cash_Disbursement__c>{testCD});
            System.assertEquals(true, cdResults[0].isSuccess);

            Account_Payable__c testAcctPayable = testData.payables[0];
            testAcctPayable.Ledger__c = testData.ledgers[4].Id;
            testAcctPayable.Status__c = 'Approved';
            update testData.payables;

            //Post AP
            AbstractPostHandler payablePostHandler = new AccountPayablePostHandler();
            List<PostResult> apResults = payablePostHandler.post(new List<Account_Payable__c>{testAcctPayable});
            System.assertEquals(true, apResults[0].isSuccess);

            AP_Disbursement__c testApDisbursement = new AP_Disbursement__c(
                    Account_Payable__c = testAcctPayable.Id,
                    Cash_Disbursement__c = testCD.Id,
                    Paid_Amount__c = 145
            );
            insert testApDisbursement;

            //Expected: The new AP Disbursement record will be posted by trigger
            List<Transaction__c> transactions = [
                    SELECT Id, GL_Account__c, GL_Account__r.Name, Ledger__r.Name, Amount__c, Account_Payable_Line__c
                    FROM Transaction__c
                    WHERE AP_Disbursement__c = :testApDisbursement.Id
            ];


            //lines sum: 165
            //paid amount: 145 - 87.8% from 165
            for (Transaction__c transactionItem : transactions) {
                if (transactionItem.Account_Payable_Line__c == testData.payableLines[0].Id) {
                    if (transactionItem.GL_Account__c == testData.payableLines[0].Expense_GL_Account__c) {
                        System.assertEquals(39.55, transactionItem.Amount__c); //87.8% from 45
                    } else {
                        System.assertEquals(-39.55, transactionItem.Amount__c);
                    }
                }

                if (transactionItem.Account_Payable_Line__c == testData.payableLines[1].Id) {
                    if (transactionItem.GL_Account__c == testData.payableLines[1].Expense_GL_Account__c) {
                        System.assertEquals(48.33, transactionItem.Amount__c); //87.8% from 55
                    } else {
                        System.assertEquals(-48.33, transactionItem.Amount__c);
                    }
                }

                if (transactionItem.Account_Payable_Line__c == testData.payableLines[2].Id) {
                    if (transactionItem.GL_Account__c == testData.payableLines[2].Expense_GL_Account__c) {
                        System.assertEquals(57.12, transactionItem.Amount__c); //87.8% from 65
                    } else {
                        System.assertEquals(-57.12, transactionItem.Amount__c);
                    }
                }
            }
            System.assertEquals(8, transactions.size());
        }
    }
}