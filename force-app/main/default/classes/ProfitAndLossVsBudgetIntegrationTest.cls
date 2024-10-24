@IsTest
private with sharing class ProfitAndLossVsBudgetIntegrationTest {

    private static final String cLabelActualTotal = Label.COMMON_ACTUAL_TOTAL;
    private static final String cLabelBudgetTotal = Label.COMMON_BUDGET_TOTAL;
    private static final String cLabelDifference = Label.COMMON_DIFFERENCE;
    private static final String cLabelBudgetPercent = Label.COMMON_BUDGET_PERCENTAGE;
    private static final String rLabelNetIncome = Label.COMMON_NET_INCOME;
    private static final String rLabelTotalRev = Label.COMMON_TOTAL_REVENUE;
    private static final String rLabelTotalExp = Label.COMMON_TOTAL_EXPENSE;

    @TestSetup
    private static void createTestData() {
        //  standard test data setup
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users.get(1)) {
            Id ledgerActual = testData.ledgers[0].Id;
            List<Financial_Cube__c> finCubes;

            // delete existing periods
            delete testData.acctPeriods;

            // create accounting periods
            testData.acctPeriods = new List<Accounting_Period__c> {
                new Accounting_Period__c(
                    Name = '2021-04',
                    Start_Date__c = Date.newInstance(2021, 4, 1),
                    End_Date__c = Date.newInstance(2021, 4, 30),
                    Status__c = AccountingPeriodActions.OPEN_STATUS
                ),
                new Accounting_Period__c(
                    Name = '2021-05',
                    Start_Date__c = Date.newInstance(2021, 5, 1),
                    End_Date__c = Date.newInstance(2021, 5, 31),
                    Status__c = AccountingPeriodActions.OPEN_STATUS
                )
            };
            insert testData.acctPeriods;

            // create billings
            testData.billings = new List<Billing__c> {
                new Billing__c(
                    Accounting_Period__c = testData.acctPeriods[0].id,
                    Customer__c = testData.accounts[0].Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Ledger__c = ledgerActual
                ),
                new Billing__c(
                    Accounting_Period__c = testData.acctPeriods[1].id,
                    Customer__c = testData.accounts[0].Id,
                    Date__c = testData.acctPeriods[1].Start_Date__c,
                    Ledger__c = ledgerActual
                )
            };
            insert testData.billings;

            // create billing lines
            testData.billingLines = new List<Billing_Line__c> {
                new Billing_Line__c(
                    Billing__c = testData.billings[0].Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Revenue_GL_Account__c = testData.glAccounts[10].Id,
                    Hours_Units__c = 1,
                    Rate__c = 4161.56
                ),
                new Billing_Line__c(
                    Billing__c = testData.billings[0].Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Revenue_GL_Account__c = testData.glAccounts[11].Id,
                    Hours_Units__c = 1,
                    Rate__c = 150700.40
                ),
                new Billing_Line__c(
                    Billing__c = testData.billings[1].Id,
                    Date__c = testData.acctPeriods[1].Start_Date__c,
                    Revenue_GL_Account__c = testData.glAccounts[10].Id,
                    Hours_Units__c = 1,
                    Rate__c = 10500.55
                ),
                new Billing_Line__c(
                    Billing__c = testData.billings[1].Id,
                    Date__c = testData.acctPeriods[1].Start_Date__c,
                    Revenue_GL_Account__c = testData.glAccounts[11].Id,
                    Hours_Units__c = 1,
                    Rate__c = -6000.22
                )
            };
            insert testData.billingLines;

            // create payables
            testData.payables = new List<Account_Payable__c> {
                new Account_Payable__c(
                    Payee_Reference__c = 'ref0',
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Ledger__c = ledgerActual,
                    Vendor__c = testData.accounts[0].Id
                ),
                new Account_Payable__c(
                    Payee_Reference__c = 'ref1',
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Date__c = testData.acctPeriods[1].Start_Date__c,
                    Ledger__c = ledgerActual,
                    Vendor__c = testData.accounts[0].Id
                )
            };
            insert testData.payables;

            // create payable lines
            testData.payableLines = new List<Account_Payable_Line__c> {
                new Account_Payable_Line__c(
                    Account_Payable__c = testData.payables[0].Id,
                    Amount__c = 900.40,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = testData.glAccounts[12].Id
                ),
                new Account_Payable_Line__c(
                    Account_Payable__c = testData.payables[0].Id,
                    Amount__c = 100.40,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = testData.glAccounts[16].Id
                ),
                new Account_Payable_Line__c(
                    Account_Payable__c = testData.payables[1].Id,
                    Amount__c = 15501.75,
                    Date__c = testData.acctPeriods[1].Start_Date__c,
                    Expense_GL_Account__c = testData.glAccounts[12].Id
                ),
                new Account_Payable_Line__c(
                    Account_Payable__c = testData.payables[1].Id,
                    Amount__c = -4560.22,
                    Date__c = testData.acctPeriods[1].Start_Date__c,
                    Expense_GL_Account__c = testData.glAccounts[16].Id
                )
            };
            insert testData.payableLines;

            // create financial cubes
            finCubes = new List<Financial_Cube__c> {
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    GL_Account__c = testData.glAccounts[10].Id,
                    Opening_Balance__c = 0,
                    Amount__c = 5400.55,
                    Ledger__c = testData.ledgers[1].Id,
                    Cube_Type__c = 'Retained Earnings'
                ),
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    GL_Account__c = testData.glAccounts[11].Id,
                    Opening_Balance__c = 0,
                    Amount__c = 55500.44,
                    Ledger__c = testData.ledgers[1].Id,
                    Cube_Type__c = 'Retained Earnings'
                ),
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    GL_Account__c = testData.glAccounts[12].Id,
                    Opening_Balance__c = 0,
                    Amount__c = 900.55,
                    Ledger__c = testData.ledgers[1].Id,
                    Cube_Type__c = 'Retained Earnings'
                ),
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    GL_Account__c = testData.glAccounts[16].Id,
                    Opening_Balance__c = 0,
                    Amount__c = 400.44,
                    Ledger__c = testData.ledgers[1].Id,
                    Cube_Type__c = 'Retained Earnings'
                )
            };
            insert finCubes;
        }
    }

    @IsTest
    private static void testProfitAndLossVsBudget_RoundToNone() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {

            testData.billings = [SELECT Id, Status__c FROM Billing__c];
            testData.payables = [SELECT Id, Status__c FROM Account_Payable__c];

            AbstractPostHandler postHandler;
            List<PostResult> postResults;

            // post billings
            postHandler = new BillingPostHandler();
            postResults = postHandler.post(testData.billings);
            System.assertEquals(true, postResults.get(0).isSuccess);

            // post payables
            postHandler = new AccountPayablePostHandler();
            postResults = postHandler.post(testData.payables);
            System.assertEquals(true, postResults.get(0).isSuccess);

            ProfitAndLossVsBudgetFinReptOptions options = new ProfitAndLossVsBudgetFinReptOptions();
            options.ledger = testData.ledgers[0].Id;
            options.budgetLedger = testData.ledgers[1].Id;
            options.startingAccountingPeriod = testData.acctPeriods[0].Id;
            options.endingAccountingPeriod = testData.acctPeriods[1].Id;
            options.showAllPeriods = true;
            options.setRoundingMode(FinancialReportOptions.FinancialReportRoundingMode.NO_ROUNDING);

            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(true, sr.isSuccess, 'The report run should be started successful.');
            System.assertNotEquals(null, sr.data, 'The report result ID should be returned');

            FinancialReportWrapper frw = FinancialReporterHelper.getFinancialReportResultsById(sr.data);
            System.assertNotEquals(null, frw, 'The completed report results should exist.');

            List<Financial_Report_Result_Value__c> expect = new List<Financial_Report_Result_Value__c> {
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[10].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 4161.56
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[10].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = 10500.55
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[10].Name,
                    Column_Header_1__c = cLabelActualTotal,
                    Currency_Value__c = 14662.11
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[10].Name,
                    Column_Header_1__c = cLabelBudgetTotal,
                    Currency_Value__c = 5400.55
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[10].Name,
                    Column_Header_1__c = cLabelDifference,
                    Currency_Value__c = 9261.56
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[10].Name,
                    Column_Header_1__c = cLabelBudgetPercent,
                    Currency_Value__c = 271.49
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[11].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 150700.40
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[11].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -6000.22
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[11].Name,
                    Column_Header_1__c = cLabelActualTotal,
                    Currency_Value__c = 144700.18
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[11].Name,
                    Column_Header_1__c = cLabelBudgetTotal,
                    Currency_Value__c = 55500.44
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[11].Name,
                    Column_Header_1__c = cLabelDifference,
                    Currency_Value__c = 89199.74
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[11].Name,
                    Column_Header_1__c = cLabelBudgetPercent,
                    Currency_Value__c = 260.72
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[12].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 900.40
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[12].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = 15501.75
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[12].Name,
                    Column_Header_1__c = cLabelActualTotal,
                    Currency_Value__c = 16402.15
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[12].Name,
                    Column_Header_1__c = cLabelBudgetTotal,
                    Currency_Value__c = 900.55
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[12].Name,
                    Column_Header_1__c = cLabelDifference,
                    Currency_Value__c = 15501.60
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[12].Name,
                    Column_Header_1__c = cLabelBudgetPercent,
                    Currency_Value__c = 1821.35
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[16].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 100.40
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[16].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -4560.22
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[16].Name,
                    Column_Header_1__c = cLabelActualTotal,
                    Currency_Value__c = -4459.82
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[16].Name,
                    Column_Header_1__c = cLabelBudgetTotal,
                    Currency_Value__c = 400.44
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[16].Name,
                    Column_Header_1__c = cLabelDifference,
                    Currency_Value__c = -4860.26
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[16].Name,
                    Column_Header_1__c = cLabelBudgetPercent,
                    Currency_Value__c = -1113.73
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalRev,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 154861.96
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalRev,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = 4500.33
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalRev,
                    Column_Header_1__c = cLabelActualTotal,
                    Currency_Value__c = 159362.29
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalRev,
                    Column_Header_1__c = cLabelBudgetTotal,
                    Currency_Value__c = 60900.99
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalRev,
                    Column_Header_1__c = cLabelDifference,
                    Currency_Value__c = 98461.3
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalRev,
                    Column_Header_1__c = cLabelBudgetPercent,
                    Currency_Value__c = 261.67
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalExp,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 1000.80
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalExp,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = 10941.53
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalExp,
                    Column_Header_1__c = cLabelActualTotal,
                    Currency_Value__c = 11942.33
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalExp,
                    Column_Header_1__c = cLabelBudgetTotal,
                    Currency_Value__c = 1300.99
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalExp,
                    Column_Header_1__c = cLabelDifference,
                    Currency_Value__c = 10641.34
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalExp,
                    Column_Header_1__c = cLabelBudgetPercent,
                    Currency_Value__c = 917.94
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelNetIncome,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 153861.16
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelNetIncome,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -6441.20
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelNetIncome,
                    Column_Header_1__c = cLabelActualTotal,
                    Currency_Value__c = 147419.96
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelNetIncome,
                    Column_Header_1__c = cLabelBudgetTotal,
                    Currency_Value__c = 59600
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelNetIncome,
                    Column_Header_1__c = cLabelDifference,
                    Currency_Value__c = 87819.96
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelNetIncome,
                    Column_Header_1__c = cLabelBudgetPercent,
                    Currency_Value__c = 247.35
                )
            };

            validateResultValues(frw, expect);
        }
    }

    @IsTest
    private static void testProfitAndLossVsBudget_RoundToWholeAmounts() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            testData.billings = [SELECT Id, Status__c FROM Billing__c];
            testData.payables = [SELECT Id, Status__c FROM Account_Payable__c];

            AbstractPostHandler postHandler;
            List<PostResult> postResults;

            // post billings
            postHandler = new BillingPostHandler();
            postResults = postHandler.post(testData.billings);
            System.assertEquals(true, postResults.get(0).isSuccess);

            // post payables
            postHandler = new AccountPayablePostHandler();
            postResults = postHandler.post(testData.payables);
            System.assertEquals(true, postResults.get(0).isSuccess);

            ProfitAndLossVsBudgetFinReptOptions options = new ProfitAndLossVsBudgetFinReptOptions();
            options.ledger = testData.ledgers[0].Id;
            options.budgetLedger = testData.ledgers[1].Id;
            options.startingAccountingPeriod = testData.acctPeriods[0].Id;
            options.endingAccountingPeriod = testData.acctPeriods[1].Id;
            options.showAllPeriods = true;
            options.setRoundingMode(FinancialReportOptions.FinancialReportRoundingMode.WHOLE_AMOUNTS);

            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(true, sr.isSuccess, 'The report run should be started successful.');
            System.assertNotEquals(null, sr.data, 'The report result ID should be returned');

            FinancialReportWrapper frw = FinancialReporterHelper.getFinancialReportResultsById(sr.data);
            System.assertNotEquals(null, frw, 'The completed report results should exist.');

            List<Financial_Report_Result_Value__c> expect = new List<Financial_Report_Result_Value__c> {
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[10].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 4162
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[10].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = 10501
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[10].Name,
                    Column_Header_1__c = cLabelActualTotal,
                    Currency_Value__c = 14663
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[10].Name,
                    Column_Header_1__c = cLabelBudgetTotal,
                    Currency_Value__c = 5401
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[10].Name,
                    Column_Header_1__c = cLabelDifference,
                    Currency_Value__c = 9262
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[10].Name,
                    Column_Header_1__c = cLabelBudgetPercent,
                    Currency_Value__c = 271.49
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[11].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 150700
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[11].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -6000
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[11].Name,
                    Column_Header_1__c = cLabelActualTotal,
                    Currency_Value__c = 144700
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[11].Name,
                    Column_Header_1__c = cLabelBudgetTotal,
                    Currency_Value__c = 55500
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[11].Name,
                    Column_Header_1__c = cLabelDifference,
                    Currency_Value__c = 89200
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[11].Name,
                    Column_Header_1__c = cLabelBudgetPercent,
                    Currency_Value__c = 260.72
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[12].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 900
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[12].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = 15502
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[12].Name,
                    Column_Header_1__c = cLabelActualTotal,
                    Currency_Value__c = 16402
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[12].Name,
                    Column_Header_1__c = cLabelBudgetTotal,
                    Currency_Value__c = 901
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[12].Name,
                    Column_Header_1__c = cLabelDifference,
                    Currency_Value__c = 15501
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[12].Name,
                    Column_Header_1__c = cLabelBudgetPercent,
                    Currency_Value__c = 1820.42
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[16].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 100
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[16].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -4560
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[16].Name,
                    Column_Header_1__c = cLabelActualTotal,
                    Currency_Value__c = -4460
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[16].Name,
                    Column_Header_1__c = cLabelBudgetTotal,
                    Currency_Value__c = 400
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[16].Name,
                    Column_Header_1__c = cLabelDifference,
                    Currency_Value__c = -4860
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[16].Name,
                    Column_Header_1__c = cLabelBudgetPercent,
                    Currency_Value__c = -1115.00
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalRev,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 154862
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalRev,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = 4501
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalRev,
                    Column_Header_1__c = cLabelActualTotal,
                    Currency_Value__c = 159363
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalRev,
                    Column_Header_1__c = cLabelBudgetTotal,
                    Currency_Value__c = 60901
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalRev,
                    Column_Header_1__c = cLabelDifference,
                    Currency_Value__c = 98462
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalRev,
                    Column_Header_1__c = cLabelBudgetPercent,
                    Currency_Value__c = 261.68
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalExp,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 1000
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalExp,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = 10942
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalExp,
                    Column_Header_1__c = cLabelActualTotal,
                    Currency_Value__c = 11942
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalExp,
                    Column_Header_1__c = cLabelBudgetTotal,
                    Currency_Value__c = 1301
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalExp,
                    Column_Header_1__c = cLabelDifference,
                    Currency_Value__c = 10641
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalExp,
                    Column_Header_1__c = cLabelBudgetPercent,
                    Currency_Value__c = 917.91
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelNetIncome,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 153862
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelNetIncome,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -6441
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelNetIncome,
                    Column_Header_1__c = cLabelActualTotal,
                    Currency_Value__c = 147421
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelNetIncome,
                    Column_Header_1__c = cLabelBudgetTotal,
                    Currency_Value__c = 59600
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelNetIncome,
                    Column_Header_1__c = cLabelDifference,
                    Currency_Value__c = 87821
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelNetIncome,
                    Column_Header_1__c = cLabelBudgetPercent,
                    Currency_Value__c = 247.35
                )
            };

            validateResultValues(frw, expect);
        }
    }

    @IsTest
    private static void testProfitAndLossVsBudget_RoundToThousands() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            testData.billings = [SELECT Id, Status__c FROM Billing__c];
            testData.payables = [SELECT Id, Status__c FROM Account_Payable__c];

            AbstractPostHandler postHandler;
            List<PostResult> postResults;

            // post billings
            postHandler = new BillingPostHandler();
            postResults = postHandler.post(testData.billings);
            System.assertEquals(true, postResults.get(0).isSuccess);

            // post payables
            postHandler = new AccountPayablePostHandler();
            postResults = postHandler.post(testData.payables);
            System.assertEquals(true, postResults.get(0).isSuccess);

            ProfitAndLossVsBudgetFinReptOptions options = new ProfitAndLossVsBudgetFinReptOptions();
            options.ledger = testData.ledgers[0].Id;
            options.budgetLedger = testData.ledgers[1].Id;
            options.startingAccountingPeriod = testData.acctPeriods[0].Id;
            options.endingAccountingPeriod = testData.acctPeriods[1].Id;
            options.showAllPeriods = true;
            options.setRoundingMode(FinancialReportOptions.FinancialReportRoundingMode.ROUND_TO_1000);

            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(true, sr.isSuccess, 'The report run should be started successful.');
            System.assertNotEquals(null, sr.data, 'The report result ID should be returned');

            FinancialReportWrapper frw = FinancialReporterHelper.getFinancialReportResultsById(sr.data);
            System.assertNotEquals(null, frw, 'The completed report results should exist.');

            List<Financial_Report_Result_Value__c> expect = new List<Financial_Report_Result_Value__c> {
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[10].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 4
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[10].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = 11
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[10].Name,
                    Column_Header_1__c = cLabelActualTotal,
                    Currency_Value__c = 15
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[10].Name,
                    Column_Header_1__c = cLabelBudgetTotal,
                    Currency_Value__c = 5
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[10].Name,
                    Column_Header_1__c = cLabelDifference,
                    Currency_Value__c = 10
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[10].Name,
                    Column_Header_1__c = cLabelBudgetPercent,
                    Currency_Value__c = 300.00
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[11].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 151
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[11].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -6
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[11].Name,
                    Column_Header_1__c = cLabelActualTotal,
                    Currency_Value__c = 145
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[11].Name,
                    Column_Header_1__c = cLabelBudgetTotal,
                    Currency_Value__c = 56
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[11].Name,
                    Column_Header_1__c = cLabelDifference,
                    Currency_Value__c = 89
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[11].Name,
                    Column_Header_1__c = cLabelBudgetPercent,
                    Currency_Value__c = 258.93
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[12].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 1
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[12].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = 16
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[12].Name,
                    Column_Header_1__c = cLabelActualTotal,
                    Currency_Value__c = 17
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[12].Name,
                    Column_Header_1__c = cLabelBudgetTotal,
                    Currency_Value__c = 1
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[12].Name,
                    Column_Header_1__c = cLabelDifference,
                    Currency_Value__c = 16
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[12].Name,
                    Column_Header_1__c = cLabelBudgetPercent,
                    Currency_Value__c = 1700.00
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[16].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 0
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[16].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -5
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[16].Name,
                    Column_Header_1__c = cLabelActualTotal,
                    Currency_Value__c = -5
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[16].Name,
                    Column_Header_1__c = cLabelBudgetTotal,
                    Currency_Value__c = 0
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[16].Name,
                    Column_Header_1__c = cLabelDifference,
                    Currency_Value__c = -5
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[16].Name,
                    Column_Header_1__c = cLabelBudgetPercent,
                    Currency_Value__c = null
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalRev,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 155
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalRev,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = 5
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalRev,
                    Column_Header_1__c = cLabelActualTotal,
                    Currency_Value__c = 160
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalRev,
                    Column_Header_1__c = cLabelBudgetTotal,
                    Currency_Value__c = 61
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalRev,
                    Column_Header_1__c = cLabelDifference,
                    Currency_Value__c = 99
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalRev,
                    Column_Header_1__c = cLabelBudgetPercent,
                    Currency_Value__c = 262.30
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalExp,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 1
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalExp,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = 11
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalExp,
                    Column_Header_1__c = cLabelActualTotal,
                    Currency_Value__c = 12
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalExp,
                    Column_Header_1__c = cLabelBudgetTotal,
                    Currency_Value__c = 1
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalExp,
                    Column_Header_1__c = cLabelDifference,
                    Currency_Value__c = 11
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotalExp,
                    Column_Header_1__c = cLabelBudgetPercent,
                    Currency_Value__c = 1200.00
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelNetIncome,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 154
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelNetIncome,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -6
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelNetIncome,
                    Column_Header_1__c = cLabelActualTotal,
                    Currency_Value__c = 148
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelNetIncome,
                    Column_Header_1__c = cLabelBudgetTotal,
                    Currency_Value__c = 60
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelNetIncome,
                    Column_Header_1__c = cLabelDifference,
                    Currency_Value__c = 88
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelNetIncome,
                    Column_Header_1__c = cLabelBudgetPercent,
                    Currency_Value__c = 246.67
                )
            };

            validateResultValues(frw, expect);
        }
    }

    private static void validateResultValues(FinancialReportWrapper frw, List<Financial_Report_Result_Value__c> expect) {
        Map<String,Financial_Report_Result_Value__c> expectRowCol = new Map<String,Financial_Report_Result_Value__c>();
        for (Financial_Report_Result_Value__c v : expect) {
            expectRowCol.put(v.Row_Label__c + v.Column_Header_1__c, v);
        }

        Integer matched = 0;
        for (Financial_Report_Result_Value__c v : frw.reportValues) {
            if (expectRowCol.containsKey(v.Row_Label__c + v.Column_Header_1__c)) {
                System.assertEquals(
                    expectRowCol.get(v.Row_Label__c + v.Column_Header_1__c).Currency_Value__c,
                    v.Currency_Value__c,
                    '[row, col] = [' + v.Row_Label__c + ', ' + v.Column_Header_1__c + ']'
                );
                matched++;
            }
        }

        System.assertEquals(expect.size(), matched, 'The report does not contain all of the expected results.');
    }

}