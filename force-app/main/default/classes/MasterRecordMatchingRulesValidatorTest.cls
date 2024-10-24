@IsTest
private class MasterRecordMatchingRulesValidatorTest {

    //================= Billing Cash Receipt Tests ==============================
    @IsTest
    public static void testAllowNegativeAppliedBCR() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings(false)
            .disableAutoPostSourceDocuments()
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Cash_Receipt__c testCR = testData.cashReceipts[0].clone();
            insert testCR;

            Billing_Cash_Receipt__c testBCR = new Billing_Cash_Receipt__c(
                Cash_Receipt__c = testCR.Id,
                Billing__c = testData.billings.get(3).Id,
                Accounting_Period__c = testData.acctPeriods[3].Id,
                Applied_Amount__c = 2
            );
            insert testBCR;
            Test.stopTest();

            System.assertEquals(
                testBCR.Applied_Amount__c,
                [
                    SELECT Received_Amount__c
                    FROM Billing__c
                    WHERE Id = :testData.billings[3].Id
                ]
                .Received_Amount__c
            );
        }
    }

    @IsTest
    public static void testValidateRecentAccountingPeriodBCR() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            testData.billings[0].Accounting_Period__c = testData.acctPeriods[2]
                .Id;
            update testData.billings[0];

            ApexPages.StandardController cont = new ApexPages.StandardController(
                [
                    SELECT Accounting_Period__r.Status__c, Status__c
                    FROM Billing__c
                    WHERE Id = :testData.billings[0].Id
                ]
            );
            BillingPostTransaction pbt = new BillingPostTransaction(cont);
            pbt.post();

            System.assertEquals(
                'Posted',
                [
                    SELECT Accounting_Period__r.Status__c, Status__c
                    FROM Billing__c
                    WHERE Id = :testData.billings[0].Id
                ]
                .Status__c
            );

            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Billing__c = testData.billings[0].Id;
            bcr.Cash_Receipt__c = testData.cashReceipts[0].Id;
            bcr.Applied_Amount__c = 100;
            bcr.Accounting_Period__c = testData.acctPeriods[0].Id;

            DMLException dmlEx;
            try {
                insert bcr;
            } catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(
                String.format(
                    MasterRecordMatchingRulesValidator.RECENT_PERIOD_MEMO_ERROR,
                    new List<String>{
                        Billing_Cash_Receipt__c.getSObjectType()
                            .getDescribe()
                            .getLabel(),
                        testData.acctPeriods[2].Name
                    }
                ),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void testPreventCreatingAccountingPeriodClosedBCR() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings(false)
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            DmlException dmlEx;
            try {
                Cash_Receipt__c testCR = testData.cashReceipts[0].clone();
                insert testCR;

                Accounting_Period__c testAccountingPeriod = testData.acctPeriods[0];
                testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
                update testAccountingPeriod;

                Billing_Cash_Receipt__c testBCR = new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testCR.Id,
                    Billing__c = testData.billings.get(0).Id,
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Applied_Amount__c = 12
                );

                insert testBCR;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            // cannot validate direct rule because lookup field rule fired first
            System.assertEquals(
                'The accounting period status must be &quot;Open&quot;',
                dmlEx.getDmlMessage(0)
            );
            Test.stopTest();
        }
    }

    @IsTest
    public static void testPreventCreatingBCRForSoftClosedPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings(false)
            .disableAutoPostSourceDocuments()
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            DmlException dmlEx;
            try {
                Cash_Receipt__c testCR = testData.cashReceipts[0].clone();
                insert testCR;

                Accounting_Period__c testAccountingPeriod = testData.acctPeriods[0];
                testAccountingPeriod.Close_AR__c = true;
                update testAccountingPeriod;

                Billing_Cash_Receipt__c testBCR = new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testCR.Id,
                    Billing__c = testData.billings.get(0).Id,
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Applied_Amount__c = 12
                );

                insert testBCR;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            String expectedMessage = String.format(Label.ERR_OPEN_ACCOUNTING_PERIOD_ERROR,
                new List<String>{Billing_Cash_Receipt__c.getSObjectType().getDescribe().getLabel()}
            );

            Assert.areEqual(expectedMessage, dmlEx.getDmlMessage(0));
        }
    }


    @IsTest
    public static void testPreventCreateNotSameLedgerBCR() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings(false)
            .disableAutoPostSourceDocuments()
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            DmlException dmlEx;
            try {
                Cash_Receipt__c testCR = testData.cashReceipts[0].clone(false, true);
                testCR.Ledger__c = testData.ledgers[2].Id;
                insert testCR;

                System.assertEquals(
                    1,
                    [SELECT COUNT() FROM Cash_Receipt__c WHERE Id = :testCR.Id]
                );

                Billing_Cash_Receipt__c testBCR = new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testCR.Id,
                    Billing__c = testData.billings.get(0).Id,
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Applied_Amount__c = 12
                );

                insert testBCR;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                MasterRecordMatchingRulesValidator.DIFFERENT_LEDGER_FOR_MASTER_RECORDS_ERROR_MAP.get(
                    Billing_Cash_Receipt__c.getSObjectType()
                ),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void testPreventCreateNotSameCurrencyBCR() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance(true)
                .enableMultiCurrency() //will throw an exception in case of non-MC org
                .createBillings(true);

            System.runAs(testData.users.get(1)) {
                String theNewCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(theNewCurrencyIsoCode)) {
                    return;
                }

                Test.startTest();
                testData.disableAutoPostSourceDocuments();

                Billing__c testBilling = testData.billings.get(0);
                //insert new CR with non base currency
                Cash_Receipt__c testCR = new Cash_Receipt__c(
                    Account__c = testData.accounts.get(0).Id,
                    Amount__c = 400,
                    Payment_Reference__c = '0000000XXX',
                    Status__c = 'In Process',
                    Receipt_Date__c = testData.acctPeriods.get(1).Start_Date__c,
                    Accounting_Period__c = testData.acctPeriods.get(1).Id,
                    Bank_Account__c = testData.glAccounts.get(0).Id,
                    Credit_GL_Account__c = testData.glAccounts.get(1).Id
                );
                testCR.put('CurrencyIsoCode', theNewCurrencyIsoCode);
                insert testCR;

                //create new BCR record
                Billing_Cash_Receipt__c testBCR = new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testCR.Id,
                    Billing__c = testBilling.Id,
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Applied_Amount__c = 12
                );

                DmlException dmlEx;
                try {
                    insert testBCR;
                } catch (DmlException ex) {
                    dmlEx = ex;
                }

                System.assertEquals(
                    MasterRecordMatchingRulesValidator.DIFFERENT_CURRENCY_FOR_MASTER_RECORDS_ERROR_MAP.get(
                        Billing_Cash_Receipt__c.getSObjectType()
                    ),
                    dmlEx.getDmlMessage(0)
                );
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    //================= Billing Credit Memo Tests ===============================

    @IsTest
    public static void testValidateNegativeAppliedBCM() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();

            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
            bcm.Billing_Invoice__c = testData.billings[3].Id;
            bcm.Billing_Credit_Memo__c = testData.billings[2].Id;
            bcm.Accounting_Period__c = testData.acctPeriods[3].Id;
            bcm.Amount__c = -10;

            DMLException dmlEx;
            try {
                insert bcm;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            // cannot validate direct rule because lookup field rule fired first
            System.assertEquals(
                'The type field of the billing must be &quot;Invoice&quot;',
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void testValidateRecentAccountingPeriodBCM() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing__c testBilling = testData.billings.get(0).clone();
            testBilling.Accounting_Period__c = testData.acctPeriods[1].Id;
            insert testBilling;

            Billing_Line__c testLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 20,
                Rate__c = 10,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );

            insert testLine;

            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
            bcm.Billing_Invoice__c = testBilling.Id;
            bcm.Billing_Credit_Memo__c = testData.billings[2].Id;
            bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
            bcm.Amount__c = -2;

            DMLException dmlEx;
            try {
                insert bcm;
            } catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(
                String.format(
                    MasterRecordMatchingRulesValidator.RECENT_PERIOD_MEMO_ERROR,
                    new List<String>{
                        Billing_Credit_Memo__c.getSObjectType()
                            .getDescribe()
                            .getLabel(),
                        testData.acctPeriods[1].Name
                    }
                ),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void testPreventCreatingAccountingPeriodClosedBCM() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            DMLException dmlEx;
            try {
                Billing__c testBilling = testData.billings.get(0).clone();
                testBilling.Ledger__c = testData.ledgers[2].Id;
                insert testBilling;

                Billing_Line__c testLine = new Billing_Line__c(
                    Billing__c = testBilling.Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Hours_Units__c = 20,
                    Rate__c = 10,
                    Revenue_GL_Account__c = testData.glAccounts[10].Id
                );
                insert testLine;

                Accounting_Period__c testAccountingPeriod = testData.acctPeriods[0];
                testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
                update testAccountingPeriod;

                Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
                bcm.Billing_Invoice__c = testBilling.Id;
                bcm.Billing_Credit_Memo__c = testData.billings[2].Id;
                bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
                bcm.Amount__c = -2;
                insert bcm;
            } catch (DMLException ex) {
                dmlEx = ex;
            }
            //cannot validate direct rule because lookup field rule fired first
            System.assertEquals(
                'The accounting period must be open',
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void testPreventCreatingBCMForSoftClosedPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing__c testBilling = testData.billings.get(0).clone();
            testBilling.Accounting_Period__c = testData.acctPeriods[1].Id;
            insert testBilling;

            Billing_Line__c testLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 20,
                Rate__c = 10,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );

            insert testLine;

            Accounting_Period__c testAccountingPeriod = testData.acctPeriods[0];
            testAccountingPeriod.Close_AR__c = true;
            update testAccountingPeriod;

            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
            bcm.Billing_Invoice__c = testBilling.Id;
            bcm.Billing_Credit_Memo__c = testData.billings[2].Id;
            bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
            bcm.Amount__c = -2;

            DMLException dmlEx;
            try {
                insert bcm;
            } catch (DMLException ex) {
                dmlEx = ex;
            }
            Assert.areEqual(String.format(
                                Label.ERR_OPEN_ACCOUNTING_PERIOD,
                                new List<String>{Billing_Credit_Memo__c.getSObjectType()
                                    .getDescribe()
                                    .getLabel()}
                                ), dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testPreventCreateNotSameLedgerBCM() {
        TestDataSuite testData = TestDataSuite.getInstance(true).createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Billing__c testBilling = testData.billings.get(0).clone();
            testBilling.Ledger__c = testData.ledgers[2].Id;
            insert testBilling;

            Billing_Line__c testLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 20,
                Rate__c = 10,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            insert testLine;

            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
            bcm.Billing_Invoice__c = testBilling.Id;
            bcm.Billing_Credit_Memo__c = testData.billings[2].Id;
            bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
            bcm.Amount__c = -2;

            DmlException dmlEx;
            try {
                insert bcm;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                MasterRecordMatchingRulesValidator.DIFFERENT_LEDGER_FOR_MASTER_RECORDS_ERROR_MAP.get(
                    Billing_Credit_Memo__c.getSObjectType()
                ),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void testPreventCreateNotSameCurrencyBCM() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance(true)
                .enableMultiCurrency() //will throw an exception in case of non-MC org
                .createBillings(true);

            System.runAs(testData.users.get(1)) {
                String theNewCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(theNewCurrencyIsoCode)) {
                    return;
                }

                Test.startTest();

                Billing__c testBilling = testData.billings.get(0).clone();

                testBilling.put('CurrencyIsoCode', theNewCurrencyIsoCode);
                insert testBilling;

                Billing_Line__c testLine = new Billing_Line__c(
                    Billing__c = testBilling.Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Hours_Units__c = 20,
                    Rate__c = 10,
                    Revenue_GL_Account__c = testData.glAccounts[10].Id
                );

                insert testLine;

                Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
                bcm.Billing_Invoice__c = testBilling.Id;
                bcm.Billing_Credit_Memo__c = testData.billings[2].Id;
                bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
                bcm.Amount__c = -2;

                DmlException dmlEx;
                try {
                    insert bcm;
                } catch (DmlException ex) {
                    dmlEx = ex;
                }

                System.assertEquals(
                    MasterRecordMatchingRulesValidator.DIFFERENT_CURRENCY_FOR_MASTER_RECORDS_ERROR_MAP.get(
                        Billing_Credit_Memo__c.getSObjectType()
                    ),
                    dmlEx.getDmlMessage(0)
                );
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testPreventCreateNotSameCCRBCM() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance(true)
                .enableMultiCurrency() //will throw an exception in case of non-MC org
                .createBillings();

            System.runAs(testData.users.get(1)) {
                String theNewCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(theNewCurrencyIsoCode)) {
                    return;
                }

                Test.startTest();

                Billing__c testBilling = testData.billings.get(0).clone();
                insert testBilling;

                testBilling.Currency_Conversion_Rate__c = 5;
                update testBilling;

                Billing_Line__c testLine = new Billing_Line__c(
                    Billing__c = testBilling.Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Hours_Units__c = 20,
                    Rate__c = 10,
                    Revenue_GL_Account__c = testData.glAccounts[10].Id
                );

                insert testLine;

                Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
                bcm.Billing_Invoice__c = testBilling.Id;
                bcm.Billing_Credit_Memo__c = testData.billings[2].Id;
                bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
                bcm.Amount__c = -2;

                DmlException dmlEx;
                try {
                    insert bcm;
                } catch (DmlException ex) {
                    dmlEx = ex;
                }

                System.assertEquals(
                    MasterRecordMatchingRulesValidator.DIFFERENT_CCR_FOR_MASTER_RECORDS_ERROR_MAP.get(
                        Billing_Credit_Memo__c.getSObjectType()
                    ),
                    dmlEx.getDmlMessage(0)
                );
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    //================= AP Disbursement Tests ===================================
    @IsTest
    public static void testValidateNegativeAppliedAPD() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables(true)
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();

            AP_Disbursement__c testApDisbursement = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[4].Id,
                Cash_Disbursement__c = testData.cashDisbursements[0].Id,
                Paid_Amount__c = 10,
                Accounting_Period__c = testData.acctPeriods[4].Id
            );
            insert testApDisbursement;
            System.assertEquals(
                testApDisbursement.Paid_Amount__c,
                [
                    SELECT Paid_Amount__c
                    FROM Account_Payable__c
                    WHERE Id = :testData.payables[4].Id
                ]
                .Paid_Amount__c
            );
        }
    }
    @IsTest
    public static void testValidateRecentAccountingPeriodAPD() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables(false)
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Accounting_Period__c testAccountingPeriod = new Accounting_Period__c(
                Name = '1991-09',
                Start_Date__c = Date.newInstance(1991, 9, 1),
                End_Date__c = Date.newInstance(1991, 9, 30),
                Status__c = AccountingPeriodActions.OPEN_STATUS
            );
            insert testAccountingPeriod;

            AccountingPeriodHandler.reset();
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            Cash_Disbursement__c testCD = testData.cashDisbursements[0].clone(false, true);
            testCD.Debit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;
            testCD.Source__c = 'Payable';
            CashDisbursementActions.isSourcedFromPayables = true;
            insert testCD;
            CashDisbursementActions.isSourcedFromPayables = false;

            AP_Disbursement__c testApDisbursement = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[0].Id,
                Cash_Disbursement__c = testCD.Id,
                Paid_Amount__c = 10,
                Accounting_Period__c = testAccountingPeriod.Id
            );

            DmlException dmlEx;
            try {
                insert testApDisbursement;
            } catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(
                String.format(
                    MasterRecordMatchingRulesValidator.RECENT_PERIOD_MEMO_ERROR,
                    new List<String>{
                        AP_Disbursement__c.getSObjectType()
                            .getDescribe()
                            .getLabel(),
                        testData.acctPeriods[0].Name
                    }
                ),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void testPreventCreatingAccountingPeriodClosedAPD() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables(false)
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();

            Accounting_Period__c testAccountingPeriod = testData.acctPeriods[0];
            testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testAccountingPeriod;

            Test.stopTest();

            AP_Disbursement__c testApDisbursement = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[0].Id,
                Cash_Disbursement__c = testData.cashDisbursements[0].Id,
                Paid_Amount__c = 145
            );

            DmlException dmlEx;
            try {
                insert testApDisbursement;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(
                    MasterRecordMatchingRulesValidator.OPEN_ACCOUNTING_PERIOD_ERROR,
                    new List<String>{
                        AP_Disbursement__c.getSObjectType()
                            .getDescribe()
                            .getLabel()
                    }
                ),
                dmlEx.getDmlMessage(0)
            );
        }

    }

    @IsTest
    public static void testPreventCreateNotSameLedgerAPD() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables(false)
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            DmlException dmlEx;
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            try {
                Cash_Disbursement__c testCD = testData.cashDisbursements[0].clone(false, true);
                testCD.Debit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;
                testCD.Source__c = 'Payable';
                testCD.Ledger__c = testData.ledgers[2].Id;
                CashDisbursementActions.isSourcedFromPayables = true;
                insert testCD;
                CashDisbursementActions.isSourcedFromPayables = false;

                System.assertEquals(
                    1,
                    [
                        SELECT COUNT()
                        FROM Cash_Disbursement__c
                        WHERE Id = :testCD.Id
                    ]
                );

                AP_Disbursement__c extraAPD = new AP_Disbursement__c(
                    Account_Payable__c = testData.payables[0].Id,
                    Cash_Disbursement__c = testCD.Id,
                    Paid_Amount__c = 10
                );
                insert extraAPD;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                MasterRecordMatchingRulesValidator.DIFFERENT_LEDGER_FOR_MASTER_RECORDS_ERROR_MAP.get(
                    AP_Disbursement__c.getSObjectType()
                ),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void testPreventCreateNotSamePayeeAPD() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables(false)
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            DmlException dmlEx;
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            try {
                Cash_Disbursement__c testCD = testData.cashDisbursements[0].clone(false, true);
                testCD.Debit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;
                testCD.Source__c = 'Payable';
                testCD.Vendor__c = testData.accounts[1].Id;
                CashDisbursementActions.isSourcedFromPayables = true;
                insert testCD;
                CashDisbursementActions.isSourcedFromPayables = false;

                System.assertEquals(
                    1,
                    [
                        SELECT COUNT()
                        FROM Cash_Disbursement__c
                        WHERE Id = :testCD.Id
                    ]
                );

                AP_Disbursement__c extraAPD = new AP_Disbursement__c(
                    Account_Payable__c = testData.payables[0].Id,
                    Cash_Disbursement__c = testCD.Id,
                    Paid_Amount__c = 10
                );
                insert extraAPD;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                MasterRecordMatchingRulesValidator.DIFFERENT_PAYEE_ON_MASTER_RECORDS_ERROR.get(
                    AP_Disbursement__c.getSObjectType()
                ),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void testPreventCreateNotSamePayeeDiffSourcePayeeAPD() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables(false)
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            DmlException dmlEx;
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            try {
                Cash_Disbursement__c testCD = testData.cashDisbursements[0].clone(false, true);
                testCD.Debit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;
                testCD.Source__c = 'Payable';
                testCD.Employee__c = testData.users[1].Id;
                testCD.Vendor__c = null;
                CashDisbursementActions.isSourcedFromPayables = true;
                insert testCD;
                CashDisbursementActions.isSourcedFromPayables = false;
                System.assertEquals(
                    1,
                    [
                        SELECT COUNT()
                        FROM Cash_Disbursement__c
                        WHERE Id = :testCD.Id
                    ]
                );

                AP_Disbursement__c extraAPD = new AP_Disbursement__c(
                    Account_Payable__c = testData.payables[0].Id,
                    Cash_Disbursement__c = testCD.Id,
                    Paid_Amount__c = 10
                );
                insert extraAPD;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                MasterRecordMatchingRulesValidator.DIFFERENT_PAYEE_ON_MASTER_RECORDS_ERROR.get(
                    AP_Disbursement__c.getSObjectType()
                ),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void testPreventCreateAPDForVoidedCD() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables(true)
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            DMLException dmlEx;
            try {
                //Post CD
                AbstractPostHandler postHandler = new CashDisbursementPostHandler();
                List<PostResult> postResults = postHandler.post(testData.cashDisbursements);
                System.assertEquals(true, postResults[0].isSuccess);
                //Void CD
                ApexPages.StandardController stdController = new ApexPages.StandardController([
                    SELECT
                        Id,
                        Status__c,
                        Disbursement_Date__c,
                        Payment_Status__c,
                        Accounting_Period__r.Status__c,
                        Type__c,
                        Bank_Account__c,
                        Amount__c,
                        Vendor__c
                    FROM Cash_Disbursement__c
                    WHERE Id = :testData.cashDisbursements[7].Id
                ]);

                CashDisbursementVoid cdv = new CashDisbursementVoid(stdController);
                cdv.cashDisbursementVoid.Void_Description__c = 'Void Reason';
                cdv.cashDisbursementVoid.Disbursement_Date__c = cdv.cashDisbursement.Disbursement_Date__c;
                cdv.voidCashDisbursement();

                System.assertEquals(
                    'Void', [
                        SELECT Payment_Status__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[7].Id
                    ].Payment_Status__c
                );

                AP_Disbursement__c extraAPD = new AP_Disbursement__c(
                    Account_Payable__c = testData.payables[0].Id,
                    Cash_Disbursement__c = testData.cashDisbursements[7].Id,
                    Paid_Amount__c = 10
                );
                insert extraAPD;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(CashDisbursement.VOIDED_CD_ERROR, dmlEx.getDMLMessage(0));
        }
    }

    @IsTest
    public static void testPreventCreateNotSameCurrencyAPD() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance(true)
                .enableMultiCurrency() //will throw an exception in case of non-MC org
                .createPayables(true);

            System.runAs(testData.users.get(1)) {
                String theNewCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(theNewCurrencyIsoCode)) {
                    return;
                }

                Test.startTest();

                Account_Payable__c testPayable = testData.payables.get(0);
                //insert new CDB record with non base currency
                Cash_Disbursement_Batch__c testCDB = new Cash_Disbursement_Batch__c(
                    Starting_Check_Number__c = 1,
                    Name = 'Test Batch XXX'
                );
                testCDB.put('CurrencyIsoCode', theNewCurrencyIsoCode);
                insert testCDB;
                //insert new CD with non base currency
                Cash_Disbursement__c testCD = new Cash_Disbursement__c(
                    Cash_Disbursement_Batch__c = testCDB.Id,
                    Disbursement_Date__c = testData.acctPeriods[0]
                        .Start_Date__c,
                    Amount__c = 10,
                    Bank_Account__c = testData.glAccounts[0].Id,
                    Debit_GL_Account__c = testData.glAccounts[23].Id,
                    Vendor__c = testData.accounts[0].Id,
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Status__c = 'In Process',
                    Reference__c = '34-56-78'
                );
                testCD.put('CurrencyIsoCode', theNewCurrencyIsoCode);
                insert testCD;

                //create APD record
                AP_Disbursement__c newAPD = new AP_Disbursement__c(
                    Account_Payable__c = testPayable.Id,
                    Cash_Disbursement__c = testCD.Id,
                    Paid_Amount__c = 10
                );

                DmlException dmlEx;
                try {
                    insert newAPD;
                } catch (DmlException ex) {
                    dmlEx = ex;
                }

                System.assertEquals(
                    MasterRecordMatchingRulesValidator.DIFFERENT_CURRENCY_FOR_MASTER_RECORDS_ERROR_MAP.get(
                        AP_Disbursement__c.getSObjectType()
                    ),
                    dmlEx.getDmlMessage(0)
                );
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    //================= AP Credit Memo Tests ====================================

    @IsTest
    public static void testValidateNegativeAppliedAPCM() {
        TestDataSuite testData = TestDataSuite.getInstance(true).createPayables();

        System.runAs(testData.users.get(1)) {
            AP_Credit_Memo__c testApCreditMemo = new AP_Credit_Memo__c(
                Account_Payable_Invoice__c = testData.payables[4].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Account_Payable_Credit_Memo__c = testData.payables[4].Id,
                Amount__c = -10
            );

            DmlException dmlEx;
            try {
                insert testApCreditMemo;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            // cannot validate direct rule because lookup field rule fired first
            System.assertEquals(
                'The Type field of the payable must be &quot;Invoice&quot;.',
                dmlEx.getDmlMessage(0)
            );
        }

    }

    @IsTest
    public static void testValidateRecentAccountingPeriodAPCM() {
        TestDataSuite testData = TestDataSuite.getInstance(true).createPayables();

        System.runAs(testData.users.get(1)) {
            testData.payables[3].Vendor__c = testData.accounts[0].Id;
            testData.payables[3].Employee__c = null;
            update testData.payables[3];

            AP_Credit_Memo__c testApCreditMemo = new AP_Credit_Memo__c(
                Account_Payable_Invoice__c = testData.payables[3].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Account_Payable_Credit_Memo__c = testData.payables[4].Id,
                Amount__c = -55
            );

            DmlException dmlEx;
            try {
                insert testApCreditMemo;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(
                    MasterRecordMatchingRulesValidator.RECENT_PERIOD_MEMO_ERROR,
                    new List<String>{
                        AP_Credit_Memo__c.getSObjectType()
                            .getDescribe()
                            .getLabel(),
                        testData.acctPeriods[1].Name
                    }
                ),
                dmlEx.getDmlMessage(0)
            );
        }

    }

    @IsTest
    public static void testPreventCreatingAccountingPeriodClosedAPCM() {
        TestDataSuite testData = TestDataSuite.getInstance(true).createPayables();

        System.runAs(testData.users[1]) {
            Test.startTest();

            Account_Payable__c testPayable = testData.payables.get(0).clone();

            testPayable.Payee_Reference__c = 'test 22';
            testPayable.Accounting_Period__c = testData.acctPeriods[0].Id;
            insert testPayable;
            Account_Payable_Line__c testLine = new Account_Payable_Line__c(
                Account_Payable__c = testPayable.Id,
                Amount__c = 300,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Expense_GL_Account__c = testData.glAccounts[16].Id
            );

            insert testLine;

            Accounting_Period__c testAccountingPeriod = testData.acctPeriods[0];
            testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testAccountingPeriod;

            AP_Credit_Memo__c testApCreditMemo = new AP_Credit_Memo__c(
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Account_Payable_Invoice__c = testPayable.Id,
                Account_Payable_Credit_Memo__c = testData.payables[4].Id,
                Amount__c = -5
            );

            DMLException dmlEx;
            try {
                insert testApCreditMemo;
            } catch (DmlException ex) {
                dmlEx = ex;
            }
            // cannot validate direct rule because lookup field rule fired first
            System.assertEquals(
                'The accounting period status must be open',
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void testPreventCreatingAPCMForSoftClosedPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance(true).createPayables();

        System.runAs(testData.users[1]) {
            Test.startTest();

            Account_Payable__c testPayable = testData.payables.get(0).clone();

            testPayable.Payee_Reference__c = 'test 22';
            testPayable.Accounting_Period__c = testData.acctPeriods[0].Id;
            insert testPayable;
            Account_Payable_Line__c testLine = new Account_Payable_Line__c(
                Account_Payable__c = testPayable.Id,
                Amount__c = 300,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Expense_GL_Account__c = testData.glAccounts[16].Id
            );

            insert testLine;

            Accounting_Period__c testAccountingPeriod = testData.acctPeriods[0];
            testAccountingPeriod.Close_AP__c = true;
            update testAccountingPeriod;

            AP_Credit_Memo__c testApCreditMemo = new AP_Credit_Memo__c(
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Account_Payable_Invoice__c = testPayable.Id,
                Account_Payable_Credit_Memo__c = testData.payables[4].Id,
                Amount__c = -5
            );

            DMLException dmlEx;
            try {
                insert testApCreditMemo;
            } catch (DmlException ex) {
                dmlEx = ex;
            }
            Assert.areEqual(String.format(
                Label.ERR_OPEN_ACCOUNTING_PERIOD,
                new List<String>{AP_Credit_Memo__c.getSObjectType()
                    .getDescribe()
                    .getLabel()}
                ), dmlEx.getDmlMessage(0));
        }
    }



    @IsTest
    public static void testPreventCreateNotSameLedgerAPCM() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables(true)
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            DMLException dmlEx;

            try {
                Account_Payable__c testPayable = testData.payables.get(0)
                    .clone();

                testPayable.Payee_Reference__c = 'test 22';
                testPayable.Ledger__c = testData.ledgers[2].Id;
                insert testPayable;

                Account_Payable_Line__c testLine = new Account_Payable_Line__c(
                    Account_Payable__c = testPayable.Id,
                    Amount__c = 300,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = testData.glAccounts[16].Id
                );

                insert testLine;

                AP_Credit_Memo__c testApCreditMemo = new AP_Credit_Memo__c(
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Account_Payable_Invoice__c = testPayable.Id,
                    Account_Payable_Credit_Memo__c = testData.payables[4].Id,
                    Amount__c = -5
                );

                insert testApCreditMemo;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                MasterRecordMatchingRulesValidator.DIFFERENT_LEDGER_FOR_MASTER_RECORDS_ERROR_MAP.get(
                    AP_Credit_Memo__c.getSObjectType()
                ),
                dmlEx.getDMLMessage(0)
            );
        }
    }

    // The application of a Payable Credit Memo to a Payable Invoice with the same Account, Contact, or Employee
    // is enforced via a validation rule on the AP Credit Memo junction object. This can be disabled by the customer.
    /*
    @IsTest
    public static void testPreventCreateNotSamePayeeDiffSourcePayeeAPCM() {

    } 
    */

    @IsTest
    public static void testPreventCreateNotSameCurrencyAPCM() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance(true)
                .enableMultiCurrency() //will throw an exception in case of non-MC org
                .createPayables(true);

            System.runAs(testData.users.get(1)) {
                String theNewCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(theNewCurrencyIsoCode)) {
                    return;
                }

                Test.startTest();

                Account_Payable__c testPayable = testData.payables.get(0)
                    .clone();

                testPayable.put('CurrencyIsoCode', theNewCurrencyIsoCode);
                testPayable.Payee_Reference__c = 'test 22';
                insert testPayable;

                Account_Payable_Line__c testLine = new Account_Payable_Line__c(
                    Account_Payable__c = testPayable.Id,
                    Amount__c = 300,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = testData.glAccounts[16].Id
                );

                insert testLine;

                AP_Credit_Memo__c testApCreditMemo = new AP_Credit_Memo__c(
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Account_Payable_Invoice__c = testPayable.Id,
                    Account_Payable_Credit_Memo__c = testData.payables[4].Id,
                    Amount__c = -5
                );

                DmlException dmlEx;
                try {
                    insert testApCreditMemo;
                } catch (DmlException ex) {
                    dmlEx = ex;
                }

                System.assertEquals(
                    MasterRecordMatchingRulesValidator.DIFFERENT_CURRENCY_FOR_MASTER_RECORDS_ERROR_MAP.get(
                        AP_Credit_Memo__c.getSObjectType()
                    ),
                    dmlEx.getDmlMessage(0)
                );
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testPreventCreateNotSameCCRAPCM() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance(true)
                .enableMultiCurrency() //will throw an exception in case of non-MC org
                .createPayables();

            System.runAs(testData.users.get(1)) {
                String theNewCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(theNewCurrencyIsoCode)) {
                    return;
                }

                Test.startTest();

                Account_Payable__c testPayable = testData.payables.get(0)
                    .clone();
                testPayable.Payee_Reference__c = 'test 22';
                insert testPayable;

                testPayable.Currency_Conversion_Rate__c = 5;
                update testPayable;

                Account_Payable_Line__c testLine = new Account_Payable_Line__c(
                    Account_Payable__c = testPayable.Id,
                    Amount__c = 300,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = testData.glAccounts[16].Id
                );

                insert testLine;

                AP_Credit_Memo__c testApCreditMemo = new AP_Credit_Memo__c(
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Account_Payable_Invoice__c = testPayable.Id,
                    Account_Payable_Credit_Memo__c = testData.payables[4].Id,
                    Amount__c = -5
                );

                DmlException dmlEx;
                try {
                    insert testApCreditMemo;
                } catch (DmlException ex) {
                    dmlEx = ex;
                }

                System.assertEquals(
                    MasterRecordMatchingRulesValidator.DIFFERENT_CCR_FOR_MASTER_RECORDS_ERROR_MAP.get(
                        AP_Credit_Memo__c.getSObjectType()
                    ),
                    dmlEx.getDmlMessage(0)
                );
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }
}