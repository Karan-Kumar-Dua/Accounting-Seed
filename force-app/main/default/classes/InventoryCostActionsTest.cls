@IsTest
private class InventoryCostActionsTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testRequireFields() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts();

        System.runAs(testData.users.get(1)) {
            Inventory_Cost__c ic =  new Inventory_Cost__c(Ledger__c = testData.ledgers[0].Id, Product__c = NULL, Unit_Cost__c = 10);
            DMLException dmlEx;

            try {
                InventoryCostActions.isPreventInsertUpdateOverride = true;
                insert ic;
            }
            catch(DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }
    }


    @isTest
    private static void testPreventInventoryCostDuplicates() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts();

        System.runAs(testData.users.get(1)) {
            Inventory_Cost__c testInventoryCost = new Inventory_Cost__c();
            testInventoryCost.Ledger__c = testData.ledgers[0].Id;
            testInventoryCost.Product__c =  testData.products[0].Id;
            testInventoryCost.Unit_Cost__c = 50;

            InventoryCostActions.isPreventInsertUpdateOverride = true;
            insert testInventoryCost;
            
            Inventory_Cost__c ic = new Inventory_Cost__c(Ledger__c = testData.ledgers[0].Id, Product__c =  testData.products[0].Id, Unit_Cost__c = 10);
            DMLException dmlEx;

            try {
                insert ic;
            }
            catch(DMLException ex) {
                dmlEx = ex;
            }
            InventoryCostActions.isPreventInsertUpdateOverride = false;
            
            System.assertEquals(InventoryCostActions.UNIQUE_KEY_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testInvCostNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            try {
                Inventory_Cost__c invCost = new Inventory_Cost__c();
                insert invCost;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

    @IsTest
    public static void testSetCurrencyIsoCodeToLedgerInsert_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .createProducts()
                .enableMultiCurrency();//will throw an exception in case of non-MC org
            
            System.runAs(testData.users[1]) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }
                Inventory_Cost__c ic = new Inventory_Cost__c(Ledger__c = testData.ledgers[0].Id, Product__c = testData.products[0].Id, Unit_Cost__c = 10);
                ic.put('CurrencyIsoCode', newCurrencyIsoCode);

                Ledger__c ledger;

                InventoryCostActions.isPreventInsertUpdateOverride = true;
                insert ic;

                Id ledgerId = testData.ledgers[0].Id;
                ledger = Database.query('SELECT Id, CurrencyIsoCode FROM Ledger__c WHERE Id = :ledgerId');

                Id icId = ic.Id;
                ic = Database.query('SELECT Id, CurrencyIsoCode FROM Inventory_Cost__c WHERE Id = :icId');

                System.assertNotEquals(null, ic);
                System.assertNotEquals(null, ic.get('CurrencyIsoCode'));
                System.assertEquals(ledger.get('CurrencyIsoCode'), ic.get('CurrencyIsoCode'));
            }
        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testSetCurrencyIsoCodeToLedgerUpdate_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .createProducts()
                .enableMultiCurrency();//will throw an exception in case of non-MC org
            
            System.runAs(testData.users[1]) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }
                Inventory_Cost__c ic = new Inventory_Cost__c(Ledger__c = testData.ledgers[0].Id, Product__c = testData.products[0].Id, Unit_Cost__c = 10);
                Ledger__c ledger;

                InventoryCostActions.isPreventInsertUpdateOverride = true;
                insert ic;

                ic.put('CurrencyIsoCode', newCurrencyIsoCode);
                update ic;
                Id ledgerId = testData.ledgers[0].Id;
                ledger = Database.query('SELECT Id, CurrencyIsoCode FROM Ledger__c WHERE Id = :ledgerId');

                Id icId = ic.Id;
                ic = Database.query('SELECT Id, CurrencyIsoCode FROM Inventory_Cost__c WHERE Id = :icId');

                System.assertNotEquals(null, ic);
                System.assertNotEquals(null, ic.get('CurrencyIsoCode'));
                System.assertEquals(ledger.get('CurrencyIsoCode'), ic.get('CurrencyIsoCode'));
            }
        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
        }
    }
}