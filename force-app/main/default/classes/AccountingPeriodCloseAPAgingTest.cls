@IsTest
private class AccountingPeriodCloseAPAgingTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testAccountingPeriodCloseAPAgingWhenMCEnabled_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency() //will throw an exception in case of non-MC org
                .createPayables(false)
                .createCashDisbursementBatches()
                .createCashDisbursements();

            System.runAs(testData.users.get(1)) {
                Test.startTest();

                AccountingSettingsHandler.getAccountingSettings();

                String newCurrency = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrency)) {
                    return;
                }

                Map<Id, Account_Payable__c> testAccountPayablesMap = new Map<Id, Account_Payable__c>();

                Account_Payable__c testAccountPayable1 = testData.payables.get(0); //Invoice
                testAccountPayable1.Status__c = 'Approved';
                testAccountPayable1.Discount_Amount__c = 0;
                testAccountPayable1.put('CurrencyIsoCode', newCurrency);
                testAccountPayablesMap.put(testAccountPayable1.Id, testAccountPayable1);

                Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);

                Account_Payable__c testAccountPayable5 = testData.payables.get(4); //Credit Memo
                testAccountPayable5.Status__c = 'Approved';
                testAccountPayable5.Accounting_Period__c = testAccountingPeriod.Id;
                testAccountPayable5.put('CurrencyIsoCode', newCurrency);
                testAccountPayablesMap.put(testAccountPayable5.Id, testAccountPayable5);

                TriggerObserver.getInstance().unlockFields(
                    new Set<SObjectField>{Schema.SObjectType.Account_Payable__c.fields.getMap().get('CurrencyIsoCode')}
                );
                update testAccountPayablesMap.values();

                testAccountPayable1.Currency_Conversion_Rate__c = 1.2;
                testAccountPayable5.Currency_Conversion_Rate__c = 1.2;

                update new List<Account_Payable__c> {testAccountPayable1, testAccountPayable5};

                for (PostResult result : AccountPayablePostService.postAccountPayables(testAccountPayablesMap.values())) {
                    System.assertEquals(true, result.isSuccess);
                }
                //Cash Disbursement Batch and all related Cash Disbursements must have the same currency
                Cash_Disbursement_Batch__c testCashDisbursementBatch = testData.cashDisbursementBatch.get(0);
                testCashDisbursementBatch.put('CurrencyIsoCode', newCurrency);
                CashDisbursementBatchActions.isPreventUpdateOverride = true;
                update testCashDisbursementBatch;

                Cash_Disbursement__c testCashDisbursement = testData.cashDisbursements.get(0);
                testCashDisbursement.Amount__c = 200;
                testCashDisbursement.Status__c = 'In Process';
                testCashDisbursement.put('CurrencyIsoCode', newCurrency);
                update testCashDisbursement;

                AP_Credit_Memo__c acm = new AP_Credit_Memo__c(
                    Account_Payable_Invoice__c = testAccountPayable1.Id,
                    Account_Payable_Credit_Memo__c = testAccountPayable5.Id,
                    Amount__c = -5,
                    Accounting_Period__c = testAccountingPeriod.Id
                );
                insert acm;

                AP_Disbursement__c apDisbursement = new AP_Disbursement__c(
                    Account_Payable__c = testAccountPayable1.Id,
                    Cash_Disbursement__c = testCashDisbursement.Id,
                    Paid_Amount__c = 135.25
                );
                apDisbursement.put('CurrencyIsoCode', newCurrency);
                insert apDisbursement;

                testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
                update testAccountingPeriod;

                Test.stopTest();

                Map<Id, Account_Payable__c> validatedTestAccountPayablesMap = new Map<Id, Account_Payable__c>([
                    SELECT Id, Closed_Accounting_Period__c, Ledger_Amount__c FROM Account_Payable__c WHERE Id IN :testAccountPayablesMap.keySet()
                ]);

                List<AP_Aging_History__c> validatedTestAgingHistories = [
                    SELECT Id, Amount__c, Account_Payable__c FROM AP_Aging_History__c WHERE Account_Payable__c IN :testAccountPayablesMap.keySet()
                ];

                Map<Id, AP_Aging_History__c> validatedTestAgingHistoriesMap = new Map<Id, AP_Aging_History__c>();

                for (AP_Aging_History__c validatedTestAgingHistory : validatedTestAgingHistories) {
                    validatedTestAgingHistoriesMap.put(validatedTestAgingHistory.Account_Payable__c, validatedTestAgingHistory);
                }

                System.assertEquals(
                    testAccountingPeriod.Id,
                    validatedTestAccountPayablesMap.get(testAccountPayable1.Id).Closed_Accounting_Period__c
                );

                System.assertEquals(
                    validatedTestAccountPayablesMap.get(testAccountPayable1.Id).Ledger_Amount__c - ((135.25 + 5) / 1.2).setScale(2, System.RoundingMode.HALF_UP),
                    validatedTestAgingHistoriesMap.get(testAccountPayable1.Id).Amount__c.setScale(0, System.RoundingMode.HALF_UP)
                );

                System.assertEquals(
                    validatedTestAccountPayablesMap.get(testAccountPayable5.Id).Ledger_Amount__c + (5 / 1.2).setScale(2, System.RoundingMode.HALF_UP),
                    validatedTestAgingHistoriesMap.get(testAccountPayable5.Id).Amount__c
                );
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    private static void testAccountingPeriodCloseAPAgingNoAccountingSettingsError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            delete testData.settings;
            AccountingSettingsHandler.getAccountingSettings();

            System.assertEquals(
                0,
                [SELECT COUNT() FROM Accounting_Settings__c]
            );

            AccountingPeriodOpenCloseOptions periodDataContainer =
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testData.acctPeriods.get(0)},
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.CLOSING
                );
            AccountingPeriodCloseAPAging apc = new AccountingPeriodCloseAPAging(periodDataContainer);

            System.assertEquals(
                false,
                apc.main.Enable_AP_Period_Sensitive_Aging__c
            );
        }

    }

    @IsTest
    private static void testAccountingPeriodCloseAPAgingFinalStatusSet() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);

            System.assertEquals(
                AccountingPeriodActions.OPEN_STATUS,
                [SELECT Id, Status__c FROM Accounting_Period__c WHERE Id = :testAccountingPeriod.Id].Status__c
            );

            AccountingPeriodOpenCloseOptions periodDataContainer =
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testAccountingPeriod},
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.CLOSING
                );

            AccountingPeriodCloseAPAging apc = new AccountingPeriodCloseAPAging(periodDataContainer);
            Database.executeBatch(apc);
            Test.stopTest();

            System.assertEquals(
                AccountingPeriodActions.CLOSED_STATUS,
                [SELECT Id, Status__c FROM Accounting_Period__c WHERE Id = :testAccountingPeriod.Id].Status__c
            );
        }

    }

    @IsTest
    private static void testAccountingPeriodCloseAPAgingNonZeroBalanceSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables()
                .createCashDisbursementBatches()
                .createCashDisbursements()
                .createAPAgingHistories();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Map<Id, Account_Payable__c> testAccountPayablesMap = new Map<Id, Account_Payable__c>();

            Account_Payable__c testAccountPayable1 = testData.payables.get(0);
            testAccountPayable1.Status__c = 'Approved';
            testAccountPayable1.Discount_Amount__c = 0;
            testAccountPayablesMap.put(testAccountPayable1.Id, testAccountPayable1);

            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);

            Account_Payable__c testAccountPayable5 = testData.payables.get(4);
            testAccountPayable5.Accounting_Period__c = testAccountingPeriod.Id;
            testAccountPayable5.Status__c = 'Approved';
            testAccountPayablesMap.put(testAccountPayable5.Id, testAccountPayable5);

            update testAccountPayablesMap.values();

            for (PostResult result : AccountPayablePostService.postAccountPayables(testAccountPayablesMap.values())) {
                System.assertEquals(
                    true,
                    result.isSuccess
                );
            }

            Cash_Disbursement__c testCashDisbursement = testData.cashDisbursements.get(0);
            testCashDisbursement.Status__c = 'In Process';
            update testCashDisbursement;

            ApexPages.StandardController controller = new ApexPages.StandardController(testCashDisbursement);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();
            cdp.post();

            AP_Credit_Memo__c acm = new AP_Credit_Memo__c(
                Account_Payable_Invoice__c = testAccountPayable1.Id,
                Account_Payable_Credit_Memo__c = testAccountPayable5.Id,
                Amount__c = -5,
                Accounting_Period__c = testAccountingPeriod.Id
            );
            insert acm;

            delete testData.apAgingHistories;
            testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testAccountingPeriod;
            Test.stopTest();

            Map<Id, Account_Payable__c> validatedTestAccountPayablesMap = new Map<Id, Account_Payable__c>([
                SELECT Id, Closed_Accounting_Period__c, Balance__c FROM Account_Payable__c WHERE Id IN :testAccountPayablesMap.keySet()
            ]);

            List<AP_Aging_History__c> validatedTestAgingHistories = [
                SELECT Id, Amount__c, Account_Payable__c FROM AP_Aging_History__c WHERE Account_Payable__c IN :testAccountPayablesMap.keySet()
            ];

            Map<Id, AP_Aging_History__c> validatedTestAgingHistoriesMap = new Map<Id, AP_Aging_History__c>();

            for (AP_Aging_History__c validatedTestAgingHistory : validatedTestAgingHistories) {
                validatedTestAgingHistoriesMap.put(validatedTestAgingHistory.Account_Payable__c, validatedTestAgingHistory);
            }

            System.assertEquals(
                null,
                validatedTestAccountPayablesMap.get(testAccountPayable1.Id).Closed_Accounting_Period__c
            );

            System.assertEquals(
                validatedTestAccountPayablesMap.get(testAccountPayable1.Id).Balance__c,
                validatedTestAgingHistoriesMap.get(testAccountPayable1.Id).Amount__c
            );

            System.assertEquals(
                validatedTestAccountPayablesMap.get(testAccountPayable5.Id).Balance__c,
                validatedTestAgingHistoriesMap.get(testAccountPayable5.Id).Amount__c
            );
        }

    }

    @IsTest
    private static void testAccountingPeriodCloseAPAgingZeroBalanceSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables()
                .createCashDisbursementBatches()
                //.createCashDisbursements();
                ;

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Map<Id, Account_Payable__c> testAccountPayablesMap = new Map<Id, Account_Payable__c>();
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);

            Account_Payable__c testInvoice = testData.payables.get(0);
            testInvoice.Accounting_Period__c = testAccountingPeriod.Id;
            testInvoice.Status__c = 'Approved';
            testInvoice.Discount_Amount__c = 0;
            testAccountPayablesMap.put(testInvoice.Id, testInvoice);

            Account_Payable__c testCreditMemo = testData.payables.get(4);
            testCreditMemo.Accounting_Period__c = testAccountingPeriod.Id;
            testCreditMemo.Status__c = 'Approved';
            testAccountPayablesMap.put(testCreditMemo.Id, testCreditMemo);

            update testAccountPayablesMap.values();

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> postResults = postHandler.post(new List<Account_Payable__c>{testInvoice});
            System.assertEquals(true, postResults[0].isSuccess);

            testInvoice = [
                SELECT Id, Status__c, Net_Amount__c, Paid_Amount__c, Credit_Memo_Applied_Amount__c
                FROM Account_Payable__c
                WHERE Id = :testInvoice.Id LIMIT 1
            ];
            
            Double cashAmount = testInvoice.Net_Amount__c - 20;
            Cash_Disbursement__c testCD = new Cash_Disbursement__c(
                Cash_Disbursement_Batch__c = testData.cashDisbursementBatch.get(0).Id,
                Disbursement_Date__c = testAccountingPeriod.Start_Date__c,
                Type__c = 'Check',
                Amount__c = cashAmount,
                Source__c = 'Account Payable',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Debit_GL_Account__c = testData.glAccounts.get(16).Id,
                Vendor__c = testData.accounts.get(0).Id,
                Accounting_Period__c = testAccountingPeriod.Id,
                Status__c = 'Approved',
                Reference__c = 'the reference XXL'
            );
            insert testCD;

            AP_Disbursement__c newAPD = new AP_Disbursement__c(
                Account_Payable__c = testInvoice.Id,
                Cash_Disbursement__c = testCD.Id,
                Paid_Amount__c = cashAmount
            );
            insert newAPD;

            System.assertEquals(
                20.00,
                [SELECT Balance__c FROM Account_Payable__c WHERE Id = :testInvoice.Id LIMIT 1].Balance__c
            );

            AbstractPostHandler cdPostHandler = new CashDisbursementPostHandler();
            List<PostResult> cdPostResults = cdPostHandler.post(new List<Cash_Disbursement__c>{testCD});

            System.assertEquals(
                true,
                cdPostResults.get(0).isSuccess
            );

            AP_Credit_Memo__c acm = new AP_Credit_Memo__c(
                Account_Payable_Invoice__c = testInvoice.Id,
                Account_Payable_Credit_Memo__c = testCreditMemo.Id,
                Amount__c = -20,
                Accounting_Period__c = testAccountingPeriod.Id
            );
            insert acm;

            testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testAccountingPeriod;

            Test.stopTest();

            Map<Id, Account_Payable__c> validatedTestAccountPayablesMap = new Map<Id, Account_Payable__c>([
                SELECT Id, Closed_Accounting_Period__c, Balance__c FROM Account_Payable__c WHERE Id IN :testAccountPayablesMap.keySet()
            ]);

            List<AP_Aging_History__c> validatedTestAgingHistories = [
                SELECT Id, Amount__c, Account_Payable__c FROM AP_Aging_History__c WHERE Account_Payable__c IN :testAccountPayablesMap.keySet()
            ];

            Map<Id, AP_Aging_History__c> validatedTestAgingHistoriesMap = new Map<Id, AP_Aging_History__c>();

            for (AP_Aging_History__c validatedTestAgingHistory : validatedTestAgingHistories) {
                validatedTestAgingHistoriesMap.put(validatedTestAgingHistory.Account_Payable__c, validatedTestAgingHistory);
            }

            System.assertEquals(
                testAccountingPeriod.Id,
                validatedTestAccountPayablesMap.get(testInvoice.Id).Closed_Accounting_Period__c
            );

            System.assertEquals(
                validatedTestAccountPayablesMap.get(testInvoice.Id).Balance__c,
                validatedTestAgingHistoriesMap.get(testInvoice.Id).Amount__c
            );

            System.assertEquals(
                validatedTestAccountPayablesMap.get(testInvoice.Id).Balance__c,
                validatedTestAgingHistoriesMap.get(testInvoice.Id).Amount__c
            );
        }
    }

    @IsTest
    private static void testAccountingPeriodCloseAPAgingDiscountAppliedSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables()
                .createCashDisbursementBatches()
                .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Map<Id, Account_Payable__c> testAccountPayablesMap = new Map<Id, Account_Payable__c>();
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
            Accounting_Period__c nextAccountingPeriod = testData.acctPeriods.get(1);

            Account_Payable__c testInvoice = testData.payables.get(0);
            testInvoice.Accounting_Period__c = testAccountingPeriod.Id;
            testInvoice.Status__c = 'Approved';
            testAccountPayablesMap.put(testInvoice.Id, testInvoice);

            update testAccountPayablesMap.values();
            
            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> postResults = postHandler.post(new List<Account_Payable__c>{testInvoice});
            System.assertEquals(true, postResults[0].isSuccess);

            testInvoice = [
                SELECT Id, Status__c, Net_Amount__c
                FROM Account_Payable__c
                WHERE Id = :testInvoice.Id LIMIT 1
            ];

            Cash_Disbursement__c testCD = new Cash_Disbursement__c(
                Cash_Disbursement_Batch__c = testData.cashDisbursementBatch.get(0).Id,
                Disbursement_Date__c = testAccountingPeriod.Start_Date__c,
                Type__c = 'Check',
                Amount__c = testInvoice.Net_Amount__c,
                Source__c = 'Account Payable',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Debit_GL_Account__c = testData.glAccounts.get(16).Id,
                Vendor__c = testData.accounts.get(0).Id,
                Accounting_Period__c = nextAccountingPeriod.Id,
                Status__c = 'Approved',
                Reference__c = 'the reference XXL'
            );
            insert testCD;

            AP_Disbursement__c newAPD = new AP_Disbursement__c(
                Account_Payable__c = testInvoice.Id,
                Cash_Disbursement__c = testCD.Id,
                Paid_Amount__c = testInvoice.Net_Amount__c
            );
            insert newAPD;

            System.assertEquals(
                0,
                [SELECT Balance__c FROM Account_Payable__c WHERE Id = :testInvoice.Id LIMIT 1].Balance__c
            );

            AbstractPostHandler cdPostHandler = new CashDisbursementPostHandler();
            List<PostResult> cdPostResults = cdPostHandler.post(new List<Cash_Disbursement__c>{testCD});

            System.assertEquals(
                true,
                cdPostResults.get(0).isSuccess
            );

            List<Accounting_Period__c> periods = new List<Accounting_Period__c>();
            testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            periods.add(testAccountingPeriod);

            nextAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            periods.add(nextAccountingPeriod);
            
            update periods;

            Test.stopTest();

            Map<Id, Account_Payable__c> validatedTestAccountPayablesMap = new Map<Id, Account_Payable__c>([
                SELECT Id, Closed_Accounting_Period__c, Balance__c, Total__c FROM Account_Payable__c WHERE Id IN :testAccountPayablesMap.keySet()
            ]);

            
            Map<Id, AP_Aging_History__c> validatedTestAgingHistoriesMap = new Map<Id, AP_Aging_History__c>();
            for (AP_Aging_History__c aph : [
                                            SELECT Accounting_Period__c, Amount__c, Account_Payable__c 
                                            FROM AP_Aging_History__c 
                                            WHERE Account_Payable__c IN :testAccountPayablesMap.keySet()
                                           ]) {
                validatedTestAgingHistoriesMap.put(aph.Accounting_Period__c, aph);
            }
            
            System.assertEquals(
                nextAccountingPeriod.Id,
                validatedTestAccountPayablesMap.get(testInvoice.Id).Closed_Accounting_Period__c
            );
            
            System.assertEquals(
                validatedTestAccountPayablesMap.get(testInvoice.Id).Total__c,
                validatedTestAgingHistoriesMap.get(testAccountingPeriod.Id).Amount__c
            );

            System.assertEquals(
                validatedTestAccountPayablesMap.get(testInvoice.Id).Balance__c,
                validatedTestAgingHistoriesMap.get(nextAccountingPeriod.Id).Amount__c
            );
        }
    }

    @IsTest
    private static void testAccountingPeriodCloseAPAgingReverseChargeSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.setAvaVATSelected();
        Test.startTest();
        testData.createPayables(false);

        System.runAs(testData.users.get(1)) {
            Id apId = testData.payables.get(0).Id;
            Map<Id, Account_Payable_Line__c> testAccountPayableLinesMap = new Map<Id, Account_Payable_Line__c>();
            for (Account_Payable_Line__c apl : [SELECT Id FROM Account_Payable_Line__c WHERE Account_Payable__c = :apId]) {
                apl.Tax_Group__c = testData.taxGroups[3].Id;
                apl.Unit_Cost__c = 100;
                testAccountPayableLinesMap.put(apl.Id, apl);
            }
            update testAccountPayableLinesMap.values();

            for (PostResult result : AccountPayablePostService.postAccountPayables(testData.payables)) {
                System.assertEquals(true, result.isSuccess, 'Records posted successfully');
            }

            testData.acctPeriods.get(0).Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods.get(0);
            Test.stopTest();
            
            Account_Payable__c ap = [SELECT Id, Sub_Total__c, Purchase_Tax3__c FROM Account_Payable__c WHERE Id = :apId];
            System.assertNotEquals(
                0,
                ap.Purchase_Tax3__c,
                'Verify non 0 purchase or VAT input tax is included on payable'
            );
            System.assertEquals(
                ap.Sub_Total__c,
                [SELECT Id, Amount__c FROM AP_Aging_History__c WHERE Account_Payable__c = :apId].Amount__c,
                'In reverse charge scenario VAT input tax is not included in AP aging record amount'
            );
        }
    }

    @IsTest
    private static void testAccountingPeriodCloseAPAgingVoidCDFuture() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Map<Id, Account_Payable__c> testAccountPayablesMap = new Map<Id, Account_Payable__c>();
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
            Accounting_Period__c nextAccountingPeriod = testData.acctPeriods.get(1);

            Account_Payable__c testInvoice = testData.payables.get(1);
            testInvoice.Accounting_Period__c = testAccountingPeriod.Id;
            testInvoice.Status__c = 'Approved';
            testAccountPayablesMap.put(testInvoice.Id, testInvoice);

            update testAccountPayablesMap.values();

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> postResults = postHandler.post(new List<Account_Payable__c>{testInvoice});
            System.assertEquals(true, postResults[0].isSuccess);

            testInvoice = [
                SELECT Id, Status__c, Net_Amount__c
                FROM Account_Payable__c
                WHERE Id = :testInvoice.Id LIMIT 1
            ];

            Cash_Disbursement__c testCD = new Cash_Disbursement__c(
                Cash_Disbursement_Batch__c = testData.cashDisbursementBatch.get(0).Id,
                Disbursement_Date__c = testAccountingPeriod.Start_Date__c,
                Type__c = 'Check',
                Amount__c = testInvoice.Net_Amount__c,
                Source__c = 'Account Payable',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Debit_GL_Account__c = testData.glAccounts.get(16).Id,
                Contact__c = testData.contacts.get(0).Id,
                Accounting_Period__c = nextAccountingPeriod.Id,
                Status__c = 'Approved',
                Reference__c = 'the reference XXL'
            );
            insert testCD;

            AP_Disbursement__c newAPD = new AP_Disbursement__c(
                Account_Payable__c = testInvoice.Id,
                Cash_Disbursement__c = testCD.Id,
                Paid_Amount__c = testInvoice.Net_Amount__c
            );
            insert newAPD;

            System.assertEquals(
                0,
                [SELECT Balance__c FROM Account_Payable__c WHERE Id = :testInvoice.Id LIMIT 1].Balance__c
            );

            AbstractPostHandler cdPostHandler = new CashDisbursementPostHandler();
            List<PostResult> cdPostResults = cdPostHandler.post(new List<Cash_Disbursement__c>{testCD});

            System.assertEquals(
                true,
                cdPostResults.get(0).isSuccess
            );

            ApexPages.StandardController stdController = new ApexPages.StandardController([
                SELECT  Id,
                    Status__c,
                    Disbursement_Date__c,
                    Payment_Status__c,
                    Accounting_Period__r.Status__c,
                    Type__c,
                    Bank_Account__c,
                    Amount__c,
                    Vendor__c
                FROM Cash_Disbursement__c
                WHERE Id = :testCD.Id
            ]);

            CashDisbursementVoid cdv = new CashDisbursementVoid(stdController);
            cdv.cashDisbursementVoid.Disbursement_Date__c = nextAccountingPeriod.Start_Date__c;
            cdv.voidCashDisbursement();

            List<Accounting_Period__c> periods = new List<Accounting_Period__c>();
            testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            periods.add(testAccountingPeriod);

            nextAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            periods.add(nextAccountingPeriod);

            update periods;

            Test.stopTest();

            Map<Id, Account_Payable__c> validatedTestAccountPayablesMap = new Map<Id, Account_Payable__c>([
                SELECT Id, Closed_Accounting_Period__c, Balance__c, Total__c FROM Account_Payable__c WHERE Id IN :testAccountPayablesMap.keySet()
            ]);


            Map<Id, AP_Aging_History__c> validatedTestAgingHistoriesMap = new Map<Id, AP_Aging_History__c>();
            for (AP_Aging_History__c aph : [
                SELECT Accounting_Period__c, Amount__c, Account_Payable__c
                FROM AP_Aging_History__c
                WHERE Account_Payable__c IN :testAccountPayablesMap.keySet()
            ]) {
                validatedTestAgingHistoriesMap.put(aph.Accounting_Period__c, aph);
            }

            System.assertEquals(
                NULL,
                validatedTestAccountPayablesMap.get(testInvoice.Id).Closed_Accounting_Period__c
            );

            System.assertEquals(
                validatedTestAccountPayablesMap.get(testInvoice.Id).Total__c,
                validatedTestAgingHistoriesMap.get(testAccountingPeriod.Id).Amount__c
            );

            System.assertEquals(
                validatedTestAccountPayablesMap.get(testInvoice.Id).Balance__c,
                validatedTestAgingHistoriesMap.get(nextAccountingPeriod.Id).Amount__c
            );
        }
    }
    
    @IsTest
    private static void testAccountingPeriodCloseAPAgingWhenMCEnabled_MCRounding() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency() //will throw an exception in case of non-MC org
                .createPayables(false)
                .createCashDisbursementBatches()
                .createCashDisbursements();

            System.runAs(testData.users.get(1)) {
                Test.startTest();

                AccountingSettingsHandler.getAccountingSettings();

                String newCurrency = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrency)) {
                    return;
                }

                Map<Id, Account_Payable__c> testAccountPayablesMap = new Map<Id, Account_Payable__c>();

                Account_Payable__c testAccountPayable1 = testData.payables.get(0).clone(); //Invoice
                testAccountPayable1.Status__c = 'Approved';
                testAccountPayable1.Payee_Reference__c = 'Test discount';
                testAccountPayable1.put('CurrencyIsoCode', newCurrency);
                testAccountPayable1.Currency_Conversion_Rate__c = 1.05;
                insert testAccountPayable1;

                Account_Payable_Line__c newApl = new Account_Payable_Line__c(
                    Account_Payable__c = testAccountPayable1.Id,
                    Amount__c = 4500,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = testData.glAccounts[16].Id
                );
                insert newApl;

                testAccountPayable1.Discount_Amount__c = 200;
                update testAccountPayable1;

                testAccountPayablesMap.put(testAccountPayable1.Id, testAccountPayable1);

                Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);

                for (PostResult result : AccountPayablePostService.postAccountPayables(testAccountPayablesMap.values())) {
                    System.assertEquals(true, result.isSuccess);
                }
                //Cash Disbursement Batch and all related Cash Disbursements must have the same currency
                Cash_Disbursement_Batch__c testCashDisbursementBatch =  new Cash_Disbursement_Batch__c(
                    Starting_Check_Number__c = 1,
                    Name = 'Test Batch Discount'
                );
                testCashDisbursementBatch.put('CurrencyIsoCode', newCurrency);
                CashDisbursementBatchActions.isPreventUpdateOverride = true;
                insert testCashDisbursementBatch;

                Cash_Disbursement__c testCashDisbursement = testData.cashDisbursements.get(0).clone();
                testCashDisbursement.Cash_Disbursement_Batch__c = testCashDisbursementBatch.Id;
                testCashDisbursement.Amount__c = 4300;
                testCashDisbursement.Status__c = 'In Process';
                testCashDisbursement.put('CurrencyIsoCode', newCurrency);
                insert testCashDisbursement;

                AP_Disbursement__c apDisbursement = new AP_Disbursement__c(
                    Account_Payable__c = testAccountPayable1.Id,
                    Cash_Disbursement__c = testCashDisbursement.Id,
                    Paid_Amount__c = 4300
                );
                apDisbursement.put('CurrencyIsoCode', newCurrency);
                insert apDisbursement;

                testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
                update testAccountingPeriod;

                Test.stopTest();

                List<AP_Aging_History__c> validatedTestAgingHistories = [
                    SELECT Id, Amount__c, Account_Payable__c FROM AP_Aging_History__c WHERE Account_Payable__c IN :testAccountPayablesMap.keySet()
                ];

                Map<Id, AP_Aging_History__c> validatedTestAgingHistoriesMap = new Map<Id, AP_Aging_History__c>();

                for (AP_Aging_History__c validatedTestAgingHistory : validatedTestAgingHistories) {
                    validatedTestAgingHistoriesMap.put(validatedTestAgingHistory.Account_Payable__c, validatedTestAgingHistory);
                }

                System.assertEquals(
                    0,
                    validatedTestAgingHistoriesMap.get(testAccountPayable1.Id).Amount__c
                );

            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    private static void testAccountingPeriodCloseAPAgingNonZeroBalanceNotPostedSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Map<Id, Account_Payable__c> testAccountPayablesMap = new Map<Id, Account_Payable__c>();

            Account_Payable__c testAccountPayable1 = testData.payables.get(0);
            testAccountPayable1.Discount_Amount__c = 0;
            testAccountPayablesMap.put(testAccountPayable1.Id, testAccountPayable1);

            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);

            Account_Payable__c testAccountPayable5 = testData.payables.get(4);
            testAccountPayable5.Accounting_Period__c = testAccountingPeriod.Id;
            testAccountPayablesMap.put(testAccountPayable5.Id, testAccountPayable5);

            update testAccountPayablesMap.values();

            Cash_Disbursement__c testCashDisbursement = testData.cashDisbursements.get(0);

            ApexPages.StandardController controller = new ApexPages.StandardController(testCashDisbursement);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();
            cdp.post();

            AP_Credit_Memo__c acm = new AP_Credit_Memo__c(
                Account_Payable_Invoice__c = testAccountPayable1.Id,
                Account_Payable_Credit_Memo__c = testAccountPayable5.Id,
                Amount__c = -5,
                Accounting_Period__c = testAccountingPeriod.Id
            );
            insert acm;

            testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testAccountingPeriod;
            Test.stopTest();

            Map<Id, Account_Payable__c> validatedTestAccountPayablesMap = new Map<Id, Account_Payable__c>([
                SELECT Id, Closed_Accounting_Period__c, Balance__c FROM Account_Payable__c WHERE Id IN :testAccountPayablesMap.keySet()
            ]);

            List<AP_Aging_History__c> validatedTestAgingHistories = [
                SELECT Id, Amount__c, Account_Payable__c FROM AP_Aging_History__c WHERE Account_Payable__c IN :testAccountPayablesMap.keySet()
            ];

            Map<Id, AP_Aging_History__c> validatedTestAgingHistoriesMap = new Map<Id, AP_Aging_History__c>();

            for (AP_Aging_History__c validatedTestAgingHistory : validatedTestAgingHistories) {
                validatedTestAgingHistoriesMap.put(validatedTestAgingHistory.Account_Payable__c, validatedTestAgingHistory);
            }

            System.assertEquals(
                null,
                validatedTestAccountPayablesMap.get(testAccountPayable1.Id).Closed_Accounting_Period__c
            );

            System.assertEquals(
                validatedTestAccountPayablesMap.get(testAccountPayable1.Id).Balance__c,
                validatedTestAgingHistoriesMap.get(testAccountPayable1.Id).Amount__c
            );

            System.assertEquals(
                validatedTestAccountPayablesMap.get(testAccountPayable5.Id).Balance__c,
                validatedTestAgingHistoriesMap.get(testAccountPayable5.Id).Amount__c
            );
        }

    }

    @IsTest
    private static void testAccountingPeriodCloseAPAgingZeroBalanceNotPostedSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Map<Id, Account_Payable__c> testAccountPayablesMap = new Map<Id, Account_Payable__c>();
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);

            Account_Payable__c testInvoice = testData.payables.get(0);
            testInvoice.Accounting_Period__c = testAccountingPeriod.Id;
            testInvoice.Discount_Amount__c = 0;
            testAccountPayablesMap.put(testInvoice.Id, testInvoice);

            Account_Payable__c testCreditMemo = testData.payables.get(4);
            testCreditMemo.Accounting_Period__c = testAccountingPeriod.Id;
            testAccountPayablesMap.put(testCreditMemo.Id, testCreditMemo);

            update testAccountPayablesMap.values();

            testInvoice = [
                SELECT Id, Status__c, Net_Amount__c, Paid_Amount__c, Credit_Memo_Applied_Amount__c
                FROM Account_Payable__c
                WHERE Id = :testInvoice.Id LIMIT 1
            ];

            Double cashAmount = testInvoice.Net_Amount__c - 20;
            Cash_Disbursement__c testCD = new Cash_Disbursement__c(
                Cash_Disbursement_Batch__c = testData.cashDisbursementBatch.get(0).Id,
                Disbursement_Date__c = testAccountingPeriod.Start_Date__c,
                Type__c = 'Check',
                Amount__c = cashAmount,
                Source__c = 'Account Payable',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Debit_GL_Account__c = testData.glAccounts.get(16).Id,
                Vendor__c = testData.accounts.get(0).Id,
                Accounting_Period__c = testAccountingPeriod.Id,
                Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                Reference__c = 'the reference XXL'
            );
            insert testCD;

            AP_Disbursement__c newAPD = new AP_Disbursement__c(
                Account_Payable__c = testInvoice.Id,
                Cash_Disbursement__c = testCD.Id,
                Paid_Amount__c = cashAmount
            );
            insert newAPD;

            System.assertEquals(
                20.00,
                [SELECT Balance__c FROM Account_Payable__c WHERE Id = :testInvoice.Id LIMIT 1].Balance__c
            );

            AbstractPostHandler cdPostHandler = new CashDisbursementPostHandler();
            List<PostResult> cdPostResults = cdPostHandler.post(new List<Cash_Disbursement__c>{testCD});

            System.assertEquals(
                true,
                cdPostResults.get(0).isSuccess
            );

            AP_Credit_Memo__c acm = new AP_Credit_Memo__c(
                Account_Payable_Invoice__c = testInvoice.Id,
                Account_Payable_Credit_Memo__c = testCreditMemo.Id,
                Amount__c = -20,
                Accounting_Period__c = testAccountingPeriod.Id
            );
            insert acm;

            testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testAccountingPeriod;

            Test.stopTest();

            Map<Id, Account_Payable__c> validatedTestAccountPayablesMap = new Map<Id, Account_Payable__c>([
                SELECT Id, Closed_Accounting_Period__c, Balance__c FROM Account_Payable__c WHERE Id IN :testAccountPayablesMap.keySet()
            ]);

            List<AP_Aging_History__c> validatedTestAgingHistories = [
                SELECT Id, Amount__c, Account_Payable__c FROM AP_Aging_History__c WHERE Account_Payable__c IN :testAccountPayablesMap.keySet()
            ];

            Map<Id, AP_Aging_History__c> validatedTestAgingHistoriesMap = new Map<Id, AP_Aging_History__c>();

            for (AP_Aging_History__c validatedTestAgingHistory : validatedTestAgingHistories) {
                validatedTestAgingHistoriesMap.put(validatedTestAgingHistory.Account_Payable__c, validatedTestAgingHistory);
            }

            System.assertEquals(
                testAccountingPeriod.Id,
                validatedTestAccountPayablesMap.get(testInvoice.Id).Closed_Accounting_Period__c
            );

            System.assertEquals(
                validatedTestAccountPayablesMap.get(testInvoice.Id).Balance__c,
                validatedTestAgingHistoriesMap.get(testInvoice.Id).Amount__c
            );

            System.assertEquals(
                validatedTestAccountPayablesMap.get(testInvoice.Id).Balance__c,
                validatedTestAgingHistoriesMap.get(testInvoice.Id).Amount__c
            );
        }
    }

    @IsTest
    private static void testcreateAPAgingOnSoftCloseSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().createCashDisbursementBatches();  
        
        System.assertEquals(TRUE, [SELECT ID FROM Account_Payable__c WHERE Accounting_Period__c != null]?.size() > 0);
        System.assertEquals(TRUE, testData.payables.get(0).Accounting_Period__c ==  testData.acctPeriods.get(0).Id);
        System.assertEquals(TRUE, testData.payables.get(1).Accounting_Period__c ==  testData.acctPeriods.get(0).Id);
        System.assertEquals(TRUE, [SELECT ID FROM AP_Aging_History__c]?.size() == 0);
        List < Accounting_Period__c > updatedPeriods = new List < Accounting_Period__c >();

        System.runAs(testData.users.get(1)) {
            
            Test.startTest();
                for (Accounting_Period__c acctPeriod: new List<Accounting_Period__c>{testData.acctPeriods.get(0), testData.acctPeriods.get(1)}) {
                    if(!acctPeriod.close_AP__c){
                        acctPeriod.close_AP__c = true;
                        acctPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
                        updatedPeriods.add(acctPeriod);
                    }
                }
                update updatedPeriods;
            Test.stopTest();
            
            List < AP_Aging_History__c > aphList = [SELECT ID, Amount__c, Accounting_Period__c, Account_Payable__c FROM AP_Aging_History__c];
            System.assertEquals(TRUE, aphList.size() > 0);
            System.assertEquals(testData.acctPeriods.get(0).Id, aphList.get(0).Accounting_Period__c);
            System.assertEquals(testData.acctPeriods.get(0).Id, aphList.get(1).Accounting_Period__c);
            System.assertEquals(testData.acctPeriods.get(0).Id, aphList.get(2).Accounting_Period__c);
            System.assertEquals(testData.acctPeriods.get(0).Id, aphList.get(3).Accounting_Period__c);
            System.assertEquals(165.00, aphList.get(0).Amount__c);
            System.assertEquals(160.00, aphList.get(1).Amount__c);
            System.assertEquals(testData.payables.get(0).Id, aphList.get(0).Account_Payable__c);
            System.assertEquals(testData.payables.get(1).Id, aphList.get(1).Account_Payable__c);
            
            System.assertEquals(testData.acctPeriods.get(1).Id, aphList.get(9).Accounting_Period__c);
            System.assertEquals(testData.acctPeriods.get(1).Id, aphList.get(10).Accounting_Period__c);
            System.assertEquals(testData.payables.get(5).Id, aphList.get(9).Account_Payable__c);
            System.assertEquals(testData.payables.get(7).Id, aphList.get(10).Account_Payable__c);
        }
    }

    /*  The idea to have this test method for the coverage. 
        No assertions can be applied over here since it's referencing ERP fields.
    */
    @IsTest
    private static void testCreateInventoryCreationOnHardClose() {
        TestDataSuite testData = TestDataSuite.getInstance();
        
        List < Accounting_Period__c > updatedPeriods = new List < Accounting_Period__c >();

        System.runAs(testData.users.get(1)) {
            for (Accounting_Period__c acctPeriod: new List<Accounting_Period__c>{testData.acctPeriods.get(0)}) {
                acctPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
                updatedPeriods.add(acctPeriod);
            }
            

            Test.startTest(); 
        
                AccountingPeriodOpenCloseOptions periodInfoContainer =
                new AccountingPeriodOpenCloseOptions(
                    updatedPeriods,
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.CLOSING // context is soft open becoz AR_close is unchecked and status is open
                );

                AccountingPeriodCloseAPAging acountingPeriodCloseAPAging = new AccountingPeriodCloseAPAging(periodInfoContainer);
                Database.executeBatch(acountingPeriodCloseAPAging,1);  
            
            Test.stopTest();

            //assert the batch completed which will make a call to ERP.  There are tests in ERP for the actual creation of Inventory Histories
            List<AsyncApexJob> completedJobs = [SELECT ID, Status, MethodName, ApexClass.Name 
                                                FROM AsyncApexJob 
                                                WHERE ApexClass.Name = 'AccountingPeriodCloseAPAging' 
                                                AND Status = 'Completed' ];

            System.assertEquals(1, completedJobs.size());
        }  
    }
}