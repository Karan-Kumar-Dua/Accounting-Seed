@IsTest
public with sharing class AccountingSettingsHelperTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testGetSettings() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Accounting_Settings__c settings = AccountingSettingsHelper.getSettings();
            System.assertNotEquals(null, settings);
            System.assertEquals(testData.settings.Id, settings.Id);
            Test.stopTest();
        }
    }

    @IsTest
    private static void testGetSettingsNoneExist() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            delete testData.settings;

            Test.startTest();
            Accounting_Settings__c settings = AccountingSettingsHelper.getSettings();
            System.assertNotEquals(null, settings);
            System.assertEquals(null, settings.Id);
            Test.stopTest();
        }
    }

    @IsTest
    private static void testGetSettingsMultipleExist() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Accounting_Settings__c clone = testData.settings.clone(false, true, false, false);
            AccountingSettingsActions.isPreventUpdateOverride = true;
            insert clone;
            AccountingSettingsActions.isPreventUpdateOverride = false;
            
            Test.startTest();
            Accounting_Settings__c settings = AccountingSettingsHelper.getSettings();
            System.assertNotEquals(null, settings);
            System.assert(settings.Id == testData.settings.Id || settings.Id == clone.Id);
            Test.stopTest();
        }
    }

    @IsTest
    private static void testSave() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Accounting_Settings__c settings = AccountingSettingsHelper.getSettings();
            settings.Amount_Right_Offset__c = 1;
            AccountingSettingsHelper.save(settings);
            Test.stopTest();

            System.assertEquals(1, [SELECT Amount_Right_Offset__c FROM Accounting_Settings__c LIMIT 1].Amount_Right_Offset__c);
        }
    }

    @IsTest
    private static void testSaveError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Exception expectedEx;
            try {
                testData.settings.Automated_Job_Results_Retention_Days__c = -100;
                AccountingSettingsHelper.save(testData.settings);
            }
            catch (AccountingSettingsHelper.AccountingSettingsHelperException e) {
                expectedEx = e;
            }
            System.assertNotEquals(null, expectedEx);
            System.assertEquals(String.format(Label.ERR_RANGE, new String[]{'1','365'}), expectedEx.getMessage());
            Test.stopTest();
        }
    }

    @IsTest
    private static void saveWithAJRRetentionJobTime() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            List<CronTrigger> cronTab = new List<CronTrigger>();
            cronTab = [
                SELECT NextFireTime
                FROM CronTrigger
                WHERE CronJobDetail.Name = 'AJR Retention Job'
            ];
            System.assertEquals(0, cronTab.size());

            Test.startTest();
            Integer fireNext = DateTime.now().hour() == 0 ? DateTime.now().hour() + 1 : DateTime.now().hour();
            testData.settings.Enable_Retention_Period__c = true;
            AccountingSettingsHelper.saveWithAJRRetentionJobTime(testData.settings, String.valueOf(fireNext));
            Test.stopTest();

            cronTab = [
                SELECT NextFireTime
                FROM CronTrigger
                WHERE CronJobDetail.Name = 'AJR Retention Job'
            ];
            System.assertEquals(1, cronTab.size());
            System.assertEquals(fireNext, cronTab[0].NextFireTime.hour());
        }
    }

    @IsTest
    private static void testGetConfigs() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost()
            .setERPEnabled()
            .setAvaVATReportingEnabled()
            .setNPSPEnabled();

        System.runAs(testData.users[1]) {
            String nextFireHour = String.valueOf(DateTime.now().hour());
            AutomatedJobResultsRetentionScheduler.startAutomatedJobResultsRetentionScheduler('0 0 ' + nextFireHour + ' * * ?', 'AJR Retention Job');

            Test.startTest();

            Map<String,Object> configs = AccountingSettingsHelper.getConfigs();
            System.assertNotEquals(null, configs);
            
            Accounting_Settings__c settings = (Accounting_Settings__c) configs.get('settings');
            System.assertEquals(testData.settings.Id, settings.Id);
            
            Map<String,Boolean> enablements = (Map<String,Boolean>) configs.get('enablements');
            System.assertEquals(true, enablements.get('headerLevelPostEnabled'));
            System.assertEquals(true, enablements.get('productCostingEnabled'));
            System.assertEquals(false, enablements.get('standardCostingEnabled'));

            Map<String,Object> pkgs = (Map<String,Object>) configs.get('pkgs');
            System.assertEquals(true, (Boolean)((Map<String,Object>) pkgs.get('fs')).get('installed'));
            System.assertEquals(true, (Boolean)((Map<String,Object>) pkgs.get('erp')).get('installed'));
            System.assertEquals(true, (Boolean)((Map<String,Object>) pkgs.get('avaVAT')).get('installed'));
            System.assertEquals(true, (Boolean)((Map<String,Object>) pkgs.get('npsp')).get('installed'));

            Map<String,Object> jobs = (Map<String,Object>) configs.get('jobs');
            Map<String,Object> ajrRetentionJob = (Map<String,Object>) jobs.get('ajrRetentionJob');
            System.assertEquals(nextFireHour, ajrRetentionJob.get('nextFire'));

            Test.stopTest();
        }
    }

    @IsTest
    private static void testGetTransactionalLedgers() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Ledger__c> ledgers = AccountingSettingsHelper.getTransactionalLedgers();
            System.assertEquals([SELECT count() FROM Ledger__c WHERE Type__c = :LedgerActions.LEDGER_TYPE_TRANSACTIONAL], ledgers.size());
            for (Ledger__c ledger : ledgers) {
                System.assertEquals(LedgerActions.LEDGER_TYPE_TRANSACTIONAL, ledger.Type__c);
            }
            Test.stopTest();
        }
    }

    @IsTest
    private static void testSaveDefaultLedgerError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users[1]) {
            Test.startTest();
            Accounting_Settings__c settings = AccountingSettingsHelper.getSettings();
            settings.Ledger_Limit__c = 3;
            AccountingSettingsActions.isPreventUpdateOverride = true;
            update settings;
            AccountingSettingsActions.isPreventUpdateOverride = false;
            LedgerHandler.reset();
            Ledger__c ledger = new Ledger__c();
            ledger.Type__c = 'Transactional';
            ledger.Default_Bank_Account__c = testData.glAccounts[0].Id;
            ledger.Default_Billing_Format__c = testData.billingFormats[0].Id;
            ledger.Billing_Outstanding_Statement_Format__c = testData.billingFormats[2].Id;
            ledger.Billing_Activity_Statement_Format__c = testData.billingFormats[3].Id;
            insert ledger;

            Exception expectedEx;
            try {
            settings.Default_Ledger__c = ledger.Id;
            AccountingSettingsHelper.save(settings);
            }
            catch (AccountingSettingsHelper.AccountingSettingsHelperException e) {
                expectedEx = e;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            System.assertEquals(Label.ERR_DEFAULT_LEDGER, expectedEx.getMessage());
        }
    }

    @IsTest
    private static void testSaveInventoryVarianceGLAccountError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setInventoryValuationStandardCost()
            .setERPEnabled();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Accounting_Settings__c settings = AccountingSettingsHelper.getSettings();
            Exception expectedEx;
            try {
                settings.Inventory_Variance_GL_Account__c = null;
                AccountingSettingsHelper.save(settings);
            }
            catch (AccountingSettingsHelper.AccountingSettingsHelperException e) {
                expectedEx = e;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            System.assertEquals(Label.ERR_INVENTORY_VARIANCE_GL_ACCOUNT, expectedEx.getMessage());
        }
    }

    @IsTest
    private static void testSaveInventoryVarianceGLAccountNoError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setInventoryValuationStandardCost()
            .disableProductCosting()
            .setERPEnabled();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Accounting_Settings__c settings = AccountingSettingsHelper.getSettings();
            settings.Inventory_Variance_GL_Account__c = null;
            AccountingSettingsHelper.save(settings);
            Test.stopTest();

            System.assertEquals(null, [SELECT Inventory_Variance_GL_Account__c FROM Accounting_Settings__c WHERE Id = :settings.Id].Inventory_Variance_GL_Account__c);
        }
    }

    @IsTest
    private static void testSaveVouchersPayableGLAccountError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setInventoryValuationStandardCost()
            .setERPEnabled();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Accounting_Settings__c settings = AccountingSettingsHelper.getSettings();
            Exception expectedEx;
            try {
                settings.Vouchers_Payable_GL_Account__c = null;
                AccountingSettingsHelper.save(settings);
            }
            catch (AccountingSettingsHelper.AccountingSettingsHelperException e) {
                expectedEx = e;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            System.assertEquals(Label.ERR_VOUCHERS_PAYABLE_GL_ACCOUNT, expectedEx.getMessage());
        }
    }

    @IsTest
    private static void testSaveVouchersPayableGLAccountNoError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setInventoryValuationStandardCost()
            .disableProductCosting()
            .setERPEnabled();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Accounting_Settings__c settings = AccountingSettingsHelper.getSettings();
            settings.Vouchers_Payable_GL_Account__c = null;
            AccountingSettingsHelper.save(settings);
            Test.stopTest();
            
            System.assertEquals(null, [SELECT Vouchers_Payable_GL_Account__c FROM Accounting_Settings__c WHERE Id = :settings.Id].Vouchers_Payable_GL_Account__c);
        }
    }

    @IsTest
    private static void testGetLedgers() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Map<String, Object>> ledgers = AccountingSettingsHelper.getLedgers();
            Test.stopTest();

            System.assertEquals(4, ledgers.size());
        }
    }

    @IsTest
    private static void testSaveAvaVATAccountIdError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setAvaVATReportingEnabled();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Accounting_Settings__c settings = AccountingSettingsHelper.getSettings();
            Exception expectedEx;
            try {
                AccountingSettingsHelper.overrideAvaVATReportingEnabled = true;
                AccountingSettingsHelper.save(settings);
            }
            catch (AccountingSettingsHelper.AccountingSettingsHelperException e) {
                expectedEx = e;
            }

            System.assertNotEquals(null, expectedEx);
            System.assert(expectedEx.getMessage().contains(Label.ERR_AVAVAT_ACCOUNT_ID_REQUIRED));
            Test.stopTest();
        }
    }

    @IsTest
    private static void testSaveAvaVATLicenseKeyError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setAvaVATReportingEnabled();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Accounting_Settings__c settings = AccountingSettingsHelper.getSettings();
            Exception expectedEx;
            try {
                AccountingSettingsHelper.overrideAvaVATReportingEnabled = true;
                AccountingSettingsHelper.save(settings);
            }
            catch (AccountingSettingsHelper.AccountingSettingsHelperException e) {
                expectedEx = e;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            System.assert(expectedEx.getMessage().contains(Label.ERR_AVAVAT_LICENSE_KEY_REQUIRED));
        }
    }

    @IsTest
    private static void testSaveAvaVATEnabledChangeToLLPError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setInventoryValuationStandardCost()
            .setAvaVATReportingEnabled();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Accounting_Settings__c settings = AccountingSettingsHelper.getSettings();
            Exception expectedEx;
            try {
                AccountingSettingsHelper.overrideAvaVATReportingEnabled = true;
                settings.Post_Settings__c = HeaderLevelTaxHelper.LINE_LEVEL_POST;
                AccountingSettingsHelper.save(settings);
            }
            catch (AccountingSettingsHelper.AccountingSettingsHelperException e) {
                expectedEx = e;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            System.assert(expectedEx.getMessage().contains(Label.ERR_AVAVAT_HLP_REQUIRED));
        }
    }

    @IsTest
    private static void testSaveAvaVATEnabledWithLLPError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setInventoryValuationStandardCost();

        System.runAs(testData.users[1]) {
            Accounting_Settings__c settings = AccountingSettingsHelper.getSettings();
            AccountingSettingsHelper.overrideAvaVATReportingEnabled = false;
            settings.Post_Settings__c = HeaderLevelTaxHelper.LINE_LEVEL_POST;
            AccountingSettingsHelper.save(settings);
            System.assertEquals(
                HeaderLevelTaxHelper.LINE_LEVEL_POST, 
                [SELECT Post_Settings__c FROM Accounting_Settings__c WHERE Id = :settings.Id].Post_Settings__c
            );
            
            Test.startTest();
            Exception expectedEx;
            try {
                AccountingSettingsHelper.overrideAvaVATReportingEnabled = true;
                AccountingSettingsHelper.save(settings);    
            }
            catch (AccountingSettingsHelper.AccountingSettingsHelperException e) {
                expectedEx = e;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            System.assert(expectedEx.getMessage().contains(Label.ERR_AVAVAT_HLP_REQUIRED));
        }
    }

    @IsTest
    private static void testSaveEnableCashFlowStatement() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashFlowCategories(false);

        System.runAs(testData.users[1]) {
            Test.startTest();
            Accounting_Settings__c settings = AccountingSettingsHelper.getSettings();
            System.assertEquals(false, settings.Enable_Cash_Flow_Statement__c);
            System.assertEquals(null, settings.Default_Cash_Receipt_Category__c);
            System.assertEquals(null, settings.Default_Cash_Disbursement_Category__c);
            System.assertEquals(null, settings.Default_Journal_Entry_Line_Category__c);

            settings.Enable_Cash_Flow_Statement__c = true;
            AccountingSettingsHelper.save(settings);  
            Test.stopTest();

            settings = AccountingSettingsHelper.getSettings();
            System.assertEquals(true, settings.Enable_Cash_Flow_Statement__c);
            System.assertNotEquals(null, settings.Default_Cash_Receipt_Category__c);
            System.assertNotEquals(null, settings.Default_Cash_Disbursement_Category__c);
            System.assertNotEquals(null, settings.Default_Journal_Entry_Line_Category__c);
        }
    }

    @IsTest
    private static void testSaveEnableAvalaraTaxCalculation() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createProducts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Accounting_Settings__c settings = AccountingSettingsHelper.getSettings();
            
            Exception expectedEx;
            try {
                settings.Enable_Avalara_Tax_Calculation__c = true;
                settings.Tax_Calculation_Mode__c = null;//like for a legacy record
                AccountingSettingsHelper.save(settings);
            }
            catch (AccountingSettingsHelper.AccountingSettingsHelperException e) {
                expectedEx = e;
            }
            System.assertNotEquals(null, expectedEx);
            System.assert(expectedEx.getMessage().contains(Label.ERR_AVATAX_ACCOUNT_ID_REQUIRED));

            expectedEx = null;
            try {
                settings.Avalara_Account_Id__c = 'avatax-acc-id';
                AccountingSettingsHelper.save(settings);
            }
            catch (AccountingSettingsHelper.AccountingSettingsHelperException e) {
                expectedEx = e;
            }
            System.assertNotEquals(null, expectedEx);
            System.assert(expectedEx.getMessage().contains(Label.ERR_AVATAX_LICENSE_KEY_REQUIRED));

            expectedEx = null;
            try {
                settings.Avalara_License_Key__c = 'avatax-license-key';
                AccountingSettingsHelper.save(settings);
            }
            catch (AccountingSettingsHelper.AccountingSettingsHelperException e) {
                expectedEx = e;
            }
            System.assertNotEquals(null, expectedEx);
            System.assert(expectedEx.getMessage().contains(Label.ERR_AVATAX_COMPANY_CODE_REQUIRED));
            
            expectedEx = null;
            try {
                settings.Company_Code__c = 'COMPANY-CODE';
                AccountingSettingsHelper.save(settings);
            }
            catch (AccountingSettingsHelper.AccountingSettingsHelperException e) {
                expectedEx = e;
            }
            System.assertNotEquals(null, expectedEx);
            System.assert(expectedEx.getMessage().contains(Label.ERR_TAX_CALCULATION_MODE_REQUIRED));

            expectedEx = null;
            try {
                settings.Tax_Calculation_Mode__c = 'Shipment';
                AccountingSettingsHelper.save(settings);
            }
            catch (AccountingSettingsHelper.AccountingSettingsHelperException e) {
                expectedEx = e;
            }
            System.assertNotEquals(null, expectedEx);
            System.assert(expectedEx.getMessage().contains(Label.ERR_AVALARA_GL_ACCOUNT_REQUIRED));

            expectedEx = null;
            try {
                settings.Avalara_Sales_Tax_GL_Account__c = testData.glAccounts[0].Id;
                AccountingSettingsHelper.save(settings);
            }
            catch (AccountingSettingsHelper.AccountingSettingsHelperException e) {
                expectedEx = e;
            }
            System.assertNotEquals(null, expectedEx);
            System.assert(expectedEx.getMessage().contains(Label.ERR_AVALARA_TAX_PRODUCT_REQUIRED));

            expectedEx = null;
            try {
                settings.Avalara_Tax_Product__c = testData.products[0].Id;
                AccountingSettingsHelper.save(settings);
            }
            catch (AccountingSettingsHelper.AccountingSettingsHelperException e) {
                expectedEx = e;
            }
            System.assertNotEquals(null, expectedEx);
            System.assert(expectedEx.getMessage().contains(Label.ERR_AVATAX_ADDRESS_REQUIRED));

            expectedEx = null;
            try {
                settings.Street__c = 'Some street';
                settings.City__c = 'Some city';
                settings.Region__c = 'Some state';
                settings.Postal_Code__c = 'Some postal code';
                settings.Country_Code__c = 'FR';//non-US, so an error expected
                AccountingSettingsHelper.save(settings);
            }
            catch (AccountingSettingsHelper.AccountingSettingsHelperException e) {
                expectedEx = e;
            }
            System.assertNotEquals(null, expectedEx);
            System.assert(expectedEx.getMessage().contains(Label.ERR_AVATAX_COUNTRY_CODE_RESTRICTED));
        }
    }
    
    @IsTest
    private static void testSaveLedgers() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.glAccounts[16].Bank__c = true;
            update testData.glAccounts[16];

            testData.ledgers[0].Default_Bank_Account__c = testData.glAccounts[16].Id;

            List<Ledger__c> ledgers = new List<Ledger__c> {
                testData.ledgers[0],
                testData.ledgers[2]
            };

            AccountingSettingsHelper.saveLedgers(ledgers);

            System.assertEquals(
                testData.glAccounts[16].Id,
                [SELECT Default_Bank_Account__c FROM Ledger__c WHERE Id = :ledgers[0].Id].Default_Bank_Account__c
            );
            System.assertEquals(
                testData.ledgers[2].Default_Bank_Account__c,
                [SELECT Default_Bank_Account__c FROM Ledger__c WHERE Id = :ledgers[1].Id].Default_Bank_Account__c
            );
            Test.stopTest();
        }
    }

    @IsTest
    private static void testSaveLedgersError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.ledgers[0].Default_Bank_Account__c = testData.glAccounts[16].Id;

            List<Ledger__c> ledgers = new List<Ledger__c> {
                testData.ledgers[0],
                testData.ledgers[2]
            };

            Exception expectedEx;
            try {
                AccountingSettingsHelper.saveLedgers(ledgers);
            }
            catch (AccountingSettingsHelper.AccountingSettingsHelperException e) {
                expectedEx = e;
            }

            System.assertNotEquals(null, expectedEx);
            System.assertEquals(
                testData.glAccounts[0].Id,
                [SELECT Default_Bank_Account__c FROM Ledger__c WHERE Id = :ledgers[0].Id].Default_Bank_Account__c
            );
            System.assertEquals(
                testData.glAccounts[0].Id,
                [SELECT Default_Bank_Account__c FROM Ledger__c WHERE Id = :ledgers[1].Id].Default_Bank_Account__c
            );
            Test.stopTest();
        }
    }

    @IsTest
    private static void testSaveAutomatedJobResultsRetentionDaysError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();

            Accounting_Settings__c settings = AccountingSettingsHelper.getSettings();
            settings.Automated_Job_Results_Retention_Days__c = 24;
            AccountingSettingsHelper.save(settings);
            
            System.assertEquals(24, [SELECT Automated_Job_Results_Retention_Days__c FROM Accounting_Settings__c WHERE Id = :settings.Id].Automated_Job_Results_Retention_Days__c);

            Exception expectedEx;
            String expectedMsg = String.format(Label.ERR_RANGE, new String[]{'1','365'});
            try {
                settings.Automated_Job_Results_Retention_Days__c = 0;
                AccountingSettingsHelper.save(settings);
            }
            catch (AccountingSettingsHelper.AccountingSettingsHelperException e) {
                expectedEx = e;
            }

            System.assertNotEquals(null, expectedEx);
            System.assertEquals(expectedMsg, ExpectedEx.getMessage());

            expectedEx = null;
            try {
                settings.Automated_Job_Results_Retention_Days__c = 370;
                AccountingSettingsHelper.save(settings);
            }
            catch (AccountingSettingsHelper.AccountingSettingsHelperException e) {
                expectedEx = e;
            }

            System.assertNotEquals(null, expectedEx);
            System.assertEquals(expectedMsg, ExpectedEx.getMessage());
            Test.stopTest();
        }
    }

    @IsTest
    private static void testSaveNoRecordSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Accounting_Settings__c settings = AccountingSettingsHelper.getSettings();
            Accounting_Settings__c clone = settings.clone(false, true, false, false);
            delete settings;
            System.assertEquals(0, [SELECT count() FROM Accounting_Settings__c]);
            Test.startTest();
            AccountingSettingsHelper.save(clone);
            Test.stopTest();
            System.assertEquals(1, [SELECT count() FROM Accounting_Settings__c]);
        }
    }

    @IsTest
    private static void testGetPaymentLinkAuthrizationURL() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            String uri = AccountingSettingsHelper.getPaymentLinkAuthrizationURL();
            String expectedURI = 
                GlobalVariables.paymentLinkSettings.Value_1__c 
                + '/auth/authorize?ref=' 
                + EncodingUtil.urlEncode(URL.getOrgDomainUrl().toExternalForm(), 'UTF-8');
            System.assertEquals(expectedURI, uri);
            Test.stopTest();
        }
    }

    @IsTest
    private static void testUserHasPaymentLinkAccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Boolean accessible = AccountingSettingsHelper.userHasPaymentLinkAccess();
            System.assert(accessible);
            Test.stopTest();
        }
    }

    private static void testUserHasPaymentLinkAccessDenied() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[2]) {
            Test.startTest();
            Boolean accessible = AccountingSettingsHelper.userHasPaymentLinkAccess();
            System.assert(!accessible);
            Test.stopTest();
        }
    }

    @IsTest
    private static void testGetAvaVATEndpointOptions() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<AbstractLWCHelper.CustomSelectOption> opts = AccountingSettingsHelper.getAvaVATEndpointOptions();
            System.assertEquals(2, opts.size());
            System.assertEquals('false', opts[0].value);
            System.assertEquals('true', opts[1].value);
        }
    }

    @IsTest
    private static void testGetAvaTaxEndpointOptions() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<AbstractLWCHelper.CustomSelectOption> opts = AccountingSettingsHelper.getAvaTaxEndpointOptions();
            System.assertEquals(2, opts.size());
            System.assertEquals('false', opts[0].value);
            System.assertEquals('true', opts[1].value);
            Test.stopTest();
        }
    }

    @IsTest
    private static void testGetTaxCalculationOptions() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<AbstractLWCHelper.CustomSelectOption> opts = AccountingSettingsHelper.getTaxCalculationOptions();
            System.assertEquals(2, opts.size());
            System.assertEquals(Label.TAX_OPTION_NATIVE, opts[0].value);
            System.assertEquals(Label.TAX_OPTION_AVATAX, opts[1].value);
            Test.stopTest();
        }
    }

    @IsTest
    private static void testGetTaxCalculationOptionsWithAvaVat() {
        TestDataSuite testData = TestDataSuite.getInstance().setAvaVATReportingEnabled();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<AbstractLWCHelper.CustomSelectOption> opts = AccountingSettingsHelper.getTaxCalculationOptions();
            System.assertEquals(3, opts.size());
            System.assertEquals(Label.TAX_OPTION_NATIVE, opts[0].value);
            System.assertEquals(Label.TAX_OPTION_AVATAX, opts[1].value);
            System.assertEquals(Label.TAX_OPTION_AVAVAT, opts[2].value);
            Test.stopTest();
        }
    }

    @IsTest
    private static void testPingAvaTax() {
        TestDataSuite testData = TestDataSuite.getInstance().enableAvaTaxCalculation();

        System.runAs(testData.users[1]) {
            Test.startTest();
            AvaTaxService.PingResultModel pingResponse = new AvaTaxService.PingResultModel();
            pingResponse.version = '1.0.0.0';
            pingResponse.authenticated = true;
            pingResponse.authenticationType = 'AccountIdLicenseKey';
            pingResponse.authenticatedUserName = 'TestUser';
            pingResponse.authenticatedUserId = '98765';
            pingResponse.authenticatedAccountId = '123456789';
            pingResponse.crmid = '1111';

            Test.setMock(HttpCalloutMock.class, new SingleRequestMock(
                200,
                'Complete',
                JSON.serialize(pingResponse),
                new Map<String, String>{'Content-Type' => 'application/json'}
            ));

            Map<String,Object> pong = AccountingSettingsHelper.pingAvaTax([SELECT Id FROM AvaTax_License__c LIMIT 1][0].Id);

            System.assertEquals(pingResponse.authenticated, (Boolean) pong.get('authenticated'));
            System.assertEquals(pingResponse.authenticationType, (String) pong.get('authenticationType'));
            System.assertEquals(pingResponse.authenticatedAccountId, (String) pong.get('authenticatedAccountId'));
            System.assertEquals(pingResponse.version, (String) pong.get('version'));
            Test.stopTest();
        }
    }

    @IsTest
    private static void testPingAvaTaxAuthFailure() {
        TestDataSuite testData = TestDataSuite.getInstance().enableAvaTaxCalculation();

        System.runAs(testData.users[1]) {
            Test.startTest();
            AvaTaxService.PingResultModel pingResponse = new AvaTaxService.PingResultModel();
            pingResponse.version = '1.0.0.0';
            pingResponse.authenticated = false;
            pingResponse.authenticationType = 'AccountIdLicenseKey';
            pingResponse.authenticatedUserName = 'TestUser';
            pingResponse.authenticatedUserId = '98765';
            pingResponse.authenticatedAccountId = '123456789';
            pingResponse.crmid = '1111';

            Test.setMock(HttpCalloutMock.class, new SingleRequestMock(
                200,
                'Complete',
                JSON.serialize(pingResponse),
                new Map<String, String>{'Content-Type' => 'application/json'}
            ));

            Map<String,Object> pong = AccountingSettingsHelper.pingAvaTax([SELECT Id FROM AvaTax_License__c LIMIT 1][0].Id);

            System.assertEquals(pingResponse.authenticated, (Boolean) pong.get('authenticated'));
            System.assertEquals(pingResponse.authenticationType, (String) pong.get('authenticationType'));
            System.assertEquals(pingResponse.authenticatedAccountId, (String) pong.get('authenticatedAccountId'));
            System.assertEquals(pingResponse.version, (String) pong.get('version'));
            Test.stopTest();
        }
    }

    @IsTest
    private static void testPingAvaTaxError() {
        TestDataSuite testData = TestDataSuite.getInstance().enableAvaTaxCalculation();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new SingleRequestMock(
                500 ,
                'Internal Server Error',
                '',
                new Map<String, String>{'Content-Type' => 'application/json'}
            ));

            Exception expectedEx;
            try {
                AccountingSettingsHelper.pingAvaTax([SELECT Id FROM AvaTax_License__c LIMIT 1][0].Id);
            }
            catch (AccountingSettingsHelper.AccountingSettingsHelperException e) {
                expectedEx = e;
            }

            System.assertNotEquals(null, expectedEx);
        }
    }

    @IsTest
    private static void saveWithChangedCashFlowDefaults() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashFlowCategories(true);

        System.runAs(testData.users[1]) {
            testData.settings.Default_Cash_Receipt_Category__c = testData.cashFlowCategories[3].Id;
            testData.settings.Default_Cash_Disbursement_Category__c = testData.cashFlowCategories[4].Id;
            testData.settings.Default_Journal_Entry_Line_Category__c = testData.cashFlowCategories[5].Id;
            AccountingSettingsHelper.save(testData.settings);

            List<GL_Account_Default__c> cfSpecs =  DomainUtils.gLAccountDefaultsBySpecification(GLAccountDefaultsHandler.instance.cashFlowSpecifications);
            for (GL_Account_Default__c cashFlowSpec : cfSpecs) {
                if (cashFlowSpec.GL_Account_Specification__c == 'Default_Cash_Receipt_Category') {
                    System.assertEquals(testData.cashFlowCategories[3].Id, cashFlowSpec.GL_Account__c);
                }
                if (cashFlowSpec.GL_Account_Specification__c == 'Default_Cash_Disbursement_Category') {
                    System.assertEquals(testData.cashFlowCategories[4].Id, cashFlowSpec.GL_Account__c);
                }
                if (cashFlowSpec.GL_Account_Specification__c == 'Default_Journal_Entry_Line_Category') {
                    System.assertEquals(testData.cashFlowCategories[5].Id, cashFlowSpec.GL_Account__c);
                }
            }
        }
    }
}