@isTest
private class FinancialReportColumnActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    
    @isTest
    static void testValidateFinRepColumnsBeforeInsertOrUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createReportDefinitions()
            .createReportColumns();

        List<Financial_Report_Column__c> colsForInsert = new List<Financial_Report_Column__c>();
        List<Financial_Report_Column__c> colsForUpdate = new List<Financial_Report_Column__c>();

        Financial_Report_Column__c testCol_1 = testData.reportCols[0].clone(false, true, false, false);
        testCol_1.Position__c = 0;
        colsForInsert.add(testCol_1);

        Financial_Report_Column__c testCol_2 = testData.reportCols[1].clone(false, true, false, false);
        testCol_2.Type__c = NULL;
        colsForInsert.add(testCol_2);

        Financial_Report_Column__c testCol_3 = testData.reportCols[2].clone(false, true, false, false);
        testCol_3.Type__c = 'Invalid Type';
        colsForInsert.add(testCol_3);

        Financial_Report_Column__c testCol_4 = testData.reportCols[3].clone(false, true, false, false);
        testCol_4.Type__c = 'Calculation %';
        testCol_4.Calculation__c = NULL;
        testCol_4.Position__c = 6;
        colsForInsert.add(testCol_4);

        Financial_Report_Column__c testCol_5 = testData.reportCols[4].clone(false, true, false, false);
        testCol_5.Type__c = 'Current Period';//Non Calculation Type
        testCol_5.Ledger__c = NULL;
        colsForInsert.add(testCol_5);

        DmlException dmlEx;
        try {
            insert colsForInsert;
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }

        System.assertEquals(FinancialReportColumnActions.POSITION_VALUE_ERROR, dmlEx.getDmlMessage(0));
        System.assertEquals(FinancialReportColumnActions.BLANK_TYPE_ERROR, dmlEx.getDmlMessage(1));
        System.assertEquals(FinancialReportColumnActions.INVALID_TYPE_ERROR, dmlEx.getDmlMessage(2));
        System.assertEquals(FinancialReportColumnActions.EMPTY_CALCULATION_ERROR, dmlEx.getDmlMessage(3));
        System.assertEquals(
            String.format(FinancialReportColumnActions.USE_VALID_LEDGER, new List<String>{'Current Period'}), 
            dmlEx.getDmlMessage(4)
        );

        Financial_Report_Column__c testCol_6 = testData.reportCols[5];
        testCol_6.Type__c = 'Calculation Number';
        testCol_6.Position__c = 3;
        testCol_6.Calculation__c = '{c1} + {c2} + {c3} + {c4}';
        colsForUpdate.add(testCol_6);

        dmlEx = NULL;
        try {
            update colsForUpdate;
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }

        System.assertNotEquals(NULL, dmlEx);
    }

    @IsTest
    public static void testFinancialReportColumnNoNullPointerExceptionInsert() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency();

            System.runAs(testData.users.get(1)) {
                DMLException dmlEx;

                Financial_Report_Column__c frc = new Financial_Report_Column__c();

                try {
                    insert frc;
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