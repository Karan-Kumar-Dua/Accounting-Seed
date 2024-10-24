@IsTest
public class ReportTableControllerTest {

    @TestSetup
    private static void createTestData() {
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.archiveOldAccountingPeriods();
            testData.createAccountingPeriodSetBasedOnCurrentDate();

            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            //Create and post Billing records for closed accounting periods
            List<Billing__c> testBillings = new List<Billing__c>{
                createBilling(
                    testData.accounts.get(0),
                    AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(currentPeriod, -3)
                ),
                createBilling(
                    testData.accounts.get(0),
                    AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(currentPeriod, -2)
                ),
                createBilling(
                    testData.accounts.get(0),
                    AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(currentPeriod, -1)
                )
            };
            List<PostResult> postResults = new BillingPostHandler().post(testBillings);
            System.assertEquals(3, postResults.size());
            System.assertEquals(true, postResults[0].isSuccess);
            System.assertEquals(true, postResults[1].isSuccess);
            System.assertEquals(true, postResults[2].isSuccess);

            testData.closePreviousAccountingPeriodsBasedOnCurrentDate();
        }
    }

    private static Billing__c createBilling(Account customer, Accounting_Period__c acctPeriod) {
        Billing__c billing = new Billing__c(
            Billing_Cycle_Start_Date__c = acctPeriod.Start_Date__c,
            Billing_Cycle_End_Date__c = acctPeriod.End_Date__c,
            Date__c = acctPeriod.Start_Date__c,
            Customer__c = customer.Id,
            Accounting_Period__c = acctPeriod.Id,
            Due_Date2__c = acctPeriod.Start_Date__c.addDays(30)
        );
        insert billing;

        Billing_Line__c billingLine = new Billing_Line__c(
            Billing__c = billing.Id,
            Date__c = acctPeriod.Start_Date__c,
            Hours_Units__c = 1,
            Rate__c = 100
        );
        insert billingLine;

        return billing;
    }
    
    @IsTest
    public static void testReportTableController() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            ProfitAndLossFinancialReportOptions reportOptions = new ProfitAndLossFinancialReportOptions();
            ProfitAndLossFinancialReport pnlReportClassInstance = new ProfitAndLossFinancialReport();

            ReportTableController rtc = new ReportTableController();
            rtc.startPeriodName = AccountingPeriodHandler.getInstance().getAccountingPeriodById(reportOptions.startingAccountingPeriod).Name;
            Test.startTest();
            rtc.frw = pnlReportClassInstance.runReport(reportOptions);
            Test.stopTest();
            List<ReportTableController.ReportValue> values;
            try {
                values = rtc.reportValueRows.get(rtc.reportValueRows.size() - 1).values;
            }
            catch (Exception ex) {
                values = new List<ReportTableController.ReportValue>();
            }
            for (ReportTableController.ReportValue v : values) {

                System.assertEquals(v.reportVal.Currency_Value__c == NULL ? false : true, v.getIsCurrency());
            }
        }
    }

    @IsTest
    public static void testMapRowPositionToRowRecord() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            List<Financial_Report_Row__c> rowList = new List<Financial_Report_Row__c>();

            Financial_Report_Row__c row1 = new Financial_Report_Row__c();
            row1.Position__c = 10;
            rowList.add(row1);

            Financial_Report_Row__c row2 = new Financial_Report_Row__c();
            row2.Position__c = 20;
            rowList.add(row2);

            Financial_Report_Row__c row3 = new Financial_Report_Row__c();
            row3.Position__c = 30;
            rowList.add(row3);

            Test.startTest();

            ReportTableController controller = new ReportTableController();
            Map<Integer, Financial_Report_Row__c> result = controller.mapRowPositionToRowRecord(rowList);

            Test.stopTest();

            System.assertEquals(true, result.containsKey(10));
            System.assertEquals(true, result.containsKey(20));
            System.assertEquals(true, result.containsKey(30));
            System.assertEquals(true, result.get(30).Position__c.intValue() == 30);
        }
    }

    @IsTest
    public static void testMapRowPositionToGLAccount() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            List<Financial_Report_Row__c> rowList = new List<Financial_Report_Row__c>();

            Financial_Report_Row__c row1 = new Financial_Report_Row__c();
            row1.Position__c = 10;
            row1.GL_Account__c = testData.glAccounts[0].Id;
            rowList.add(row1);

            Financial_Report_Row__c row2 = new Financial_Report_Row__c();
            row2.Position__c = 20;
            row2.GL_Account__c = testData.glAccounts[1].Id;
            rowList.add(row2);

            Financial_Report_Row__c row3 = new Financial_Report_Row__c();
            row3.Position__c = 30;
            row3.GL_Account__c = testData.glAccounts[2].Id;
            rowList.add(row3);

            Test.startTest();

            ReportTableController controller = new ReportTableController();
            Map<Integer, Id> result = controller.mapRowPositionToGLAccount(rowList);

            Test.stopTest();

            System.assertEquals(true, result.containsKey(10));
            System.assertEquals(true, result.containsKey(20));
            System.assertEquals(true, result.containsKey(30));
            System.assertEquals(true, result.get(10) == testData.glAccounts[0].Id);
        }

    }

    @IsTest
    public static void testReportTableControllerReportSettingsLoaded() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createReportDefinitions()
            .createGlReportingGroups()
            .createGlReportingGroupLines()
            .createReportRows()
            .createReportColumns()
            .createFinancialReportResults();

        System.runAs(testData.users.get(1)) {

            // udpate settings
            Financial_Reporter_Settings__c settings = FinancialReporterSettingsHandler.getNewSettings();
            settings.Company_Name__c = 'Accounting Seed';
            FinancialReporterSettingsActions.isDmlRestrictionBypassEnabled = true;
            insert settings;
            FinancialReporterSettingsActions.isDmlRestrictionBypassEnabled = false;

            testData.ledgers[1].Financial_Reporter_Settings__c = settings.Id;
            update testData.ledgers[1];

            // construct report info
            FinancialReportWrapper frw = new FinancialReportWrapper();
            frw.reportDefinition = testData.reportDefs[0];
            frw.colList = testData.reportCols;
            frw.rowList = testData.reportRows;
            frw.reportResult = testData.financialReportResults[0];
            frw.reportValues = new List<Financial_Report_Result_Value__c> {
                new Financial_Report_Result_Value__c(
                    Number_Value__c = 100,
                    Row_Position__c = 1,
                    Column_Position__c = 1,
                    Row_Type__c = 'Calculation Number'
                )
            };

            // create test subject
            ReportTableController rtc = new ReportTableController();
            rtc.currentPeriodName = rtc.startPeriodName = AccountingPeriodHandler.getInstance().getAccountingPeriodById(testData.acctPeriods[0].Id).Name;
            rtc.startPeriodName = rtc.currentPeriodName;

            Test.startTest();
            // work happens when FinancialReportWrapper is assigned
            rtc.frw = frw;
            Test.stopTest();
            
            System.assertEquals(settings.Company_Name__c, rtc.companyName);
        }
    }

    @IsTest
    public static void testReportTableControllerReportSettingsNoApplyToCustom() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createReportDefinitions()
            .createGlReportingGroups()
            .createGlReportingGroupLines()
            .createReportRows()
            .createReportColumns()
            .createFinancialReportResults();

        System.runAs(testData.users.get(1)) {

            // udpate settings
            Financial_Reporter_Settings__c settings = FinancialReporterSettingsHandler.getNewSettings();
            settings.Company_Name__c = 'Accounting Seed';
            settings.Column_Header_Variant__c = 'MM/YY';
            FinancialReporterSettingsActions.isDmlRestrictionBypassEnabled = true;
            insert settings;
            FinancialReporterSettingsActions.isDmlRestrictionBypassEnabled = false;

            testData.ledgers[1].Financial_Reporter_Settings__c = settings.Id;
            update testData.ledgers[1];

            // construct report info
            FinancialReportWrapper frw = new FinancialReportWrapper();
            frw.reportDefinition = testData.reportDefs[0];
            frw.colList = testData.reportCols;
            frw.rowList = testData.reportRows;
            frw.reportResult = testData.financialReportResults[0];
            frw.reportValues = new List<Financial_Report_Result_Value__c> {
                new Financial_Report_Result_Value__c(
                    Number_Value__c = 100,
                    Row_Position__c = 1,
                    Column_Position__c = 1,
                    Row_Type__c = 'Blank',
                    Column_Type__c = 'Current Period',
                    Column_Header_1__c = '1991-10'
                )
            };

            // create test subject
            ReportTableController rtc = new ReportTableController();
            rtc.currentPeriodName = rtc.startPeriodName = AccountingPeriodHandler.getInstance().getAccountingPeriodById(testData.acctPeriods[0].Id).Name;
            rtc.startPeriodName = rtc.currentPeriodName;

            Test.startTest();
            // work happens when FinancialReportWrapper is assigned
            rtc.frw = frw;
            Test.stopTest();

            System.assertEquals('1991-10',rtc.headers[0]);

        }
    }


    @IsTest
    public static void testReportTableControllerReportSettingsPeriodFormatMMYYYY() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createReportDefinitions()
            .createGlReportingGroups()
            .createGlReportingGroupLines()
            .createReportRows()
            .createReportColumns()
            .createFinancialReportResults();

        System.runAs(testData.users.get(1)) {

            // udpate settings
            Financial_Reporter_Settings__c settings = FinancialReporterSettingsHandler.getNewSettings();
            settings.Company_Name__c = 'Accounting Seed';
            settings.Column_Header_Variant__c = 'MM/YY';
            FinancialReporterSettingsActions.isDmlRestrictionBypassEnabled = true;
            insert settings;
            FinancialReporterSettingsActions.isDmlRestrictionBypassEnabled = false;

            testData.ledgers[1].Financial_Reporter_Settings__c = settings.Id;
            update testData.ledgers[1];

            // construct report info
            FinancialReportWrapper frw = new FinancialReportWrapper();
            frw.colList = testData.reportCols;
            frw.rowList = testData.reportRows;
            frw.reportResult = testData.financialReportResults[0];
            frw.reportValues = new List<Financial_Report_Result_Value__c> {
                new Financial_Report_Result_Value__c(
                    Number_Value__c = 100,
                    Row_Position__c = 1,
                    Column_Position__c = 1,
                    Row_Type__c = 'Blank',
                    Column_Type__c = 'Current Period',
                    Column_Header_1__c = '1991-10'
                )
            };

            // create test subject
            ReportTableController rtc = new ReportTableController();
            rtc.currentPeriodName = rtc.startPeriodName = AccountingPeriodHandler.getInstance().getAccountingPeriodById(testData.acctPeriods[0].Id).Name;
            rtc.startPeriodName = rtc.currentPeriodName;

            Test.startTest();
            // work happens when FinancialReportWrapper is assigned
            rtc.frw = frw;
            Test.stopTest();
            
            System.assertEquals('10/1991',rtc.headers[0]);
            System.assertEquals(settings.Company_Name__c, rtc.companyName);
        }
    }

    @IsTest
    public static void testReportTableControllerReportSettingsPeriodFormatEndDate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createReportDefinitions()
            .createGlReportingGroups()
            .createGlReportingGroupLines()
            .createReportRows()
            .createReportColumns()
            .createFinancialReportResults();

        System.runAs(testData.users.get(1)) {

            // udpate settings
            Financial_Reporter_Settings__c settings = FinancialReporterSettingsHandler.getNewSettings();
            settings.Company_Name__c = 'Accounting Seed';
            settings.Column_Header_Variant__c = 'Period End Date';
            FinancialReporterSettingsActions.isDmlRestrictionBypassEnabled = true;
            insert settings;
            FinancialReporterSettingsActions.isDmlRestrictionBypassEnabled = false;

            testData.ledgers[1].Financial_Reporter_Settings__c = settings.Id;
            update testData.ledgers[1];

            // construct report info
            FinancialReportWrapper frw = new FinancialReportWrapper();
            frw.colList = testData.reportCols;
            frw.rowList = testData.reportRows;
            frw.reportResult = testData.financialReportResults[0];
            frw.reportValues = new List<Financial_Report_Result_Value__c> {
                new Financial_Report_Result_Value__c(
                    Number_Value__c = 100,
                    Row_Position__c = 1,
                    Column_Position__c = 1,
                    Row_Type__c = 'Blank',
                    Column_Type__c = 'Current Period',
                    Column_Header_1__c = '1991-10'
                )
            };

            // create test subject
            ReportTableController rtc = new ReportTableController();
            rtc.currentPeriodName = rtc.startPeriodName = AccountingPeriodHandler.getInstance().getAccountingPeriodById(testData.acctPeriods[0].Id).Name;
            rtc.startPeriodName = rtc.currentPeriodName;

            Test.startTest();
            // work happens when FinancialReportWrapper is assigned
            rtc.frw = frw;
            Test.stopTest();
            String expected = Date.newInstance(1991, 10, 31).format();

            System.assertEquals(expected, rtc.headers[0]);
            System.assertEquals(settings.Company_Name__c, rtc.companyName);
        }
    }

    @IsTest
    public static void testReportTableControllerReportSettingsPeriodFormatEndDateWithOffset() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createReportDefinitions()
            .createGlReportingGroups()
            .createGlReportingGroupLines()
            .createReportRows()
            .createReportColumns()
            .createFinancialReportResults();

        System.runAs(testData.users.get(1)) {

            // udpate settings
            Financial_Reporter_Settings__c settings = FinancialReporterSettingsHandler.getNewSettings();
            settings.Company_Name__c = 'Accounting Seed';
            settings.Column_Header_Variant__c = 'Period End Date';
            FinancialReporterSettingsActions.isDmlRestrictionBypassEnabled = true;
            insert settings;
            FinancialReporterSettingsActions.isDmlRestrictionBypassEnabled = false;

            testData.ledgers[1].Financial_Reporter_Settings__c = settings.Id;
            update testData.ledgers[1];

            // construct report info
            FinancialReportWrapper frw = new FinancialReportWrapper();
            frw.colList = testData.reportCols;
            Financial_Report_Column__c frc = frw.colList[0];
            frc.Offset__c = -1;
            update frc;

            frw.rowList = testData.reportRows;
            frw.reportResult = testData.financialReportResults[0];
            frw.reportValues = new List<Financial_Report_Result_Value__c> {
                new Financial_Report_Result_Value__c(
                    Number_Value__c = 100,
                    Row_Position__c = 1,
                    Column_Position__c = 1,
                    Row_Type__c = 'Blank',
                    Column_Type__c = 'Current Period',
                    Column_Header_1__c = '1991-09'
                )
            };

            // create test subject
            ReportTableController rtc = new ReportTableController();
            rtc.currentPeriodName = rtc.startPeriodName = AccountingPeriodHandler.getInstance().getAccountingPeriodById(testData.acctPeriods[0].Id).Name;
            rtc.startPeriodName = rtc.currentPeriodName;

            Test.startTest();
            // work happens when FinancialReportWrapper is assigned
            rtc.frw = frw;
            Test.stopTest();
            String expected = Date.newInstance(1991, 9, 30).format();

            System.assertEquals(expected, rtc.headers[0]);
            System.assertEquals(settings.Company_Name__c, rtc.companyName);
        }
    }
}