@IsTest
public class PostInstallActionsTest {

    @IsTest
    public static void testNewInstallScript() {
        PostInstallActions postInstall = new PostInstallActions();
        Test.testInstall(postInstall, NULL);
        
        System.assertEquals(30, postInstall.glAccounts.size());
        System.assertEquals(3, postInstall.glAccountsExpense.size());
        System.assertEquals(2, postInstall.ledgers.size()); 
        System.assertEquals(
            Ledger_Custom_Settings__c.getOrgDefaults().Ledger_Id__c,
            [SELECT Id, Type__c FROM Ledger__c WHERE Type__c = 'Transactional'].Id
        );
        System.assertNotEquals(NULL, postInstall.billingFormats[0].Id);
        System.assertEquals(PostInstallActions.CURRENCY_FORMAT, postInstall.billingFormats[0].Currency_Format__c);
        System.assertEquals(PostInstallActions.NUMERIC_FORMAT, postInstall.billingFormats[0].Numeric_Format__c);
        System.assertEquals(1, postInstall.settings.size());
        System.assertEquals(HeaderLevelTaxHelper.HEADER_LEVEL_POST, AccountingSettingsHandler.getAccountingSettings().Post_Settings__c);
        System.assertEquals(15, postInstall.acctPeriods.size());
        System.assertEquals(4, [SELECT count() FROM Accounting_Period__c WHERE Start_Date__c <= :System.today()]);
        
        System.assertEquals(3, postInstall.timeCardPeriods.size());
        System.assertEquals(3, [SELECT count() FROM Time_Card_Accounting_Period__c WHERE Accounting_Period__c = :postInstall.acctPeriods[1].Id]);

        System.assertEquals(false, [SELECT Is_Active__c FROM BDC_Binding__c WHERE name = 'Yodlee'].Is_Active__c);
        System.assertEquals(true,[SELECT Id,Enable_Billing_Period_Sensitive_Aging__c 
                            FROM Accounting_Settings__c LIMIT 1].Enable_Billing_Period_Sensitive_Aging__c);
        System.assertEquals(true,[SELECT Id,Enable_AP_Period_Sensitive_Aging__c 
                            FROM Accounting_Settings__c LIMIT 1].Enable_AP_Period_Sensitive_Aging__c);
        System.assertEquals(1,[SELECT Id,Tax_Settings_Method__c FROM Tax_Settings__c 
                            WHERE Tax_Settings_Method__c =:TaxSettingsActions.NATIVE_TAX_METHOD].size());
        System.assertEquals(0,[SELECT count() FROM Payment_Method__c]);
        System.assertEquals(0,[SELECT count() FROM Payment_Processor__c]);
        System.assertEquals(0,[SELECT count() FROM Payment_Processor_Customer__c]);
    }

    @IsTest
    public static void testVersionUpgrade342() {
        TestDataSuite testDataSuite = TestDataSuite.getInstance(true);

        Test.startTest();

        // validate new default value
        System.assertEquals('Average Cost', AccountingSettingsHandler.getAccountingSettings().Inventory_Valuation_Method__c);
        AccountingSettingsHandler.acctSeedSettings = NULL;

        PostInstallActions postInstall = new PostInstallActions();
        Test.testInstall(postInstall, new Version(3, 45));

        System.assertEquals('Standard Cost', AccountingSettingsHandler.getAccountingSettings().Inventory_Valuation_Method__c);
    }

    @IsTest
    public static void testNewInstallAccountingSettingsGLAccounts() {
        PostInstallActions postInstall = new PostInstallActions();
        Test.testInstall(postInstall, NULL);
        System.assertEquals(
            [SELECT Id, Name FROM GL_Account__c WHERE Name = '2030-Accrued Payroll'].Id,
            [SELECT Labor_GL_Account__c FROM Accounting_Settings__c LIMIT 1].Labor_GL_Account__c
        );
        System.assertEquals(
            [SELECT Id, Name FROM GL_Account__c WHERE Name = '5040-Vendor Payment Discounts'].Id,
            [SELECT Payment_Discount_GL_Account__c FROM Accounting_Settings__c LIMIT 1].Payment_Discount_GL_Account__c
        );
        System.assertEquals(
            [SELECT Id, Name FROM GL_Account__c WHERE Name = '5050-Labor'].Id,
            [SELECT Default_Project_Task_Labor_GL_Account__c FROM Accounting_Settings__c LIMIT 1].Default_Project_Task_Labor_GL_Account__c
        );
        System.assertEquals(
            [SELECT Id, Name FROM GL_Account__c WHERE Name = '1600-Work In Process'].Id,
            [SELECT Work_in_Process_GL_Account__c FROM Accounting_Settings__c LIMIT 1].Work_in_Process_GL_Account__c
        );
        System.assertEquals(
            [SELECT Id, Name FROM GL_Account__c WHERE Name = '2010-Vouchers Payable'].Id,
            [SELECT Vouchers_Payable_GL_Account__c FROM Accounting_Settings__c LIMIT 1].Vouchers_Payable_GL_Account__c
        );
        System.assertEquals(
            [SELECT Id, Name FROM GL_Account__c WHERE Name = '4900-Customer Payment Discounts'].Id,
            [SELECT Customer_Payment_Adjustment_GL_Account__c FROM Accounting_Settings__c LIMIT 1].Customer_Payment_Adjustment_GL_Account__c
        );
        System.assertEquals(
            [SELECT Id, Name FROM GL_Account__c WHERE Name = '1400-Prepaid Expenses'].Id,
            [SELECT Prepaid_Expense_GL_Account__c FROM Accounting_Settings__c LIMIT 1].Prepaid_Expense_GL_Account__c
        );
        System.assertEquals(
            [SELECT Id, Name FROM GL_Account__c WHERE Name = '1450-Deferred Expenses'].Id,
            [SELECT Default_Credit_GL_Account_Expense__c FROM Accounting_Settings__c LIMIT 1].Default_Credit_GL_Account_Expense__c
        );
        System.assertEquals(
            [SELECT Id, Name FROM GL_Account__c WHERE Name = '2500-Deferred Revenue'].Id,
            [SELECT Default_Debit_GL_Account_Revenue__c FROM Accounting_Settings__c LIMIT 1].Default_Debit_GL_Account_Revenue__c
        );
        System.assertEquals(
            [SELECT Id, Name FROM GL_Account__c WHERE Name = '4000-Product Revenue'].Id,
            [SELECT Default_Credit_GL_Account_Revenue__c FROM Accounting_Settings__c LIMIT 1].Default_Credit_GL_Account_Revenue__c
        );
    }

