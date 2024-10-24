@IsTest
public class TimeCardControllerExtTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testTimeCardControllerExtSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.settings.Label_for_Time_Card_Variable_2__c = 'Test Label 1';
            testData.settings.Label_for_Time_Card_Variable_1__c = 'Test Label 1';
            update testData.settings;
            AccountingSettingsHandler.acctSeedSettings = NULL;

            //Instantiate class
            ApexPages.StandardController controller = new ApexPages.StandardController(testData.timeCards[0]);
            TimeCardControllerExt tce = new TimeCardControllerExt(controller);
            System.assertEquals([SELECT count() From Time_Card_Line__c WHERE Time_Card__c = :testData.timeCards[0].Id], tce.wrapperMap.size());

            tce.addTimeCardLineItem();
            System.assertEquals([SELECT count() FROM Time_Card_Line__c WHERE Time_Card__c = :testData.timeCards[0].Id] + 1, tce.wrapperMap.size());

            tce.selectedRow = 1;
            tce.deleteTimeCardLineItem();
            System.assertEquals([SELECT count() FROM Time_Card_Line__c WHERE Time_Card__c = :testData.timeCards[0].Id], tce.wrapperMap.size());

            System.assertEquals(tce.uiConfig.variable1Name, testData.settings.Label_for_Time_Card_Variable_1__c);
            System.assertEquals(tce.uiConfig.variable2Name, testData.settings.Label_for_Time_Card_Variable_2__c);

            //tce.getTimeCardDayHeader();
            System.assertEquals(7, tce.getDayHeaders().size());

            //tce.getTimeCardDayTotals();
            //System.assertEquals(7,tce.getDayTotals().size());

            // Add new time card line and assert time card line is committed to database
            tce.addTimeCardLineItem();
            tce.wrapperMap.values()[1].timeCardLine.Project__c = testData.projects[0].Id;
            tce.wrapperMap.values()[1].timeCardLine.Project_Task__c = testData.projectTasks[0].Id;

            tce.wrapperMap.values()[2].timeCardLine.Project__c = testData.projects[0].Id;
            tce.wrapperMap.values()[2].timeCardLine.Project_Task__c = testData.projectTasks[1].Id;
            tce.recalcPage();
            tce.selectedRow = 0;
            System.assertEquals([SELECT count() FROM Time_Card_Line__c WHERE Time_Card__c = :testData.timeCards[0].Id], tce.wrapperMap.size());
            System.assertNotEquals(NULL, tce.showComments());
        }

    }

    @IsTest
    public static void testTimeCardControllerExtEditError() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            ApexPages.StandardController controller = new ApexPages.StandardController(testData.timeCards[0]);
            TimeCardControllerExt tce = new TimeCardControllerExt(controller);
            Datetime timeCardLastModified = [SELECT Id, LastModifiedDate FROM Time_Card__c WHERE Id = :testData.timeCards[0].Id].LastModifiedDate;

            TestDataSuite.getOneSecondDelayByDateTime(timeCardLastModified);
            update testData.timeCards[0];
            tce.recalcPage();

            System.assertEquals(TimeCardControllerExt.LAST_MODIFIED_ERROR, ApexPages.getMessages()[0].getDetail());
        }

    }

    @IsTest         
    public static void testTimeCardControllerExtLastModifiedDateTimeError() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            ApexPages.StandardController controller = new ApexPages.StandardController(testData.timeCards[0]);
            TimeCardControllerExt tce = new TimeCardControllerExt(controller);

            ApexPages.StandardController controller2 = new ApexPages.StandardController(testData.timeCards[0]);
            TimeCardControllerExt tce2 = new TimeCardControllerExt(controller2);
            tce2.recalcPage();
            Datetime timeCardLastModified = [SELECT Id, LastModifiedDate FROM Time_Card__c WHERE Id = :testData.timeCards[0].Id].LastModifiedDate;

            TestDataSuite.getOneSecondDelayByDateTime(timeCardLastModified);
            update testData.timeCards[0];
            tce.recalcPage();

            System.assertEquals(TimeCardControllerExt.LAST_MODIFIED_ERROR, ApexPages.getMessages()[0].getDetail());
        }

    }
}