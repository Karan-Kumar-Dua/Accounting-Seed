@IsTest
private class AccountingPeriodCloseBillingAgingTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testAccountingPeriodCloseBillingAgingWhenMCEnabled_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                    .enableMultiCurrency() //will throw an exception in case of non-MC org
                    .createCashReceipts()
                    .createBillings()
                    .createBillingAgingHistories();

            System.runAs(testData.users.get(1)) {
                Test.startTest();
                AccountingSettingsHandler.getAccountingSettings();

                Map<Id, Billing__c> testBillingsMap = new Map<Id, Billing__c>();

                String newCurrency = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrency)) {
                    return;
                }
                Billing__c testBilling1 = testData.billings.get(0); //Invoice
                testBilling1.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED;
                testBilling1.put('CurrencyIsoCode', newCurrency);
                testBillingsMap.put(testBilling1.Id, testBilling1);

                Billing__c testBilling2 = testData.billings.get(3); //Credit Memo
                testBilling2.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED;
                testBilling2.put('CurrencyIsoCode', newCurrency);
                testBillingsMap.put(testBilling2.Id, testBilling2);

                TriggerObserver.getInstance().unlockFields(
                    new Set<SObjectField>{Schema.SObjectType.Billing__c.fields.getMap().get('CurrencyIsoCode')}
                );
                update testBillingsMap.values();
                TriggerObserver.reset();

                testBilling1.Currency_Conversion_Rate__c = 1.2;
                testBilling2.Currency_Conversion_Rate__c = 1.2;
                update new List<Billing__c> {testBilling1, testBilling2};

                Cash_Receipt__c testCR = testData.cashReceipts.get(2).clone();
                testCR.put('CurrencyIsoCode', newCurrency);
                testCR.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED;
                insert testCR;

                PostResult result = BillingPostService.postBillings(testBillingsMap.values()).get(0);
                System.assertEquals(true, result.isSuccess);

                System.assertEquals(
                    AccountingPeriodActions.OPEN_STATUS,
                    [SELECT Id, Status__c FROM Accounting_Period__c WHERE Id = :testData.acctPeriods.get(0).Id].Status__c
                );

                Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c(
                    Billing__c = testBilling1.Id,
                    Cash_Receipt__c = testCR.Id,
                    Applied_Amount__c = 1,
                    Adjustment_Amount__c = 3,
                    Adjustment_GL_Account__c = testData.glAccounts.get(0).Id,
                    Accounting_Period__c = testData.acctPeriods.get(0).Id
                );
                insert bcr;

                Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c(
                    Billing_Invoice__c = testBilling1.Id,
                    Billing_Credit_Memo__c = testBilling2.Id,
                    Amount__c = -5,
                    Accounting_Period__c = testData.acctPeriods.get(0).Id
                );
                insert bcm;

                delete testData.billingAgingHistories;
                testData.acctPeriods.get(0).Status__c = AccountingPeriodActions.CLOSED_STATUS;
                update testData.acctPeriods.get(0);

                Test.stopTest();

                Map<Id, Billing__c> validatedTestBillingsMap = new Map<Id, Billing__c>([
                    SELECT Id, Closed_Accounting_Period__c, Ledger_Amount__c
                    FROM Billing__c
                    WHERE Id IN :testBillingsMap.keySet()
                ]);

                Map<Id, Billing_Aging_History__c> validatedTestBillingAgingHistoriesMap =
                    new Map<Id, Billing_Aging_History__c>();

                List<Billing_Aging_History__c> validatedTestBillingAgingHistories = [
                    SELECT Id, Amount__c, Billing__c
                    FROM Billing_Aging_History__c
                    WHERE Billing__c IN :testBillingsMap.keySet()
                ];

                for (Billing_Aging_History__c validatedTestBillingAgingHistory : validatedTestBillingAgingHistories) {
                    validatedTestBillingAgingHistoriesMap.put(
                        validatedTestBillingAgingHistory.Billing__c,
                        validatedTestBillingAgingHistory
                    );
                }

                System.assertEquals(
                    null,
                    validatedTestBillingsMap.get(testBilling1.Id).Closed_Accounting_Period__c
                );

                System.assertEquals(
                    validatedTestBillingsMap.get(testBilling1.Id).Ledger_Amount__c
                        - (3 / 1.2 + 1 / 1.2 + 5/ 1.2).setScale(2, System.RoundingMode.HALF_UP),
                    validatedTestBillingAgingHistoriesMap.get(testBilling1.Id).Amount__c
                );

                System.assertEquals(
                    validatedTestBillingsMap.get(testBilling2.Id).Ledger_Amount__c
                        + (5/ 1.2).setScale(2, System.RoundingMode.HALF_UP),
                    validatedTestBillingAgingHistoriesMap.get(testBilling2.Id).Amount__c
                );
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    private static void testAccountingPeriodCloseBillingAgingNoAccountingSettingsError() {
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
                    new List<Accounting_Period__c>{testData.acctPeriods.get(3)},
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.CLOSING
                );
            AccountingPeriodCloseBillingAging apc = new AccountingPeriodCloseBillingAging(periodDataContainer);

            System.assertEquals(
                false,
                apc.main.Enable_Billing_Period_Sensitive_Aging__c
            );
        }
    }

    @IsTest
    private static void testAccountingPeriodCloseBillingAgingFinalStatusSet() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            System.assertEquals(
                AccountingPeriodActions.OPEN_STATUS,
                [SELECT Id, Status__c FROM Accounting_Period__c WHERE Id = :testData.acctPeriods.get(0).Id].Status__c
            );

            AccountingPeriodOpenCloseOptions periodDataContainer =
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testData.acctPeriods.get(0)},
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.CLOSING
                );
            AccountingPeriodCloseBillingAging apc = new AccountingPeriodCloseBillingAging(periodDataContainer);
            Database.executeBatch(apc);

            Test.stopTest();

            System.assertEquals(
                AccountingPeriodActions.CLOSED_STATUS,
                [SELECT Id, Status__c FROM Accounting_Period__c WHERE Id = :testData.acctPeriods.get(0).Id].Status__c
            );
        }
    }
    
    @IsTest
    private static void testAccountingPeriodCloseBillingAgingNonZeroBalanceSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createCashReceipts()
                .createBillings()
                .createBillingAgingHistories();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Map<Id, Billing__c> testBillingsMap = new Map<Id, Billing__c>();

            Billing__c testBilling1 = testData.billings.get(0); //Invoice
            testBilling1.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED;
            testBillingsMap.put(testBilling1.Id, testBilling1);

            Billing__c testBilling2 = testData.billings.get(3); //Credit Memo
            testBilling2.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED;
            testBillingsMap.put(testBilling2.Id, testBilling2);
            update testBillingsMap.values();

            for (PostResult result : BillingPostService.postBillings(testBillingsMap.values())) {
                System.assertEquals(
                    true,
                    result.isSuccess
                );
            }

            List<Billing_Cash_Receipt__c> insertBCR = new List<Billing_Cash_Receipt__c>();

            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c(
                Billing__c = testBilling1.Id,
                Cash_Receipt__c = testData.cashReceipts.get(2).Id,//has same period as billing
                Applied_Amount__c = 1,
                Adjustment_Amount__c = 3,
                Adjustment_GL_Account__c = testData.glAccounts.get(0).Id,
                Accounting_Period__c = testData.acctPeriods.get(0).Id
            );
            insertBCR.add(bcr);
            insert insertBCR;

            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c(
                Billing_Invoice__c = testBilling1.Id,
                Billing_Credit_Memo__c = testBilling2.Id,
                Amount__c = -5,
                Accounting_Period__c = testData.acctPeriods.get(0).Id
            );
            insert bcm;

            delete testData.billingAgingHistories;

            testData.acctPeriods.get(0).Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods.get(0);

            Test.stopTest();

            Map<Id, Billing__c> validatedTestBillingsMap = new Map<Id, Billing__c>([
                SELECT Id, Closed_Accounting_Period__c, Total__c
                FROM Billing__c
                WHERE Id IN :testBillingsMap.keySet()
            ]);

            Map<Id, Billing_Aging_History__c> validatedTestBillingAgingHistoriesMap = new Map<Id, Billing_Aging_History__c>();

            List<Billing_Aging_History__c> validatedTestBillingAgingHistories = [
                SELECT Id, Amount__c, Billing__c
                FROM Billing_Aging_History__c
                WHERE Billing__c IN :testBillingsMap.keySet()
            ];

            for (Billing_Aging_History__c validatedTestBillingAgingHistory : validatedTestBillingAgingHistories) {
                validatedTestBillingAgingHistoriesMap.put(
                    validatedTestBillingAgingHistory.Billing__c,
                    validatedTestBillingAgingHistory
                );
            }

            System.assertEquals(
                null,
                validatedTestBillingsMap.get(testBilling1.Id).Closed_Accounting_Period__c
            );

            System.assertEquals(
                validatedTestBillingsMap.get(testBilling1.Id).Total__c - 9,
                validatedTestBillingAgingHistoriesMap.get(testBilling1.Id).Amount__c
            );

            System.assertEquals(
                validatedTestBillingsMap.get(testBilling2.Id).Total__c + 5,
                validatedTestBillingAgingHistoriesMap.get(testBilling2.Id).Amount__c
            );
        }
    }

    @IsTest
    private static void testAccountingPeriodCloseBillingAgingZeroBalanceSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createCashReceipts()
                .createBillings()
                .createBillingAgingHistories();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Map<Id, Billing__c> testBillingsMap = new Map<Id, Billing__c>();

            Billing__c testBilling1 = testData.billings.get(0); //Invoice
            testBilling1.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED;
            testBillingsMap.put(testBilling1.Id, testBilling1);

            Billing__c testBilling2 = testData.billings.get(3); //Credit Memo
            testBilling2.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED;
            testBillingsMap.put(testBilling2.Id, testBilling2);
            update testBillingsMap.values();

            for (PostResult result : BillingPostService.postBillings(testBillingsMap.values())) {
                System.assertEquals(
                    true,
                    result.isSuccess
                );
            }
            delete testData.billingAgingHistories;

            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c(
                Billing__c = testBilling1.Id,
                Cash_Receipt__c = testData.cashReceipts.get(2).Id,
                Applied_Amount__c = 50,
                Adjustment_Amount__c = 150,
                Adjustment_GL_Account__c = testData.glAccounts.get(0).Id,
                Accounting_Period__c = testData.acctPeriods.get(0).Id
            );
            insert bcr;

            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c(
                Billing_Invoice__c = testBilling1.Id,
                Billing_Credit_Memo__c = testBilling2.Id,
                Amount__c = -250,
                Accounting_Period__c = testData.acctPeriods.get(0).Id
            );
            insert bcm;

            testData.acctPeriods.get(0).Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods.get(0);

            Test.stopTest();

            Map<Id, Billing__c> validatedTestBillingsMap = new Map<Id, Billing__c>([
                SELECT Id, Closed_Accounting_Period__c, Balance__c FROM Billing__c WHERE Id IN :testBillingsMap.keySet()
            ]);

            Map<Id, Billing_Aging_History__c> validatedTestBillingAgingHistoriesMap = new Map<Id, Billing_Aging_History__c>();

            List<Billing_Aging_History__c> validatedTestBillingAgingHistories = [
                SELECT Id, Amount__c, Billing__c FROM Billing_Aging_History__c WHERE Billing__c IN :testBillingsMap.keySet()
            ];

            for (Billing_Aging_History__c validatedTestBillingAgingHistory : validatedTestBillingAgingHistories) {
                validatedTestBillingAgingHistoriesMap.put(
                    validatedTestBillingAgingHistory.Billing__c,
                    validatedTestBillingAgingHistory
                );
            }

            System.assertEquals(
                testData.acctPeriods.get(0).Id,
                validatedTestBillingsMap.get(testBilling1.Id).Closed_Accounting_Period__c
            );

            System.assertEquals(
                validatedTestBillingsMap.get(testBilling1.Id).Balance__c,
                validatedTestBillingAgingHistoriesMap.get(testBilling1.Id).Amount__c
            );

            System.assertEquals(
                validatedTestBillingsMap.get(testBilling2.Id).Balance__c,
                validatedTestBillingAgingHistoriesMap.get(testBilling2.Id).Amount__c
            );
        }
    }

    @IsTest
    private static void testCloseAccountingPeriodBillingAgingHistoryWhenNegativeAdjustmentAmount() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            //Create Billing
            Billing__c testBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c.addDays(3),
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = testData.acctPeriods[0].Start_Date__c + 30
            );
            insert testBilling;

            Billing_Line__c testBillingLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 1,
                Rate__c = 500,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            insert testBillingLine;

            //Post Billing
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, postResults[0].isSuccess);

            //Create Cash Receipt
            Cash_Receipt__c testCR = new Cash_Receipt__c(
                Account__c = testData.accounts.get(0).Id,
                Amount__c = 500,
                Payment_Reference__c = '0000000432',
                Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                Receipt_Date__c = testData.acctPeriods.get(0).Start_Date__c,
                Accounting_Period__c = testData.acctPeriods.get(0).Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Credit_GL_Account__c = testData.glAccounts.get(1).Id
            );
            insert testCR;

            //Apply the Cash Receipt with negative adjustment amount
            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c(
                Billing__c = testBilling.Id,
                Cash_Receipt__c = testCR.Id,
                Applied_Amount__c = 300,
                Adjustment_Amount__c = -150,
                Adjustment_GL_Account__c = testData.glAccounts[21].Id,//4900-Customer Payment Discounts
                Accounting_Period__c = testData.acctPeriods.get(0).Id
            );
            insert bcr;

            
            //Close Accounting Period
            testData.acctPeriods.get(0).Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods.get(0);
            Test.stopTest();

            //Validate Billing Aging History record
            List<Billing_Aging_History__c> billAgingHistories = [
                SELECT Id, Amount__c
                FROM Billing_Aging_History__c
                WHERE Billing__c = :testBilling.Id
            ];

            System.assertEquals(false, billAgingHistories.isEmpty());
            System.assertEquals(500 - 300 - (-150), billAgingHistories[0].Amount__c);
        }
    }

    @IsTest
    private static void testAccountingPeriodCloseBillingAgingZeroBalanceNotPostedSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Map<Id, Billing__c> testBillingsMap = new Map<Id, Billing__c>();

            Billing__c testBilling1 = testData.billings.get(0); //Invoice
            testBillingsMap.put(testBilling1.Id, testBilling1);

            Billing__c testBilling2 = testData.billings.get(3); //Credit Memo
            testBillingsMap.put(testBilling2.Id, testBilling2);

            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c(
                Billing__c = testBilling1.Id,
                Cash_Receipt__c = testData.cashReceipts.get(2).Id,
                Applied_Amount__c = 50,
                Adjustment_Amount__c = 150,
                Adjustment_GL_Account__c = testData.glAccounts.get(0).Id,
                Accounting_Period__c = testData.acctPeriods.get(0).Id
            );
            insert bcr;

            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c(
                Billing_Invoice__c = testBilling1.Id,
                Billing_Credit_Memo__c = testBilling2.Id,
                Amount__c = -250,
                Accounting_Period__c = testData.acctPeriods.get(0).Id
            );
            insert bcm;

            testData.acctPeriods.get(0).Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods.get(0);

            Test.stopTest();

            Map<Id, Billing__c> validatedTestBillingsMap = new Map<Id, Billing__c>([
                SELECT Id, Closed_Accounting_Period__c, Balance__c FROM Billing__c WHERE Id IN :testBillingsMap.keySet()
            ]);

            Map<Id, Billing_Aging_History__c> validatedTestBillingAgingHistoriesMap = new Map<Id, Billing_Aging_History__c>();

            List<Billing_Aging_History__c> validatedTestBillingAgingHistories = [
                SELECT Id, Amount__c, Billing__c FROM Billing_Aging_History__c WHERE Billing__c IN :testBillingsMap.keySet()
            ];

            for (Billing_Aging_History__c validatedTestBillingAgingHistory : validatedTestBillingAgingHistories) {
                validatedTestBillingAgingHistoriesMap.put(
                    validatedTestBillingAgingHistory.Billing__c,
                    validatedTestBillingAgingHistory
                );
            }

            System.assertEquals(
                testData.acctPeriods.get(0).Id,
                validatedTestBillingsMap.get(testBilling1.Id).Closed_Accounting_Period__c
            );

            System.assertEquals(
                validatedTestBillingsMap.get(testBilling1.Id).Balance__c,
                validatedTestBillingAgingHistoriesMap.get(testBilling1.Id).Amount__c
            );

            System.assertEquals(
                validatedTestBillingsMap.get(testBilling2.Id).Balance__c,
                validatedTestBillingAgingHistoriesMap.get(testBilling2.Id).Amount__c
            );
        }
    }

    @IsTest
    private static void testAccountingPeriodCloseBillingAgingNonZeroBalanceNotPostedSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Map<Id, Billing__c> testBillingsMap = new Map<Id, Billing__c>();

            Billing__c testBilling1 = testData.billings.get(0); //Invoice
            testBillingsMap.put(testBilling1.Id, testBilling1);

            Billing__c testBilling2 = testData.billings.get(3); //Credit Memo
            testBillingsMap.put(testBilling2.Id, testBilling2);

            List<Billing_Cash_Receipt__c> insertBCR = new List<Billing_Cash_Receipt__c>();

            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c(
                Billing__c = testBilling1.Id,
                Cash_Receipt__c = testData.cashReceipts.get(2).Id,//has same period as billing
                Applied_Amount__c = 1,
                Adjustment_Amount__c = 3,
                Adjustment_GL_Account__c = testData.glAccounts.get(0).Id,
                Accounting_Period__c = testData.acctPeriods.get(0).Id
            );
            insertBCR.add(bcr);
            insert insertBCR;

            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c(
                Billing_Invoice__c = testBilling1.Id,
                Billing_Credit_Memo__c = testBilling2.Id,
                Amount__c = -5,
                Accounting_Period__c = testData.acctPeriods.get(0).Id
            );
            insert bcm;

            testData.acctPeriods.get(0).Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods.get(0);

            Test.stopTest();

            Map<Id, Billing__c> validatedTestBillingsMap = new Map<Id, Billing__c>([
                SELECT Id, Closed_Accounting_Period__c, Total__c
                FROM Billing__c
                WHERE Id IN :testBillingsMap.keySet()
            ]);

            Map<Id, Billing_Aging_History__c> validatedTestBillingAgingHistoriesMap = new Map<Id, Billing_Aging_History__c>();

            List<Billing_Aging_History__c> validatedTestBillingAgingHistories = [
                SELECT Id, Amount__c, Billing__c
                FROM Billing_Aging_History__c
                WHERE Billing__c IN :testBillingsMap.keySet()
            ];

            for (Billing_Aging_History__c validatedTestBillingAgingHistory : validatedTestBillingAgingHistories) {
                validatedTestBillingAgingHistoriesMap.put(
                    validatedTestBillingAgingHistory.Billing__c,
                    validatedTestBillingAgingHistory
                );
            }

            System.assertEquals(
                null,
                validatedTestBillingsMap.get(testBilling1.Id).Closed_Accounting_Period__c
            );

            System.assertEquals(
                validatedTestBillingsMap.get(testBilling1.Id).Total__c - 9,
                validatedTestBillingAgingHistoriesMap.get(testBilling1.Id).Amount__c
            );

            System.assertEquals(
                validatedTestBillingsMap.get(testBilling2.Id).Total__c + 5,
                validatedTestBillingAgingHistoriesMap.get(testBilling2.Id).Amount__c
            );
        }
    }
    
    @isTest
    private static void testcreateCloseBillingAgingOnSoftCloseSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
            
        System.assertEquals(TRUE, [SELECT ID FROM Billing__c WHERE Accounting_Period__c != null]?.size() > 0);
        System.assertEquals(TRUE, testData.billings.get(0).Accounting_Period__c ==  testData.acctPeriods.get(0).Id);
        System.assertEquals(TRUE, testData.billings.get(1).Accounting_Period__c ==  testData.acctPeriods.get(0).Id);
        System.assertEquals(TRUE, [SELECT ID FROM Billing_Aging_History__c]?.size() == 0);
        List < Accounting_Period__c > updatedPeriods = new List < Accounting_Period__c >();

        System.runAs(testData.users.get(1)) {
            
            Test.startTest();
                for (Accounting_Period__c acctPeriod: new List<Accounting_Period__c>{testData.acctPeriods.get(0), testData.acctPeriods.get(1)}) {
                    if(!acctPeriod.close_AR__c){
                        acctPeriod.AcctSeed__Close_AR__c = true;
                        acctPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
                        updatedPeriods.add(acctPeriod);
                    }
                }
                update updatedPeriods;
            Test.stopTest();
            
            List < Billing_Aging_History__c > bahList = [SELECT ID, Amount__c, Accounting_Period__c, Billing__c FROM Billing_Aging_History__c];
            System.assertEquals(TRUE, bahList.size() > 0);
            System.assertEquals(testData.acctPeriods.get(0).Id, bahList.get(0).Accounting_Period__c);
            System.assertEquals(testData.acctPeriods.get(0).Id, bahList.get(1).Accounting_Period__c);
            System.assertEquals(testData.acctPeriods.get(0).Id, bahList.get(2).Accounting_Period__c);
            System.assertEquals(testData.acctPeriods.get(0).Id, bahList.get(3).Accounting_Period__c);
            System.assertEquals(testData.billings.get(0).Id, bahList.get(0).Billing__c);
            System.assertEquals(testData.billings.get(1).Id, bahList.get(1).Billing__c);
            
            System.assertEquals(testData.acctPeriods.get(1).Id, bahList.get(5).Accounting_Period__c);
            System.assertEquals(testData.acctPeriods.get(1).Id, bahList.get(6).Accounting_Period__c);
            System.assertEquals(testData.acctPeriods.get(1).Id, bahList.get(7).Accounting_Period__c);
            System.assertEquals(testData.billings.get(1).Id, bahList.get(5).Billing__c);
            System.assertEquals(testData.billings.get(2).Id, bahList.get(6).Billing__c);
            System.assertEquals(testData.billings.get(3).Id, bahList.get(3).Billing__c);
            System.assertEquals(testData.billings.get(0).Id, bahList.get(4).Billing__c);
        }
    }

}