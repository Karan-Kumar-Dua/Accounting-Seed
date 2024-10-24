@IsTest
private class AmortizationHelperTest {
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testCreateEntriesBehavior() {
        String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            System.assert([SELECT Id FROM Scheduled_Revenue_Expense__c].isEmpty());
            Test.startTest();
            Account_Payable__c accountPayable = testData.payables[0];
            GL_Account__c newAccGL = testData.glAccounts[12];
            Map<String, Object> result = AmortizationHelper.createEntries(new Map<String, Object>{
                    'sourceDocumentId' => accountPayable.Id,
                    'selectedMethod' => 'Straight Line - Daily',
                    'startDate' => Datetime.newInstance(accountPayable.Date__c.addDays(2), Time.newInstance(0, 0, 0, 0)).format('yyyy-MM-dd'),
                    'endDate' => Datetime.newInstance(accountPayable.Due_Date__c.addDays(5), Time.newInstance(0, 0, 0, 0)).format('yyyy-MM-dd'),
                    PACKAGE_QUALIFIER + 'Amount__c' => '13400',
                    PACKAGE_QUALIFIER + 'Debit_GL_Account__c' => newAccGL.Id,
                    PACKAGE_QUALIFIER + 'Credit_GL_Account__c' => newAccGL.Id,
                    'accrualCash' => LedgerActions.ACCOUNTING_METHOD_ACCRUAL
            });
            Test.stopTest();

            System.assert((Boolean)result.get('isSuccess'));
            System.assert(![SELECT Id FROM Scheduled_Revenue_Expense__c].isEmpty());
        }
    }

    @IsTest
    static void testFetchSettingsBehavior() {
        String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Account_Payable__c accountPayable = testData.payables[0];
            GL_Account__c newAccGL = testData.glAccounts[12];
            AmortizationHelper.createEntries(new Map<String, Object>{
                    'sourceDocumentId' => accountPayable.Id,
                    'selectedMethod' => 'Straight Line - Daily',
                    'startDate' => Datetime.newInstance(accountPayable.Date__c.addDays(2), Time.newInstance(0, 0, 0, 0)).format('yyyy-MM-dd'),
                    'endDate' => Datetime.newInstance(accountPayable.Due_Date__c.addDays(5), Time.newInstance(0, 0, 0, 0)).format('yyyy-MM-dd'),
                    PACKAGE_QUALIFIER + 'Amount__c' => '13400',
                    PACKAGE_QUALIFIER + 'Debit_GL_Account__c' => newAccGL.Id,
                    PACKAGE_QUALIFIER + 'Credit_GL_Account__c' => newAccGL.Id,
                    'accrualCash' => LedgerActions.ACCOUNTING_METHOD_ACCRUAL
            });

            Map<String, Object> result = AmortizationHelper.fetchSettings(accountPayable.Id);
            Test.stopTest();

            System.assert(result.get('isAutoPostEnabled') != null);
            System.assert(Double.valueOf(result.get('existingAmountsSum')) == 13400);
            System.assert(result.get('methodOptions') != null);
        }
    }

    @IsTest
    static void testFetchCalculationsBehavior() {
        String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Account_Payable__c accountPayable = testData.payables[0];
            GL_Account__c newAccGL = testData.glAccounts[12];
            Map<String, Object> result = AmortizationHelper.fetchCalculations(new Map<String, Object>{
                    'sourceDocumentId' => accountPayable.Id,
                    'selectedMethod' => 'Straight Line - Daily',
                    'startDate' => Datetime.newInstance(accountPayable.Date__c.addDays(2), Time.newInstance(0, 0, 0, 0)).format('yyyy-MM-dd'),
                    'endDate' => Datetime.newInstance(accountPayable.Due_Date__c.addDays(5), Time.newInstance(0, 0, 0, 0)).format('yyyy-MM-dd'),
                    PACKAGE_QUALIFIER + 'Amount__c' => '13400',
                    PACKAGE_QUALIFIER + 'Debit_GL_Account__c' => newAccGL.Id,
                    PACKAGE_QUALIFIER + 'Credit_GL_Account__c' => newAccGL.Id,
                    'accrualCash' => LedgerActions.ACCOUNTING_METHOD_ACCRUAL
            });
            Test.stopTest();

            System.assert((Boolean)result.get('isSuccess'));
            System.assert(result.get('rows') != null);
        }
    }

    @IsTest
    static void testAccountingPeriodsIsValidNoStartDatePeriod() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            AmortizationHelper.AccountingPeriodsWrapper aw = new AmortizationHelper.AccountingPeriodsWrapper();
            aw.startDate = testData.acctPeriods[0].Start_Date__c.addDays(-15);
            AmortizationHelper.AccountingPeriodsWrapper res = AmortizationHelper.isAccountingPeriodsValid(JSON.serialize(aw));

            System.assert(res.isError);
        }
    }

    @IsTest
    static void testAccountingPeriodsIsValidNoNumberPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            AmortizationHelper.AccountingPeriodsWrapper aw = new AmortizationHelper.AccountingPeriodsWrapper();
            aw.startDate = testData.acctPeriods[0].Start_Date__c;
            aw.periodNumber = 100;
            AmortizationHelper.AccountingPeriodsWrapper res = AmortizationHelper.isAccountingPeriodsValid(JSON.serialize(aw));

            System.assert(res.isError);
        }
    }

    @IsTest
    static void testAccountingPeriodsIsValidNoEndDatePeriod() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            AmortizationHelper.AccountingPeriodsWrapper aw = new AmortizationHelper.AccountingPeriodsWrapper();
            aw.startDate = testData.acctPeriods[0].Start_Date__c;
            aw.endDate = testData.acctPeriods[testData.acctPeriods.size() - 1].End_Date__c.addDays(20);
            AmortizationHelper.AccountingPeriodsWrapper res = AmortizationHelper.isAccountingPeriodsValid(JSON.serialize(aw));

            System.assert(res.isError);
        }
    }

    @IsTest
    static void testAccountingPeriodsIsValidNumberPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            AmortizationHelper.AccountingPeriodsWrapper aw = new AmortizationHelper.AccountingPeriodsWrapper();
            aw.startDate = testData.acctPeriods[0].Start_Date__c.addDays(3);
            aw.periodNumber = 1;
            AmortizationHelper.AccountingPeriodsWrapper res = AmortizationHelper.isAccountingPeriodsValid(JSON.serialize(aw));

            System.assert(!res.isError);
            System.assertEquals(testData.acctPeriods[0].Start_Date__c.addDays(3), res.endDate);
        }
    }

    @IsTest
    static void testAccountingPeriodsIsValidEndDatePeriod() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            AmortizationHelper.AccountingPeriodsWrapper aw = new AmortizationHelper.AccountingPeriodsWrapper();
            aw.startDate = testData.acctPeriods[0].Start_Date__c.addDays(3);
            aw.endDate = testData.acctPeriods[1].Start_Date__c.addDays(3);
            AmortizationHelper.AccountingPeriodsWrapper res = AmortizationHelper.isAccountingPeriodsValid(JSON.serialize(aw));

            System.assert(!res.isError);
            System.assertEquals(2, res.periodNumber);
        }
    }

    @IsTest
    static void testGetAccountingInfoFromBillingLines() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings().createAccountingVariables();
        System.runAs(testData.users.get(1)) {
            testData.billingLines[0].GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            testData.billingLines[1].GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            update testData.billingLines;
            testData.accounts[0].GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            update testData.accounts[0];
            AmortizationHelper.AccountingInfoWrapper res = AmortizationHelper.getAccountingInfo(testData.billings[0].Id);

            System.assertEquals(testData.accountingVariables1[0].Id, res.glVariable1);
            System.assertEquals(testData.accountingVariables2[0].Id, res.glVariable2);
            System.assertEquals(testData.accountingVariables3[0].Id, res.glVariable3);
        }
    }

    @IsTest
    static void testGetAccountingInfoFromPayableLines() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().createAccountingVariables();
        System.runAs(testData.users.get(1)) {
            testData.payableLines[0].GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            testData.payableLines[1].GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            update testData.payableLines;
            testData.accounts[0].GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            update testData.accounts[0];
            AmortizationHelper.AccountingInfoWrapper res = AmortizationHelper.getAccountingInfo(testData.payables[0].Id);

            System.assertEquals(testData.accountingVariables1[0].Id, res.glVariable1);
            System.assertEquals(testData.accountingVariables2[0].Id, res.glVariable2);
            System.assertEquals(testData.accountingVariables3[0].Id, res.glVariable3);
        }
    }

    @IsTest
    static void testGetGLAccountFromPayable() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
        System.runAs(testData.users.get(1)) {
            testData.accounts[0].Default_Expense_GL_Account__c = testData.glAccounts[0].Id;
            update testData.accounts[0];
            AmortizationHelper.AccountingInfoWrapper res = AmortizationHelper.getAccountingInfo(testData.payables[0].Id);
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            System.assertEquals(defaultsBySpecDevNames.get(GLAccountDefaultsHandler.DEFAULT_CREDIT_GL_ACCOUNT_EXPENSE)?.GL_Account__c, res.creditGlAccount);
            System.assertEquals(testData.glAccounts[0].Id, res.debitGlAccount);
        }
    }

    @IsTest
    static void testGetGLAccountFromPayableWithNonAccountPayee() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
        System.runAs(testData.users.get(1)) {
            testData.accounts[0].Default_Expense_GL_Account__c = testData.glAccounts[0].Id;
            update testData.accounts[0];
            testData.payables[0].Vendor__c = null;
            testData.payables[0].Contact__c = testData.contacts[0].Id;
            update testData.payables[0];

            AmortizationHelper.AccountingInfoWrapper res = AmortizationHelper.getAccountingInfo(testData.payables[0].Id);
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            System.assertEquals(defaultsBySpecDevNames.get(GLAccountDefaultsHandler.DEFAULT_CREDIT_GL_ACCOUNT_EXPENSE)?.GL_Account__c, res.creditGlAccount);
            System.assertEquals(null, res.debitGlAccount);
        }
    }

    @IsTest
    static void testGetGLAccountFromBilling() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        System.runAs(testData.users.get(1)) {
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            AmortizationHelper.AccountingInfoWrapper res = AmortizationHelper.getAccountingInfo(testData.billings[0].Id);

            System.assertEquals(defaultsBySpecDevNames.get(GLAccountDefaultsHandler.DEFAULT_CREDIT_GL_ACCOUNT_REVENUE)?.GL_Account__c, res.creditGlAccount);
            System.assertEquals(defaultsBySpecDevNames.get(GLAccountDefaultsHandler.DEFAULT_DEBIT_GL_ACCOUNT_REVENUE)?.GL_Account__c, res.debitGlAccount);
        }
    }

    @IsTest
    static void testCreateEntriesBehaviorPlatformUser() {
        String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
        System.runAs(testData.users.get(0)) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard Platform User'];
            User testPlatformUser = new User(
                Alias = 'pltfUsr',
                Email = 'platformuser@testorg.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'Testing',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = p.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = 'platformUser.recbill@testorg.com'
            );
            insert testPlatformUser;

            TestDataSuite.assignAdminPermissionSet(testPlatformUser.Id);

            System.runAs(testPlatformUser) {
                System.assert([SELECT Id FROM Scheduled_Revenue_Expense__c].isEmpty());
                Test.startTest();
                Account_Payable__c accountPayable = testData.payables[0];
                GL_Account__c newAccGL = testData.glAccounts[12];
                Map<String, Object> result = AmortizationHelper.createEntries(new Map<String, Object>{
                    'sourceDocumentId' => accountPayable.Id,
                    'selectedMethod' => 'Straight Line - Daily',
                    'startDate' => Datetime.newInstance(accountPayable.Date__c.addDays(2), Time.newInstance(0, 0, 0, 0)).format('yyyy-MM-dd'),
                    'endDate' => Datetime.newInstance(accountPayable.Due_Date__c.addDays(5), Time.newInstance(0, 0, 0, 0)).format('yyyy-MM-dd'),
                    PACKAGE_QUALIFIER + 'Amount__c' => '13400',
                    PACKAGE_QUALIFIER + 'Debit_GL_Account__c' => newAccGL.Id,
                    PACKAGE_QUALIFIER + 'Credit_GL_Account__c' => newAccGL.Id,
                    'accrualCash' => LedgerActions.ACCOUNTING_METHOD_ACCRUAL
                });
                Test.stopTest();

                System.assert((Boolean)result.get('isSuccess'));
                System.assert(![SELECT Id FROM Scheduled_Revenue_Expense__c].isEmpty());
            }
        }
    }

    @IsTest
    static void testGetAccountingInfoLineTotalFromPayableLines() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().createAccountingVariables();
        System.runAs(testData.users.get(1)) {
            Map<String, GL_Account_Default__c> glAccounts = GLAccount.glAccountDefaultsMapByLedgerId(testData.payables[0].Ledger__c);
            List<Account_Payable_Line__c> payableLines = [Select id, Sub_Total__c, Expense_GL_Account__c from Account_Payable_Line__c Where Account_Payable__c=:testData.payableLines[0].Account_Payable__c];
            payableLines[0].Expense_GL_Account__c = glAccounts.get(GLAccountDefaultsHandler.DEFAULT_CREDIT_GL_ACCOUNT_EXPENSE).GL_account__c;
            payableLines[1].Expense_GL_Account__c = glAccounts.get(GLAccountDefaultsHandler.DEFAULT_CREDIT_GL_ACCOUNT_EXPENSE).GL_account__c;
            payableLines[2].Expense_GL_Account__c = glAccounts.get(GLAccountDefaultsHandler.DEFAULT_CREDIT_GL_ACCOUNT_EXPENSE).GL_account__c;
            update payableLines;
            AmortizationHelper.AccountingInfoWrapper res = AmortizationHelper.getAccountingInfo(testData.payables[0].Id);

            Assert.areEqual(payableLines[0].Sub_Total__c + payableLines[1].Sub_Total__c + payableLines[2].Sub_Total__c, res.lineSubTotal);
        }
    }

    @IsTest
    static void testGetAccountingInfoLineTotalFromBillingLines() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings().createAccountingVariables();
        System.runAs(testData.users.get(1)) {
            Map<String, GL_Account_Default__c> glAccounts = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers[0].Id);
            List<Billing_Line__c> billingLines = [Select id, Sub_Total__c, Revenue_GL_Account__c from Billing_Line__c Where Billing__c=:testData.billingLines[0].Billing__c];
            billingLines[0].Revenue_GL_Account__c = glAccounts.get(GLAccountDefaultsHandler.DEFAULT_DEBIT_GL_ACCOUNT_REVENUE).GL_account__c;
            billingLines[1].Revenue_GL_Account__c = glAccounts.get(GLAccountDefaultsHandler.DEFAULT_DEBIT_GL_ACCOUNT_REVENUE).GL_account__c;
            update billingLines;

            AmortizationHelper.AccountingInfoWrapper res = AmortizationHelper.getAccountingInfo(testData.billings[0].Id);

            Assert.areEqual(billingLines[0].Sub_Total__c + billingLines[1].Sub_Total__c, res.lineSubTotal);
        }
    }

    @IsTest
    static void testCreateFAEntriesBehavior() {
        String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
        TestDataSuite testData = TestDataSuite.getInstance().createFixedAssets();

        System.runAs(testData.users.get(1)) {
            System.assert([SELECT Id FROM Scheduled_Revenue_Expense__c].isEmpty());
            Test.startTest();
            Fixed_Asset__c fixedAsset = testData.fixedAssets[0];
            GL_Account__c newAccGL = testData.glAccounts[12];
            Map<String, Object> result = AmortizationHelper.createEntries(new Map<String, Object>{
                'sourceDocumentId' => fixedAsset.Id,
                'selectedMethod' => 'Straight Line - Daily',
                'startDate' => Datetime.newInstance(testData.acctPeriods[0].Start_Date__c.addDays(2), Time.newInstance(0, 0, 0, 0)).format('yyyy-MM-dd'),
                'endDate' => Datetime.newInstance(testData.acctPeriods[0].Start_Date__c.addDays(5), Time.newInstance(0, 0, 0, 0)).format('yyyy-MM-dd'),
                PACKAGE_QUALIFIER + 'Amount__c' => '13400',
                PACKAGE_QUALIFIER + 'Debit_GL_Account__c' => newAccGL.Id,
                PACKAGE_QUALIFIER + 'Credit_GL_Account__c' => newAccGL.Id,
                'accrualCash' => LedgerActions.ACCOUNTING_METHOD_ACCRUAL
            });
            Test.stopTest();
            List<Scheduled_Revenue_Expense__c> sre = [SELECT Id, Fixed_Asset__c FROM Scheduled_Revenue_Expense__c];

            System.assert((Boolean)result.get('isSuccess'));
            System.assert(!sre.isEmpty());
            System.assertEquals(fixedAsset.Id, sre[0].Fixed_Asset__c);
        }
    }
}