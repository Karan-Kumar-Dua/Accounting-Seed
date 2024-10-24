@IsTest
private class ExpenseReportHelperTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testGetExpenseReportData() {

        TestDataSuite testData = TestDataSuite.getInstance()
            .createGLAccountExpenses()
            .createProjects()
            .createProjectTasks()
            .createExpenseReports()
            .createExpenseLines();

        System.runAs(testData.users.get(1)) {
            Expense_Report__c testExpReport = testData.expenseReports.get(0);
            ExpenseReportHelper.ExpenseReportData expReportData = ExpenseReportHelper.getExpenseReportData(testExpReport.Id);

            System.assertEquals(testExpReport.Id, expReportData.id);
            System.assertEquals(1, expReportData.mileageLines.size());
            System.assertEquals(1, expReportData.expenseLines.size());
        }

    }

    @IsTest
    static void testGetProjectTasks() {

        TestDataSuite testData = TestDataSuite.getInstance()
            .createGLAccountExpenses()
            .createProjects()
            .createProjectTasks();

        System.runAs(testData.users.get(1)) {
            Project__c testProject = testData.projects.get(0);
            List<Project_Task__c> projectTasks = FinancialSuiteUtils.getProjectTasks(testProject.Id);

            System.assertNotEquals(true, projectTasks.isEmpty());
        }

    }

    @IsTest
    static void testSaveExpenseLines() {

        TestDataSuite testData = TestDataSuite.getInstance()
            .createGLAccountExpenses()
            .createProjects()
            .createProjectTasks()
            .createExpenseReports()
            .createExpenseLines();

        System.runAs(testData.users.get(1)) {
            Expense_Report__c testExpReport = testData.expenseReports.get(0);
            ExpenseReportHelper.ExpenseReportData expReportData = ExpenseReportHelper.getExpenseReportData(testExpReport.Id);

            System.assertEquals(testExpReport.Id, expReportData.id);
            System.assertEquals(1, expReportData.mileageLines.size());
            System.assertEquals(1, expReportData.expenseLines.size());

            ExpenseReportHelper.ExpenseLineData mileageLineData = expReportData.mileageLines.get(0);
            mileageLineData.internalComment.stringValue = 'mileage internal comment';
            mileageLineData.invoiceComment.stringValue = 'mileage invoice comment';
            ExpenseReportHelper.ExpenseLineData expenseLineData = expReportData.expenseLines.get(0);
            expenseLineData.internalComment.stringValue = 'expense internal comment';
            expenseLineData.invoiceComment.stringValue = 'expense invoice comment';

            String serializedMileageLines = JSON.serialize(mileageLineData);
            String serializedExpenseLines = JSON.serialize(expenseLineData);

            Test.startTest();
            DmlException dmlEx;
            try {
                ExpenseReportHelper.saveExpenseLines(
                    testExpReport.Id, new List<String>{serializedMileageLines, serializedExpenseLines}
                );
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);

            Expense_Line__c mileageLine = [
                SELECT Id, Internal_Comment__c, Invoice_Comment__c
                FROM Expense_Line__c
                WHERE Id = :mileageLineData.id
            ];
            Expense_Line__c expenseLine = [
                SELECT Id, Internal_Comment__c, Invoice_Comment__c
                FROM Expense_Line__c
                WHERE Id = :expenseLineData.id
            ];

            System.assertNotEquals(NULL, mileageLine);
            System.assertNotEquals(NULL, expenseLine);
            System.assertEquals('mileage internal comment', mileageLine.Internal_Comment__c);
            System.assertEquals('mileage invoice comment', mileageLine.Invoice_Comment__c);
            System.assertEquals('expense internal comment', expenseLine.Internal_Comment__c);
            System.assertEquals('expense invoice comment', expenseLine.Invoice_Comment__c);
        }

    }

    @IsTest
    static void testDeleteExpenseLines() {

        TestDataSuite testData = TestDataSuite.getInstance()
            .createGLAccountExpenses()
            .createProjects()
            .createProjectTasks()
            .createExpenseReports()
            .createExpenseLines();

        System.runAs(testData.users.get(1)) {
            Expense_Report__c testExpReport = testData.expenseReports.get(0);
            ExpenseReportHelper.ExpenseReportData expReportData = ExpenseReportHelper.getExpenseReportData(testExpReport.Id);

            System.assertEquals(testExpReport.Id, expReportData.id);
            System.assertEquals(1, expReportData.mileageLines.size());
            System.assertEquals(1, expReportData.expenseLines.size());

            ExpenseReportHelper.ExpenseLineData mileageLineData = expReportData.mileageLines.get(0);
            ExpenseReportHelper.ExpenseLineData expenseLineData = expReportData.expenseLines.get(0);

            Test.startTest();
            DmlException dmlEx;
            try {
                ExpenseReportHelper.deleteExpenseLine(mileageLineData.id);
                ExpenseReportHelper.deleteExpenseLine(expenseLineData.id);
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);

            List<Expense_Line__c> expLines = [
                SELECT Id, Internal_Comment__c, Invoice_Comment__c
                FROM Expense_Line__c
                WHERE Expense_Report__c = :testExpReport.Id
            ];

            System.assertEquals(true, expLines.isEmpty());
        }

    }

}