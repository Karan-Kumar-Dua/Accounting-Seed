@IsTest
private class ProjectTaskActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testAssociateDefaultLaborGLAccount() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks();

        // Insert and associate with default labor gl account
        Project_Task__c projTask = testData.projectTasks[0].clone(false);
        projTask.Labor_GL_Account__c = NULL;
        insert projTask;

        System.assertEquals(
            testData.settings.Default_Project_Task_Labor_GL_Account__c,
            [SELECT Labor_GL_Account__c FROM Project_Task__c WHERE Id = :projTask.Id].Labor_GL_Account__c
        );

        // Insert and throw exception no labor gl account
        testData.settings.Default_Project_Task_Labor_GL_Account__c = NULL;
        update testData.settings;
        AccountingSettingsHandler.acctSeedSettings = NULL;

        projTask = testData.projectTasks[0].clone(false);
        projTask.Labor_GL_Account__c = NULL;

        DMLException dmlEx;
        try {
            insert projTask;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }
        System.assertEquals(ProjectTaskActions.PROJECT_TASK_LABOR_GL_ACCOUNT_ERROR, dmlEx.getDMlMessage(0));
    }

    @IsTest
    private static void testProjectTaskNoNullPointerExceptionInsert() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency(); //will throw an exception in case of non-MC org

            System.runAs(testData.users.get(1)) {
                Project_Task__c pt = new Project_Task__c();
                DMLException dmlEx;
                try {
                    insert pt;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }
                System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
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
                delete testData.projectTasks;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(ProjectTaskActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

}