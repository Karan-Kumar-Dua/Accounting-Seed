@isTest
public class FinancialCubeTransactionActionsTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    public static void testFinancialCubeTransactionActionsPreventInsertError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createBillings(true);

        System.runAs(testData.users.get(1)) {

            Financial_Cube_Transaction__c fct = [
                SELECT Id, Amount__c, Financial_Cube__c, Transaction__c
                FROM Financial_Cube_Transaction__c
                WHERE Transaction__r.Billing_Line__c = :testData.billingLines[0].Id LIMIT 1
            ];

            Financial_Cube_Transaction__c fctInsert = fct.clone(false, true);

            DMLException dmlEx;
            try {
                insert fctInsert;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(FinancialCubeTransactionActions.INSERT_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @isTest
    public static void testFinancialCubeTransactionActionsPreventInsertSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createBillings(true);

        System.runAs(testData.users.get(1)) {

            Financial_Cube_Transaction__c fct = [
                SELECT Id, Amount__c, Financial_Cube__c, Transaction__c
                FROM Financial_Cube_Transaction__c
                WHERE Transaction__r.Billing_Line__c = :testData.billingLines[0].Id limit 1
            ];

            Financial_Cube_Transaction__c fctInsert = fct.clone(false, true);

            DMLException dmlEx;
            try {
                FinancialCubeTransactionActions.isPreventOverride = true;
                insert fctInsert;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);
        }
    }
    
    @isTest
    public static void testFinancialCubeTransactionActionsPreventUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createBillings(true);

        System.runAs(testData.users.get(1)) {

            Financial_Cube_Transaction__c fct = [
                SELECT Id, Amount__c
                FROM Financial_Cube_Transaction__c
                WHERE Transaction__r.Billing_Line__c = :testData.billingLines[0].Id LIMIT 1
            ];

            fct.Amount__c = fct.Amount__c + 10;

            DMLException dmlEx;
            try {
                update fct;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(FinancialCubeTransactionActions.UPDATE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @isTest
    public static void testFinancialCubeTransactionActionsPreventUpdateOverride() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createBillings(true);

        System.runAs(testData.users.get(1)) {

            Financial_Cube_Transaction__c fct = [
                SELECT Id, Amount__c
                FROM Financial_Cube_Transaction__c
                WHERE Transaction__r.Billing_Line__c = :testData.billingLines[0].Id limit 1
            ];

            fct.Amount__c = fct.Amount__c + 10;

            DMLException dmlEx;
            try {
                FinancialCubeTransactionActions.isPreventOverride = true;
                update fct;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);
        }
    }
    
    @isTest    
    public static void testFinancialCubeTransactionActionsPreventDelete() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createBillings(true);

        System.runAs(testData.users.get(1)) {

            Financial_Cube_Transaction__c fct = [
                SELECT Id, Amount__c
                FROM Financial_Cube_Transaction__c
                WHERE Transaction__r.Billing_Line__c = :testData.billingLines[0].Id LIMIT 1
            ];

            DMLException dmlEx;
            try {
                delete fct;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(FinancialCubeTransactionActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }

    } 
    
    @isTest    
    public static void testFinancialCubeTransactionActionsPreventDeleteOverride() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createBillings(true);

        System.runAs(testData.users.get(1)) {
            Financial_Cube_Transaction__c fct = [
                SELECT Id, Amount__c
                FROM Financial_Cube_Transaction__c
                WHERE Transaction__r.Billing_Line__c = :testData.billingLines[0].Id LIMIT 1
            ];

            DMLException dmlEx;
            try {
                FinancialCubeTransactionActions.isPreventOverride = true;
                delete fct;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);
        }
    }

    @isTest
    public static void testFinancialCubeTransactionCurrencyIsAlwaysLedgerCurrency() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency() //will throw an exception in case of non-MC org
                .setLineLevelPost()
                .createBillings(true);

            System.runAs(testData.users.get(1)) {

                String newCurrency = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrency)) {
                    return;
                }
                String ledgerCurrency = (String) Database.query('SELECT Id, CurrencyIsoCode FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Ledger__c WHERE Id = \'' + String.escapeSingleQuotes(testData.ledgers[0].Id) + '\'')[0].get('CurrencyIsoCode');

                Billing__c newBilling = testData.billings[0].clone();
                newBilling.put('CurrencyIsoCode', newCurrency);
                newBilling.Status__c = 'Approved';
                insert newBilling;

                Billing_Line__c newBillingLine = testData.billingLines[0].clone();
                newBillingLine.Billing__c = newBilling.Id;
                insert newBillingLine;

                ApexPages.StandardController cont = new ApexPages.StandardController([
                    SELECT Id, Date__c, Status__c, Accounting_Period__r.Status__c
                    FROM Billing__c
                    WHERE Id = :newBilling.Id
                ]);

                Test.startTest();
                BillingPostTransaction pbt = new BillingPostTransaction(cont);
                pbt.post();

                Financial_Cube_Transaction__c fct = (Financial_Cube_Transaction__c) Database.query(
                    'SELECT ID, CurrencyIsoCode ' +
                    'FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Financial_Cube_Transaction__c ' +
                    'WHERE ' + GlobalVariables.PACKAGE_QUALIFIER + 'Transaction__r.' + GlobalVariables.PACKAGE_QUALIFIER + 'Billing_Line__c = \'' + String.escapeSingleQuotes(newBillingLine.Id) + '\' LIMIT 1'
                );

                System.assertEquals(ledgerCurrency, fct.get('CurrencyIsoCode'));
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testFinancialCubeTransactionNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            try {
                Financial_Cube_Transaction__c fct = new Financial_Cube_Transaction__c();
                insert fct;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

    @IsTest
    public static void testFinancialCubeTransactionNoNullPointerExceptionInsert_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency();

            System.runAs(testData.users.get(1)) {
                DMLException dmlEx;
                try {
                    Financial_Cube_Transaction__c fct = new Financial_Cube_Transaction__c();
                    insert fct;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }
                System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
            }
        }
        catch (Exception ex) {

        }
    }

}