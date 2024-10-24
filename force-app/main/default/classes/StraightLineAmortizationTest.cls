@IsTest
public with sharing class StraightLineAmortizationTest {
    public static final Decimal DEFAULT_AMOUNT = 6875;

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
            Integer numPeriods = 3;
            Date firstPeriodStart = testData.acctPeriods[0].Start_Date__c.addDays(17);

            Test.startTest();
            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = accountPayable.Id;
            option.startDate = firstPeriodStart;
            option.endDate = null;
            option.amount = DEFAULT_AMOUNT;
            option.numberOfPeriods = numPeriods;
            option.creditGlAccount = newAccGL.Id;
            option.debitGlAccount = newAccGL.Id;
            option.amortizationMethod = 'Straight Line - Prorated Monthly';

            StraightLineAmortization method = new StraightLineAmortization();
            AmortizationResult res = method.amortize(option, accountPayable);
            List<Scheduled_Revenue_Expense__c> result = res.amortizationEntries;
            Test.stopTest();

            Integer daysLeftFirstMonth = firstPeriodStart.daysBetween(testData.acctPeriods[0].End_Date__c) + 1;
            Decimal monthlyRate = (DEFAULT_AMOUNT/numPeriods).setScale(2, System.RoundingMode.HALF_UP);
            Decimal firstAmount = (monthlyRate * daysLeftFirstMonth/31).setScale(2, System.RoundingMode.HALF_UP);
            Decimal lastAmount = DEFAULT_AMOUNT - firstAmount - ((numPeriods - 1) * monthlyRate);

            System.assert(res.isSuccess);
            System.assertEquals(4, result.size());
            System.assertEquals(firstAmount,  result[0].Amount__c);
            System.assertEquals(monthlyRate, result[1].Amount__c);
            System.assertEquals(monthlyRate, result[2].Amount__c);
            System.assertEquals(lastAmount, result[3].Amount__c);
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
                    SELECT 
                        Id
                      , Name
                      , Ledger_Amount__c
                      , Ledger__c
                      , Date__c
                      , Due_Date__c
                      , Total__c
                      , Vendor__c
                    FROM Account_Payable__c
                    WHERE Id = :accountPayable.Id LIMIT 1
                ];

                GL_Account__c newAccGL = testData.glAccounts[12];

                AmortizationOptions option = new AmortizationOptions();
                option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
                option.sourceDocument = accountPayable.Id;
                option.startDate = accountPayable.Date__c;
                option.endDate = null;
                option.numberOfPeriods = 4;
                option.creditGlAccount = newAccGL.Id;
                option.debitGlAccount = newAccGL.Id;
                option.amortizationMethod = 'Straight Line - Prorated Monthly';

                StraightLineAmortization method = new StraightLineAmortization();
                AmortizationResult res = method.amortize(option, accountPayable);
                System.assert(res.isSuccess);

                Decimal resultTotal = 0;
                for (Scheduled_Revenue_Expense__c sre : res.amortizationEntries) {
                    resultTotal += sre.Amount__c;
                }

                System.assertEquals(accountPayable.Ledger_Amount__c, resultTotal);
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
            option.endDate = null;
            option.numberOfPeriods = 4;
            option.amount = DEFAULT_AMOUNT;
            option.creditGlAccount = newAccGL.Id;
            option.debitGlAccount = newAccGL.Id;
            option.amortizationMethod = 'Straight Line - Prorated Monthly';

            StraightLineAmortization method = new StraightLineAmortization();
            AmortizationResult res = method.amortize(option, accountPayable);
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
            option.endDate = null;
            option.numberOfPeriods = 3;
            option.amount = DEFAULT_AMOUNT;
            option.creditGlAccount = testData.glAccounts[0].Id;
            option.debitGlAccount = testData.glAccounts[0].Id;
            option.amortizationMethod = 'Straight Line - Prorated Monthly';

            StraightLineAmortization method = new StraightLineAmortization();
            AmortizationResult res = method.amortize(option, testData.billings[0]);
            System.assert(res.isSuccess);

            List<Scheduled_Revenue_Expense__c> result = res.amortizationEntries;

            for (Scheduled_Revenue_Expense__c revenueExpense: result) {
                System.assertEquals(testData.ledgers[2].Id, revenueExpense.Ledger__c);
            }
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
            option.endDate = null;
            option.numberOfPeriods = 5;
            option.amount = DEFAULT_AMOUNT;
            option.creditGlAccount = testData.glAccounts[12].Id;
            option.debitGlAccount = testData.glAccounts[12].Id;
            option.description = 'test description';
            option.amortizationMethod = 'Straight Line - Prorated Monthly';

            StraightLineAmortization method = new StraightLineAmortization();
            AmortizationResult res = method.amortize(option, testBilling);
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

                testBilling = [
                    SELECT 
                        Id
                      , Name
                      , Ledger_Amount__c
                      , Ledger__c
                      , Date__c
                      , Due_Date2__c
                      , Customer__c 
                    FROM Billing__c 
                    WHERE Id = :testBilling.Id
                ];

                AmortizationOptions option = new AmortizationOptions();
                option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
                option.sourceDocument = testData.billings[0].Id;
                option.startDate = testData.billings[0].Billing_Cycle_Start_Date__c;
                option.endDate = null;
                option.numberOfPeriods = 4;
                option.creditGlAccount = testData.glAccounts[12].Id;
                option.debitGlAccount = testData.glAccounts[12].Id;
                option.amortizationMethod = 'Straight Line - Prorated Monthly';

                StraightLineAmortization method = new StraightLineAmortization();
                AmortizationResult res = method.amortize(option, testBilling);
                System.assert(res.isSuccess);

                Decimal resultTotal = 0;
                for (Scheduled_Revenue_Expense__c sre : res.amortizationEntries) {
                    resultTotal += sre.Amount__c;
                }

                System.assertEquals(testBilling.Ledger_Amount__c, resultTotal);
            }
        }
        catch (Exception ex) {}
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
            option.endDate = null;
            option.numberOfPeriods = 4;
            option.amount = DEFAULT_AMOUNT;
            option.creditGlAccount = testData.glAccounts[12].Id;
            option.debitGlAccount = testData.glAccounts[12].Id;
            option.description = 'test description';
            option.amortizationMethod = 'Straight Line - Prorated Monthly';

            // need to mock since metadata is not available in test
            AmortizationTest.AmortizationMethodFactoryMock mockFactory 
                = new AmortizationTest.AmortizationMethodFactoryMock(new StraightLineAmortization());
            AmortizationMethodFactory methodFactory 
                = (AmortizationMethodFactory) Test.createStub(AmortizationMethodFactory.class, mockFactory);

            Amortization amor = new Amortization();
            amor.methodFactory = methodFactory;
            AmortizationResult res = amor.amortize(option);
            System.assert(res.isSuccess);

            List<Scheduled_Revenue_Expense__c> result = res.amortizationEntries;

            System.assertEquals(testData.billings[0].Billing_Cycle_Start_Date__c, result[0].Transaction_Date__c);
        }

    }

    @isTest
    public static void testCheckCreateItemSRERoundingCorrection() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Decimal amount = 54998.77;

            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = testData.payables[0].Id;
            option.startDate = testData.acctPeriods[0].Start_Date__c;
            option.endDate = null;
            option.numberOfPeriods = 5;
            option.amount = amount;
            option.creditGlAccount = testData.glAccounts[12].Id;
            option.debitGlAccount = testData.glAccounts[12].Id;
            option.amortizationMethod = 'Straight Line - Prorated Monthly';

            // need to mock since metadata is not available in test
            AmortizationTest.AmortizationMethodFactoryMock mockFactory 
                = new AmortizationTest.AmortizationMethodFactoryMock(new StraightLineAmortization());
            AmortizationMethodFactory methodFactory 
                = (AmortizationMethodFactory) Test.createStub(AmortizationMethodFactory.class, mockFactory);

            Amortization amor = new Amortization();
            amor.methodFactory = methodFactory;
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
    public static void testCreateStraightLineSREFromListOptionsWithDiffDates() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Account_Payable__c accountPayable = testData.payables[0];
            GL_Account__c newAccGL = testData.glAccounts[12];
            Integer numPeriods = 3;
            Date firstPeriodStart = testData.acctPeriods[0].Start_Date__c.addDays(17);

            Test.startTest();
            List<AmortizationOptions> amOptions = new List<AmortizationOptions>();

            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = accountPayable.Id;
            option.startDate = firstPeriodStart;
            option.endDate = null;
            option.amount = DEFAULT_AMOUNT;
            option.numberOfPeriods = numPeriods;
            option.creditGlAccount = newAccGL.Id;
            option.debitGlAccount = newAccGL.Id;
            option.amortizationMethod = 'Straight Line - Prorated Monthly';

            amOptions.add(option);

            AmortizationOptions option2 = new AmortizationOptions();
            option2.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option2.sourceDocument = accountPayable.Id;
            option2.startDate = firstPeriodStart;
            option2.endDate = null;
            option2.amount = DEFAULT_AMOUNT;
            option2.numberOfPeriods = numPeriods + 3;
            option2.creditGlAccount = newAccGL.Id;
            option2.debitGlAccount = newAccGL.Id;
            option2.amortizationMethod = 'Straight Line - Prorated Monthly';

            amOptions.add(option2);

           
            Amortization amor = new Amortization();
            List<AmortizationResult> amorResults = amor.amortize(amOptions);
            
            
            System.assert(amorResults[0].isSuccess);
            System.assertEquals(4, amorResults[0].amortizationEntries.size());

            System.assert(amorResults[1].isSuccess);
            System.assertEquals(7, amorResults[1].amortizationEntries.size());

        }

    }
    @isTest
    public static void testStraightLineAmortizationWithNullNOP() {
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
            option.amortizationMethod = 'Straight Line - Prorated Monthly';

            // need to mock since metadata is not available in test
            AmortizationTest.AmortizationMethodFactoryMock mockFactory 
                = new AmortizationTest.AmortizationMethodFactoryMock(new StraightLineAmortization());
            AmortizationMethodFactory methodFactory 
                = (AmortizationMethodFactory) Test.createStub(AmortizationMethodFactory.class, mockFactory);

            Amortization amor = new Amortization();
            amor.methodFactory = methodFactory;
            AmortizationResult res = amor.amortize(option);
            System.assertEquals(false,res.isSuccess);
            System.assertEquals(Label.ERR_NUMBER_OF_ACCOUNTING_PERIOD_CANNOT_BE_EMPTY,res.errors[0]);
            System.assertEquals(null,res.amortizationEntries);
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
            opts.amortizationMethod = 'Straight Line - Prorated Monthly';
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
            option.amortizationMethod = 'Straight Line - Prorated Monthly';
            Amortization a = new Amortization();
            AmortizationResult ar = a.amortize(option);
            Test.stopTest();

            Assert.isTrue(ar.isSuccess);
        }
    }

    @IsTest
    private static void testCheckDefaultAmountForBilling() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings().createTaxGroups();

        Accounting_Period__c startPeriod = AccountingPeriodHandler.getInstance().getFirstOpenedPeriod();
        Accounting_Period__c endPeriod = AccountingPeriodHandler.getInstance().getNextAccountingPeriod(startPeriod.Id);

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
            option.endDate = testBilling.Billing_Cycle_Start_Date__c.addDays(35);
            option.numberOfPeriods = 2;
            option.amortizationMethod = 'Straight Line - Prorated Monthly';
            option.amortizeDefaultRevenuePrepaidExpense = false;
            Amortization a = new Amortization();
            AmortizationResult ar = a.amortize(option);

            Billing__c billing = [Select Id, Sub_Total__c,Total__c from Billing__c where Id= :testData.billings[0].Id][0];

            Test.stopTest();

            Assert.isTrue(ar.isSuccess);
            Assert.areEqual(billing.Total__c,560,'Billing Total is not matching');
            Assert.areEqual(billing.Sub_Total__c,550,'Billing Sub-Total is not matching');
            Assert.areEqual(ar.amortizationEntries.size(),2,'Amortization entries are not matching');
            Decimal totalAmortizationAmount = 0;
            for(Scheduled_Revenue_Expense__c arEntries : ar.amortizationEntries) {
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
            option.amortizationMethod = 'Straight Line - Prorated Monthly';
            option.numberOfPeriods = 2;
            option.amortizeDefaultRevenuePrepaidExpense = false;
            Amortization a = new Amortization();
            AmortizationResult ar = a.amortize(option);

            Account_Payable__c payable = [Select Id, Sub_Total__c,Total__c from Account_Payable__c where Id= :testPayables.Id][0];

            Test.stopTest();

            Assert.isTrue(ar.isSuccess);
            Assert.areEqual(payable.Total__c,270,'Payable Total is not matching');
            Assert.areEqual(payable.Sub_Total__c,265,'Payable Sub-Total is not matching');
            Decimal totalAmortizationAmount = 0;
            for(Scheduled_Revenue_Expense__c arEntries : ar.amortizationEntries) {
                totalAmortizationAmount += arEntries.Amount__c;
            }
            Assert.areEqual(payable.Sub_Total__c, totalAmortizationAmount, 'Amortization amount does not matches the default(subtotal)');
        }
    }

    @isTest
    public static void testScheduledRevenueExpenseForCreditMemo() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = testData.payables[4].Id;
            option.startDate = testData.acctPeriods[0].Start_Date__c;
            option.endDate = null;
            option.numberOfPeriods = 5;
            option.creditGlAccount = testData.glAccounts[12].Id;
            option.debitGlAccount = testData.glAccounts[12].Id;
            option.amortizationMethod = 'Straight Line - Prorated Monthly';
            option.amortizeDefaultRevenuePrepaidExpense = false;

            // need to mock since metadata is not available in test
            AmortizationTest.AmortizationMethodFactoryMock mockFactory
                = new AmortizationTest.AmortizationMethodFactoryMock(new StraightLineAmortization());
            AmortizationMethodFactory methodFactory
                = (AmortizationMethodFactory) Test.createStub(AmortizationMethodFactory.class, mockFactory);

            Amortization amor = new Amortization();
            amor.methodFactory = methodFactory;
            AmortizationResult res = amor.amortize(option);
            System.assert(res.isSuccess);

            Decimal resultTotal = 0;
            for (Scheduled_Revenue_Expense__c sre : res.amortizationEntries) {
                resultTotal += sre.Amount__c;
            }

            System.assertEquals([SELECT Total__c FROM Account_Payable__c WHERE Id = :testData.payables[4].Id].Total__c, resultTotal);
            System.assertEquals(5, res.amortizationEntries.size());
        }

    }

}