    @IsTest
    public static void testVersionUpgrade336() {
        TestDataSuite testDataSuite = TestDataSuite.getInstance(true);

        Test.startTest();
        testDataSuite.glAccounts[16].Bank__c = true;
        update testDataSuite.glAccounts[16];
        AccountingSettingsHandler.acctSeedSettings = NULL;
        testDataSuite.settings.Default_Bank_Account__c = testDataSuite.glAccounts[16].Id;
        testDataSuite.settings.Billing_Activity_Statement_Format__c = testDataSuite.billingFormats[3].Id;
        testDataSuite.settings.Billing_Outstanding_Statement_Format__c = testDataSuite.billingFormats[2].Id;
        testDataSuite.settings.Default_Billing_Format__c = testDataSuite.billingFormats[1].Id;
        update testDataSuite.settings;

        PostInstallActions postInstall = new PostInstallActions();
        Test.testInstall(postInstall, new Version(3, 35));

        System.assertEquals(testDataSuite.ledgers[0].Id, Ledger_Custom_Settings__c.getOrgDefaults().Ledger_Id__c);
        System.assertEquals(
            testDataSuite.glAccounts[16].Id,
            AccountingSettingsHandler.getAccountingSettings().Default_Bank_Account__c
        );
        System.assertEquals(
            testDataSuite.billingFormats[3].Id,
            AccountingSettingsHandler.getAccountingSettings().Billing_Activity_Statement_Format__c
        );
        System.assertEquals(
            testDataSuite.billingFormats[2].Id,
            AccountingSettingsHandler.getAccountingSettings().Billing_Outstanding_Statement_Format__c
        );
        System.assertEquals(
            testDataSuite.billingFormats[1].Id,
            AccountingSettingsHandler.getAccountingSettings().Default_Billing_Format__c
        );
    }

    @IsTest
    public static void testVersionUpgrade38() {
        TestDataSuite testDataSuite = TestDataSuite.getInstance(true);

        testDataSuite.settings.Default_Bank_Account__c = testDataSuite.glAccounts[0].Id;
        testDataSuite.settings.Default_Billing_Format__c = testDataSuite.billingFormats[0].Id;
        testDataSuite.settings.Billing_Activity_Statement_Format__c = [SELECT Id FROM Billing_Format__c WHERE Type__c = 'Activity Statement' LIMIT 1].Id;
        testDataSuite.settings.Billing_Outstanding_Statement_Format__c = [SELECT Id FROM Billing_Format__c WHERE Type__c = 'Outstanding Statement' LIMIT 1].Id;
        update testDataSuite.settings;

        Test.startTest();
        PostInstallActions postInstall = new PostInstallActions();
        Test.testInstall(postInstall, new Version(3, 9));

        System.assertNotEquals(NULL, testDataSuite.settings);
    }

    @IsTest
    public static void testVersionUpgrade220() {
        TestDataSuite testDataSuite = TestDataSuite.getInstance(true);

        testDataSuite.settings.Default_Bank_Account__c = testDataSuite.glAccounts[0].Id;
        testDataSuite.settings.Default_Billing_Format__c = testDataSuite.billingFormats[0].Id;
        testDataSuite.settings.Billing_Activity_Statement_Format__c = [SELECT Id FROM Billing_Format__c WHERE Type__c = 'Activity Statement' LIMIT 1].Id;
        testDataSuite.settings.Billing_Outstanding_Statement_Format__c = [SELECT Id FROM Billing_Format__c WHERE Type__c = 'Outstanding Statement' LIMIT 1].Id;
        update testDataSuite.settings;

        Billing_Format__c bf = testDataSuite.billingFormats[0].clone(false, true);
        bf.Type__c = 'Test';
        insert bf;

        System.assertEquals('Test', [SELECT Type__c FROM Billing_Format__c WHERE Id = :bf.Id].Type__c);
        Test.startTest();
        PostInstallActions postInstall = new PostInstallActions();
        Test.testInstall(postInstall, new Version(2, 19));
        Test.stopTest();

        System.assertEquals(
            PostInstallActions.BILLING_EMAIL_TEMPLATE,
            [SELECT Default_Email_Template__c FROM Billing_Format__c WHERE Id = :bf.Id].Default_Email_Template__c
        );
        System.assertEquals('Billing', [SELECT Type__c FROM Billing_Format__c WHERE Id = :bf.Id].Type__c);

        List<Billing_Format__c> billFormats = [SELECT Id, Currency_Format__c, Numeric_Format__c FROM Billing_Format__c LIMIT 1];
        System.assertEquals(PostInstallActions.CURRENCY_FORMAT, billFormats[0].Currency_Format__c);
        System.assertEquals(PostInstallActions.NUMERIC_FORMAT, billFormats[0].Numeric_Format__c);
    }

    @IsTest    
    public static void testVersionUpgrade221() {
        PostInstallActions postInstall = new PostInstallActions();
        Test.testInstall(postInstall, NULL);
        System.assertEquals(1, [SELECT count() FROM Billing_Format__c WHERE Type__c = 'Outstanding Statement']);
        System.assertEquals(1, [SELECT count() FROM Billing_Format__c WHERE Type__c = 'Activity Statement']);

        Billing_Format__c bFormat = [SELECT Id FROM Billing_Format__c WHERE Type__c = 'Billing' LIMIT 1];
        Accounting_Settings__c settings = [SELECT Id FROM Accounting_Settings__c LIMIT 1];
        settings.Billing_Activity_Statement_Format__c = bFormat.Id;
        settings.Billing_Outstanding_Statement_Format__c = bFormat.Id;
        settings.Default_Bank_Account__c = [SELECT Id FROM GL_Account__c WHERE Bank__c = TRUE LIMIT 1].Id;
        settings.Default_Billing_Format__c = bFormat.Id;
        update settings;

        Test.testInstall(postInstall, new Version(2, 20));
        
        System.assertEquals(2, [SELECT count() FROM Billing_Format__c WHERE Type__c = 'Outstanding Statement']);
        System.assertEquals(2, [SELECT count() FROM Billing_Format__c WHERE Type__c = 'Activity Statement']);

        System.assertEquals(PostInstallActions.CURRENCY_FORMAT, postInstall.billingFormats[0].Currency_Format__c);
        System.assertEquals(PostInstallActions.NUMERIC_FORMAT, postInstall.billingFormats[0].Numeric_Format__c);
    }
    
