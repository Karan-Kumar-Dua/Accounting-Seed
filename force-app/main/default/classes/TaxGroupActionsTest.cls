@IsTest
private class TaxGroupActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testTaxTypeChangeError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Tax_Group__c testTaxGroup = new Tax_Group__c(
                Name = 'TestTaxGroup',
                Tax_Type__c = 'Sales'
            );

            insert testTaxGroup;

            Tax_Rate__c testTaxRate = new Tax_Rate__c(
                Name = 'TestTaxRate',
                Tax_Group__c = testTaxGroup.Id,
                Tax_Rate__c = 10,
                Sales_Tax_Liability_GL_Account__c = testData.glAccounts[6].Id
            );

            DmlException dmlEx;
            try {
                insert testTaxRate;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);

            //Update Tax Type on Tax Group record
            try {
                testTaxGroup.Tax_Type__c = 'Purchase';
                update testTaxGroup;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(TaxGroupActions.TAX_RATE_PURCHASE_TAX_GL_ACCOUNT_MISSING_ERROR, dmlEx.getDmlMessage(0));

            dmlEx = NULL;
            try {
                testTaxGroup.Tax_Type__c = 'Sales and Purchase';
                update testTaxGroup;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(TaxGroupActions.TAX_RATE_SALES_AND_PURCHASE_TAX_GL_ACCOUNT_MISSING_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    static void testMaxTaxRateLimitReachedError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Tax_Group__c testTaxGroup = new Tax_Group__c(
                Name = 'TestTaxGroup',
                Tax_Type__c = 'Sales'
            );

            insert testTaxGroup;

            Tax_Rate__c testTaxRate = new Tax_Rate__c(
                Name = 'TestTaxRate',
                Tax_Group__c = testTaxGroup.Id,
                Tax_Rate__c = 10,
                Sales_Tax_Liability_GL_Account__c = testData.glAccounts[6].Id
            );

            List<Tax_Rate__c> rates = new List<Tax_Rate__c>();
            rates.add(testTaxRate);
            for (Integer i = 0; i < TaxGroupActions.MAX_TAX_RATES_COUNT; i++) {
                rates.add(testTaxRate.clone());
            }

            DmlException dmlEx;
            try {
                insert rates;//DML exception cause 6 line per Tax Group
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(
                String.format(TaxGroupActions.MAX_LINE_ERROR, new List<String>{String.valueOf(TaxGroupActions.MAX_TAX_RATES_COUNT)}),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    static void testPreventUpdateCombinedTaxRateIfAssociated() {
        TestDataSuite testData = TestDataSuite.getInstance().createTaxGroups();

        System.runAs(testData.users.get(1)) {
            Billing__c testBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c+3,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = System.today() + 30
            );
            insert testBilling;

            Billing_Line__c testBillingLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 20,
                Rate__c = 10,
                Revenue_GL_Account__c = testData.glAccounts[10].Id,
                Tax_Group__c = testDAta.taxGroups[0].Id
            );
            insert testBillingLine;

            Test.startTest();
            Tax_Rate__c testTaxRate = testData.taxRates[0];
            DmlException dmlEx;
            try {
                testTaxRate.Tax_Rate__c = 15;
                update testTaxRate;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(TaxGroupActions.COMBINED_TAX_RATE_UPDATE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    static void testPreventUpdateTaxRateCountIfAssociated() {
        TestDataSuite testData = TestDataSuite.getInstance().createTaxGroups();

        System.runAs(testData.users.get(1)) {
            Billing__c testBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c+3,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = System.today() + 30
            );
            insert testBilling;

            Billing_Line__c testBillingLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 20,
                Rate__c = 10,
                Revenue_GL_Account__c = testData.glAccounts[10].Id,
                Tax_Group__c = testDAta.taxGroups[0].Id
            );
            insert testBillingLine;

            Test.startTest();
            DmlException dmlEx;
            try {
                Tax_Rate__c newTaxRate = new Tax_Rate__c(
                    Name = 'SalesTaxRate2',
                    Tax_Group__c = testData.taxGroups[0].Id,
                    Tax_Rate__c = 10,
                    Sales_Tax_Liability_GL_Account__c = testData.glAccounts[6].Id
                );
                insert newTaxRate;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(TaxGroupActions.COMBINED_TAX_RATE_UPDATE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    static void testMaxTaxRateLimitReachedErrorAvaVATReporting() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setAvaVATSelected();

        System.runAs(testData.users.get(1)) {
            Tax_Group__c testTaxGroup = new Tax_Group__c(
                Name = 'TestTaxGroup',
                Tax_Type__c = 'Sales',
                External_Id2__c = 'ExtId'
            );
            insert testTaxGroup;

            Tax_Rate__c testTaxRate = new Tax_Rate__c(
                Name = 'TestTaxRate',
                Tax_Group__c = testTaxGroup.Id,
                Tax_Rate__c = 10,
                Purchase_Tax_Expense_GL_Account__c = testData.glAccounts[32].Id,
                Sales_Tax_Liability_GL_Account__c = testData.glAccounts[33].Id
            );

            List<Tax_Rate__c> rates = new List<Tax_Rate__c>();
            rates.add(testTaxRate);
            for (Integer i = 0; i < TaxGroupActions.AVAVAT_MAX_TAX_RATES_COUNT; i++) {
                rates.add(testTaxRate.clone());
            }

            DmlException dmlEx;
            try {
                insert rates;//DML exception cause 2 line per Tax Group
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(
                String.format(TaxGroupActions.MAX_LINE_ERROR, new List<String>{String.valueOf(TaxGroupActions.AVAVAT_MAX_TAX_RATES_COUNT)}),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    static void testMaxTaxRateLimitReachedErrorAvaVATReportingNoExternalID() {
        TestDataSuite testData = TestDataSuite.getInstance()
        .setAvaVATReportingEnabled();

        System.runAs(testData.users.get(1)) {
            Tax_Group__c testTaxGroup = new Tax_Group__c(
                Name = 'TestTaxGroup',
                Tax_Type__c = 'Sales'
            );

            insert testTaxGroup;

            Tax_Rate__c testTaxRate = new Tax_Rate__c(
                Name = 'TestTaxRate',
                Tax_Group__c = testTaxGroup.Id,
                Tax_Rate__c = 10,
                Sales_Tax_Liability_GL_Account__c = testData.glAccounts[6].Id
            );

            List<Tax_Rate__c> rates = new List<Tax_Rate__c>();
            rates.add(testTaxRate);
            for (Integer i = 0; i < TaxGroupActions.MAX_TAX_RATES_COUNT; i++) {
                rates.add(testTaxRate.clone());
            }

            DmlException dmlEx;
            try {
                insert rates;//DML exception cause 6 line per Tax Group
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(
                String.format(TaxGroupActions.MAX_LINE_ERROR, new List<String>{String.valueOf(TaxGroupActions.MAX_TAX_RATES_COUNT)}),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    static void testTaxRateWithoutGLAccountsAvaVAT() {
        TestDataSuite testData = TestDataSuite.getInstance()
        .setAvaVATSelected();

        System.runAs(testData.users.get(1)) {
            
            Tax_Group__c testTaxGroup = new Tax_Group__c(
                Name = 'TestTaxGroup',
                Tax_Type__c = 'Purchase',
                External_Id2__c = 'ExtID'
            );

            insert testTaxGroup;

            List<GL_Account__c> glAccounts = new List<GL_Account__c>();
            glAccounts.add(
                new GL_Account__c(
                    Name = 'Cash Flow Test GL Account',
                    Active__c = true,
                    Type__c = 'Cash Flow',
                    Sub_Type_1__c = 'Operating'                
                )
            );

            insert glAccounts;        

            //Attempt to insert a tax rate without setting the two GL Accounts 
            Tax_Rate__c testTaxRate = new Tax_Rate__c(
                Name = 'TestTaxRate',
                Tax_Group__c = testTaxGroup.Id,
                Tax_Rate__c = 10
            );

            DmlException dmlEx;
            try {
                insert testTaxRate;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(TaxGroupActions.TAX_RATE_PURCHASE_TAX_GL_ACCOUNT_MISSING_ERROR, dmlEx.getDmlMessage(0));

            //Attempt to insert a tax rate with the Purchase Tax Expense GL Account set to a GL Account that is not Balance Sheet, Expense or Revenue type
            testTaxRate.Purchase_Tax_Expense_GL_Account__c = glAccounts[0].Id;            

            dmlEx = NULL;
            try {
                insert testTaxRate;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));

            //Attempt to insert a tax rate with the Sales Tax Liability GL Account set to a GL Account that is not an Output VAT account 
            testTaxRate.Purchase_Tax_Expense_GL_Account__c = testData.glAccounts[30].Id;
            testTaxRate.Sales_Tax_Liability_GL_Account__c = testData.glAccounts[6].Id;

            dmlEx = NULL;
            try {
                insert testTaxRate;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));

            //Insert a tax rate with both GL Accounts set
            testTaxRate.Purchase_Tax_Expense_GL_Account__c = testData.glAccounts[32].Id;
            testTaxRate.Sales_Tax_Liability_GL_Account__c = testData.glAccounts[33].Id;

            dmlEx = NULL;
            try {
                insert testTaxRate;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);

            Test.startTest();
            //Update the tax rate record to null out one of the GL Accounts
            dmlEx = NULL;
            try {
                testTaxRate.Purchase_Tax_Expense_GL_Account__c = NULL;
                update testTaxRate;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(TaxGroupActions.TAX_RATE_PURCHASE_TAX_GL_ACCOUNT_MISSING_ERROR, dmlEx.getDmlMessage(0));
            
            //Update the tax rate record to set to a GL Account that is not Balance Sheet, Expense or Revenue type
            dmlEx = NULL;
            try {
                testTaxRate.Purchase_Tax_Expense_GL_Account__c = glAccounts[0].Id;
                update testTaxRate;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);            
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));

            //Update the tax rate record to set the Sales Tax Liability GL Account to a GL account that does not have Output VAT set
            dmlEx = NULL;
            try {
                testTaxRate.Purchase_Tax_Expense_GL_Account__c = testData.glAccounts[30].Id;
                testTaxRate.Sales_Tax_Liability_GL_Account__c = testData.glAccounts[6].Id;
                update testTaxRate;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);            
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));

            //Update the tax rate record with both GL Accounts set
            dmlEx = NULL;
            try {
                testTaxRate.Purchase_Tax_Expense_GL_Account__c = testData.glAccounts[32].Id;
                testTaxRate.Sales_Tax_Liability_GL_Account__c = testData.glAccounts[33].Id;
                update testTaxRate;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);    
            
            //update the tax group to set the reverse charge checkbox to true, then attempt to add a new tax rate record with only one of the GL Accounts set
            testTaxGroup.Reverse_Charge__c = true;
            update testTaxGroup;

            Tax_Rate__c testTaxRate2 = new Tax_Rate__c(
                Name = 'TestTaxRate',
                Tax_Group__c = testTaxGroup.Id,
                Tax_Rate__c = 10,
                Purchase_Tax_Expense_GL_Account__c = testData.glAccounts[32].Id
            );

            dmlEx = NULL;
            try {
                insert testTaxRate2;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(TaxGroupActions.AVAVAT_TAX_RATE_SALES_AND_PURCHASE_TAX_GL_ACCOUNT_MISSING_ERROR, dmlEx.getDmlMessage(0));

            //insert it with both GL Accounts set
            testTaxRate2.Sales_Tax_Liability_GL_Account__c = testData.glAccounts[33].Id;

            dmlEx = NULL;
            try {
                insert testTaxRate2;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);

            //update the tax rate to remove one of the GL Accounts
            testTaxRate2.Purchase_Tax_Expense_GL_Account__c = NULL;

            dmlEx = NULL;
            try {
                update testTaxRate2;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(TaxGroupActions.AVAVAT_TAX_RATE_SALES_AND_PURCHASE_TAX_GL_ACCOUNT_MISSING_ERROR, dmlEx.getDmlMessage(0));
            Test.stopTest();
        }
    }

    @IsTest
    static void testExternalIDNotAllowedIfAvaVATNotEnabled() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Tax_Group__c testTaxGroup = new Tax_Group__c(
                Name = 'TestTaxGroup',
                Tax_Type__c = 'Sales',
                External_Id2__c = 'ExtId'
            );
            DmlException dmlEx;
            try {
                insert testTaxGroup;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(
                TaxGroupActions.EXTERNAL_ID_NOT_ALLOWED_ERROR,
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    static void testPreventDeleteTaxGroup() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost();

        System.runAs(testData.users.get(1)) {
            Tax_Group__c testTaxGroup = new Tax_Group__c(
                Name = 'TestTaxGroup',
                Tax_Type__c = 'Sales'
            );
            insert testTaxGroup;

            Tax_Rate__c testTaxRate = new Tax_Rate__c(
                Name = 'TestTaxRate',
                Tax_Group__c = testTaxGroup.Id,
                Tax_Rate__c = 10,
                Sales_Tax_Liability_GL_Account__c = testData.glAccounts[6].Id
            );
            insert testTaxRate;

            Billing__c testBilling = new Billing__c(
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id
            );
            insert testBilling;

            Billing_Line__c testBillingLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 1,
                Rate__c = 100,
                Tax_Group__c = testTaxGroup.Id
            );
            insert testBillingLine;

            Decimal expectedTotal = testBillingLine.Rate__c * testBillingLine.Hours_Units__c * testTaxRate.Tax_Rate__c/100
                + testBillingLine.Rate__c * testBillingLine.Hours_Units__c;

            System.assertEquals(
                expectedTotal,
                [SELECT Total__c FROM Billing_Line__c WHERE Id = :testBillingLine.Id].Total__c
            );

            DmlException dmlEx;
            try {
                delete testTaxGroup;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(TaxGroupActions.EXISTED_RECORD_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    static void testPreventDeleteTaxGroupRecurringRecordsExist() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost();

        System.runAs(testData.users.get(1)) {
            Tax_Group__c testSalesPurchaseTaxGroup = new Tax_Group__c(
                Name = 'TestSalesTaxGroup',
                Tax_Type__c = 'Sales and Purchase'
            );
            insert testSalesPurchaseTaxGroup;

            Tax_Rate__c testTaxRate = new Tax_Rate__c(
                Name = 'TestTaxRate',
                Tax_Group__c = testSalesPurchaseTaxGroup.Id,
                Tax_Rate__c = 10,
                Sales_Tax_Liability_GL_Account__c = testData.glAccounts[6].Id,
                Purchase_Tax_Expense_GL_Account__c = testData.glAccounts[6].Id
            );
            insert testTaxRate;

            Recurring_Billing__c testRecBilling = new Recurring_Billing__c(
                Name = 'Test Recurring Billing',
                Customer__c = testData.accounts[0].Id,
                Next_Billing_Date__c = Date.newInstance(1991, 12, 31),
                Billing_Frequency__c = 'Monthly',
                Status__c = 'Active'
            );
            insert testRecBilling;

            Recurring_Billing_Line__c testRecBillingLine = new Recurring_Billing_Line__c(
                Recurring_Billing__c = testRecBilling.Id,
                Quantity__c = 1,
                Rate__c = 100,
                Revenue_GL_Account__c = testData.glAccounts[11].Id,
                Tax_Group__c = testSalesPurchaseTaxGroup.Id
            );
            insert testRecBillingLine;

            Recurring_Account_Payable__c testRecPayable = new Recurring_Account_Payable__c(
                Name = 'Test Recurring Payable',
                Vendor__c = testData.accounts.get(0).Id,
                Next_Account_Payable_Date__c = Date.newInstance(1991, 12, 31),
                Account_Payable_Frequency__c = 'Monthly',
                Status__c = 'Active'
            );
            insert testRecPayable;

            Recurring_Account_Payable_Line__c testRecPayableLine = new Recurring_Account_Payable_Line__c(
                Recurring_Account_Payable__c = testRecPayable.Id,
                Quantity__c = 1,
                Unit_Cost__c = 100,
                Expense_GL_Account__c = testData.glAccounts.get(11).Id,
                Tax_Group__c = testSalesPurchaseTaxGroup.Id
            );
            insert testRecPayableLine;

            DmlException dmlEx;
            try {
                delete testSalesPurchaseTaxGroup;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(TaxGroupActions.EXISTED_RECORD_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    static void testPreventTaxTypeChange() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Tax_Group__c testSalesTaxGroup = new Tax_Group__c(
                Name = 'TestSalesTaxGroup',
                Tax_Type__c = 'Sales'
            );
            insert testSalesTaxGroup;

            Tax_Rate__c testTaxRate1 = new Tax_Rate__c(
                Name = 'TestTaxRate1',
                Tax_Group__c = testSalesTaxGroup.Id,
                Tax_Rate__c = 10,
                Sales_Tax_Liability_GL_Account__c = testData.glAccounts[6].Id
            );
            insert testTaxRate1;

            Tax_Group__c testPurchaseTaxGroup = new Tax_Group__c(
                Name = 'TestPurchaseTaxGroup',
                Tax_Type__c = 'Purchase'
            );
            insert testPurchaseTaxGroup;

            Tax_Rate__c testTaxRate2 = new Tax_Rate__c(
                Name = 'TestTaxRate2',
                Tax_Group__c = testPurchaseTaxGroup.Id,
                Tax_Rate__c = 10,
                Purchase_Tax_Expense_GL_Account__c = testData.glAccounts[6].Id
            );
            insert testTaxRate2;

            Billing__c testBilling = new Billing__c(
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id
            );
            insert testBilling;

            Billing_Line__c testBillingLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 1,
                Rate__c = 100,
                Tax_Group__c = testSalesTaxGroup.Id
            );
            insert testBillingLine;

            Decimal expectedTotal = testBillingLine.Rate__c * testBillingLine.Hours_Units__c * testTaxRate2.Tax_Rate__c/100
                + testBillingLine.Rate__c * testBillingLine.Hours_Units__c;

            System.assertEquals(
                expectedTotal,
                [SELECT Total__c FROM Billing_Line__c WHERE Id = :testBillingLine.Id].Total__c
            );

            Account_Payable__c testPayable = new Account_Payable__c(
                Payee_Reference__c = '234sdfigojjnklsndlfg',
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Vendor__c = testData.accounts[0].Id
            );
            insert testPayable;

            Account_Payable_Line__c testPayableLine = new Account_Payable_Line__c(
                Account_Payable__c = testPayable.Id,
                Unit_Cost__c = 100,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Expense_GL_Account__c = testData.glAccounts[16].Id,
                Tax_Group__c = testPurchaseTaxGroup.Id
            );
            insert testPayableLine;

            DmlException dmlEx;
            try {
                testSalesTaxGroup.Tax_Type__c = 'Purchase';
                update testSalesTaxGroup;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(TaxGroupActions.SALES_TAX_TYPE_CHANGE_ERROR, dmlEx.getDmlMessage(0));

            dmlEx = NULL;
            try {
                testPurchaseTaxGroup.Tax_Type__c = 'Sales';
                update testPurchaseTaxGroup;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(TaxGroupActions.PURCHASE_TAX_TYPE_CHANGE_ERROR, dmlEx.getDmlMessage(0));
            Test.stopTest();
        }
    }

    @IsTest
    static void testPreventTaxTypeChangeIfRecurringRecordsExist() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost();

        System.runAs(testData.users.get(1)) {
            Tax_Group__c testSalesTaxGroup = new Tax_Group__c(
                Name = 'TestSalesTaxGroup',
                Tax_Type__c = 'Sales'
            );
            insert testSalesTaxGroup;

            Tax_Rate__c testTaxRate1 = new Tax_Rate__c(
                Name = 'TestTaxRate1',
                Tax_Group__c = testSalesTaxGroup.Id,
                Tax_Rate__c = 10,
                Sales_Tax_Liability_GL_Account__c = testData.glAccounts[6].Id
            );
            insert testTaxRate1;

            Tax_Group__c testPurchaseTaxGroup = new Tax_Group__c(
                Name = 'TestPurchaseTaxGroup',
                Tax_Type__c = 'Purchase'
            );
            insert testPurchaseTaxGroup;

            Tax_Rate__c testTaxRate2 = new Tax_Rate__c(
                Name = 'TestTaxRate2',
                Tax_Group__c = testPurchaseTaxGroup.Id,
                Tax_Rate__c = 10,
                Purchase_Tax_Expense_GL_Account__c = testData.glAccounts[6].Id
            );
            insert testTaxRate2;

            Recurring_Billing__c testRecBilling = new Recurring_Billing__c(
                Name = 'Test Recurring Billing',
                Customer__c = testData.accounts[0].Id,
                Next_Billing_Date__c = Date.newInstance(1991, 12, 31),
                Billing_Frequency__c = 'Monthly',
                Status__c = 'Active'
            );
            insert testRecBilling;

            Recurring_Billing_Line__c testRecBillingLine = new Recurring_Billing_Line__c(
                Recurring_Billing__c = testRecBilling.Id,
                Quantity__c = 1,
                Rate__c = 100,
                Revenue_GL_Account__c = testData.glAccounts[11].Id,
                Tax_Group__c = testSalesTaxGroup.Id
            );
            insert testRecBillingLine;

            Decimal expectedTotal = testRecBillingLine.Rate__c * testRecBillingLine.Quantity__c * testTaxRate1.Tax_Rate__c/100
                + testRecBillingLine.Rate__c * testRecBillingLine.Quantity__c;

            System.assertEquals(
                expectedTotal,
                [SELECT Total__c FROM Recurring_Billing_Line__c WHERE Id = :testRecBillingLine.Id].Total__c
            );

            Recurring_Account_Payable__c testRecPayable = new Recurring_Account_Payable__c(
                Name = 'Test Recurring Payable',
                Vendor__c = testData.accounts.get(0).Id,
                Next_Account_Payable_Date__c = Date.newInstance(1991, 12, 31),
                Account_Payable_Frequency__c = 'Monthly',
                Status__c = 'Active'
            );
            insert testRecPayable;

            Recurring_Account_Payable_Line__c testRecPayableLine = new Recurring_Account_Payable_Line__c(
                Recurring_Account_Payable__c = testRecPayable.Id,
                Quantity__c = 1,
                Unit_Cost__c = 100,
                Expense_GL_Account__c = testData.glAccounts.get(11).Id,
                Tax_Group__c = testPurchaseTaxGroup.Id
            );
            insert testRecPayableLine;

            Test.startTest();
            DmlException dmlEx;
            try {
                testSalesTaxGroup.Tax_Type__c = 'Purchase';
                update testSalesTaxGroup;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(TaxGroupActions.SALES_TAX_TYPE_CHANGE_ERROR, dmlEx.getDmlMessage(0));

            dmlEx = NULL;
            try {
                testPurchaseTaxGroup.Tax_Type__c = 'Sales';
                update testPurchaseTaxGroup;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(TaxGroupActions.PURCHASE_TAX_TYPE_CHANGE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    static void testPreventTaxTypeChangeFromSalesAndPurchase() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Tax_Group__c testTaxGroup = new Tax_Group__c(
                Name = 'TestTaxGroup',
                Tax_Type__c = 'Sales and Purchase'
            );
            insert testTaxGroup;

            Tax_Rate__c testTaxRate = new Tax_Rate__c(
                Name = 'TestTaxRate',
                Tax_Group__c = testTaxGroup.Id,
                Tax_Rate__c = 10,
                Sales_Tax_Liability_GL_Account__c = testData.glAccounts[6].Id,
                Purchase_Tax_Expense_GL_Account__c = testData.glAccounts[6].Id
            );
            insert testTaxRate;

            Billing__c testBilling = new Billing__c(
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id
            );
            insert testBilling;

            Billing_Line__c testBillingLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 1,
                Rate__c = 100,
                Tax_Group__c = testTaxGroup.Id
            );
            insert testBillingLine;

            Account_Payable__c testPayable = new Account_Payable__c(
                Payee_Reference__c = '234sdfigojjnklsndlfg',
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Vendor__c = testData.accounts[0].Id
            );
            insert testPayable;

            Account_Payable_Line__c testPayableLine = new Account_Payable_Line__c(
                Account_Payable__c = testPayable.Id,
                Unit_Cost__c = 100,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Expense_GL_Account__c = testData.glAccounts[16].Id,
                Tax_Group__c = testTaxGroup.Id
            );
            insert testPayableLine;

            DmlException dmlEx;
            try {
                testTaxGroup.Tax_Type__c = 'Sales';
                update testTaxGroup;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(TaxGroupActions.PURCHASE_TAX_TYPE_CHANGE_ERROR, dmlEx.getDmlMessage(0));

            dmlEx = NULL;
            try {
                testTaxGroup.Tax_Type__c = 'Purchase';
                update testTaxGroup;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(TaxGroupActions.SALES_TAX_TYPE_CHANGE_ERROR, dmlEx.getDmlMessage(0));
            Test.stopTest();
        }
    }

    @IsTest
    public static void testTaxGroupNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            DMLException dmlEx;
            try {
                Tax_Group__c tg = new Tax_Group__c();
                insert tg;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

    @IsTest
    static void testPreventUpdateTaxInclusiveIfAssociated() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.setHeaderLevelPost();
        testData.createTaxGroups();

        Test.startTest();
        testData.createBillings();

        System.runAs(testData.users.get(1)) {
            Tax_Group__c taxGroup = testData.taxGroups[0];
            Assert.isFalse([SELECT Tax_Inclusive__c FROM Tax_Group__c WHERE Id = :taxGroup.Id].Tax_Inclusive__c);
            taxGroup.Tax_Inclusive__c = true;
            update taxGroup;

            Billing__c billing = testData.billings[0];

            Billing_Line__c billingLine = new Billing_Line__c(
                Billing__c = billing.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 20,
                Rate__c = 10,
                Revenue_GL_Account__c = testData.glAccounts[10].Id,
                Tax_Group__c = taxGroup.Id
            );
            insert billingLine;

            DmlException expectedEx;
            try {
                taxGroup.Tax_Inclusive__c = false;
                update taxGroup;
            }
            catch (DmlException ex) {
                expectedEx = ex;
            }
            Test.stopTest();
            Assert.isNotNull(expectedEx);
            Assert.areEqual(Label.ERR_TAX_GROUP_UPDATE_TAX_INCLUSIVE, expectedEx.getDmlMessage(0));
        }
    }

}