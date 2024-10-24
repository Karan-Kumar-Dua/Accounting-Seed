@IsTest
public class RecurringAccountPayableLineActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testExpenseGLAccountIsRequiredOnInsert() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables();
        System.runAs(testData.users.get(1)) {
            Recurring_Account_Payable_Line__c payableLine = new Recurring_Account_Payable_Line__c(
                Recurring_Account_Payable__c = testData.recurringPayables[0].Id,
                Amount2__c = 10,
                Quantity__c = 1,
                Expense_GL_Account__c = NULL
            );

            DmlException dmlEx;
            try {
                insert payableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testExpenseGLAccountIsRequiredOnUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables();
        System.runAs(testData.users.get(1)) {
            Recurring_Account_Payable_Line__c recurringAccountPayableLine = new Recurring_Account_Payable_Line__c(
                Recurring_Account_Payable__c = testData.recurringPayables[0].Id,
                Amount2__c = 10,
                Quantity__c= 1,
                Expense_GL_Account__c = testData.glAccounts.get(11).Id
            );

            DmlException dmlEx;
            try {
                insert recurringAccountPayableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);

            recurringAccountPayableLine.Expense_GL_Account__c = NULL;

            try {
                update recurringAccountPayableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testExpenseGLAccountIsAutoPopulatedInventoryProduct() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables().createProducts();
        System.runAs(testData.users.get(1)) {
            Recurring_Account_Payable_Line__c recurringAccountPayableLine = new Recurring_Account_Payable_Line__c(
                    Recurring_Account_Payable__c = testData.recurringPayables[0].Id,
                    Amount2__c = 10,
                    Quantity__c= 1,
                    Product__c = testData.products[0].Id
            );

            DmlException dmlEx;
            try {
                insert recurringAccountPayableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);

            System.assert([SELECT Id, Expense_GL_Account__c FROM Recurring_Account_Payable_Line__c LIMIT 1].Expense_GL_Account__c != null);
        }
    }

    @IsTest
    public static void testExpenseGLAccountIsAutoPopulatedStandardProduct() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables().createProducts();
        System.runAs(testData.users.get(1)) {

            Product2 standardProduct = new Product2(
                    Name = 'Standard Rate',
                    Inventory_GL_Account__c = testData.glAccounts[22].Id,
                    Expense_GL_Account__c = testData.glAccounts[6].Id,
                    Revenue_GL_Account__c = testData.glAccounts[11].Id);
            insert standardProduct;

            Recurring_Account_Payable_Line__c recurringAccountPayableLine = new Recurring_Account_Payable_Line__c(
                    Recurring_Account_Payable__c = testData.recurringPayables[0].Id,
                    Amount2__c = 10,
                    Quantity__c= 1,
                    Product__c = standardProduct.Id
            );

            DmlException dmlEx;
            try {
                insert recurringAccountPayableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);

            System.assert([SELECT Id, Expense_GL_Account__c FROM Recurring_Account_Payable_Line__c LIMIT 1].Expense_GL_Account__c != null);
        }
    }

    @IsTest
    public static void testNormalizeNumericAndCurrencyFieldsInsert() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables();

        System.runAs(testData.users.get(1)) {

            Recurring_Account_Payable_Line__c payableLine = new Recurring_Account_Payable_Line__c(
                Recurring_Account_Payable__c = testData.recurringPayables[0].Id,
                Amount2__c = 20.989342348934,
                Quantity__c= 10.236746723674344,
                Expense_GL_Account__c = testData.glAccounts[11].Id
            );

            insert payableLine;

            Recurring_Account_Payable_Line__c newBillingLine = [
                SELECT Id,
                    Amount2__c,
                    Quantity__c
                FROM Recurring_Account_Payable_Line__c
                WHERE Id = : payableLine.Id];

            System.assertEquals(20.99, newBillingLine.Amount2__c);
            System.assertEquals(10.236747, newBillingLine.Quantity__c);
        }

    }

    @IsTest
    public static void testNormalizeNumericAndCurrencyFieldsUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables().createRecurringAccountPayableLines();

        System.runAs(testData.users.get(1)) {

            testData.recurringPayableLines[0].Amount2__c = 20.989342348934;
            testData.recurringPayableLines[0].Quantity__c = 10.236746723674344;
            testData.recurringPayableLines[0].Unit_Cost__c = NULL;

            update testData.recurringPayableLines[0];

            Recurring_Account_Payable_Line__c newBillingLine = [
                SELECT Id,
                    Amount2__c,
                    Quantity__c
                FROM Recurring_Account_Payable_Line__c
                WHERE Id = : testData.recurringPayableLines[0].Id];

            System.assertEquals(20.99, newBillingLine.Amount2__c);
            System.assertEquals(10.236747, newBillingLine.Quantity__c);
        }

    }

    @IsTest
    public static void testRecurringAccountPayableLineNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            try {
                Recurring_Account_Payable_Line__c rpl = new Recurring_Account_Payable_Line__c();
                insert rpl;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

    @IsTest
    public static void testRecurringAccountPayableLineNoNullPointerExceptionInsert_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency(); //will throw an exception in case of non-MC org

            System.runAs(testData.users.get(1)) {
                DMLException dmlEx;
                try {
                    Recurring_Account_Payable_Line__c rpl = new Recurring_Account_Payable_Line__c();
                    insert rpl;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }
                System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testSetCurrencyFromParent() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createRecurringAccountPayables();
            String newCurrency = SObjectActionsTest.getTheNewCurrencyIsoCode();
            if (String.isBlank(newCurrency)) {
                return;
            }
            String testRPId = testData.recurringPayables[0].Id;
            String parentCurrency = (String) Database.query('SELECT CurrencyIsoCode FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Recurring_Account_Payable__c WHERE Id = :testRPId')[0].get('CurrencyIsoCode');
            System.assertNotEquals(newCurrency, parentCurrency);

            Recurring_Account_Payable_Line__c rpLine = new Recurring_Account_Payable_Line__c(
                Recurring_Account_Payable__c = testData.recurringPayables[0].Id,
                Amount2__c = 20,
                Quantity__c= 10,
                Expense_GL_Account__c = testData.glAccounts[11].Id
            );
            rpLine.put('CurrencyIsoCode', newCurrency);

            insert rpLine;

            String lineId = rpLine.Id;
            String lineCurrencyInsert = (String) Database.query('SELECT CurrencyIsoCode FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Recurring_Account_Payable_Line__c WHERE Id = :lineId')[0].get('CurrencyIsoCode');

            System.assertEquals(parentCurrency, lineCurrencyInsert);

            rpLine.put('CurrencyIsoCode', newCurrency);

            update rpLine;

            String lineCurrencyUpdate = (String) Database.query('SELECT CurrencyIsoCode FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Recurring_Account_Payable_Line__c WHERE Id = :lineId')[0].get('CurrencyIsoCode');

            System.assertEquals(parentCurrency, lineCurrencyUpdate);
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

}