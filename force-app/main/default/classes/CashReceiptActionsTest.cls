@IsTest
public class CashReceiptActionsTest {
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testPopulateCreditGLAccount() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Cash_Receipt__c testCR = new Cash_Receipt__c(
                Account__c = testData.accounts[0].Id,
                Amount__c = 400,
                Payment_Reference__c = 'uniqRefXXX',
                Status__c = 'In Process',
                Receipt_Date__c = testData.acctPeriods[1].Start_Date__c,
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Purpose__c = 'Customer Receipt'
            );
            insert testCR;
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers[0].Id);
            System.assertEquals(
                defaultsBySpecDevNames.get(GLAccountDefaultsHandler.UNAPPLIED_CASH_GL_ACCOUNT)?.GL_Account__c,
                [
                    SELECT Credit_GL_Account__c
                    FROM Cash_Receipt__c
                    WHERE Id = :testCR.Id
                    LIMIT 1
                ]
                .Credit_GL_Account__c
            );
        }

    }

    @IsTest
    public static void testPopulateCreditGLAccountIfClonedFromPostedRecord() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Cash_Receipt__c existedCR = [
                SELECT
                    Id,
                    Status__c,
                    Credit_GL_Account__c,
                    Account__c,
                    Amount__c,
                    Payment_Reference__c,
                    Accounting_Period__c
                FROM Cash_Receipt__c
                WHERE Id = :testData.cashReceipts[0].Id
            ];
            Cash_Receipt__c testCR = existedCR.clone();
            System.assertEquals('Posted', testCR.Status__c);
            INSERT testCR;
            
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers[0].Id);
            System.assertEquals(
                defaultsBySpecDevNames.get(GLAccountDefaultsHandler.UNAPPLIED_CASH_GL_ACCOUNT)?.GL_Account__c,
                [
                    SELECT Credit_GL_Account__c
                    FROM Cash_Receipt__c
                    WHERE Id = :testCR.Id
                    LIMIT 1
                ]
                .Credit_GL_Account__c
            );
        }

    }

    @IsTest
    public static void testRequiredFieldInsertError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Cash_Receipt__c receipt = testData.cashReceipts[1]
                .clone(false, true);
            receipt.Receipt_Date__c = Date.newInstance(1970, 3, 13);
            receipt.Ledger__c = LedgerHandler.getLedgerId();
            receipt.Accounting_Period__c = null;

            DMLException dmlEx;
            try {
                insert receipt;
            } catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(
                SObjectActions.REQUIRED_FIELD_ERROR,
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void testRequiredFieldUpdateError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            CashReceiptPostService.unpostCashReceipts(
                new List<Cash_Receipt__c>{ testData.cashReceipts[0] }
            );

            testData.cashReceipts[0].Bank_Account__c = null;

            DMLException dmlEx;
            try {
                update testData.cashReceipts[0];
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                SObjectActions.REQUIRED_FIELD_ERROR,
                dmlEx.getDmlMessage(0)
            );

            CashReceiptPostService.unpostCashReceipts(
                new List<Cash_Receipt__c>{ testData.cashReceipts[1] }
            );

            testData.cashReceipts[1].Accounting_Period__c = null;

            dmlEx = null;
            try {
                update testData.cashReceipts[1];
            } catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(
                SObjectActions.REQUIRED_FIELD_ERROR,
                dmlEx.getDmlMessage(0)
            );

            CashReceiptPostService.unpostCashReceipts(
                new List<Cash_Receipt__c>{ testData.cashReceipts[2] }
            );

            testData.cashReceipts[2].Ledger__c = null;

            dmlEx = null;
            try {
                update testData.cashReceipts[2];
            } catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(
                SObjectActions.REQUIRED_FIELD_ERROR,
                dmlEx.getDmlMessage(0)
            );
        }

    }

    @IsTest
    public static void testPreventUpdateActionError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            ApexPages.StandardController controller = new ApexPages.StandardController(
                testData.cashReceipts[0]
            );
            CashReceiptPost crp = new CashReceiptPost(controller);
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, [
                    SELECT Status__c
                    FROM Cash_Receipt__c
                    WHERE Id = :testData.cashReceipts[0].Id
                ]
                .Status__c
            );
            // Test update no error since no fields changed.
            Cash_Receipt__c cr = [
                SELECT Accounting_Period__r.Status__c, Status__c
                FROM Cash_Receipt__c
                WHERE Id = :testData.cashReceipts[0].Id
            ];
            // Test update error since attempted to change protected field.
            DMLException dmlEx;
            try {
                cr.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED;
                update cr;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            SourceDocumentUpdateFieldValidator sfu = new CashReceiptFieldUpdateValidator();
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
    public static void testPreventUpdateActionPostedNoChangeSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            ApexPages.StandardController controller = new ApexPages.StandardController(
                testData.cashReceipts[0]
            );
            CashReceiptPost crp = new CashReceiptPost(controller);
            System.assertEquals(
                'Posted',
                [
                    SELECT Status__c
                    FROM Cash_Receipt__c
                    WHERE Id = :testData.cashReceipts[0].Id
                ]
                .Status__c
            );

            DMLException dmlEx;

            // Test update no error since no fields changed.
            Cash_Receipt__c cr = [
                SELECT Accounting_Period__r.Status__c, Status__c
                FROM Cash_Receipt__c
                WHERE Id = :testData.cashReceipts[0].Id
            ];

            try {
                update cr;
            } catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(null, dmlEx);
        }
    }

    @IsTest
    public static void testPreventUpdateActionPostedNoChangeSetScaleSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Cash_Receipt__c cr = testData.cashReceipts[0].clone(false, true);
            cr.Amount__c = 100.35946436;
            insert cr;
            System.assertEquals(
                'Posted',
                [SELECT Status__c FROM Cash_Receipt__c WHERE Id = :cr.Id]
                .Status__c
            );
            cr = [
                SELECT Id, Amount__c, Status__c
                FROM Cash_Receipt__c
                WHERE Id = :cr.Id
            ];

            DMLException dmlEx;
            try {
                cr.Amount__c = 100.36;
                update cr;
            } catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(null, dmlEx);
        }

    }

    @IsTest
    public static void testPreventDeleteLineActionPosted() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(true);

        System.runAs(testData.users[1]) {
            Test.startTest();
            DMLException dmlEx;
            try {
                delete testData.journalEntryLines;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                SourceDocumentUpdateFieldValidator.POSTED_DELETE_ERROR,
                dmlEx.getDmlMessage(0)
            );
        }

    }

    @IsTest
    public static void testSetDefaultBankAccount() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            //create new Bank Account
            GL_Account__c newBankGLAccount = new GL_Account__c(
                Name = '1000-Cash-2',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Bank__c = true,
                Sub_Type_1__c = 'Assets',
                Sub_Type_2__c = 'Cash'
            );
            insert newBankGLAccount;

            testData.ledgers[2].Default_Bank_Account__c = newBankGLAccount.Id;
            update testData.ledgers[2];

            Cash_Receipt__c receipt = testData.cashReceipts[0]
                .clone(false, true);
            receipt.Ledger__c = testData.ledgers[2].Id;
            receipt.Bank_Account__c = null;
            insert receipt;

            System.assertEquals(
                newBankGLAccount.Id,
                [
                    SELECT Bank_Account__c
                    FROM Cash_Receipt__c
                    WHERE Id = :receipt.Id
                ]
                .Bank_Account__c
            );
        }

    }

    @IsTest
    public static void testPreventDeleteBillingCashReceipts() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Accounting_Period__c = testData.acctPeriods[1].Id;
            bcr.Applied_Amount__c = 10;
            bcr.Billing__c = testData.billings[0].Id;
            bcr.Cash_Receipt__c = testData.cashReceipts[0].Id;
            insert bcr;

            DMLException dmlEx;

            try {
                delete testData.cashReceipts[0];
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                CashReceiptActions.BILLING_CASH_RECEPT_ERROR,
                dmlEx.getDmlMessage(0)
            );
        }

    }

    @IsTest
    public static void testCashReceiptNoControlAccount() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            delete [SELECT Id FROM GL_Account_Default__c WHERE GL_Account_Specification__c = :GLAccountDefaultsHandler.UNAPPLIED_CASH_GL_ACCOUNT];
            GLAccountDefaultsHandler.instance = null;

            List<Cash_Receipt__c> cashReceipts = new List<Cash_Receipt__c>();
            cashReceipts.add(
                new Cash_Receipt__c(
                    Account__c = testData.accounts[0].Id,
                    Amount__c = 500,
                    Payment_Reference__c = '0000000432',
                    Status__c = 'In Process',
                    Receipt_Date__c = testData.acctPeriods[1].Start_Date__c,
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Purpose__c = 'Customer Receipt',
                    Bank_Account__c = testData.glAccounts[0].Id
                )
            );

            DmlException dmlEx;
            try {
                insert cashReceipts;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(Label.ERR_CR_NO_UNAPPLIED_CASH_GL_ACCOUNT, new List<String>{'Cash Receipt'}),
                dmlEx.getDmlMessage(0)
            );
        }

    }

    @IsTest
    public static void testCashReceiptUnpostedDeleteSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            ApexPages.StandardController cont = new ApexPages.StandardController(
                [
                    SELECT Accounting_Period__r.Status__c, Status__c
                    FROM Cash_Receipt__c
                    WHERE Id = :testData.cashReceipts[0].Id
                ]
            );
            CashReceiptPost pbt = new CashReceiptPost(cont);
            pbt.unpost();
            System.assertEquals(
                'Approved',
                [
                    SELECT Accounting_Period__r.Status__c, Status__c
                    FROM Cash_Receipt__c
                    WHERE Id = :testData.cashReceipts[0].Id
                ]
                .Status__c
            );

            testData.cashReceipts[0]
                .Accounting_Period__c = testData.acctPeriods[4].Id;
            update testData.cashReceipts[0];

            DMLException dmlEx;
            try {
                delete testData.cashReceipts[0];
            } catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(null, dmlEx);
        }

    }

    @IsTest
    public static void testCashReceiptPostedDeleteError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            ApexPages.StandardController cont = new ApexPages.StandardController(
                [
                    SELECT Accounting_Period__r.Status__c, Status__c
                    FROM Cash_Receipt__c
                    WHERE Id = :testData.cashReceipts[0].Id
                ]
            );
            CashReceiptPost pbt = new CashReceiptPost(cont);
            pbt.unpost();
            System.assertEquals(
                'Approved',
                [
                    SELECT Accounting_Period__r.Status__c, Status__c
                    FROM Cash_Receipt__c
                    WHERE Id = :testData.cashReceipts[0].Id
                ]
                .Status__c
            );

            testData.cashReceipts[0]
                .Accounting_Period__c = testData.acctPeriods[4].Id;
            update testData.cashReceipts[0];

            cont = new ApexPages.StandardController(
                [
                    SELECT Accounting_Period__r.Status__c, Status__c
                    FROM Cash_Receipt__c
                    WHERE Id = :testData.cashReceipts[0].Id
                ]
            );
            pbt = new CashReceiptPost(cont);
            pbt.post();

            System.assertEquals(
                'Posted',
                [
                    SELECT Accounting_Period__r.Status__c, Status__c
                    FROM Cash_Receipt__c
                    WHERE Id = :testData.cashReceipts[0].Id
                ]
                .Status__c
            );

            DMLException dmlEx;
            try {
                delete testData.cashReceipts[0];
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                SourceDocumentUpdateFieldValidator.POSTED_DELETE_ERROR,
                dmlEx.getDmlMessage(0)
            );
        }

    }

    @IsTest
    public static void testCashReceiptPreventUpdateBankReconciliationFieldSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankReconciliations();

        System.runAs(testData.users[1]) {
            testData.cashReceipts[0]
                .Bank_Reconciliation__c = testData.bankReconciliations[0].Id;

            DMLException dmlEx = null;
            try {
                update testData.cashReceipts[0];
            } catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(
                System.StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION,
                dmlEx.getDmlType(0)
            );
        }

    }

    @IsTest
    public static void testCashReceiptPreventUpdateBankDepositFieldSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankDeposits();

        System.runAs(testData.users[1]) {
            testData.cashReceipts[0].Bank_Deposit__c = testData.bankDeposits[0]
                .Id;

            DMLException dmlEx = null;
            try {
                update testData.cashReceipts[0];
            } catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(
                System.StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION,
                dmlEx.getDmlType(0)
            );
        }

    }

    @IsTest
    public static void testCashReceiptSetDefaultFieldsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankDeposits()
            .createBankReconciliations();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Cash_Receipt__c receipt = testData.cashReceipts[0]
                .clone(false, true);
            receipt.Bank_Account__c = null;
            receipt.Status__c = 'In Process';
            receipt.Bank_Deposit__c = testData.bankDeposits[0].Id;
            receipt.Bank_Reconciliation__c = testData.bankReconciliations[0].Id;
            receipt.Cleared_Date__c = System.today();
            receipt.Ledger__c = null;

            TriggerObserver.getInstance()
                .unlockFields(
                    new Set<SObjectField>{
                        Cash_Receipt__c.Bank_Deposit__c,
                        Cash_Receipt__c.Bank_Reconciliation__c,
                        Cash_Receipt__c.Status__c
                    }
                );
            insert receipt;

            System.assertEquals(
                'In Process',
                [SELECT Status__c FROM Cash_Receipt__c WHERE Id = :receipt.Id]
                .Status__c
            );
            System.assertEquals(
                0,
                [
                    SELECT COUNT()
                    FROM Transaction__c
                    WHERE Cash_Receipt__c = :receipt.Id
                ]
            );
            System.assertEquals(
                null,
                [
                    SELECT Bank_Deposit__c
                    FROM Cash_Receipt__c
                    WHERE Id = :receipt.Id
                ]
                .Bank_Deposit__c
            );
            System.assertEquals(
                null,
                [
                    SELECT Bank_Reconciliation__c
                    FROM Cash_Receipt__c
                    WHERE Id = :receipt.Id
                ]
                .Bank_Reconciliation__c
            );
            System.assertEquals(
                null,
                [
                    SELECT Cleared_Date__c
                    FROM Cash_Receipt__c
                    WHERE Id = :receipt.Id
                ]
                .Cleared_Date__c
            );
            System.assertEquals(
                testData.ledgerSettings.Ledger_Id__c,
                [SELECT Ledger__c FROM Cash_Receipt__c WHERE Id = :receipt.Id]
                .Ledger__c
            );
        }

    }

    @IsTest
    public static void testSetPreventUpdateStatusFieldPostedError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            PostResult result = CashReceiptPostService.unpostCashReceipts(
                new List<Cash_Receipt__c>{ testData.cashReceipts[0] }
            )[0];
            System.assertEquals(true, result.isSuccess);

            DMLException dmlEx = null;
            try {
                testData.cashReceipts[0].Status__c = 'Posted';
                update testData.cashReceipts[0];
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                SourceDocumentUpdateFieldValidator.UPDATE_STATUS_ERROR,
                dmlEx.getDMLMessage(0)
            );
        }

    }

    @IsTest
    public static void testPreventUpdateCustomerAppliedBCRError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Billing_Cash_Receipt__c testBillingCashReceipt = new Billing_Cash_Receipt__c(
                Billing__c = testData.billings[0].Id,
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Cash_Receipt__c = testData.cashReceipts[0].Id,
                Applied_Amount__c = 200
            );

            insert testBillingCashReceipt;

            testData.cashReceipts[0].Account__c = testData.accounts[1].Id;
            DmlException dmlEx;
            try {
                update testData.cashReceipts[0];
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                SObjectActions.APPLIED_ITEMS_ERROR_MAP.get(
                    Cash_Receipt__c.getSObjectType()
                ),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void testPreventUpdatePeriodAppliedBCRError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Billing_Cash_Receipt__c testBillingCashReceipt = new Billing_Cash_Receipt__c(
                Billing__c = testData.billings[0].Id,
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Cash_Receipt__c = testData.cashReceipts[0].Id,
                Applied_Amount__c = 200
            );

            insert testBillingCashReceipt;

            testData.cashReceipts[0]
                .Accounting_Period__c = testData.acctPeriods[3].Id;
            DmlException dmlEx;
            try {
                update testData.cashReceipts[0];
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                SObjectActions.APPLIED_ACC_PERIOD_ERROR_MAP.get(
                    Cash_Receipt__c.getSObjectType()
                ),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    public static testMethod void testSetDefaultGLAVFromRelatedAccount() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankDeposits()
            .createBankReconciliations()
            .createAccountingVariables();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.accounts[0]
                .GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            testData.accounts[0]
                .GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            testData.accounts[0]
                .GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            testData.accounts[0]
                .GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update testData.accounts[0];

            Cash_Receipt__c receipt = testData.cashReceipts[0]
                .clone(false, true);
            receipt.Bank_Account__c = null;
            receipt.Status__c = 'In Process';
            receipt.Bank_Deposit__c = testData.bankDeposits[0].Id;
            receipt.Bank_Reconciliation__c = testData.bankReconciliations[0].Id;
            receipt.Cleared_Date__c = System.today();
            insert receipt;

            System.assertEquals(
                testData.accounts[0].GL_Account_Variable_1__c,
                [
                    SELECT GL_Account_Variable_1__c
                    FROM Cash_Receipt__c
                    WHERE Id = :receipt.Id
                ]
                .GL_Account_Variable_1__c
            );

            System.assertEquals(
                testData.accounts[0].GL_Account_Variable_2__c,
                [
                    SELECT GL_Account_Variable_2__c
                    FROM Cash_Receipt__c
                    WHERE Id = :receipt.Id
                ]
                .GL_Account_Variable_2__c
            );

            System.assertEquals(
                testData.accounts[0].GL_Account_Variable_3__c,
                [
                    SELECT GL_Account_Variable_3__c
                    FROM Cash_Receipt__c
                    WHERE Id = :receipt.Id
                ]
                .GL_Account_Variable_3__c
            );

            System.assertEquals(
                testData.accounts[0].GL_Account_Variable_4__c,
                [
                    SELECT GL_Account_Variable_4__c
                    FROM Cash_Receipt__c
                    WHERE Id = :receipt.Id
                ]
                .GL_Account_Variable_4__c
            );
        }

    }

    @IsTest
    public static void testPreventUpdateCurrencyIfPosted_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createCashReceipts();

            System.runAs(testData.users[1]) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }
                Cash_Receipt__c testCR = testData.cashReceipts[0];
                Cash_Receipt__c postedCR = [
                    SELECT Id
                    FROM Cash_Receipt__c
                    WHERE Id = :testCR.Id
                    LIMIT 1
                ];
                postedCR.put('CurrencyIsoCode', newCurrencyIsoCode);
                DmlException dmlEx;
                try {
                    update postedCR;
                } catch (DmlException ex) {
                    dmlEx = ex;
                }

                System.assertNotEquals(null, dmlEx);
            }
        } catch (Exception ex) {
        }
    }

    @IsTest
    public static void testCashReceiptNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Cash_Receipt__c cr = new Cash_Receipt__c();
            DMLException dmlEx;
            try {
                insert cr;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assert(
                !dmlEx.getDmlMessage(0).contains('System.NullPointerException')
            );
        }
    }

    @IsTest
    public static void testNormalizeNumericAndCurrencyFieldsInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Cash_Receipt__c cashReceipt = new Cash_Receipt__c(
                Account__c = testData.accounts[0].Id,
                Payment_Reference__c = '0000000432',
                Status__c = 'In Process',
                Receipt_Date__c = testData.acctPeriods[1].Start_Date__c,
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = testData.glAccounts[0].Id,
                Amount__c = 20.989342348934,
                Currency_Conversion_Rate__c = 10.236746723674344
            );

            insert cashReceipt;

            Cash_Receipt__c newCashReceipt = [
                SELECT Id, Amount__c, Currency_Conversion_Rate__c
                FROM Cash_Receipt__c
                WHERE Id = :cashReceipt.Id
            ];

            System.assertEquals(20.99, newCashReceipt.Amount__c);
            System.assertEquals(
                10.236747,
                newCashReceipt.Currency_Conversion_Rate__c
            );
        }

    }

    @IsTest
    public static void testNormalizeNumericAndCurrencyFieldsUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            testData.cashReceipts[0].Amount__c = 20.989342348934;
            testData.cashReceipts[0]
                .Currency_Conversion_Rate__c = 10.236746723674344;

            TriggerObserver.getInstance()
                .unlockFields(
                    new Set<SObjectField>{
                        Cash_Receipt__c.Amount__c,
                        Cash_Receipt__c.Currency_Conversion_Rate__c,
                        Cash_Receipt__c.Status__c
                    }
                );
            update testData.cashReceipts[0];

            Cash_Receipt__c newCashReceipt = [
                SELECT Id, Amount__c, Currency_Conversion_Rate__c
                FROM Cash_Receipt__c
                WHERE Id = :testData.cashReceipts[0].Id
            ];

            System.assertEquals(20.99, newCashReceipt.Amount__c);
            System.assertEquals(
                10.236747,
                newCashReceipt.Currency_Conversion_Rate__c
            );
        }
    }

    @IsTest
    public static void testAllowOverAppliedCRByBCRPositive() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Cash_Receipt__c testCR = testData.cashReceipts[0].clone();
            testCR.Amount__c = 5;

            insert testCR;

            Billing_Cash_Receipt__c testBCR = new Billing_Cash_Receipt__c(
                Cash_Receipt__c = testCR.Id,
                Billing__c = testData.billings[0].Id,
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Applied_Amount__c = 50
            );
            insert testBCR;
            System.assertEquals(
                [
                    SELECT Received_Amount__c
                    FROM Billing__c
                    WHERE Id = :testData.billings[0].Id
                ]
                .Received_Amount__c,
                testBCR.Applied_Amount__c
            );
            Test.stopTest();
        }
    }

    @IsTest
    public static void testAllowOverAppliedCRByBCRNegative() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Cash_Receipt__c testCR = testData.cashReceipts[0].clone();
            testCR.Amount__c = 5;

            insert testCR;

            Billing_Cash_Receipt__c testBCR = new Billing_Cash_Receipt__c(
                Cash_Receipt__c = testCR.Id,
                Billing__c = testData.billings[0].Id,
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Applied_Amount__c = -50
            );
            insert testBCR;
            System.assertEquals(
                [
                    SELECT Received_Amount__c
                    FROM Billing__c
                    WHERE Id = :testData.billings[0].Id
                ]
                .Received_Amount__c,
                testBCR.Applied_Amount__c
            );
            Test.stopTest();
        }
    }
    @IsTest
    public static void testPostOnInsertSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [
                    SELECT Status__c
                    FROM Cash_Receipt__c
                    WHERE Id = :testData.cashReceipts[0].Id
                ]
                .Status__c
            );
        }
    }

    @IsTest
    public static void testPostOnInsertFailure() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            DmlException dmlEx;
            try {
                AccountingPeriodActions.isFirstRun = false;
                testData.acctPeriods[0]
                    .Status__c = AccountingPeriodActions.CLOSED_STATUS;
                update testData.acctPeriods[0];

                testData.createCashReceipts();
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(null, dmlEx);

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [
                    SELECT Status__c
                    FROM Cash_Receipt__c
                    WHERE Id = :testData.cashReceipts[0].Id
                ]
                .Status__c
            );
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                [
                    SELECT Status__c
                    FROM Cash_Receipt__c
                    WHERE Id = :testData.cashReceipts[2].Id
                ]
                .Status__c
            );
            List<Task> activities = [
                SELECT Id
                FROM Task
                WHERE WhatId = :testData.cashReceipts[2].Id
            ];
            System.assertNotEquals(true, activities.isEmpty());
        }
    }

    @IsTest
    public static void testSetCurrencyIsoCodeIfNullInsert_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency() //will throw an exception in case of non-MC org
                .createCashReceipts();

            System.runAs(testData.users[1]) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Cash_Receipt__c cr = testData.cashReceipts[0]
                    .clone(false, true);
                cr.put('CurrencyIsoCode', null);

                insert cr;
                Id crId = cr.Id;

                cr = Database.query(
                    'SELECT Id, CurrencyIsoCode FROM Cash_Receipt__c WHERE Id = :crId'
                );
                System.assertNotEquals(null, cr);
                System.assertNotEquals(null, cr.get('CurrencyIsoCode'));
                System.assertEquals(
                    UserInfo.getDefaultCurrency(),
                    cr.get('CurrencyIsoCode')
                );
            }
        } catch (Exception ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testSetCurrencyIsoCodeIfNullUpdate_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency() //will throw an exception in case of non-MC org
                .createCashReceipts();

            System.runAs(testData.users[1]) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Cash_Receipt__c cr = testData.cashReceipts[0]
                    .clone(false, true);

                insert cr;
                Id crId = cr.Id;
                CashReceiptPostService.unpostCashReceipts(
                    new List<Cash_Receipt__c>{ cr }
                );

                cr.put('CurrencyIsoCode', null);
                update cr;

                cr = Database.query(
                    'SELECT Id, CurrencyIsoCode FROM Cash_Receipt__c WHERE Id = :crId'
                );
                System.assertNotEquals(null, cr);
                System.assertNotEquals(null, cr.get('CurrencyIsoCode'));
                System.assertEquals(
                    UserInfo.getDefaultCurrency(),
                    cr.get('CurrencyIsoCode')
                );
            }
        } catch (Exception ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    private static void testAmountToWords() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Integer Year = Date.today().Year();      
                  
            Accounting_Period__c acctPeriod = new Accounting_Period__c(
                Name = Year + '-01',
                Start_Date__c = Date.newInstance(Year, 1, 1),
                End_Date__c = Date.newInstance(Year, 12, 31),
                Status__c = AccountingPeriodActions.OPEN_STATUS
            );
            insert acctPeriod;        

            Cash_Receipt__c cr = testData.cashReceipts[0].clone(false, true);
            cr.Account__c = testData.accounts[0].Id;
            cr.Receipt_Date__c = acctPeriod.Start_Date__c;
            cr.Amount__c = 24.98;
            cr.Payment_Type__c = 'Check';
            insert cr;

            Cash_Receipt__c newCR = [
                SELECT Amount_In_Words__c
                FROM Cash_Receipt__c
                WHERE Id = :cr.Id LIMIT 1
            ];

            System.assert(String.isNotBlank(newCR.Amount_In_Words__c));    

            cr.Amount__c = 25.01;
            update cr;

            Cash_Receipt__c updatedCR = [
                SELECT Amount_In_Words__c
                FROM Cash_Receipt__c
                WHERE Id = :cr.Id LIMIT 1
            ];
            
            System.assert(String.isNotBlank(updatedCR.Amount_In_Words__c));
            System.assertNotEquals(newCR.Amount_In_Words__c, updatedCR.Amount_In_Words__c);      
        }
    }

    @IsTest
    private static void testSetCheckNumber() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Integer Year = Date.today().Year();      
                  
            Accounting_Period__c acctPeriod = new Accounting_Period__c(
                Name = Year + '-01',
                Start_Date__c = Date.newInstance(Year, 1, 1),
                End_Date__c = Date.newInstance(Year, 12, 31),
                Status__c = AccountingPeriodActions.OPEN_STATUS
            );
            insert acctPeriod;        

            List<Cash_Receipt__c> crs = new List<Cash_Receipt__c>();
            
            // check number expected
            Cash_Receipt__c cr1 = testData.cashReceipts[0].clone(false, true);
            cr1.Account__c = testData.accounts[0].Id;
            cr1.Receipt_Date__c = acctPeriod.Start_Date__c;
            cr1.Amount__c = -24.98;
            cr1.Payment_Type__c = 'Check';
            crs.add(cr1);

            // check number not expected
            Cash_Receipt__c cr2 = testData.cashReceipts[0].clone(false, true);
            cr2.Account__c = testData.accounts[0].Id;
            cr2.Receipt_Date__c = acctPeriod.Start_Date__c;
            cr2.Amount__c = -24.98;
            cr2.Payment_Type__c = 'Electronic';
            crs.add(cr2);

            // check number not expected
            Cash_Receipt__c cr3 = testData.cashReceipts[0].clone(false, true);
            cr3.Account__c = testData.accounts[0].Id;
            cr3.Receipt_Date__c = acctPeriod.Start_Date__c;
            cr3.Amount__c = 24.98;
            cr3.Payment_Type__c = 'Check';
            crs.add(cr3);

            // check number not expected
            Cash_Receipt__c cr4 = testData.cashReceipts[0].clone(false, true);
            cr4.Account__c = testData.accounts[0].Id;
            cr4.Receipt_Date__c = acctPeriod.Start_Date__c;
            cr4.Amount__c = -24.98;
            cr4.Payment_Type__c = null;
            crs.add(cr4);

            insert crs;

            List<Cash_Receipt__c> results = [
                SELECT Id
                FROM Cash_Receipt__c
                WHERE Check_Number__c <> null
            ];

            System.assertEquals(1, results.size());
            System.assertEquals(cr1.Id, results[0].Id);
        }
    }

    @IsTest
    private static void testRequireAndValidateFieldsCheckNumErr() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Integer Year = Date.today().Year();      
                  
            Accounting_Period__c acctPeriod = new Accounting_Period__c(
                Name = Year + '-01',
                Start_Date__c = Date.newInstance(Year, 1, 1),
                End_Date__c = Date.newInstance(Year, 12, 31),
                Status__c = AccountingPeriodActions.OPEN_STATUS
            );
            insert acctPeriod;
            
            Cash_Receipt__c cr = testData.cashReceipts[0].clone(false, true);
            cr.Account__c = testData.accounts[0].Id;
            cr.Receipt_Date__c = acctPeriod.Start_Date__c;
            cr.Amount__c = 24.98;
            cr.Check_Number__c = 123;

            Exception expectedEx;
            try {
                insert cr;
            } 
            catch(DmlException ex) {
                expectedEx = ex;
            }
            
            System.assertNotEquals(null, expectedEx);
            System.assertEquals(1, expectedEx.getNumDml());
            System.assertEquals(Label.ERR_CR_CHECK_NUMBER_POS_AMOUNT, expectedEx.getDmlMessage(0));
        }
    }
    @IsTest
    private static void testUpdateStatusFromAnythingtoApproved() {
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

            testCR1.Status__c = 'In Process';
            UPDATE testCR1;

            System.assertEquals(
                0, [
                    SELECT count()
                    FROM Cash_Receipt__c
                    WHERE Status__c = 'Posted'
                    AND Id = :testCR1.Id
                ]
            );

            testCR1.Status__c = 'Approved';
            UPDATE testCR1;

            System.assertEquals(
                1, [
                SELECT count()
                FROM Cash_Receipt__c
                WHERE Status__c = 'Posted'
                AND Id = :testCR1.Id
            ]);
        }
    }

    @IsTest
    private static void testSetDefaultFieldsStatus() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();

            String defaultStatus = FinancialSuiteUtils.getDefaultPostingStatus(Cash_Receipt__c.Status__c);

            // test In Process
            Cash_Receipt__c cr = new Cash_Receipt__c(
                Status__c = 'In Process'
            );
            CashReceiptActions.setDefaultFields(new List<Cash_Receipt__c>{cr});
            Assert.areEqual('In Process', cr.Status__c);

            // test Approved
            cr.Status__c = 'Approved';
            CashReceiptActions.setDefaultFields(new List<Cash_Receipt__c>{cr});
            Assert.areEqual('Approved', cr.Status__c);

            // test Posted
            cr.Status__c = 'Posted';
            CashReceiptActions.setDefaultFields(new List<Cash_Receipt__c>{cr});
            Assert.areEqual(defaultStatus, cr.Status__c);

            // test blank
            cr.Status__c = '';
            CashReceiptActions.setDefaultFields(new List<Cash_Receipt__c>{cr});
            Assert.areEqual(defaultStatus, cr.Status__c);

            // test null
            cr.Status__c = null;
            CashReceiptActions.setDefaultFields(new List<Cash_Receipt__c>{cr});
            Assert.areEqual(defaultStatus, cr.Status__c);

            // test other
            cr.Status__c = 'Other';
            CashReceiptActions.setDefaultFields(new List<Cash_Receipt__c>{cr});
            Assert.areEqual('Other', cr.Status__c);
            Test.stopTest();
        }

    }
}