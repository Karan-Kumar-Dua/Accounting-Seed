@IsTest
public class ProjectDeepCloneTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testCloneProject() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Task theTask = new Task();
            theTask.WhatId = testData.projectTasks[0].Id;
            theTask.OwnerId = UserInfo.getUserId();
            theTask.ActivityDate = System.today();
            theTask.Status = 'In Progress';
            theTask.Priority = 'Normal';
            theTask.Subject = 'Test';
            insert theTask;

            ApexPages.StandardController controller = new ApexPages.StandardController(testData.projects[0]);
            ProjectDeepClone pdc = new ProjectDeepClone(controller);
            pdc.deepCloneForIds(true);

            System.assertEquals(1, [SELECT count() FROM Project__c WHERE Id = :pdc.clonedProject.Id]);
            System.assertEquals(2, [SELECT count() FROM Project_Task__c WHERE Project__c = :pdc.clonedProject.Id]);
            System.assertEquals(1, [SELECT count() FROM Task WHERE WhatId = :pdc.projTaskMap.values()[0].Id]);
        }

    }

    @IsTest
    public static void testCloneProjectProjectNameTruncate() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.projects[0].Name = 'test proect name adfhbsdfnbdfhdfhdfhdfshdfhdsfhfdhstrv je ewrnbbgaerbrehreutrbvh';
            update testData.projects[0];

            ApexPages.StandardController controller = new ApexPages.StandardController(testData.projects[0]);
            ProjectDeepClone pdc = new ProjectDeepClone(controller);
            pdc.deepCloneForIds(true);

            System.assertEquals(1, [SELECT count() FROM Project__c WHERE Id = :pdc.clonedProject.Id]);
            System.assertEquals(2, [SELECT count() FROM Project_Task__c WHERE Project__c = :pdc.clonedProject.Id]);
        }
    }
}