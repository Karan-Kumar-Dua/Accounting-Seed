@isTest
private class AccountingVariableActionsTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testChangeTypeError() {
        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            testData.accountingVariables1.get(0).Type__c = 'GL Account Variable 2';

            Test.startTest();

            DMLException dmlEx;
            try {
                update testData.accountingVariables1.get(0);
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            Test.stopTest();

            System.assertEquals(
                AccountingVariableActions.TYPE_CHANGE_ERROR,
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @isTest
    private static void testDeleteWhenRelatedRecordExistsError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            //Create additional Accounting Variables with type "Time Card Variable 1" & "Time Card Variable 2"
            List<Accounting_Variable__c> tcvs = new List<Accounting_Variable__c>();
            Accounting_Variable__c tcv1 = new Accounting_Variable__c(
                Name = 'TCV-1',
                Active__c = true,
                Type__c = AccountingVariableActions.TIME_CARD_VARIABLE_1
            );
            tcvs.add(tcv1);

            Accounting_Variable__c tcv2 = new Accounting_Variable__c(
                Name = 'TCV-2',
                Active__c = true,
                Type__c = AccountingVariableActions.TIME_CARD_VARIABLE_2
            );
            tcvs.add(tcv2);
            insert tcvs;

            Journal_Entry_Line__c testJeLine = testData.journalEntryLines[0];
            testJeLine.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            testJeLine.GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            testJeLine.GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            testJeLine.GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            testJeLine.Time_Card_Variable_1__c = tcv1.Id;
            testJeLine.Time_Card_Variable_2__c = tcv2.Id;
            update testJeLine;

            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Journal_Entry__c>{testData.journalEntries[0]});
            System.assertEquals(true, postResults[0].isSuccess);

            Test.startTest();
            DMLException dmlEx;
            try {
                delete testData.accountingVariables1.get(0);
            } catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(AccountingVariableActions.DELETE_ERROR, dmlEx.getDmlMessage(0));

            dmlEx = NULL;
            try {
                delete testData.accountingVariables2.get(0);
            } catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(AccountingVariableActions.DELETE_ERROR, dmlEx.getDmlMessage(0));

            dmlEx = NULL;
            try {
                delete testData.accountingVariables3.get(0);
            } catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(AccountingVariableActions.DELETE_ERROR, dmlEx.getDmlMessage(0));

            dmlEx = NULL;
            try {
                delete testData.accountingVariables4.get(0);
            } catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(AccountingVariableActions.DELETE_ERROR, dmlEx.getDmlMessage(0));

            dmlEx = NULL;
            try {
                delete tcv1;
            } catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(AccountingVariableActions.DELETE_ERROR, dmlEx.getDmlMessage(0));

            dmlEx = NULL;
            try {
                delete tcv2;
            } catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(AccountingVariableActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }
    }
    
    @IsTest
    public static void testAccountingVariableNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            try {
                Accounting_Variable__c accVar = new Accounting_Variable__c();
                insert accVar;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

    @IsTest
    private static void testTotalNumberOfGlavLimit() {
        FeatureManagement.setPackageIntegerValue(FeatureManagementHandler.FP_GLAV_LIMIT, 10);
        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            Integer currentNumberOfExistedGLAVs = DomainUtils.countActiveGLAVs();
            System.assertEquals(8, currentNumberOfExistedGLAVs);
            System.assertEquals(10, AccountingVariableActions.GLAV_TOTAL_LIMIT);

            List<Accounting_Variable__c> newGLAVs = new List<Accounting_Variable__c>{
                testData.accountingVariables1[0].clone(),
                testData.accountingVariables2[0].clone(),
                testData.accountingVariables3[0].clone(),
                testData.accountingVariables4[0].clone()
            };

            DMLException dmlEx;
            try {
                insert newGLAVs;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(AccountingVariableActions.GLAV_MAX_LIMIT_REACHED, dmlEx.getDmlMessage(0));
        }
    }

}