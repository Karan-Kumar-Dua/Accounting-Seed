@IsTest
private class TrialBalanceIntegrationTest {
    private static final String cLabelOpeningBalance = 'Opening Balance';
    private static final String cLabelYearToDate = 'Year To Date';
    private static final String rLabelTotal = Label.COMMON_TOTAL;

    @TestSetup
    private static void createTestData() {
        //  standard test data setup
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users.get(1)) {
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
                ),
                new Accounting_Period__c(
                    Name = '2021-06',
                    Start_Date__c = Date.newInstance(2021, 6, 1),
                    End_Date__c = Date.newInstance(2021, 6, 30),
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

            GL_Account__c payrollGlAccount = testData.glAccounts[30];

            // create Journal Entry Lines
            testData.journalEntryLines = new List<Journal_Entry_Line__c> {
                //Lines for Test_JE_1
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testData.journalEntries[0].Id,
                    Debit__c = 4161.56,
                    GL_Account__c = testData.glAccounts[0].Id//1000-Cash
                ),
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testData.journalEntries[0].Id,
                    Debit__c = 150700.40,
                    GL_Account__c = testData.glAccounts[23].Id//1400-Prepaid Expenses
                ),
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testData.journalEntries[0].Id,
                    Debit__c = 900.40,
                    GL_Account__c = testData.glAccounts[6].Id//2020-Accrued Expenses
                ),
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testData.journalEntries[0].Id,
                    Debit__c = 100.40,
                    GL_Account__c = payrollGlAccount.Id//2030-Accrued Payroll
                ),
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testData.journalEntries[0].Id,
                    Credit__c = 546.66,
                    GL_Account__c = testData.glAccounts[7].Id//3000-Owners Equity
                ),
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testData.journalEntries[0].Id,
                    Credit__c = 155316.1,
                    GL_Account__c = testData.glAccounts[10].Id//4000-Product Revenue
                ),
                //Lines for Test_JE_2
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testData.journalEntries[1].Id,
                    Credit__c = 5000,
                    GL_Account__c = testData.glAccounts[0].Id//1000-Cash
                ),
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testData.journalEntries[1].Id,
                    Credit__c = 90744.45,
                    GL_Account__c = testData.glAccounts[23].Id//1400-Prepaid Expenses
                ),
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testData.journalEntries[1].Id,
                    Credit__c = 8060.4,
                    GL_Account__c = testData.glAccounts[6].Id//2020-Accrued Expenses
                ),
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testData.journalEntries[1].Id,
                    Credit__c = 1700.4,
                    GL_Account__c = payrollGlAccount.Id//2030-Accrued Payroll
                ),
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testData.journalEntries[1].Id,
                    Debit__c = 1576.66,
                    GL_Account__c = testData.glAccounts[7].Id//3000-Owners Equity
                ),
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testData.journalEntries[1].Id,
                    Debit__c = 103928.59,
                    GL_Account__c = testData.glAccounts[10].Id//4000-Product Revenue
                )
            };
            insert testData.journalEntryLines;

            AbstractPostHandler postHandler;
            List<PostResult> postResults;

            // post Journal Entries
            postHandler = new JournalEntryPostHandler();
            postResults = postHandler.post(testData.journalEntries);
            System.assertEquals(true, postResults.get(0).isSuccess);

            //Close period 2021-04 for real (with real batch execution)
            Test.startTest();
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];
            Test.stopTest();
        }
    }

    @IsTest
    private static void testTrialBalance_RoundToNone() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            TrialBalanceFinancialReportOptions options = new TrialBalanceFinancialReportOptions();
            options.ledger = testData.ledgers[0].Id;
            options.startingAccountingPeriod = testData.acctPeriods[1].Id;

            Test.startTest();
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(true, sr.isSuccess, 'The report run should be started successful.');
            System.assertNotEquals(null, sr.data, 'The report result ID should be returned');

            FinancialReportWrapper frw = FinancialReporterHelper.getFinancialReportResultsById(sr.data);
            System.assertNotEquals(null, frw, 'The completed report results should exist.');

            GL_Account__c payrollGlAccount = [SELECT Id, Name FROM GL_Account__c WHERE Name = '2030-Accrued Payroll'];

            List<Financial_Report_Result_Value__c> expect = new List<Financial_Report_Result_Value__c> {
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[0].Name,
                    Column_Header_1__c = cLabelOpeningBalance,
                    Currency_Value__c = 4161.56
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[0].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -5000
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[0].Name,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = -838.44
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[23].Name,
                    Column_Header_1__c = cLabelOpeningBalance,
                    Currency_Value__c = 150700.40
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[23].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -90744.45
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[23].Name,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = 59955.95
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[6].Name,
                    Column_Header_1__c = cLabelOpeningBalance,
                    Currency_Value__c = 900.40
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[6].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -8060.40
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[6].Name,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = -7160.00
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = payrollGlAccount.Name,
                    Column_Header_1__c = cLabelOpeningBalance,
                    Currency_Value__c = 100.40
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = payrollGlAccount.Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = -1700.40
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = payrollGlAccount.Name,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = -1600.00
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[7].Name,
                    Column_Header_1__c = cLabelOpeningBalance,
                    Currency_Value__c = -546.66
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[7].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = 1576.66
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[7].Name,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = 1030
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[10].Name,
                    Column_Header_1__c = cLabelOpeningBalance,
                    Currency_Value__c = -155316.10
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[10].Name,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = 103928.59
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = testData.glAccounts[10].Name,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = -51387.51
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotal,
                    Column_Header_1__c = cLabelOpeningBalance,
                    Currency_Value__c = 0
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotal,
                    Column_Header_1__c = testData.acctPeriods[1].Name,
                    Currency_Value__c = 0
                ),
                new Financial_Report_Result_Value__c(
                    Row_Label__c = rLabelTotal,
                    Column_Header_1__c = cLabelYearToDate,
                    Currency_Value__c = 0
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