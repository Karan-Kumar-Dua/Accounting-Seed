@isTest
public class Product2ActionsTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    public static void testPreventUpdateTaxRateProduct_UseCase1() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts();

        Test.startTest();
        Account testAccount = testData.accounts[0];
        Product2 prod = testData.products[0];
        prod.Tax_Rate__c = 10;
        prod.Accounting_Type__c = 'Tax Rate';
        prod.Revenue_GL_Account__c = testData.glAccounts[16].Id;
        update prod;

        Account_Tax__c testAccountTax = new Account_Tax__c(
            Tax_Rate__c = prod.Id,
            Account__c = testAccount.Id
        );
        insert testAccountTax;

        DMLException dmlEx;

        try {
            prod.Tax_Rate__c = NULL;
            update prod;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(Product2Actions.TAX_RATE_BLANK_ERROR, dmlEx.getDmlMessage(0));
    }

    @isTest
    public static void testPreventUpdateTaxRateProduct_UseCase2() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts();

        Test.startTest();
        Account testAccount = testData.accounts[0];
        Product2 prod = testData.products[0];
        prod.Tax_Rate__c = 10;
        prod.Accounting_Type__c = 'Tax Rate';
        prod.Revenue_GL_Account__c = testData.glAccounts[16].Id;
        update prod;

        Account_Tax__c testAccountTax = new Account_Tax__c(
            Tax_Rate__c = prod.Id,
            Account__c = testAccount.Id
        );
        insert testAccountTax;

        DMLException dmlEx;

        try {
            prod.Accounting_Type__c = 'Taxable Product';
            update prod;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(Product2Actions.TAX_TYPE_UPDATE_ERROR, dmlEx.getDmlMessage(0));
    }

    @isTest
    public static void testPreventUpdateTaxRateProduct_UseCase3() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts();

        Test.startTest();
        Account testAccount = testData.accounts[0];
        Product2 prod = testData.products[0];
        prod.Inventory_Type__c = NULL;
        prod.Inventory_Product__c = false;
        prod.Tax_Rate__c = 10;
        prod.Accounting_Type__c = 'Tax Rate';
        prod.Revenue_GL_Account__c = testData.glAccounts[16].Id;
        update prod;

        Account_Tax__c testAccountTax = new Account_Tax__c(
            Tax_Rate__c = prod.Id,
            Account__c = testAccount.Id
        );
        insert testAccountTax;

        DMLException dmlEx;

        try {
            prod.Revenue_GL_Account__c = NULL;
            update prod;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(Product2Actions.REVENUE_GL_ACCOUNT_UPDATE_ERROR, dmlEx.getDmlMessage(0));
    }

    @isTest
    public static void testInsertAccountGLVar1Success() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables();
        Test.startTest();
        Product2 prod = testData.products[0].clone(false,true);
        prod.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;

        DMLException dmlEx;

        try {
            insert prod;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(prod.GL_Account_Variable_1__c,[SELECT Id, GL_Account_Variable_1__c FROM Product2 WHERE Id = :prod.Id].GL_Account_Variable_1__c);
    }

    @isTest
    public static void testInsertAccountGLVar1Error() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables();
        Test.startTest();
        Product2 prod = testData.products[0].clone(false,true);
        prod.GL_Account_Variable_1__c = testData.accountingVariables2[0].Id;

        DMLException dmlEx;

        try {
            insert prod;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(String.format(SObjectActions.TYPE_ERROR, new String[]{'1'}),dmlEx.getDMLMessage(0));
    }

    @isTest
    public static void testUpdateAccountGLVar1Success() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables();
        Test.startTest();
        Product2 prod = testData.products[0].clone(false,true);
        insert prod;
        System.assertEquals(NULL,prod.GL_Account_Variable_2__c);

        prod.GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
        DMLException dmlEx;

        try {
            update prod;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(
            prod.GL_Account_Variable_2__c,
            [SELECT Id, GL_Account_Variable_2__c FROM Product2 WHERE Id = :prod.Id].GL_Account_Variable_2__c
        );
    }

    @isTest
    public static void testUpdateAccountGLVar1Error() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables();
        Test.startTest();
        Product2 prod = testData.products[0].clone(false,true);
        insert prod;
        System.assertEquals(NULL,prod.GL_Account_Variable_2__c);

        prod.GL_Account_Variable_1__c = testData.accountingVariables2[0].Id;
        DMLException dmlEx;

        try {
            update prod;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(String.format(SObjectActions.TYPE_ERROR, new String[]{'1'}),dmlEx.getDMLMessage(0));
    }

    @isTest
    public static void testInsertAccountGLVar2Success() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables();
        Test.startTest();
        Product2 prod = testData.products[0].clone(false,true);
        prod.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;

        DMLException dmlEx;

        try {
            insert prod;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(
            prod.GL_Account_Variable_2__c,
            [SELECT Id, GL_Account_Variable_2__c FROM Product2 WHERE Id = :prod.Id].GL_Account_Variable_2__c
        );
    }

    @isTest
    public static void testInsertAccountGLVar2Error() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables();
        Test.startTest();
        Product2 prod = testData.products[0].clone(false, true);
        prod.GL_Account_Variable_2__c = testData.accountingVariables1[0].Id;

        DMLException dmlEx;

        try {
            insert prod;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(String.format(SObjectActions.TYPE_ERROR, new String[]{'2'}), dmlEx.getDMLMessage(0));
    }

    @isTest
    public static void testUpdateAccountGLVar2Success() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables();
        Test.startTest();

        Product2 prod = testData.products[0].clone(false, true);
        insert prod;
        System.assertEquals(NULL,prod.GL_Account_Variable_2__c);

        prod.GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
        DMLException dmlEx;

        try {
            update prod;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(
            prod.GL_Account_Variable_2__c,
            [SELECT Id, GL_Account_Variable_2__c FROM Product2 WHERE Id = :prod.Id].GL_Account_Variable_2__c
        );
    }

    @isTest
    public static void testUpdateAccountGLVar2Error() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables();
        Test.startTest();
        Product2 prod = testData.products[0].clone(false, true);
        insert prod;
        System.assertEquals(NULL,prod.GL_Account_Variable_2__c);

        prod.GL_Account_Variable_2__c = testData.accountingVariables1[0].Id;
        DMLException dmlEx;

        try {
            update prod;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(String.format(SObjectActions.TYPE_ERROR, new String[]{'2'}), dmlEx.getDMLMessage(0));
    }

    @isTest
    public static void testInsertAccountGLVar3Success() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables();
        Test.startTest();
        Product2 prod = testData.products[0].clone(false, true);
        prod.GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;

        DMLException dmlEx;

        try {
            insert prod;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(
            prod.GL_Account_Variable_3__c,
            [SELECT Id, GL_Account_Variable_3__c FROM Product2 WHERE Id = :prod.Id].GL_Account_Variable_3__c
        );
    }

    @isTest
    public static void testInsertAccountGLVar3Error() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables();
        Test.startTest();
        Product2 prod = testData.products[0].clone(false, true);
        prod.GL_Account_Variable_3__c = testData.accountingVariables1[0].Id;

        DMLException dmlEx;

        try {
            insert prod;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(String.format(SObjectActions.TYPE_ERROR, new String[]{'3'}), dmlEx.getDMLMessage(0));
    }

    @isTest
    public static void testUpdateAccountGLVar3Success() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables();
        Test.startTest();
        Product2 prod = testData.products[0].clone(false, true);
        insert prod;
        System.assertEquals(NULL, prod.GL_Account_Variable_3__c);

        prod.GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
        DMLException dmlEx;

        try {
            update prod;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(
            prod.GL_Account_Variable_3__c,
            [SELECT Id, GL_Account_Variable_3__c FROM Product2 WHERE Id = :prod.Id].GL_Account_Variable_3__c
        );
    }

    @isTest
    public static void testUpdateAccountGLVar3Error() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables();
        Test.startTest();
        Product2 prod = testData.products[0].clone(false,true);
        insert prod;
        System.assertEquals(NULL, prod.GL_Account_Variable_3__c);

        prod.GL_Account_Variable_3__c = testData.accountingVariables1[0].Id;
        DMLException dmlEx;

        try {
            update prod;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(String.format(SObjectActions.TYPE_ERROR, new String[]{'3'}), dmlEx.getDMLMessage(0));
    }

    @isTest
    public static void testInsertAccountGLVar4Success() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables();
        Test.startTest();
        Product2 prod = testData.products[0].clone(false,true);
        prod.GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;

        DMLException dmlEx;

        try {
            insert prod;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(
            prod.GL_Account_Variable_4__c,
            [SELECT Id, GL_Account_Variable_4__c FROM Product2 WHERE Id = :prod.Id].GL_Account_Variable_4__c
        );
    }

    @isTest
    public static void testInsertAccountGLVar4Error() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables();
        Test.startTest();
        Product2 prod = testData.products[0].clone(false, true);
        prod.GL_Account_Variable_4__c = testData.accountingVariables1[0].Id;

        DMLException dmlEx;

        try {
            insert prod;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(String.format(SObjectActions.TYPE_ERROR, new String[]{'4'}), dmlEx.getDMLMessage(0));
    }

    @isTest
    public static void testUpdateAccountGLVar4Success() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables();
        Test.startTest();
        Product2 prod = testData.products[0].clone(false, true);
        insert prod;

        System.assertEquals(NULL, prod.GL_Account_Variable_4__c);

        prod.GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
        DMLException dmlEx;

        try {
            update prod;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(
            prod.GL_Account_Variable_4__c,
            [SELECT Id, GL_Account_Variable_4__c FROM Product2 WHERE Id = :prod.Id].GL_Account_Variable_4__c
        );
    }

    @isTest
    public static void testUpdateAccountGLVar4Error() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables();
        Test.startTest();
        Product2 prod = testData.products[0].clone(false, true);
        insert prod;
        System.assertEquals(NULL, prod.GL_Account_Variable_4__c);

        prod.GL_Account_Variable_4__c = testData.accountingVariables1[0].Id;

        DMLException dmlEx;
        try {
            update prod;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(String.format(SObjectActions.TYPE_ERROR, new String[]{'4'}),dmlEx.getDMLMessage(0));
    }

    @isTest
    public static void testPreventUpdateTypeWithRelatedParts() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts();
        Test.startTest();
        Product_Part__c productPart = new Product_Part__c(
            Product__c = testData.products[0].Id,
            Product_Part__c = testData.products[0].Id,
            Quantity__c = 1
        );
        insert productPart;

        DMLException dmlEx;
        try {
            testData.products[0].Inventory_Type__c = 'Kit';
            update testData.products[0];
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(Product2Actions.TYPE_UPDATE_ERROR, dmlEx.getDmlMessage(0));
    }
}