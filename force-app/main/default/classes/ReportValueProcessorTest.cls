@IsTest
private class ReportValueProcessorTest {

    @TestSetup
    private static void createTestData() {
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.archiveOldAccountingPeriods();
            testData.createAccountingPeriodSetBasedOnCurrentDate();
            testData.closePreviousAccountingPeriodsBasedOnCurrentDate();
        }
    }

    @IsTest
    private static void testConstructor() {
        TestDataSuite testData = TestDataSuite.getInstance()
        .createGlReportingGroups()
        .createGlReportingGroupLines()
        .createReportDefinitions()
        .createReportRows()
        .createReportColumns();

        System.runas(testData.users.get(1)) {
            CustomFinancialReportOptions reportOptions = new CustomFinancialReportOptions(testData.reportDefs[0].Id);
            reportOptions.glAccounts = DomainUtils.getAllGlAccounts();
            reportOptions.ledgerIds = new List<Id>{testData.ledgers[0].Id};

            Financial_Report_Row__c thisrow = testData.reportRows[0];
            List<String> reportingGroupList = new List<String>{thisrow.GL_Account_Reporting_Group__c};
            BalanceBuilder balancebuilder = new BalanceBuilder();
            Test.startTest();
            ReportValueProcessor processor = new ReportValueProcessor(reportOptions, reportingGroupList, balancebuilder);
            Test.stopTest();
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(reportOptions.ledger);
            System.assertEquals(processor.currentYearEarningsGLAccountId, defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT)?.GL_Account__c);
            System.assertEquals(processor.retainedEarningsGLAccountId, defaultsBySpecDevNames.get(GLAccountDefaultsHandler.RETAINED_EARNINGS_GL_ACCOUNT)?.GL_Account__c);
            System.assertEquals(processor.reportOptions.getLedgerIds(), reportOptions.getLedgerIds());
            System.assertEquals(processor.reportOptions.startingAccountingPeriod, reportOptions.startingAccountingPeriod);
            System.assertEquals(processor.reportOptions.getListOfPeriodNames(), reportOptions.getListOfPeriodNames());
            System.assertEquals(processor.balancebuilder, balancebuilder);
        }
    }

    @IsTest
    private static void testCreateReport() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createGlReportingGroups()
            .createGlReportingGroupLines()
            .createReportDefinitions()
            .createReportRows()
            .createReportColumns();

        System.runAs(testData.users.get(1)) {
            FinancialReportWrapper frw = new FinancialReportWrapper();
            frw.reportDefinition = testData.reportDefs[0];
            frw.colList = testData.reportCols;
            frw.rowList = testData.reportRows;
            CustomFinancialReportOptions reportOptions = new CustomFinancialReportOptions(testData.reportDefs[0].Id);
            reportOptions.glAccounts = DomainUtils.getAllGlAccounts();
            reportOptions.ledgerIds = new List<Id>{testData.ledgers[0].Id};

            Test.startTest();
            FinancialReportGenerator frg = new FinancialReportGenerator(frw, reportOptions);
            frg.createFinReportResult();
            frg.createReportStub();
            Integer recNum = 0;
            for (Financial_Report_Result_Value__c r : frg.reportValues) {
                Financial_Report_Row__c thisrow = frg.rowMap.get(recNum);
                Financial_Report_Column__c thiscol = frg.colMap.get(recNum);
                Financial_Report_Column__c initialColumn = frg.colMap.get(0);
                List<String> reportingGroupList = frg.reportingGroupMap.get(thisrow.GL_Account_Reporting_Group__c);    
                ReportValueProcessor.ReportValueCalculationResult result = new ReportValueProcessor(reportOptions, reportingGroupList, frg.balanceBuilderInstance)
                    .calculateReportValue(r, thisrow, thiscol, initialColumn, frg.periodBalMap.get(recNum));
                System.assertEquals(result.isSuccess, true);                                
                recNum++;                
                result = null;
            }            
        }
    }

    @IsTest
    private static void testCreateCashFlowReport() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createGlReportingGroups()
            .createGlReportingGroupLines()
            .createReportDefinitions()
            .createReportRows()
            .createReportColumns();

        System.runAs(testData.users.get(1)) {
            FinancialReportWrapper frw = new FinancialReportWrapper();
            frw.reportDefinition = testData.reportDefs[0];
            frw.colList = testData.reportCols;
            frw.rowList = testData.reportRows;
            testData.createCashFlowCategories(false);
            CashFlowFinancialReportOptions reportOptions = new CashFlowFinancialReportOptions();

            Test.startTest();
            FinancialReportGenerator frg = new FinancialReportGenerator(frw, reportOptions);
            frg.createFinReportResult();
            frg.createReportStub();
            Integer recNum = 0;
            for (Financial_Report_Result_Value__c r : frg.reportValues) {
                Financial_Report_Row__c thisrow = frg.rowMap.get(recNum);
                Financial_Report_Column__c thiscol = frg.colMap.get(recNum);
                Financial_Report_Column__c initialColumn = frg.colMap.get(0);
                List<String> reportingGroupList = frg.reportingGroupMap.get(thisrow.GL_Account_Reporting_Group__c);    
                ReportValueProcessor.ReportValueCalculationResult result =
                    new ReportValueProcessor(reportOptions, reportingGroupList, frg.balanceBuilderInstance)
                        .calculateReportValue(r, thisrow, thiscol, initialColumn, frg.periodBalMap.get(recNum));

                System.assertEquals(result.isSuccess, true);
                recNum++;                
                result = null;
            }            
        }
    }

    @IsTest
    private static void testDoRounding() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            ProfitAndLossFinancialReportOptions reportOptions = new ProfitAndLossFinancialReportOptions();
            reportOptions.glAccounts = DomainUtils.getAllGlAccounts();

            Test.startTest();
            ReportValueProcessor processor = new ReportValueProcessor(reportOptions, null, null);
            processor.reportOptions.setRoundingMode(FinancialReportOptions.FinancialReportRoundingMode.WHOLE_AMOUNTS);
            System.assertEquals(1001, processor.doRounding(1000.50));
            System.assertEquals(0, processor.doRounding(0.499));
            System.assertEquals(-56, processor.doRounding(-55.55));

            processor.reportOptions.setRoundingMode(FinancialReportOptions.FinancialReportRoundingMode.ROUND_TO_1000);
            System.assertEquals(1, processor.doRounding(1000.50));
            System.assertEquals(0, processor.doRounding(0.499));
            System.assertEquals(0, processor.doRounding(-55.55));
        }
    }

}