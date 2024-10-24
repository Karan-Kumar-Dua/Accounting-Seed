@IsTest
private class MonthlyAmortizationTest {

    public static final Decimal DEFAULT_AMOUNT = 5000;

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testCreateMonthlySREFromSingleOption() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
        Accounting_Period__c startPeriod = AccountingPeriodHandler.getInstance().getFirstOpenedPeriod();
        Accounting_Period__c endPeriod = AccountingPeriodHandler.getInstance().getNextAccountingPeriod(startPeriod.Id);
        List<Accounting_Period__c> acctPeriods = AccountingPeriodHandler.getInstance().getAccountingPeriodsByDateRangeAndStatus(
            startPeriod.Start_Date__c, endPeriod.End_Date__c, AccountingPeriodActions.OPEN_STATUS
        );
        Decimal monthlyExpense = DEFAULT_AMOUNT / acctPeriods.size();

        System.runAs(testData.users.get(1)) {
            Account_Payable__c accountPayable = [
                SELECT Id, Date__c, Due_Date__c, Total__c
                FROM Account_Payable__c
                WHERE Id = :testData.payables[0].Id
            ];

            GL_Account__c newAccGL = testData.glAccounts[12];

            Test.startTest();
            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = accountPayable.Id;
            option.startDate = startPeriod.Start_Date__c;
            option.endDate = null;
            option.numberOfPeriods = 2;
            option.amount = DEFAULT_AMOUNT;
            option.creditGlAccount = newAccGL.Id;
            option.debitGlAccount = newAccGL.Id;
            option.amortizationMethod = 'Straight Line - Full Month';

            Amortization amor = new Amortization();
            AmortizationResult res = amor.amortize(option);
            System.assert(res.isSuccess);

            List<Scheduled_Revenue_Expense__c> result = res.amortizationEntries;
            System.assertEquals(monthlyExpense.setScale(2, System.RoundingMode.HALF_UP), result[0].Amount__c);
            System.assertEquals(monthlyExpense.setScale(2, System.RoundingMode.HALF_UP), result[1].Amount__c);
        }
    }

    @IsTest
    public static void testCreateMonthlySREFromListOptions() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createPayables(false);

        Test.startTest();

        testData.createBillings(false);
        Accounting_Period__c startPeriod = AccountingPeriodHandler.getInstance().getFirstOpenedPeriod();

        System.runAs(testData.users.get(1)) {
            Account_Payable__c testPayable = [
                SELECT Id, Date__c, Due_Date__c, Total__c
                FROM Account_Payable__c
                WHERE Id = :testData.payables[0].Id
            ];

            Billing__c testBilling = [
                SELECT Id, Billing_Cycle_Start_Date__c, Billing_Cycle_End_Date__c, Total__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];

            testBilling.Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c;
            update testBilling;

            GL_Account__c newAccGL = testData.glAccounts[12];

            List<AmortizationOptions> amOptions = new List<AmortizationOptions>();

            AmortizationOptions optionBilling = new AmortizationOptions();
            optionBilling.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            optionBilling.sourceDocument = testBilling.Id;
            optionBilling.startDate = startPeriod.Start_Date__c;
            optionBilling.endDate = null;
            optionBilling.numberOfPeriods = 2;
            optionBilling.amount = testBilling.Total__c;
            optionBilling.creditGlAccount = newAccGL.Id;
            optionBilling.debitGlAccount = newAccGL.Id;
            optionBilling.amortizationMethod = 'Straight Line - Full Month';

            amOptions.add(optionBilling);

            AmortizationOptions optionPayable = new AmortizationOptions();
            optionPayable.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            optionPayable.sourceDocument = testPayable.Id;
            optionPayable.startDate = startPeriod.Start_Date__c;
            optionPayable.endDate = null;
            optionPayable.numberOfPeriods = 6;
            optionPayable.amount = testPayable.Total__c;
            optionPayable.creditGlAccount = newAccGL.Id;
            optionPayable.debitGlAccount = newAccGL.Id;
            optionPayable.amortizationMethod = 'Straight Line - Full Month';

            amOptions.add(optionPayable);

            Amortization amor = new Amortization();
            List<AmortizationResult> res = amor.amortize(amOptions);

            System.assert(res[0].isSuccess);
            System.assert(res[1].isSuccess);

            List<Scheduled_Revenue_Expense__c> result0 = res[0].amortizationEntries;
            Decimal monthlyExpenseBilling = testBilling.Total__c / optionBilling.numberOfPeriods;
            System.assertEquals(monthlyExpenseBilling.setScale(2, System.RoundingMode.HALF_UP), result0[0].Amount__c);
            System.assertEquals(monthlyExpenseBilling.setScale(2, System.RoundingMode.HALF_UP), result0[1].Amount__c);

            List<Scheduled_Revenue_Expense__c> result1 = res[1].amortizationEntries;
            Decimal monthlyExpensePayable = testPayable.Total__c / optionPayable.numberOfPeriods;
            System.assertEquals(monthlyExpensePayable.setScale(2, System.RoundingMode.HALF_UP), result1[0].Amount__c);
            System.assertEquals(monthlyExpensePayable.setScale(2, System.RoundingMode.HALF_UP), result1[1].Amount__c);
            System.assertEquals(monthlyExpensePayable.setScale(2, System.RoundingMode.HALF_UP), result1[2].Amount__c);
            System.assertEquals(monthlyExpensePayable.setScale(2, System.RoundingMode.HALF_UP), result1[3].Amount__c);
            System.assertEquals(monthlyExpensePayable.setScale(2, System.RoundingMode.HALF_UP), result1[4].Amount__c);
            System.assertEquals(monthlyExpensePayable.setScale(2, System.RoundingMode.HALF_UP), result1[5].Amount__c);
        }
    }

    @IsTest
    public static void testCreateMonthlySREFromBillingTotal() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        Accounting_Period__c startPeriod = AccountingPeriodHandler.getInstance().getFirstOpenedPeriod();
        Accounting_Period__c endPeriod = AccountingPeriodHandler.getInstance().getNextAccountingPeriod(startPeriod.Id);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Billing__c testBilling = [
                SELECT Id, Total__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];

            testBilling.Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c;
            update testBilling;

            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = testData.billings[0].Id;
            option.startDate = startPeriod.Start_Date__c;
            option.endDate = null;
            option.numberOfPeriods = 2;
            option.amount = testBilling.Total__c;
            option.creditGlAccount = testData.glAccounts[12].Id;
            option.debitGlAccount = testData.glAccounts[12].Id;
            option.amortizationMethod = 'Straight Line - Full Month';

            Amortization amor = new Amortization();
            AmortizationResult res = amor.amortize(option);
            System.assert(res.isSuccess);

            List<Scheduled_Revenue_Expense__c> result = res.amortizationEntries;
            List<Accounting_Period__c> acctPeriods = AccountingPeriodHandler.getInstance().getAccountingPeriodsByDateRangeAndStatus(option.startDate, endPeriod.End_Date__c, AccountingPeriodActions.OPEN_STATUS);
            Decimal monthlyExpense = testBilling.Total__c / acctPeriods.size();
            System.assertEquals(monthlyExpense.setScale(2, System.RoundingMode.HALF_UP), result[0].Amount__c);
            System.assertEquals(monthlyExpense.setScale(2, System.RoundingMode.HALF_UP), result[1].Amount__c);
        }
    }

    @IsTest
    public static void testCreateMonthlySREFromPayableTotal() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        Accounting_Period__c startPeriod = AccountingPeriodHandler.getInstance().getFirstOpenedPeriod();
        Accounting_Period__c endPeriod = AccountingPeriodHandler.getInstance().getNextAccountingPeriod(startPeriod.Id);


        System.runAs(testData.users.get(1)) {
            Account_Payable__c accountPayable = [
                SELECT Id, Total__c
                FROM Account_Payable__c
                WHERE Id = :testData.payables[0].Id
            ];
            GL_Account__c newAccGL = testData.glAccounts[12];

            Test.startTest();
            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = accountPayable.Id;
            option.startDate = startPeriod.Start_Date__c;
            option.endDate = null;
            option.numberOfPeriods = 2;
            option.amount = accountPayable.Total__c;
            option.creditGlAccount = newAccGL.Id;
            option.debitGlAccount = newAccGL.Id;
            option.amortizationMethod = 'Straight Line - Full Month';

            Amortization amor = new Amortization();
            AmortizationResult res = amor.amortize(option);

            System.assert(res.isSuccess);
            List<Scheduled_Revenue_Expense__c> result = res.amortizationEntries;
            List<Accounting_Period__c> acctPeriods = AccountingPeriodHandler.getInstance().getAccountingPeriodsByDateRangeAndStatus(option.startDate, endPeriod.End_Date__c, AccountingPeriodActions.OPEN_STATUS);
            Decimal monthlyExpense = accountPayable.Total__c / acctPeriods.size();
            System.assertEquals(monthlyExpense.setScale(2, System.RoundingMode.HALF_UP), result[0].Amount__c);
            System.assertEquals(monthlyExpense.setScale(2, System.RoundingMode.HALF_UP), result[1].Amount__c);
        }
    }

    @IsTest
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
            option.endDate = null;
            option.numberOfPeriods = 2;
            option.amount = DEFAULT_AMOUNT;
            option.creditGlAccount = testData.glAccounts[12].Id;
            option.debitGlAccount = testData.glAccounts[12].Id;
            option.description = 'test description';
            option.amortizationMethod = 'Straight Line - Full Month';

            Amortization amor = new Amortization();
            AmortizationResult res = amor.amortize(option);
            System.assert(res.isSuccess);

            List<Scheduled_Revenue_Expense__c> result = res.amortizationEntries;

            System.assertEquals(testData.billings[0].Billing_Cycle_Start_Date__c, result[0].Transaction_Date__c);
        }

    }

    @IsTest
    public static void testCreateMonthlySRERoundingCorrection() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Decimal amount = 54998.77;
            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = testData.payables[0].Id;
            option.startDate = testData.acctPeriods[0].Start_Date__c;
            option.endDate = null;
            option.numberOfPeriods = 2;
            option.amount = amount;
            option.creditGlAccount = testData.glAccounts[12].Id;
            option.debitGlAccount = testData.glAccounts[12].Id;
            option.amortizationMethod = 'Straight Line - Full Month';

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

    @IsTest
    public static void testCreateMonthlySREFromNullNOP() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Decimal amount = 54998.77;
            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = testData.payables[0].Id;
            option.startDate = testData.acctPeriods[0].Start_Date__c;
            option.endDate = null;
            option.numberOfPeriods = null;
            option.amount = amount;
            option.creditGlAccount = testData.glAccounts[12].Id;
            option.debitGlAccount = testData.glAccounts[12].Id;
            option.amortizationMethod = 'Straight Line - Full Month';

            Amortization amor = new Amortization();
            AmortizationResult res = amor.amortize(option);
            System.assertEquals(false, res.isSuccess);
            System.assertEquals(Label.ERR_NUMBER_OF_ACCOUNTING_PERIOD_CANNOT_BE_EMPTY, res.errors[0]);
            System.assertEquals(null, res.amortizationEntries);
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
            opts.endDate = testAccountingPeriod.Start_Date__c.addDays(35);
            opts.numberOfPeriods = 2;
            opts.amortizationMethod = 'Straight Line - Full Month';
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
            option.numberOfPeriods = 2;
            option.endDate = testAccountingPeriod.Start_Date__c.addDays(35);
            option.amortizationMethod = 'Straight Line - Full Month';
            Amortization a = new Amortization();
            AmortizationResult ar = a.amortize(option);
            Test.stopTest();

            Assert.isTrue(ar.isSuccess);
        }
    }

    @IsTest
    private static void testCheckDefaultAmountForBilling() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createBillings(false);
        Test.startTest();
        testData.createTaxGroups();

        System.runAs(testData.users.get(1)) {
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
            option.endDate = testBilling.Billing_Cycle_Start_Date__c.addDays(35);
            option.numberOfPeriods = 2;
            option.amortizationMethod = 'Straight Line - Full Month';
            option.amortizeDefaultRevenuePrepaidExpense = false;
            Amortization a = new Amortization();
            AmortizationResult ar = a.amortize(option);

            Billing__c billing = [SELECT Id, Sub_Total__c, Total__c FROM Billing__c WHERE Id = :testData.billings[0].Id][0];
            Test.stopTest();

            Assert.isTrue(ar.isSuccess);
            Assert.areEqual(billing.Total__c, 560, 'Billing Total is not matching');
            Assert.areEqual(billing.Sub_Total__c, 550, 'Billing Sub-Total is not matching');
            Assert.areEqual(ar.amortizationEntries.size(), 2, 'Amortization entries are not matching');
            Decimal totalAmortizationAmount = 0;
            for (Scheduled_Revenue_Expense__c arEntries : ar.amortizationEntries) {
                totalAmortizationAmount += arEntries.Amount__c;
            }
            Assert.areEqual(billing.Sub_Total__c, totalAmortizationAmount, 'Amortization amount does not matches the default(subtotal)');
        }
    }

    @IsTest
    private static void testCheckDefaultAmountForPayables() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().createTaxGroups();
        Accounting_Period__c startPeriod = AccountingPeriodHandler.getInstance().getFirstOpenedPeriod();
        Accounting_Period__c endPeriod = AccountingPeriodHandler.getInstance().getNextAccountingPeriod(startPeriod.Id);

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
            option.endDate = testData.acctPeriods[0].End_Date__c.addDays(5);
            option.amortizationMethod = 'Straight Line - Daily';
            option.numberOfPeriods = 2;
            option.amortizeDefaultRevenuePrepaidExpense = false;
            Amortization a = new Amortization();
            AmortizationResult ar = a.amortize(option);

            Account_Payable__c payable = [Select Id, Sub_Total__c, Total__c from Account_Payable__c where Id = :testPayables.Id][0];

            Test.stopTest();

            Assert.isTrue(ar.isSuccess);
            Assert.areEqual(payable.Total__c, 270, 'Payable Total is not matching');
            Assert.areEqual(payable.Sub_Total__c, 265, 'Payable Sub-Total is not matching');
            Decimal totalAmortizationAmount = 0;
            for (Scheduled_Revenue_Expense__c arEntries : ar.amortizationEntries) {
                totalAmortizationAmount += arEntries.Amount__c;
            }
            Assert.areEqual(payable.Sub_Total__c, totalAmortizationAmount, 'Amortization amount does not matches the default(subtotal)');
        }
    }
}