    @IsTest    
    public static void testVersionUpgrade316() {
        PostInstallActions postInstall = new PostInstallActions();
        Test.testInstall(postInstall, NULL);

        Billing_Format__c bFormat = [SELECT Id FROM Billing_Format__c WHERE Type__c = 'Billing' LIMIT 1];
        Accounting_Settings__c settings = [SELECT Prepaid_Expense_GL_Account__c FROM Accounting_Settings__c LIMIT 1];
        settings.Billing_Activity_Statement_Format__c = [SELECT Id FROM Billing_Format__c WHERE Type__c = 'Activity Statement' LIMIT 1].Id;
        settings.Billing_Outstanding_Statement_Format__c = [SELECT Id FROM Billing_Format__c WHERE Type__c = 'Outstanding Statement' LIMIT 1].Id;
        settings.Default_Bank_Account__c = [SELECT Id FROM GL_Account__c WHERE Bank__c = TRUE LIMIT 1].Id;
        settings.Default_Billing_Format__c = bFormat.Id;
        settings.Prepaid_Expense_GL_Account__c = NULL;
        update settings;

        System.assertEquals(
            NULL,
            [SELECT Prepaid_Expense_GL_Account__c FROM Accounting_Settings__c LIMIT 1].Prepaid_Expense_GL_Account__c
        );

        Test.testInstall(postInstall, new Version(3, 15));

        System.assertEquals(
            [SELECT Id, Name FROM GL_Account__c WHERE Name = '1400-Prepaid Expenses'].Id,
            [SELECT Prepaid_Expense_GL_Account__c FROM Accounting_Settings__c LIMIT 1].Prepaid_Expense_GL_Account__c
        );
    }

    @IsTest/*IRVING*/
    public static void testVersionUpgrade351() {
        PostInstallActions postInstall = new PostInstallActions();
        Test.testInstall(postInstall, NULL);

        System.assertEquals(HeaderLevelTaxHelper.HEADER_LEVEL_POST, [SELECT Post_Settings__c FROM Accounting_Settings__c LIMIT 1].Post_Settings__c);

        Test.testInstall(postInstall, new Version(3, 49), true);
        Test.testInstall(postInstall, new Version(3, 52), true);

        System.assertEquals(HeaderLevelTaxHelper.LINE_LEVEL_POST, [SELECT Post_Settings__c FROM Accounting_Settings__c LIMIT 1].Post_Settings__c);
    }

    @IsTest/*KERMIT*/
    public static void testRecurringPeriodTaskSampleData() {
        PostInstallActions postInstall = new PostInstallActions();
        Test.testInstall(postInstall, NULL);
        list<Period_Task__c> acctPeriodTasks = new list<Period_Task__c>([select id from Period_Task__c]);
        System.assertEquals(21, acctPeriodTasks.size());
        delete acctPeriodTasks;

        Test.testInstall(postInstall, new Version(3, 52), true);
        Test.testInstall(postInstall, new Version(3, 81));
        acctPeriodTasks = [select id from Period_Task__c];
        System.assertEquals(21, acctPeriodTasks.size());
    }

    @IsTest
    public static void testSetNewInMagHomeFieldsOnAcctSettings() {
        PostInstallActions postInstall = new PostInstallActions();
        Test.testInstall(postInstall, NULL);

        delete [SELECT Id FROM GL_Account_Default__c];

        GL_Account__c glAccount = [SELECT Id FROM GL_Account__c WHERE Name = '1450-Deferred Expenses' LIMIT 1];
        delete glAccount;

        Accounting_Settings__c settings = [SELECT Id FROM Accounting_Settings__c LIMIT 1];
        settings.Default_Credit_GL_Account_Expense__c = null;
        settings.Default_Credit_GL_Account_Revenue__c = null;
        settings.Default_Debit_GL_Account_Revenue__c = null;

        update settings;

        Test.testInstall(postInstall, new Version(3, 52), true);
        Test.startTest();
        Test.testInstall(postInstall, new Version(3, 100));
        
        GL_Account__c newGlAccount = [SELECT Id FROM GL_Account__c WHERE Name = '1450-Deferred Expenses' LIMIT 1];
        settings = [
            SELECT Id,
            Default_Credit_GL_Account_Expense__c,
            Default_Debit_GL_Account_Revenue__c,
            Default_Credit_GL_Account_Revenue__c
            FROM Accounting_Settings__c LIMIT 1
        ];

        System.assert(newGlAccount != null);
        System.assertEquals(newGlAccount.Id, settings.Default_Credit_GL_Account_Expense__c);
        System.assertEquals(
            [SELECT Id, Name FROM GL_Account__c WHERE Name = '2500-Deferred Revenue'].Id,
            settings.Default_Debit_GL_Account_Revenue__c
        );
        Test.stopTest();
    }

    @IsTest
    public static void testSetNewInMagHomeFieldsOnAcctSettingsIfNoGLAccount() {
        PostInstallActions postInstall = new PostInstallActions();
        Test.testInstall(postInstall, NULL);
        delete [SELECT Id FROM GL_Account_Default__c];

        GL_Account__c glAccount = [SELECT Id FROM GL_Account__c WHERE Name = '1450-Deferred Expenses' LIMIT 1];
        delete glAccount;
        GL_Account__c glAccount2 = [SELECT Id FROM GL_Account__c WHERE Name = '2500-Deferred Revenue' LIMIT 1];
        delete glAccount2;

        Accounting_Settings__c settings = [SELECT Id FROM Accounting_Settings__c LIMIT 1];
        settings.Default_Credit_GL_Account_Expense__c = null;
        settings.Default_Credit_GL_Account_Revenue__c = null;
        settings.Default_Debit_GL_Account_Revenue__c = null;

        update settings;

        Test.startTest();

        Test.testInstall(postInstall, new Version(3, 52), true);
        Test.testInstall(postInstall, new Version(3, 100));

        GL_Account__c newGlAccount = [SELECT Id FROM GL_Account__c WHERE Name = '1450-Deferred Expenses' LIMIT 1];
        settings = [
            SELECT Id,
                Default_Credit_GL_Account_Expense__c,
                Default_Debit_GL_Account_Revenue__c,
                Default_Credit_GL_Account_Revenue__c
            FROM Accounting_Settings__c LIMIT 1
        ];

        System.assert(newGlAccount != null);
        System.assertEquals(newGlAccount.Id, settings.Default_Credit_GL_Account_Expense__c);
        System.assertEquals(
            null,
            settings.Default_Debit_GL_Account_Revenue__c
        );
    }
    
