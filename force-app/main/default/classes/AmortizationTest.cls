@IsTest
public with sharing class AmortizationTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testAmortizeUnsupportedSrcDocType() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            AmortizationOptions opts = new AmortizationOptions();
            opts.sourceDocument = FinancialSuiteUtils.getFakeId(Contact.getSObjectType());
            Amortization a = new Amortization();
            AmortizationResult ar = a.amortize(opts);
            Test.stopTest();

            System.assert(!ar.isSuccess);
            System.assertEquals(Amortization.INVALID_SRC_DOC_TYPE, ar.errors[0]);
        }
    }

    @IsTest
    private static void testAmortizeInvalidMethod() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            AmortizationOptions opts = new AmortizationOptions();
            opts.amortizationMethod = 'BadMethodAmortization';
            opts.sourceDocument = FinancialSuiteUtils.getFakeId(Billing__c.getSObjectType());
            Amortization a = new Amortization();
            AmortizationResult ar = a.amortize(opts);
            Test.stopTest();

            System.assert(!ar.isSuccess);
            System.assertEquals(Amortization.INVALID_AMORTIZATION_METHOD, ar.errors[0]);
        }
    }

    @IsTest
    private static void testAmortizeWithoutInput() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            AmortizationOptions opts;
            Amortization a = new Amortization();
            AmortizationResult ar = a.amortize(opts);
            Test.stopTest();

            System.assert(!ar.isSuccess);
            System.assertEquals(Amortization.MISSING_OPTIONS, ar.errors[0]);
        }
    }

    @IsTest
    private static void testAmortizeStartDateError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            AmortizationOptions opts = new AmortizationOptions();
            opts.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            opts.sourceDocument = testData.payables[0].Id;
            opts.startDate = testData.payables[0].Date__c.addDays(2);
            opts.endDate = testData.payables[0].Date__c.addDays(-5);
            opts.amortizationMethod = 'Straight Line - Daily';
            Amortization a = new Amortization();
            AmortizationResult ar = a.amortize(opts);
            Test.stopTest();

            System.assert(!ar.isSuccess);
            System.assertEquals(Amortization.ERROR_START_DATE_GREATER_END_DATE, ar.errors[0]);
        }
    }

    @IsTest
    private static void testAmortizeStartDateEmptyError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            AmortizationOptions opts = new AmortizationOptions();
            opts.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            opts.sourceDocument = testData.payables[0].Id;
            opts.startDate = null;
            opts.endDate = testData.payables[0].Date__c.addDays(-5);
            opts.amortizationMethod = 'Straight Line - Daily';
            Amortization a = new Amortization();
            AmortizationResult ar = a.amortize(opts);
            Test.stopTest();

            System.assert(!ar.isSuccess);
            System.assertEquals(Amortization.ERROR_START_DATE_EMPTY, ar.errors[0]);
        }
    }

    @IsTest
    private static void testAmortizeEndDateEmptyError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            AmortizationOptions opts = new AmortizationOptions();
            opts.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            opts.sourceDocument = testData.payables[0].Id;
            opts.startDate = testData.payables[0].Date__c.addDays(2);
            opts.endDate = null;
            opts.amortizationMethod = 'Straight Line - Daily';
            Amortization a = new Amortization();
            AmortizationResult ar = a.amortize(opts);
            Test.stopTest();

            System.assert(!ar.isSuccess);
            System.assertEquals(Label.ERR_END_DATE_CANNOT_BE_EMPTY, ar.errors[0]);
        }
    }

    @IsTest
    private static void testAmortizePeriodsError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            AmortizationOptions opts = new AmortizationOptions();
            opts.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            opts.sourceDocument = testData.payables[0].Id;
            opts.startDate = testData.acctPeriods[0].Start_Date__c.addDays(-15);
            opts.endDate = testData.payables[0].Date__c.addDays(2);
            opts.amortizationMethod = 'Straight Line - Daily';
            Amortization a = new Amortization();
            AmortizationResult ar = a.amortize(opts);
            Test.stopTest();

            System.assert(!ar.isSuccess);
            System.assertEquals(Amortization.ERROR_NO_OPEN_PERIODS, ar.errors[0]);
        }
    }

   @IsTest
   private static void testAmortizeSave() {
       TestDataSuite testData = TestDataSuite.getInstance()
           .createBillings(true);

       System.runAs(testData.users.get(1)) {
           Test.startTest();
           AmortizationOptions opts = new AmortizationOptions();
           opts.amortizationMethod = 'UsingMock';
           opts.sourceDocument = testData.billings[0].Id;
           opts.startDate = testData.billings[0].Billing_Cycle_Start_Date__c;
           opts.endDate = testData.billings[0].Billing_Cycle_End_Date__c;

           // set mocks
           AmortizationResult expectedResult = new AmortizationResult();
           expectedResult.isSuccess = true;
           expectedResult.errors = new List<String>();
           expectedResult.amortizationEntries = new List<Scheduled_Revenue_Expense__c>();
           List<AmortizationResult> amortizationEntries = new List<AmortizationResult>{
               expectedResult
           };

           AmortizationMethodMock mockMethod = new AmortizationMethodMock(amortizationEntries);
           AbstractAmortization method = (AbstractAmortization) Test.createStub(DailyAmortization.class, mockMethod);

           AmortizationMethodFactoryMock mockFactory = new AmortizationMethodFactoryMock(method);
           AmortizationMethodFactory methodFactory = (AmortizationMethodFactory) Test.createStub(AmortizationMethodFactory.class, mockFactory);

           Amortization a = new Amortization();
           a.methodFactory = methodFactory;

           List<AmortizationResult> ars = a.processAmortizations(new List<AmortizationOptions>{ opts });

           System.assertEquals(1, ars.size());
           System.assertEquals(expectedResult.isSuccess, ars[0].isSuccess);
           System.assertEquals(expectedResult.errors.size(), ars[0].errors.size());
           System.assertEquals(expectedResult.amortizationEntries.size(), ars[0].amortizationEntries.size());
       }
   }

   @IsTest
   private static void testAmortizeInvocableSave() {
       TestDataSuite testData = TestDataSuite.getInstance()
           .createBillings(true);

       System.runAs(testData.users.get(1)) {
           Test.startTest();
           AmortizationOptions opts = new AmortizationOptions();
           opts.sourceDocument = testData.billings[0].Id;
           List<AmortizationResult> ars = Amortization.amortizeInvocable(new List<AmortizationOptions>{ opts });
           System.assertEquals(1, ars.size());
       }
   }

   

   @IsTest
   private static void testAmortizePartialSave() {
       TestDataSuite testData = TestDataSuite.getInstance()
           .createBillings(true);

       System.runAs(testData.users.get(1)) {
           Test.startTest();
           AmortizationOptions opts1 = new AmortizationOptions();
           opts1.amortizationMethod = 'UsingMock';
           opts1.sourceDocument = testData.billings[0].Id;
           opts1.startDate = testData.billings[0].Billing_Cycle_Start_Date__c;
           opts1.endDate = testData.billings[0].Billing_Cycle_End_Date__c;

           AmortizationOptions opts2 = new AmortizationOptions();
           opts2.sourceDocument = FinancialSuiteUtils.getFakeId(Contact.getSObjectType());

           // set mocks
           AmortizationResult expectedResult = new AmortizationResult();
           expectedResult.isSuccess = true;
           expectedResult.errors = new List<String>();
           expectedResult.amortizationEntries = new List<Scheduled_Revenue_Expense__c>();
           List<AmortizationResult> amortizationEntries = new List<AmortizationResult>{
               expectedResult
           };

           AmortizationMethodMock mockMethod = new AmortizationMethodMock(amortizationEntries);
           AbstractAmortization method = (AbstractAmortization) Test.createStub(DailyAmortization.class, mockMethod);

           AmortizationMethodFactoryMock mockFactory = new AmortizationMethodFactoryMock(method);
           AmortizationMethodFactory methodFactory = (AmortizationMethodFactory) Test.createStub(AmortizationMethodFactory.class, mockFactory);

           Amortization a = new Amortization();
           a.methodFactory = methodFactory;

           List<AmortizationResult> ars = a.processAmortizations(new List<AmortizationOptions>{ opts1, opts2 });
           Test.stopTest();

           System.assertEquals(2, ars.size());
           System.assert(ars[0].isSuccess || ars[1].isSuccess);
           System.assert(!ars[0].isSuccess || !ars[1].isSuccess);
       }
   }

    @IsTest
    private static void testAmortizePreservesOrder() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            AmortizationOptions opts1 = new AmortizationOptions();
            opts1.amortizationMethod = 'UsingMock';
            opts1.sourceDocument = testData.billings[0].Id;
            opts1.startDate = testData.billings[0].Billing_Cycle_Start_Date__c;
            opts1.endDate = testData.billings[0].Billing_Cycle_End_Date__c;

            AmortizationOptions opts2 = new AmortizationOptions();
            opts2.sourceDocument = FinancialSuiteUtils.getFakeId(Contact.getSObjectType());

            AmortizationOptions opts3 = new AmortizationOptions();
            opts3.amortizationMethod = 'UsingMock';
            opts3.sourceDocument = testData.billings[1].Id;
            opts3.startDate = testData.billings[1].Billing_Cycle_Start_Date__c;
            opts3.endDate = testData.billings[1].Billing_Cycle_End_Date__c;

            // set mocks
            AmortizationResult expectedResult1 = new AmortizationResult();
            expectedResult1.isSuccess = true;
            expectedResult1.errors = new List<String>();
            expectedResult1.amortizationEntries = new List<Scheduled_Revenue_Expense__c>{
                new Scheduled_Revenue_Expense__c()
            };
            AmortizationResult expectedResult2 = new AmortizationResult();
            expectedResult2.isSuccess = true;
            expectedResult2.errors = new List<String>();
            expectedResult2.amortizationEntries = new List<Scheduled_Revenue_Expense__c>{
                new Scheduled_Revenue_Expense__c(),
                new Scheduled_Revenue_Expense__c()
            };

            List<AmortizationResult> amortizationEntries = new List<AmortizationResult>{
                expectedResult1, 
                expectedResult2
            };

            AmortizationMethodMock mockMethod = new AmortizationMethodMock(amortizationEntries);
            AbstractAmortization method = (AbstractAmortization) Test.createStub(DailyAmortization.class, mockMethod);

            AmortizationMethodFactoryMock mockFactory = new AmortizationMethodFactoryMock(method);
            AmortizationMethodFactory methodFactory = (AmortizationMethodFactory) Test.createStub(AmortizationMethodFactory.class, mockFactory);

            Amortization a = new Amortization();
            a.methodFactory = methodFactory;

            List<AmortizationResult> ars = a.processAmortizations(new List<AmortizationOptions>{ opts1, opts2, opts3 });
            Test.stopTest();
            
            System.assertEquals(3, ars.size());
            System.assert(ars[0].isSuccess);
            System.assert(!ars[1].isSuccess);
            System.assert(ars[2].isSuccess);
            System.assertEquals(1, ars[0].amortizationEntries.size());
            System.assertEquals(null, ars[1].amortizationEntries);
            System.assertEquals(2, ars[2].amortizationEntries.size());
        }
    }

    @IsTest
    private static void testAmortizeDefaultPrepaidGLDailySave() {
         TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Billing__c testBilling = testData.billings[0];
            testBilling.Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c;

            update testBilling;
            List<Billing_Line__c> lines = [SELECT Id, Revenue_GL_Account__c FROM Billing_Line__c WHERE Billing__c = :testBilling.Id];
            for (Billing_Line__c line : lines) {
                line.Revenue_GL_Account__c = testData.glAccounts[25].Id;
            }
            update lines;

            Billing__c billing = [Select Id, AcctSeed__Sub_Total__c from Billing__c where Id=:testData.billings[0].Id];

            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = billing.Id;
            option.startDate = testData.billings[0].Billing_Cycle_Start_Date__c;
            option.endDate = testData.billings[0].Billing_Cycle_End_Date__c;
            option.creditGlAccount = testData.glAccounts[12].Id;
            option.debitGlAccount = testData.glAccounts[12].Id;
            option.description = 'test description';
            option.amortizationMethod = 'Straight Line - Daily';
            option.amortizeDefaultRevenuePrepaidExpense = true;

            Amortization amor = new Amortization();
            AmortizationResult res = amor.amortize(option);

            List<Billing_Line__c> billingLines = [Select Id, Sub_Total__c from Billing_Line__c where Billing__c =:billing.Id];
            List<Scheduled_Revenue_Expense__c> result = res.amortizationEntries;
            Assert.isTrue(res.isSuccess);
            Assert.areEqual('test description', result[0].Description__c);
            Assert.areEqual(billingLines[0].Sub_Total__c + billingLines[1].Sub_Total__c, result[0].Amount__c);
        }
    }

    @IsTest
    private static void testAmortizeDefaultPrepaidGLMonthlySave() {
         TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Billing__c testBilling = testData.billings[0];
            testBilling.Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c;

            update testBilling;
            List<Billing_Line__c> lines = [SELECT Id, Revenue_GL_Account__c FROM Billing_Line__c WHERE Billing__c = :testBilling.Id];
            for (Billing_Line__c line : lines) {
                line.Revenue_GL_Account__c = testData.glAccounts[25].Id;
            }
            update lines;

            Billing__c billing = [Select Id, AcctSeed__Sub_Total__c from Billing__c where Id=:testData.billings[0].Id];

            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = billing.Id;
            option.startDate = testData.billings[0].Billing_Cycle_Start_Date__c;
            option.endDate = testData.billings[0].Billing_Cycle_End_Date__c;
            option.creditGlAccount = testData.glAccounts[12].Id;
            option.debitGlAccount = testData.glAccounts[12].Id;
            option.description = 'test description';
            option.amortizationMethod = 'Straight Line - Full Month';
            option.amortizeDefaultRevenuePrepaidExpense = true;
            option.numberOfPeriods = 2;

            Amortization amor = new Amortization();
            AmortizationResult res = amor.amortize(option);

            List<Scheduled_Revenue_Expense__c> result = res.amortizationEntries;
            Assert.isTrue(res.isSuccess);
            Assert.areEqual(billing.Sub_Total__c/option.numberOfPeriods, result[0].Amount__c);
            Assert.areEqual(billing.Sub_Total__c/option.numberOfPeriods, result[1].Amount__c);
        }
    }

    @IsTest
    private static void testAmortizeDefaultPrepaidGLProratedMonthlySave() {
         TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Billing__c testBilling = testData.billings[0];
            testBilling.Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c;

            update testBilling;
            List<Billing_Line__c> lines = [SELECT Id, Revenue_GL_Account__c FROM Billing_Line__c WHERE Billing__c = :testBilling.Id];
            for (Billing_Line__c line : lines) {
                line.Revenue_GL_Account__c = testData.glAccounts[25].Id;
            }
            update lines;

            Billing__c billing = [Select Id, AcctSeed__Sub_Total__c from Billing__c where Id=:testData.billings[0].Id];

            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = billing.Id;
            option.startDate = testData.billings[0].Billing_Cycle_Start_Date__c;
            option.endDate = testData.billings[0].Billing_Cycle_End_Date__c;
            option.creditGlAccount = testData.glAccounts[12].Id;
            option.debitGlAccount = testData.glAccounts[12].Id;
            option.description = 'test description';
            option.amortizationMethod = 'Straight Line - Prorated Monthly';
            option.amortizeDefaultRevenuePrepaidExpense = true;
            option.numberOfPeriods = 2;

            Amortization amor = new Amortization();
            AmortizationResult res = amor.amortize(option);

            List<Scheduled_Revenue_Expense__c> result = res.amortizationEntries;
            Assert.isTrue(res.isSuccess);
            Assert.areEqual(billing.Sub_Total__c/option.numberOfPeriods, result[0].Amount__c);
            Assert.areEqual(billing.Sub_Total__c/option.numberOfPeriods, result[1].Amount__c);
        }
    }

    @IsTest
    private static void testAmortizeDefaultPrepaidGLPayableDailySave() {
         TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Account_Payable__c testPayable = testData.payables[0];
            testPayable.Due_Date__c = testData.acctPeriods[0].End_Date__c;

            update testPayable;

            Map<String, GL_Account_Default__c> glAccounts = GLAccount.glAccountDefaultsMapByLedgerId(testData.payables[0].Ledger__c);
            List<Account_Payable_Line__c> payableLines = [Select id, Sub_Total__c, Expense_GL_Account__c from Account_Payable_Line__c Where Account_Payable__c=:testData.payableLines[0].Account_Payable__c];
            payableLines[0].Expense_GL_Account__c = glAccounts.get(GLAccountDefaultsHandler.DEFAULT_CREDIT_GL_ACCOUNT_EXPENSE).GL_account__c;
            payableLines[1].Expense_GL_Account__c = glAccounts.get(GLAccountDefaultsHandler.DEFAULT_CREDIT_GL_ACCOUNT_EXPENSE).GL_account__c;
            payableLines[2].Expense_GL_Account__c = glAccounts.get(GLAccountDefaultsHandler.DEFAULT_CREDIT_GL_ACCOUNT_EXPENSE).GL_account__c;
            update payableLines;

            Account_Payable__c payable = [Select Id, AcctSeed__Sub_Total__c from Account_Payable__c where Id=:testData.payables[0].Id];

            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = payable.Id;
            option.startDate = testData.payables[0].Date__c;
            option.endDate = testData.payables[0].Due_Date__c;
            option.creditGlAccount = testData.glAccounts[12].Id;
            option.debitGlAccount = testData.glAccounts[12].Id;
            option.description = 'test description';
            option.amortizationMethod = 'Straight Line - Daily';
            option.amortizeDefaultRevenuePrepaidExpense = true;

            Amortization amor = new Amortization();
            AmortizationResult res = amor.amortize(option);

            List<Scheduled_Revenue_Expense__c> result = res.amortizationEntries;
            Assert.isTrue(res.isSuccess);
            Assert.areEqual('test description', result[0].Description__c);
            Assert.areEqual(payableLines[0].Sub_Total__c + payableLines[1].Sub_Total__c + payableLines[2].Sub_Total__c, result[0].Amount__c);
        }
    }

    @IsTest
    private static void testAmortizeNoDefaultPrepaidGLPayableDailySave() {
         TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Account_Payable__c testPayable = testData.payables[0];
            testPayable.Due_Date__c = testData.acctPeriods[0].End_Date__c;

            update testPayable;

            Map<String, GL_Account_Default__c> glAccounts = GLAccount.glAccountDefaultsMapByLedgerId(testData.payables[0].Ledger__c);
            List<Account_Payable_Line__c> payableLines = [Select id, Sub_Total__c, Expense_GL_Account__c from Account_Payable_Line__c Where Account_Payable__c=:testData.payableLines[0].Account_Payable__c];
            payableLines[0].Expense_GL_Account__c = glAccounts.get(GLAccountDefaultsHandler.DEFAULT_CREDIT_GL_ACCOUNT_EXPENSE).GL_account__c;
            payableLines[1].Expense_GL_Account__c = glAccounts.get(GLAccountDefaultsHandler.DEFAULT_CREDIT_GL_ACCOUNT_EXPENSE).GL_account__c;
            payableLines[2].Expense_GL_Account__c = glAccounts.get(GLAccountDefaultsHandler.DEFAULT_CREDIT_GL_ACCOUNT_EXPENSE).GL_account__c;
            update payableLines;

            Account_Payable__c payable = [Select Id, AcctSeed__Sub_Total__c from Account_Payable__c where Id=:testData.payables[0].Id];

            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = payable.Id;
            option.startDate = testData.payables[0].Date__c;
            option.endDate = testData.payables[0].Due_Date__c;
            option.creditGlAccount = testData.glAccounts[12].Id;
            option.debitGlAccount = testData.glAccounts[12].Id;
            option.description = 'test description';
            option.amortizationMethod = 'Straight Line - Daily';
            option.amortizeDefaultRevenuePrepaidExpense = false;

            Amortization amor = new Amortization();
            AmortizationResult res = amor.amortize(option);

            List<Scheduled_Revenue_Expense__c> result = res.amortizationEntries;
            Assert.isTrue(res.isSuccess);
            Assert.areEqual('test description', result[0].Description__c);
            Assert.areEqual(payable.Sub_Total__c, result[0].Amount__c);
        }
    }

    @IsTest
    private static void testAmortizeDefaultPrepaidGLPayableMonthlySave() {
         TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Account_Payable__c testPayable = testData.payables[0];
            testPayable.Due_Date__c = testData.acctPeriods[0].End_Date__c;

            update testPayable;

            Map<String, GL_Account_Default__c> glAccounts = GLAccount.glAccountDefaultsMapByLedgerId(testData.payables[0].Ledger__c);
            List<Account_Payable_Line__c> payableLines = [Select id, Sub_Total__c, Expense_GL_Account__c from Account_Payable_Line__c Where Account_Payable__c=:testData.payableLines[0].Account_Payable__c];
            payableLines[0].Expense_GL_Account__c = glAccounts.get(GLAccountDefaultsHandler.DEFAULT_CREDIT_GL_ACCOUNT_EXPENSE).GL_account__c;
            payableLines[1].Expense_GL_Account__c = glAccounts.get(GLAccountDefaultsHandler.DEFAULT_CREDIT_GL_ACCOUNT_EXPENSE).GL_account__c;
            payableLines[2].Expense_GL_Account__c = glAccounts.get(GLAccountDefaultsHandler.DEFAULT_CREDIT_GL_ACCOUNT_EXPENSE).GL_account__c;
            update payableLines;

            Account_Payable__c payable = [Select Id, AcctSeed__Sub_Total__c from Account_Payable__c where Id=:testData.payables[0].Id];

            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = payable.Id;
            option.startDate = testData.payables[0].Date__c;
            option.endDate = testData.payables[0].Due_Date__c;
            option.creditGlAccount = testData.glAccounts[12].Id;
            option.debitGlAccount = testData.glAccounts[12].Id;
            option.description = 'test description';
            option.amortizationMethod = 'Straight Line - Full Month';
            option.amortizeDefaultRevenuePrepaidExpense = true;
            option.numberOfPeriods = 2;

            Amortization amor = new Amortization();
            AmortizationResult res = amor.amortize(option);

            List<Scheduled_Revenue_Expense__c> result = res.amortizationEntries;
            Assert.isTrue(res.isSuccess);
            Assert.areEqual('test description', result[0].Description__c);
            Assert.areEqual(payable.Sub_Total__c/option.numberOfPeriods, result[0].Amount__c);
            Assert.areEqual(payable.Sub_Total__c/option.numberOfPeriods, result[1].Amount__c);
        }
    }

    @IsTest
    public static void testAmortizeDefaultPrepaidGLDailyLLPWithTaxSave() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createBillings()
            .createProducts();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Billing__c testBilling = testData.billings[0];
            testBilling.Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c;
            update testBilling;

            delete [SELECT Id FROM Billing_Line__c WHERE Billing__c = :testBilling.Id];

            Product2 taxRateProduct = testData.products[4];
            Product2 taxableProduct = testData.products[3];
            Account_Tax__c tax = new Account_Tax__c(
                Account__c = testBilling.Customer__c,
                Tax_Rate__c = taxRateProduct.Id,
                Tax_Type__c = 'Sales'
            );
            insert tax;

            Billing_Line__c taxableLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testBilling.Date__c,
                Hours_Units__c = 25,
                Rate__c = 10,
                Product__c = taxableProduct.Id,
                Revenue_GL_Account__c = testData.glAccounts[25].Id
            );

            Billing_Line__c salesTaxLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testBilling.Date__c,
                Hours_Units__c = 1,
                Rate__c = 10,
                Product__c = taxRateProduct.Id,
                Revenue_GL_Account__c = testData.glAccounts[25].Id
            );

            insert new List<Billing_Line__c>{taxableLine, salesTaxLine};

            System.assertEquals(10, [SELECT Id, Sales_Tax2__c FROM Billing__c WHERE Id = :testBilling.Id].Sales_Tax2__c.setScale(2, System.RoundingMode.HALF_UP));
            System.assertEquals(true, [SELECT Tax_Line__c FROM Billing_Line__c WHERE Id = :salesTaxLine.Id].Tax_Line__c);

            Billing__c billing = [Select Id, AcctSeed__Sub_Total__c from Billing__c where Id = :testData.billings[0].Id];

            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = billing.Id;
            option.startDate = testData.billings[0].Billing_Cycle_Start_Date__c;
            option.endDate = testData.billings[0].Billing_Cycle_End_Date__c;
            option.creditGlAccount = testData.glAccounts[12].Id;
            option.debitGlAccount = testData.glAccounts[12].Id;
            option.description = 'test description';
            option.amortizationMethod = 'Straight Line - Daily';
            option.amortizeDefaultRevenuePrepaidExpense = true;

            Amortization amor = new Amortization();
            AmortizationResult res = amor.amortize(option);

            List<Billing_Line__c> billingLines = [Select Id, Sub_Total__c from Billing_Line__c where Billing__c =:billing.Id];
            List<Scheduled_Revenue_Expense__c> result = res.amortizationEntries;
            Assert.isTrue(res.isSuccess);
            Assert.areEqual('test description', result[0].Description__c);
            Assert.areEqual(billingLines[0].Sub_Total__c, result[0].Amount__c);
        }
    }

    public class AmortizationMethodFactoryMock implements System.StubProvider {
        
        private AbstractAmortization output;

        public AmortizationMethodFactoryMock(AbstractAmortization output) {
            this.output = output;
        }

        public Object handleMethodCall(
                Object stubbedObject,
                String stubbedMethodName,
                Type returnType,
                List<Type> listOfParamTypes,
                List<String> listOfParamNames,
                List<Object> listOfArgs) {

            return output;
        }
    }

    public class AmortizationMethodMock implements System.StubProvider {
        
        private List<AmortizationResult> output;

        public AmortizationMethodMock(List<AmortizationResult> output) {
            this.output = output;
        }

        public Object handleMethodCall(
                Object stubbedObject,
                String stubbedMethodName,
                Type returnType,
                List<Type> listOfParamTypes,
                List<String> listOfParamNames,
                List<Object> listOfArgs) {
            
            
            if (stubbedMethodName == 'amortize') {
                return output.remove(0);
            }  
            return null;     
        }
    }
}