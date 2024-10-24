@IsTest
private class FinancialReporterSettingsActionsTest {

    @TestSetup
    private static void createTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testPreventInsertFinancialReporterSettings() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            DmlException dmlEx;
            try {
                Financial_Reporter_Settings__c newSettings = new Financial_Reporter_Settings__c(
                    Company_Name__c = UserInfo.getOrganizationName(),
                    Column_Header_Variant__c = FinancialReporterSettingsHandler.COLUMN_HEADER_VARIANT_ACCOUNTING_PERIOD,
                    Rounding__c = FinancialReporterSettingsHandler.ROUNDING_NO_ROUNDING
                );
                insert newSettings;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(FinancialReporterSettingsActions.FRS_INSERT_DML_RESTRICTION_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testPreventInsertFinancialReporterSettingsBypassed() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            DmlException dmlEx;
            try {
                Financial_Reporter_Settings__c newSettings = new Financial_Reporter_Settings__c(
                    Company_Name__c = UserInfo.getOrganizationName(),
                    Column_Header_Variant__c = FinancialReporterSettingsHandler.COLUMN_HEADER_VARIANT_ACCOUNTING_PERIOD,
                    Rounding__c = FinancialReporterSettingsHandler.ROUNDING_NO_ROUNDING
                );
                FinancialReporterSettingsActions.isDmlRestrictionBypassEnabled = true;
                insert newSettings;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(null, dmlEx);
        }
    }

    @IsTest
    private static void testPreventUpdateFinancialReporterSettings() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Financial_Reporter_Settings__c newSettings = new Financial_Reporter_Settings__c(
                Company_Name__c = UserInfo.getOrganizationName(),
                Column_Header_Variant__c = FinancialReporterSettingsHandler.COLUMN_HEADER_VARIANT_ACCOUNTING_PERIOD,
                Rounding__c = FinancialReporterSettingsHandler.ROUNDING_NO_ROUNDING
            );

            DmlException dmlEx;
            try {
                FinancialReporterSettingsActions.isDmlRestrictionBypassEnabled = true;
                insert newSettings;
                FinancialReporterSettingsActions.isDmlRestrictionBypassEnabled = false;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(null, dmlEx);

            try {
                newSettings.Company_Name__c = 'new name';
                update newSettings;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(FinancialReporterSettingsActions.FRS_UPDATE_DML_RESTRICTION_ERROR, dmlEx.getDmlMessage(0));
        }
    }

}