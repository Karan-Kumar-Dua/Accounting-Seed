@IsTest
private class TaxServiceFactoryTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testGetClassInstanceSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Tax_Settings__c actualSetting = new Tax_Settings__c();
            actualSetting.Tax_Settings_Method__c = TaxSettingsActions.NATIVE_TAX_METHOD;
            insert actualSetting;

            Ledger__c selectedLedger = LedgerHandler.getInstanceWithSharing(true).getLedgerById(testData.ledgers[0].Id);
            selectedLedger.Tax_Settings__c = actualSetting.Id;
            update selectedLedger;

            Map<Id, AbstractTaxService> taxServices = TaxServiceFactory.getTaxMethod(new Set<Id> {actualSetting.Id});

            System.assertEquals(true, taxServices.values()[0] instanceof NativeTaxHeaderLevel);
        }

    }

    @IsTest
    public static void testGetMultipleClassesInstanceSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings().createAddressObjects();

        System.runAs(testData.users.get(1)) {
            Tax_Settings__c actualSetting = new Tax_Settings__c();
            actualSetting.Tax_Settings_Method__c = TaxSettingsActions.NATIVE_TAX_METHOD;
            insert actualSetting;

            AvaTax_License__c newLicense = new AvaTax_License__c();
            newLicense.Active_AvaTax_Endpoint__c = 'testEndpoint';
            newLicense.AvaTax_Account_ID__c = 'testId';
            newLicense.AvaTax_License_Key__c = 'testKey';
            insert newLicense;

            Tax_Settings__c budgetSetting = new Tax_Settings__c();
            budgetSetting.Tax_Settings_Method__c = TaxSettingsActions.AVA_TAX_METHOD;
            budgetSetting.Origin_Address__c = testData.addressObjects[0].Id;
            budgetSetting.Sales_Tax_GL_Account__c = testData.glAccounts[15].Id;
            budgetSetting.AvaTax_License__c = newLicense.Id;
            insert budgetSetting;

            Ledger__c selectedLedger = LedgerHandler.getInstanceWithSharing(true).getLedgerById(testData.ledgers[0].Id);
            selectedLedger.Tax_Settings__c = actualSetting.Id;
            update selectedLedger;
            Ledger__c selectedLedger2 = LedgerHandler.getInstanceWithSharing(true).getLedgerById(testData.ledgers[1].Id);
            selectedLedger2.Tax_Settings__c = budgetSetting.Id;
            selectedLedger2.Sales_Tax_Company_Code__c = 'testCode';
            update selectedLedger2;

            Map<Id, AbstractTaxService> taxServices = TaxServiceFactory.getTaxMethod(new Set<Id> {actualSetting.Id, budgetSetting.Id});

            System.assertEquals(true, taxServices.values()[0] instanceof NativeTaxHeaderLevel);
            System.assertEquals(true, taxServices.values()[1] instanceof AvaTaxHeaderLevel);

        }

    }

    @IsTest
    public static void testGetClassInstanceLineLevelSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings().setLineLevelPost();

        System.runAs(testData.users.get(1)) {
            Tax_Settings__c actualSetting = new Tax_Settings__c();
            actualSetting.Tax_Settings_Method__c = TaxSettingsActions.NATIVE_TAX_METHOD;
            insert actualSetting;

            Ledger__c selectedLedger = LedgerHandler.getInstanceWithSharing(true).getLedgerById(testData.ledgers[0].Id);
            selectedLedger.Tax_Settings__c = actualSetting.Id;
            update selectedLedger;

            Map<Id, AbstractTaxService> taxServices = TaxServiceFactory.getTaxMethod(new Set<Id> {actualSetting.Id});

            System.assertEquals(true, taxServices.values()[0] instanceof NativeTaxLineLevel);
        }

    }
}