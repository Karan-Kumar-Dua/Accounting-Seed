@IsTest
private class AmortizationIntegrationTest {

    public static final Decimal DEFAULT_AMOUNT = 54998.77;

    @TestSetup
    private static void setupTestData() {
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users.get(1)) {
            // delete existing periods
            delete testData.acctPeriods;

            // create accounting periods
            testData.acctPeriods = new List<Accounting_Period__c> {
                new Accounting_Period__c(
                    Name = '2021-11',
                    Start_Date__c = Date.newInstance(2021, 11, 1),
                    End_Date__c = Date.newInstance(2021, 11, 30),
                    Status__c = AccountingPeriodActions.OPEN_STATUS
                ),
                new Accounting_Period__c(
                    Name = '2021-12',
                    Start_Date__c = Date.newInstance(2021, 12, 1),
                    End_Date__c = Date.newInstance(2021, 12, 31),
                    Status__c = AccountingPeriodActions.OPEN_STATUS
                ),
                new Accounting_Period__c(
                    Name = '2022-01',
                    Start_Date__c = Date.newInstance(2022, 1, 1),
                    End_Date__c = Date.newInstance(2022, 1, 31),
                    Status__c = AccountingPeriodActions.OPEN_STATUS
                ),
                new Accounting_Period__c(
                    Name = '2022-02',
                    Start_Date__c = Date.newInstance(2022, 2, 1),
                    End_Date__c = Date.newInstance(2022, 2, 28),
                    Status__c = AccountingPeriodActions.OPEN_STATUS
                ),
                new Accounting_Period__c(
                    Name = '2022-03',
                    Start_Date__c = Date.newInstance(2022, 3, 1),
                    End_Date__c = Date.newInstance(2022, 3, 31),
                    Status__c = AccountingPeriodActions.OPEN_STATUS
                )
            };
            insert testData.acctPeriods;


            Billing__c bill = new Billing__c(
                Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c + 3,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Status__c = 'Approved',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = System.today() + 30
            );

            insert bill;

            Billing_Line__c billLine = new Billing_Line__c(
                Billing__c = bill.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 1,
                Rate__c = DEFAULT_AMOUNT,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );

            insert billLine;

            Account_Payable__c pay = new Account_Payable__c(
                Payee_Reference__c = '2345sdfghtwsrehfdhdfhdfh',
                Status__c = 'Approved',
                Payment_Status__c = 'Unpaid',
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Due_Date__c = testData.acctPeriods[0].End_Date__c,
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Ledger__c = testData.ledgers[0].Id
            );

            insert pay;

            Account_Payable_Line__c payLine = new Account_Payable_Line__c(
                Account_Payable__c = pay.Id,
                Amount__c = DEFAULT_AMOUNT,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Expense_GL_Account__c = testData.glAccounts[16].Id
            );

            insert payLine;
        }

    }

    //==================Billing Side=================================

    @isTest
    public static void testBillingDailyAmortization() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Id billId = [SELECT Id, Billing__c FROM Billing_Line__c WHERE Rate__c = :DEFAULT_AMOUNT].Billing__c;

            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = billId;
            option.startDate = testData.acctPeriods[0].Start_Date__c + 4;
            option.endDate = testData.acctPeriods[4].Start_Date__c + 4;
            option.amount = DEFAULT_AMOUNT;
            option.creditGlAccount = testData.glAccounts[12].Id;
            option.debitGlAccount = testData.glAccounts[12].Id;
            option.amortizationMethod = 'Straight Line - Daily';

            Amortization amor = new Amortization();
            AmortizationResult res = amor.amortize(option);
            System.assert(res.isSuccess);

            List<Scheduled_Revenue_Expense__c> result = res.amortizationEntries;

            Decimal resultCount = 0;

            System.assertEquals(11817.92, result[0].Amount__c);
            resultCount += result[0].Amount__c;

            for (Integer i = 1; i <= result.size() - 3; i++) {
                System.assertEquals(14090.59, result[i].Amount__c);
                resultCount += result[i].Amount__c;
            }

            System.assertEquals(12726.99, result[result.size() - 2].Amount__c);
            resultCount += result[result.size() - 2].Amount__c;

            System.assertEquals(2272.68, result[result.size() - 1].Amount__c);
            resultCount += result[result.size() - 1].Amount__c;

            System.assertEquals(DEFAULT_AMOUNT, resultCount);
            Test.stopTest();
        }

    }

    @isTest
    public static void testBillingMonthlyAmortization() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Id billId = [SELECT Id, Billing__c FROM Billing_Line__c WHERE Rate__c = :DEFAULT_AMOUNT].Billing__c;

            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = billId;
            option.startDate = testData.acctPeriods[0].Start_Date__c + 5;
            option.endDate = null;
            option.numberOfPeriods = 5;
            option.amount = DEFAULT_AMOUNT;
            option.creditGlAccount = testData.glAccounts[12].Id;
            option.debitGlAccount = testData.glAccounts[12].Id;
            option.amortizationMethod = 'Straight Line - Full Month';

            Amortization amor = new Amortization();
            AmortizationResult res = amor.amortize(option);
            System.assert(res.isSuccess);

            List<Scheduled_Revenue_Expense__c> result = res.amortizationEntries;

            Decimal resultCount = 0;

            for (Integer i = 0; i <= result.size() - 2; i++) {
                System.assertEquals(10999.75, result[i].Amount__c);
                resultCount += result[i].Amount__c;
            }

            System.assertEquals(10999.77, result[result.size() - 1].Amount__c);
            resultCount += result[result.size() - 1].Amount__c;

            System.assertEquals(DEFAULT_AMOUNT, resultCount);
            Test.stopTest();
        }

    }

    @isTest
    public static void testBillingStraightLineAmortization() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Id billId = [SELECT Id, Billing__c FROM Billing_Line__c WHERE Rate__c = :DEFAULT_AMOUNT].Billing__c;

            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = billId;
            option.startDate = testData.acctPeriods[0].Start_Date__c + 4;
            option.endDate = null;
            option.numberOfPeriods = 4;
            option.amount = DEFAULT_AMOUNT;
            option.creditGlAccount = testData.glAccounts[12].Id;
            option.debitGlAccount = testData.glAccounts[12].Id;
            option.amortizationMethod = 'Straight Line - Prorated Monthly';

            Amortization amor = new Amortization();
            AmortizationResult res = amor.amortize(option);
            System.assert(res.isSuccess);

            List<Scheduled_Revenue_Expense__c> result = res.amortizationEntries;

            Decimal resultCount = 0;

            System.assertEquals(11916.40, result[0].Amount__c);
            resultCount += result[0].Amount__c;

            for (Integer i = 1; i <= result.size() - 2; i++) {
                System.assertEquals(13749.69, result[i].Amount__c);
                resultCount += result[i].Amount__c;
            }

            System.assertEquals(1833.30, result[result.size() - 1].Amount__c);
            resultCount += result[result.size() - 1].Amount__c;

            System.assertEquals(DEFAULT_AMOUNT, resultCount);
            Test.stopTest();
        }

    }

    //==================Payable Side=================================

    @isTest
    public static void testPayableDailyAmortization() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Id payId = [SELECT Id, Account_Payable__c FROM Account_Payable_Line__c WHERE Amount__c = :DEFAULT_AMOUNT].Account_Payable__c;

            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = payId;
            option.startDate = testData.acctPeriods[0].Start_Date__c + 4;
            option.endDate = testData.acctPeriods[4].Start_Date__c + 4;
            option.amount = DEFAULT_AMOUNT;
            option.creditGlAccount = testData.glAccounts[12].Id;
            option.debitGlAccount = testData.glAccounts[12].Id;
            option.amortizationMethod = 'Straight Line - Daily';

            Amortization amor = new Amortization();
            AmortizationResult res = amor.amortize(option);
            System.assert(res.isSuccess);

            List<Scheduled_Revenue_Expense__c> result = res.amortizationEntries;

            Decimal resultCount = 0;

            System.assertEquals(11817.92, result[0].Amount__c);
            resultCount += result[0].Amount__c;

            for (Integer i = 1; i <= result.size() - 3; i++) {
                System.assertEquals(14090.59, result[i].Amount__c);
                resultCount += result[i].Amount__c;
            }

            System.assertEquals(12726.99, result[result.size() - 2].Amount__c);
            resultCount += result[result.size() - 2].Amount__c;

            System.assertEquals(2272.68, result[result.size() - 1].Amount__c);
            resultCount += result[result.size() - 1].Amount__c;

            System.assertEquals(DEFAULT_AMOUNT, resultCount);
            Test.stopTest();
        }
    }

    @isTest
    public static void testPayableMonthlyAmortization() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Id payId = [SELECT Id, Account_Payable__c FROM Account_Payable_Line__c WHERE Amount__c = :DEFAULT_AMOUNT].Account_Payable__c;

            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = payId;
            option.startDate = testData.acctPeriods[0].Start_Date__c + 5;
            option.endDate = null;
            option.numberOfPeriods = 5;
            option.amount = DEFAULT_AMOUNT;
            option.creditGlAccount = testData.glAccounts[12].Id;
            option.debitGlAccount = testData.glAccounts[12].Id;
            option.amortizationMethod = 'Straight Line - Full Month';

            Amortization amor = new Amortization();
            AmortizationResult res = amor.amortize(option);
            System.assert(res.isSuccess);

            List<Scheduled_Revenue_Expense__c> result = res.amortizationEntries;

            Decimal resultCount = 0;

            for (Integer i = 0; i <= result.size() - 2; i++) {
                System.assertEquals(10999.75, result[i].Amount__c);
                resultCount += result[i].Amount__c;
            }

            System.assertEquals(10999.77, result[result.size() - 1].Amount__c);
            resultCount += result[result.size() - 1].Amount__c;

            System.assertEquals(DEFAULT_AMOUNT, resultCount);
            Test.stopTest();
        }

    }

    @isTest
    public static void testPayableStraightLineAmortization() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Id payId = [SELECT Id, Account_Payable__c FROM Account_Payable_Line__c WHERE Amount__c = :DEFAULT_AMOUNT].Account_Payable__c;

            AmortizationOptions option = new AmortizationOptions();
            option.accrualCash = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            option.sourceDocument = payId;
            option.startDate = testData.acctPeriods[0].Start_Date__c + 4;
            option.endDate = testData.acctPeriods[4].Start_Date__c + 4;
            option.numberOfPeriods = 4;
            option.amount = DEFAULT_AMOUNT;
            option.creditGlAccount = testData.glAccounts[12].Id;
            option.debitGlAccount = testData.glAccounts[12].Id;
            option.amortizationMethod = 'Straight Line - Prorated Monthly';

            Amortization amor = new Amortization();
            AmortizationResult res = amor.amortize(option);
            System.assert(res.isSuccess);

            List<Scheduled_Revenue_Expense__c> result = res.amortizationEntries;

            Decimal resultCount = 0;

            System.assertEquals(11916.40, result[0].Amount__c);
            resultCount += result[0].Amount__c;

            for (Integer i = 1; i <= result.size() - 2; i++) {
                System.assertEquals(13749.69, result[i].Amount__c);
                resultCount += result[i].Amount__c;
            }

            System.assertEquals(1833.30, result[result.size() - 1].Amount__c);
            resultCount += result[result.size() - 1].Amount__c;

            System.assertEquals(DEFAULT_AMOUNT, resultCount);
            Test.stopTest();
        }
    }
}