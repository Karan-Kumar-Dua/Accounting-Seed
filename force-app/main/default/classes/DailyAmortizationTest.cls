@IsTest
private class DailyAmortizationTest {

    public static final Decimal DEFAULT_AMOUNT = 5000;

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    public static void testCheckCreateItemScheduledRevenueExpense() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Account_Payable__c accountPayable = testData.payables[0];
            GL_Account__c newAccGL = testData.glAccounts[12];

            Test.startTest();
            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = accountPayable.Id;
            option.startDate = accountPayable.Date__c.addDays(2);
            option.endDate = accountPayable.Due_Date__c.addDays(5);
            option.amount = DEFAULT_AMOUNT;
            option.creditGlAccount = newAccGL.Id;
            option.debitGlAccount = newAccGL.Id;
            option.amortizationMethod = 'Straight Line - Daily';

            Amortization amor = new Amortization();
            AmortizationResult res = amor.amortize(option);
            List<Scheduled_Revenue_Expense__c> result = res.amortizationEntries;

            Decimal dailyExpense = DEFAULT_AMOUNT / (accountPayable.Date__c.addDays(2).daysBetween(accountPayable.Due_Date__c.addDays(5)) + 1);
            Decimal firstAmount = dailyExpense * (accountPayable.Date__c.addDays(2).daysBetween(testData.acctPeriods[0].End_Date__c) + 1);
            Decimal secondAmount = dailyExpense * (testData.acctPeriods[1].Start_Date__c.daysBetween(accountPayable.Due_Date__c.addDays(5)) + 1);

