@isTest
private class AccountPayablePayBatchTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testAccountPayablePayBatchNoSelectionError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            testData.payables.get(1).Status__c = 'Approved';
            testData.payables.get(2).Status__c = 'Approved';
            update testData.payables;

            List<Account_Payable__c> testAccountPayables = new List<Account_Payable__c>{
                testData.payables.get(0),
                testData.payables.get(1),
                testData.payables.get(2)
            };

            for (PostResult result : AccountPayablePostService.postAccountPayables(testAccountPayables)) {
                System.assertEquals(
                    true,
                    result.isSuccess
                );
            }

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT Id, Total__c, Payment_Status__c, Contact__c, Vendor__c, Employee__c
                FROM Account_Payable__c
                WHERE Id IN :testData.payables
            ]);

            AccountPayablePayBatch apb = new AccountPayablePayBatch(setController);

            Test.stopTest();

            System.assertEquals(
                true,
                apb.paymentResultDispatcher.isGeneralErrorExists()
            );
        }
    }
    
    @isTest
    private static void testAccountPayablePayBatchDiscountAmountSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            testData.payables.get(0).Discount_Amount__c = 10;
            update testData.payables.get(0);

            PostResult result = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(0)}).get(0);

            System.assertEquals(
                true,
                result.isSuccess
            );

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(0).Id
            ]);
            setController.setSelected(setController.getRecords());

            AccountPayablePayBatch apb = new AccountPayablePayBatch(setController);
            for (CashDisbursementWrapper cdw : apb.wrappedCDs) {
                cdw.cashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(0).Start_Date__c.addDays(3);
            }
            apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            apb.wrappedCDs.get(0).cashDisbursement.Accounting_Period__c = testData.acctPeriods.get(0).Id;
            apb.payBatch();

            Test.stopTest();

            System.assertEquals(
                1,
                [SELECT COUNT() FROM Cash_Disbursement__c WHERE Cash_Disbursement_Batch__c = :apb.cashDisbursementBatchToInsert.Id]
            );

            System.assertEquals(
                apb.accountPayables.get(0).Total__c - testData.payables.get(0).Discount_Amount__c,
                [SELECT Id, Amount__c FROM Cash_Disbursement__c WHERE Cash_Disbursement_Batch__c = :apb.cashDisbursementBatchToInsert.Id].Amount__c
            );
        }
    }

    @isTest
    private static void testAccountPayablePayBatchCreditMemoWithDiscountSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            testData.payables.get(0).Discount_Amount__c = 10;
            update testData.payables.get(0);

            PostResult result = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(0)}).get(0);

            System.assertEquals(
                true,
                result.isSuccess
            );

            Account_Payable__c acctPayable = testData.payables.get(0).clone(false, true);
            acctPayable.Payee_Reference__c += '456';
            acctPayable.Discount_Amount__c = 0;
            insert acctPayable;

            Account_Payable_Line__c acctPayableLine = testData.payableLines.get(0).clone(false, true);
            acctPayableLine.Account_Payable__c = acctPayable.Id;
            acctPayableLine.Amount__c = -100;
            insert acctPayableLine;

            acctPayable.Discount_Amount__c = 10;
            update acctPayable;

            AP_Credit_Memo__c creditMemo = new AP_Credit_Memo__c();
            creditMemo.Account_Payable_Invoice__c = testData.payables.get(0).Id;
            creditMemo.Account_Payable_Credit_Memo__c = acctPayable.Id;
            creditMemo.Amount__c = -10;
            creditMemo.Accounting_Period__c = testData.acctPeriods.get(0).Id;
            insert creditMemo;

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(0).Id
            ]);
            setController.setSelected(setController.getRecords());

            AccountPayablePayBatch apb = new AccountPayablePayBatch(setController);
            for (CashDisbursementWrapper cdw : apb.wrappedCDs) {
                cdw.cashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(0).Start_Date__c.addDays(3);
            }
            apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            apb.payBatch();

            Test.stopTest();

            System.assertEquals(
                1,
                [SELECT COUNT() FROM Cash_Disbursement__c WHERE Cash_Disbursement_Batch__c = :apb.cashDisbursementBatchToInsert.Id]
            );

            System.assertEquals(
                apb.accountPayables.get(0).Total__c - testData.payables.get(0).Discount_Amount__c - apb.accountPayables.get(0).Credit_Memo_Applied_Amount__c,
                [SELECT Id, Amount__c FROM Cash_Disbursement__c WHERE Cash_Disbursement_Batch__c = :apb.cashDisbursementBatchToInsert.Id].Amount__c
            );
        }
    }

    @isTest
    private static void testAccountPayablePayBatchCreditMemoWithNoDiscountSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            testData.payables.get(0).Discount_Amount__c = 0;
            update testData.payables.get(0);

            PostResult result = AccountPayablePostService.postAccountPayables(
                new List<Account_Payable__c>{testData.payables.get(0)}
            ).get(0);

            System.assertEquals(
                true,
                result.isSuccess
            );

            Account_Payable__c acctPayable = testData.payables.get(0).clone(false, true);
            acctPayable.Payee_Reference__c += '456';
            insert acctPayable;

            Account_Payable_Line__c acctPayableLine = testData.payableLines.get(0).clone(false, true);
            acctPayableLine.Account_Payable__c = acctPayable.Id;
            acctPayableLine.Amount__c = -100;
            insert acctPayableLine;

            AP_Credit_Memo__c creditMemo = new AP_Credit_Memo__c();
            creditMemo.Account_Payable_Invoice__c = testData.payables.get(0).Id;
            creditMemo.Account_Payable_Credit_Memo__c = acctPayable.Id;
            creditMemo.Amount__c = -10;
            creditMemo.Accounting_Period__c = testData.acctPeriods.get(0).Id;
            insert creditMemo;

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(0).Id
            ]);

            setController.setSelected(setController.getRecords());
            AccountPayablePayBatch apb = new AccountPayablePayBatch(setController);
            for (CashDisbursementWrapper cdw : apb.wrappedCDs) {
                cdw.cashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(0).Start_Date__c.addDays(3);
            }
            apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            apb.payBatch();

            Test.stopTest();

            System.assertEquals(
                1,
                [SELECT COUNT() FROM Cash_Disbursement__c WHERE Cash_Disbursement_Batch__c = :apb.cashDisbursementBatchToInsert.Id]
            );

            System.assertEquals(
                apb.accountPayables.get(0).Total__c - testData.payables.get(0).Discount_Amount__c - apb.accountPayables.get(0).Credit_Memo_Applied_Amount__c,
                [SELECT Id, Amount__c FROM Cash_Disbursement__c WHERE Cash_Disbursement_Batch__c = :apb.cashDisbursementBatchToInsert.Id].Amount__c
            );
        }
    }

    @isTest
    private static void testAccountPayablePayBatchDiscountAmountVendorDiscountAppliedSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            testData.payables.get(0).Discount_Amount__c = 0;
            testData.payables.get(0).Date__c = System.today() -3;
            testData.payables.get(0).Due_Date__c = System.today() -3;
            update testData.payables;

            PostResult result = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(0)}).get(0);

            System.assertEquals(
                true,
                result.isSuccess
            );

            testData.accounts.get(0).Discount_Days_Due__c = 30;
            testData.accounts.get(0).Discount_Percent__c = 10;
            update testData.accounts.get(0);

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(0).Id
            ]);
            setController.setSelected(setController.getRecords());

            AccountPayablePayBatch apb = new AccountPayablePayBatch(setController);
            for (CashDisbursementWrapper cdw : apb.wrappedCDs) {
                cdw.cashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(3);
            }
            apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            apb.payBatch();

            Test.stopTest();

            System.assertEquals(
                1,
                [SELECT COUNT() FROM Cash_Disbursement__c WHERE Cash_Disbursement_Batch__c = :apb.cashDisbursementBatchToInsert.Id]
            );

            System.assertEquals(
                apb.accountPayables.get(0).Total__c - (apb.accountPayables.get(0).Total__c * (testData.accounts.get(0).Discount_Percent__c / 100)),
                [SELECT Id, Amount__c From Cash_Disbursement__c WHERE Cash_Disbursement_Batch__c = :apb.cashDisbursementBatchToInsert.Id].Amount__c
            );

            System.assertEquals(
                apb.accountPayables.get(0).Total__c * (testData.accounts.get(0).Discount_Percent__c / 100),
                [SELECT Id, Total__c, Discount_Amount__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Discount_Amount__c
            );
        }
    }

    @isTest
    private static void testAccountPayablePayBatchAccountingPeriodBeforeError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            testData.payables.get(0).Discount_Amount__c = 0;
            testData.payables.get(0).Date__c = System.today() -3;
            testData.payables.get(0).Due_Date__c = System.today() -3;
            testData.payables.get(0).Accounting_Period__c = testData.acctPeriods.get(1).Id;
            update testData.payables.get(0);

            PostResult result = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(0)}).get(0);

            System.assertEquals(
                true,
                result.isSuccess
            );

            testData.accounts.get(0).Discount_Days_Due__c = 30;
            testData.accounts.get(0).Discount_Percent__c = 10;
            update testData.accounts.get(0);

            testData.acctPeriods.get(0).Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods.get(0);

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(0).Id
            ]);
            setController.setSelected(setController.getRecords());

            AccountPayablePayBatch apb = new AccountPayablePayBatch(setController);
            for (CashDisbursementWrapper cdw : apb.wrappedCDs) {
                cdw.cashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(0).Start_Date__c.addDays(3);
            }
            apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            apb.payBatch();

            Test.stopTest();

            System.assertEquals(
                true,
                apb.paymentResultDispatcher.isGeneralErrorExists()
            );
        }
    }

    @isTest
    private static void testAccountPayablePayBatchWithCashFlowCategory() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables()
                .createCashFlowCategories(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            Id defaultCDCategory = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.DEFAULT_CASH_DISBURSEMENT_CATEGORY)?.GL_Account__c;
            System.assertEquals(
                'Payments to suppliers',
                [SELECT Id, Name FROM GL_Account__c WHERE Id = :defaultCDCategory].Name
            );

            testData.payables.get(3).Status__c = 'Approved';
            testData.payables.get(3).Accounting_Period__c = testData.acctPeriods.get(0).Id;
            update testData.payables.get(3);

            PostResult result = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(3)}).get(0);

            System.assertEquals(
                true,
                result.isSuccess
            );

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(3).Id
            ]);
            setController.setSelected(setController.getRecords());

            AccountPayablePayBatch apb = new AccountPayablePayBatch(setController);
            for (CashDisbursementWrapper cdw : apb.wrappedCDs) {
                cdw.cashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(0).Start_Date__c.addDays(3);
                cdw.cashDisbursement.Cash_Flow_Category__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.DEFAULT_CASH_RECEIPT_CATEGORY)?.GL_Account__c;
            }
            apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            apb.payBatch();

            Test.stopTest();

            List<AP_Disbursement__c> newAPDs = [
                SELECT Id, Cash_Disbursement__c
                FROM AP_Disbursement__c
                WHERE Account_Payable__c = :testData.payables.get(3).Id
            ];

            System.assertEquals(
                1,
                newAPDs.size()
            );

            System.assertEquals(
                'Paid',
                [SELECT Id, Payment_Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(3).Id].Payment_Status__c
            );

            System.assertEquals(
                defaultsBySpecDevNames.get(GLAccountDefaultsHandler.DEFAULT_CASH_RECEIPT_CATEGORY)?.GL_Account__c,
                [SELECT Cash_Flow_Category__c FROM Cash_Disbursement__c WHERE Id = :newAPDs.get(0).Cash_Disbursement__c LIMIT 1].Cash_Flow_Category__c
            );
        }
    }

    @isTest
    private static void testAccountPayablePayBatchSummarySuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            testData.payables.get(1).Status__c = 'Approved';
            testData.payables.get(2).Status__c = 'Approved';
            testData.payables.get(3).Status__c = 'Approved';
            update testData.payables;

            List<Account_Payable__c> testAccountPayables = new List<Account_Payable__c>{
                    testData.payables.get(0),
                    testData.payables.get(1),
                    testData.payables.get(2),
                    testData.payables.get(3)
            };

            for (PostResult result : AccountPayablePostService.postAccountPayables(testAccountPayables)) {
                System.assertEquals(
                    true,
                    result.isSuccess
                );
            }

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id IN :testData.payables
            ]);
            setController.setSelected(setController.getRecords());

            AccountPayablePayBatch apb = new AccountPayablePayBatch(setController);
            for (CashDisbursementWrapper cdw : apb.wrappedCDs) {
                cdw.cashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(3);
            }
            apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            apb.payBatch();

            Test.stopTest();

            System.assertEquals(
                1,
                [SELECT COUNT() FROM Cash_Disbursement__c WHERE Vendor__c = :testData.payables.get(0).Vendor__c]
            );

            System.assertEquals(
                1,
                [SELECT COUNT() FROM Cash_Disbursement__c WHERE Contact__c = :testData.payables.get(1).Contact__c]
            );

            System.assertEquals(
                1,
                [SELECT COUNT() FROM Cash_Disbursement__c WHERE Employee__c = :testData.payables.get(2).Employee__c]
            );
        }
    }

    @isTest
    private static void testAccountPayablePayBatchWithDefaultGLAVsAndGLAccountsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables()
                .createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            update testData.payables;

            //setup default GLAV values for the Billing's Customer(Lookup to Account)
            Account testCustomer = new Account(
                Id = testData.payables.get(0).Vendor__c,
                GL_Account_Variable_1__c = testData.accountingVariables1.get(0).Id,
                GL_Account_Variable_2__c = testData.accountingVariables2.get(0).Id,
                GL_Account_Variable_3__c = testData.accountingVariables3.get(0).Id,
                GL_Account_Variable_4__c = testData.accountingVariables4.get(0).Id
            );
            update testCustomer;

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(0)})) {
                System.assertEquals(
                    true,
                    result.isSuccess
                );
            }

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id IN :testData.payables
            ]);
            setController.setSelected(setController.getRecords());

            AccountPayablePayBatch controller = new AccountPayablePayBatch(setController);
            for (CashDisbursementWrapper cdw : controller.wrappedCDs) {
                cdw.cashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(3);
            }
            controller.uiCashDisbursement.Accounting_Period__c = testData.acctPeriods.get(0).Id;
            controller.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            controller.payBatch();

            Test.stopTest();

            System.assertEquals(
                1,
                [SELECT COUNT() FROM Cash_Disbursement__c WHERE Vendor__c = :testCustomer.Id]
            );

            List<Cash_Disbursement__c> validatedTestCashDisbursements = [
                SELECT  Id,
                        Bank_Account__c,
                        Debit_GL_Account__c,
                        GL_Account_Variable_1__c,
                        GL_Account_Variable_2__c,
                        GL_Account_Variable_3__c,
                        GL_Account_Variable_4__c
                FROM Cash_Disbursement__c
                WHERE Vendor__c = :testCustomer.Id
            ];

            Ledger__c testDefaultLedger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(LedgerHandler.getLedgerId());
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testDefaultLedger.Id);
            for (Cash_Disbursement__c cashDisbursement : validatedTestCashDisbursements) {
                System.assertEquals(
                    testDefaultLedger.Default_Bank_Account__c,
                    cashDisbursement.Bank_Account__c
                );

                System.assertEquals(
                    defaultsBySpecDevNames.get(GLAccountDefaultsHandler.PREPAID_EXPENSE_GL_ACCOUNT)?.GL_Account__c,
                    cashDisbursement.Debit_GL_Account__c
                );

                System.assertEquals(
                    testCustomer.GL_Account_Variable_1__c,
                    cashDisbursement.GL_Account_Variable_1__c
                );

                System.assertEquals(
                    testCustomer.GL_Account_Variable_2__c,
                    cashDisbursement.GL_Account_Variable_2__c
                );

                System.assertEquals(
                    testCustomer.GL_Account_Variable_3__c,
                    cashDisbursement.GL_Account_Variable_3__c
                );

                System.assertEquals(
                    testCustomer.GL_Account_Variable_4__c,
                    cashDisbursement.GL_Account_Variable_4__c
                );
            }
        }
    }

    @isTest
    private static void testRefreshCheckNumber() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createCashDisbursementBatches();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Cash_Disbursement__c testCD = new Cash_Disbursement__c(
                Cash_Disbursement_Batch__c = testData.cashDisbursementBatch.get(0).Id,
                Disbursement_Date__c = testData.acctPeriods.get(0).Start_Date__c,
                Type__c = 'Check',
                Amount__c = 500,
                Source__c = 'Account Payable',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Employee__c = UserInfo.getUserId(),
                Accounting_Period__c = testData.acctPeriods.get(0).Id,
                Status__c = 'In Process',
                Reference__c = 'someReference',
                Check_Number__c = 99
            );

            insert testCD;

            Decimal nextCheckNumber = AccountPayablePaymentHandler.refreshCheckNumber(testData.glAccounts.get(0).Id);

            Test.stopTest();

            System.assertEquals(
                100,
                nextCheckNumber
            );
        }
    }

    @isTest
    private static void testPayBatchAndPost() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            testData.payables.get(0).Accounting_Period__c = testData.acctPeriods.get(0).Id;
            update testData.payables.get(0);

            testData.payables.get(3).Status__c = 'Approved';
            testData.payables.get(3).Accounting_Period__c = testData.acctPeriods.get(0).Id;
            update testData.payables.get(3);

            List<Account_Payable__c> testAccountPayables = new List<Account_Payable__c>{
                testData.payables.get(0),
                testData.payables.get(3)
            };

            for (PostResult result : AccountPayablePostService.postAccountPayables(testAccountPayables)) {
                System.assertEquals(
                    true,
                    result.isSuccess
                );
            }

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                    SELECT Id
                    FROM Account_Payable__c
                    WHERE Id IN :testData.payables
            ]);
            setController.setSelected(setController.getRecords());

            AccountPayablePayBatch controller = new AccountPayablePayBatch(setController);
            for (CashDisbursementWrapper cdw : controller.wrappedCDs) {
                cdw.cashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(3);
            }
            controller.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            controller.uiCashDisbursement.Amount__c = [SELECT Id, Total__c FROM Account_Payable__c WHERE Id = :testData.payables.get(3).Id].Total__c;
            controller.payBatchAndPost();

            Test.stopTest();

            System.assertEquals(
                false,
                controller.isError
            );

            List<Cash_Disbursement__c> testCashDisbursements = [
                SELECT Id, Status__c
                FROM Cash_Disbursement__c
                WHERE Cash_Disbursement_Batch__c = :controller.cashDisbursementBatchToInsert.Id
            ];

            System.assert(
                !testCashDisbursements.isEmpty()
            );

            System.assertEquals(
                'Posted',
                testCashDisbursements.get(0).Status__c
            );

            System.assertEquals(
                'Posted',
                testCashDisbursements.get(1).Status__c
            );
        }
    }

    @IsTest
    private static void testAccountPayablePayBatchReverseCharge() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency() //will throw an exception in case of non-MC org
                .setHeaderLevelPost()
                .createTaxGroups()
                .setAvaVATSelected();

            System.runAs(testData.users.get(1)) {
                Test.startTest();
                String theNewCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(theNewCurrencyIsoCode)) {
                    return;
                }
                //Create Ledger for foreign currency
                Ledger__c theLedger = testData.ledgers.get(0).clone();
                theLedger.put('CurrencyIsoCode', theNewCurrencyIsoCode);
                insert theLedger;

                //Create Payables
                List<Account_Payable__c> payables = new List<Account_Payable__c>();
                Account_Payable__c payable1 = new Account_Payable__c(
                    Payee_Reference__c = 'payable1',
                    Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                    Payment_Status__c = 'Unpaid',
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Due_Date__c = testData.acctPeriods[0].End_Date__c,
                    Vendor__c = testData.accounts[0].Id,
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Ledger__c = theLedger.Id
                );
                payable1.put('CurrencyIsoCode', theNewCurrencyIsoCode);
                payables.add(payable1);

                Account_Payable__c payable2 = new Account_Payable__c(
                    Payee_Reference__c = 'payable2',
                    Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                    Payment_Status__c = 'Unpaid',
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Due_Date__c = testData.acctPeriods[0].End_Date__c,
                    Contact__c = testData.contacts[0].Id,
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Ledger__c = theLedger.Id
                );
                payable2.put('CurrencyIsoCode', theNewCurrencyIsoCode);
                payables.add(payable2);
                insert payables;
                Set<Id> payableIds = new Set<Id>(new Map<Id, Account_Payable__c>(payables).keySet());
                //Create Payable Lines
                List<Account_Payable_Line__c> lines = new List<Account_Payable_Line__c>();
                Account_Payable_Line__c line1 = new Account_Payable_Line__c(
                    Account_Payable__c = payable1.Id,
                    Unit_Cost__c = 100,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = testData.glAccounts[16].Id,
                    Tax_Group__c = testData.taxGroups[3].Id
                );
                lines.add(line1);
                Account_Payable_Line__c line2 = new Account_Payable_Line__c(
                    Account_Payable__c = payable2.Id,
                    Unit_Cost__c = 100,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = testData.glAccounts[16].Id,
                    Tax_Group__c = testData.taxGroups[3].Id
                );
                lines.add(line2);
                insert lines;

                payables = [
                    SELECT  Id,
                            Reverse_Charge__c,
                            VAT_Line_Count__c,
                            Reverse_Charge_Count__c,
                            Purchase_Tax3__c,
                            Vendor__c,
                            Contact__c,
                            Payment_Status__c
                    FROM Account_Payable__c
                    WHERE Id IN :payableIds
                ];

                System.assertEquals(true, payables[0].Reverse_Charge__c);
                System.assertEquals(1, payables[0].VAT_Line_Count__c);
                System.assertEquals(1, payables[0].Reverse_Charge_Count__c);
                System.assertEquals(20, payables[0].Purchase_Tax3__c.setScale(2, System.RoundingMode.HALF_UP));
                System.assertEquals('Unpaid', payables[0].Payment_Status__c);

                System.assertEquals(true, payables[1].Reverse_Charge__c);
                System.assertEquals(1, payables[1].VAT_Line_Count__c);
                System.assertEquals(1, payables[1].Reverse_Charge_Count__c);
                System.assertEquals(20, payables[1].Purchase_Tax3__c.setScale(2, System.RoundingMode.HALF_UP));
                System.assertEquals('Unpaid', payables[1].Payment_Status__c);

                //Post all payables
                AbstractPostHandler postHandler = new AccountPayablePostHandler();
                List<PostResult> postResults = postHandler.post(payables);
                System.assertEquals(true, postResults[0].isSuccess);
                System.assertEquals(true, postResults[1].isSuccess);

                ApexPages.StandardSetController setController = new ApexPages.StandardSetController(payables);
                setController.setSelected(setController.getRecords());

                AccountPayablePayBatch apb = new AccountPayablePayBatch(setController);
                for (CashDisbursementWrapper cdw : apb.wrappedCDs) {
                    cdw.cashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(3);
                }
                apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
                apb.payBatch();
                Test.stopTest();

                payable1 = [SELECT Payment_Status__c, Purchase_Tax3__c, Total__c FROM Account_Payable__c WHERE Id = :payable1.Id];
                payable2 = [SELECT Payment_Status__c, Purchase_Tax3__c, Total__c FROM Account_Payable__c WHERE Id = :payable2.Id];
                System.assertEquals('Paid', payable1.Payment_Status__c);
                System.assertEquals('Paid', payable2.Payment_Status__c);

                Cash_Disbursement__c cd1 = [SELECT Id, Amount__c FROM Cash_Disbursement__c WHERE Vendor__c = :payables[0].Vendor__c];
                Cash_Disbursement__c cd2 = [SELECT Id, Amount__c FROM Cash_Disbursement__c WHERE Contact__c = :payables[1].Contact__c];
                //Total (100) - Purchase Tax (20) expected
                System.assertEquals((payable1.Total__c - payable1.Purchase_Tax3__c).setScale(2, System.RoundingMode.HALF_UP), cd1.Amount__c);
                System.assertEquals((payable2.Total__c - payable2.Purchase_Tax3__c).setScale(2, System.RoundingMode.HALF_UP), cd2.Amount__c);
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }

    }

    @IsTest
    private static void testAccountPayablePayBatchReverseChargeDiscountFromVendor() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency() //will throw an exception in case of non-MC org
                .setHeaderLevelPost()
                .createTaxGroups()
                .setAvaVATSelected();

            System.runAs(testData.users.get(1)) {
                Test.startTest();
                String theNewCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(theNewCurrencyIsoCode)) {
                    return;
                }
                //Create Ledger for foreign currency
                Ledger__c theLedger = testData.ledgers.get(0).clone();
                theLedger.put('CurrencyIsoCode', theNewCurrencyIsoCode);
                insert theLedger;

                //Populate Discount on Account
                Account testAccount = testData.accounts[0];
                testAccount.Discount_Days_Due__c = 30;
                testAccount.Discount_Percent__c = 10;
                update testAccount;

                //Create Payables
                List<Account_Payable__c> payables = new List<Account_Payable__c>();
                Account_Payable__c payable1 = new Account_Payable__c(
                    Payee_Reference__c = 'payable1',
                    Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                    Payment_Status__c = 'Unpaid',
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Due_Date__c = testData.acctPeriods[0].Start_Date__c.addDays(30),
                    Vendor__c = testAccount.Id,
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Ledger__c = theLedger.Id
                );
                payable1.put('CurrencyIsoCode', theNewCurrencyIsoCode);
                payables.add(payable1);

                Account_Payable__c payable2 = new Account_Payable__c(
                    Payee_Reference__c = 'payable2',
                    Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                    Payment_Status__c = 'Unpaid',
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Due_Date__c = testData.acctPeriods[0].End_Date__c,
                    Contact__c = testData.contacts[0].Id,
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Ledger__c = theLedger.Id
                );
                payable2.put('CurrencyIsoCode', theNewCurrencyIsoCode);
                payables.add(payable2);
                insert payables;
                Set<Id> payableIds = new Set<Id>(new Map<Id, Account_Payable__c>(payables).keySet());
                //Create Payable Lines
                List<Account_Payable_Line__c> lines = new List<Account_Payable_Line__c>();
                Account_Payable_Line__c line1 = new Account_Payable_Line__c(
                    Account_Payable__c = payable1.Id,
                    Unit_Cost__c = 100,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = testData.glAccounts[16].Id,
                    Tax_Group__c = testData.taxGroups[3].Id
                );
                lines.add(line1);
                Account_Payable_Line__c line2 = new Account_Payable_Line__c(
                    Account_Payable__c = payable2.Id,
                    Unit_Cost__c = 100,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = testData.glAccounts[16].Id,
                    Tax_Group__c = testData.taxGroups[3].Id
                );
                lines.add(line2);
                insert lines;

                payables = [
                    SELECT  Id,
                            Reverse_Charge__c,
                            VAT_Line_Count__c,
                            Reverse_Charge_Count__c,
                            Purchase_Tax3__c,
                            Vendor__c,
                            Contact__c,
                            Payment_Status__c
                    FROM Account_Payable__c
                    WHERE Id IN :payableIds
                ];

                System.assertEquals(true, payables[0].Reverse_Charge__c);
                System.assertEquals(1, payables[0].VAT_Line_Count__c);
                System.assertEquals(1, payables[0].Reverse_Charge_Count__c);
                System.assertEquals(20, payables[0].Purchase_Tax3__c.setScale(2, System.RoundingMode.HALF_UP));
                System.assertEquals('Unpaid', payables[0].Payment_Status__c);

                System.assertEquals(true, payables[1].Reverse_Charge__c);
                System.assertEquals(1, payables[1].VAT_Line_Count__c);
                System.assertEquals(1, payables[1].Reverse_Charge_Count__c);
                System.assertEquals(20, payables[1].Purchase_Tax3__c.setScale(2, System.RoundingMode.HALF_UP));
                System.assertEquals('Unpaid', payables[1].Payment_Status__c);

                //Post all payables
                AbstractPostHandler postHandler = new AccountPayablePostHandler();
                List<PostResult> postResults = postHandler.post(payables);
                System.assertEquals(true, postResults[0].isSuccess);
                System.assertEquals(true, postResults[1].isSuccess);

                ApexPages.StandardSetController setController = new ApexPages.StandardSetController(payables);
                setController.setSelected(setController.getRecords());

                AccountPayablePayBatch apb = new AccountPayablePayBatch(setController);
                for (CashDisbursementWrapper cdw : apb.wrappedCDs) {
                    cdw.cashDisbursement.Disbursement_Date__c = testData.acctPeriods[0].Start_Date__c.addDays(3);
                }
                apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
                apb.payBatch();
                Test.stopTest();

                payable1 = [SELECT Payment_Status__c, Purchase_Tax3__c, Discount_Amount__c, Total__c FROM Account_Payable__c WHERE Id = :payable1.Id];
                payable2 = [SELECT Payment_Status__c, Purchase_Tax3__c, Discount_Amount__c, Total__c FROM Account_Payable__c WHERE Id = :payable2.Id];
                System.assertEquals('Paid', payable1.Payment_Status__c);
                System.assertEquals('Paid', payable2.Payment_Status__c);
                System.assertEquals(10, payable1.Discount_Amount__c);

                Cash_Disbursement__c cd1 = [SELECT Id, Amount__c FROM Cash_Disbursement__c WHERE Vendor__c = :payables[0].Vendor__c];
                Cash_Disbursement__c cd2 = [SELECT Id, Amount__c FROM Cash_Disbursement__c WHERE Contact__c = :payables[1].Contact__c];
                //Total (100) - Purchase Tax (10) expected
                System.assertEquals(
                    (payable1.Total__c - payable1.Discount_Amount__c - payable1.Purchase_Tax3__c).setScale(2, System.RoundingMode.HALF_UP),
                    cd1.Amount__c.setScale(2, System.RoundingMode.HALF_UP)
                );
                System.assertEquals(
                    (payable2.Total__c - payable2.Purchase_Tax3__c).setScale(2, System.RoundingMode.HALF_UP),
                    cd2.Amount__c.setScale(2, System.RoundingMode.HALF_UP)
                );
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }

    }

    @isTest
    private static void testPayBatch1099FailBlankBox() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {

            Integer Year = Date.today().Year(); 
            
            Accounting_Period__c acctPeriod = new Accounting_Period__c(
                Name = Year + '-01',
                Start_Date__c = Date.newInstance(Year, 1, 1),
                End_Date__c = Date.newInstance(Year, 12, 31),
                Status__c = AccountingPeriodActions.OPEN_STATUS
            );
            insert acctPeriod; 
            
            Account acct = testData.accounts[0];
            acct.X1099_Vendor__c = true;
            Id formTypeId = [SELECT Id, Effective_Year__c FROM Form_Type__mdt WHERE Effective_Year__c <= :Year ORDER BY Effective_Year__c DESC LIMIT 1].Id;
            acct.Default_Form_Category_Id__c = [SELECT Id from Form_Category__mdt WHERE Form_Type__c = :formTypeId LIMIT 1].Id;
            update acct;

            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            testData.payables.get(0).Accounting_Period__c = acctPeriod.Id;
            update testData.payables.get(0);

            testData.payables.get(3).Status__c = 'Approved';
            testData.payables.get(3).Accounting_Period__c = acctPeriod.Id;
            update testData.payables.get(3);

            List<Account_Payable__c> testAccountPayables = new List<Account_Payable__c>{
                testData.payables.get(0),
                testData.payables.get(3)
            };

            for (PostResult result : AccountPayablePostService.postAccountPayables(testAccountPayables)) {
                System.assertEquals(
                    true,
                    result.isSuccess
                );
            }

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                    SELECT Id
                    FROM Account_Payable__c
                    WHERE Id IN :testData.payables
            ]);
            setController.setSelected(setController.getRecords());

            AccountPayablePayBatch controller = new AccountPayablePayBatch(setController);
            for (CashDisbursementWrapper cdw : controller.wrappedCDs) {
                cdw.cashDisbursement.Disbursement_Date__c = acctPeriod.Start_Date__c.addDays(3);
                cdw.cashDisbursement.Form_Category_Id__c = formTypeId;
                cdw.cashDisbursement.Form_1099_Box__c = '';

            }
            controller.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            controller.uiCashDisbursement.Amount__c = [SELECT Id, Total__c FROM Account_Payable__c WHERE Id = :testData.payables.get(3).Id].Total__c;
            controller.payBatchAndPost();

            Test.stopTest();

            System.assertEquals(
                false,
                controller.isError
            );

            for (ApexPages.Message message: ApexPages.getMessages()) {
                System.assertEquals(AccountPayablePaymentHandler.FORM_CATEGORY_INVALID_ERROR_MESSAGE, message.getSummary());      
            }
        }
    }   
    
    @isTest
    private static void testPayBatch1099FailInvalidCategory() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {

            Account acct = testData.accounts[0];
            acct.X1099_Vendor__c = true;
            Id formTypeId = [SELECT Id, Effective_Year__c FROM Form_Type__mdt WHERE Effective_Year__c = 2001 LIMIT 1].Id;
            acct.Default_Form_Category_Id__c = [SELECT Id from Form_Category__mdt WHERE Form_Type__c = :formTypeId LIMIT 1].Id;
            update acct;

            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            testData.payables.get(0).Accounting_Period__c = testData.acctPeriods.get(0).Id;
            update testData.payables.get(0);

            testData.payables.get(3).Status__c = 'Approved';
            testData.payables.get(3).Accounting_Period__c = testData.acctPeriods.get(0).Id;
            update testData.payables.get(3);

            List<Account_Payable__c> testAccountPayables = new List<Account_Payable__c>{
                testData.payables.get(0),
                testData.payables.get(3)
            };

            for (PostResult result : AccountPayablePostService.postAccountPayables(testAccountPayables)) {
                System.assertEquals(
                    true,
                    result.isSuccess
                );
            }

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                    SELECT Id
                    FROM Account_Payable__c
                    WHERE Id IN :testData.payables
            ]);
            setController.setSelected(setController.getRecords());

            AccountPayablePayBatch controller = new AccountPayablePayBatch(setController);
            for (CashDisbursementWrapper cdw : controller.wrappedCDs) {
                cdw.cashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(3);
                cdw.cashDisbursement.Form_Category_Id__c = formTypeId;
                cdw.cashDisbursement.Form_1099_Box__c = acct.Default_Form_Category_Id__c;

            }
            controller.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            controller.uiCashDisbursement.Amount__c = [SELECT Id, Total__c FROM Account_Payable__c WHERE Id = :testData.payables.get(3).Id].Total__c;
            controller.payBatchAndPost();

            Test.stopTest();

            System.assertEquals(
                false,
                controller.isError
            );

            for (ApexPages.Message message: ApexPages.getMessages()) {
                System.assertEquals(
                    String.format(AccountPayablePaymentHandler.FORM_TYPE_INVALID_ERROR_MESSAGE, new List<String>{testData.acctPeriods.get(1).Start_Date__c.addDays(3).format()}), 
                    message.getSummary());       
            }
        }
    }

    @isTest
    private static void testAPDAppliedDateFromCDDate() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            testData.payables.get(0).Accounting_Period__c = testData.acctPeriods.get(0).Id;
            update testData.payables.get(0);

            testData.payables.get(3).Status__c = 'Approved';
            testData.payables.get(3).Accounting_Period__c = testData.acctPeriods.get(0).Id;
            update testData.payables.get(3);

            List<Account_Payable__c> testAccountPayables = new List<Account_Payable__c>{
                testData.payables.get(0),
                testData.payables.get(3)
            };

            for (PostResult result : AccountPayablePostService.postAccountPayables(testAccountPayables)) {
                System.assertEquals(
                    true,
                    result.isSuccess
                );
            }

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id IN :testData.payables
            ]);
            setController.setSelected(setController.getRecords());

            AccountPayablePayBatch controller = new AccountPayablePayBatch(setController);
            for (CashDisbursementWrapper cdw : controller.wrappedCDs) {
                cdw.cashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(5);
            }
            controller.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            controller.uiCashDisbursement.Amount__c = [SELECT Id, Total__c FROM Account_Payable__c WHERE Id = :testData.payables.get(3).Id].Total__c;
            controller.payBatchAndPost();

            Test.stopTest();

            System.assertEquals(
                false,
                controller.isError
            );

            List<Cash_Disbursement__c> testCashDisbursements = [
                SELECT Id, Status__c
                FROM Cash_Disbursement__c
                WHERE Cash_Disbursement_Batch__c = :controller.cashDisbursementBatchToInsert.Id
            ];

            List<AP_Disbursement__c> results = [
                SELECT Id, Applied_Date__c
                FROM AP_Disbursement__c
                WHERE Account_Payable__c = :testData.payables.get(0).Id OR Account_Payable__c = :testData.payables.get(3).Id
            ];

            System.assert(
                !testCashDisbursements.isEmpty()
            );

            for (AP_Disbursement__c res : results) {
                System.assertEquals(testData.acctPeriods.get(1).Start_Date__c.addDays(5), res.Applied_Date__c);
            }
        }
    }

    @isTest
    private static void testAccountPayablePayBatchForPayableAccountingCDSource() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables()
                .createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Accounting_Settings__c accSetting= testData.settings;
            accSetting.Cash_Disbursement_Source__c = 'Payable';
            update accSetting;

            testData.payables.get(0).Status__c = 'Approved';
            update testData.payables;

            //setup default GLAV values for the Billing's Customer(Lookup to Account)
            Account testCustomer = new Account(
                Id = testData.payables.get(0).Vendor__c,
                GL_Account_Variable_1__c = testData.accountingVariables1.get(0).Id,
                GL_Account_Variable_2__c = testData.accountingVariables2.get(0).Id,
                GL_Account_Variable_3__c = testData.accountingVariables3.get(0).Id,
                GL_Account_Variable_4__c = testData.accountingVariables4.get(0).Id
            );
            update testCustomer;

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(0)})) {
                System.assertEquals(
                    true,
                    result.isSuccess
                );
            }

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id IN :testData.payables
            ]);
            setController.setSelected(setController.getRecords());

            AccountPayablePayBatch controller = new AccountPayablePayBatch(setController);
            for (CashDisbursementWrapper cdw : controller.wrappedCDs) {
                cdw.cashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(3);
            }
            controller.uiCashDisbursement.Accounting_Period__c = testData.acctPeriods.get(0).Id;
            controller.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            controller.payBatch();

            Test.stopTest();

            System.assertEquals(
                1,
                [SELECT COUNT() FROM Cash_Disbursement__c WHERE Vendor__c = :testCustomer.Id]
            );

            List<Cash_Disbursement__c> validatedTestCashDisbursements = [
                SELECT  Id,
                        Bank_Account__c,
                		Debit_GL_Account__c
                FROM Cash_Disbursement__c
                WHERE Vendor__c = :testCustomer.Id
            ];

            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            for (Cash_Disbursement__c cashDisbursement : validatedTestCashDisbursements) {
                System.assertEquals(
                    defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c,
                    cashDisbursement.Debit_GL_Account__c
                );
       		 }
        }
    }

    @isTest
    private static void testAccountPayablePayBatchDebitGLAccountFromUIPage() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables()
                .createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            update testData.payables;

            //setup default GLAV values for the Billing's Customer(Lookup to Account)
            Account testCustomer = new Account(
                Id = testData.payables.get(0).Vendor__c,
                GL_Account_Variable_1__c = testData.accountingVariables1.get(0).Id,
                GL_Account_Variable_2__c = testData.accountingVariables2.get(0).Id,
                GL_Account_Variable_3__c = testData.accountingVariables3.get(0).Id,
                GL_Account_Variable_4__c = testData.accountingVariables4.get(0).Id
            );
            update testCustomer;

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(0)})) {
                System.assertEquals(
                    true,
                    result.isSuccess
                );
            }

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id IN :testData.payables
            ]);
            setController.setSelected(setController.getRecords());

            AccountPayablePayBatch controller = new AccountPayablePayBatch(setController);
            for (CashDisbursementWrapper cdw : controller.wrappedCDs) {
                cdw.cashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(3);
            }
            controller.uiCashDisbursement.Accounting_Period__c = testData.acctPeriods.get(0).Id;
            controller.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            controller.uiCashDisbursement.Debit_GL_Account__c = testData.glAccounts.get(0).Id;
            controller.payBatch();

            Test.stopTest();

            List<Cash_Disbursement__c> validatedTestCashDisbursements = [
                SELECT  Id,
                        Bank_Account__c,
                		Debit_GL_Account__c
                FROM Cash_Disbursement__c
                WHERE Vendor__c = :testCustomer.Id
            ];

            for (Cash_Disbursement__c cashDisbursement : validatedTestCashDisbursements) {

                System.assertEquals(
                    testData.glAccounts.get(0).Id,
                    cashDisbursement.Debit_GL_Account__c
                );
       		 }
        }
    }

    @isTest
    private static void testAccountPayablePayBatchForCashLedger() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables()
                .createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Account_Payable__c accountPayable = testData.payables.get(0);
            accountPayable.Status__c = 'Approved';
            accountPayable.Ledger__c = testData.ledgers.get(3).Id;
            update accountPayable;

            //setup default GLAV values for the Billing's Customer(Lookup to Account)
            Account testCustomer = new Account(
                Id = testData.payables.get(0).Vendor__c,
                GL_Account_Variable_1__c = testData.accountingVariables1.get(0).Id,
                GL_Account_Variable_2__c = testData.accountingVariables2.get(0).Id,
                GL_Account_Variable_3__c = testData.accountingVariables3.get(0).Id,
                GL_Account_Variable_4__c = testData.accountingVariables4.get(0).Id
            );
            update testCustomer;

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(0)})) {
                System.assertEquals(
                    true,
                    result.isSuccess
                );
            }

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id IN :testData.payables
            ]);
            setController.setSelected(setController.getRecords());

            AccountPayablePayBatch controller = new AccountPayablePayBatch(setController);
            for (CashDisbursementWrapper cdw : controller.wrappedCDs) {
                cdw.cashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(3);
            }
            controller.uiCashDisbursement.Accounting_Period__c = testData.acctPeriods.get(0).Id;
            controller.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            controller.uiCashDisbursement.Debit_GL_Account__c = testData.glAccounts.get(0).Id;
            controller.payBatch();

            Test.stopTest();

            List<Cash_Disbursement__c> validatedTestCashDisbursements = [
                SELECT  Id,
                        Bank_Account__c,
                		Debit_GL_Account__c
                FROM Cash_Disbursement__c
                WHERE Vendor__c = :testCustomer.Id
            ];

            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            for (Cash_Disbursement__c cashDisbursement : validatedTestCashDisbursements) {

                System.assertEquals(
                    defaultsBySpecDevNames.get(GLAccountDefaultsHandler.UNAPPLIED_EXPENSE_GL_ACCOUNT)?.GL_Account__c,
                    cashDisbursement.Debit_GL_Account__c
                );
       		 }
        }
    }

    @isTest
    private static void testAccountPayablePayBatchForAllOnHoldPayable() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables()
                .createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Accounting_Settings__c accSetting= testData.settings;
            accSetting.Cash_Disbursement_Source__c = 'Payable';
            update accSetting;

            Account_Payable__c accountPayable = testData.payables.get(0);
            accountPayable.Status__c = 'Approved';
            accountPayable.Ledger__c = testData.ledgers.get(3).Id;
            accountPayable.On_Hold__c = true;
            update accountPayable;

            //setup default GLAV values for the Billing's Customer(Lookup to Account)
            Account testCustomer = new Account(
                Id = testData.payables.get(0).Vendor__c,
                GL_Account_Variable_1__c = testData.accountingVariables1.get(0).Id,
                GL_Account_Variable_2__c = testData.accountingVariables2.get(0).Id,
                GL_Account_Variable_3__c = testData.accountingVariables3.get(0).Id,
                GL_Account_Variable_4__c = testData.accountingVariables4.get(0).Id
            );
            update testCustomer;

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(0)})) {
                System.assertEquals(
                    true,
                    result.isSuccess
                );
            }

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id IN :testData.payables
            ]);
            setController.setSelected(setController.getRecords());

            AccountPayablePayBatch controller = new AccountPayablePayBatch(setController);
            PageReference pageRef = Page.AccountPayablePayBatch;
            Test.setCurrentPage(pageRef);

            Test.stopTest();
            System.assertEquals(
                AccountPayablePaymentHandler.ERR_ON_PAYABLE_PAY_BATCH_PAGE_WHEN_ON_HOLD_IS_CHECKED,
                ApexPages.getMessages().get(0).getSummary()
            );


        }
    }

    @isTest
    private static void testAccountPayablePayBatchForAllOnHoldUnCheckedPayable() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables()
                .createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Accounting_Settings__c accSetting= testData.settings;
            accSetting.Cash_Disbursement_Source__c = 'Payable';
            update accSetting;

            Account_Payable__c accountPayable = testData.payables.get(0);
            accountPayable.Status__c = 'Approved';
            accountPayable.Ledger__c = testData.ledgers.get(3).Id;
            update accountPayable;

            //setup default GLAV values for the Billing's Customer(Lookup to Account)
            Account testCustomer = new Account(
                Id = testData.payables.get(0).Vendor__c,
                GL_Account_Variable_1__c = testData.accountingVariables1.get(0).Id,
                GL_Account_Variable_2__c = testData.accountingVariables2.get(0).Id,
                GL_Account_Variable_3__c = testData.accountingVariables3.get(0).Id,
                GL_Account_Variable_4__c = testData.accountingVariables4.get(0).Id
            );
            update testCustomer;

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(0)})) {
                System.assertEquals(
                    true,
                    result.isSuccess
                );
            }

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id IN :testData.payables
            ]);
            setController.setSelected(setController.getRecords());

            AccountPayablePayBatch controller = new AccountPayablePayBatch(setController);
            PageReference pageRef = Page.AccountPayablePayBatch;
            Test.setCurrentPage(pageRef);

            Test.stopTest();
            Assert.areEqual(0, ApexPages.getMessages().size());


        }
    }

    @isTest
    private static void testAccountPayablePayBatchForOnHoldandUncheckedOnHoldPayable() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables()
                .createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            List<Account_Payable__c> listOfpayables = new List<Account_Payable__c>();

            Accounting_Settings__c accSetting= testData.settings;
            accSetting.Cash_Disbursement_Source__c = 'Payable';
            update accSetting;

            Account_Payable__c accountPayable1 = testData.payables.get(0);
            accountPayable1.Status__c = 'Approved';
            accountPayable1.Ledger__c = testData.ledgers.get(3).Id;
            listOfpayables.add(accountPayable1);

            Account_Payable__c accountPayable2 = testData.payables.get(3);
            accountPayable2.Status__c = 'Approved';
            accountPayable2.Ledger__c = testData.ledgers.get(3).Id;
            accountPayable2.On_Hold__c = true;
            listOfpayables.add(accountPayable2);

            update listOfpayables;

            //setup default GLAV values for the Billing's Customer(Lookup to Account)
            Account testCustomer = new Account(
                Id = testData.payables.get(0).Vendor__c,
                GL_Account_Variable_1__c = testData.accountingVariables1.get(0).Id,
                GL_Account_Variable_2__c = testData.accountingVariables2.get(0).Id,
                GL_Account_Variable_3__c = testData.accountingVariables3.get(0).Id,
                GL_Account_Variable_4__c = testData.accountingVariables4.get(0).Id
            );
            update testCustomer;

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(0),testData.payables.get(3)})) {
                System.assertEquals(
                    true,
                    result.isSuccess
                );
            }

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id IN :testData.payables
            ]);
            setController.setSelected(setController.getRecords());

            AccountPayablePayBatch controller = new AccountPayablePayBatch(setController);
            PageReference pageRef = Page.AccountPayablePayBatch;
            Test.setCurrentPage(pageRef);

            Test.stopTest();
            System.assertEquals(
                AccountPayablePaymentHandler.ERR_ON_PAYABLE_PAY_BATCH_PAGE_WHEN_ON_HOLD_IS_CHECKED,
                ApexPages.getMessages().get(0).getSummary()
            );


        }
    }

}