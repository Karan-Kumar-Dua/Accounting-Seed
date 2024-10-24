@IsTest
private class AccountPayableApplyCreditMemoTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testValidateAccountingPeriodSoftClose() {
        TestDataSuite testData = TestDataSuite.getInstance()
        .createPayables(false)
        .createCashDisbursementBatches()
        .createCashDisbursements(false);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.acctPeriods[1].Close_AP__c = true;
            testData.acctPeriods[2].Close_AP__c = true;
            testData.acctPeriods[3].Close_AP__c = true;
            testData.acctPeriods[4].Close_AP__c = true;
            testData.acctPeriods[5].Close_AP__c = true;
            testData.acctPeriods[6].Close_AP__c = true;
            update testData.acctPeriods;

            List<Account_Payable__c> testPayables = new List<Account_Payable__c>{
                testData.payables.get(0),
                testData.payables.get(1)
            };

            for (PostResult result : AccountPayablePostService.postAccountPayables(testPayables)) {
                Assert.areEqual(true, result.isSuccess);
            }

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id, Net_Amount__c, Total__c, Vendor__c, Contact__c, Employee__c
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(4).Id
            ]);

            AccountPayableApplyCreditMemo cab = new AccountPayableApplyCreditMemo(controller);
            Test.stopTest();

            Assert.areEqual(1, cab.creditMemoLineWrapperList.size());
            Assert.areEqual(testData.payables.get(0).Accounting_Period__c, cab.creditMemoLineWrapperList[0].acctPayable.AcctSeed__Accounting_Period__c);
            Assert.areEqual(testData.payables.get(0).Payee_Reference__c, cab.creditMemoLineWrapperList[0].acctPayable.Payee_Reference__c);
            Assert.areEqual(testData.payables.get(0).Id, cab.creditMemoLineWrapperList[0].acctPayable.Id);
            Assert.isTrue(cab.creditMemoLineWrapperList[0].isPeriodClosed);
            Assert.isNull(cab.creditMemoLineWrapperList[0].originalAccountingPeriod);
        }
    }

    @IsTest
    private static void testValidateAccountingPeriodNullError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(false)
            .createCashDisbursementBatches()
            .createCashDisbursements(false);

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            List<Account_Payable__c> testPayables = new List<Account_Payable__c>{
                testData.payables.get(0),
                testData.payables.get(1)
            };

            for (PostResult result : AccountPayablePostService.postAccountPayables(testPayables)) {
                System.assertEquals(true, result.isSuccess);
            }

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id, Net_Amount__c, Total__c, Vendor__c, Contact__c, Employee__c
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(4).Id
            ]);

            AccountPayableApplyCreditMemo cab = new AccountPayableApplyCreditMemo(controller);

            cab.creditMemoLineWrapperList.get(0).acmLine.Amount__c = -100;
            cab.creditMemoLineWrapperList.get(0).acmLine.Accounting_Period__c = null;

            Boolean validateStatus = cab.validate();

            Test.stopTest();

            System.assertEquals(false, validateStatus);

            System.assertEquals(
                SObjectActions.REQUIRED_FIELD_ERROR,
                ApexPages.getMessages().get(0).getDetail()
            );
        }
    }
    
    @IsTest
    private static void testValidateAmountLessThanZeroError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(false)
            .createCashDisbursementBatches()
            .createCashDisbursements(false);

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(1).Contact__c = null;
            testData.payables.get(1).Vendor__c = testData.accounts.get(0).Id;
            update testData.payables;

            List<Account_Payable__c> testPayables = new List<Account_Payable__c>{
                testData.payables.get(0),
                testData.payables.get(1)
            };

            for (PostResult result : AccountPayablePostService.postAccountPayables(testPayables)) {
                System.assertEquals(true, result.isSuccess);
            }

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id, Net_Amount__c, Total__c, Vendor__c, Contact__c, Employee__c
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(4).Id
            ]);
            AccountPayableApplyCreditMemo cab = new AccountPayableApplyCreditMemo(controller);

            cab.creditMemoLineWrapperList.get(0).acmLine.Amount__c = -10;
            cab.creditMemoLineWrapperList.get(0).acmLine.Accounting_Period__c = testData.acctPeriods.get(1).Id;
            Boolean validateStatus = cab.validate();
            Test.stopTest();

            System.assertEquals(false, validateStatus);
            System.assertEquals(
                AccountPayableApplyCreditMemo.AMOUNT_LESS_THAN_ZERO_ERROR,
                ApexPages.getMessages().get(0).getDetail()
            );
        }
    }    

    @IsTest
    private static void testValidateAccountPayableBalanceAdjustmentAmountLessThanZeroError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(false)
            .createCashDisbursementBatches()
            .createCashDisbursements(false);

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(1).Contact__c = null;
            testData.payables.get(1).Vendor__c = testData.accounts.get(0).Id;
            update testData.payables;

            List<Account_Payable__c> testPayables = new List<Account_Payable__c>{
                testData.payables.get(0),
                testData.payables.get(1)
            };

            for (PostResult result : AccountPayablePostService.postAccountPayables(testPayables)) {
                System.assertEquals(true, result.isSuccess);
            }

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id, Net_Amount__c, Total__c, Vendor__c, Contact__c, Employee__c
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(4).Id
            ]);
            AccountPayableApplyCreditMemo cab = new AccountPayableApplyCreditMemo(controller);

            cab.creditMemoLineWrapperList.get(0).acmLine.Amount__c = 1000000;
            cab.creditMemoLineWrapperList.get(0).acmLine.Accounting_Period__c = testData.acctPeriods.get(1).Id;

            Boolean validateStatus = cab.validate();

            Test.stopTest();

            System.assertEquals(
                false, validateStatus
            );

            System.assertEquals(
                AccountPayableApplyCreditMemo.ACCOUNT_PAYABLE_BALANCE_LESS_THAN_ZERO_ERROR,
                ApexPages.getMessages().get(0).getDetail()
            );
        }
    }

    @IsTest
    private static void testValidateCreditMemoBalanceLessThanZeroError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(1).Contact__c = null;
            testData.payables.get(1).Vendor__c = testData.accounts.get(0).Id;
            update testData.payables;

            List<Account_Payable__c> testPayables = new List<Account_Payable__c>{
                testData.payables.get(0),
                testData.payables.get(1)
            };

            for (PostResult result : AccountPayablePostService.postAccountPayables(testPayables)) {
                System.assertEquals(true, result.isSuccess);
            }

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id, Net_Amount__c, Total__c, Vendor__c, Contact__c, Employee__c
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(4).Id
            ]);
            AccountPayableApplyCreditMemo cab = new AccountPayableApplyCreditMemo(controller);

            cab.creditMemoLineWrapperList.get(0).acmLine.Amount__c = 40;
            cab.creditMemoLineWrapperList.get(0).acmLine.Accounting_Period__c = testData.acctPeriods.get(1).Id;
            cab.creditMemoLineWrapperList.get(1).acmLine.Amount__c = 20;
            cab.creditMemoLineWrapperList.get(1).acmLine.Accounting_Period__c = testData.acctPeriods.get(1).Id;

            Boolean validateStatus = cab.validate();

            Test.stopTest();

            System.assertEquals(false, validateStatus);

            System.assertEquals(
                AccountPayableApplyCreditMemo.CM_BALANCE_LESS_THAN_ZERO_ERROR,
                ApexPages.getMessages().get(0).getDetail()
            );
        }
    } 
    
    @isTest         
    private static void testCreditMemoApplyAccountsPayableSave() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(1).Contact__c = NULL;
            testData.payables.get(1).Vendor__c = testData.accounts.get(0).Id;

            update testData.payables;

            List<Account_Payable__c> testPayables = new List<Account_Payable__c>{
                testData.payables.get(0),
                testData.payables.get(1)
            };

            for (PostResult result : AccountPayablePostService.postAccountPayables(testPayables)) {
                System.assertEquals(true, result.isSuccess);
            }

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id, Net_Amount__c, Total__c, Vendor__c, Contact__c, Employee__c
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(4).Id
            ]);
            AccountPayableApplyCreditMemo cab = new AccountPayableApplyCreditMemo(controller);

            cab.creditMemoLineWrapperList.get(0).acmLine.Amount__c = 30;
            cab.creditMemoLineWrapperList.get(0).acmLine.Accounting_Period__c = testData.acctPeriods.get(1).Id;
            cab.creditMemoLineWrapperList.get(1).acmLine.Amount__c = 10;
            cab.creditMemoLineWrapperList.get(1).acmLine.Accounting_Period__c = testData.acctPeriods.get(1).Id;
            cab.save();

            Test.stopTest();

            System.assertEquals(
                2,
                [SELECT COUNT() FROM AP_Credit_Memo__c WHERE Account_Payable_Credit_Memo__c = :testData.payables.get(4).Id]
            );

            System.assertEquals(
                2,
                cab.creditMemoLineWrapperList.size()
            );
        }
    }

    @isTest         
    private static void testCreditMemoApplyAccountsPayableSaveAndRefresh() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(1).Contact__c = NULL;
            testData.payables.get(1).Vendor__c = testData.accounts.get(0).Id;

            update testData.payables;

            List<Account_Payable__c> testPayables = new List<Account_Payable__c>{
                testData.payables.get(0),
                testData.payables.get(1)
            };

            for (PostResult result : AccountPayablePostService.postAccountPayables(testPayables)) {
                System.assertEquals(true, result.isSuccess);
            }

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id, Net_Amount__c, Total__c, Vendor__c, Contact__c, Employee__c
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(4).Id
            ]);

            AccountPayableApplyCreditMemo cab = new AccountPayableApplyCreditMemo(controller);

            cab.creditMemoLineWrapperList.get(0).acmLine.Amount__c = 30;
            cab.creditMemoLineWrapperList.get(0).acmLine.Accounting_Period__c = testData.acctPeriods.get(1).Id;
            cab.creditMemoLineWrapperList.get(1).acmLine.Amount__c = 10;
            cab.creditMemoLineWrapperList.get(1).acmLine.Accounting_Period__c = testData.acctPeriods.get(1).Id;
            cab.saveAndRefresh();

            Test.stopTest();

            System.assertEquals(
                2,
                [SELECT count() FROM AP_Credit_Memo__c WHERE Account_Payable_Credit_Memo__c = :testData.payables.get(4).Id]
            );

            System.assertEquals(
                2,
                cab.creditMemoLineWrapperList.size()
            );
        }
    }

    @IsTest
    private static void testCreditMemoApplyAccountsPayableLastModifiedDateTimeError() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createPayables(true);

        Test.startTest();

        testData.createCashDisbursementBatches();
        testData.createCashDisbursements(false);

        System.runAs(testData.users.get(1)) {
            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id, Net_Amount__c, Total__c, Vendor__c, Contact__c, Employee__c
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(4).Id
            ]);

            AccountPayableApplyCreditMemo cab = new AccountPayableApplyCreditMemo(controller);
            cab.creditMemoLineWrapperList.get(0).acmLine.Amount__c = 30;
            cab.creditMemoLineWrapperList.get(0).acmLine.Accounting_Period__c = testData.acctPeriods.get(0).Id;
            Datetime payableLastModified = [SELECT Id, LastModifiedDate FROM Account_Payable__c WHERE Id = :testData.payables[4].Id LIMIT 1].LastModifiedDate;

            TestDataSuite.getOneSecondDelayByDateTime(payableLastModified);
            for (PostResult result : AccountPayablePostService.unpostAccountPayables(new List<Account_Payable__c>{testData.payables.get(4)})) {
                System.assertEquals(true, result.isSuccess);
            }
            cab.save();

            System.assertEquals(
                AccountPayableApplyCreditMemo.LAST_MODIFIED_ERROR,
                ApexPages.getMessages().get(0).getSummary()
            );
        }
    }

    @IsTest
    private static void testCreditMemoApplyAccountsPayableSaveAndRefresh_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency() //will throw an exception in case of non-MC org
                .createPayables(true)
                .createCashDisbursementBatches()
                .createCashDisbursements();

            System.runAs(testData.users.get(1)) {
                Test.startTest();

                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }
                Account_Payable__c testAP1 = testData.payables.get(0);
                Account_Payable__c testAP2 = testData.payables.get(1);
                Account_Payable__c creditMemo = testData.payables.get(4); //it is Account Payable record with Type: Credit Memo

                //testAP1 - it is foreign AP with the same Currency and Currency Conversion Rate like in Credit Memo
                testAP1.put('CurrencyIsoCode', newCurrencyIsoCode);
                testAP1.Currency_Conversion_Rate__c = 1.2;

                //testAP2 - it is foreign AP with the same Currency like in Credit Memo but different Currency Conversion Rate
                testAP2.put('CurrencyIsoCode', newCurrencyIsoCode);
                testAP2.Currency_Conversion_Rate__c = 1.5;

                //change Currency and Currency Conversion Rate for Credit Memo
                creditMemo.put('CurrencyIsoCode', newCurrencyIsoCode);
                creditMemo.Currency_Conversion_Rate__c = 1.2;

                TriggerObserver.getInstance().unlockFields(
                    new Set<SObjectField>{Schema.SObjectType.Account_Payable__c.fields.getMap().get('CurrencyIsoCode')}
                );
                update new List<Account_Payable__c>{testAP1, testAP2, creditMemo};

                //now we need to post all that Account Payables
                for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testAP1, testAP2, creditMemo})) {
                    System.assertEquals(
                        true,
                        result.isSuccess
                    );
                }

                ApexPages.StandardController stdController = new ApexPages.StandardController(creditMemo);
                AccountPayableApplyCreditMemo controller = new AccountPayableApplyCreditMemo(stdController);

                //Check non corporate flag is set to true
                System.assertEquals(
                    false,
                    controller.isLedgerCurrency
                );

                //Check only one AP is in list (by currency and ccr)
                System.assertEquals(
                    1,
                    controller.creditMemoLineWrapperList.size()
                );

                controller.creditMemoLineWrapperList.get(0).acmLine.Amount__c = 30;
                controller.creditMemoLineWrapperList.get(0).acmLine.Accounting_Period__c = testData.acctPeriods.get(1).Id;

                controller.saveAndRefresh();

                Test.stopTest();

                System.assertEquals(
                    1,
                    [SELECT COUNT() FROM AP_Credit_Memo__c WHERE Account_Payable_Credit_Memo__c = :creditMemo.Id]
                );
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @isTest
    private static void testCreditMemoApplyAccountsPayableForLegacyRecords_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency() //will throw an exception in case of non-MC org
                .createPayables()
                .createCashDisbursementBatches()
                .createCashDisbursements();

            System.runAs(testData.users.get(1)) {
                Test.startTest();

                Map<Id, Account_Payable__c> accountPayableMap = new Map<Id, Account_Payable__c>();

                Account_Payable__c creditMemo = testData.payables.get(4); //it is Account Payable record with Type: Credit Memo
                accountPayableMap.put(creditMemo.Id, creditMemo);

                Account_Payable__c testAP1 = testData.payables.get(0);
                accountPayableMap.put(testAP1.Id, testAP1);

                Account_Payable__c testAP2 = testData.payables.get(1);
                testAP2.Contact__c = NULL;
                testAP2.Vendor__c = creditMemo.Vendor__c;
                accountPayableMap.put(testAP2.Id, testAP2);

                update accountPayableMap.values();

                //now we need to post all that Account Payables
                for (PostResult result : AccountPayablePostService.postAccountPayables(accountPayableMap.values())) {
                    System.assertEquals(true, result.isSuccess);
                }

                testAP1 = [SELECT Id, Currency_Conversion_Rate__c, Status__c FROM Account_Payable__c WHERE Id = :testAP1.Id];
                testAP2 = [SELECT Id, Currency_Conversion_Rate__c, Status__c FROM Account_Payable__c WHERE Id = :testAP2.Id];
                creditMemo = [SELECT Id, Currency_Conversion_Rate__c, Status__c FROM Account_Payable__c WHERE Id = :creditMemo.Id];

                //Set CCR to simulate legacy records in org
                //testAP1 - it is legacy AP with the same Currency and Currency Conversion Rate like in Credit Memo
                testAP1.Currency_Conversion_Rate__c = NULL;

                //testAP2 - it is legacy AP with the same Currency like in Credit Memo but different Currency Conversion Rate
                //wich was set to default value by trigger during update
                testAP2.Currency_Conversion_Rate__c = 1;

                //change Currency and Currency Conversion Rate for Credit Memo
                creditMemo.Currency_Conversion_Rate__c = NULL;

                update new List<Account_Payable__c>{testAP1, testAP2, creditMemo};

                //make sure that CCRs were set as planned
                System.assertEquals(NULL, testAP1.Currency_Conversion_Rate__c);
                System.assertEquals(1, testAP2.Currency_Conversion_Rate__c);
                System.assertEquals(NULL, creditMemo.Currency_Conversion_Rate__c);

                ApexPages.StandardController stdController = new ApexPages.StandardController(creditMemo);
                AccountPayableApplyCreditMemo controller = new AccountPayableApplyCreditMemo(stdController);

                Test.stopTest();

                //Check base currency flag is set to true
                System.assertEquals(true, controller.isLedgerCurrency);
                //Check both APs are in list (by currency and ccr)
                System.assertEquals(2, controller.creditMemoLineWrapperList.size());
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testRecentAccountingPeriodAndNotRecentError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(1).Contact__c = NULL;
            testData.payables.get(1).Vendor__c = testData.accounts.get(0).Id;

            update testData.payables;

            List<Account_Payable__c> testPayables = new List<Account_Payable__c>{
                testData.payables.get(0),
                testData.payables.get(4)
            };

            for (PostResult result : AccountPayablePostService.postAccountPayables(testPayables)) {
                System.assertEquals(true, result.isSuccess);
            }

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id, Net_Amount__c, Total__c, Vendor__c, Contact__c, Employee__c
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(4).Id
            ]);
            AccountPayableApplyCreditMemo cab = new AccountPayableApplyCreditMemo(controller);

            System.assertEquals(cab.creditMemoLineWrapperList.get(0).acmLine.Accounting_Period__c, testData.acctPeriods[1].Id);

            cab.creditMemoLineWrapperList.get(0).acmLine.Amount__c = 30;
            cab.creditMemoLineWrapperList.get(0).acmLine.Accounting_Period__c = testData.acctPeriods.get(0).Id;
            cab.save();

            Test.stopTest();

            System.assertEquals(
                String.format(
                    AccountPayableApplyCreditMemo.PERIOD_ERROR,
                    new List<String> {testData.acctPeriods[1].Name}),
                ApexPages.getMessages().get(0).getSummary()
            );
        }
    }

    @IsTest
    public static void testSelectAppliedInvoices() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(false)
            .createCashDisbursementBatches()
            .createCashDisbursements(false);

        System.runAs(testData.users.get(1)) {
            testData.payables[0].Vendor__c = testData.accounts[1].Id;
            testData.payables[1].Vendor__c = testData.accounts[1].Id;
            testData.payables[1].Contact__c = NULL;
            testData.payables[2].Vendor__c = testData.accounts[1].Id;
            testData.payables[2].Employee__c = NULL;
            testData.payables[3].Vendor__c = testData.accounts[1].Id;
            testData.payables[3].Employee__c = NULL;
            testData.payables[4].Vendor__c = testData.accounts[1].Id;
            testData.payables[5].Vendor__c = testData.accounts[1].Id;
            testData.payables[7].Vendor__c = testData.accounts[1].Id;
            update testData.payables;

            Test.startTest();

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[5], testData.payables[0]})) {
                System.assertEquals(true, result.isSuccess);
            }

            List<AP_Credit_Memo__c> apcmList = new List<AP_Credit_Memo__c>();

            AP_Credit_Memo__c testAPCM = new AP_Credit_Memo__c();
            testAPCM.Account_Payable_Credit_Memo__c = testData.payables[4].Id;
            testAPCM.Account_Payable_Invoice__c = testData.payables[1].Id;
            testAPCM.Accounting_Period__c = testData.acctPeriods[2].Id;
            testAPCM.Amount__c = -3;

            apcmList.add(testAPCM);

            AP_Credit_Memo__c testAPCM2 = new AP_Credit_Memo__c();
            testAPCM2.Account_Payable_Credit_Memo__c = testData.payables[4].Id;
            testAPCM2.Account_Payable_Invoice__c = testData.payables[2].Id;
            testAPCM2.Accounting_Period__c = testData.acctPeriods[2].Id;
            testAPCM2.Amount__c = -3;

            apcmList.add(testAPCM2);

            AP_Credit_Memo__c testAPCM3 = new AP_Credit_Memo__c();
            testAPCM3.Account_Payable_Credit_Memo__c = testData.payables[4].Id;
            testAPCM3.Account_Payable_Invoice__c = testData.payables[3].Id;
            testAPCM3.Accounting_Period__c = testData.acctPeriods[2].Id;
            testAPCM3.Amount__c = -3;

            apcmList.add(testAPCM3);

            AP_Credit_Memo__c testAPCM4 = new AP_Credit_Memo__c();
            testAPCM4.Account_Payable_Credit_Memo__c = testData.payables[4].Id;
            testAPCM4.Account_Payable_Invoice__c = testData.payables[7].Id;
            testAPCM4.Accounting_Period__c = testData.acctPeriods[2].Id;
            testAPCM4.Amount__c = -3;

            apcmList.add(testAPCM4);
            insert apcmList;

            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.payables.get(4));
            AccountPayableApplyCreditMemo controller = new AccountPayableApplyCreditMemo(stdController);

            System.assertEquals(6, controller.creditMemoLineWrapperList.size());
        }
    }

}