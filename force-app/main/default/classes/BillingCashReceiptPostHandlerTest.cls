@IsTest
public class BillingCashReceiptPostHandlerTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testPurgeUnlockedPostingStatusFieldOnly() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        System.runAs(testData.users.get(1)) {

            //Put some field into set of unlocked fields just to check it later
            TriggerObserver.getInstance().unlockField(Account.GL_Account_Variable_1__c);
            //create and post records
            testData.createBillings(false);
            testData.createCashReceipts();
            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c(
                Cash_Receipt__c = testData.cashReceipts[0].Id,
                Billing__c = testData.billings.get(0).Id,
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Applied_Amount__c = 100
            );
            insert bcr;
            //Validate that Posting Status field was removed from the set of unlocked fields after the end of posting routine
            System.assertEquals(false, TriggerObserver.getInstance().isUnlockedField(Billing__c.Status__c));
            System.assertEquals(false, TriggerObserver.getInstance().isUnlockedField(Cash_Receipt__c.Status__c));
            System.assertEquals(false, TriggerObserver.getInstance().isUnlockedField(Billing_Cash_Receipt__c.Status__c));
            //Validate that originally unlocked field is still unlocked
            System.assertEquals(true, TriggerObserver.getInstance().isUnlockedField(Account.GL_Account_Variable_1__c));
            Test.stopTest();
        }
    }

    @IsTest
    public static void testBillingCashReceiptPostClosedPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            //Turn Off AutoPost
            Accounting_Settings__c settings = AccountingSettingsHandler.getAccountingSettings();
            settings.Auto_Post_Billing_Cash_Receipts__c = false;
            update settings;

            Billing_Cash_Receipt__c testBCR = new Billing_Cash_Receipt__c(
                Cash_Receipt__c = testData.cashReceipts[2].Id,
                Billing__c = testData.billings[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Applied_Amount__c = 12
            );
            insert testBCR;

            Accounting_Period__c testPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodById(testData.acctPeriods.get(0).Id);
            testPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testPeriod;

            Test.stopTest();//to be sure that batch is executed

            AbstractPostHandler postHandler = new BillingCashReceiptPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing_Cash_Receipt__c>{testBCR});
            //We expect that the posting process will fail because Accounting Period is CLOSED
            System.assertNotEquals(true, results.get(0).isSuccess);
        }
    }

    @IsTest
    public static void testBillingCashReceiptPostNoControlAccount() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings(false)
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            delete [
                SELECT
                    Id
                FROM GL_Account_Default__c
                WHERE GL_Account_Specification__c = :GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT
            ];
            GLAccountDefaultsHandler.instance = null;

            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();
            billingCashReceipts.add(
                new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testData.cashReceipts[0].Id,
                    Billing__c = testData.billings[0].Id,
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Applied_Amount__c = 12
                )
            );

            DmlException dmlEx;
            try {
                insert billingCashReceipts;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(BillingCashReceiptPostHandler.NO_CONTROL_ACCOUNT_MESSAGE, ApexPages.getMessages()[0].getDetail());
            System.assertEquals(
                String.format(
                    BillingCashReceiptActions.AUTO_POST_FAILED_ERROR,
                    new List<String>{BillingCashReceiptPostHandler.NO_CONTROL_ACCOUNT_MESSAGE}
                ),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void testBillingCashReceiptPost() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments();
        Test.startTest();
        testData.createBillings(false)
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();
            billingCashReceipts.add(
                new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testData.cashReceipts[0].Id,
                    Billing__c = testData.billings[0].Id,
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Applied_Amount__c = 12
                )
            );
            insert billingCashReceipts;
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id]);

            AbstractPostHandler postHandler = new BillingCashReceiptPostHandler();
            postHandler.post(new List<Billing_Cash_Receipt__c>{billingCashReceipts[0]});
            System.assertEquals(2, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id]);
        }
    }

    @IsTest
    public static void testRefundBCRNoPosting() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments();
        Test.startTest();
        testData.createBillings(false)
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();
            billingCashReceipts.add(
                new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testData.cashReceipts[0].Id,
                    Billing__c = testData.billings[0].Id,
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Applied_Amount__c = 12,
                    Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_BCR_REFUND
                )
            );
            insert billingCashReceipts;
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id]);

            AbstractPostHandler postHandler = new BillingCashReceiptPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing_Cash_Receipt__c>{billingCashReceipts[0]});
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id]);
        }
    }

    @IsTest
    public static void testBillingCashReceiptPostNonZeroAdjustmentAmount() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments();
        Test.startTest();
        testData.createBillings(false)
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();

            billingCashReceipts.add(
                new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testData.cashReceipts[0].Id,
                    Billing__c = testData.billings[0].Id,
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Applied_Amount__c = 12,
                    Adjustment_GL_Account__c = testData.glAccounts[16].Id,
                    Adjustment_Amount__c = 5.00
                )
            );
            insert billingCashReceipts;
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id]);

            AbstractPostHandler postHandler = new BillingCashReceiptPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing_Cash_Receipt__c>{billingCashReceipts[0]});
            System.assertEquals(3, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id]);
        }

    }

    @IsTest
    public static void testBillingCashReceiptPostZeroAdjustmentAmount() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments();
        Test.startTest();
        testData.createBillings(false)
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();

            billingCashReceipts.add(
                new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testData.cashReceipts[0].Id,
                    Billing__c = testData.billings[0].Id,
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Applied_Amount__c = 12,
                    Adjustment_GL_Account__c = testData.glAccounts[16].Id,
                    Adjustment_Amount__c = 0.00
                )
            );
            insert billingCashReceipts;
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id]);

            AbstractPostHandler postHandler = new BillingCashReceiptPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing_Cash_Receipt__c>{billingCashReceipts[0]});
            System.assertEquals(2, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id]);
        }
    }

    @IsTest
    public static void testBillingCashReceiptPostLessThanZeroAdjustmentAmount() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments();
        Test.startTest();
        testData.createBillings(false)
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();

            billingCashReceipts.add(
                new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testData.cashReceipts[0].Id,
                    Billing__c = testData.billings[0].Id,
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Applied_Amount__c = 12,
                    Adjustment_GL_Account__c = testData.glAccounts[16].Id,
                    Adjustment_Amount__c = -6.00
                )
            );
            insert billingCashReceipts;
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id]);

            AbstractPostHandler postHandler = new BillingCashReceiptPostHandler();
            postHandler.post(new List<Billing_Cash_Receipt__c>{billingCashReceipts[0]});
            System.assertEquals(3, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id]);
        }
    }

    @IsTest
    public static void testBillingCashReceiptPostAdjustmentAmountRounding() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments();
        Test.startTest();
        testData.createBillings(false)
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();

            billingCashReceipts.add(
                new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testData.cashReceipts[0].Id,
                    Billing__c = testData.billings[0].Id,
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Applied_Amount__c = 12,
                    Adjustment_GL_Account__c = testData.glAccounts[16].Id,
                    Adjustment_Amount__c = 0.000001
                )
            );
            insert billingCashReceipts;
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id]);

            AbstractPostHandler postHandler = new BillingCashReceiptPostHandler();
            postHandler.post(new List<Billing_Cash_Receipt__c>{billingCashReceipts[0]});
            System.assertEquals(2, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id]);
        }
    }

    @IsTest
    public static void testBillingCashReceiptUnpost() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings(false)
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();

            billingCashReceipts.add(
                new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testData.cashReceipts[0].Id,
                    Billing__c = testData.billings[0].Id,
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Applied_Amount__c = 12
                )
            );

            insert billingCashReceipts;
            System.assertEquals(2, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id]);

            AbstractPostHandler postHandler = new BillingCashReceiptPostHandler();
            List<PostResult> results = postHandler.unpost(new List<Billing_Cash_Receipt__c>{billingCashReceipts[0]});
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id]);
        }

    }

    @IsTest
    public static void testBillingCashReceiptPostWithDifferentAccount() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments();
        Test.startTest();
        testData.createBillings(false)
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            Cash_Receipt__c newCR = testData.cashReceipts[0].clone();
            newCR.Account__c = testData.accounts.get(1).Id;
            insert newCR;

            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();
            billingCashReceipts.add(
                new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = newCR.Id,
                    Billing__c = testData.billings[0].Id,
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Applied_Amount__c = 12
                )
            );
            insert billingCashReceipts;
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id]);

            AbstractPostHandler postHandler = new BillingCashReceiptPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing_Cash_Receipt__c>{billingCashReceipts[0]});
            System.assertEquals(2, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id]);

            List<Transaction__c> transactions = [SELECT Id, Account__c FROM Transaction__c WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id];

            System.assertEquals(newCR.Account__c, transactions[0].Account__c);
            System.assertEquals(testData.billings[0].Customer__c, transactions[1].Account__c);
        }
    }

    @IsTest
    public static void testBillingCashReceiptPostInheritProduct() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments();
        Test.startTest();
        testData.createBillings(false)
            .createCashReceipts()
            .createAccountingVariables()
            .createProducts()
            .createProjects()
            .createProjectTasks();

        System.runAs(testData.users[1]) {
            Cash_Receipt__c newCR = testData.cashReceipts[0].clone();
            newCR.Account__c = testData.accounts.get(1).Id;
            newCR.Product__c = testData.products.get(0).Id;
            newCR.Project__c = testData.projects.get(0).Id;
            newCR.Project_Task__c = testData.projectTasks.get(0).Id;
            newCR.GL_Account_Variable_1__c = testData.accountingVariables1.get(0).Id;
            newCR.GL_Account_Variable_2__c = testData.accountingVariables2.get(0).Id;
            newCR.GL_Account_Variable_3__c = testData.accountingVariables3.get(0).Id;
            newCR.GL_Account_Variable_4__c = testData.accountingVariables4.get(0).Id;
            insert newCR;

            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();
            billingCashReceipts.add(
                new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = newCR.Id,
                    Billing__c = testData.billings[0].Id,
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Applied_Amount__c = 12
                )
            );
            insert billingCashReceipts;
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id]);

            AbstractPostHandler postHandler = new BillingCashReceiptPostHandler();
            postHandler.post(new List<Billing_Cash_Receipt__c>{billingCashReceipts[0]});
            System.assertEquals(2, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id]);

            List<Transaction__c> transactions = [
                SELECT Id, Account__c, GL_Account_Variable_1__c, GL_Account_Variable_2__c, GL_Account_Variable_3__c,
                    GL_Account_Variable_4__c, Project__c, Project_Task__c, Product__c
                FROM Transaction__c
                WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id
            ];

            System.assertEquals(newCR.Account__c, transactions[0].Account__c);
            System.assertEquals(testData.billings[0].Customer__c, transactions[1].Account__c);
            System.assertEquals(testData.products.get(0).Id, transactions[0].Product__c);
            System.assertEquals(testData.projects.get(0).Id, transactions[0].Project__c);
            System.assertEquals(testData.projectTasks.get(0).Id, transactions[0].Project_Task__c);
            System.assertEquals(testData.accountingVariables1.get(0).Id, transactions[0].GL_Account_Variable_1__c);
            System.assertEquals(testData.accountingVariables2.get(0).Id, transactions[0].GL_Account_Variable_2__c);
            System.assertEquals(testData.accountingVariables3.get(0).Id, transactions[0].GL_Account_Variable_3__c);
            System.assertEquals(testData.accountingVariables4.get(0).Id, transactions[0].GL_Account_Variable_4__c);
            System.assertEquals(testData.products.get(0).Id, transactions[1].Product__c);
            System.assertEquals(testData.projects.get(0).Id, transactions[1].Project__c);
            System.assertEquals(testData.projectTasks.get(0).Id, transactions[1].Project_Task__c);
            System.assertEquals(testData.accountingVariables1.get(0).Id, transactions[1].GL_Account_Variable_1__c);
            System.assertEquals(testData.accountingVariables2.get(0).Id, transactions[1].GL_Account_Variable_2__c);
            System.assertEquals(testData.accountingVariables3.get(0).Id, transactions[1].GL_Account_Variable_3__c);
            System.assertEquals(testData.accountingVariables4.get(0).Id, transactions[1].GL_Account_Variable_4__c);
        }
    }

    @IsTest
    public static void testBillingCashReceiptPostSoftClosedPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            //Turn Off AutoPost
            Accounting_Settings__c settings = AccountingSettingsHandler.getAccountingSettings();
            settings.Auto_Post_Billing_Cash_Receipts__c = false;
            update settings;

            Billing_Cash_Receipt__c testBCR = new Billing_Cash_Receipt__c(
                Cash_Receipt__c = testData.cashReceipts[2].Id,
                Billing__c = testData.billings[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Applied_Amount__c = 12
            );
            insert testBCR;

            Accounting_Period__c testPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodById(testData.acctPeriods.get(0).Id);
            testPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
            testPeriod.Close_AR__c = true;
            update testPeriod;

            Test.stopTest();//to be sure that batch is executed

            AbstractPostHandler postHandler = new BillingCashReceiptPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing_Cash_Receipt__c>{testBCR});
            //We expect that the posting process will fail because Accounting Period is CLOSED
           
            Assert.isFalse(results.get(0).isSuccess);
            Assert.areEqual(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD, results.get(0).errors.get(0).statusCode );
            
        }
    }

    //=============================================================================
    //===== Group of test methods related to the Multi Currency functionality =====
    //=============================================================================

    @IsTest
    public static void testBillingCashReceiptPost_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency();
            Test.startTest();
            testData.createBillings(true)
                .createCashReceipts();

            System.runAs(testData.users[1]) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Billing__c testBilling = testData.billings[0];
                testBilling.Status__c = 'Approved';
                testBilling.put('CurrencyIsoCode', newCurrencyIsoCode);
                testBilling.Currency_Conversion_Rate__c = 1.0;

                TriggerObserver.getInstance().unlockFields(
                    new Set<SObjectField>{Schema.SobjectType.Billing__c.fields.getMap().get('CurrencyIsoCode')}
                );
                update testBilling;
                TriggerObserver.reset();
                //unpost cash receipt first
                Cash_Receipt__c testCR = testData.cashReceipts[0];
                CashReceiptPostService.unpostCashReceipts(new List<Cash_Receipt__c>{testCR});

                testCR.put('CurrencyIsoCode', newCurrencyIsoCode);
                testCR.Currency_Conversion_Rate__c = 1.2;
                update testCR;

                AbstractPostHandler postHandler = new BillingPostHandler();
                List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});

                System.assertEquals(true, results[0].isSuccess);
                System.assertEquals('Posted', [SELECT Status__c FROM Billing__c WHERE Id = :testBilling.Id].Status__c);

                List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();

                billingCashReceipts.add(
                    new Billing_Cash_Receipt__c(
                        Cash_Receipt__c = testCR.Id,
                        Billing__c = testBilling.Id,
                        Accounting_Period__c = testData.acctPeriods[1].Id,
                        Applied_Amount__c = 12,
                        Adjustment_GL_Account__c = testData.glAccounts[16].Id,
                        Adjustment_Amount__c = 6
                    )
                );

                insert billingCashReceipts;

                System.assertEquals(
                    4,
                    [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id]
                );
                System.assertEquals(
                    0, [
                        SELECT sum(Amount__c) sum
                        FROM Transaction__c
                        WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id
                        GROUP BY Billing_Cash_Receipt__c
                    ][0].get('sum')
                );
                Test.stopTest();
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }

    }

    @IsTest
    static void testInactiveLedger() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .disableAutoPostSourceDocuments()
                .createBillings()
                .createCashReceipts();
        Test.startTest();

        System.runAs(testData.users[1]) {
            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>{
                    new Billing_Cash_Receipt__c(
                            Cash_Receipt__c = testData.cashReceipts[0].Id,
                            Billing__c = testData.billings[0].Id,
                            Accounting_Period__c = testData.acctPeriods[1].Id,
                            Applied_Amount__c = 12
                    )
            };
            insert billingCashReceipts;

            List<Billing__c> billings = [SELECT Id, Ledger__c FROM Billing__c WHERE Id =: testData.billings[0].Id];
            TriggerObserver.getInstance().unlockField(Ledger__c.Active__c);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(new List<Ledger__c>{
                    new Ledger__c(Id = billings[0].Ledger__c, Active__c = false)
            }, new List<String>{});
            TriggerObserver.purgeUnlockedFields(Ledger__c.Active__c);

            List<PostResult> postResults = new BillingCashReceiptPostHandler().post(billingCashReceipts);
            System.assert(postResults[0].errors[0].message == Label.AcctSeed.ERR_LEDGER_ACTIVE_ONLY);
        }
    }

    @IsTest
    public static void testHLPCashBillingCashReceiptPost() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings(false)
                .createCashReceipts();

        System.runAs(testData.users[1]) {
            Billing__c testBilling = testData.billings[0];
            testBilling.Status__c = 'Approved';
            testBilling.Ledger__c = testData.ledgers[3].Id;
            update testBilling;

            Cash_Receipt__c testCR = testData.cashReceipts[0];
            CashReceiptPostService.unpostCashReceipts(new List<Cash_Receipt__c>{testCR});

            testCR.Ledger__c = testData.ledgers[3].Id;
            update testCR;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});

            System.assertEquals(true, results[0].isSuccess);
            System.assertEquals('Posted', [SELECT Status__c FROM Billing__c WHERE Id = :testBilling.Id].Status__c);

            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>{
                    new Billing_Cash_Receipt__c(
                            Cash_Receipt__c = testCR.Id,
                            Billing__c = testBilling.Id,
                            Accounting_Period__c = testData.acctPeriods[1].Id,
                            Applied_Amount__c = 12,
                            Adjustment_GL_Account__c = testData.glAccounts[16].Id,
                            Adjustment_Amount__c = 6
                    )
            };
            insert billingCashReceipts;

            List<Transaction__c> transactions = [
                    SELECT Id, GL_Account__c, GL_Account__r.Name, Amount__c
                    FROM Transaction__c
                    WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id
            ];
            System.assertEquals(3, transactions.size());

            Decimal sum = 0;
            for (Transaction__c transactionItem : transactions) {
                sum += transactionItem.Amount__c;
                if (transactionItem.GL_Account__c == testData.glAccounts[10].Id) {
                    System.assertEquals(-18, transactionItem.Amount__c);
                }
                if (transactionItem.GL_Account__c == testData.glAccounts[16].Id) {
                    System.assertEquals(6, transactionItem.Amount__c);
                }
            }
            System.assertEquals(0, sum);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testLLPCashBillingCashReceiptPost() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost();
        Test.startTest();
        testData.createBillings(false)
                .createCashReceipts();

        System.runAs(testData.users[1]) {
            Billing__c testBilling = testData.billings[0];
            testBilling.Status__c = 'Approved';
            testBilling.Ledger__c = testData.ledgers[3].Id;
            update testBilling;

            Cash_Receipt__c testCR = testData.cashReceipts[0];
            CashReceiptPostService.unpostCashReceipts(new List<Cash_Receipt__c>{testCR});

            testCR.Ledger__c = testData.ledgers[3].Id;
            update testCR;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});

            System.assertEquals(true, results[0].isSuccess);
            System.assertEquals('Posted', [SELECT Status__c FROM Billing__c WHERE Id = :testBilling.Id].Status__c);

            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>{
                    new Billing_Cash_Receipt__c(
                            Cash_Receipt__c = testCR.Id,
                            Billing__c = testBilling.Id,
                            Accounting_Period__c = testData.acctPeriods[1].Id,
                            Applied_Amount__c = 12,
                            Adjustment_GL_Account__c = testData.glAccounts[16].Id,
                            Adjustment_Amount__c = 6
                    )
            };
            insert billingCashReceipts;

            List<Transaction__c> transactions = [
                    SELECT Id, GL_Account__c, GL_Account__r.Name, Amount__c, Billing_Line__c
                    FROM Transaction__c
                    WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id
            ];
            System.assertEquals(6, transactions.size());

            Decimal sum = 0;
            for (Transaction__c transactionItem : transactions) {
                sum += transactionItem.Amount__c;
                if (transactionItem.Billing_Line__c == testData.billingLines[0].Id && transactionItem.GL_Account__c == testData.glAccounts[10].Id) {
                    System.assertEquals(-8, transactionItem.Amount__c);
                }
                if (transactionItem.Billing_Line__c == testData.billingLines[1].Id && transactionItem.GL_Account__c == testData.glAccounts[10].Id) {
                    System.assertEquals(-10, transactionItem.Amount__c);
                }
                if (transactionItem.GL_Account__c == testData.glAccounts[16].Id) {
                    System.assertEquals(6, transactionItem.Amount__c);
                }
            }
            System.assertEquals(0, sum);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testHLPAccrualCashBillingCashReceiptPost() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings(false)
                .createCashReceipts();

        System.runAs(testData.users[1]) {
            List<GL_Account_Default__c> glAccountDefaults = new List<GL_Account_Default__c>{
                    new GL_Account_Default__c(
                            GL_Account_Specification__c = GLAccountDefaultsHandler.UNAPPLIED_REVENUE_GL_ACCOUNT,
                            GL_Account__c = testData.glAccounts[21].Id,
                            Ledger__c = LedgerHandler.getShadowLedger(testData.ledgers[4].Id).Id
                    )
            };
            insert glAccountDefaults;
            GLAccountDefaultsHandler.instance = null;

            Billing__c testBilling = testData.billings[0];
            testBilling.Status__c = 'Approved';
            testBilling.Ledger__c = testData.ledgers[4].Id;
            update testBilling;

            Cash_Receipt__c testCR = testData.cashReceipts[0];
            CashReceiptPostService.unpostCashReceipts(new List<Cash_Receipt__c>{testCR});

            testCR.Ledger__c = testData.ledgers[4].Id;
            update testCR;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});

            System.assertEquals(true, results[0].isSuccess);
            System.assertEquals('Posted', [SELECT Status__c FROM Billing__c WHERE Id = :testBilling.Id].Status__c);

            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>{
                    new Billing_Cash_Receipt__c(
                            Cash_Receipt__c = testCR.Id,
                            Billing__c = testBilling.Id,
                            Accounting_Period__c = testData.acctPeriods[1].Id,
                            Applied_Amount__c = 12,
                            Adjustment_GL_Account__c = testData.glAccounts[16].Id,
                            Adjustment_Amount__c = 6
                    )
            };
            insert billingCashReceipts;

            List<Transaction__c> transactions = [
                    SELECT Id, GL_Account__c, GL_Account__r.Name, Amount__c, Ledger__r.Name
                    FROM Transaction__c
                    WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id
            ];
            System.assertEquals(6, transactions.size());

            Decimal sum = 0;
            for (Transaction__c transactionItem : transactions) {
                sum += transactionItem.Amount__c;
                if (transactionItem.GL_Account__c == testData.glAccounts[10].Id) {
                    System.assertEquals(-18, transactionItem.Amount__c);
                }
                if (transactionItem.GL_Account__c == testData.glAccounts[16].Id) {
                    System.assertEquals(6, transactionItem.Amount__c);
                }
            }
            System.assertEquals(0, sum);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testLLPAccrualCashBillingCashReceiptPost() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .setLineLevelPost();
        Test.startTest();
        testData.createBillings(false)
                .createCashReceipts();

        System.runAs(testData.users[1]) {
            List<GL_Account_Default__c> glAccountDefaults = new List<GL_Account_Default__c>{
                    new GL_Account_Default__c(
                            GL_Account_Specification__c = GLAccountDefaultsHandler.UNAPPLIED_REVENUE_GL_ACCOUNT,
                            GL_Account__c = testData.glAccounts[21].Id,
                            Ledger__c = LedgerHandler.getShadowLedger(testData.ledgers[4].Id).Id
                    )
            };
            insert glAccountDefaults;
            GLAccountDefaultsHandler.instance = null;

            Billing__c testBilling = testData.billings[0];
            testBilling.Status__c = 'Approved';
            testBilling.Ledger__c = testData.ledgers[4].Id;
            update testBilling;

            Cash_Receipt__c testCR = testData.cashReceipts[0];
            CashReceiptPostService.unpostCashReceipts(new List<Cash_Receipt__c>{testCR});

            testCR.Ledger__c = testData.ledgers[4].Id;
            update testCR;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});

            System.assertEquals(true, results[0].isSuccess);
            System.assertEquals('Posted', [SELECT Status__c FROM Billing__c WHERE Id = :testBilling.Id].Status__c);

            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>{
                    new Billing_Cash_Receipt__c(
                            Cash_Receipt__c = testCR.Id,
                            Billing__c = testBilling.Id,
                            Accounting_Period__c = testData.acctPeriods[1].Id,
                            Applied_Amount__c = 12,
                            Adjustment_GL_Account__c = testData.glAccounts[16].Id,
                            Adjustment_Amount__c = 6
                    )
            };
            insert billingCashReceipts;

            List<Transaction__c> transactions = [
                    SELECT Id, GL_Account__c, GL_Account__r.Name, Amount__c, Billing_Line__c
                    FROM Transaction__c
                    WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id
            ];
            System.assertEquals(9, transactions.size());

            Decimal sum = 0;
            for (Transaction__c transactionItem : transactions) {
                sum += transactionItem.Amount__c;
                if (transactionItem.Billing_Line__c == testData.billingLines[0].Id && transactionItem.GL_Account__c == testData.glAccounts[10].Id) {
                    System.assertEquals(-8, transactionItem.Amount__c);
                }
                if (transactionItem.Billing_Line__c == testData.billingLines[1].Id && transactionItem.GL_Account__c == testData.glAccounts[10].Id) {
                    System.assertEquals(-10, transactionItem.Amount__c);
                }
                if (transactionItem.GL_Account__c == testData.glAccounts[16].Id) {
                    System.assertEquals(6, transactionItem.Amount__c);
                }
            }
            System.assertEquals(0, sum);
            Test.stopTest();
        }
    }

}