    @IsTest
    public static void testUpdateBillingFormatsEmailDelivery() {
        PostInstallActions postInstall = new PostInstallActions();
        Test.testInstall(postInstall, NULL);
       

        List<Billing_Format__c> billingFormats = [SELECT Id, Automated_Email_Delivery__c, Automated_Email_Delivery2__c FROM Billing_Format__c];
        billingFormats[0].Automated_Email_Delivery__c = 'Balance Due';
        billingFormats[1].Automated_Email_Delivery__c = 'Zero Balance';
        billingFormats[2].Automated_Email_Delivery__c = 'No Delivery';
        update billingFormats;

        Test.testInstall(postInstall, new Version(3, 52), true);
        Test.testInstall(postInstall, new Version(3, 100));

        for(Billing_Format__c billingFormat :[SELECT Id, Automated_Email_Delivery__c, Automated_Email_Delivery2__c FROM Billing_Format__c] ){
            switch on billingFormat.Automated_Email_Delivery__c{
                when 'Balance Due' {		
                    System.assertEquals('Balance Due Only', billingFormat.Automated_Email_Delivery2__c);
                }
                when 'Zero Balance' {		
                    System.assertEquals('Zero Balance Only', billingFormat.Automated_Email_Delivery2__c);
                }
                when 'No Delivery' {		
                    System.assertEquals('No Delivery', billingFormat.Automated_Email_Delivery2__c);
                }
            }
        }
    }

    @IsTest
    public static void testUpdateLedgerTaxSetting() {
        PostInstallActions postInstall = new PostInstallActions();
        Test.testInstall(postInstall, NULL);
    
        for (Ledger__c transLedger : DomainUtils.getLedgerByType(new Set<String> {'Transactional'})) {
            System.assertNotEquals(null, transLedger.Tax_Settings__c);
        }

        Test.testInstall(postInstall, new Version(3, 52), true);
        Test.testInstall(postInstall, new Version(3, 120));

        List<Tax_Settings__c> taxSettings = [SELECT Id, Name FROM Tax_Settings__c];

        for (Ledger__c transLedger : DomainUtils.getLedgerByType(new Set<String> {'Transactional'})) {
            System.assertEquals(taxSettings[0].Id, transLedger.Tax_Settings__c);
            System.assertEquals(TaxSettingsActions.NATIVE_TAX_METHOD, taxSettings[0].Name);
        }

    }
    @IsTest
    public static void testVersionUpgrade133() {
        TestDataSuite testDataSuite = TestDataSuite.getInstance(true);

        Test.startTest();

        Accounting_Settings__c setting = [SELECT Id FROM Accounting_Settings__c ORDER BY CreatedDate DESC LIMIT 1];
        setting.Stripe_Connected_Account_Id__c = 'test_StripeId';
        update setting;
        
        List<Account> accts = [SELECT Id,Stripe_Customer_Id__c FROM Account];

        for (Account acc : accts) {
            acc.Stripe_Customer_Id__c = 'Test_' + acc.Id;
        }
        update accts;

        Payment_Processor__c pp = new Payment_Processor__c(
            Name = 'Test PP',
            Type__c = PaymentProcessorActions.STRIPE_TYPE,
            Active__c = true,
            Connected_Account_Token__c = '123456'
        );
        insert pp;

        Payment_Method__c pm = new Payment_Method__c(
            Customer__c = accts[0].Id,
            Payment_Processor__c = pp.Id,
            External_Id__c = '12345678;abcd',
            Last_Four_Digits__c = '4242',
            Payment_Method_Type__c = 'Credit Card',
            Status__c = 'Active',
            Expiration_Month__c = '12',
            Expiration_Year__c = '2224',
            Type__c = 'Visa'
        );
        insert pm;

        PostInstallActions postInstall = new PostInstallActions();
        Test.testInstall(postInstall, new Version(3,132));
        Test.stopTest();

        System.assertEquals(1,[SELECT Id FROM Payment_Processor__c WHERE Id != :pp.Id].size());
        System.assertEquals(accts.size(),[SELECT Id FROM Payment_Processor_Customer__c].size());
        System.assertEquals([SELECT Id FROM Payment_Processor__c WHERE Id != :pp.Id][0].Id,
                            [SELECT Id,Payment_Processor__c FROM Payment_Method__c][0].Payment_Processor__c);
        
        System.assertEquals([SELECT Id FROM Payment_Processor__c WHERE Id != :pp.Id][0].Id,
                            [SELECT Id,Stripe_Connected_Account_Id__c FROM Accounting_Settings__c ORDER BY CreatedDate DESC LIMIT 1][0].Stripe_Connected_Account_Id__c);
    }

    @IsTest
    public static void testBDCBindingsOnSpring23Pre1Upgrade() {
        PostInstallActions postInstall = new PostInstallActions();
        Test.testInstall(postInstall, NULL);
        BDC_Binding__c bind = [SELECT Is_Active__c FROM BDC_Binding__c WHERE name = 'Yodlee'];
        
        //assert yodlee binding is correct on new install
        System.assertEquals(false, bind.Is_Active__c);

        //remove yodlee binding
        delete bind;

        Test.testInstall(postInstall, new Version(3, 121), true);
        Test.testInstall(postInstall, new Version(3, 133));

        //assert yodlee bind is active on upgrade when binding record does not exist
        System.assertEquals(true, [SELECT Is_Active__c FROM BDC_Binding__c WHERE name = 'Yodlee'].Is_Active__c);
        System.assertEquals(false, [SELECT Is_Active__c FROM BDC_Binding__c WHERE name = 'Plaid'].Is_Active__c);
        
    }

