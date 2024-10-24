@IsTest
private class EnablementsQueueableTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testBehavior() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            List<AsyncApexJob> completedJobsBefore = [
                SELECT ID, Status, MethodName, ApexClass.Name
                FROM AsyncApexJob
                WHERE ApexClass.Name = 'EnablementsQueueable'
                AND Status = 'Completed'
            ];

            System.assertEquals(1, completedJobsBefore.size());

            Test.startTest();
            EnablementsQueueable enablementsJob = new EnablementsQueueable(
                TriggerOperation.AFTER_INSERT
                , new List<Accounting_Settings__c> {testData.settings}
            );
            System.enqueueJob(enablementsJob);
            Test.stopTest();

            List<AsyncApexJob> completedJobsAfter = [
                SELECT ID, Status, MethodName, ApexClass.Name
                FROM AsyncApexJob
                WHERE ApexClass.Name = 'EnablementsQueueable'
                AND Status = 'Completed'
            ];

            System.assertEquals(2, completedJobsAfter.size());
        }
    }
}