            System.assert(res.isSuccess);
            System.assertEquals(firstAmount.setScale(2, System.RoundingMode.HALF_UP), result[0].Amount__c);
            System.assertEquals(secondAmount.setScale(2, System.RoundingMode.HALF_UP), result[1].Amount__c);
        }

    }

    @isTest
    public static void testScheduledRevenueExpenseForForeignAP () {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createPayables();

            System.runAs(testData.users.get(1)) {

                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Account_Payable__c accountPayable = testData.payables[1];
                accountPayable.put('CurrencyIsoCode', newCurrencyIsoCode);
                accountPayable.Currency_Conversion_Rate__c = 1.2;

                TriggerObserver.getInstance().unlockFields(
                    new Set<SObjectField>{Schema.SObjectType.Account_Payable__c.fields.getMap().get('CurrencyIsoCode')}
                );
                update accountPayable;
                accountPayable = [
                    SELECT Id, Ledger_Amount__c, Date__c, Due_Date__c, Total__c
                    FROM Account_Payable__c
                    WHERE Id = :accountPayable.Id LIMIT 1
                ];

                GL_Account__c newAccGL = testData.glAccounts[12];

                AmortizationOptions option = new AmortizationOptions();
                option.sourceDocument = accountPayable.Id;
                option.startDate = accountPayable.Date__c;
                option.endDate = accountPayable.Due_Date__c;
                option.creditGlAccount = newAccGL.Id;
                option.debitGlAccount = newAccGL.Id;
                option.amortizationMethod = 'Straight Line - Daily';

                Amortization amor = new Amortization();
                AmortizationResult res = amor.amortize(option);
                System.assert(res.isSuccess);

                List<Scheduled_Revenue_Expense__c> result = res.amortizationEntries;

                System.assertEquals(accountPayable.Ledger_Amount__c, result[0].Amount__c);
            }
        }
        catch (Exception ex) {

        }

    }

    @isTest
    public static void testLedgerBySourceAccountPayable () {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Account_Payable__c accountPayable = testData.payables[0];
            GL_Account__c newAccGL = testData.glAccounts[12];
            accountPayable.Ledger__c = testData.ledgers[2].Id;
            update accountPayable;

            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = accountPayable.Id;
            option.startDate = accountPayable.Date__c.addDays(2);
            option.endDate = accountPayable.Due_Date__c.addDays(5);
            option.amount = DEFAULT_AMOUNT;
            option.creditGlAccount = newAccGL.Id;
            option.debitGlAccount = newAccGL.Id;
            option.amortizationMethod = 'Straight Line - Daily';

            Amortization amor = new Amortization();
            AmortizationResult res = amor.amortize(option);
            System.assert(res.isSuccess);

            List<Scheduled_Revenue_Expense__c> result = res.amortizationEntries;

            for (Scheduled_Revenue_Expense__c revenueExpense: result) {

                System.assertEquals(testData.ledgers[2].Id, revenueExpense.Ledger__c);
            }

        }

    }

    @isTest
    public static void testLedgerBySourceBilling() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.billings[0].Billing_Cycle_Start_Date__c = testData.acctPeriods[2].Start_Date__c;
            testData.billings[0].Billing_Cycle_End_Date__c = testData.acctPeriods[3].End_Date__c;
            testData.billings[0].Ledger__c = testData.ledgers[2].Id;
            update testData.billings[0];

            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = testData.billings[0].Id;
            option.startDate = testData.billings[0].Billing_Cycle_Start_Date__c;
            option.endDate = testData.billings[0].Billing_Cycle_End_Date__c;
            option.amount = DEFAULT_AMOUNT;
            option.creditGlAccount = testData.glAccounts[0].Id;
            option.debitGlAccount = testData.glAccounts[0].Id;
            option.amortizationMethod = 'Straight Line - Daily';

            Amortization amor = new Amortization();
            AmortizationResult res = amor.amortize(option);
            System.assert(res.isSuccess);

            List<Scheduled_Revenue_Expense__c> result = res.amortizationEntries;

            for (Scheduled_Revenue_Expense__c revenueExpense: result) {

                System.assertEquals(testData.ledgers[2].Id, revenueExpense.Ledger__c);
            }
        }

    }

    @isTest
    public static void testDefaultReveneueExpenesevalueFromOption() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Billing__c testBilling = testData.billings[0];
            testBilling.Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c;

            update testBilling;

            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = testData.billings[0].Id;
            option.startDate = testData.billings[0].Billing_Cycle_Start_Date__c;
            option.endDate = testData.billings[0].Billing_Cycle_End_Date__c;
            option.amount = DEFAULT_AMOUNT;
            option.creditGlAccount = testData.glAccounts[12].Id;
            option.debitGlAccount = testData.glAccounts[12].Id;
            option.description = 'test description';
            option.amortizationMethod = 'Straight Line - Daily';

            //default amortizeDefaultRevenuePrepaidExpense value that inherits from Accounting_Settings__c
            Assert.areEqual(option.amortizeDefaultRevenuePrepaidExpense, testData.settings.Amortize_Default_Revenue_Prepaid_Expense__c);

            Amortization amor = new Amortization();
            AmortizationResult res = amor.amortize(option);
            Assert.isTrue(res.isSuccess);

            List<Scheduled_Revenue_Expense__c> result = res.amortizationEntries;

            Assert.areEqual('test description', result[0].Description__c);
        }

    }

    @isTest
    public static void testScheduledRevenueExpensesFromBillingSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Billing__c testBilling = testData.billings[0];
            testBilling.Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c;

            update testBilling;

            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = testData.billings[0].Id;
            option.startDate = testData.billings[0].Billing_Cycle_Start_Date__c;
            option.endDate = testData.billings[0].Billing_Cycle_End_Date__c;
            option.amount = DEFAULT_AMOUNT;
            option.creditGlAccount = testData.glAccounts[12].Id;
            option.debitGlAccount = testData.glAccounts[12].Id;
            option.description = 'test description';
            option.amortizationMethod = 'Straight Line - Daily';

            Amortization amor = new Amortization();
            AmortizationResult res = amor.amortize(option);
            System.assert(res.isSuccess);

            List<Scheduled_Revenue_Expense__c> result = res.amortizationEntries;

            System.assertEquals('test description', result[0].Description__c);
        }

    }

    @isTest
    public static void testScheduledRevenueExpensesFromForeignBilling() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createBillings();

            System.runAs(testData.users.get(1)) {

                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }
                Billing__c testBilling = testData.billings[0];
                testBilling.Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c;
                testBilling.put('CurrencyIsoCode', newCurrencyIsoCode);
                testBilling.Currency_Conversion_Rate__c = 1.2;

                TriggerObserver.getInstance().unlockFields(
                    new Set<SObjectField>{Schema.SObjectType.Billing__c.fields.getMap().get('CurrencyIsoCode')}
                );
                update testBilling;
                TriggerObserver.reset();

                testBilling = [SELECT Id, Ledger_Amount__c, Date__c, Due_Date2__c FROM Billing__c WHERE Id = :testBilling.Id];

                AmortizationOptions option = new AmortizationOptions();
                option.sourceDocument = testData.billings[0].Id;
                option.startDate = testData.billings[0].Billing_Cycle_Start_Date__c;
                option.endDate = testData.billings[0].Billing_Cycle_End_Date__c;
                option.creditGlAccount = testData.glAccounts[12].Id;
                option.debitGlAccount = testData.glAccounts[12].Id;
                option.amortizationMethod = 'Straight Line - Daily';

                Amortization amor = new Amortization();
                AmortizationResult res = amor.amortize(option);
                System.assert(res.isSuccess);

                List<Scheduled_Revenue_Expense__c> result = res.amortizationEntries;

                System.assertEquals(testBilling.Ledger_Amount__c, result[0].Amount__c);
            }
        }
        catch (Exception ex) {

        }

    }

    @isTest
    public static void testSetTransactionDataValue() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Billing__c testBilling = testData.billings[0];
            testBilling.Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c;
            update testBilling;

            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = testData.billings[0].Id;
            option.startDate = testData.billings[0].Billing_Cycle_Start_Date__c;
            option.endDate = testData.billings[0].Billing_Cycle_End_Date__c;
            option.amount = DEFAULT_AMOUNT;
            option.creditGlAccount = testData.glAccounts[12].Id;
            option.debitGlAccount = testData.glAccounts[12].Id;
            option.description = 'test description';
            option.amortizationMethod = 'Straight Line - Daily';

            Amortization amor = new Amortization();
            AmortizationResult res = amor.amortize(option);
            System.assert(res.isSuccess);

            List<Scheduled_Revenue_Expense__c> result = res.amortizationEntries;

            System.assertEquals(testData.billings[0].Billing_Cycle_Start_Date__c, result[0].Transaction_Date__c);
        }

    }

    @isTest
    public static void testCreateDailySRERoundingCorrection() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Decimal amount = 54998.77;
            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = testData.payables[0].Id;
            option.startDate = testData.acctPeriods[0].Start_Date__c;
            option.endDate = testData.acctPeriods[4].End_Date__c;
            option.amount = amount;
            option.creditGlAccount = testData.glAccounts[12].Id;
            option.debitGlAccount = testData.glAccounts[12].Id;
            option.amortizationMethod = 'Straight Line - Daily';

            Amortization amor = new Amortization();
            AmortizationResult res = amor.amortize(option);
            System.assert(res.isSuccess);

            Decimal resultTotal = 0;
            for (Scheduled_Revenue_Expense__c sre : res.amortizationEntries) {
                resultTotal += sre.Amount__c;
            }

            System.assertEquals(amount, resultTotal);
        }
    }

    @isTest
    public static void testCreateDailySREFromListOptionsWithDiffDates() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Billing__c testBilling = testData.billings[0];
            testBilling.Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c;

            update testBilling;
            List<AmortizationOptions> amOptions = new List<AmortizationOptions>();

            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = testData.billings[0].Id;
            option.startDate = testData.billings[0].Billing_Cycle_Start_Date__c;
            option.endDate = testData.billings[0].Billing_Cycle_End_Date__c;
            option.amount = DEFAULT_AMOUNT;
            option.creditGlAccount = testData.glAccounts[12].Id;
            option.debitGlAccount = testData.glAccounts[12].Id;
            option.description = 'test description';
            option.amortizationMethod = 'Straight Line - Daily';

            amOptions.add(option);

            AmortizationOptions option2 = new AmortizationOptions();
            option2.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option2.sourceDocument = testData.billings[0].Id;
            option2.startDate = testData.billings[0].Billing_Cycle_Start_Date__c;
            option2.endDate = testData.billings[0].Billing_Cycle_End_Date__c.addDays(90) ;
            option2.amount = DEFAULT_AMOUNT;
            option2.creditGlAccount = testData.glAccounts[12].Id;
            option2.debitGlAccount = testData.glAccounts[12].Id;
            option2.description = 'test description';
            option2.amortizationMethod = 'Straight Line - Daily';

            amOptions.add(option2);
           
            Amortization amor = new Amortization();
            List<AmortizationResult> amorResults = amor.amortize(amOptions);
     
            System.assert(amorResults[0].isSuccess);
            System.assertEquals(1, amorResults[0].amortizationEntries.size());
            
            System.assert(amorResults[1].isSuccess);
            System.assertEquals(4, amorResults[1].amortizationEntries.size());

        }

    }

    @IsTest
    private static void testAmortizePayablesForSoftCosePeriods() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods[0];
            testAccountingPeriod.Close_AP__c = true;
            update testAccountingPeriod;

            AmortizationOptions opts = new AmortizationOptions();
            opts.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            opts.sourceDocument = testData.payables[0].Id;
            opts.startDate = testAccountingPeriod.Start_Date__c;
            opts.endDate = testAccountingPeriod.Start_Date__c.addDays(5);
            opts.amortizationMethod = 'Straight Line - Daily';
            Amortization a = new Amortization();
            AmortizationResult ar = a.amortize(opts);
            Test.stopTest();

            Assert.isTrue(ar.isSuccess);
        }
    }

    @IsTest
    private static void testAmortizeBillingsForSoftCosePeriods() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods[0];
            testAccountingPeriod.Close_AR__c = true;
            update testAccountingPeriod;

            Billing__c testBilling = testData.billings[0];
            testBilling.Billing_Cycle_End_Date__c = testAccountingPeriod.End_Date__c;

            update testBilling;

            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = testBilling.Id;
            option.startDate = testAccountingPeriod.Start_Date__c;
            option.endDate = testAccountingPeriod.Start_Date__c.addDays(35);
            option.amortizationMethod = 'Straight Line - Daily';
            Amortization a = new Amortization();
            AmortizationResult ar = a.amortize(option);
            Test.stopTest();

            Assert.isTrue(ar.isSuccess);
        }
    }
    @IsTest
    private static void testCheckDefaultAmountForBilling() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings().createTaxGroups();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Billing__c testBilling = testData.billings[0];

            Billing_Line__c billingLine = new Billing_Line__c(
                    Billing__c = testBilling.Id,
                    Date__c = testBilling.Billing_Cycle_Start_Date__c,
                    Hours_Units__c = 10,
                    Rate__c = 10,
                    Tax_Group__c = testData.taxGroups[0].Id,
                    Revenue_GL_Account__c = testData.glAccounts[10].Id
                );

            insert billingLine;

            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = testBilling.Id;
            option.startDate = testBilling.Billing_Cycle_Start_Date__c;
            option.endDate = testBilling.Billing_Cycle_End_Date__c-3;
            option.amortizationMethod = 'Straight Line - Daily';
            option.amortizeDefaultRevenuePrepaidExpense = false;
            Amortization a = new Amortization();
            AmortizationResult ar = a.amortize(option);

            Billing__c billing = [Select Id, Sub_Total__c,Total__c from Billing__c where Id= :testData.billings[0].Id][0];

            Test.stopTest();

            Assert.isTrue(ar.isSuccess);
            Assert.areEqual(billing.Total__c,560,'Billing Total is not matching');
            Assert.areEqual(billing.Sub_Total__c,550,'Billing Sub-Total is not matching');
            Assert.areEqual(ar.amortizationEntries.size(),1,'Amortization entries are not matching');
            for(Scheduled_Revenue_Expense__c arEntries : ar.amortizationEntries) {
                Assert.areEqual(billing.Sub_Total__c, arEntries.Amount__c, 'Amortization amount does not matches the default(subtotal)');
            }
        }
    }

    @IsTest
    private static void testCheckDefaultAmountForPayables() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().createTaxGroups();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Account_Payable__c testPayables = testData.payables[0];

            Account_Payable_Line__c payableLine = new Account_Payable_Line__c(
                    Account_Payable__c = testPayables.Id,
                    Quantity__c = 50,
                    Unit_Cost__c = 2,
                    Tax_Group__c = testData.taxGroups[1].Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = testData.glAccounts[16].Id
                );

            insert payableLine;

            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = testPayables.Id;
            option.startDate = testData.acctPeriods[0].Start_Date__c;
            option.endDate = testData.acctPeriods[0].End_Date__c;
            option.amortizationMethod = 'Straight Line - Daily';
            option.amortizeDefaultRevenuePrepaidExpense = false;
            Amortization a = new Amortization();
            AmortizationResult ar = a.amortize(option);

            Account_Payable__c payable = [Select Id, Sub_Total__c,Total__c from Account_Payable__c where Id= :testPayables.Id][0];

            Test.stopTest();

            Assert.isTrue(ar.isSuccess);
            Assert.areEqual(payable.Total__c,270,'Payable Total is not matching');
            Assert.areEqual(payable.Sub_Total__c,265,'Payable Sub-Total is not matching');
            Assert.areEqual(ar.amortizationEntries.size(),1,'Amortization entries are not matching');
            for(Scheduled_Revenue_Expense__c arEntries : ar.amortizationEntries) {
                Assert.areEqual(payable.Sub_Total__c, arEntries.Amount__c, 'Amortization amount does not matches the default(subtotal)');
            }
        }
    }
}