    @IsTest
    public static void testCreateGLAccountDefaultsOnSpring23Upgrade() {
        PostInstallActions postInstall = new PostInstallActions();
        Test.testInstall(postInstall, NULL);
        List<GL_Account_Default__c> defaults = [SELECT Id FROM GL_Account_Default__c];

        //assert Defaults is correct on new install
        System.assertEquals(false, defaults.isEmpty());
        delete defaults;

        Accounting_Settings__c acctSettings = AccountingSettingsHandler.getAccountingSettings();
        GL_Account__c glAccount = DomainUtils.getGlAccountsByName(new List<String> {'4000-Product Revenue'})[0];

        GL_Account__c newGlAccount = glAccount.clone();
        newGlAccount.Name = '4006-Product Revenue';
        newGlAccount.Active__c = true;
        newGlAccount.Type__c = 'Revenue';
        newGlAccount.Sub_Type_1__c = 'Product Revenue';
        newGlAccount.Sub_Type_2__c = 'Product Family 1';
        insert newGlAccount;

        acctSettings.CTA_GL_Account__c = [SELECT Id FROM GL_Account__c WHERE Name = '1000-Cash' LIMIT 1].Id;
        acctSettings.Default_Credit_GL_Account_Revenue__c = newGlAccount.Id;
        AccountingSettingsActions.skipPreventUpdatePostSettingsValidations = true;
        AccountingSettingsActions.isPreventUpdateOverride = true;
        update acctSettings;
        AccountingSettingsActions.skipPreventUpdatePostSettingsValidations = false;
        AccountingSettingsActions.isPreventUpdateOverride = false;

        Test.startTest();
        Test.testInstall(postInstall, new Version(3, 133), true);
        Test.testInstall(postInstall, new Version(3, 147));
        Test.stopTest();

        for (GL_Account_Default__c def : [SELECT Id, GL_Account__c, GL_Account_Specification__c FROM GL_Account_Default__c]) {
            if (def.GL_Account__c == newGlAccount.Id) {
                System.assert(def.GL_Account_Specification__c == 'Revenue_GL_Account' || def.GL_Account_Specification__c == 'Default_Credit_GL_Account_Revenue');
            }
        }

        System.assertEquals(2, [SELECT Id, GL_Account__c FROM GL_Account_Default__c WHERE GL_Account__c = :newGlAccount.Id].size());
        // total defaults count for 2 ledgers
        System.assertEquals(38, [SELECT Id, GL_Account__c FROM GL_Account_Default__c].size());

    }

    @IsTest
    public static void testCreateConsolidationGLAccountDefaultsOnSummer23Pre1Upgrade() {
        PostInstallActions postInstall = new PostInstallActions();
        Test.testInstall(postInstall, NULL);
        AccountingLimitHandler.getInstance().setLimit(AccountingLimitHandler.LimitType.LEDGER_LIMIT, 10);

        Accounting_Settings__c settings = AccountingSettingsHelper.getSettings();
        settings.Ledger_Limit__c = 5;
        AccountingSettingsActions.isPreventUpdateOverride = true;
        update settings;
        AccountingSettingsActions.isPreventUpdateOverride = false;
        List<Ledger__c> consolidationLedgers = new List<Ledger__c>{
            new Ledger__c(
                Name = 'Consolidation ledger1',
                Type__c = LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL,
                Default_Bank_Account__c = DomainUtils.getGlAccountsByName(new List<String> {'1000-Cash'})[0].Id,
                Default_Billing_Format__c = [SELECT Id FROM Billing_Format__c WHERE Name = :'Default Billing Service'][0].Id,
                Billing_Outstanding_Statement_Format__c = [SELECT Id FROM Billing_Format__c WHERE Name = :'Default Billing Outstanding Statement'][0].Id,
                Billing_Activity_Statement_Format__c = [SELECT Id FROM Billing_Format__c WHERE Name = :'Default Billing Activity Statement'][0].Id
            )
        };

        insert consolidationLedgers;

        List<GL_Account_Default__c> defaults = [SELECT Id FROM GL_Account_Default__c];
        //assert Defaults is correct on new install
        System.assertEquals(false, defaults.isEmpty());
        delete defaults;

        Accounting_Settings__c acctSettings = AccountingSettingsHandler.getAccountingSettings();
        GL_Account__c glAccount = DomainUtils.getGlAccountsByName(new List<String> {'4000-Product Revenue'})[0];

        GL_Account__c newGlAccount = glAccount.clone();
        newGlAccount.Name = '3900-CTA';
        newGlAccount.Active__c = true;
        newGlAccount.Type__c = 'Balance Sheet';
        newGlAccount.Sub_Type_1__c = 'Owners Equity';
        newGlAccount.Sub_Type_2__c = 'Equity';
        insert newGlAccount;

        acctSettings.CTA_GL_Account__c = newGlAccount.Id;
        AccountingSettingsActions.skipPreventUpdatePostSettingsValidations = true;
        AccountingSettingsActions.isPreventUpdateOverride = true;
        update acctSettings;
        AccountingSettingsActions.skipPreventUpdatePostSettingsValidations = false;
        AccountingSettingsActions.isPreventUpdateOverride = false;

        Test.startTest();
        Test.testInstall(postInstall, new Version(3, 133), true);
        Test.testInstall(postInstall, new Version(3, 147));
        Test.stopTest();

        List<GL_Account_Default__c> defs = [
            SELECT
                Id,
                GL_Account__c,
                GL_Account__r.Name,
                GL_Account_Specification__c,
                Ledger__c,
                Ledger__r.Name
            FROM GL_Account_Default__c
            WHERE Ledger__r.Name = :'Consolidation ledger1'
        ];

        System.assertEquals(3, defs.size());
        for (GL_Account_Default__c def : defs) {
            if (def.GL_Account_Specification__c == GLAccountDefaultsHandler.CTA_GL_ACCOUNT) {
                System.assert(def.GL_Account__r.Name == '3900-CTA');
            }
            System.assert(def.GL_Account_Specification__c == GLAccountDefaultsHandler.CTA_GL_ACCOUNT
                || def.GL_Account_Specification__c == GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT
                || def.GL_Account_Specification__c == GLAccountDefaultsHandler.RETAINED_EARNINGS_GL_ACCOUNT);
        }

        List<GL_Account_Default__c> transDefs = [
            SELECT Id, GL_Account__c, GL_Account__r.Name, GL_Account_Specification__c, Ledger__c, Ledger__r.Name
            FROM GL_Account_Default__c
            WHERE Ledger__r.Name = :'Actual'
        ];

        System.assertEquals(19, transDefs.size());

        for (GL_Account_Default__c def : transDefs) {
            if (def.GL_Account_Specification__c == GLAccountDefaultsHandler.CTA_GL_ACCOUNT) {
                System.assert(def.GL_Account__r.Name == '3900-CTA');
            }
        }

    }

    @IsTest
    public static void testSetAutoPostSourceDocsFields() {
        PostInstallActions postInstall = new PostInstallActions();
        Test.testInstall(postInstall, NULL);

        try {
            Accounting_Settings__c acctSettings = AccountingSettingsHandler.getAccountingSettings();
            System.assertEquals(true, acctSettings.get('Auto_Post_Source_Documents__c'));

            acctSettings.put('Auto_Post_Source_Documents__c', false);
            update acctSettings;

            Test.startTest();
            Test.testInstall(postInstall, new Version(3, 144), true);
            Test.stopTest();

            String acctSettingsId = acctSettings.Id;
            Accounting_Settings__c acctSettings2 = Database.query(
                'SELECT ' +
                    'Id, ' +
                    'Auto_Post_Source_Documents__c, ' +
                    'Auto_Post_Cash_Receipts__c, ' +
                    'Auto_Post_Billing_Cash_Receipts__c, ' +
                    'Auto_Post_AP_Disbursements__c, ' +
                    'Auto_Post_Amortization_Entries__c ' +
                'FROM Accounting_Settings__c ' +
                'WHERE Id =: acctSettingsId ' +
                'LIMIT 1'
            );
            System.assertEquals(false, acctSettings2.get('Auto_Post_Source_Documents__c'));
            System.assertEquals(false, acctSettings2.Auto_Post_AP_Disbursements__c);
        }
        catch (System.SObjectException sObjEx) {

        }
    }

