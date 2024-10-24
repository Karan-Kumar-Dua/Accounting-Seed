@IsTest
public class ProductPartActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    // Allow add more than 15 Product Parts for Purchased and Manufactured products
    @IsTest
    public static void testValidateProductPartRowsQuantityPositive() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts();

        List<Product_Part__c> productParts = new List<Product_Part__c>();
        for (Integer i = 0; i < 17; i++) {
            Product_Part__c productPart = new Product_Part__c(
                Product__c = testData.products[0].Id,
                Product_Part__c = testData.products[0].Id,
                Quantity__c = i
            );
            productParts.add(productPart);
        }
        insert productParts;

        System.assertEquals(17, [SELECT COUNT() FROM Product_Part__c WHERE Product__c = :testData.products[0].Id]);
    }

    // Restrict add more than 249 Product Parts for Kit products
    @IsTest
    public static void testValidateKitProductPartRowsQuantityNegative() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts();

        System.assertEquals(249, ProductPartActions.KIT_PRODUCT_PART_LIMIT);

        List<Product_Part__c> productParts = new List<Product_Part__c>();
        for (Integer i = 0; i < ProductPartActions.KIT_PRODUCT_PART_LIMIT + 1; i++) {
            Product_Part__c productPart = new Product_Part__c(
                Product__c = testData.products[2].Id,
                Product_Part__c = testData.products[0].Id,
                Quantity__c = i
            );
            productParts.add(productPart);
        }

        DMLException dmlEx;
        try {
            insert productParts;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(ProductPartActions.getKitProductPartLimitError(), dmlEx.getDmlMessage(0));
    }

    @IsTest
        public static void testValidateKitProductPartRowsQuantityMaxPositive() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts();

        System.assertEquals(249, ProductPartActions.KIT_PRODUCT_PART_LIMIT);

        List<Product_Part__c> productParts = new List<Product_Part__c>();
        for (Integer i = 0; i < ProductPartActions.KIT_PRODUCT_PART_LIMIT; i++) {
            Product_Part__c productPart = new Product_Part__c(
                Product__c = testData.products[2].Id,
                Product_Part__c = testData.products[0].Id,
                Quantity__c = i
            );
            productParts.add(productPart);
        }

        DMLException dmlEx;
        try {
            insert productParts;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(NULL, dmlEx);
    }

    // Restrict add more than 5 Product Parts for Kit products Standard Cost
    @IsTest
    public static void testValidateKitProductPartRowsQuantityNegativeStandardCost() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setInventoryValuationStandardCost()
            .createProducts();

        System.assertEquals(5, ProductPartActions.KIT_PRODUCT_PART_LIMIT);

        List<Product_Part__c> productParts = new List<Product_Part__c>();
        for (Integer i = 0; i < ProductPartActions.KIT_PRODUCT_PART_LIMIT + 1; i++) {
            Product_Part__c productPart = new Product_Part__c(
                Product__c = testData.products[2].Id,
                Product_Part__c = testData.products[0].Id,
                Quantity__c = i
            );
            productParts.add(productPart);
        }

        DMLException dmlEx;
        try {
            insert productParts;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(ProductPartActions.getKitProductPartLimitError(), dmlEx.getDmlMessage(0));
    }

    // Restrict add more than 100 Product Parts for Manufactured products
    @IsTest
    public static void testValidateManufacturedProductPartRowsQuantityNegative() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts();

        System.runAs(testData.users.get(1)) {
            Product2 testProduct = new Product2(
                Name = 'Test Manufactured Product',
                Inventory_GL_Account__c = testData.glAccounts[22].Id,
                Expense_GL_Account__c = testData.glAccounts[6].Id,
                Revenue_GL_Account__c = testData.glAccounts[11].Id,
                Inventory_Type__c = 'Manufactured',
                Inventory_Product__c = true,
                Unit_Cost__c = 1000
            );
            insert testProduct;

            List<Product_Part__c> productParts = new List<Product_Part__c>();
            for (Integer i = 0; i < ProductPartActions.MANUFACTURED_PRODUCT_PART_LIMIT + 1; i++) {
                Product_Part__c productPart = new Product_Part__c(
                    Product__c = testProduct.Id,
                    Product_Part__c = testData.products[0].Id,
                    Quantity__c = i
                );
                productParts.add(productPart);
            }

            DmlException dmlEx;
            try {
                insert productParts;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(ProductPartActions.getManufacturedProductPartLimitError(), dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testValidateMasterProductChanges() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts();
        List<Product_Part__c> productParts = new List<Product_Part__c>();
        for (Integer i = 0; i < 5; i++) {
            Product_Part__c productPart = new Product_Part__c(
                Product__c = testData.products[0].Id,
                Product_Part__c = testData.products[0].Id,
                Quantity__c = i
            );
            productParts.add(productPart);
        }
        insert productParts;

        for (Product_Part__c part : productParts) {
            part.Product__c = testData.products[1].Id;
        }

        DMLException dmlEx;

        try {
            update productParts;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(ProductPartActions.PRODUCT_CHANGE_ERROR, dmlEx.getDMLMessage(0));
    }

    @IsTest
    public static void testProductPartNoNullPointerExceptionInsert() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency(); //will throw an exception in case of non-MC org

            System.runAs(testData.users.get(1)) {
                DMLException dmlEx;

                Product_Part__c pp = new Product_Part__c();

                try {
                    insert pp;
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

}