@IsTest
private class AutomatedJobResultsRetentionSchedTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testStartAutomatedJobResultsRetentionScheduler() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();

            String CRON_EXPRESSION = '0 13 * * * ?';

            String jobId = AutomatedJobResultsRetentionScheduler.startAutomatedJobResultsRetentionScheduler(CRON_EXPRESSION, 'AJR Retention Job Test');
            Test.stopTest();

            System.assertEquals(
                1,
                DomainUtils.getCronTriggerByJobName(new Set<String> {'AJR Retention Job Test'}).size()
            );

        }
    }
}