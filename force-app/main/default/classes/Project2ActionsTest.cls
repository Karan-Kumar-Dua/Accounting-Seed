@IsTest
private class Project2ActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testPreventDeleteIfHasRelatedRecords() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            DmlException dmlEx;
            try {
                delete testData.projects;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(Project2Actions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

}