@isTest
public class ExpenseReportControllerExtTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest	
    public static void testExpenseReportControllerExt() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createExpenseReports()
            .createGLAccountExpenses()
            .createExpenseLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            ExpenseReportControllerExt ere = new ExpenseReportControllerExt(new ApexPages.StandardController(testData.expenseReports[0]));

            // Check lists have loaded as expected
            System.assertEquals(ere.expensesMap.size(),1);
            System.assertEquals(ere.mileageMap.size(),1);

            // Test aggregation methods
            System.assertEquals(50.0, ere.getProjectAmountTotal());
            System.assertEquals(50.0, ere.getMileageMilesTotal());
            System.assertEquals(26.0, ere.getMileageAmountTotal());

            // Checking addition of expense rows on the page
            ere.addExpenseLine();
            System.assertEquals(2,ere.expensesMap.size());

            // save and check error conditions for each row are set correctly
            ere.saveAndClose();
            // Check expense errors
            System.assertEquals(true, ere.expensesMap.values()[1].isProjectError);
            System.assertEquals(true, ere.expensesMap.values()[1].isProjectTaskError);
            System.assertEquals(true, ere.expensesMap.values()[1].isAmountError);
            System.assertEquals(true, ere.expensesMap.values()[1].isExpenseTypeError);
            System.assertEquals(true, ere.expensesMap.values()[1].isDateError);

            // Test adding new expense line
            ere.mileageMap.values()[0].strExpenseTypeId = ere.expenseTypesList[1].getValue();
            ere.mileageMap.values()[0].expenseLine.Mileage_Origin__c = 'Test';
            ere.mileageMap.values()[0].expenseLine.Mileage_Destination__c = 'Test';
            ere.expensesMap.values()[1].expenseLine.Project__c = testData.projects[0].Id;
            ere.expensesMap.values()[1].expenseLine.Project_Task__c = testData.projectTasks[0].Id;
            ere.expensesMap.values()[1].expenseLine.Amount__c = 100;
            ere.expensesMap.values()[1].expenseLine.Expense_GL_Account__c = ere.expenseTypesList[1].getValue();
            ere.expensesMap.values()[1].expenseLine.Date__c = System.today();
            ere.expensesMap.values()[1].strExpenseTypeId = ere.expenseTypesList[1].getValue();

            ere.saveAndRefresh();

            System.assertNotEquals(NULL, ere.expensesMap.values()[1].expenseLine.Id);

            ere.addMileageLine();
            System.assertEquals(2, ere.mileageMap.size());
            ere.saveAndClose();

            // Check mileage errors
            System.assertEquals(true, ere.mileageMap.values()[1].isProjectError);
            System.assertEquals(true, ere.mileageMap.values()[1].isProjectTaskError);
            System.assertEquals(true, ere.mileageMap.values()[1].isMilesError);
            System.assertEquals(true, ere.mileageMap.values()[1].isExpenseTypeError);
            System.assertEquals(true, ere.mileageMap.values()[1].isDateError);
            System.assertEquals(true, ere.mileageMap.values()[1].isOriginError);
            System.assertEquals(true, ere.mileageMap.values()[1].isDestinationError);

            // Test adding new mileage line
            ere.mileageMap.values()[1].expenseLine.Project__c = testData.projects[0].Id;
            ere.mileageMap.values()[1].expenseLine.Project_Task__c = testData.projectTasks[0].Id;
            ere.mileageMap.values()[1].expenseLine.Amount__c = 100;
            ere.mileageMap.values()[1].expenseLine.Expense_GL_Account__c = ere.expenseTypesList[1].getValue();
            ere.mileageMap.values()[1].expenseLine.Date__c = System.today();
            ere.mileageMap.values()[1].expenseLine.Mileage_Origin__c = 'Riverside CA';
            ere.mileageMap.values()[1].expenseLine.Mileage_Destination__c = 'San Bernadino CA';
            ere.mileageMap.values()[1].expenseLine.Miles__c = 50;
            ere.mileageMap.values()[1].strExpenseTypeId = ere.expenseTypesList[1].getValue();
            ere.saveAndRefresh();

            System.assertNotEquals(NULL, ere.mileageMap.values()[1].expenseLine.Id);

            // Test delete mileage and expense lines
            ere.selectedExpenseRow = 1;
            ere.deleteExpenseLine();
            System.assertEquals(1,ere.expensesMap.size());

            ere.selectedMileageRow = 1;
            ere.deleteMileageLine();
            System.assertEquals(1,ere.mileageMap.size());
        }

    }
}