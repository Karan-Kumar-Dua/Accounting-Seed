@IsTest
public class JournalEntryReverseDeepCloneTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    static testmethod void testDeepCloneReverse() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            ApexPages.StandardController con = new ApexPages.StandardController(testData.journalEntries[0]);
            JournalEntryReverseDeepClone ext = new JournalEntryReverseDeepClone(con);

            PageReference pr = ext.jeCloneWithLines();
            System.assertEquals(ext.lstInsertJELines.size(), ext.lstJELines.size());
        }

    }

}