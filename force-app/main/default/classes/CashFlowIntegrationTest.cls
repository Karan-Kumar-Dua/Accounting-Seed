@IsTest
private class CashFlowIntegrationTest {

    private static final String cLabelYearToDate = 'Year To Date';
    private static final String rLabelBeginningCB = 'Beginning Cash Balance';
    private static final String rLabelOperatingActivities = 'Net cash flow from Operating Activities';
    private static final String rLabelInvestingActivities = 'Net cash flow from Investing Activities';
    private static final String rLabelFinancingActivities = 'Net cash flow from Financing Activities';
    private static final String rLabelNetIncrease = 'Net increase (decrease) in cash';
    private static final String rLabelEndingCB = 'Ending Cash Balance';

    @TestSetup
    private static void createTestData() {
        //  standard test data setup
        TestDataSuite testData = TestDataSuite.getInstance(true).createCashFlowCategories(true);

        System.runAs(testData.users.get(1)) {
            // delete existing periods
            delete testData.acctPeriods;

            // create accounting periods
            testData.acctPeriods = new List<Accounting_Period__c> {
                new Accounting_Period__c(
                    Name = '2021-01',
                    Start_Date__c = Date.newInstance(2021, 1, 1),
                    End_Date__c = Date.newInstance(2021, 1, 31),
                    Status__c = AccountingPeriodActions.OPEN_STATUS
                ),
                new Accounting_Period__c(
                    Name = '2021-02',
                    Start_Date__c = Date.newInstance(2021, 2, 1),
                    End_Date__c = Date.newInstance(2021, 2, 28),
                    Status__c = AccountingPeriodActions.OPEN_STATUS
                ),
                new Accounting_Period__c(
                    Name = '2021-03',
                    Start_Date__c = Date.newInstance(2021, 3, 1),
                    End_Date__c = Date.newInstance(2021, 3, 30),
                    Status__c = AccountingPeriodActions.OPEN_STATUS
                )
            };
            insert testData.acctPeriods;

            // create Journal Entries
            testData.journalEntries = new List<Journal_Entry__c> {
                new Journal_Entry__c(
                    Name = 'Test_JE_1',
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Journal_Date__c = testData.acctPeriods[0].Start_Date__c
                ),
                new Journal_Entry__c(
                    Name = 'Test_JE_2',
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Journal_Date__c = testData.acctPeriods[1].Start_Date__c
                )
            };
            insert testData.journalEntries;

            // create Journal Entry Lines
            testData.journalEntryLines = new List<Journal_Entry_Line__c> {
                //Lines for Test_JE_1
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testData.journalEntries[0].Id,
                    Debit__c = 4161.56,
                    GL_Account__c = testData.glAccounts[0].Id,//1000-Cash
                    Cash_Flow_Category__c = testData.cashFlowCategories[1].Id //Payments to suppliers
                ),
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testData.journalEntries[0].Id,
                    Debit__c = 150700.40,
                    GL_Account__c = testData.glAccounts[0].Id,//1000-Cash
                    Cash_Flow_Category__c = testData.cashFlowCategories[0].Id //Receipts from customers
                ),
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testData.journalEntries[0].Id,
                    Debit__c = 900.40,
                    GL_Account__c = testData.glAccounts[0].Id,//1000-Cash
                    Cash_Flow_Category__c = testData.cashFlowCategories[7].Id //Proceeds from sale of fixed assets
                ),
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testData.journalEntries[0].Id,
                    Debit__c = 100.40,
                    GL_Account__c = testData.glAccounts[0].Id,//1000-Cash
                    Cash_Flow_Category__c = testData.cashFlowCategories[8].Id //Payment for fixed assets
                ),
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testData.journalEntries[0].Id,
                    Credit__c = 546.66,
                    GL_Account__c = testData.glAccounts[0].Id,//1000-Cash
                    Cash_Flow_Category__c = testData.cashFlowCategories[10].Id //Proceeds from issuance of debt
                ),
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testData.journalEntries[0].Id,
                    Credit__c = 154081.65,
                    GL_Account__c = testData.glAccounts[0].Id,//1000-Cash
                    Cash_Flow_Category__c = testData.cashFlowCategories[11].Id //Repayment of debt
                ),
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testData.journalEntries[0].Id,
                    Credit__c = 1234.45,
                    GL_Account__c = testData.glAccounts[12].Id//5000-Cost of Goods Sold
                ),
                //Lines for Test_JE_2
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testData.journalEntries[1].Id,
                    Credit__c = 5000,
                    GL_Account__c = testData.glAccounts[0].Id,//1000-Cash
                    Cash_Flow_Category__c = testData.cashFlowCategories[1].Id //Payments to suppliers
                ),
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testData.journalEntries[1].Id,
                    Credit__c = 90744.45,
                    GL_Account__c = testData.glAccounts[0].Id,//1000-Cash
                    Cash_Flow_Category__c = testData.cashFlowCategories[0].Id //Receipts from customers
                ),
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testData.journalEntries[1].Id,
                    Credit__c = 8060.4,
                    GL_Account__c = testData.glAccounts[0].Id,//1000-Cash
                    Cash_Flow_Category__c = testData.cashFlowCategories[7].Id //Proceeds from sale of fixed assets
                ),
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testData.journalEntries[1].Id,
                    Credit__c = 6700.4,
                    GL_Account__c = testData.glAccounts[0].Id,//1000-Cash
                    Cash_Flow_Category__c = testData.cashFlowCategories[8].Id //Payment for fixed assets
                ),
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testData.journalEntries[1].Id,
                    Debit__c = 1576.66,
                    GL_Account__c = testData.glAccounts[0].Id,//1000-Cash
                    Cash_Flow_Category__c = testData.cashFlowCategories[10].Id //Proceeds from issuance of debt
                ),
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testData.journalEntries[1].Id,
                    Debit__c = 103928.59,
                    GL_Account__c = testData.glAccounts[0].Id,//1000-Cash
                    Cash_Flow_Category__c = testData.cashFlowCategories[11].Id //Repayment of debt
                ),
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testData.journalEntries[1].Id,
                    Debit__c = 5000,
                    GL_Account__c = testData.glAccounts[12].Id//5000-Cost of Goods Sold
                )
            };
            insert testData.journalEntryLines;

            AbstractPostHandler postHandler;
            List<PostResult> postResults;

            // post Journal Entries
            postHandler = new JournalEntryPostHandler();
            postResults = postHandler.post(testData.journalEntries);
            System.assertEquals(true, postResults.get(0).isSuccess);

            //Close periods 2021-01 & 2021-02 for real (with real batch execution)
            Test.startTest();
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            testData.acctPeriods[1].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update new List<Accounting_Period__c>{testData.acctPeriods[0], testData.acctPeriods[1]};
            Test.stopTest();
        }
    }

    @IsTest
    private static void testCashFlow_RoundToNone() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.cashFlowCategories = [SELECT Id, Name FROM GL_Account__c WHERE Type__c = 'Cash Flow'];

        System.runAs(testData.users.get(1)) {
            CashFlowFinancialReportOptions options = new CashFlowFinancialReportOptions();
            options.ledger = testData.ledgers[0].Id;
            options.startingAccountingPeriod = testData.acctPeriods[1].Id;
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
                    Row_Label__c = rLabelBeginningCB,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 0
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelBeginningCB,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = 1234.45
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelBeginningCB,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = 0
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[0].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 150700.40
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[0].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -90744.45
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[0].Name,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = 59955.95
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[1].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 4161.56
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[1].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -5000.00
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[1].Name,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = -838.44
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelOperatingActivities,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 154861.96
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelOperatingActivities,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -95744.45
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelOperatingActivities,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = 59117.51
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[7].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 900.40
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[7].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -8060.40
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[7].Name,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = -7160.00
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[8].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 100.40
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[8].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -6700.40
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[8].Name,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = -6600.00
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelInvestingActivities,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 1000.80
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelInvestingActivities,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -14760.80
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelInvestingActivities,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = -13760.00
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[10].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = -546.66
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[10].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = 1576.66
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[10].Name,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = 1030.00
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[11].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = -154081.65
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[11].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = 103928.59
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[11].Name,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = -50153.06
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelFinancingActivities,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = -154628.31
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelFinancingActivities,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = 105505.25
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelFinancingActivities,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = -49123.06
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelNetIncrease,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 1234.45
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelNetIncrease,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -5000.00
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelNetIncrease,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = -3765.55
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelEndingCB,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 1234.45
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelEndingCB,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -3765.55
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelEndingCB,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = -3765.55
                )

            };

            validateResultValues(frw, expect);
        }
    }

    @IsTest
    private static void testCashFlow_RoundToWholeAmounts() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.cashFlowCategories = [SELECT Id, Name FROM GL_Account__c WHERE Type__c = 'Cash Flow'];

        System.runAs(testData.users.get(1)) {
            CashFlowFinancialReportOptions options = new CashFlowFinancialReportOptions();
            options.ledger = testData.ledgers[0].Id;
            options.startingAccountingPeriod = testData.acctPeriods[1].Id;
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
                    Row_Label__c = rLabelBeginningCB,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 0
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelBeginningCB,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = 1234
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelBeginningCB,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = 0
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[0].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 150700
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[0].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -90744
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[0].Name,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = 59956
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[1].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 4162
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[1].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -5000
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[1].Name,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = -838
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelOperatingActivities,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 154862
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelOperatingActivities,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -95744
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelOperatingActivities,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = 59118
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[7].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 900
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[7].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -8060
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[7].Name,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = -7160
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[8].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 100
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[8].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -6700
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[8].Name,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = -6600
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelInvestingActivities,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 1000
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelInvestingActivities,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -14760
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelInvestingActivities,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = -13760
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[10].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = -547
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[10].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = 1577
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[10].Name,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = 1030
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[11].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = -154082
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[11].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = 103929
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[11].Name,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = -50153
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelFinancingActivities,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = -154629
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelFinancingActivities,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = 105506
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelFinancingActivities,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = -49123
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelNetIncrease,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 1234
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelNetIncrease,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -5000
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelNetIncrease,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = -3766
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelEndingCB,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 1234
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelEndingCB,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -3766
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelEndingCB,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = -3766
                )
            };

            validateResultValues(frw, expect);
        }
    }

    @IsTest
    private static void testCashFlow_RoundToThousands() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.cashFlowCategories = [SELECT Id, Name FROM GL_Account__c WHERE Type__c = 'Cash Flow'];

        System.runAs(testData.users.get(1)) {
            CashFlowFinancialReportOptions options = new CashFlowFinancialReportOptions();
            options.ledger = testData.ledgers[0].Id;
            options.startingAccountingPeriod = testData.acctPeriods[1].Id;
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
                    Row_Label__c = rLabelBeginningCB,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 0
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelBeginningCB,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = 1
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelBeginningCB,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = 0
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[0].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 151
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[0].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -91
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[0].Name,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = 60
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[1].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 4
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[1].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -5
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[1].Name,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = -1
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelOperatingActivities,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 155
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelOperatingActivities,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -96
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelOperatingActivities,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = 59
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[7].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 1
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[7].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -8
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[7].Name,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = -7
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[8].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 0
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[8].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -7
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[8].Name,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = -7
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelInvestingActivities,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 1
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelInvestingActivities,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -15
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelInvestingActivities,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = -14
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[10].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = -1
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[10].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = 2
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[10].Name,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = 1
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[11].Name,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = -154
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[11].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = 104
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.cashFlowCategories[11].Name,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = -50
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelFinancingActivities,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = -155
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelFinancingActivities,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = 106
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelFinancingActivities,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = -49
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelNetIncrease,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 1
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelNetIncrease,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -5
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelNetIncrease,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = -4
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelEndingCB,
                    Column_Header_1__c = testData.acctPeriods[0].Name,
                    Currency_Value__c = 1
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelEndingCB,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -4
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelEndingCB,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = -4
                )
            };

            validateResultValues(frw, expect);
        }
    }

    private static void validateResultValues(FinancialReportWrapper frw, List<Financial_Report_Result_Value__c> expect) {
        Map<String, Financial_Report_Result_Value__c> expectRowCol = new Map<String, Financial_Report_Result_Value__c>();
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