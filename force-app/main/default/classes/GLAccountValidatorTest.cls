@IsTest
public class GLAccountValidatorTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testGlValidatorForTaxRateAndCashFlowCategory() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashFlowCategories(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            //Create Tax Group
            Tax_Group__c testTaxGroup = new Tax_Group__c(
                Name = 'SalesAndPurchaseTaxGroup',
                Tax_Type__c = 'Sales and Purchase'
            );
            insert testTaxGroup;

            //create Tax Rate with not-valid GL Accounts
            Tax_Rate__c testTaxRate = new Tax_Rate__c(
                Name = 'SalesAndPurchase',
                Tax_Group__c = testTaxGroup.Id,
                Tax_Rate__c = 10,
                Sales_Tax_Liability_GL_Account__c = testData.cashFlowCategories[0].Id,//not-valid
                Purchase_Tax_Expense_GL_Account__c = testData.cashFlowCategories[1].Id//not-valid
            );

            DmlException dmlEx;
            try {
                insert testTaxRate;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));

            dmlEx = NULL;
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            testTaxRate.Sales_Tax_Liability_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CUSTOMER_PAYMENT_ADJUSTMENT_GL_ACCOUNT)?.GL_Account__c;//valid
            testTaxRate.Purchase_Tax_Expense_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.LABOR_GL_ACCOUNT)?.GL_Account__c;//valid
            try {
                insert testTaxRate;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);

            try {
                testTaxRate.Purchase_Tax_Expense_GL_Account__c = testData.cashFlowCategories[1].Id;//not-valid
                update testTaxRate;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testGlValidatorForTaxRate() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            //Create Tax Group
            Tax_Group__c testTaxGroup = new Tax_Group__c(
                Name = 'SalesAndPurchaseTaxGroup',
                Tax_Type__c = 'Sales and Purchase'
            );
            insert testTaxGroup;
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            //create Tax Rate with not-valid GL Accounts
            Tax_Rate__c testTaxRate = new Tax_Rate__c(
                Name = 'SalesAndPurchase',
                Tax_Group__c = testTaxGroup.Id,
                Tax_Rate__c = 10,
                Sales_Tax_Liability_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT)?.GL_Account__c,//not-valid
                Purchase_Tax_Expense_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.PREPAID_EXPENSE_GL_ACCOUNT )?.GL_Account__c//valid
            );

            DmlException dmlEx;
            try {
                insert testTaxRate;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));

            dmlEx = NULL;
            testTaxRate.Sales_Tax_Liability_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CUSTOMER_PAYMENT_ADJUSTMENT_GL_ACCOUNT)?.GL_Account__c;//valid
            testTaxRate.Purchase_Tax_Expense_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;//not-valid
            try {
                insert testTaxRate;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));

            dmlEx = NULL;
            testTaxRate.Sales_Tax_Liability_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CUSTOMER_PAYMENT_ADJUSTMENT_GL_ACCOUNT)?.GL_Account__c;//valid
            testTaxRate.Purchase_Tax_Expense_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.LABOR_GL_ACCOUNT)?.GL_Account__c;//valid
            try {
                insert testTaxRate;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);

            try {
                testTaxRate.Purchase_Tax_Expense_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;//not-valid
                update testTaxRate;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testGlValidatorForTaxRateAvaVAT() {
        TestDataSuite testData = TestDataSuite.getInstance()
        .setAvaVATSelected();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            GL_Account__c inputVATGLAccount = testData.glAccounts[32];
            GL_Account__c outputVATGLAccount = testData.glAccounts[33];
            GL_Account__c invalidGLAccount = new GL_Account__c(
                Name = 'invalid GL',
                Active__c = true,
                Type__c = 'Cash Flow',
                Sub_Type_1__c = 'Operating'
            );
            insert invalidGLAccount;

            //Create Tax Group
            Tax_Group__c testTaxGroup = new Tax_Group__c(
                Name = 'SalesAndPurchaseTaxGroup',
                Tax_Type__c = 'Sales and Purchase',
                External_Id2__c = 'ABC123'
            );
            insert testTaxGroup;
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            //create Tax Rate with not-valid GL Accounts
            Tax_Rate__c testTaxRate = new Tax_Rate__c(
                Name = 'SalesAndPurchase',
                Tax_Group__c = testTaxGroup.Id,
                Tax_Rate__c = 10,
                Sales_Tax_Liability_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT)?.GL_Account__c,//not-valid
                Purchase_Tax_Expense_GL_Account__c = inputVATGLAccount.Id//valid
            );

            DmlException dmlEx;
            try {
                insert testTaxRate;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));

            dmlEx = NULL;
            testTaxRate.Sales_Tax_Liability_GL_Account__c = outputVATGLAccount.Id;//valid
            testTaxRate.Purchase_Tax_Expense_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;//not-valid
            try {
                insert testTaxRate;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));

            dmlEx = NULL;
            testTaxRate.Sales_Tax_Liability_GL_Account__c = outputVATGLAccount.Id;//valid
            testTaxRate.Purchase_Tax_Expense_GL_Account__c = inputVATGLAccount.Id;//valid
            try {
                insert testTaxRate;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);

            try {
                testTaxRate.Purchase_Tax_Expense_GL_Account__c =  defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;//not-valid
                update testTaxRate;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));

            dmlEx = NULL;
            try {
                testTaxRate.Purchase_Tax_Expense_GL_Account__c = invalidGLAccount.Id;//not-valid because of wrong sub_type_1 value
                update testTaxRate;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testGlValidatorForJournalEntryLine() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users[1]) {
            Test.startTest();
            DmlException dmlEx;
            try {
                Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
                Journal_Entry_Line__c testJEL = testData.journalEntryLines[0].clone(false, true, false, false);
                testJEL.GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT)?.GL_Account__c;
                insert testJEL;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testGlValidatorForBillingCashReceipt() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Accounting_Period__c = testData.acctPeriods[1].Id;
            bcr.Billing__c = testData.billings[0].Id;
            bcr.Cash_Receipt__c = testData.cashReceipts[0].Id;
            bcr.Applied_Amount__c = 1;
            bcr.Adjustment_Amount__c = 0.5;
            bcr.Adjustment_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT)?.GL_Account__c;

            DmlException dmlEx;
            try {
                insert bcr;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));

            dmlEx = NULL;
            try {
                bcr.Adjustment_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.REVENUE_GL_ACCOUNT)?.GL_Account__c;//valid bc of relaxed AS rule
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);
        }
    }

    @IsTest
    public static void testGlValidatorForBankDeposit() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankDeposits();

        System.runAs(testData.users[1]) {
            Bank_Deposit__c testBankDeposit = testData.bankDeposits[0];

            DmlException dmlEx;
            try {
                testBankDeposit.Bank_Account__c = testData.glAccounts[1].Id;
                update testBankDeposit;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testGlValidatorForBankReconciliation() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankReconciliations();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Bank_Reconciliation2__c testBankReconciliation = testData.bankReconciliations[0];
            System.assertNotEquals(NULL, testBankReconciliation);

            DmlException dmlEx;
            try {
                TriggerObserver.getInstance().unlockField(Bank_Reconciliation2__c.Bank_Account__c);
                testBankReconciliation.Bank_Account__c = testData.glAccounts[0].Id;
                update testBankReconciliation;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            Test.stopTest();

            System.assertEquals(NULL, dmlEx);
        }
    }

    @IsTest
    public static void testGlValidatorForBillingLine() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            GL_Account__c bankGlAccount = createBankGlAccount();
            GL_Account__c cashFlowCategory = createCashFlowCategory();
            GL_Account__c balanceSheetGLAccount = createBalanceSheetGlAccount();
            GL_Account__c revenueGlAccount = createRevenueGlAccount();

            Billing__c testBilling = new Billing__c(
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Status__c = 'Approved',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = testData.acctPeriods[0].Start_Date__c + 30
            );

            insert testBilling;

            Billing_Line__c testBillingLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 20,
                Rate__c = 10,
                Revenue_GL_Account__c = cashFlowCategory.Id,
                Expense_GL_Account__c = bankGlAccount.Id,
                Inventory_GL_Account__c = bankGlAccount.Id
            );

            Test.startTest();
            DmlException dmlEx;
            try {
                insert testBillingLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));

            testBillingLine.Revenue_GL_Account__c = revenueGlAccount.Id;
            testBillingLine.Expense_GL_Account__c = balanceSheetGLAccount.Id;
            testBillingLine.Inventory_GL_Account__c = balanceSheetGLAccount.Id;
            insert testBillingLine;

            //update section
            GLAccountValidator.cumulativeErrorMessage = NULL;
            testBillingLine.Revenue_GL_Account__c = bankGlAccount.Id;
            testBillingLine.Expense_GL_Account__c = cashFlowCategory.Id;
            testBillingLine.Inventory_GL_Account__c = cashFlowCategory.Id;

            dmlEx = NULL;
            try {
                update testBillingLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            //Check relaxed restriction for GL Accounts populated on Accounting Settings
            GLAccountValidator.cumulativeErrorMessage = NULL;
            testBillingLine.Revenue_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.REVENUE_GL_ACCOUNT)?.GL_Account__c;
            testBillingLine.Expense_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.REVENUE_GL_ACCOUNT)?.GL_Account__c;
            testBillingLine.Inventory_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.REVENUE_GL_ACCOUNT)?.GL_Account__c;

            dmlEx = NULL;
            try {
                update testBillingLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
        }
    }

    @IsTest
    public static void testGlValidatorForRecurringBillingLine() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            GL_Account__c bankGlAccount = createBankGlAccount();
            GL_Account__c cashFlowCategory = createCashFlowCategory();
            GL_Account__c revenueGlAccount = createRevenueGlAccount();

            Recurring_Billing__c testRecBilling = new Recurring_Billing__c(
                Name = 'Custom Recurring Billing',
                Customer__c = testData.accounts[0].Id,
                Next_Billing_Date__c = Date.newInstance(1991, 12, 31),
                Opportunity__c = testData.opportunities[0].Id,
                Billing_Frequency__c = 'Monthly',
                Status__c = 'Active'
            );

            insert testRecBilling;

            Recurring_Billing_Line__c testRecBillingLine = new Recurring_Billing_Line__c(
                Recurring_Billing__c = testRecBilling.Id,
                Quantity__c = 1,
                Rate__c = 1000,
                Revenue_GL_Account__c = cashFlowCategory.Id
            );

            Test.startTest();
            DmlException dmlEx;
            try {
                insert testRecBillingLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));

            testRecBillingLine.Revenue_GL_Account__c = revenueGlAccount.Id;
            insert testRecBillingLine;

            //update section
            GLAccountValidator.cumulativeErrorMessage = NULL;
            testRecBillingLine.Revenue_GL_Account__c = bankGlAccount.Id;

            dmlEx = NULL;
            try {
                update testRecBillingLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            //Check relaxed restriction for GL Accounts populated on Accounting Settings
            GLAccountValidator.cumulativeErrorMessage = NULL;
            testRecBillingLine.Revenue_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.REVENUE_GL_ACCOUNT)?.GL_Account__c;

            dmlEx = NULL;
            try {
                update testRecBillingLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
        }
    }

    @IsTest
    public static void testGlValidatorForRecurringBillingLineRevenueAccount() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            GL_Account__c revenueGlAccount = createRevenueGlAccount();

            Recurring_Billing__c testRecBilling = new Recurring_Billing__c(
                Name = 'Custom Recurring Billing',
                Customer__c = testData.accounts[0].Id,
                Next_Billing_Date__c = Date.newinstance(1991, 12, 31),
                Opportunity__c = testData.opportunities[0].Id,
                Billing_Frequency__c = 'Monthly',
                Status__c = 'Active'
            );

            insert testRecBilling;

            Recurring_Billing_Line__c testRecBillingLine = new Recurring_Billing_Line__c(
                Recurring_Billing__c = testRecBilling.Id,
                Quantity__c = 1,
                Rate__c = 1000,
                Revenue_GL_Account__c = testData.glAccounts[4].Id
            );

            Test.startTest();
            DmlException dmlEx;
            try {
                insert testRecBillingLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));

            testRecBillingLine.Revenue_GL_Account__c = testData.glAccounts[10].Id;
            insert testRecBillingLine;

            //update section
            GLAccountValidator.cumulativeErrorMessage = NULL;
            testRecBillingLine.Revenue_GL_Account__c = testData.glAccounts[4].Id;

            dmlEx = NULL;
            try {
                update testRecBillingLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));
        }
    }
  
