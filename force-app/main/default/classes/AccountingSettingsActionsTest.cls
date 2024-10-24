@IsTest
private class AccountingSettingsActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void enableStdCostInTestContext() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            Accounting_Settings__c newSetting = [SELECT Id FROM Accounting_Settings__c LIMIT 1];
            newSetting.Inventory_Valuation_Method__c = 'Standard Cost';

            Test.startTest();

            update newSetting;

            Test.stopTest();

            System.assert([SELECT Id,Inventory_Valuation_Method__c FROM Accounting_Settings__c].Inventory_Valuation_Method__c == 'Standard Cost');
        }
    }

    @IsTest
    private static void enforceAvgCostValuationMethod() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            AccountingSettingsActions.skipPreventUpdateInventoryValuationMethod = false;
            Accounting_Settings__c newSetting = [SELECT Id FROM Accounting_Settings__c LIMIT 1];
            newSetting.Inventory_Valuation_Method__c = 'Standard Cost';

            Test.startTest();

            DmlException dmlEx;
            try {
                update newSetting;
            } 
            catch (DmlException ex) {
                dmlEx = ex;
            }

            Test.stopTest();

            System.assertEquals(AccountingSettingsActions.CONTACT_AS_SUPPORT, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testPreventInsertExtraRecords() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Settings__c newSetting = testData.settings.clone(false, true);

            Test.startTest();

            DmlException dmlEx;
            try {
                insert newSetting;
            } 
            catch (DmlException ex) {
                dmlEx = ex;
            }

            Test.stopTest();

            System.assertEquals(AccountingSettingsActions.EXTRA_SETTINGS_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testPreventUpdateAvalaraConfiguration() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            DmlException dmlEx;
            try {
                testData.settings.Enable_Avalara_Tax_Calculation__c = true;
                update testData.settings;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(
                    AccountingSettingsActions.UPDATE_AVALARA_CONFIGURATION_ERROR,
                    new List<String>{
                        FinancialSuiteUtils.formatFieldStrings(
                            Accounting_Settings__c.SObjectType,
                            new List<String>{AccountingSettingsActions.nonUpdateAvalaraFields.get(0)}
                        )
                    }
                ),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    private static void testPreventUpdateAvalaraConfigurationSkipped() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            DmlException dmlEx;
            try {
                testData.settings.Avalara_Production_Endpoint__c = true;
                AccountingSettingsActions.skipAvalaraFieldsUpdateValidation = true;
                update testData.settings;
            } 
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
            System.assertEquals(
                true, [
                    SELECT Id, Avalara_Production_Endpoint__c FROM Accounting_Settings__c WHERE Id = :testData.settings.Id
                ].Avalara_Production_Endpoint__c
            );
        }
    }

    @IsTest
    public static void testPreventPostSettingUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            DmlException dmlEx;

            try {
                AccountingSettingsActions.skipPreventUpdatePostSettings = false;
                testData.settings.Post_Settings__c = HeaderLevelTaxHelper.LINE_LEVEL_POST;

                update testData.settings;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(true, dmlEx.getMessage().contains(AccountingSettingsActions.CONTACT_AS_SUPPORT));
        }
    }

    @IsTest
    public static void testEnableMultiCurrency() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            DmlException dmlEx;

            try {
                testData.settings.Enable_Multi_Currency__c = true;

                update testData.settings;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(true, dmlEx.getMessage().contains(AccountingSettingsActions.CONTACT_AS_SUPPORT));
        }
    }

    @IsTest
    public static void testValidateAvaVATReportingSettings() {
        TestDataSuite testData = TestDataSuite.getInstance()
        .setAvaVATReportingEnabled();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            DmlException dmlEx;

            try {
                AccountingSettingsActions.skipPreventUpdatePostSettingsValidations = false;
                AccountingSettingsHandler.setIsAvaVATReportingEnabled(true);
                testData.settings.Post_Settings__c = HeaderLevelTaxHelper.LINE_LEVEL_POST;
                
                update testData.settings;
            } 
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);            
            System.assertEquals(true, dmlEx.getMessage().contains(AccountingSettingsActions.AVAVAT_HLP_REQUIRED_ERROR));

            dmlEx = NULL;
            try {
                AccountingSettingsActions.skipPreventUpdatePostSettingsValidations = false;
                AccountingSettingsHandler.setIsAvaVATReportingEnabled(true);
                testData.settings.Post_Settings__c = HeaderLevelTaxHelper.HEADER_LEVEL_POST;
                
                update testData.settings;
            } 
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);  
            
            dmlEx = NULL;
            try {
                AccountingSettingsActions.skipPreventUpdatePostSettingsValidations = false;
                AccountingSettingsHandler.setIsAvaVATReportingEnabled(false);
                testData.settings.Post_Settings__c = HeaderLevelTaxHelper.LINE_LEVEL_POST;
                
                update testData.settings;
            } 
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);  

            dmlEx = NULL;
            try {
                AccountingSettingsActions.skipPreventUpdatePostSettingsValidations = false;
                AccountingSettingsHandler.setIsAvaVATReportingEnabled(true);
                update testData.settings;
            } 
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);  
            System.assertEquals(true, dmlEx.getMessage().contains(AccountingSettingsActions.AVAVAT_HLP_REQUIRED_ERROR));
        }
    }

    @IsTest
    public static void testAccountingSettingsNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            try {
                Accounting_Settings__c accSet = new Accounting_Settings__c();
                insert accSet;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

    @IsTest
    public static void testAccountingSettingsValidateAvaTaxSalesTaxNonBalanceSheetUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            System.assertNotEquals('Balance Sheet',testData.glAccounts[15].Type__c);
            System.assertNotEquals('Liabilities',testData.glAccounts[15].Sub_Type_1__c);

            DmlException dmlEx;
            try {
                testData.settings.Avalara_Sales_Tax_GL_Account__c = testData.glAccounts[15].Id;
                update testData.settings;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(AccountingSettingsActions.AVALARA_GL_ACCOUNT_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testAccountingSettingsValidateAvaTaxSalesTaxNonLiabilitiesUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            System.assertEquals('Balance Sheet',testData.glAccounts[0].Type__c);
            System.assertNotEquals('Liabilities',testData.glAccounts[0].Sub_Type_1__c);

            DmlException dmlEx;
            try {
                testData.settings.Avalara_Sales_Tax_GL_Account__c = testData.glAccounts[0].Id;
                update testData.settings;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(AccountingSettingsActions.AVALARA_GL_ACCOUNT_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testAccountingSettingsValidateAvaTaxSalesTaxUpdateSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            System.assertEquals('Balance Sheet',testData.glAccounts[5].Type__c);
            System.assertEquals('Liabilities',testData.glAccounts[5].Sub_Type_1__c);

            DmlException dmlEx;
            try {
                testData.settings.Avalara_Sales_Tax_GL_Account__c = testData.glAccounts[5].Id;
                update testData.settings;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
        }
    }

    @IsTest
    public static void testCreateLedgerCustomSettingsIfNotExist() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            List<Ledger_Custom_Settings__c> ledgerSettings = [SELECT Id FROM Ledger_Custom_Settings__c];
            System.assertEquals(1, ledgerSettings.size());

            delete ledgerSettings;
            ledgerSettings = [SELECT Id FROM Ledger_Custom_Settings__c];
            System.assertEquals(0, ledgerSettings.size());
            
            Accounting_Settings__c backup = testData.settings;
            delete testData.settings;
            backup.Id = NULL;
            insert backup;

            ledgerSettings = [SELECT Id, Ledger_Id__c FROM Ledger_Custom_Settings__c];
            System.assertEquals(1, ledgerSettings.size());
            System.assertEquals(testData.ledgers[0].Id, ledgerSettings[0].Ledger_Id__c);
        }
    }

    @IsTest
    public static void testPopulateRequiredFieldsOnInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Settings__c copyAccountingSettings = testData.settings.clone(false, true, false, false);
            delete testData.settings;
            System.assertEquals(0, [SELECT count() FROM Accounting_Settings__c LIMIT 1]);

            copyAccountingSettings.Enable_Avalara_Tax_Calculation__c = true;
            copyAccountingSettings.Avalara_Production_Endpoint__c = true;
            copyAccountingSettings.Archive_Month_Offset__c = 50;
            copyAccountingSettings.Ledger_Limit__c = 25;

            insert copyAccountingSettings;

            copyAccountingSettings = [
                SELECT  Id,
                        Enable_Avalara_Tax_Calculation__c,
                        Avalara_Production_Endpoint__c,
                        Archive_Month_Offset__c,
                        Ledger_Limit__c
                FROM Accounting_Settings__c
                WHERE Id = :copyAccountingSettings.Id
            ];

            System.assertEquals(false, copyAccountingSettings.Enable_Avalara_Tax_Calculation__c);
            System.assertEquals(false, copyAccountingSettings.Avalara_Production_Endpoint__c);
            System.assertEquals(15, copyAccountingSettings.Archive_Month_Offset__c);
            System.assertEquals(1, copyAccountingSettings.Ledger_Limit__c);
        }
    }

    @IsTest
    public static void testPopulateHeaderLevelPostingOnInsert() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setERPEnabled();

        System.runAs(testData.users.get(1)) {
            Accounting_Settings__c copyAccountingSettings = testData.settings.clone(false, true, false, false);
            delete testData.settings;
            System.assertEquals(0, [SELECT count() FROM Accounting_Settings__c LIMIT 1]);

            copyAccountingSettings.Inventory_Valuation_Method__c = 'Standard Cost';
            copyAccountingSettings.Post_Settings__c = HeaderLevelTaxHelper.HEADER_LEVEL_POST;

            DmlException dmlEx;
            try {
                AccountingSettingsActions.skipPreventUpdatePostSettingsValidations = false;
                insert copyAccountingSettings;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(HeaderLevelTaxHelper.HEADER_LEVEL_POSTING_SET_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testPopulateHeaderLevelPostingOnUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setERPEnabled();

        System.runAs(testData.users.get(1)) {
            Accounting_Settings__c settings = testData.settings;
            settings.Inventory_Valuation_Method__c = 'Standard Cost';
            settings.Post_Settings__c = HeaderLevelTaxHelper.HEADER_LEVEL_POST;

            DmlException dmlEx;
            try {
                AccountingSettingsActions.skipPreventUpdatePostSettingsValidations = false;
                update settings;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(HeaderLevelTaxHelper.HEADER_LEVEL_POSTING_SET_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testupdatePaymentProcessors() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();
        System.runAs(testData.users.get(1)) {
            Accounting_Settings__c newSetting = testData.settings;
            newSetting.Stripe_Connected_Account_Id__c = testData.paymentProcessors[0].Id;

            Test.startTest();

            update newSetting;

            Test.stopTest();

            Accounting_Settings__c updatedSettings = [SELECT Stripe_Connected_Account_Id__c FROM Accounting_Settings__c WHERE Id = :newSetting.Id];
            System.assertEquals(newSetting.Stripe_Connected_Account_Id__c, updatedSettings.Stripe_Connected_Account_Id__c);

            Payment_Processor__c updatedProcessor = [SELECT Global_Default_Payment_Processor__c FROM Payment_Processor__c WHERE Id = :newSetting.Stripe_Connected_Account_Id__c];
            System.assertEquals(true, updatedProcessor.Global_Default_Payment_Processor__c);
        }
    }

    @IsTest
    private static void testupdatePaymentProcessorsNone() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();
        System.runAs(testData.users.get(1)) {
            Accounting_Settings__c newSetting = testData.settings;
            newSetting.Stripe_Connected_Account_Id__c = testData.paymentProcessors[0].Id;

            Test.startTest();

            update newSetting;

            System.assertEquals(1, [SELECT count() FROM Payment_Processor__c WHERE Global_Default_Payment_Processor__c = TRUE]);

            newSetting.Stripe_Connected_Account_Id__c = null;

            update newSetting;

            System.assertEquals(0, [SELECT count() FROM Payment_Processor__c WHERE Global_Default_Payment_Processor__c = TRUE]);

            Test.stopTest();
        }
    }

}