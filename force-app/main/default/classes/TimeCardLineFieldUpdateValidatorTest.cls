@IsTest
private class TimeCardLineFieldUpdateValidatorTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testValidatePreventDeleteActionPosted() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards(true);

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new TimeCardLineFieldUpdateValidator();

            DMLException dmlEx;

            try {
                delete testData.timeCardLines[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.POSTED_DELETE_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @isTest
    private static void testValidateLockedFieldPosted() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards(true);

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new TimeCardLineFieldUpdateValidator();

            DMLException dmlEx;

            try {
                testData.timeCardLines[0].Project__c = testData.projects[1].Id;
                testData.timeCardLines[0].Project_Task__c = testData.projectTasks[2].Id;
                update testData.timeCardLines[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(SourceDocumentUpdateFieldValidator.POSTED_UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFieldsPosted), sfu.postedStatusValues[0]}),
                dmlEx.getDmlMessage(0));
        }
    }
}