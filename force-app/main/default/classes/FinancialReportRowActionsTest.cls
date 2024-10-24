@isTest
private class FinancialReportRowActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testValidateFinRepRowsBeforeInsertOrUpdate() {

        TestDataSuite testData = TestDataSuite.getInstance()
            .createGlReportingGroups()
            .createGlReportingGroupLines()
            .createReportDefinitions()
            .createReportRows();
        
        List<Financial_Report_Row__c> rowsForInsert = new List<Financial_Report_Row__c>();
        List<Financial_Report_Row__c> rowsForUpdate = new List<Financial_Report_Row__c>();

        Financial_Report_Row__c testRow_1 = testData.reportRows[0].clone(false, true, false, false);
        testRow_1.Position__c = 0;
        rowsForInsert.add(testRow_1);

        Financial_Report_Row__c testRow_2 = testData.reportRows[1].clone(false, true, false, false);
        testRow_2.Type__c = NULL;
        rowsForInsert.add(testRow_2);

        Financial_Report_Row__c testRow_3 = testData.reportRows[2].clone(false, true, false, false);
        testRow_3.Type__c = 'Non valid type';
        rowsForInsert.add(testRow_3);

        Financial_Report_Row__c testRow_4 = testData.reportRows[3].clone(false, true, false, false);
        testRow_4.Type__c = 'GL Account';
        testRow_4.GL_Account__c = NULL;
        rowsForInsert.add(testRow_4);

        Financial_Report_Row__c testRow_5 = testData.reportRows[4].clone(false, true, false, false);
        testRow_5.Type__c = 'Reporting Group';
        testRow_5.GL_Account_Reporting_Group__c = NULL;
        rowsForInsert.add(testRow_5);

        Financial_Report_Row__c testRow_6 = testData.reportRows[5].clone(false, true, false, false);
        testRow_6.Type__c = 'Calculation %';
        testRow_6.Calculation__c = NULL;
        testRow_6.Position__c = 6;
        rowsForInsert.add(testRow_6);

        DMLException dmlEx;       
        try {    
            insert rowsForInsert;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }       
        
        System.assertEquals(FinancialReportRowActions.POSITION_VALUE_ERROR, dmlEx.getDmlMessage(0));
        System.assertEquals(FinancialReportRowActions.BLANK_TYPE_ERROR, dmlEx.getDmlMessage(1));
        System.assertEquals(FinancialReportRowActions.INVALID_TYPE_ERROR, dmlEx.getDmlMessage(2));
        System.assertEquals(FinancialReportRowActions.MUST_SELECT_GL_ACCOUNT_TYPE_ERROR, dmlEx.getDmlMessage(3));
        System.assertEquals(FinancialReportRowActions.MUST_SELECT_GL_ACCOUNT_REPORTING_GROUP_TYPE_ERROR, dmlEx.getDmlMessage(4));
        System.assertEquals(FinancialReportRowActions.EMPTY_CALCULATION_ERROR, dmlEx.getDmlMessage(5));

        Financial_Report_Row__c testRow_7 = testData.reportRows[6];
        testRow_7.Type__c = 'Calculation Number';
        testRow_7.Position__c = 3;
        testRow_7.Calculation__c = '{r1} + {r2} + {r3} + {r4}';
        rowsForUpdate.add(testRow_7);