    @IsTest
    public static void testUpgradeSummer23Pre2PushPaymentProcessing() {        
        PostInstallActions postInstall = new PostInstallActions();
        Test.testInstall(postInstall, null); // install

        // account connected to stripe
        Account acct = new Account(
            Name = 'Test Customer', 
            Accounting_Active__c = true, 
            Accounting_Type__c = 'Customer & Vendor', 
            Stripe_Customer_Id__c = 'cus_123abc456def123abc456def'
        );
        insert acct;

        // need to create a placeholder because Payment_Processor__c is required 
        // on the payment method, and we still want to test payment methods are
        // upgraded correctly
        Payment_Processor__c placeholderProcessor = new Payment_Processor__c(
            Name = 'Placeholder',
            Type__c = PaymentProcessorActions.STRIPE_TYPE,
            Connected_Account_Token__c = 'Placeholder'
        );
        insert placeholderProcessor;

        Date today = Date.today();

        // payment method connected to stripe
        Payment_Method__c paymentMethod = new Payment_Method__c(
            Customer__c = acct.Id, 
            Expiration_Month__c = '12',
            Expiration_Year__c = String.valueOf(today.year() + 1),
            Type__c = 'VISA',
            Last_Four_Digits__c = '7845',
            Status__c = 'Active',
            External_Id__c = 'pm_123abc456def123abc456def',
            Payment_Processor__c = placeholderProcessor.Id
        );
        insert paymentMethod;

        // accounting setting connected to stripe
        Accounting_Settings__c acctSettings = AccountingSettingsHandler.getAccountingSettings();
        acctSettings.Stripe_Connected_Account_Id__c = 'acct_123abc456def123abc456def';
        update acctSettings;
        AccountingSettingsHandler.resetAccountingSettings();

        Test.startTest();
        Test.testInstall(postInstall, new Version(3, 155), true); // push upgrade
        Test.stopTest(); // stop test here so updatePaymentMethods future can complete execution

        // Check Payment Processor
        List<Payment_Processor__c> processors = [
            SELECT 
                Id
              , Name
              , Connected_Account_Token__c
              , Active__c
              , Test_Mode__c
              , Type__c
              , Global_Default_Payment_Processor__c  
            FROM Payment_Processor__c
            ORDER BY Connected_Account_Token__c ASC
        ];
        Assert.isNotNull(processors);
        Assert.areEqual(2, processors.size()); // placeholder plus post install created processor
        
        Payment_Processor__c processor = processors[0]; // the post install created processor
        // assert processor is connected account token matches accounting settings
        Assert.areEqual(acctSettings.Stripe_Connected_Account_Id__c, processor.Connected_Account_Token__c);
        // assert processor is active
        Assert.isTrue(processor.Active__c);
        // assert processor is not in test mode
        Assert.isFalse(processor.Test_Mode__c);
        // assert processor is type stripe
        Assert.areEqual(PaymentProcessorActions.STRIPE_TYPE, processor.Type__c);
        // assert processor has name Stripe
        Assert.areEqual(PaymentProcessorActions.STRIPE_TYPE, processor.Name);
        // assert processor is set as global default
        Assert.isTrue(processor.Global_Default_Payment_Processor__c);

        // Check Accounting Settings
        Assert.areEqual(processor.Id, AccountingSettingsHandler.getAccountingSettings().Stripe_Connected_Account_Id__c);

        // Check Payment Method
        // assert payment method is connected to processor
        Assert.areEqual(processor.Id, [SELECT Payment_Processor__c FROM Payment_Method__c WHERE Id = :paymentMethod.Id][0].Payment_Processor__c);

        // Check Payment Processor Customer
        List<Payment_Processor_Customer__c> processorCustomers = [
            SELECT 
                Id
              , Account__c
              , External_Id__c
              , Processor__c
            FROM Payment_Processor_Customer__c
        ];
        Assert.isNotNull(processorCustomers);
        Assert.areEqual(1, processorCustomers.size());

        Payment_Processor_Customer__c processorCustomer = processorCustomers[0];
        // assert processor customer is connected to account
        Assert.areEqual(acct.Id, processorCustomer.Account__c);
        // assert processor customer is connected to processor
        Assert.areEqual(processor.Id, processorCustomer.Processor__c);
        // assert processor customer external id matches stripe customer id
        Assert.areEqual(acct.Stripe_Customer_Id__c, processorCustomer.External_Id__c);
    }

