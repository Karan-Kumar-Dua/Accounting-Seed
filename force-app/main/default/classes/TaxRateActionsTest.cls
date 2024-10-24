@IsTest
private class TaxRateActionsTest {
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testTaxRateCreateMissingSalesTaxGlAccountError() {
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
            System.assertEquals(TaxGroupActions.TAX_RATE_SALES_TAX_GL_ACCOUNT_MISSING_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    static void testTaxRateCreateMissingPurchaseTaxGlAccountError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Tax_Group__c testTaxGroup = new Tax_Group__c(
                Name = 'TestTaxGroup',
                Tax_Type__c = 'Purchase'
            );

            insert testTaxGroup;

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
        }
    }

    @IsTest
    static void testTaxRateCreateMissingBothSalesAndPurchaseTaxGlAccountsError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Tax_Group__c testTaxGroup = new Tax_Group__c(
                Name = 'TestTaxGroup',
                Tax_Type__c = 'Sales and Purchase'
            );

            insert testTaxGroup;

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
            System.assertEquals(TaxGroupActions.TAX_RATE_SALES_AND_PURCHASE_TAX_GL_ACCOUNT_MISSING_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testTaxRateNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            DMLException dmlEx;
            try {
                Tax_Rate__c tr = new Tax_Rate__c();
                insert tr;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

}