        try {
            update rowsForUpdate;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }
        
    }

    @IsTest
    static void testCreateRowForCashFlowGLAccount() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashFlowCategories(false);

        System.runAs(testData.users[1]) {
            Financial_Report_Definition__c testRepDef = new Financial_Report_Definition__c(
                    Name = 'Test Report Definition'
            );
            insert testRepDef;

            Financial_Report_Row__c testFinRepRow = new Financial_Report_Row__c(
                Financial_Report_Definition__c = testRepDef.Id,
                Row_Label__c = testData.cashFlowCategories[0].Name,
                Type__c = 'GL Account',
                GL_Account__c = testData.cashFlowCategories[0].Id,
                Position__c = 10,
                Normal_Balance__c = 'Credit'
            );

            DmlException dmlEx;
            try {
                insert testFinRepRow;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(FinancialReportRowActions.CASH_FLOW_RELATED_GL_ACCOUNT_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    static void testUpdateRowForCashFlowGLAccount() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashFlowCategories(false);

        System.runAs(testData.users[1]) {
            Financial_Report_Definition__c testRepDef = new Financial_Report_Definition__c(
                Name = 'Test Report Definition'
            );
            insert testRepDef;

            Financial_Report_Row__c testFinRepRow = new Financial_Report_Row__c(
                Financial_Report_Definition__c = testRepDef.Id,
                Row_Label__c = testData.glAccounts[0].Name,
                Type__c = 'GL Account',
                GL_Account__c = testData.glAccounts[0].Id,
                Position__c = 10,
                Normal_Balance__c = 'Credit'
            );

            DmlException dmlEx;
            try {
                insert testFinRepRow;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);

            try {
                testFinRepRow.GL_Account__c = testData.cashFlowCategories[0].Id;
                update testFinRepRow;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(FinancialReportRowActions.CASH_FLOW_RELATED_GL_ACCOUNT_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    static void testCreateRowForGLAccountReportingGroupWithCashFlowGLAccountInside() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashFlowCategories(false);

        System.runAs(testData.users[1]) {
            Financial_Report_Definition__c testRepDef = new Financial_Report_Definition__c(
                Name = 'Test Report Definition'
            );
            insert testRepDef;

            GL_Account_Reporting_Group__c testGroup = new GL_Account_Reporting_Group__c(Name = 'Test Group');
            insert testGroup;

            List<GL_Account_Reporting_Group_Line__c> groupLines = new List<GL_Account_Reporting_Group_Line__c>();
            GL_Account_Reporting_Group_Line__c validGroupLine = new GL_Account_Reporting_Group_Line__c(
                GL_Account_Reporting_Group__c =  testGroup.Id,
                GL_Account__c = testData.glAccounts[0].Id
            );
            groupLines.add(validGroupLine);
            GL_Account_Reporting_Group_Line__c invalidGroupLine = new GL_Account_Reporting_Group_Line__c(
                GL_Account_Reporting_Group__c =  testGroup.Id,
                GL_Account__c = testData.cashFlowCategories[0].Id
            );
            groupLines.add(invalidGroupLine);

            insert groupLines;


            Financial_Report_Row__c testFinRepRow = new Financial_Report_Row__c(
                Financial_Report_Definition__c = testRepDef.Id,
                Row_Label__c = testData.glAccounts[0].Name,
                Type__c = 'Reporting Group',
                GL_Account_Reporting_Group__c = testGroup.Id,
                Position__c = 10,
                Normal_Balance__c = 'Credit'
            );

            DmlException dmlEx;
            try {
                insert testFinRepRow;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(FinancialReportRowActions.CASH_FLOW_RELATED_GL_ACCOUNT_IN_GROUP_ERROR, dmlEx.getDmlMessage(0));

        }
    }

    @IsTest
    static void testCreateRowForEmptyGLAccountReportingGroup() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Financial_Report_Definition__c testRepDef = new Financial_Report_Definition__c(
                Name = 'Test Report Definition'
            );
            insert testRepDef;

            GL_Account_Reporting_Group__c testGroup = new GL_Account_Reporting_Group__c(Name = 'Test Group');
            insert testGroup;

            Financial_Report_Row__c testFinRepRow = new Financial_Report_Row__c(
                Financial_Report_Definition__c = testRepDef.Id,
                Row_Label__c = testData.glAccounts[0].Name,
                Type__c = 'Reporting Group',
                GL_Account_Reporting_Group__c = testGroup.Id,
                Position__c = 10,
                Normal_Balance__c = 'Credit'
            );

            /*=======*/Test.startTest();/*==========*/
            DmlException dmlEx;
            try {
                insert testFinRepRow;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            /*========*/Test.stopTest();/*==========*/

            System.assertEquals(FinancialReportRowActions.EMPTY_GL_ACCOUNT_REPORTING_GROUP, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testFinancialReportRowNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashFlowCategories(false);

        System.runAs(testData.users[1]) {
            DMLException dmlEx;

            Financial_Report_Row__c frr = new Financial_Report_Row__c();

            try {
                insert frr;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

}