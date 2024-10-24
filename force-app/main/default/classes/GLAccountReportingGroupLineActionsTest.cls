@IsTest
public class GLAccountReportingGroupLineActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testInsertDuplicatedInNewCollection() {
        TestDataSuite testData = TestDataSuite.getInstance();

        List<GL_Account_Reporting_Group__c> reportingGroups = new List<GL_Account_Reporting_Group__c>{
            new GL_Account_Reporting_Group__c(Name = 'Test Reporting Group 1', Type__c = 'Balance Sheet'),
            new GL_Account_Reporting_Group__c(Name = 'Test Reporting Group 2', Type__c = 'Balance Sheet')
        };

        insert reportingGroups;

        List<GL_Account_Reporting_Group_Line__c> reportingGroupLines = new List<GL_Account_Reporting_Group_Line__c>{
            new GL_Account_Reporting_Group_Line__c(
                GL_Account_Reporting_Group__c = reportingGroups[0].Id,
                GL_Account__c = testData.glAccounts[0].Id
            ),
            new GL_Account_Reporting_Group_Line__c(
                GL_Account_Reporting_Group__c = reportingGroups[0].Id,
                GL_Account__c = testData.glAccounts[0].Id
            ),
            new GL_Account_Reporting_Group_Line__c(
                GL_Account_Reporting_Group__c = reportingGroups[1].Id,
                GL_Account__c = testData.glAccounts[0].Id
            )
        };

        DmlException dmlEx;
        try {
            insert reportingGroupLines;
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }

        System.assertEquals(
            GLAccountReportingGroupLineActions.DUPLICATED_GL_ACCOUNT_IN_REPORTING_GROUP,
            dmlEx.getDmlMessage(0)
        );

    }

    @IsTest
    private static void testUpdateDuplicatedInDB() {
        TestDataSuite testData = TestDataSuite.getInstance();

        List<GL_Account_Reporting_Group__c> reportingGroups = new List<GL_Account_Reporting_Group__c>{
            new GL_Account_Reporting_Group__c(Name = 'Test Reporting Group 1', Type__c = 'Balance Sheet'),
            new GL_Account_Reporting_Group__c(Name = 'Test Reporting Group 2', Type__c = 'Balance Sheet')
        };

        insert reportingGroups;

        List<GL_Account_Reporting_Group_Line__c> reportingGroupLines = new List<GL_Account_Reporting_Group_Line__c>{
            new GL_Account_Reporting_Group_Line__c(
                GL_Account_Reporting_Group__c = reportingGroups[0].Id,
                GL_Account__c = testData.glAccounts[0].Id
            ),
            new GL_Account_Reporting_Group_Line__c(
                GL_Account_Reporting_Group__c = reportingGroups[0].Id,
                GL_Account__c = testData.glAccounts[1].Id
            ),
            new GL_Account_Reporting_Group_Line__c(
                GL_Account_Reporting_Group__c = reportingGroups[1].Id,
                GL_Account__c = testData.glAccounts[0].Id
            )
        };

        DmlException dmlEx;
        try {
            insert reportingGroupLines;
        } catch (DmlException ex) {
            dmlEx = ex;
        }

        System.assertEquals(NULL, dmlEx);

        GL_Account_Reporting_Group_Line__c newRepGroupLine = [
            SELECT Id, GL_Account_Reporting_Group__c, GL_Account__c
            FROM GL_Account_Reporting_Group_Line__c
            WHERE GL_Account__c = :testData.glAccounts[1].Id
            LIMIT 1
        ];

        try {
            newRepGroupLine.GL_Account__c = testData.glAccounts[0].Id;
            update newRepGroupLine;
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }

        System.assertEquals(
            GLAccountReportingGroupLineActions.DUPLICATED_GL_ACCOUNT_IN_REPORTING_GROUP,
            dmlEx.getDmlMessage(0)
        );

    }

    @IsTest
    public static void testGLAccountReportingGroupLineNoNullPointerExceptionInsert() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency();

            System.runAs(testData.users.get(1)) {
                DMLException dmlEx;

                GL_Account_Reporting_Group_Line__c gla = new GL_Account_Reporting_Group_Line__c();

                try {
                    insert gla;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }
                System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
            }
        }
        catch (Exception ex) {

        }
    }

}