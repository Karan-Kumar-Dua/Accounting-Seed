@IsTest
private class JournalEntryLDVAutoReverseBatchTest {

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
            Database.executeBatch(new JournalEntryLDVAutoReverseBatch(new Set<Id>{testData.journalEntries[0].Id}), 200);
            Test.stopTest();

            System.assert(String.isNotBlank([SELECT Id, Auto_Reversal_JE__c FROM Journal_Entry__c WHERE Id =: testData.journalEntries[0].Id].Auto_Reversal_JE__c));
        }
    }
}