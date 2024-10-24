@IsTest
private class JournalEntryLDVCloneBatchTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testBehavior() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(false);

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Set<Id> sourceIds = new Set<Id>{testData.journalEntries[0].Id};
            JournalEntryLDVCloneBatch batchInstance = new JournalEntryLDVCloneBatch(
                sourceIds,
                testData.acctPeriods[1].Id,
                Date.today(),
                null,
                false
            );
            Database.executeBatch(batchInstance);

            Test.stopTest();

            System.assertNotEquals(true, [SELECT Id FROM Journal_Entry__c WHERE Journal_Date__c =: Date.today()].isEmpty());
        }
    }

}