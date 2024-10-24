@IsTest
private class FinancialReportMassAddRowExtTest {
    
    private static ApexPages.StandardSetController stdSetController;
    private static FinancialReportMassAddRowExt controller;
    private static Financial_Report_Definition__c reportDef;

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    /* tests */
    
    @IsTest
    static void testInitWithExistingRows() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            setup(true);
            System.assert(controller.reportIsInvalid, 'report should be invalid');
            System.assert(hasWarningPageMessage(), 'there should be a warning message');
            teardown();
        }

    }

    @IsTest
    static void testCancelButton() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            setup();
            PageReference cancelRef = controller.cancel();
            System.assert(cancelRef.getRedirect(), 'should be redirecting');
            teardown();
        }

    }

    @IsTest
    static void testCreateNoRowsSelected() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            setup();
            controller.createRows();
            System.assert(hasErrorPageMessage(), 'no rows selected should create page error');
            teardown();
        }

    }

    @IsTest
    static void testAllGLAccountsQueryFilter() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            setup();
            controller.queryGLAccounts();

            Boolean hasBalanceSheet = false;
            Boolean hasNonBalanceSheet = false;

            for (FinancialReportMassAddRowExt.GLAccountWrapper g : controller.glAccountWraps.values()) {
                if (g.glAccount.Type__c == 'Balance Sheet') {
                    hasBalanceSheet = true;
                }
                else {
                    hasNonBalanceSheet = true;
                }
                if (hasBalanceSheet && hasNonBalanceSheet) break;
            }

            System.assert(hasBalanceSheet && hasNonBalanceSheet, 'should contain all account types');

            teardown();
        }

    }

    @IsTest
    static void testBalanceSheetQueryFilter() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            setup();
            controller.selectedReportType = '1';
            controller.queryGLAccounts();
            for (FinancialReportMassAddRowExt.GLAccountWrapper g : controller.glAccountWraps.values()) {
                System.assertEquals('Balance Sheet', g.glAccount.Type__c, 'incorrect gl account type returned: ' + g.glAccount.Type__c);
            }
            teardown();
        }

    }

    @IsTest
    static void testProfitLossQueryFilter() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            setup();
            controller.selectedReportType = '2';
            controller.queryGLAccounts();
            for (FinancialReportMassAddRowExt.GLAccountWrapper g : controller.glAccountWraps.values()) {
                System.assertNotEquals('Balance Sheet', g.glAccount.Type__c, 'incorrectly returned a Balance Sheet account');
            }
            teardown();
        }

    }

    @IsTest
    static void testSubTypeQueryFilters() {
        TestDataSuite testData = TestDataSuite.getInstance().createFRGLAccounts();

        System.runAs(testData.users[1]) {
            setup();
            controller.selectedReportType = '1';
            controller.groupBySubType1 = true;
            controller.queryGLAccounts();
            System.assertEquals(20, controller.glAccountWraps.size(), ' should return 20 GL Account with Type "Balance Sheet" ');
            for (FinancialReportMassAddRowExt.GLAccountWrapper g : controller.glAccountWraps.values()) {
                System.assertEquals('Balance Sheet', g.glAccount.Type__c, 'incorrectly returned a non Balance Sheet account');
            }
            controller.groupBySubType2 = true;
            controller.queryGLAccounts();
            System.assertEquals(20, controller.glAccountWraps.size(), ' should return 20 GL Account with Type "Balance Sheet" ');
            teardown();
        }

    }

    @IsTest
    static void testSortingWrappedGLAccounts() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAccountExpenses().createFRGLAccounts();

        System.runAs(testData.users[1]) {
            setup();

            List<GL_Account__c> additionalGlAccounts = new List<GL_Account__c>();

            additionalGlAccounts.add(
                new GL_Account__c(
                    Name = 'ADD_ACC_BS_FULL_SUB_TYPES',
                    Active__c = true,
                    Type__c = 'Balance Sheet',
                    Bank__c = true,
                    Sub_Type_1__c = 'Assets',
                    Sub_Type_2__c = 'Current Assets'
                )
            );

            additionalGlAccounts.add(
                new GL_Account__c(
                    Name = 'ADD_ACC_BS_SUB_TYPE_1',
                    Active__c = true,
                    Type__c = 'Balance Sheet',
                    Bank__c = true,
                    Sub_Type_1__c = 'Owners Equity',
                    Sub_Type_2__c = NULL
                )
            );

            additionalGlAccounts.add(
                new GL_Account__c(
                    Name = 'ADD_ACC_PL_EMPTY_SUB_TYPES',
                    Active__c = true,
                    Type__c = 'Revenue',
                    Bank__c = true,
                    Sub_Type_1__c = NULL,
                    Sub_Type_2__c = NULL
                )
            );

            additionalGlAccounts.add(
                new GL_Account__c(
                    Name = 'ADD_ACC_PL_SUB_TYPE_1',
                    Active__c = true,
                    Type__c = 'Revenue',
                    Bank__c = true,
                    Sub_Type_1__c = 'Product Revenue',
                    Sub_Type_2__c = NULL
                )
            );

            insert additionalGlAccounts;

            controller.selectedReportType = '2';//select "Profit & Loss" report type
            controller.groupBySubType1 = true;
            controller.groupBySubType2 = true;
            List<SelectOption> availableTypes = controller.reportTypes;

            controller.queryGLAccounts();
            System.assertEquals(22, controller.glAccountWraps.size(), ' should return 22 GL Accounts with Types "Revenue" or "Expense" ');

            controller.selectedReportType = '1';//select "Balance Sheet" report type
            controller.groupBySubType1 = true;
            controller.groupBySubType2 = false;

            controller.queryGLAccounts();
            System.assertEquals(22, controller.glAccountWraps.size(), ' should return 22 GL Accounts with Type "Balance Sheet" ');
        }

    }

    @IsTest
    static void testCreateAllRows() {
        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables();

        System.runAs(testData.users[1]) {
            setup();

            controller.beginningRowNumber = 100;
            controller.incrementRowNumber = 100;
            controller.proxyRow.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            controller.proxyRow.GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            controller.proxyRow.GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            controller.proxyRow.GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            controller.queryGLAccounts();

            for (FinancialReportMassAddRowExt.GLAccountWrapper g : controller.glAccountWraps.values()) {
                g.selected = true;
            }

            controller.createRows();

            Integer rowIndex = 0;
            Integer rowNum = 100;

            for (Financial_Report_Row__c r : getRows()) {
                System.assertEquals(rowNum, Integer.valueOf(r.Position__c), 'position of row ' + rowIndex + ' should be ' + rowNum);

                System.assertEquals('GL Account', r.Type__c, 'type should be GL Account');

                System.assertEquals(testData.accountingVariables1[0].Id, r.GL_Account_Variable_1__c, 'variable1 should match');
                System.assertEquals(testData.accountingVariables2[0].Id, r.GL_Account_Variable_2__c, 'variable2 should match');
                System.assertEquals(testData.accountingVariables3[0].Id, r.GL_Account_Variable_3__c, 'variable3 should match');
                System.assertEquals(testData.accountingVariables4[0].Id, r.GL_Account_Variable_4__c, 'variable4 should match');

                String normalBalance = 'Credit';

                if (r.GL_Account__r.Type__c == 'Balance Sheet' || r.GL_Account__r.Type__c == 'Expense') {
                    normalBalance = 'Debit';
                }

                System.assertEquals(normalBalance, r.Normal_Balance__c, 'normal balance should be ' + normalBalance + ' for gl type ' + r.GL_Account__r.Type__c);

                rowIndex ++;
                rowNum += 100;
            }

            PageReference ref = controller.createRows();
            teardown();
        }

    }

    @IsTest
    static void testCreateWithExistingRows() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            setup(true);
            System.assertEquals(0, controller.glAccountWraps.size(), 'there should be 0 gl account wrappers');
            PageReference ref = controller.createRows();
            System.assertEquals(null, ref, 'Page reference should return null');
            System.assert(hasErrorPageMessage(), 'There should be an error on the page');
            teardown();
        }

    }

    @IsTest
    static void testPageMessageHelpers() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            setup();
            controller.addInfo('test info');
            controller.addWarning('test warning');
            controller.addError('test error');
            System.assert(hasInfoPageMessage(), 'should have an info message');
            System.assert(hasWarningPageMessage(), 'should have a warning message');
            System.assert(hasErrorPageMessage(), 'should have an error message');
            teardown();
        }

    }

    @IsTest
    static void testCreateGroupedBalanceSheetRows() {
        TestDataSuite testData = TestDataSuite.getInstance().createGlReportingGroups().createFRGLAccounts();

        System.runAs(testData.users[1]) {
            setup();

            List<GL_Account__c> additionalGlAccounts = new List<GL_Account__c>();

            additionalGlAccounts.add(
                new GL_Account__c(
                    Name = 'ADD_ACC_BS_FULL_SUB_TYPES',
                    Active__c = true,
                    Type__c = 'Balance Sheet',
                    Bank__c = true,
                    Sub_Type_1__c = 'Assets',
                    Sub_Type_2__c = 'Current Assets'
                )
            );

            additionalGlAccounts.add(
                new GL_Account__c(
                    Name = 'ADD_ACC_BS_SUB_TYPE_1',
                    Active__c = true,
                    Type__c = 'Balance Sheet',
                    Bank__c = true,
                    Sub_Type_1__c = 'Owners Equity',
                    Sub_Type_2__c = 'Equity'
                )
            );

            additionalGlAccounts.add(
                new GL_Account__c(
                    Name = 'ADD_ACC_PL_EMPTY_SUB_TYPES',
                    Active__c = true,
                    Type__c = 'Revenue',
                    Bank__c = true,
                    Sub_Type_1__c = NULL,
                    Sub_Type_2__c = NULL
                )
            );

            additionalGlAccounts.add(
                new GL_Account__c(
                    Name = 'ADD_ACC_PL_SUB_TYPE_1',
                    Active__c = true,
                    Type__c = 'Revenue',
                    Bank__c = true,
                    Sub_Type_1__c = 'Product Revenue',
                    Sub_Type_2__c = NULL
                )
            );
            insert additionalGlAccounts;

            controller.selectedReportType = '1';//select "Balance Sheet" report type
            controller.groupBySubType1 = true;
            List<SelectOption> availableTypes = controller.reportTypes;

            controller.queryGLAccounts();
            //2 additional + 19 from testDataSuite
            System.assertEquals(22, controller.glAccountWraps.size());

            for (FinancialReportMassAddRowExt.GlAccountWrapper wrappedGLAccount : controller.glAccountWraps.values()) {
                wrappedGLAccount.selected = true;
            }

            controller.createRows();

            List<Financial_Report_Row__c> createdRows = [
                SELECT Id
                FROM Financial_Report_Row__c
                WHERE Financial_Report_Definition__c = :controller.reportDefinition.Id
            ];
            System.assertEquals(50, createdRows.size());
        }

    }

    @IsTest
    static void testCreateGroupedProfitAndLossRows() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAccountExpenses().createFRGLAccounts();

        System.runAs(testData.users[1]) {
            setup();

            List<GL_Account__c> additionalGlAccounts = new List<GL_Account__c>();

            additionalGlAccounts.add(
                new GL_Account__c(
                    Name = 'ADD_ACC_BS_FULL_SUB_TYPES',
                    Active__c = true,
                    Type__c = 'Balance Sheet',
                    Bank__c = true,
                    Sub_Type_1__c = 'Assets',
                    Sub_Type_2__c = 'Current Assets'
                )
            );

            additionalGlAccounts.add(
                new GL_Account__c(
                    Name = 'ADD_ACC_BS_SUB_TYPE_1',
                    Active__c = true,
                    Type__c = 'Balance Sheet',
                    Bank__c = true,
                    Sub_Type_1__c = 'Owners Equity',
                    Sub_Type_2__c = 'Equity'
                )
            );

            additionalGlAccounts.add(
                new GL_Account__c(
                    Name = 'ADD_ACC_PL_EMPTY_SUB_TYPES',
                    Active__c = true,
                    Type__c = 'Revenue',
                    Bank__c = true,
                    Sub_Type_1__c = 'Product Revenue',
                    Sub_Type_2__c = 'Product Family 1'
                )
            );

            additionalGlAccounts.add(
                new GL_Account__c(
                    Name = 'ADD_ACC_PL_SUB_TYPE_1',
                    Active__c = true,
                    Type__c = 'Expense',
                    Bank__c = true,
                    Sub_Type_1__c = 'Sales & Marketing',
                    Sub_Type_2__c = 'Marketing Events'
                )
            );

            insert additionalGlAccounts;

            controller.selectedReportType = '2';//select "Profit & Loss" report type
            controller.groupBySubType1 = true;
            controller.groupbySubType2 = true;
            List<SelectOption> availableTypes = controller.reportTypes;

            controller.queryGLAccounts();
            //2 additional + 20 from TestDataSuite
            System.assertEquals(22, controller.glAccountWraps.size());

            for (FinancialReportMassAddRowExt.GlAccountWrapper wrappedGLAccount : controller.glAccountWraps.values()) {
                wrappedGLAccount.selected = true;
            }

            controller.createRows();

            List<Financial_Report_Row__c> createdRows = [
                SELECT Id
                FROM Financial_Report_Row__c
                WHERE Financial_Report_Definition__c = :controller.reportDefinition.Id
            ];

            System.assertEquals(70, createdRows.size());
        }

    }

    /* test helpers */
    
    static Boolean hasInfoPageMessage() {
        return hasPageMessageOfType(ApexPages.Severity.INFO);
    }

    static Boolean hasWarningPageMessage() {
        return hasPageMessageOfType(ApexPages.Severity.WARNING);
    }

    static Boolean hasErrorPageMessage() {
        return hasPageMessageOfType(ApexPages.Severity.ERROR);
    }

    static Boolean hasPageMessageOfType(ApexPages.Severity severity) {
        for (ApexPages.Message m : ApexPages.getMessages()) {
            if (m.getSeverity() == severity) {
                return true;
            }
        }
        return false;
    }

    static List<Financial_Report_Row__c> getRows() {
        return getRows(reportDef.Id);
    }

    static List<Financial_Report_Row__c> getRows(Id reportDefId) {
        return [
            SELECT
                Id,
                Financial_Report_Definition__c,
                Row_Label__c,
                Type__c,
                GL_Account__c,
                GL_Account_Variable_1__c,
                GL_Account_Variable_2__c,
                GL_Account_Variable_3__c,
                GL_Account_Variable_4__c,
                Position__c,
                Normal_Balance__c,
                GL_Account__r.Type__c,
                GL_Account__r.Name
            FROM Financial_Report_Row__c
            WHERE Financial_Report_Definition__c = :reportDefId
            ORDER BY Position__c
        ];
    }

    /* data setup */
    
    static void setup() {
        setup(false);
    }

    static void setup(Boolean addExistingRow) {
        // start test context
        Test.startTest();
        // init test data
        TestDataSuite testData = TestDataSuite.getInstance();

        // init and save report definition
        reportDef = new Financial_Report_Definition__c();
        reportDef.Name = 'Test Report';
        insert reportDef;

        if (addExistingRow) {
            Financial_Report_Row__c row = new Financial_Report_Row__c();
            row.Financial_Report_Definition__c = reportDef.Id;
            row.Row_Label__c = 'Test Existing Row';
            row.Type__c = 'GL Account';
            row.GL_Account__c = testData.glAccounts[0].Id;
            row.Position__c = 1;
            row.Normal_Balance__c = 'Credit';
            insert row;
        }

        // set current apex page
        Test.setCurrentPage(Page.FinancialReportMassAddRow);
        ApexPages.currentPage().getParameters().put('id', reportDef.Id);

        // instantiate standard set controller
        stdSetController = new ApexPages.StandardSetController(new List<Financial_Report_Row__c>());

        // initialize controller extension
        controller = new FinancialReportMassAddRowExt(stdSetController);
    }

    /* data teardown */
    
    static void teardown() {
        // stop test context
        Test.stopTest();
    }
    
}