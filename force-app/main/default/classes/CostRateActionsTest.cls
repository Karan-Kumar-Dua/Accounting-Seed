@IsTest
public class CostRateActionsTest {

    @TestSetup
    public static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testPreventWeeklySalaryAndProjectAndProjectTaskInsertError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks();

        System.runAs(testData.users[1]) {
            Cost_Rates__c cr = new Cost_Rates__c();
            cr.Weekly_Salary_Cost__c = 1025;
            cr.Project__c = testData.projects[0].Id;

            DMLException dmlEx;

            try {
                insert cr;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(CostRateActions.WEEKLEY_SALARY_PROJECT_ERROR, dmlEx.getDMLMessage(0));
        }

    }

    @IsTest
    public static void testPreventWeeklySalaryAndProjectAndProjectTaskUpdateError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks();

        System.runAs(testData.users[1]) {
            Cost_Rates__c cr = new Cost_Rates__c();
            cr.Weekly_Salary_Cost__c = 1025;
            insert cr;

            DMLException dmlEx;
            try {
                cr.Project__c = testData.projects[0].Id;
                update cr;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(CostRateActions.WEEKLEY_SALARY_PROJECT_ERROR, dmlEx.getDMLMessage(0));
        }

    }

    @IsTest
    public static void testPreventSetOvertimeHourlyCostWithoutHourlyCostInsertError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks();

        System.runAs(testData.users[1]) {
            Cost_Rates__c cr = new Cost_Rates__c();
            cr.Overtime_Hourly_Cost__c = 100;

            DMLException dmlEx;
            try {
                insert cr;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(CostRateActions.HOURLY_COST_MUST_BE_SET_ERROR, dmlEx.getDMLMessage(0));
        }
    }

    @IsTest
    public static void testPreventSetOvertimeHourlyCostWithoutHourlyCostUpdateError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks();

        System.runAs(testData.users[1]) {
            Cost_Rates__c cr = new Cost_Rates__c();
            cr.Hourly_Cost__c = 60;
            insert cr;

            DMLException dmlEx;

            try {
                cr.Project__c = testData.projects[0].Id;
                cr.Hourly_Cost__c = NULL;
                cr.Overtime_Hourly_Cost__c = 100;
                update cr;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(CostRateActions.HOURLY_COST_MUST_BE_SET_ERROR, dmlEx.getDMLMessage(0));
        }
    }

    @IsTest
    public static void testCostRatesNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            DMLException dmlEx;
            try {
                Cost_Rates__c cr = new Cost_Rates__c();
                insert cr;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

    @IsTest
    public static void testCostRatesNoNullPointerExceptionInsert_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency();

            System.runAs(testData.users[1]) {
                Cost_Rates__c cr = new Cost_Rates__c();
                DMLException dmlEx;
                try {
                    insert cr;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }
                System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

}