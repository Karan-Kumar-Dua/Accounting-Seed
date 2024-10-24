@IsTest
private class InventoryCostHandlerTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testProcessInventoryCostWithoutExistedInventoryCost () {

        TestDataSuite testData = TestDataSuite.getInstance().createProducts();
        testData.setInventoryValuationAverageCost();

        List<Inventory_Cost__c> inventoryCostsBeforeTest = [SELECT Id FROM Inventory_Cost__c];
        System.assertEquals(0, inventoryCostsBeforeTest.size());

        System.runAs(testData.users.get(1)) {
            List<InventoryCostHandler.InventoryMovement> testDataInventoryMovements = new List<InventoryCostHandler.InventoryMovement>();
            InventoryCostHandler.InventoryMovement testInventoryMovement = new InventoryCostHandler.InventoryMovement();
            testInventoryMovement.productId = testData.products[0].Id;
            testInventoryMovement.ledgerId = testData.ledgers[0].Id;
            testInventoryMovement.invBalQuantity = 0;
            testInventoryMovement.invMovQuantity = 20.0;
            testInventoryMovement.invMovUnitCost = 30.0;

            testDataInventoryMovements.add(testInventoryMovement);

            InventoryCostHandler.upsertInventoryCost(testDataInventoryMovements);

            List<Inventory_Cost__c> inventoryCosts = [SELECT Unit_Cost__c FROM Inventory_Cost__c];
            System.assertEquals(1,inventoryCosts.size());
            System.assertEquals(30, inventoryCosts[0].Unit_Cost__c);
        }
    }

    @isTest
    private static void testProcessInventoryCostWithSameProductAndDiffLedger () {

        TestDataSuite testData = TestDataSuite.getInstance().createProducts();
        testData.setInventoryValuationAverageCost();

        List<Inventory_Cost__c> inventoryCostsBeforeTest = [SELECT Id FROM Inventory_Cost__c];
        System.assertEquals(0, inventoryCostsBeforeTest.size());

        System.runAs(testData.users.get(1)) {
            InventoryCostHandler.InventoryMovement testInventoryMovement = new InventoryCostHandler.InventoryMovement();
            testInventoryMovement.productId = testData.products[0].Id;
            testInventoryMovement.ledgerId = testData.ledgers[0].Id;
            testInventoryMovement.invBalQuantity = 0;
            testInventoryMovement.invMovQuantity = 20.0;
            testInventoryMovement.invMovUnitCost = 30.0;

            InventoryCostHandler.upsertInventoryCost(new List<InventoryCostHandler.InventoryMovement> {testInventoryMovement});

            InventoryCostHandler.InventoryMovement testInventoryMovement2 = new InventoryCostHandler.InventoryMovement();
            testInventoryMovement2.productId = testData.products[0].Id;
            testInventoryMovement2.ledgerId = testData.ledgers[2].Id;
            testInventoryMovement2.invBalQuantity = 0;
            testInventoryMovement2.invMovQuantity = 20.0;
            testInventoryMovement2.invMovUnitCost = 30.0;

            InventoryCostHandler.upsertInventoryCost(new List<InventoryCostHandler.InventoryMovement> {testInventoryMovement2});

            List<Inventory_Cost__c> inventoryCosts = [SELECT Unit_Cost__c FROM Inventory_Cost__c];
            System.assertEquals(2,inventoryCosts.size());
            System.assertEquals(30, inventoryCosts[0].Unit_Cost__c);
        }
    }


    @isTest
    private static void testProcessInventoryCostWithExistedInventoryCost () {

        TestDataSuite testData = TestDataSuite.getInstance().createProducts();
        testData.setInventoryValuationAverageCost();

        System.runAs(testData.users.get(1)) {
            
            Inventory_Cost__c testInventoryCost = new Inventory_Cost__c();
            testInventoryCost.Ledger__c = testData.ledgers[0].Id;
            testInventoryCost.Product__c =  testData.products[0].Id;
            testInventoryCost.Unit_Cost__c = 20;

            InventoryCostActions.isPreventInsertUpdateOverride = true;
            insert testInventoryCost;
            InventoryCostActions.isPreventInsertUpdateOverride = false;
            
            List<InventoryCostHandler.InventoryMovement> testDataInventoryMovements = new List<InventoryCostHandler.InventoryMovement>();
            InventoryCostHandler.InventoryMovement testInventoryMovement = new InventoryCostHandler.InventoryMovement();
            testInventoryMovement.productId = testData.products[0].Id;
            testInventoryMovement.ledgerId = testData.ledgers[0].Id;
            testInventoryMovement.invBalQuantity = 20.0;
            testInventoryMovement.invMovQuantity = 20.0;
            testInventoryMovement.invMovUnitCost = 40.0;

            testDataInventoryMovements.add(testInventoryMovement);
            InventoryCostHandler.upsertInventoryCost(testDataInventoryMovements);
            List<InventoryCostHandler.InventoryCostModel> icm = InventoryCostHandler.getInstance().getUnitCostByProductId(testInventoryMovement.productId);
            System.assertEquals(1,icm.size());
            System.assertEquals(30, icm[0].unitCost.setscale(6,RoundingMode.DOWN));

            List<Inventory_Cost__c> inventoryCosts = [SELECT Unit_Cost__c FROM Inventory_Cost__c];
            System.assertEquals(1,inventoryCosts.size());
            System.assertEquals(30, inventoryCosts[0].Unit_Cost__c);

        }
    }

    @isTest
    private static void testProcessInventoryCostWithExistedInventoryCostConsecutiveMovementsSameProduct () {

        TestDataSuite testData = TestDataSuite.getInstance().createProducts();
        testData.setInventoryValuationAverageCost();

        System.runAs(testData.users.get(1)) {

            Inventory_Cost__c testInventoryCost = new Inventory_Cost__c();
            testInventoryCost.Ledger__c = testData.ledgers[0].Id;
            testInventoryCost.Product__c =  testData.products[0].Id;
            testInventoryCost.Unit_Cost__c = 20;

            InventoryCostActions.isPreventInsertUpdateOverride = true;
            insert testInventoryCost;
            InventoryCostActions.isPreventInsertUpdateOverride = false;

            InventoryCostHandler.InventoryMovement testInventoryMovement = new InventoryCostHandler.InventoryMovement();
            testInventoryMovement.productId = testData.products[0].Id;
            testInventoryMovement.ledgerId = testData.ledgers[0].Id;
            testInventoryMovement.invBalQuantity = 2.0;
            testInventoryMovement.invMovQuantity = 4.0;
            testInventoryMovement.invMovUnitCost = 40.0;

            InventoryCostHandler.upsertInventoryCost(new List<InventoryCostHandler.InventoryMovement>{testInventoryMovement});
            List<InventoryCostHandler.InventoryCostModel> icm = InventoryCostHandler.getInstance().getUnitCostByProductId(testInventoryMovement.productId);
            System.assertEquals(1,icm.size());
            System.assertEquals(33.333333, icm[0].unitCost.setscale(6,RoundingMode.DOWN));

            List<Inventory_Cost__c> inventoryCosts = [SELECT Unit_Cost__c FROM Inventory_Cost__c];
            System.assertEquals(1,inventoryCosts.size());
            System.assertEquals(33.333333, inventoryCosts[0].Unit_Cost__c);

            testInventoryMovement = new InventoryCostHandler.InventoryMovement();
            testInventoryMovement.productId = testData.products[0].Id;
            testInventoryMovement.ledgerId = testData.ledgers[0].Id;
            testInventoryMovement.invBalQuantity = 6.0;
            testInventoryMovement.invMovQuantity = 2.0;
            testInventoryMovement.invMovUnitCost = 30.0;

            InventoryCostHandler.upsertInventoryCost(new List<InventoryCostHandler.InventoryMovement>{testInventoryMovement});
            icm = InventoryCostHandler.getInstance().getUnitCostByProductId(testInventoryMovement.productId);
            System.assertEquals(1,icm.size());
            System.assertEquals(32.5, icm[0].unitCost.setscale(6,RoundingMode.DOWN));
            
            inventoryCosts = [SELECT Unit_Cost__c FROM Inventory_Cost__c];
            System.assertEquals(1,inventoryCosts.size());
            System.assertEquals(32.5, inventoryCosts[0].Unit_Cost__c);

        }
    }
    
    @isTest
    private static void testProcessInventoryCostWithExistedInventoryCostConsecutiveMovementsSameProductZero () {

        TestDataSuite testData = TestDataSuite.getInstance().createProducts();
        testData.setInventoryValuationAverageCost();

        System.runAs(testData.users.get(1)) {

            InventoryCostHandler.InventoryMovement testInventoryMovement = new InventoryCostHandler.InventoryMovement();
            testInventoryMovement.productId = testData.products[0].Id;
            testInventoryMovement.ledgerId = testData.ledgers[0].Id;
            testInventoryMovement.invBalQuantity = 0;
            testInventoryMovement.invMovQuantity = 4.0;
            testInventoryMovement.invMovUnitCost = 40.0;

            InventoryCostHandler.upsertInventoryCost(new List<InventoryCostHandler.InventoryMovement>{testInventoryMovement});
            List<InventoryCostHandler.InventoryCostModel> icm = InventoryCostHandler.getInstance().getUnitCostByProductId(testInventoryMovement.productId);
            System.assertEquals(1,icm.size());
            System.assertEquals(40, icm[0].unitCost.setscale(6,RoundingMode.DOWN));

            List<Inventory_Cost__c> inventoryCosts = [SELECT Unit_Cost__c FROM Inventory_Cost__c];
            System.assertEquals(1,inventoryCosts.size());
            System.assertEquals(40, inventoryCosts[0].Unit_Cost__c);

            testInventoryMovement = new InventoryCostHandler.InventoryMovement();
            testInventoryMovement.productId = testData.products[0].Id;
            testInventoryMovement.ledgerId = testData.ledgers[0].Id;
            testInventoryMovement.invBalQuantity = 4.0;
            testInventoryMovement.invMovQuantity = -4.0;
            testInventoryMovement.invMovUnitCost = 40.0;

            InventoryCostHandler.upsertInventoryCost(new List<InventoryCostHandler.InventoryMovement>{testInventoryMovement});
            icm = InventoryCostHandler.getInstance().getUnitCostByProductId(testInventoryMovement.productId);
            System.assertEquals(1,icm.size());
            System.assertEquals(0, icm[0].unitCost.setscale(6,RoundingMode.DOWN));

            inventoryCosts = [SELECT Unit_Cost__c FROM Inventory_Cost__c];
            System.assertEquals(1,inventoryCosts.size());
            System.assertEquals(0, inventoryCosts[0].Unit_Cost__c);

        }
    }

    @isTest
    private static void testProcessInventoryCostWithExistedInventoryCostNegativeQuantityInventoryCostIsZero() {

        TestDataSuite testData = TestDataSuite.getInstance().createProducts();
        testData.setInventoryValuationAverageCost();

        System.runAs(testData.users.get(1)) {

            Inventory_Cost__c testInventoryCost = new Inventory_Cost__c();
            testInventoryCost.Ledger__c = testData.ledgers[0].Id;
            testInventoryCost.Product__c =  testData.products[0].Id;
            testInventoryCost.Unit_Cost__c = 20;

            InventoryCostActions.isPreventInsertUpdateOverride = true;
            insert testInventoryCost;
            InventoryCostActions.isPreventInsertUpdateOverride = false;

            InventoryCostHandler.InventoryMovement testInventoryMovement = new InventoryCostHandler.InventoryMovement();
            testInventoryMovement.productId = testData.products[0].Id;
            testInventoryMovement.ledgerId = testData.ledgers[0].Id;
            testInventoryMovement.invBalQuantity = 2.0;
            testInventoryMovement.invMovQuantity = 4.0;
            testInventoryMovement.invMovUnitCost = 40.0;

            InventoryCostHandler.upsertInventoryCost(new List<InventoryCostHandler.InventoryMovement>{testInventoryMovement});
            List<InventoryCostHandler.InventoryCostModel> icm = InventoryCostHandler.getInstance().getUnitCostByProductId(testInventoryMovement.productId);
            System.assertEquals(1,icm.size());
            System.assertEquals(33.333333, icm[0].unitCost.setscale(6,RoundingMode.DOWN));

            List<Inventory_Cost__c> inventoryCosts = [SELECT Unit_Cost__c FROM Inventory_Cost__c];
            System.assertEquals(1,inventoryCosts.size());
            System.assertEquals(33.333333, inventoryCosts[0].Unit_Cost__c);

            testInventoryMovement = new InventoryCostHandler.InventoryMovement();
            testInventoryMovement.productId = testData.products[0].Id;
            testInventoryMovement.ledgerId = testData.ledgers[0].Id;
            testInventoryMovement.invBalQuantity = 6.0;
            testInventoryMovement.invMovQuantity = -8.0;
            testInventoryMovement.invMovUnitCost = 30.0;

            InventoryCostHandler.upsertInventoryCost(new List<InventoryCostHandler.InventoryMovement>{testInventoryMovement});
            icm = InventoryCostHandler.getInstance().getUnitCostByProductId(testInventoryMovement.productId);
            System.assertEquals(1,icm.size());
            System.assertEquals(0, icm[0].unitCost.setscale(6,RoundingMode.DOWN));

            inventoryCosts = [SELECT Unit_Cost__c FROM Inventory_Cost__c];
            System.assertEquals(1,inventoryCosts.size());
            System.assertEquals(0, inventoryCosts[0].Unit_Cost__c);

        }
    }

    @isTest
    private static void testProcessInventoryCostWithExistedInventoryCostConsecutiveMovementsSameProductNegativeQuantity() {

        TestDataSuite testData = TestDataSuite.getInstance().createProducts();
        testData.setInventoryValuationAverageCost();

        System.runAs(testData.users.get(1)) {

            Inventory_Cost__c testInventoryCost = new Inventory_Cost__c();
            testInventoryCost.Ledger__c = testData.ledgers[0].Id;
            testInventoryCost.Product__c =  testData.products[0].Id;
            testInventoryCost.Unit_Cost__c = 20;

            InventoryCostActions.isPreventInsertUpdateOverride = true;
            insert testInventoryCost;
            InventoryCostActions.isPreventInsertUpdateOverride = false;

            InventoryCostHandler.InventoryMovement testInventoryMovement = new InventoryCostHandler.InventoryMovement();
            testInventoryMovement.productId = testData.products[0].Id;
            testInventoryMovement.ledgerId = testData.ledgers[0].Id;
            testInventoryMovement.invBalQuantity = 2.0;
            testInventoryMovement.invMovQuantity = 4.0;
            testInventoryMovement.invMovUnitCost = 40.0;

            InventoryCostHandler.upsertInventoryCost(new List<InventoryCostHandler.InventoryMovement>{testInventoryMovement});
            List<InventoryCostHandler.InventoryCostModel> icm = InventoryCostHandler.getInstance().getUnitCostByProductId(testInventoryMovement.productId);
            System.assertEquals(1,icm.size());
            System.assertEquals(33.333333, icm[0].unitCost.setscale(6,RoundingMode.DOWN));

            List<Inventory_Cost__c> inventoryCosts = [SELECT Unit_Cost__c FROM Inventory_Cost__c];
            System.assertEquals(1,inventoryCosts.size());
            System.assertEquals(33.333333, inventoryCosts[0].Unit_Cost__c);

            testInventoryMovement = new InventoryCostHandler.InventoryMovement();
            testInventoryMovement.productId = testData.products[0].Id;
            testInventoryMovement.ledgerId = testData.ledgers[0].Id;
            testInventoryMovement.invBalQuantity = 6.0;
            testInventoryMovement.invMovQuantity = 2.0;
            testInventoryMovement.invMovUnitCost = 30.0;

            InventoryCostHandler.upsertInventoryCost(new List<InventoryCostHandler.InventoryMovement>{testInventoryMovement});
            icm = InventoryCostHandler.getInstance().getUnitCostByProductId(testInventoryMovement.productId);
            System.assertEquals(1,icm.size());
            System.assertEquals(32.5, icm[0].unitCost.setscale(6,RoundingMode.DOWN));

            inventoryCosts = [SELECT Unit_Cost__c FROM Inventory_Cost__c];
            System.assertEquals(1,inventoryCosts.size());
            System.assertEquals(32.5, inventoryCosts[0].Unit_Cost__c);

            testInventoryMovement = new InventoryCostHandler.InventoryMovement();
            testInventoryMovement.productId = testData.products[0].Id;
            testInventoryMovement.ledgerId = testData.ledgers[0].Id;
            testInventoryMovement.invBalQuantity = 8.0;
            testInventoryMovement.invMovQuantity = -2.0;
            testInventoryMovement.invMovUnitCost = 30.0;

            InventoryCostHandler.upsertInventoryCost(new List<InventoryCostHandler.InventoryMovement>{testInventoryMovement});
            icm = InventoryCostHandler.getInstance().getUnitCostByProductId(testInventoryMovement.productId);
            System.assertEquals(1,icm.size());
            System.assertEquals(33.333333, icm[0].unitCost.setscale(6,RoundingMode.DOWN));

            inventoryCosts = [SELECT Unit_Cost__c FROM Inventory_Cost__c];
            System.assertEquals(1,inventoryCosts.size());
            System.assertEquals(33.333333, inventoryCosts[0].Unit_Cost__c);
        }
    }
    
    @isTest
    private static void testProcessInventoryCostIfInventoryValuationIsStandardCost () {

        TestDataSuite testData = TestDataSuite.getInstance().createProducts();
        testData.setInventoryValuationStandardCost();

        System.runAs(testData.users.get(1)) {
            delete [SELECT Id FROM Inventory_Cost__c];
            Decimal prodUnitCost = [SELECT Id, Unit_Cost__c FROM Product2 WHERE Id = :testData.products[0].Id].Unit_Cost__c;

            List<InventoryCostHandler.InventoryMovement> testDataInventoryMovements = new List<InventoryCostHandler.InventoryMovement>();
            InventoryCostHandler.InventoryMovement testInventoryMovement = new InventoryCostHandler.InventoryMovement();
            testInventoryMovement.productId = testData.products[0].Id;
            testInventoryMovement.ledgerId = testData.ledgers[0].Id;
            testInventoryMovement.invBalQuantity = 10.0;
            testInventoryMovement.invMovQuantity = 20.0;
            testInventoryMovement.invMovUnitCost = 30.0;

            testDataInventoryMovements.add(testInventoryMovement);
            InventoryCostHandler.upsertInventoryCost(testDataInventoryMovements);

            List<InventoryCostHandler.InventoryCostModel> icm = InventoryCostHandler.getInstance().getUnitCostByProductId(testInventoryMovement.productId);
            System.assertEquals(1,icm.size());
            System.assertEquals(prodUnitCost, icm[0].unitCost.setscale(6,RoundingMode.DOWN));

            System.assertEquals(0,[SELECT count() FROM Inventory_Cost__c WHERE Product__c = :testData.products[0].Id]);
            //System.assertEquals(prodUnitCost, [SELECT Id, Unit_Cost__c FROM Inventory_Cost__c WHERE Product__c = :testData.products[0].Id].Unit_Cost__c);
        }
    }
    
    @isTest
    private static void testGetUnitCostByProductIdIfInventoryValuationIsStandardCost () {

        TestDataSuite testData = TestDataSuite.getInstance().createProducts();
        testData.setInventoryValuationStandardCost();

        System.runAs(testData.users.get(1)) {

            Map<Id, Product2> productsByIds = new Map<Id, Product2>(testData.products);

            Map<Id, List<InventoryCostHandler.InventoryCostModel>> result = InventoryCostHandler.getInstance().getUnitCostByProductId(productsByIds.keySet());
            System.assertEquals(testData.products.size(), result.size());

            List<InventoryCostHandler.InventoryCostModel> resultIfOne = InventoryCostHandler.getInstance().getUnitCostByProductId(testData.products[0].Id);
            System.assertEquals(100, resultIfOne[0].unitCost);
            InventoryCostHandler.InventoryCost ic = new InventoryCostHandler.InventoryCost(resultIfOne[0],false);
            System.assertEquals(false,InventoryCostHandler.getInstance().isAverageCostEnabled);
            System.assertEquals(String.valueOf(testData.products[0].Id), ic.getInventoryCostKey());
        }

    }

    @isTest
    private static void testGetUnitCostByProductIfInventoryValuationIsAverageCost () {

        TestDataSuite testData = TestDataSuite.getInstance().createProducts();
        testData.setInventoryValuationAverageCost();

        Inventory_Cost__c testInventoryCost = new Inventory_Cost__c();
        testInventoryCost.Ledger__c = testData.ledgers[0].Id;
        testInventoryCost.Product__c =  testData.products[0].Id;
        testInventoryCost.Unit_Cost__c = 50;

        InventoryCostActions.isPreventInsertUpdateOverride = true;
        insert testInventoryCost;
        InventoryCostActions.isPreventInsertUpdateOverride = false;

        System.runAs(testData.users.get(1)) {
            Map<Id, Product2> productsByIds = new Map<Id, Product2>(testData.products);

            Map<Id, List<InventoryCostHandler.InventoryCostModel>> result = InventoryCostHandler.getInstance().getUnitCostByProductId(productsByIds.keySet());
            System.assertEquals(testData.products.size(), result.size());

            List<InventoryCostHandler.InventoryCostModel> resultIfOne = InventoryCostHandler.getInstance().getUnitCostByProductId(testData.products[0].Id);
            System.assertEquals(50, resultIfOne[0].unitCost);
            InventoryCostHandler.InventoryCost ic = new InventoryCostHandler.InventoryCost(resultIfOne[0],true);
            System.assertEquals(String.valueOf(testData.products[0].Id ) + String.valueOf(testData.ledgers[0].Id), ic.getInventoryCostKey());
        }

    }

    @isTest
    private static void testIsAverageCostEnabled () {

        TestDataSuite testData = TestDataSuite.getInstance();
        testData.setInventoryValuationAverageCost();

        System.runAs(testData.users.get(1)) {
            Boolean toAssert  = InventoryCostHandler.getInstance().isAverageCostEnabled;
            System.assertEquals(true, toAssert);
        }
    }

    @isTest
    private static void testIsStandardCostEnabled () {

        TestDataSuite testData = TestDataSuite.getInstance();
        testData.setInventoryValuationStandardCost();

        System.runAs(testData.users.get(1)) {
            Boolean toAssert = InventoryCostHandler.getInstance().isAverageCostEnabled;
            System.assertNotEquals(true, toAssert);
        }
    }

}