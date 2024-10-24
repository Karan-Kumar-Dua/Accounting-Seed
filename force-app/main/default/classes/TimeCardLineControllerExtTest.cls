@IsTest
public class TimeCardLineControllerExtTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testTimeCardLineControllerExtSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            ApexPages.StandardController controller = new ApexPages.StandardController(testData.timeCardLines[0]);
            TimeCardLineControllerExt tce = new TimeCardLineControllerExt(controller);

            System.assertNotEquals(NULL, tce.saveBack().getUrl());
        }

    }
    
    @IsTest
    public static void testTimeCardLineControllerExtLastModifiedError() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            ApexPages.StandardController controller = new ApexPages.StandardController(testData.timeCardLines[0]);
            TimeCardLineControllerExt tce = new TimeCardLineControllerExt(controller);
            Datetime timeCardLastModified = [SELECT Id, LastModifiedDate FROM Time_Card__c WHERE Id = :testData.timeCards[0].Id].LastModifiedDate;

            TestDataSuite.getOneSecondDelayByDateTime(timeCardLastModified);
            update testData.timeCards[0];

            tce.saveBack();
            System.assertEquals(TimeCardLineControllerExt.LAST_MODIFIED_ERROR, ApexPages.getMessages()[0].getDetail());
        }

    }
}