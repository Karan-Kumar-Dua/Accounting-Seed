@IsTest
public class TimeCardPeriodActionTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testAddPeriodNoError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        //Insert record in the database to test against.
        Time_Card_Period__c period = new Time_Card_Period__c(
            Name = 'January',
            Start_Date__c = date.newinstance(1992, 1, 1),
            End_Date__c = date.newinstance(1992, 1, 31)
        );

        insert period;

        // Verify the results are correct. The record was added? or errored out?
        System.assertNotEquals(NULL, period.Id);
    }

    @IsTest
    public static void testAddPeriodStartDateInRange() {
       TestDataSuite testData = TestDataSuite.getInstance();

        //Insert record in the database to test against.
        Time_Card_Period__c period = new Time_Card_Period__c(
            Name = 'January',
            Start_Date__c = date.newinstance(1992, 1, 1),
            End_Date__c = date.newinstance(1992, 1, 7)
        );
        insert period;

        TimeCardPeriodAction.isFirstRun = true;

        // Setup new instance to test.
        Time_Card_Period__c period1 = new Time_Card_Period__c(
            Name = 'January',
            Start_Date__c = date.newinstance(1992, 1, 2)
        );

        DMLException dmlEx;

        try {
            insert period1;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        // Verify the results are correct. The record was added? or errored out?
        System.assertEquals(System.StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, dmlEx.getDmlType(0));
    }

    @IsTest
    public static void testAddPeriodEndDateInRange() {
       TestDataSuite testData = TestDataSuite.getInstance();

        // Insert record in the database to test against.
        Time_Card_Period__c period = new Time_Card_Period__c(
            Name = 'January',
            Start_Date__c = date.newinstance(1992, 1, 1),
            End_Date__c = date.newinstance(1992, 1, 7)
        );
        insert period;

        TimeCardPeriodAction.isFirstRun = true;

        // Setup new instance to test.
        Time_Card_Period__c period1 = new Time_Card_Period__c(
            Name = 'January',
            Start_Date__c = date.newinstance(1991, 12, 31),
            End_Date__c = date.newinstance(1992, 1, 6)
        );

        DMLException dmlEx;

        try {
            insert period1;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        // Verify the results are correct. The record was added? or errored out?
        System.assertEquals(System.StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, dmlEx.getDmlType(0));
    }

    @IsTest
    public static void testBothStartAndEndDateInRange() {
       TestDataSuite testData = TestDataSuite.getInstance();

        // Insert record in the database to test against.
        Time_Card_Period__c period = new Time_Card_Period__c(
            Name = 'January',
            Start_Date__c = date.newinstance(1992, 1, 1),
            End_Date__c = date.newinstance(1992, 1, 7)
        );
        insert period;

        TimeCardPeriodAction.isFirstRun = true;

        // Setup new instance to test.
        Time_Card_Period__c period1 = new Time_Card_Period__c(
            Name = 'January',
            Start_Date__c = date.newinstance(1991, 12, 31),
            End_Date__c = date.newinstance(1992, 1, 6)
        );

        DMLException dmlEx;

        try {
            insert period1;
        }
        catch(DMLException ex) {
            dmlEx = ex;
        }

        // Verify the results are correct. The record was added? or errored out?
        System.assertEquals(System.StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, dmlEx.getDmlType(0));
    }

    @IsTest
    public static void testPreventUpdateDateChangedAndTimeCard() {
       TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();
        testData.periods[0].Start_Date__c = System.today();

        DMLException dmlEx;
        TimeCardPeriodAction.isFirstRun = true;

        try {
            update testData.periods[0];
        }
        catch(DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, dmlEx.getDmlType(0));
    }

    @IsTest
    public static void testTimeCards() {
        // Initialize data and remove other child records
       TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        DMLException dmlEx;

        try {
            delete testData.periods;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(StatusCode.DELETE_FAILED, dmlEx.getDmlType(0));
    }

    @IsTest
    public static void testStatusFieldError() {
       TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        DMLException dmlEx;

        try {
            testData.periods[0].Status__c = NULL;
            TimeCardPeriodAction.isFirstRun = true;
            update testData.periods[0];
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
    }

    @IsTest
    public static void testTimeCardPeriodNoNullPointerExceptionInsert() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createProjects()
                .createProjectTasks()
                .createTimeCards();

            System.runAs(testData.users.get(1)) {
                DMLException dmlEx;

                Time_Card_Period__c tcp = new Time_Card_Period__c();

                try {
                    insert tcp;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }

                System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));

            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

}