    @IsTest
    public static void testUpgradeSummer23Pre2PullPaymentProcessing() {
        PostInstallActions postInstall = new PostInstallActions();
        Test.testInstall(postInstall, null); // install

        // account connected to stripe
        Account acct = new Account(
            Name = 'Test Customer', 
            Accounting_Active__c = true, 
            Accounting_Type__c = 'Customer & Vendor', 
            Stripe_Customer_Id__c = 'cus_123abc456def123abc456def'
        );
        insert acct;

        // need to create a placeholder because Payment_Processor__c is required 
        // on the payment method, and we still want to test payment methods are
        // upgraded correctly
        Payment_Processor__c placeholderProcessor = new Payment_Processor__c(
            Name = 'Placeholder',
            Type__c = PaymentProcessorActions.STRIPE_TYPE,
            Connected_Account_Token__c = 'Placeholder'
        );
        insert placeholderProcessor;

        Date today = Date.today();

        // payment method connected to stripe
        Payment_Method__c paymentMethod = new Payment_Method__c(
            Customer__c = acct.Id, 
            Expiration_Month__c = '12',
            Expiration_Year__c = String.valueOf(today.year() + 1),
            Type__c = 'VISA',
            Last_Four_Digits__c = '7845',
            Status__c = 'Active',
            External_Id__c = 'pm_123abc456def123abc456def',
            Payment_Processor__c = placeholderProcessor.Id
        );
        insert paymentMethod;

        // accounting setting connected to stripe
        Accounting_Settings__c acctSettings = AccountingSettingsHandler.getAccountingSettings();
        acctSettings.Stripe_Connected_Account_Id__c = 'acct_123abc456def123abc456def';
        update acctSettings;
        AccountingSettingsHandler.resetAccountingSettings();

        Test.startTest();
        Test.testInstall(postInstall, new Version(3, 155), false); // pull upgrade
        Test.stopTest(); // stop test here so updatePaymentMethods future can complete execution

        // Check Payment Processor
        List<Payment_Processor__c> processors = [
            SELECT 
                Id
              , Name
              , Connected_Account_Token__c
              , Active__c
              , Test_Mode__c
              , Type__c
              , Global_Default_Payment_Processor__c  
            FROM Payment_Processor__c
            ORDER BY Connected_Account_Token__c ASC
        ];
        Assert.isNotNull(processors);
        Assert.areEqual(2, processors.size()); // placeholder plus post install created processor
        
        Payment_Processor__c processor = processors[0]; // the post install created processor
        // assert processor is connected account token matches accounting settings
        Assert.areEqual(acctSettings.Stripe_Connected_Account_Id__c, processor.Connected_Account_Token__c);
        // assert processor is active
        Assert.isTrue(processor.Active__c);
        // assert processor is not in test mode
        Assert.isFalse(processor.Test_Mode__c);
        // assert processor is type stripe
        Assert.areEqual(PaymentProcessorActions.STRIPE_TYPE, processor.Type__c);
        // assert processor has name Stripe
        Assert.areEqual(PaymentProcessorActions.STRIPE_TYPE, processor.Name);
        // assert processor is set as global default
        Assert.isTrue(processor.Global_Default_Payment_Processor__c);

        // Check Accounting Settings
        Assert.areEqual(processor.Id, AccountingSettingsHandler.getAccountingSettings().Stripe_Connected_Account_Id__c);

        // Check Payment Method
        // assert payment method is connected to processor
        Assert.areEqual(processor.Id, [SELECT Payment_Processor__c FROM Payment_Method__c WHERE Id = :paymentMethod.Id][0].Payment_Processor__c);

        // Check Payment Processor Customer
        List<Payment_Processor_Customer__c> processorCustomers = [
            SELECT 
                Id
              , Account__c
              , External_Id__c
              , Processor__c
            FROM Payment_Processor_Customer__c
        ];
        Assert.isNotNull(processorCustomers);
        Assert.areEqual(1, processorCustomers.size());

        Payment_Processor_Customer__c processorCustomer = processorCustomers[0];
        // assert processor customer is connected to account
        Assert.areEqual(acct.Id, processorCustomer.Account__c);
        // assert processor customer is connected to processor
        Assert.areEqual(processor.Id, processorCustomer.Processor__c);
        // assert processor customer external id matches stripe customer id
        Assert.areEqual(acct.Stripe_Customer_Id__c, processorCustomer.External_Id__c);
    }

    @IsTest
    public static void testUpgradeSummer23Pre2PushNonPaymentProcessing() {
        PostInstallActions postInstall = new PostInstallActions();
        Test.testInstall(postInstall, null);

        Test.startTest();
        Test.testInstall(postInstall, new Version(3, 155), true); // push upgrade
        Test.stopTest();

        Assert.areEqual(0, [SELECT count() FROM Payment_Processor__c]);
        Assert.areEqual(0, [SELECT count() FROM Payment_Processor_Customer__c]);
        Assert.areEqual(0, [SELECT count() FROM Payment_Method__c]);
    }

    @IsTest
    public static void testUpgradeSummer23Pre2PullNonPaymentProcessing() {
        PostInstallActions postInstall = new PostInstallActions();
        Test.testInstall(postInstall, null);

        Test.startTest();
        Test.testInstall(postInstall, new Version(3, 155), false); // pull upgrade
        Test.stopTest();

        Assert.areEqual(0, [SELECT count() FROM Payment_Processor__c]);
        Assert.areEqual(0, [SELECT count() FROM Payment_Processor_Customer__c]);
        Assert.areEqual(0, [SELECT count() FROM Payment_Method__c]);
    }

    @IsTest
    public static void testUpgradeSummer23Pre2BadExistingStripeId() {
        PostInstallActions postInstall = new PostInstallActions();
        Test.testInstall(postInstall, null);

        // update accounting settings to have a bad stripe connected account id
        Accounting_Settings__c acctSettings = AccountingSettingsHandler.getAccountingSettings();
        acctSettings.Stripe_Connected_Account_Id__c = ' nUlL ';
        update acctSettings;
        AccountingSettingsHandler.resetAccountingSettings();

        Test.startTest();
        Test.testInstall(postInstall, new Version(3, 155), true); // push upgrade
        Test.stopTest();

        // processor not created
        Assert.areEqual(0, [SELECT count() FROM Payment_Processor__c]);
    }

    @IsTest
    public static void testPresetLedgerAccountingMethod() {
        TestDataSuite testDataSuite = TestDataSuite.getInstance(true);

        List<Ledger__c> ledgers = [SELECT Id, Accounting_Method__c FROM Ledger__c WHERE Accounting_Method__c =: LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH LIMIT 1];
        System.assert(ledgers[0].Accounting_Method__c == LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH);

        Test.startTest();
        PostInstallActions.presetLedgerAccountingMethod(LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH, LedgerActions.ACCOUNTING_METHOD_CASH);
        Test.stopTest();

        System.assert([SELECT Accounting_Method__c FROM Ledger__c WHERE Id =:ledgers[0].Id].Accounting_Method__c == LedgerActions.ACCOUNTING_METHOD_CASH);
    }

