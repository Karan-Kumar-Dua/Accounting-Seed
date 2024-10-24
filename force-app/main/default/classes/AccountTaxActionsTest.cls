@isTest
public class AccountTaxActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    public static testMethod void testAccountTaxInsertNegative() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Account_Tax__c testTax = new Account_Tax__c();
            Boolean successfullyInserted;
            try {
                insert testTax;
                successfullyInserted = true;
            }
            catch (DmlException dmlEx) {
                successfullyInserted = false;
            }

            System.assertEquals(false, successfullyInserted);
        }

    }

    public static testMethod void testAccountTaxInsertPositive() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts();

        System.runAs(testData.users.get(1)) {
            Boolean successfullyInserted;
            try {
                testData.createAccountTaxes();
                successfullyInserted = true;
            }
            catch (DmlException dmlEx) {
                successfullyInserted = false;
            }

            System.assertEquals(true, successfullyInserted);
        }
    }

    public static testMethod void testAccountTaxUpdateNoTaxRateProduct() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts();

        System.runAs(testData.users.get(1)) {
            Boolean successfullyInserted;
            Boolean successfullyUpdated;
            try {
                testData.createAccountTaxes();
                successfullyInserted = true;
            }
            catch (DmlException dmlEx) {
                successfullyInserted = false;
            }

            System.assertEquals(true, successfullyInserted);

            //update
            Account_Tax__c taxForUpdate = testData.accountTaxes[0];
            Product2 newProduct = testData.products[2];
            taxForUpdate.Tax_Rate__c = newProduct.Id;//product without tax rate value
            try {
                update taxForUpdate;
                successfullyUpdated = true;
            }
            catch (DmlException dmlEx) {
                successfullyUpdated = false;
            }

            System.assertEquals(false, successfullyUpdated);
        }
    }

    public static testMethod void testAccountTaxUpdateSalesTaxTypeAndEmptyExpenseGLAccount() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts();

        System.runAs(testData.users.get(1)) {
            Boolean successfullyInserted;
            try {
                testData.createAccountTaxes();
                successfullyInserted = true;
            }
            catch (DmlException dmlEx) {
                successfullyInserted = false;
            }

            System.assertEquals(true, successfullyInserted);

            //create Tax Rate product with empty Expense_GL_Account__c field
            //such Product will be available only for Account Tax record with Tax Type equals to 'Purchase'
            Product2 testTaxRateProduct = testData.products[4];
            testTaxRateProduct.Expense_GL_Account__c = NULL;
            update testTaxRateProduct;

            testTaxRateProduct = [
                SELECT Id, Name, Expense_GL_Account__c, Revenue_GL_Account__c, Accounting_Type__c, Tax_Rate__c
                FROM Product2
                WHERE Id = :testTaxRateProduct.Id LIMIT 1
            ];

            System.assertEquals(NULL, testTaxRateProduct.Expense_GL_Account__c);

            Account_Tax__c testAccountTax = new Account_Tax__c(
                Account__c = testData.accounts[0].Id,
                Tax_Type__c = 'Sales',
                Tax_Rate__c = testTaxRateProduct.Id
            );

            insert testAccountTax;

            //update
            testAccountTax.Tax_Type__c = 'Purchase';

            DmlException dmlEx;
            try {
                update testAccountTax;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(AccountTaxActions.FIELDS_VALIDATION_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    public static testMethod void testAccountTaxUpdatePositive() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts();

        System.runAs(testData.users.get(1)) {
            Boolean successfullyInserted;
            Boolean successfullyUpdated;
            try {
                testData.createAccountTaxes();
                successfullyInserted = true;
            }
            catch (DmlException dmlEx) {
                successfullyInserted = false;
            }

            System.assertEquals(true, successfullyInserted);

            //update
            testData.accountTaxes[0].Tax_Rate__c = testData.products[4].Id;//product with tax rate value
            try {
                update testData.accountTaxes[0];
                successfullyUpdated = true;
            }
            catch (DmlException dmlEx) {
                successfullyUpdated = false;
            }

            System.assertEquals(true, successfullyUpdated);
        }
    }

    @IsTest
    public static void testAccountTaxNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            DMLException dmlEx;
            try {
                Account_Tax__c accTax = new Account_Tax__c();
                insert accTax;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

    @IsTest
    public static void testAccountTaxNoNullPointerExceptionInsert_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency();
            System.runAs(testData.users[1]) {
                DMLException dmlEx;
                try {
                    Account_Tax__c accTax = new Account_Tax__c();
                    insert accTax;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }
                System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip it if MC is not enabled
        }
        catch (Exception ex) {
            throw ex;//MC has been enabled but then test failed
        }
    }

}