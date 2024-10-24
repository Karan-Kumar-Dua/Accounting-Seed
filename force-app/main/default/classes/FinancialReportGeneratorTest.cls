@IsTest
private class FinancialReportGeneratorTest {

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
    private static void testCreateFinReportResult() {
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
            System.assertNotEquals(NULL, frg.reportResult.Id);
        }
    }

    @IsTest
    private static void testPopulateGlAccountReportingGroupMap() {
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
            System.assertNotEquals(true, frg.reportingGroupMap.isEmpty());
            System.assertEquals(1, frg.reportingGroupMap.size());
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
            frg.finishReport();
            System.assertEquals('Complete', frg.reportResult.Status__c);
        }
    }

    @IsTest
    private static void testCreateProfitAndLossReportWithZeroRowsSuppression() {
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
            ProfitAndLossFinancialReportOptions reportOptions = new ProfitAndLossFinancialReportOptions();
            reportOptions.glAccounts = DomainUtils.getAllGlAccounts();

            FinancialReportGenerator frg = new FinancialReportGenerator(frw, reportOptions);
            frg.reportOptions.suppressZeroAmountRows = true;
            frg.createFinReportResult();
            frg.createReportStub();
            frg.finishReport();
            System.assertEquals('Complete', frg.reportResult.Status__c);
        }
    }

    @IsTest
    private static void testCreateProfitAndLossVsBudgetReportWithZeroRowsSuppression() {
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
            ProfitAndLossVsBudgetFinReptOptions reportOptions = new ProfitAndLossVsBudgetFinReptOptions();

            FinancialReportGenerator frg = new FinancialReportGenerator(frw, reportOptions);
            frg.reportOptions.suppressZeroAmountRows = true;
            frg.createFinReportResult();
            frg.createReportStub();
            frg.finishReport();
            System.assertEquals('Complete', frg.reportResult.Status__c);
        }
    }

    @IsTest
    private static void testCreateBalanceSheetReportWithZeroRowsSuppression() {
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
            BalanceSheetFinancialReportOptions reportOptions = new BalanceSheetFinancialReportOptions();

            FinancialReportGenerator frg = new FinancialReportGenerator(frw, reportOptions);
            frg.reportOptions.suppressZeroAmountRows = true;
            frg.createFinReportResult();
            frg.createReportStub();
            frg.finishReport();
            System.assertEquals('Complete', frg.reportResult.Status__c);
        }
    }

    @IsTest
    private static void testCreateTrialBalanceReportWithZeroRowsSuppression() {
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
            TrialBalanceFinancialReportOptions reportOptions = new TrialBalanceFinancialReportOptions();
            reportOptions.startingAccountingPeriod = testData.acctPeriods[0].Id;

            FinancialReportGenerator frg = new FinancialReportGenerator(frw, reportOptions);
            frg.reportOptions.suppressZeroAmountRows = true;
            frg.createFinReportResult();
            frg.createReportStub();
            frg.finishReport();
            System.assertEquals('Complete', frg.reportResult.Status__c);
        }
    }

    @IsTest
    private static void testSetTrialBalanceRetainedEarningsWithGLAVs() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            //Create Retained Earnings Financial Cube
            List<Financial_Cube__c> fCubeList = new List<Financial_Cube__c>();
            Financial_Cube__c fCube1 = new Financial_Cube__c();
            fCube1.Ledger__c = testData.ledgers.get(0).Id;
            fCube1.Accounting_Period__c = testData.acctPeriods[1].Id;
            fCube1.GL_Account__c = testData.glAccounts.get(8).Id;
            fCube1.Opening_Balance__c = 100;
            fCube1.Amount__c = 0;
            fCube1.Cube_Type__c = 'Retained Earnings';
            fCube1.GL_Account_Variable_1__c = testData.accountingVariables1.get(0).Id;
            fCubeList.add(fCube1);

            Financial_Cube__c fCube2 = new Financial_Cube__c();
            fCube2.Ledger__c = testData.ledgers.get(0).Id;
            fCube2.Accounting_Period__c = testData.acctPeriods[1].Id;
            fCube2.GL_Account__c = testData.glAccounts.get(8).Id;
            fCube2.Opening_Balance__c = 100;
            fCube2.Amount__c = 0;
            fCube2.Cube_Type__c = 'Retained Earnings';
            fCube2.GL_Account_Variable_1__c = testData.accountingVariables1.get(0).Id;
            fCube2.GL_Account_Variable_2__c = testData.accountingVariables2.get(0).Id;
            fCubeList.add(fCube2);

            FinancialCubeActions.isPreventOverride = true;
            insert fCubeList;
            FinancialCubeActions.isPreventOverride = false;

            //Create Financial Statement Result Value
            List<Financial_Report_Result_Value__c> rValues = new List<Financial_Report_Result_Value__c>();
            Financial_Report_Result_Value__c resultValue = new Financial_Report_Result_Value__c(
                Row_Label__c = testData.glAccounts[8].Name,
                Column_Header_1__c = 'Opening Balance',
                Currency_Value__c = 0,
                Row_Type__c = 'GL Account',
                Column_Position__c = 0
            );
            rValues.add(resultValue);

            //Create Financial Report Row
            Financial_Report_Row__c row = new Financial_Report_Row__c(
                Row_Label__c = testData.glAccounts[8].Name,
                Type__c = 'GL Account',
                GL_Account__c = testData.glAccounts[8].Id,
                Position__c = 1
            );
            Map<Integer, Financial_Report_Row__c> rowMap = new Map<Integer, Financial_Report_Row__c>{
                0 => row
            };

            //Create Financial Report options
            TrialBalanceFinancialReportOptions reportOptions = new TrialBalanceFinancialReportOptions();
            reportOptions.startingAccountingPeriod = testData.acctPeriods[1].Id;
            reportOptions.glVariable1 = testData.accountingVariables1.get(0).Id;

            Test.startTest();
            FinancialReportGenerator frg = new FinancialReportGenerator(new FinancialReportWrapper(), reportOptions);
            frg.rowMap = rowMap;
            rValues = frg.setTrialBalanceRetainedEarnings(rValues);
            Test.stopTest();

            System.assertEquals(200, rValues[0].Currency_Value__c);
        }
    }

    @IsTest
    private static void testCreateCustomReportWithZeroRowsSuppression() {
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

            FinancialReportGenerator frg = new FinancialReportGenerator(frw, reportOptions);
            frg.reportOptions.suppressZeroAmountRows = true;
            frg.createFinReportResult();
            frg.createReportStub();
            frg.finishReport();
            System.assertEquals('Complete', frg.reportResult.Status__c);
        }
    }

    @IsTest
    private static void testSetTrialBalanceRetainedEarnings() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables()
            .createGlReportingGroups()
            .createGlReportingGroupLines()
            .createReportDefinitions()
            .createReportRows()
            .createReportColumns();

        System.runAs(testData.users.get(1)) {
            //Create Financial Cubes
            List<Financial_Cube__c> fCubes = new List<Financial_Cube__c>();
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers[0].Id);
            fCubes.add(new Financial_Cube__c(
                Ledger__c = testData.ledgers[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                GL_Account__c = testData.glAccounts[8].Id,
                GL_Account_Variable_1__c = testData.accountingVariables1[0].Id,
                GL_Account_Variable_2__c = testData.accountingVariables2[0].Id,
                GL_Account_Variable_3__c = testData.accountingVariables3[0].Id,
                GL_Account_Variable_4__c = testData.accountingVariables4[0].Id,
                Opening_Balance__c = 1000,
                Cube_Type__c = 'Retained Earnings'
            ));

            fCubes.add(new Financial_Cube__c(
                Ledger__c = testData.ledgers[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                GL_Account__c = testData.glAccounts[8].Id,
                GL_Account_Variable_1__c = testData.accountingVariables1[1].Id,
                GL_Account_Variable_2__c = testData.accountingVariables2[1].Id,
                GL_Account_Variable_3__c = testData.accountingVariables3[1].Id,
                GL_Account_Variable_4__c = testData.accountingVariables4[1].Id,
                Opening_Balance__c = 1000,
                Cube_Type__c = 'Retained Earnings'
            ));

            FinancialCubeActions.isPreventOverride = true;
            insert fCubes;
            Id retainedEarningId = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.RETAINED_EARNINGS_GL_ACCOUNT)?.GL_Account__c;
            fCubes = [
                SELECT Id
                FROM Financial_Cube__c
                WHERE Accounting_Period__c IN (SELECT Id FROM Accounting_Period__c WHERE Name = :testData.acctPeriods[0].Name)
                AND GL_Account__c = :retainedEarningId
                AND GL_Account_Variable_1__c = :testData.accountingVariables1[0].Id
                AND GL_Account_Variable_2__c = :testData.accountingVariables2[0].Id
                AND GL_Account_Variable_3__c = :testData.accountingVariables3[0].Id
                AND GL_Account_Variable_4__c = :testData.accountingVariables4[0].Id
            ];

            System.assertEquals(1, fCubes.size());

            FinancialReportWrapper frw = new FinancialReportWrapper();
            frw.reportDefinition = testData.reportDefs[0];
            frw.colList = testData.reportCols;
            frw.rowList = testData.reportRows;
            TrialBalanceFinancialReportOptions reportOptions = new TrialBalanceFinancialReportOptions();
            reportOptions.glVariable1 = testData.accountingVariables1[0].Id;
            reportOptions.glVariable2 = testData.accountingVariables2[0].Id;
            reportOptions.glVariable3 = testData.accountingVariables3[0].Id;
            reportOptions.glVariable4 = testData.accountingVariables4[0].Id;
            reportOptions.startingAccountingPeriod = testData.acctPeriods[0].Id;

            FinancialReportGenerator frg = new FinancialReportGenerator(frw, reportOptions);
            frg.reportOptions.suppressZeroAmountRows = false;

            frg.createFinReportResult();
            frg.createReportStub();
            frg.finishReport();
            System.assertEquals('Complete', frg.reportResult.Status__c);
        }
    }

}