@IsTest
    public static void testGlValidatorForRecurringPayableLineExpenseAccount() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            GL_Account__c bankGlAccount = createBankGlAccount();

            Recurring_Account_Payable__c testRecPayable = new Recurring_Account_Payable__c(
                Name = 'Custom Recurring Payable',
                Vendor__c = testData.accounts[0].Id,
                Next_Account_Payable_Date__c = Date.newinstance(1991, 12, 31),
                Account_Payable_Frequency__c = 'Monthly',
                Status__c = 'Active'
            );

            insert testRecPayable;

            Recurring_Account_Payable_Line__c testRecPayableLine = new Recurring_Account_Payable_Line__c(
                Recurring_Account_Payable__c = testRecPayable.Id,
                Quantity__c = 1,
                Amount2__c = 2,
                Expense_GL_Account__c = testData.glAccounts[4].Id
            );

            Test.startTest();
            DmlException dmlEx;
            try {
                insert testRecPayableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));

            testRecPayableLine.Expense_GL_Account__c = testData.glAccounts[22].Id;
            insert testRecPayableLine;

            //update section
            GLAccountValidator.cumulativeErrorMessage = NULL;
            testRecPayableLine.Expense_GL_Account__c = bankGlAccount.Id;

            dmlEx = NULL;
            try {
                update testRecPayableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));
        }
    }
  
  @IsTest
    public static void testGlValidatorForRecurringPayableLine() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            GL_Account__c bankGlAccount = createBankGlAccount();
            GL_Account__c revenueGlAccount = createRevenueGlAccount();

            Recurring_Account_Payable__c testRecPayable = new Recurring_Account_Payable__c(
                Name = 'Test Recurring Billing X',
                Vendor__c = testData.accounts.get(0).Id,
                Next_Account_Payable_Date__c = Date.newInstance(1991, 12, 31),
                Account_Payable_Frequency__c = 'Monthly',
                Status__c = 'Active'
            );

            insert testRecPayable;

            Recurring_Account_Payable_Line__c testRecPayableLine = new Recurring_Account_Payable_Line__c(
                Recurring_Account_Payable__c = testRecPayable.Id,
                Quantity__c = 2,
                Amount2__c = 1000,
                Expense_GL_Account__c = bankGlAccount.Id//WRONG VALUE
            );

            Test.startTest();
            DmlException dmlEx;
            try {
                insert testRecPayableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));

            testRecPayableLine.Expense_GL_Account__c = revenueGlAccount.Id;
            insert testRecPayableLine;

            //update section
            GLAccountValidator.cumulativeErrorMessage = NULL;
            testRecPayableLine.Expense_GL_Account__c = bankGlAccount.Id;//WRONG VALUE

            dmlEx = NULL;
            try {
                update testRecPayableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            //Check relaxed restriction for GL Accounts populated on Accounting Settings
            GLAccountValidator.cumulativeErrorMessage = NULL;
            testRecPayableLine.Expense_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.REVENUE_GL_ACCOUNT)?.GL_Account__c;

            dmlEx = NULL;
            try {
                update testRecPayableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);

            GLAccountValidator.cumulativeErrorMessage = NULL;
            testRecPayableLine.Expense_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.UNAPPLIED_CASH_GL_ACCOUNT)?.GL_Account__c;

            dmlEx = NULL;
            try {
                update testRecPayableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);

            GLAccountValidator.cumulativeErrorMessage = NULL;
            testRecPayableLine.Expense_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.PREPAID_EXPENSE_GL_ACCOUNT)?.GL_Account__c;

            dmlEx = NULL;
            try {
                update testRecPayableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
        }
    }

    @IsTest
    public static void testGlValidatorForCashReceipt() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashFlowCategories(true);

        System.runAs(testData.users[1]) {
            GL_Account__c bankGlAccount = createBankGlAccount();
            GL_Account__c cashFlowCategory = createCashFlowCategory();
            GL_Account__c balanceSheetGLAccount = createBalanceSheetGlAccount();
            GL_Account__c revenueGlAccount = createRevenueGlAccount();

            Cash_Receipt__c testCR = new Cash_Receipt__c(
                Account__c = testData.accounts[0].Id,
                Amount__c = 100,
                Payment_Reference__c = 'xxxxxxx',
                Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                Receipt_Date__c = testData.acctPeriods[1].Start_Date__c,
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = balanceSheetGLAccount.Id,//WRONG VALUE
                Credit_GL_Account__c = cashFlowCategory.Id,//WRONG VALUE
                Cash_Flow_Category__c = balanceSheetGLAccount.Id//WRONG VALUE
            );

            Test.startTest();
            DmlException dmlEx;
            try {
                insert testCR;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));

            testCR.Bank_Account__c = bankGlAccount.Id;
            testCR.Credit_GL_Account__c = revenueGlAccount.Id;
            testCR.Cash_Flow_Category__c = cashFlowCategory.Id;
            insert testCR;

            //unpost Cash Receipt
            AbstractPostHandler postHandler = new CashReceiptPostHandler();
            List<PostResult> postResults = postHandler.unpost(new List<Cash_Receipt__c>{testCR});
            System.assertEquals(true, postResults[0].isSuccess);

            //update section
            GLAccountValidator.cumulativeErrorMessage = NULL;
            testCR.Bank_Account__c = testData.glAccounts[0].Id;
            testCR.Credit_GL_Account__c = bankGlAccount.Id;//WRONG VALUE
            testCR.Cash_Flow_Category__c = revenueGlAccount.Id;//WRONG VALUE

            dmlEx = NULL;
            try {
                CashReceiptActions.isFirstRun = true;
                update testCR;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            //Check relaxed restriction for GL Accounts populated on Accounting Settings
            GLAccountValidator.cumulativeErrorMessage = NULL;
            testCR.Credit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.REVENUE_GL_ACCOUNT)?.GL_Account__c;
            testCR.Cash_Flow_Category__c = cashFlowCategory.Id;

            dmlEx = NULL;
            try {
                CashReceiptActions.isFirstRun = true;
                update testCR;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);

            GLAccountValidator.cumulativeErrorMessage = NULL;
            testCR.Credit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.PREPAID_EXPENSE_GL_ACCOUNT)?.GL_Account__c;
            testCR.Cash_Flow_Category__c = cashFlowCategory.Id;

            dmlEx = NULL;
            try {
                CashReceiptActions.isFirstRun = true;
                update testCR;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
        }
    }

    @IsTest
    public static void testGlValidatorForCashReceiptARControlLimit() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashFlowCategories(true);

        System.runAs(testData.users[1]) {
            GL_Account__c bankGlAccount = createBankGlAccount();
            GL_Account__c cashFlowCategory = createCashFlowCategory();

            Cash_Receipt__c testCR = new Cash_Receipt__c(
                Account__c = testData.accounts[0].Id,
                Amount__c = 100,
                Payment_Reference__c = 'xxxxxxx',
                Status__c = 'Approved',
                Receipt_Date__c = testData.acctPeriods[1].Start_Date__c,
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = bankGlAccount.Id,
                Credit_GL_Account__c = testData.glAccounts[2].Id,//current AR Control GL Account
                Cash_Flow_Category__c = cashFlowCategory.Id
            );

            Test.startTest();
            DmlException dmlEx;
            try {
                insert testCR;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testGlValidatorForPayableLine() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            GL_Account__c bankGlAccount = createBankGlAccount();
            GL_Account__c cashFlowCategory = createCashFlowCategory();
            GL_Account__c balanceSheetGLAccount = createBalanceSheetGlAccount();

            Account_Payable__c testPayable = new Account_Payable__c(
                Payee_Reference__c = 'xxxxx',
                Status__c = 'Approved',
                Payment_Status__c = 'Unpaid',
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Due_Date__c = testData.acctPeriods[0].End_Date__c,
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id
            );

            insert testPayable;

            Account_Payable_Line__c testPayableLine = new Account_Payable_Line__c(
                Account_Payable__c = testPayable.Id,
                Amount__c = 100,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Expense_GL_Account__c = cashFlowCategory.Id
            );

            DmlException dmlEx;
            try {
                insert testPayableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));

            testPayableLine.Expense_GL_Account__c = balanceSheetGLAccount.Id;
            insert testPayableLine;

            //update section
            GLAccountValidator.cumulativeErrorMessage = NULL;
            testPayableLine.Expense_GL_Account__c = bankGlAccount.Id;

            dmlEx = NULL;
            try {
                update testPayableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            //Check relaxed restriction for GL Accounts populated on Accounting Settings
            GLAccountValidator.cumulativeErrorMessage = NULL;
            testPayableLine.Expense_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.REVENUE_GL_ACCOUNT)?.GL_Account__c;

            dmlEx = NULL;
            try {
                update testPayableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);

            GLAccountValidator.cumulativeErrorMessage = NULL;
            testPayableLine.Expense_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT)?.GL_Account__c;

            dmlEx = NULL;
            try {
                update testPayableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);

            GLAccountValidator.cumulativeErrorMessage = NULL;
            testPayableLine.Expense_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.PREPAID_EXPENSE_GL_ACCOUNT)?.GL_Account__c;

            dmlEx = NULL;
            try {
                update testPayableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
        }
    }

    @IsTest
    public static void testGLValidatorForPayableLineError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Accounting_Settings__c settings = AccountingSettingsHandler.getAccountingSettings();
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            Account_Payable__c testPayable = new Account_Payable__c(
                    Payee_Reference__c = 'xxxxx',
                    Status__c = 'Approved',
                    Payment_Status__c = 'Unpaid',
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Due_Date__c = testData.acctPeriods[0].End_Date__c,
                    Vendor__c = testData.accounts[0].Id,
                    Accounting_Period__c = testData.acctPeriods[0].Id
            );
            insert testPayable;

            Account_Payable_Line__c testPayableLine = new Account_Payable_Line__c(
                    Account_Payable__c = testPayable.Id,
                    Amount__c = 100,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c
            );

            DmlException dmlEx;

            try {
                insert testPayableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));

            testPayableLine.Expense_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT)?.GL_Account__c;

            try {
                insert testPayableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testGLValidatorForBillingLineError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Accounting_Settings__c settings = AccountingSettingsHandler.getAccountingSettings();
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            GL_Account__c bankGlAccount = createBankGlAccount();

            Billing__c testBilling = new Billing__c(
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Customer__c = testData.accounts[0].Id,
                    Status__c = 'Approved',
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Billing_Format__c = testData.billingFormats[0].Id,
                    Due_Date2__c = testData.acctPeriods[0].Start_Date__c + 30
            );

            insert testBilling;

            Billing_Line__c testBillingLine = new Billing_Line__c(
                    Billing__c = testBilling.Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Hours_Units__c = 20,
                    Rate__c = 10,
                    Revenue_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT)?.GL_Account__c,
                    Expense_GL_Account__c = bankGlAccount.Id,
                    Inventory_GL_Account__c = bankGlAccount.Id
            );

            DmlException dmlEx;

            try {
                insert testBillingLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));

            testBillingLine.Expense_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;

            try {
                insert testBillingLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testGlValidatorForAmortizationEntry() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            GL_Account__c bankGlAccount = createBankGlAccount();
            Scheduled_Revenue_Expense__c amortizationEntry = new Scheduled_Revenue_Expense__c(
                Name = 'Test Rev X',
                Amount__c = 400,
                Credit_GL_Account__c = bankGlAccount.Id,
                Debit_GL_Account__c = bankGlAccount.Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Status__c = 'Scheduled'
            );

            DmlException dmlEx;
            try {
                insert amortizationEntry;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            //Check relaxed restriction for GL Accounts populated on Accounting Settings
            dmlEx = NULL;
            try {
                amortizationEntry.Credit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.REVENUE_GL_ACCOUNT)?.GL_Account__c;
                amortizationEntry.Debit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.PREPAID_EXPENSE_GL_ACCOUNT)?.GL_Account__c;
                insert amortizationEntry;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
        }
    }

    @IsTest
    public static void testGlValidatorForCashDisbursementOnInsert() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches();

        System.runAs(testData.users[1]) {
            GL_Account__c bankGlAccount = createBankGlAccount();
            GL_Account__c balanceSheetGlAccount = createBalanceSheetGlAccount();

            Cash_Disbursement__c newCashDisbursement = new Cash_Disbursement__c(
                Cash_Disbursement_Batch__c = testData.cashDisbursementBatch[0].Id,
                Disbursement_Date__c = testData.acctPeriods[0].Start_Date__c,
                Type__c = 'Check',
                Amount__c = 10,
                Source__c = 'Payable',
                Bank_Account__c = balanceSheetGlAccount.Id,//WRONG VALUE
                Debit_GL_Account__c = bankGlAccount.Id,//WRONG VALUE
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Status__c = 'Approved',
                Reference__c = 'the reference 0'
            );

            DmlException dmlEx;
            try {
                insert newCashDisbursement;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testGlValidatorSourceManualAPControlForCashDisbursementUpdateError() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches();

        System.runAs(testData.users[1]) {
            GL_Account__c bankGlAccount = createBankGlAccount();
            Accounting_Settings__c settings = AccountingSettingsHandler.getAccountingSettings();
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            Cash_Disbursement__c newCashDisbursement = new Cash_Disbursement__c(
                Cash_Disbursement_Batch__c = testData.cashDisbursementBatch[0].Id,
                Disbursement_Date__c = testData.acctPeriods[0].Start_Date__c,
                Type__c = 'Check',
                Amount__c = 10,
                Source__c = 'Manual',
                Bank_Account__c = bankGlAccount.Id,
                Debit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.PREPAID_EXPENSE_GL_ACCOUNT)?.GL_Account__c,//WRONG VALUE
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Status__c = 'Approved',
                Reference__c = 'the reference 0'
            );
            insert newCashDisbursement;

            DmlException dmlEx;
            try {
                // WRONG VALUE
                newCashDisbursement.Debit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;
                update newCashDisbursement;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testGlValidatorForCashDisbursementOnUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            GL_Account__c bankGlAccount = createBankGlAccount();
            GL_Account__c balanceSheetGlAccount = createBalanceSheetGlAccount();

            Cash_Disbursement__c testCD = testData.cashDisbursements[0];
            testCD.Bank_Account__c = balanceSheetGlAccount.Id;//WRONG VALUE
            testCD.Debit_GL_Account__c = bankGlAccount.Id;//WRONG VALUE

            DmlException dmlEx;
            try {
                update testCD;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            //Check relaxed restriction for GL Accounts populated on Accounting Settings
            GLAccountValidator.cumulativeErrorMessage = NULL;
            testCD.Debit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.REVENUE_GL_ACCOUNT)?.GL_Account__c;
            testCD.Bank_Account__c = bankGlAccount.Id;

            dmlEx = NULL;
            try {
                CashReceiptActions.isFirstRun = true;
                update testCD;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);

            GLAccountValidator.cumulativeErrorMessage = NULL;
            testCD.Debit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.PREPAID_EXPENSE_GL_ACCOUNT)?.GL_Account__c;

            dmlEx = NULL;
            try {
                CashReceiptActions.isFirstRun = true;
                update testCD;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
        }
    }

    @IsTest
    public static void testGlValidatorIgnoreUnusedAccountingSettingField() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {

            Accounting_Settings__c settings = AccountingSettingsHandler.getAccountingSettings();
            settings.Default_Bank_Account__c = testData.glAccounts[0].Id;

            update settings;
            AccountingSettingsHandler.resetAccountingSettings();

            Cash_Disbursement__c testCD = testData.cashDisbursements[0].clone(false);

            DmlException dmlEx;
            try {
                insert testCD;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
        }
    }

    @IsTest
    public static void testGlValidatorForProduct() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            Product2 testProduct = new Product2(
                Name = 'Test Prod X',
                Inventory_GL_Account__c = testData.glAccounts[22].Id,
                Expense_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.REVENUE_GL_ACCOUNT)?.GL_Account__c,//valid bc of relaxed AS rule
                Revenue_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.PREPAID_EXPENSE_GL_ACCOUNT)?.GL_Account__c,//valid bc of relaxed AS rule
                Inventory_Type__c = 'Purchased',
                Inventory_Product__c = true,
                Unit_Cost__c = 100
            );

            DmlException dmlEx;
            try {
                insert testProduct;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx, 'No DML expected');
        }
    }

    @IsTest
    public static void testGlValidatorAccountingSettingsGLAccountsCR() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            GL_Account__c bankGlAccount = createBankGlAccount();
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            Cash_Receipt__c testCR = new Cash_Receipt__c(
                Account__c = testData.accounts[0].Id,
                Amount__c = 100,
                Payment_Reference__c = 'xxxxxxx',
                Status__c = 'Approved',
                Receipt_Date__c = testData.acctPeriods[1].Start_Date__c,
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = bankGlAccount.Id,
                Credit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT)?.GL_Account__c
            );

            checkErrorResultInsert(testCR);
            testCR.Credit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultInsert(testCR);
            testCR.Credit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultInsert(testCR);
            testCR.Credit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultInsert(testCR);
        }
    }

    @IsTest
    public static void testGlValidatorAccountingSettingsGLAccountsBL() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing_Line__c testObj = testData.billingLines[0].clone();
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            testObj.Revenue_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT)?.GL_Account__c;

            checkErrorResultInsert(testObj);
            testObj.Revenue_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultInsert(testObj);
            testObj.Revenue_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultInsert(testObj);
            testObj = testData.billingLines[0].clone();
            testObj.Expense_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultInsert(testObj);
            testObj = testData.billingLines[0].clone();
            testObj.Inventory_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultInsert(testObj);
            testObj = testData.billingLines[0].clone();
            testObj.Revenue_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT)?.GL_Account__c;
            checkSucessResultInsert(testObj);
        }
    }

    @IsTest
    public static void testGlValidatorAccountingSettingsGLAccountsRBL() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringBilling().createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            Recurring_Billing_Line__c testObj = testData.recurringBillingLines[0].clone();
            testObj.Revenue_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT)?.GL_Account__c;

            checkErrorResultInsert(testObj);
            testObj.Revenue_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultInsert(testObj);
            testObj.Revenue_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultInsert(testObj);
        }
    }

    @IsTest
    public static void testGlValidatorAccountingSettingsGLAccountsAPL() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            Account_Payable_Line__c testObj = testData.payableLines[0].clone();
            testObj.Expense_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT)?.GL_Account__c;

            checkErrorResultInsert(testObj);
            testObj.Expense_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultInsert(testObj);
            testObj.Expense_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultInsert(testObj);
        }
    }

    @IsTest
    public static void testGlValidatorAccountingSettingsGLAccountsRAPL() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables().createRecurringAccountPayableLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            Recurring_Account_Payable_Line__c testObj = testData.recurringPayableLines[0].clone();
            testObj.Expense_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT)?.GL_Account__c;

            checkErrorResultInsert(testObj);
            testObj.Expense_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultInsert(testObj);
            testObj.Expense_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultInsert(testObj);
        }
    }

    @IsTest
    public static void testGlValidatorAccountingSettingsGLAccountsBCR() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();

            Billing_Cash_Receipt__c testObj = new Billing_Cash_Receipt__c(
                Cash_Receipt__c = testData.cashReceipts[0].Id,
                Billing__c = testData.billings.get(0).Id,
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Applied_Amount__c = 100
            );
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);

            testObj.Adjustment_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT)?.GL_Account__c;

            checkErrorResultInsert(testObj);
            testObj.Adjustment_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultInsert(testObj);
            testObj.Adjustment_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultInsert(testObj);
            testObj.Adjustment_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultInsert(testObj);
        }
    }

    @IsTest
    public static void testGlValidatorAccountingSettingsGLAccountsCD() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            Cash_Disbursement__c testCD = testData.cashDisbursements[0].clone(true,true);
            testCD.Ledger__c = testData.ledgers.get(0).Id;
            Cash_Disbursement__c[] testCDList = new Cash_Disbursement__c[]{testCD};
            testCD.Debit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultNoInsert(testCDList);

            testCD.Debit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultNoInsert(testCDList);

            //Vouchers_Payable_GL_Account__c allow only for 'Manual' source
            testCD.Debit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultNoInsert(testCDList);

            testCD.Debit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;
            checkSuccessResultNoInsert(testCDList);
            
            //AP_Control_GL_Account__c not allow only for 'Manual' source
            testCD.Source__c = 'Manual';
            testCD.Debit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultNoInsert(testCDList);

            testCD.Debit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT)?.GL_Account__c;
            checkSuccessResultNoInsert(testCDList);
        }
    }

    @IsTest
    public static void testGlValidatorAccountingSettingsGLAccountsPT() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            Project_Task__c testObj = testData.projectTasks[0].clone();
            testObj.Labor_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT)?.GL_Account__c;

            checkErrorResultInsert(testObj);
            testObj.Labor_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultInsert(testObj);
            testObj.Labor_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultInsert(testObj);
            testObj.Labor_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultInsert(testObj);
        }
    }

    @IsTest
    public static void testGlValidatorAccountingSettingsGLAccountsProduct() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            Product2 testObj = testData.products[0].clone();
            testObj.Expense_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT)?.GL_Account__c;

            checkErrorResultInsert(testObj);
            testObj.Expense_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultInsert(testObj);
            testObj.Expense_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultInsert(testObj);
        }
    }

    @IsTest
    public static void testGlValidatorAccountingSettingsGLAccountsSRE() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            Scheduled_Revenue_Expense__c testObj = testData.scheduledRevenues[0].clone();
            testObj.Ledger__c = testData.ledgers.get(0).Id;
            testObj.Credit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT)?.GL_Account__c;

            checkErrorResultInsert(testObj);
            testObj.Credit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultInsert(testObj);
            testObj.Credit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultInsert(testObj);
            testObj.Credit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultInsert(testObj);
        }
    }

    @IsTest
    public static void testGlValidatorAccountingSettingsGLAccountsJE() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            Journal_Entry_Line__c testObj = testData.journalEntryLines[0].clone();
            testObj.GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultInsert(testObj);
        }
    }

    @IsTest
    public static void testGlValidatorAccountingSettingsGLAccountsRJE() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries()
            .createRecurringJournalEntry()
            .createRecurringJournalEntryLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            Recurring_Journal_Entry_Line__c testObj = testData.recurringJournalEntryLines[0].clone();
            testObj.GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT)?.GL_Account__c;
            checkErrorResultInsert(testObj);
        }
    }

    //==========================================================================================

    private static void checkErrorResultInsert(SObject obj) {
        DmlException dmlEx;
        try {
            insert obj;
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }

        System.assertNotEquals(NULL, dmlEx);
        System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));
    }

    private static void checkErrorResultNoInsert(SObject[] objs) {
        GLAccountValidator.validateGlAccountLookups(objs, NULL);
        System.assertNotEquals(NULL, GLAccountValidator.cumulativeErrorMessage);
    }

    private static void checkSuccessResultNoInsert(SObject[] objs) {
        GLAccountValidator.validateGlAccountLookups(objs, NULL);
        System.assertEquals(NULL, GLAccountValidator.cumulativeErrorMessage);
    }

    private static void checkSucessResultInsert(SObject obj) {
        DmlException dmlEx;
        try {
            insert obj;
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }

        System.assertEquals(NULL, dmlEx);
    }

    public static GL_Account__c createBankGlAccount() {
        GL_Account__c bankGlAccount = new GL_Account__c(
            Name = '1000-Cash-2',
            Active__c = true,
            Type__c = 'Balance Sheet',
            Bank__c = true,
            Sub_Type_1__c = 'Assets',
            Sub_Type_2__c = 'Cash'
        );
        insert bankGlAccount;
        return bankGlAccount;
    }

    public static GL_Account__c createCashFlowCategory() {
        GL_Account__c CFGLAccount = new GL_Account__c(
            Name = 'Custom Cash Flow Category',
            Sub_Type_1__c = 'Operating',
            Type__c = 'Cash Flow'
        );
        insert CFGLAccount;
        return CFGLAccount;
    }

    public static GL_Account__c createBalanceSheetGlAccount() {
        GL_Account__c bsGlAccount = new GL_Account__c(
            Name = 'Custom Balance Sheet GL Account',
            Active__c = true,
            Type__c = 'Balance Sheet',
            Sub_Type_1__c = 'Assets',
            Sub_Type_2__c = 'Cash'
        );
        insert bsGlAccount;
        return bsGlAccount;
    }

    public static GL_Account__c createRevenueGlAccount() {
        GL_Account__c revenueGlAccount = new GL_Account__c(
            Name = 'Custom Revenue GL Account',
            Active__c = true,
            Type__c = 'Revenue',
            Sub_Type_1__c = 'Product Revenue',
            Sub_Type_2__c = 'Product Family 1'
        );
        insert revenueGlAccount;
        return revenueGlAccount;
    }

}