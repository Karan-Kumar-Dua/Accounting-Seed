@IsTest
private class TaxSettingsActionsTest {
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testTaxSettingsActionsSetRequiredFieldsInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            List<Tax_Settings__c> taxSettings = new List<Tax_Settings__c>();
            taxSettings.add(
                    new Tax_Settings__c(
                            Name = 'Test',
                            Tax_Settings_Method__c = TaxSettingsActions.AVA_TAX_METHOD
                    )
            );

            try {
                insert taxSettings;
            } catch (DmlException ex) {
                System.assert(ex.getDmlMessage(0) == SObjectActions.REQUIRED_FIELD_ERROR);
            }

            taxSettings[0].Tax_Settings_Method__c = TaxSettingsActions.NATIVE_TAX_METHOD;
            insert taxSettings;

            taxSettings[0].Tax_Settings_Method__c = TaxSettingsActions.AVA_TAX_METHOD;
            try {
                update taxSettings;
            } catch (DmlException ex) {
                System.assert(ex.getDmlMessage(0) == SObjectActions.REQUIRED_FIELD_ERROR);
            }
        }
    }
}