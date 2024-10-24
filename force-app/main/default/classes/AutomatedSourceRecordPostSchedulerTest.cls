@IsTest
private class AutomatedSourceRecordPostSchedulerTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testBillingExecute() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            String CRON_EXP = '0 0 0 * * ? *';
            // Schedule the test job
            String jobId = AutomatedSourceRecordPostScheduler.startAutomatedSourceRecordPostScheduler(
                CRON_EXP, new List<String>{'Billings'}
            );
            // Get the information from the CronTrigger API object 
            CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE Id = :jobId];
            // Verify the job has not run 
            System.assertEquals(0, ct.TimesTriggered);
            Test.stopTest();
        }
    }

    @IsTest
    static void testPayableExecute() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            String CRON_EXP = '0 0 0 * * ? *';
            // Schedule the test job
            String jobId = AutomatedSourceRecordPostScheduler.startAutomatedSourceRecordPostScheduler(
                CRON_EXP, new List<String>{'Payables'}
            );
            // Get the information from the CronTrigger API object 
            CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE Id = :jobId];
            // Verify the job has not run
            System.assertEquals(0, ct.TimesTriggered);
            Test.stopTest();
        }
    }

    @IsTest
    static void testTimeCardExecute() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createTimeCards();

        System.runAs(testData.users[1]) {
            Test.startTest();
            String CRON_EXP = '0 0 0 * * ? *';
            // Schedule the test job
            String jobId = AutomatedSourceRecordPostScheduler.startAutomatedSourceRecordPostScheduler(
                CRON_EXP, new List<String>{'Time Cards'}
            );
            // Get the information from the CronTrigger API object
            CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE Id = :jobId];
            // Verify the job has not run 
            System.assertEquals(0, ct.TimesTriggered);
            Test.stopTest();
        }
    }

}