    @IsTest
    public static void testActivateLedgersTest() {
        TestDataSuite testDataSuite = TestDataSuite.getInstance(true);

        List<Ledger__c> ledgers = DomainUtils.getLedgerByType(new Set<String> {'Transactional'});
        TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Ledger__c.Active__c});
        update new Ledger__c(Id = ledgers[0].Id, Active__c = false);
        TriggerObserver.purgeUnlockedFields(Ledger__c.Active__c);
        System.assert(![SELECT Active__c FROM Ledger__c WHERE Id =:ledgers[0].Id].Active__c);

        Test.startTest();
        PostInstallActions.activateLedgersAsynchronously();
        Test.stopTest();

        System.assert([SELECT Active__c FROM Ledger__c WHERE Id =:ledgers[0].Id].Active__c);
    }

    @IsTest
    public static void testCreateConnectionNameForExistingAccessTokens() {
        //create 6 access tokens with no name across 2 institutions to simulate existing ones before release
        List<BDC_Access_Tokens__c> newAccTokens = new List<BDC_Access_Tokens__c>();
        Integer tokenCounter = 0;
        while (tokenCounter < 3) {
            BDC_Access_Tokens__c newToken = new BDC_Access_Tokens__c();
            newToken.Financial_Institution_Id__c = 'big bank 1';
            newToken.Financial_Institution_Identity_Id__c = 'bigbank1' + String.valueOf(tokenCounter);
            newToken.Name = 'bigbank1Name' + String.valueOf(tokenCounter);
            newToken.Identity_Name__c= null;
            newToken.Source__c = 'Plaid';
            newToken.Token__c = 'bbbbank1' + String.valueOf(tokenCounter);
            newAccTokens.add(newToken);
            tokenCounter++;
        }

        tokenCounter = 0;
        while (tokenCounter < 3) {
            BDC_Access_Tokens__c newToken = new BDC_Access_Tokens__c();
            newToken.Financial_Institution_Id__c = 'big bank 2';
            newToken.Financial_Institution_Identity_Id__c = 'bigbank2' + String.valueOf(tokenCounter);
            newToken.Name = 'bigbank2Name' + String.valueOf(tokenCounter);
            newToken.Identity_Name__c= null;
            newToken.Source__c = 'Plaid';
            newToken.Token__c = 'bbbbank2' + String.valueOf(tokenCounter);
            newAccTokens.add(newToken);
            tokenCounter++;
        }

        insert newAccTokens;

        //run the post install action
        PostInstallActions.createConnectionNameForExistingAccessTokens();

        //bucket the connection names by institution
        Map<String, Set<String>> institutionToConnectionName = new Map<String, Set<String>>();
        for (BDC_Access_Tokens__c aToken : BDC_Access_Tokens__c.getAll().values()) {
            if (institutionToConnectionName.get(aToken.Financial_Institution_Id__c) == null) {
                institutionToConnectionName.put(aToken.Financial_Institution_Id__c, new Set<String>());
            }
            institutionToConnectionName.get(aToken.Financial_Institution_Id__c).add(aToken.Identity_Name__c);
        }

        //check that each institution has 3 connections with the correct names
        for (Set<String> connNamesForInstitution: institutionToConnectionName.values()) {
            System.assert(connNamesForInstitution.contains('Connection_1'));
            System.assert(connNamesForInstitution.contains('Connection_2'));
            System.assert(connNamesForInstitution.contains('Connection_3'));
        }
    }

    @IsTest
    public static void testCreateConnectionNameForExistingGLAM() {

        //create supporting objects for GLAM
        TestDataSuite testDataSuite = TestDataSuite.getInstance(true);

        Ledger__c ledgerForGlam = [SELECT Id FROM Ledger__c][0];
        GL_Account__c accForGlam = [SELECT Id FROM GL_Account__c][0];

        //Create access token to be associated with the GLAM via identity
        String mockIdentityId = 'ladsfjakjh2';
        BDC_Access_Tokens__c tokenWithName = new BDC_Access_Tokens__c();
        tokenWithName.Financial_Institution_Id__c = 'big bank 1';
        tokenWithName.Financial_Institution_Identity_Id__c = mockIdentityId;
        tokenWithName.Name = 'bigbank1Name';
        tokenWithName.Identity_Name__c= 'nameForConnection';
        tokenWithName.Source__c = 'Plaid';
        tokenWithName.Token__c = 'bbbbank1';
        insert tokenWithName;

        //simulate a previously existing GLAM which has a identity id but no connection name but has been mapped to a ledger and GL_Account__c
        GL_Account_Mapping__c noConnNameMapping = new GL_Account_Mapping__c();
        noConnNameMapping.Ledger__c = ledgerForGlam.Id;
        noConnNameMapping.GL_Account__c = accForGlam.Id;
        noConnNameMapping.Financial_Institution_Id__c = mockIdentityId;
        noConnNameMapping.External_Id__c = 'mockextid123';
        noConnNameMapping.Inactive__c= false;
        noConnNameMapping.Source__c = 'Plaid';
        insert noConnNameMapping;

        //run script
        PostInstallActions.createConnectionNameForExistingGLAM();

        //assure that the connection name on the access token is on the GLAM
        GL_Account_Mapping__c updatedGLAM = [SELECT Id, Connection_Name__c FROM GL_Account_Mapping__c WHERE Ledger__c = :ledgerForGlam.Id AND GL_Account__c = :accForGlam.Id][0];
        System.assertNotEquals(updatedGLAM.Connection_Name__c, null);


    }

    @IsTest
    public static void testsetCashDisbursementSourcePayable() {
        PostInstallActions postInstall = new PostInstallActions();
        Test.testInstall(postInstall, null);

        Test.startTest();
            Accounting_Settings__c settings = [SELECT Id,Cash_Disbursement_Source__c 
            FROM Accounting_Settings__c LIMIT 1];
            settings.Cash_Disbursement_Source__c = NULL;
            update settings;

            Test.testInstall(postInstall, new Version(3,234), true); 
        Test.stopTest();

        System.assertEquals('Payable',[SELECT Id,Cash_Disbursement_Source__c 
                            FROM Accounting_Settings__c LIMIT 1].Cash_Disbursement_Source__c);
    }

    @IsTest
    public static void testCreateUnappliedCashGLAccounts() {
        PostInstallActions postInstall = new PostInstallActions();
        Test.testInstall(postInstall, null);

        Test.startTest();
        List<String> glAccountNames = new List<String>{
                PostInstallActions.CASH_4015_UNAPPLIED_REVENUE,
                PostInstallActions.CASH_8000_UNAPPLIED_EXPENSE
        };
        delete [SELECT Id FROM GL_Account_Default__c WHERE GL_Account__r.Name =: glAccountNames];
        delete DomainUtils.getGlAccountsByName(glAccountNames);
        System.assert(DomainUtils.getGlAccountsByName(glAccountNames).size() == 0);

        Test.testInstall(postInstall, new Version(3,234), true);
        Test.stopTest();

        System.assert(DomainUtils.getGlAccountsByName(glAccountNames).size() == 2);
        System.assert(!DomainUtils.gLAccountDefaultsBySpecsAndLTypes(
                new Set<String>(PostInstallActions.GL_ACCT_DEF_SPECS_BY_GL_ACCT_NAMES.values()),
                new Set<String>{ LedgerActions.LEDGER_TYPE_TRANSACTIONAL, LedgerActions.LEDGER_TYPE_BUDGET }
        ).isEmpty());
    }
}