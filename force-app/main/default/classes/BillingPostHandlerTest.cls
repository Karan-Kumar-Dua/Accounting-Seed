@IsTest
public class BillingPostHandlerTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    //======================================================================================
    //===================== POST TESTS ===================================================
    //======================================================================================

    @IsTest
    private static void testPurgeUnlockedPostingStatusFieldOnly() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {

            //Put some field into set of unlocked fields just to check it later
            TriggerObserver.getInstance().unlockField(Account.GL_Account_Variable_1__c);
            //create and post records
            testData.createBillings(true);
            //Validate that Posting Status field was removed from the set of unlocked fields after the end of posting routine
            System.assertEquals(false, TriggerObserver.getInstance().isUnlockedField(Billing__c.Status__c));
            //Validate that originally unlocked field is still unlocked
            System.assertEquals(true, TriggerObserver.getInstance().isUnlockedField(Account.GL_Account_Variable_1__c));
        }
    }

    @IsTest
    private static void testPartialPosting() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Billing__c testBilling1 = testData.billings.get(0);
            Billing__c testBilling2 = testData.billings.get(1);

            testBilling1.Status__c = 'In Process';
            update testBilling1;

            Test.startTest();
            AbstractPostHandler postHandler = new BillingPostHandler();
            postHandler.post(new List<Billing__c>{testBilling1, testBilling2});
            Test.stopTest();

            System.assertEquals(1, [SELECT count() FROM Billing__c WHERE Status__c = 'Posted']);
        }
    }
    
    @IsTest
    public static void testPostWithClosedAcctPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            // Test accounting period is closed error
            Billing__c testBilling = testData.billings[0];
            testBilling.Status__c = 'Approved';
            update testBilling;

            AccountingPeriodActions.isFirstRun = false;
            Accounting_Period__c testAcctPeriod = testData.acctPeriods[0];
            testAcctPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testAcctPeriod;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testPostAlreadyPostedRecord() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing__c testBilling = testData.billings[0];
            testBilling.Status__c = 'Approved';
            update testBilling;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            //Confirm posted
            System.assertEquals(true, results[0].isSuccess);

            //try to post the record twice
            postHandler.dispatcher.clearResultsMap();
            List<PostResult> secondResults = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(PostResult.StatusCode.ALREADY_POSTED, secondResults[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testPostNotApprovedBilling() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Billing__c testBilling = testData.billings[0];
            testBilling.Status__c = 'In Process';
            update testBilling;

            Test.startTest();
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            Test.stopTest();

            System.assertEquals(PostResult.StatusCode.STATUS_NOT_APPROVED, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testPostWithoutLines() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing__c testBilling = testData.billings[0];
            testBilling.Status__c = 'Approved';
            update testBilling;
            delete testData.billingLines;
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(PostResult.StatusCode.NO_LINES, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing__c testBilling = testData.billings[0];
            testBilling.Status__c = 'Approved';
            update testBilling;
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, results[0].isSuccess);
        }

    }

    @IsTest
    public static void testPostWithStandardCostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createProducts()
            .createBillings()
            .setInventoryValuationStandardCost()
            .setERPEnabled();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Product2 testProduct = testData.products[0];
            Billing__c testBilling = testData.billings[0];
            Billing_Line__c testBillingLine = testData.billingLines[0];
            testBillingLine.Product__c = testProduct.Id;
            update testBillingLine;
            delete testData.billingLines[1];
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, results.get(0).isSuccess);
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Billing__c WHERE Id = :testBilling.Id].Status__c
            );
            System.assertEquals(
                4, [
                    SELECT count() FROM Transaction__c WHERE Billing_Line__r.Billing__c = :testBilling.Id
                ]
            );
            System.assertEquals(
                0, [
                    SELECT sum(Amount__c) sum
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    GROUP BY Billing_Line__r.Billing__c
                ][0].get('sum')
            );
            System.assertEquals(
                0, [
                    SELECT sum(Units__c) sum
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    GROUP BY Billing_Line__r.Billing__c
                ][0].get('sum')
            );
        }

    }

    @IsTest
    public static void testPostWithStandardCostProductCostingDisabled() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createProducts()
            .createBillings()
            .setInventoryValuationStandardCost()
            .setERPEnabled()
            .disableProductCosting();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Product2 testProduct = testData.products[0];
            Billing__c testBilling = testData.billings[0];
            Billing_Line__c testBillingLine = testData.billingLines[0];
            testBillingLine.Product__c = testProduct.Id;
            update testBillingLine;
            delete testData.billingLines[1];
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, results.get(0).isSuccess);
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Billing__c WHERE Id = :testBilling.Id].Status__c
            );
            System.assertEquals(
                2, [
                SELECT count() FROM Transaction__c WHERE Billing_Line__r.Billing__c = :testBilling.Id
            ]
            );
            System.assertEquals(
                0, [
                    SELECT sum(Amount__c) sum
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    GROUP BY Billing_Line__r.Billing__c
                ][0].get('sum')
            );
            System.assertEquals(
                0, [
                    SELECT sum(Units__c) sum
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    GROUP BY Billing_Line__r.Billing__c
                ][0].get('sum')
            );
        }

    }

    @IsTest
    public static void testBillingStandardCostPostProductKitSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createProducts()
            .createProductParts()
            .createBillings();

        testData.setInventoryValuationStandardCost();
        testData.setERPEnabled();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Product2 kitProduct = testData.products[2];
            Product2 product0 = testData.products[0];
            Product2 product1 = testData.products[1];

            Billing__c testBilling = testData.billings[0];
            testBilling.Status__c = 'Approved';
            update testBilling;

            Billing_Line__c testBillingLine = testData.billingLines[0];
            testBillingLine.Product__c = kitProduct.Id;
            testBillingLine.Hours_Units__c = 1;

            // Set inventory and expense gl account product overrides on billing line.
            // These should NOT override the product gl accounts for kits on the associated transactions
            testBillingLine.Inventory_GL_Account__c = testData.glAccounts[16].Id;
            testBillingLine.Expense_GL_Account__c = testData.glAccounts[7].Id;
            testBillingLine.Product_Unit_Cost__c = 99999;
            update testBillingLine;

            delete testData.billingLines[1];

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});

            System.assertEquals('Posted', [SELECT Status__c FROM Billing__c WHERE Id = :testBilling.Id].Status__c);
            System.assertEquals(6, [SELECT count() FROM Transaction__c WHERE Billing_Line__r.Billing__c = :testBilling.Id]);

            // Validate amount is calculated correctly based on the unit cost and the quantity defined on the product part
            System.assertEquals([
                    SELECT Amount__c
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    AND Product__c = :product0.Id
                    AND Amount__c > 0
                    LIMIT 1
                ].Amount__c,
                (1 * [SELECT Unit_Cost__c FROM Product2 WHERE Id = :product0.Id].Unit_Cost__c)
            );

            System.assertEquals([
                    SELECT Amount__c
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    AND Product__c = :product0.Id
                    AND Amount__c < 0
                    LIMIT 1
                ].Amount__c,
                (-1 * [SELECT Unit_Cost__c FROM Product2 WHERE Id = :product0.Id].Unit_Cost__c)
            );

            // Validate amount is calculated correctly based on the unit cost and the quantity defined on the product part
            System.assertEquals([
                    SELECT Amount__c
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    AND Product__c = :product1.Id
                    AND Amount__c > 0
                    LIMIT 1
                ].Amount__c,
                (1 * [SELECT Unit_Cost__c FROM Product2 WHERE Id = :product1.Id].Unit_Cost__c)
            );

            System.assertEquals([
                    SELECT Amount__c
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    AND Product__c = :product1.Id
                    AND Amount__c < 0
                    LIMIT 1
                ].Amount__c,
                (-1 * [SELECT Unit_Cost__c FROM Product2 WHERE Id = :product1.Id].Unit_Cost__c)
            );

            System.assertEquals(
                testBillingLine.Rate__c,
                Math.abs([
                    SELECT Amount__c
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    AND Product__c = :kitProduct.Id
                    LIMIT 1
                ].Amount__c)
            );

            // Validate inventory and expense gl accounts were correctly used from product record.
            // These should NOT override the product gl accounts for kits.
            System.assertEquals(
                product0.Expense_GL_Account__c, [
                    SELECT Amount__c, GL_Account__c
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    AND Product__c = :product0.Id
                    AND Amount__c > 0
                    LIMIT 1
                ].GL_Account__c
            );

            System.assertEquals(
                product0.Inventory_GL_Account__c, [
                    SELECT Amount__c, GL_Account__r.Name
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    AND Product__c = :product0.Id
                    AND Amount__c < 0
                    LIMIT 1
                ].GL_Account__c
            );

            // Validate inventory and expense gl accounts were correctly used from product record.
            // These should NOT override the product gl accounts for kits.
            System.assertEquals(
                product1.Expense_GL_Account__c, [
                    SELECT Amount__c, GL_Account__r.Name
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    AND Product__c = :product1.Id
                    AND Amount__c > 0
                    LIMIT 1
                ].GL_Account__c
            );

            System.assertEquals(
                product1.Inventory_GL_Account__c, [
                    SELECT Amount__c, GL_Account__r.Name
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    AND Product__c = :product1.Id
                    AND Amount__c < 0
                    LIMIT 1
                ].GL_Account__c
            );

            // Validate gl accounts set correctly for kit product transactions
            System.assertEquals(
                testBillingLine.Revenue_GL_Account__c, [
                    SELECT Amount__c, GL_Account__r.Name
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    AND Product__c = :kitProduct.Id
                    AND Amount__c < 0
                    LIMIT 1
                ].GL_Account__c
            );

            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            System.assertEquals(
                defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT)?.GL_Account__c,
                [SELECT Amount__c, GL_Account__r.Name
                 FROM Transaction__c
                 WHERE Billing_Line__r.Billing__c = :testBilling.Id
                 AND Product__c = :kitProduct.Id
                 AND Amount__c > 0 LIMIT 1
                ].GL_Account__c
            );

            System.assertEquals(
                testBillingLine.Rate__c,
                Math.abs([
                    SELECT Amount__c
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    AND Product__c = :kitProduct.Id LIMIT 1
                ].Amount__c)
            );

            System.assertEquals(
                0, [
                    SELECT sum(Amount__c) sum
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    GROUP BY Billing_Line__r.Billing__c
                ][0].get('sum')
            );
            System.assertEquals(
                0, [
                    SELECT sum(Units__c) sum
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    GROUP BY Billing_Line__r.Billing__c
                ][0].get('sum')
            );
        }

    }

    @IsTest
    public static void testStandardCostPostWithKittenProductsProductPartQuantityGreaterThanOneSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createProducts()
            .createProductParts()
            .createBillings()
            .setInventoryValuationStandardCost()
            .setERPEnabled();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Product2 kitProduct = testData.products[2];
            Product2 product0 = testData.products[0];
            Product2 product1 = testData.products[1];

            Product_Part__c productPart0 = testData.productParts[0];
            Product_Part__c productPart1 = testData.productParts[1];

            Billing__c testBilling = testData.billings[0];
            Billing_Line__c testBillingLine = testData.billingLines[0];
            testBillingLine.Product__c = kitProduct.Id;
            testBillingLine.Hours_Units__c = 1;

            // Set inventory and expense gl account product overrides on billing line.
            // These should NOT override the product gl accounts for kits on the associated transactions
            testBillingLine.Inventory_GL_Account__c = testData.glAccounts[16].Id;
            testBillingLine.Expense_GL_Account__c = testData.glAccounts[7].Id;
            testBillingLine.Product_Unit_Cost__c = 99999;
            update testBillingLine;

            delete testData.billingLines[1];

            productPart0.Quantity__c = 2;
            productPart1.Quantity__c = 3;
            update new List<Product_Part__c>{productPart0, productPart1};

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});

            System.assertEquals(true, results.get(0).isSuccess);
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Billing__c WHERE Id = :testBilling.Id].Status__c
            );
            System.assertEquals(6, [SELECT count() FROM Transaction__c WHERE Billing_Line__r.Billing__c = :testBilling.Id]);

            // Validate amounts are correct. The product unit cost field
            // Validate amount is calculated correctly based on the unit cost and the quantity defined on the product part
            System.assertEquals(
                [
                    SELECT Amount__c
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    AND Product__c = :product0.Id
                    AND Amount__c > 0
                    LIMIT 1
                ].Amount__c,
                (2 * [SELECT Unit_Cost__c FROM Product2 WHERE Id = :product0.Id].Unit_Cost__c)
            );

            System.assertEquals(
                [
                    SELECT Amount__c
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    AND Product__c = :product0.Id
                    AND Amount__c < 0
                    LIMIT 1
                ].Amount__c,
                (-2 * [SELECT Unit_Cost__c FROM Product2 WHERE Id = :product0.Id].Unit_Cost__c)
            );

            // Validate amount is calculated correctly based on the unit cost and the quantity defined on the product part
            System.assertEquals(
                [
                    SELECT Amount__c
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    AND Product__c = :product1.Id
                    AND Amount__c > 0
                    LIMIT 1
                ].Amount__c,
                (3 * [SELECT Unit_Cost__c FROM Product2 WHERE Id = :product1.Id].Unit_Cost__c)
            );

            System.assertEquals(
                [
                    SELECT Amount__c
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    AND Product__c = :product1.Id
                    AND Amount__c < 0
                    LIMIT 1
                ].Amount__c,
                (-3 * [SELECT Unit_Cost__c FROM Product2 WHERE Id = :product1.Id].Unit_Cost__c)
            );

            System.assertEquals(
                testBillingLine.Rate__c,
                Math.abs([
                    SELECT Amount__c
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    AND Product__c = :kitProduct.Id
                    LIMIT 1
                ].Amount__c)
            );

            // Validate inventory and expense gl accounts were correctly used from product record.
            // These should NOT override the product gl accounts for kits.
            System.assertEquals(
                product0.Expense_GL_Account__c,
                [
                    SELECT Amount__c, GL_Account__c
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    AND Product__c = :product0.Id
                    AND Amount__c > 0
                    LIMIT 1
                ].GL_Account__c
            );

            System.assertEquals(
                product0.Inventory_GL_Account__c,
                [
                    SELECT Amount__c, GL_Account__r.Name
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    AND Product__c = :product0.Id
                    AND Amount__c < 0
                    LIMIT 1
                ].GL_Account__c
            );

            // Validate inventory and expense gl accounts were correctly used from product record.
            // These should NOT override the product gl accounts for kits.
            System.assertEquals(
                product1.Expense_GL_Account__c,
                [
                    SELECT Amount__c, GL_Account__r.Name
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    AND Product__c = :product1.Id
                    AND Amount__c > 0
                    LIMIT 1
                ].GL_Account__c
            );

            System.assertEquals(
                product1.Inventory_GL_Account__c,
                [
                    SELECT Amount__c, GL_Account__r.Name
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    AND Product__c = :product1.Id
                    AND Amount__c < 0
                    LIMIT 1
                ].GL_Account__c
            );

            // Validate gl accounts set correctly for kit product transactions
            System.assertEquals(
                testBillingLine.Revenue_GL_Account__c,
                [
                    SELECT Amount__c, GL_Account__r.Name
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    AND Product__c = :kitProduct.Id
                    AND Amount__c < 0
                    LIMIT 1
                ].GL_Account__c
            );
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            System.assertEquals(
                defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT)?.GL_Account__c,
                [
                    SELECT Amount__c, GL_Account__r.Name
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    AND Product__c = :kitProduct.Id
                    AND Amount__c > 0
                    LIMIT 1
                ].GL_Account__c
            );

            System.assertEquals(
                testBillingLine.Rate__c,
                Math.abs(
                    [
                        SELECT Amount__c
                        FROM Transaction__c
                        WHERE Billing_Line__r.Billing__c = :testBilling.Id
                        AND Product__c = :kitProduct.Id
                        LIMIT 1
                    ].Amount__c
                )
            );

            System.assertEquals(
                0, [
                    SELECT sum(Amount__c) sum
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    GROUP BY Billing_Line__r.Billing__c
                ][0].get('sum')
            );
            System.assertEquals(
                0, [
                    SELECT sum(Units__c) sum
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    GROUP BY Billing_Line__r.Billing__c
                ][0].get('sum')
            );
        }

    }

    @IsTest
    public static void testPostStandardCostUnitCostBillingLineSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createProducts()
            .createBillings()
            .setInventoryValuationStandardCost()
            .setERPEnabled();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billingLines[0].Product__c = testData.products[0].Id;
            testData.billingLines[0].Inventory_GL_Account__c = testData.glAccounts[16].Id;
            testData.billingLines[0].Expense_GL_Account__c = testData.glAccounts[7].Id;
            testData.billingLines[0].Product_Unit_Cost__c = 99999;
            update testData.billingLines[0];

            delete testData.billingLines[1];

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<String>{testData.billings[0].Id});

            System.assertEquals(true, results.get(0).isSuccess);
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Billing__c WHERE Id = :testData.billings[0].Id].Status__c
            );
            System.assertEquals(4, [SELECT count() FROM Transaction__c WHERE Billing_Line__r.Billing__c = :testData.billings[0].Id]);
            System.assertEquals(4, [SELECT count() FROM Transaction__c WHERE Product__c = :testData.products[0].Id]);

            // validate gl accounts are set correctly based on overrides for the transaction records
            System.assertEquals(
                1, [
                    SELECT count()
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testData.billings[0].Id
                    AND Product__c = :testData.products[0].Id
                    AND Amount__c < 0
                    AND GL_Account__c = :testData.billingLines[0].Revenue_GL_Account__c
                ]
            );
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            Id arControlId = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT)?.GL_Account__c;
            System.assertEquals(
                1, [
                    SELECT count()
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testData.billings[0].Id
                    AND Product__c = :testData.products[0].Id
                    AND Amount__c > 0
                    AND GL_Account__c = :arControlId
                ]
            );

            System.assertEquals(
                1, [
                    SELECT count()
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testData.billings[0].Id
                    AND Product__c = :testData.products[0].Id
                    AND Amount__c < 0
                    AND GL_Account__c = :[
                        SELECT Id, Inventory_GL_Account__c
                        FROM Billing_Line__c
                        WHERE Id = :testData.billingLines[0].Id
                    ].Inventory_GL_Account__c
                ]
            );

            System.assertEquals(
                1, [
                    SELECT count()
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testData.billings[0].Id
                    AND Product__c = :testData.products[0].Id
                    AND Amount__c > 0
                    AND GL_Account__c = :[
                        SELECT Id, Expense_GL_Account__c
                        FROM Billing_Line__c
                        WHERE Id = :testData.billingLines[0].Id
                    ].Expense_GL_Account__c
                ]
            );

            System.assertEquals(
                (testData.billingLines[0].Hours_Units__c * testData.billingLines[0].Product_Unit_Cost__c),
                Math.abs([
                    SELECT Amount__c
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testData.billings[0].Id
                    AND Product__c = :testData.products[0].Id
                    AND GL_Account__c = :[
                        SELECT Id, Inventory_GL_Account__c
                        FROM Billing_Line__c
                        WHERE Id = :testData.billingLines[0].Id
                    ].Inventory_GL_Account__c LIMIT 1
                ].Amount__c)
            );

            System.assertEquals(
                (testData.billingLines[0].Hours_Units__c * testData.billingLines[0].Product_Unit_Cost__c),
                Math.abs([
                    SELECT Amount__c
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testData.billings[0].Id
                    AND Product__c = :testData.products[0].Id
                    AND GL_Account__c = :[
                        SELECT Id, Expense_GL_Account__c
                        FROM Billing_Line__c
                        WHERE Id = :testData.billingLines[0].Id].Expense_GL_Account__c LIMIT 1
                ].Amount__c)
            );

            System.assertEquals(
                0, [
                    SELECT sum(Amount__c) sum
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testData.billings[0].Id
                    GROUP BY Billing_Line__r.Billing__c
                ][0].get('sum')
            );
            System.assertEquals(
                0, [
                    SELECT sum(Units__c) sum
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testData.billings[0].Id
                    GROUP BY Billing_Line__r.Billing__c
                ][0].get('sum')
            );
        }

    }

    @IsTest
    public static void testPostStandardCostingUnitCostProductSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createProducts()
            .createBillings()
            .setInventoryValuationStandardCost()
            .setERPEnabled();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billingLines[0].Product__c = testData.products[0].Id;
            update testData.billingLines[0];

            delete testData.billingLines[1];

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testData.billings[0]});
            System.assertEquals(true, results.get(0).isSuccess);
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Billing__c WHERE Id = :testData.billings[0].Id].Status__c
            );
            System.assertEquals(4, [SELECT count() FROM Transaction__c WHERE Billing_Line__r.Billing__c = :testData.billings[0].Id]);
            System.assertEquals(0, [SELECT sum(Amount__c) sum FROM Transaction__c WHERE Billing_Line__r.Billing__c = :testData.billings[0].Id GROUP BY Billing_Line__r.Billing__c][0].get('sum'));
            System.assertEquals(0, [SELECT sum(Units__c) sum FROM Transaction__c WHERE Billing_Line__r.Billing__c = :testData.billings[0].Id GROUP BY Billing_Line__r.Billing__c][0].get('sum'));
        }

    }

    @IsTest
    public static void testPostStandardCostingExcludeBillingCreditMemoSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createProducts()
            .createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billingLines[0].Product__c = testData.products[0].Id;
            testData.billingLines[0].Rate__c = -1000;
            update testData.billingLines[0];

            delete testData.billingLines[1];

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testData.billings[0]});

            System.assertEquals(true, results.get(0).isSuccess);
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Billing__c WHERE Id = :testData.billings[0].Id].Status__c
            );
            System.assertEquals(2, [SELECT count() FROM Transaction__c WHERE Billing_Line__r.Billing__c = :testData.billings[0].Id]);
            System.assertEquals(0, [SELECT sum(Amount__c) sum FROM Transaction__c WHERE Billing_Line__r.Billing__c = :testData.billings[0].Id GROUP BY Billing_Line__r.Billing__c][0].get('sum'));
            System.assertEquals(0, [SELECT sum(Units__c) sum FROM Transaction__c WHERE Billing_Line__r.Billing__c = :testData.billings[0].Id GROUP BY Billing_Line__r.Billing__c][0].get('sum'));
        }

    }

    @IsTest
    public static void testPostAverageCostingExcludeInventoryCostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createProducts()
            .createBillings();

        testData.setInventoryValuationAverageCost();
        testData.setERPEnabled();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];

            testData.billingLines[0].Product__c = testData.products[0].Id;
            testData.billingLines[0].Rate__c = 1000;
            update testData.billingLines[0];

            delete testData.billingLines[1];

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testData.billings[0]});

            System.assertEquals('Posted', [SELECT Status__c FROM Billing__c WHERE Id = :testData.billings[0].Id].Status__c);
            System.assertEquals(2, [SELECT count() FROM Transaction__c WHERE Billing_Line__r.Billing__c = :testData.billings[0].Id]);
            System.assertEquals(0, [SELECT sum(Amount__c) sum FROM Transaction__c WHERE Billing_Line__r.Billing__c = :testData.billings[0].Id GROUP BY Billing_Line__r.Billing__c][0].get('sum'));
            System.assertEquals(0, [SELECT sum(Units__c) sum FROM Transaction__c WHERE Billing_Line__r.Billing__c = :testData.billings[0].Id GROUP BY Billing_Line__r.Billing__c][0].get('sum'));
        }

    }

    @IsTest
    public static void testPostBatchLineLimitWithoutStandardCostingError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProducts()
            .createBillings();

        testData.setInventoryValuationStandardCost();
        testData.setERPEnabled();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Billing__c> testBillings = new List<Billing__c>();
            Billing__c firstTestBilling = new Billing__c(
                Id = testData.billings[0].Id,
                Status__c = 'Approved',
                Date__c = testData.billings[0].Date__c
            );
            Billing__c secondTestBilling = new Billing__c(
                Id = testData.billings[1].Id,
                Status__c = 'Approved',
                Date__c = testData.billings[1].Date__c
            );
            testBillings.add(firstTestBilling);
            testBillings.add(secondTestBilling);
            update testBillings;

            List<Billing_Line__c> newLineList = new List<Billing_Line__c>();
            Integer newLinesQuantity = BillingPostHandler.BILLING_LINE_COUNT_NO_PRODUCT_COSTING_LIMIT / 2 + 1;//more than half

            newLineList.addAll(createBillingLines(firstTestBilling.Id, NULL, firstTestBilling.Date__c, newLinesQuantity));
            newLineList.addAll(createBillingLines(secondTestBilling.Id, NULL, secondTestBilling.Date__c, newLinesQuantity));

            BillingLineActions.isBypassGLAccountValidations = true;
            insert newLineList;
            BillingLineActions.isBypassGLAccountValidations = false;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(testBillings);

            String expectedErrorMessage = String.format(
                BillingPostHandler.BILLING_LINE_COUNT_LIMIT_EXCEEDED_ERROR_MESSAGE,
                new List<String>{
                    String.valueOf(BillingPostHandler.BILLING_LINE_COUNT_NO_PRODUCT_COSTING_LIMIT)
                }
            );

            System.assertEquals(expectedErrorMessage, results[0].errors[0].message);
            System.assertEquals(expectedErrorMessage, results[1].errors[0].message);
        }

    }

    @IsTest
    public static void testPostBatchLineLimitWithStandardCostingError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProducts()
            .createBillings();

        testData.setInventoryValuationStandardCost();
        testData.setERPEnabled();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Billing__c> testBillings = new List<Billing__c>();
            Billing__c firstTestBilling = new Billing__c(
                Id = testData.billings[0].Id,
                Status__c = 'Approved',
                Date__c = testData.billings[0].Date__c
            );
            Billing__c secondTestBilling = new Billing__c(
                Id = testData.billings[1].Id,
                Status__c = 'Approved',
                Date__c = testData.billings[1].Date__c
            );
            testBillings.add(firstTestBilling);
            testBillings.add(secondTestBilling);
            update testBillings;

            List<Billing_Line__c> newLineList = new List<Billing_Line__c>();
            Product2 testProduct = testData.products[0];
            Integer newLinesQuantity = BillingPostHandler.BILLING_LINE_COUNT_PRODUCT_COSTING_LIMIT / 2 + 1;//more than half

            newLineList.addAll(createBillingLines(firstTestBilling.Id, testProduct.Id, firstTestBilling.Date__c, newLinesQuantity));
            newLineList.addAll(createBillingLines(secondTestBilling.Id, testProduct.Id, secondTestBilling.Date__c, newLinesQuantity));

            BillingLineActions.isBypassGLAccountValidations = true;
            insert newLineList;
            BillingLineActions.isBypassGLAccountValidations = false;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(testBillings);

            String expectedErrorMessage = String.format(
                BillingPostHandler.BILLING_LINE_COUNT_LIMIT_EXCEEDED_ERROR_MESSAGE,
                new List<String>{
                    String.valueOf(BillingPostHandler.BILLING_LINE_COUNT_PRODUCT_COSTING_LIMIT)
                }
            );

            System.assertEquals(expectedErrorMessage, results[0].errors[0].message);
            System.assertEquals(expectedErrorMessage, results[1].errors[0].message);
        }

    }

    @IsTest
    public static void testPostBatchLineLimitWithStandardCostingAndKittingError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProducts()
            .createBillings();

        testData.setInventoryValuationStandardCost();
        testData.setERPEnabled();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Billing__c> testBillings = new List<Billing__c>();
            Billing__c firstTestBilling = new Billing__c(
                Id = testData.billings[0].Id,
                Status__c = 'Approved',
                Date__c = testData.billings[0].Date__c
            );
            Billing__c secondTestBilling = new Billing__c(
                Id = testData.billings[1].Id,
                Status__c = 'Approved',
                Date__c = testData.billings[1].Date__c
            );
            testBillings.add(firstTestBilling);
            testBillings.add(secondTestBilling);
            update testBillings;

            List<Billing_Line__c> newLineList = new List<Billing_Line__c>();
            Product2 testProduct = testData.products[2];//kitten product
            Integer newLinesQuantity = BillingPostHandler.BILLING_LINE_COUNT_PRODUCT_COSTING_AND_KITTING_LIMIT / 2 + 1;//more than half

            newLineList.addAll(createBillingLines(firstTestBilling.Id, testProduct.Id, firstTestBilling.Date__c, newLinesQuantity));
            newLineList.addAll(createBillingLines(secondTestBilling.Id, testProduct.Id, secondTestBilling.Date__c, newLinesQuantity));

            insert newLineList;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(testBillings);

            String expectedErrorMessage = String.format(
                BillingPostHandler.BILLING_LINE_COUNT_LIMIT_EXCEEDED_ERROR_MESSAGE,
                new List<String>{
                    String.valueOf(BillingPostHandler.BILLING_LINE_COUNT_PRODUCT_COSTING_AND_KITTING_LIMIT)
                }
            );

            System.assertEquals(expectedErrorMessage, results[0].errors[0].message);
            System.assertEquals(expectedErrorMessage, results[1].errors[0].message);
        }

    }

    @IsTest
    public static void testPostBatchLineLimitWithAverageCostingAndKittingError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProducts()
            .createBillings();
        testData.setERPEnabled();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Billing__c> testBillings = new List<Billing__c>();
            Billing__c firstTestBilling = new Billing__c(
                Id = testData.billings[0].Id,
                Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                Date__c = testData.billings[0].Date__c
            );
            Billing__c secondTestBilling = new Billing__c(
                Id = testData.billings[1].Id,
                Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                Date__c = testData.billings[1].Date__c
            );
            testBillings.add(firstTestBilling);
            testBillings.add(secondTestBilling);
            update testBillings;

            List<Billing_Line__c> newLineList = new List<Billing_Line__c>();
            Product2 testProduct = testData.products[2];//kitten product
            Integer newLinesQuantity = BillingPostHandler.BILLING_LINE_COUNT_PRODUCT_COSTING_AND_KITTING_LIMIT / 2 + 1;//more than half

            newLineList.addAll(createBillingLines(firstTestBilling.Id, testProduct.Id, firstTestBilling.Date__c, newLinesQuantity));
            newLineList.addAll(createBillingLines(secondTestBilling.Id, testProduct.Id, secondTestBilling.Date__c, newLinesQuantity));

            BillingLineActions.isBypassGLAccountValidations = true;
            insert newLineList;
            BillingLineActions.isBypassGLAccountValidations = false;

            AbstractPostHandler postHandler = new BillingPostHandler();
            
            List<PostResult> results = postHandler.post(testBillings);
            Test.stopTest();

            String expectedErrorMessage = String.format(
                BillingPostHandler.BILLING_LINE_COUNT_LIMIT_EXCEEDED_ERROR_MESSAGE,
                new List<String>{
                    String.valueOf(BillingPostHandler.BILLING_LINE_COUNT_PRODUCT_COSTING_AND_KITTING_LIMIT)
                }
            );

            System.assertEquals(expectedErrorMessage, results[0].errors[0].message);
            System.assertEquals(expectedErrorMessage, results[1].errors[0].message);
        }

    }

    @IsTest
    public static void testPostZeroTotalSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        
        Billing__c billing = testData.billings[4];
        billing.Status__c = 'Approved';
        update billing;

        System.assertEquals(
            0.0, 
            [SELECT Total__c FROM Billing__c WHERE Id = :billing.Id].Total__c
        );

        System.runAs(testData.users[1]) {
            Test.startTest();
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{billing});
            Test.stopTest();

            System.assertEquals(true, results[0].isSuccess);
        }
    }

    //======================================================================================
    //===================== UNPOST TESTS ===================================================
    //======================================================================================

    @IsTest
    public static void testUnpostWithClosedAcctPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProducts()
            .createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing__c testBilling = testData.billings[0];
            testBilling.Status__c = 'Approved';
            update testBilling;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, results[0].isSuccess);

            AccountingPeriodActions.isFirstRun = false;
            Accounting_Period__c testAcctPeriod = testData.acctPeriods[0];
            testAcctPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testAcctPeriod;

            postHandler.dispatcher.clearResultsMap();
            List<PostResult> secondResults = postHandler.unpost(new List<Billing__c>{testBilling});
            System.assertEquals(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD, secondResults[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testUnpostLineCountLimitError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProducts()
            .createBillings();

        System.runAs(testData.users[1]) {
            List<Billing__c> testBillings;

            Billing__c firstTestBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c + 3,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Status__c = 'Approved',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = System.today() + 30
            );

            Billing__c secondTestBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c + 3,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Status__c = 'Approved',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = System.today() + 30
            );

            Billing__c thirdTestBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c + 3,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Status__c = 'Approved',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = System.today() + 30
            );

            testBillings = new List<Billing__c>{
                firstTestBilling,
                secondTestBilling,
                thirdTestBilling
            };
            insert testBillings;
            Integer newLinesQuantity = BillingPostHandler.BILLING_LINE_COUNT_NO_PRODUCT_COSTING_LIMIT;

            Test.startTest();
            BillingLineActions.isBypassGLAccountValidations = true;
            insert createBillingLines(firstTestBilling.Id, NULL, firstTestBilling.Date__c, newLinesQuantity);//500 of 1000
            insert createBillingLines(secondTestBilling.Id, NULL, secondTestBilling.Date__c, newLinesQuantity);//1000 of 1000
            insert createBillingLines(thirdTestBilling.Id, NULL, thirdTestBilling.Date__c, 1);//1001
            BillingLineActions.isBypassGLAccountValidations = false;

            // mock post billings
            for (Billing__c testBilling : testBillings) {
                testBilling.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED;
            }
            SourceDocumentUpdateFieldValidator.overridePreventUpdateStatusFieldPosted = true;
            update testBillings;

            AbstractPostHandler postHandler = new BillingPostHandler();
            //Actual testing is here ==========================================
            postHandler.dispatcher.clearResultsMap();
            List<PostResult> unpostResults = postHandler.unpost(testBillings);
            //=================================================================
            Test.stopTest();

            String expectedErrorMessage = String.format(
                BillingPostHandler.BILLING_LINE_COUNT_LIMIT_EXCEEDED_ERROR_MESSAGE,
                new List<String>{
                    String.valueOf(BillingPostHandler.UNPOST_BILLING_LINE_COUNT_LIMIT)
                }
            );

            System.assertEquals(expectedErrorMessage, unpostResults[0].errors[0].message);
            System.assertEquals(expectedErrorMessage, unpostResults[1].errors[0].message);
            System.assertEquals(expectedErrorMessage, unpostResults[2].errors[0].message);
        }

    }

    @IsTest
    public static void testUnpostLLPSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createProducts()
            .createBillings(true);

        System.runAs(testData.users[1]) {
            Billing__c testBilling = testData.billings[0];
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.unpost(new List<Billing__c>{testBilling});

            System.assertEquals(true, postResults[0].isSuccess);
            List<Billing_Line__c> testBillingLines = [
                SELECT Id FROM Billing_Line__c WHERE Billing__c = :testBilling.Id
            ];
            System.assertEquals(true, TransactionActions.queryTransactions(testBillingLines).isEmpty());
        }

    }

    @IsTest
    public static void testUnpostHLPSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost();
        Test.startTest();
        testData.createProducts()
            .createBillings(true);

        System.runAs(testData.users[1]) {
            Billing__c testBilling = testData.billings[0];
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.unpost(new List<Billing__c>{testBilling});
            System.assertEquals(true, postResults[0].isSuccess);

            System.assertEquals(true, postResults[0].isSuccess);
            List<Billing_Line__c> testBillingLines = [
                SELECT Id, Billing__c FROM Billing_Line__c WHERE Billing__c = :testBilling.Id
            ];
            System.assertEquals(true, TransactionActions.queryTransactions(testBillingLines, true).isEmpty());
        }

    }

    @IsTest
    public static void testPostHLPAndUnpostLLPSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost();
        Test.startTest();
        testData.createProducts()
            .createBillings(true);

        System.runAs(testData.users[1]) {
            testData.setLineLevelPost();

            Billing__c testBilling = testData.billings[0];
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.unpost(new List<Billing__c>{testBilling});
            System.assertEquals(true, postResults[0].isSuccess);

            System.assertEquals(true, postResults[0].isSuccess);
            List<Billing_Line__c> testBillingLines = [
                SELECT Id, Billing__c FROM Billing_Line__c WHERE Billing__c = :testBilling.Id
            ];
            System.assertEquals(true, TransactionActions.queryTransactions(testBillingLines, true).isEmpty());
        }

    }

    @IsTest
    private static void testProcessDmlExceptions() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            PostResultDispatcher dispatcher = new PostResultDispatcher();
            dispatcher.addPostErrorResult(
                (String) testData.billings[0].Id,
                new PostResult.PostErrorResult(
                    testData.billings[0],
                    PostResult.StatusCode.SYSTEM_EXCEPTION,
                    'error message'
                )
            );

            //since Name field was not queried for the Billing record
            //we expect Id as a Name will be stored in the PostResultDispatcher instance
            System.assertEquals(testData.billings[0].Id, dispatcher.getPostResults().get(0).name);
        }
    }

    @IsTest
    private static void testPostAndCalculateAvalaraTaxesLLP() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost();

        System.runAs(testData.users.get(1)) {
            //Enable Avalara Tax Calculation
            testData.enableAvaTaxCalculation();
            //create taxable product
            Product2 testProduct = new Product2(
                Name = 'Jewelry',
                Expense_GL_Account__c = testData.glAccounts[12].Id,
                Revenue_GL_Account__c = testData.glAccounts[10].Id,
                Accounting_Type__c = 'Taxable Product'
            );
            insert testProduct;

            Billing__c testBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c+3,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Status__c = 'Approved',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = System.today() + 30,
                Billing_Street__c = '999 Billing Street',
                Billing_City__c = 'BillingCity',
                Billing_State__c = 'CA',
                Billing_Country__c = 'US',
                Billing_PostalCode__c = '94104',
                Shipping_Street__c = '888 Shipping Street',
                Shipping_City__c = 'ShippingCity',
                Shipping_State__c = 'CA',
                Shipping_Country__c = 'US',
                Shipping_PostalCode__c = '90100',
                Ledger__c = testData.ledgers[0].Id
            );
            insert testBilling;

            Billing_Line__c testBillingLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 1,
                Product__c = testProduct.Id,
                Rate__c = 1000,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            insert testBillingLine;

            //re-query billing line to have all necessary fields populated
            testBillingLine = [
                SELECT Id, Name, Hours_Units__c, Rate__c
                FROM Billing_Line__c
                WHERE Id = :testBillingLine.Id
            ];

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(testBilling, new List<Billing_Line__c>{testBillingLine}, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Billing__c>{testBilling});
            Test.stopTest();

            System.assertEquals(true, postResults.get(0).isSuccess);

            List<Billing_Line__c> salesTaxLines = [
                SELECT Id, Billing__r.Status__c, Hours_Units__c, Rate__c
                FROM Billing_Line__c
                WHERE Billing__c = :testBilling.Id
                AND Product__c = :AvaTaxHelper.getSalesTaxProductId(testBilling)
            ];

            System.assertNotEquals(true, salesTaxLines.isEmpty(), 'sales tax line has not been created');
            System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, salesTaxLines.get(0).Billing__r.Status__c);
            System.assertEquals(
                testBillingLine.Hours_Units__c * testBillingLine.Rate__c / 10,
                salesTaxLines.get(0).Rate__c
            );
        }
    }

    @IsTest
    private static void testSetLedgerForAvalaraTaxesVirtualLineLLP() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost();

        System.runAs(testData.users.get(1)) {
            //Enable Avalara Tax Calculation
            testData.enableAvaTaxCalculation();
            //create taxable product
            Product2 testProduct = new Product2(
                Name = 'Jewelry',
                Expense_GL_Account__c = testData.glAccounts[12].Id,
                Revenue_GL_Account__c = testData.glAccounts[10].Id,
                Accounting_Type__c = 'Taxable Product'
            );
            insert testProduct;

            Billing__c testBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c+3,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Status__c = 'Approved',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = System.today() + 30,
                Billing_Street__c = '999 Billing Street',
                Billing_City__c = 'BillingCity',
                Billing_State__c = 'CA',
                Billing_Country__c = 'US',
                Billing_PostalCode__c = '94104',
                Shipping_Street__c = '888 Shipping Street',
                Shipping_City__c = 'ShippingCity',
                Shipping_State__c = 'CA',
                Shipping_Country__c = 'US',
                Shipping_PostalCode__c = '90100'
            );
            insert testBilling;

            Billing_Line__c testBillingLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 1,
                Product__c = testProduct.Id,
                Rate__c = 1000,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            insert testBillingLine;

            //re-query billing line to have all necessary fields populated
            testBillingLine = [
                SELECT Id, Name, Hours_Units__c, Rate__c
                FROM Billing_Line__c
                WHERE Id = :testBillingLine.Id
            ];

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(testBilling, new List<Billing_Line__c>{testBillingLine}, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();
            BillingPostHandler postHandler = new BillingPostHandler();
            postHandler.validateBeforePost(new List<Billing__c>{testBilling}, true);

            for (Transaction__c tr : postHandler.getForecastedTransactions()) {
                if (tr.Billing_Line__c == NULL) {
                    System.assertEquals(testData.ledgers[0].Id, tr.Ledger__c);
                }
            }
        }
    }

    @IsTest
    private static void testPostAndCalculateAvalaraTaxesHLP() {
        TestDataSuite testData = TestDataSuite.getInstance().setHeaderLevelPost();

        System.runAs(testData.users.get(1)) {
            //Enable Avalara Tax Calculation
            testData.enableAvaTaxCalculation();
            //create taxable product
            Product2 testProduct = new Product2(
                Name = 'Jewelry',
                Expense_GL_Account__c = testData.glAccounts[12].Id,
                Revenue_GL_Account__c = testData.glAccounts[10].Id,
                Accounting_Type__c = 'Taxable Product'
            );
            insert testProduct;

            Billing__c testBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c+3,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Status__c = 'Approved',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = System.today() + 30,
                Billing_Street__c = '999 Billing Street',
                Billing_City__c = 'BillingCity',
                Billing_State__c = 'CA',
                Billing_Country__c = 'US',
                Billing_PostalCode__c = '94104',
                Shipping_Street__c = '888 Shipping Street',
                Shipping_City__c = 'ShippingCity',
                Shipping_State__c = 'CA',
                Shipping_Country__c = 'US',
                Shipping_PostalCode__c = '90100'
            );
            insert testBilling;

            Billing_Line__c testBillingLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 1,
                Product__c = testProduct.Id,
                Rate__c = 1000,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            insert testBillingLine;

            //re-query billing line to have all necessary fields populated
            testBillingLine = [
                SELECT Id, Name, Hours_Units__c, Rate__c
                FROM Billing_Line__c
                WHERE Id = :testBillingLine.Id
            ];

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(testBilling, new List<Billing_Line__c>{testBillingLine}, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Billing__c>{testBilling});
            Test.stopTest();

            System.assertEquals(true, postResults.get(0).isSuccess);

            Billing_Line__c checkedBLine = [
                SELECT Id, Billing__r.Status__c, Hours_Units__c, Rate__c, Tax_Amount2__c
                FROM Billing_Line__c
                WHERE Id = :testBillingLine.Id
            ];

            System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, checkedBLine.Billing__r.Status__c);
            System.assertEquals(
                checkedBLine.Hours_Units__c * checkedBLine.Rate__c / 10,
                checkedBLine.Tax_Amount2__c
            );
        }
    }

    @IsTest
    private static void testPostAndCalculateAvalaraTaxesHLPLockedRecord() {
        TestDataSuite testData = TestDataSuite.getInstance().setHeaderLevelPost();

        System.runAs(testData.users.get(1)) {
            //Enable Avalara Tax Calculation
            testData.enableAvaTaxCalculation();
            //create taxable product
            Product2 testProduct = new Product2(
                Name = 'Jewelry',
                Expense_GL_Account__c = testData.glAccounts[12].Id,
                Revenue_GL_Account__c = testData.glAccounts[10].Id,
                Accounting_Type__c = 'Taxable Product'
            );
            insert testProduct;

            Billing__c testBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c+3,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Status__c = 'Approved',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = System.today() + 30,
                Billing_Street__c = '999 Billing Street',
                Billing_City__c = 'BillingCity',
                Billing_State__c = 'CA',
                Billing_Country__c = 'US',
                Billing_PostalCode__c = '94104',
                Shipping_Street__c = '888 Shipping Street',
                Shipping_City__c = 'ShippingCity',
                Shipping_State__c = 'CA',
                Shipping_Country__c = 'US',
                Shipping_PostalCode__c = '90100'
            );
            insert testBilling;

            Billing_Line__c testBillingLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 1,
                Product__c = testProduct.Id,
                Rate__c = 1000,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            insert testBillingLine;
            Test.startTest();
            //re-query billing line to have all necessary fields populated
            testBillingLine = [
                SELECT Id, Name, Hours_Units__c, Rate__c
                FROM Billing_Line__c
                WHERE Id = :testBillingLine.Id
            ];

            testBilling.Locked_In_AvaTax__c = true;

            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Billing__c.Locked_In_AvaTax__c});
            update testBilling;
            TriggerObserver.reset();

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(testBilling, new List<Billing_Line__c>{testBillingLine}, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Billing__c>{testBilling});
            Test.stopTest();

            System.assertEquals(true, postResults.get(0).isSuccess);

            Billing_Line__c checkedBLine = [
                SELECT Id, Billing__r.Status__c, Hours_Units__c, Rate__c, Tax_Amount2__c
                FROM Billing_Line__c
                WHERE Id = :testBillingLine.Id
            ];

            System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, checkedBLine.Billing__r.Status__c);

            //since we have billing locked for avalara expected result is 0
            System.assertEquals(0, checkedBLine.Tax_Amount2__c);
        }
    }

    @IsTest
    private static void testPostAndCalculateAvalaraTaxes_NO_SHIPPING_ADDRESS_HLP() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .enableAvaTaxCalculation();

        System.runAs(testData.users.get(1)) {
            //create taxable product
            Product2 testProduct = new Product2(
                Name = 'Jewelry',
                Expense_GL_Account__c = testData.glAccounts[12].Id,
                Revenue_GL_Account__c = testData.glAccounts[10].Id,
                Accounting_Type__c = 'Taxable Product'
            );
            insert testProduct;

            Billing__c testBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c+3,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Status__c = 'Approved',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = System.today() + 30
            );
            insert testBilling;

            Billing_Line__c testBillingLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 1,
                Product__c = testProduct.Id,
                Rate__c = 1000,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            insert testBillingLine;

            //re-query billing line to have all necessary fields populated
            testBillingLine = [
                SELECT Id, Name, Hours_Units__c, Rate__c
                FROM Billing_Line__c
                WHERE Id = :testBillingLine.Id
            ];

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(testBilling, new List<Billing_Line__c>{testBillingLine}, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Billing__c>{testBilling});
            Test.stopTest();

            System.assertEquals(true, postResults.get(0).isSuccess);

            Billing_Line__c checkedBLine = [
                SELECT Id, Billing__r.Status__c, Hours_Units__c, Rate__c, Tax_Amount2__c
                FROM Billing_Line__c
                WHERE Id = :testBillingLine.Id
            ];

            System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, checkedBLine.Billing__r.Status__c);
            // if no address on billing get address from Tax Setting
            System.assertEquals(3, [SELECT count() FROM Transaction__c WHERE Billing__c = :testBilling.Id]);
        }
    }

    @IsTest
    private static void testPostAndCalculateAvalaraTaxesForNonUsdLedgerHLP_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency() //will throw an exception in case of non-MC org
                .enableAvaTaxCalculation();

            System.runAs(testData.users.get(1)) {
                String theNewCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(theNewCurrencyIsoCode)) {
                    return;
                }

                //Create new ledger with foreign currency
                Ledger__c newLedger = testData.ledgers[0].clone(false, true, false, false);
                newLedger.put('Name', 'Actual-Foreign');
                newLedger.put('CurrencyIsoCode', theNewCurrencyIsoCode);
                insert newLedger;

                //create taxable product
                Product2 testProduct = new Product2(
                    Name = 'Jewelry',
                    Expense_GL_Account__c = testData.glAccounts[12].Id,
                    Revenue_GL_Account__c = testData.glAccounts[10].Id,
                    Accounting_Type__c = 'Taxable Product'
                );
                insert testProduct;

                Billing__c testBilling = new Billing__c(
                    Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                    Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c+3,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Customer__c = testData.accounts[0].Id,
                    Status__c = 'Approved',
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Billing_Format__c = testData.billingFormats[0].Id,
                    Due_Date2__c = System.today() + 30,
                    Billing_Street__c = '999 Billing Street',
                    Billing_City__c = 'BillingCity',
                    Billing_State__c = 'CA',
                    Billing_Country__c = 'US',
                    Billing_PostalCode__c = '94104',
                    Shipping_Street__c = '888 Shipping Street',
                    Shipping_City__c = 'ShippingCity',
                    Shipping_State__c = 'CA',
                    Shipping_Country__c = 'US',
                    Shipping_PostalCode__c = '90100',
                    Ledger__c = newLedger.Id
                );
                insert testBilling;

                Billing_Line__c testBillingLine = new Billing_Line__c(
                    Billing__c = testBilling.Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Hours_Units__c = 1,
                    Product__c = testProduct.Id,
                    Rate__c = 1000,
                    Revenue_GL_Account__c = testData.glAccounts[10].Id
                );
                insert testBillingLine;

                //re-query billing line to have all necessary fields populated
                testBillingLine = [
                    SELECT Id, Name, Hours_Units__c, Rate__c
                    FROM Billing_Line__c
                    WHERE Id = :testBillingLine.Id
                ];

                SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                    200,
                    'Complete',
                    testData.getCreateAvaTaxTransactionResponseBody(testBilling, new List<Billing_Line__c>{testBillingLine}, 10),
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );

                Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

                Test.startTest();
                AbstractPostHandler postHandler = new BillingPostHandler();
                List<PostResult> postResults = postHandler.post(new List<Billing__c>{testBilling});
                Test.stopTest();

                System.assertEquals(true, postResults.get(0).isSuccess);

                Billing_Line__c checkedBLine = [
                    SELECT Id, Billing__r.Status__c, Hours_Units__c, Rate__c, Tax_Amount2__c
                    FROM Billing_Line__c
                    WHERE Id = :testBillingLine.Id
                ];

                System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, checkedBLine.Billing__r.Status__c);
                System.assertEquals(0, checkedBLine.Tax_Amount2__c);//b.c. records with non-usd ledgers not supported by AvaTax
                System.assertEquals(2, [SELECT count() FROM Transaction__c WHERE Billing__c = :testBilling.Id]);
                System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Billing__c = :testBilling.Id AND GL_Account__c = :AvaTaxHelper.getAvaTaxGLAccount(testBilling)]);
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    private static void testPostAndCalculateAvalaraTaxesTimeCardVarsHLP() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost();

        System.runAs(testData.users.get(1)) {
            //Enable Avalara Tax Calculation
            testData.enableAvaTaxCalculation();
            //create taxable product
            Product2 testProduct = new Product2(
                Name = 'Jewelry',
                Expense_GL_Account__c = testData.glAccounts[12].Id,
                Revenue_GL_Account__c = testData.glAccounts[10].Id,
                Accounting_Type__c = 'Taxable Product'
            );
            insert testProduct;

            Billing__c testBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c+3,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Status__c = 'Approved',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = System.today() + 30,
                Billing_Street__c = '999 Billing Street',
                Billing_City__c = 'BillingCity',
                Billing_State__c = 'CA',
                Billing_Country__c = 'US',
                Billing_PostalCode__c = '94104',
                Shipping_Street__c = '888 Shipping Street',
                Shipping_City__c = 'ShippingCity',
                Shipping_State__c = 'CA',
                Shipping_Country__c = 'US',
                Shipping_PostalCode__c = '90100',
                Ledger__c = testData.ledgers[0].Id
            );
            insert testBilling;

            //create Time Card Variables
            List<Accounting_Variable__c> tcvs = new List<Accounting_Variable__c>();
            Accounting_Variable__c tcv1 = new Accounting_Variable__c(
                Name = 'TCV-1',
                Active__c = true,
                Type__c = 'Time Card Variable 1'
            );

            List<Billing_Line__c> testBillingLines = new List<Billing_Line__c>();
            Billing_Line__c testBillingLineTCV1 = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 1,
                Product__c = testProduct.Id,
                Rate__c = 1000,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            testBillingLines.add(testBillingLineTCV1);

            Billing_Line__c testBillingLineTCV2 = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 1,
                Product__c = testProduct.Id,
                Rate__c = 1000,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            testBillingLines.add(testBillingLineTCV2);
            insert testBillingLines;
            Test.startTest();

            //re-query billing line to have all necessary fields populated
            testBillingLines = [
                SELECT Id, Name, Hours_Units__c, Rate__c
                FROM Billing_Line__c
                WHERE Id IN :testBillingLines
            ];

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(testBilling, testBillingLines, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Billing__c>{testBilling});
            Test.stopTest();

            System.assertEquals(true, postResults.get(0).isSuccess);

            testBilling = [SELECT Id, Status__c, Ledger__c FROM Billing__c WHERE Id = :testBilling.Id];

            List<Billing_Line__c> checkedBLines = [
                SELECT Id, Billing__r.Status__c, Hours_Units__c, Rate__c, Tax_Amount2__c
                FROM Billing_Line__c
                WHERE Id = :testBillingLines
            ];

            System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, testBilling.Status__c);
            System.assertEquals(
                checkedBLines[0].Hours_Units__c * checkedBLines[0].Rate__c / 10,
                checkedBLines[0].Tax_Amount2__c
            );
            System.assertEquals(
                checkedBLines[1].Hours_Units__c * checkedBLines[1].Rate__c / 10,
                checkedBLines[1].Tax_Amount2__c
            );

            List<Transaction__c> taxTransactions = [
                SELECT Id, Time_Card_Variable_1__c, Time_Card_Variable_2__c
                FROM Transaction__c
                WHERE Billing__c = :testBilling.Id
                AND GL_Account__c = :AvaTaxHelper.getAvaTaxGLAccount(testBilling)
                AND (Time_Card_Variable_1__c != NULL OR Time_Card_Variable_2__c != NULL)
            ];

            System.assertEquals(tcvs.size(), taxTransactions.size());
        }
    }

    @IsTest
    private static void testPostAndCalculateAvalaraTaxesLimitExceeded() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            //Enable Avalara Tax Calculation
            testData.enableAvaTaxCalculation();
            //create taxable product
            Product2 testProduct = new Product2(
                Name = 'Jewelry',
                Expense_GL_Account__c = testData.glAccounts[12].Id,
                Revenue_GL_Account__c = testData.glAccounts[10].Id,
                Accounting_Type__c = 'Taxable Product'
            );
            insert testProduct;

            List<Billing__c> testBillings = new List<Billing__c>();
            List<Billing_Line__c> testBillingLines = new List<Billing_Line__c>();

            for (Integer i = 0; i <= AvaTaxHelper.AVALARA_SELECTED_RECORDS_LIMIT; i++) {
                Billing__c testBilling = new Billing__c(
                    Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                    Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c+3,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Customer__c = testData.accounts[0].Id,
                    Status__c = 'Approved',
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Billing_Format__c = testData.billingFormats[0].Id,
                    Due_Date2__c = System.today() + 30,
                    Billing_Street__c = '999 Billing Street',
                    Billing_City__c = 'BillingCity',
                    Billing_State__c = 'CA',
                    Billing_Country__c = 'US',
                    Billing_PostalCode__c = '94104',
                    Shipping_Street__c = '888 Shipping Street',
                    Shipping_City__c = 'ShippingCity',
                    Shipping_State__c = 'CA',
                    Shipping_Country__c = 'US',
                    Shipping_PostalCode__c = '90100'
                );
                testBillings.add(testBilling);
            }
            insert testBillings;

            for (Integer i = 0; i <= AvaTaxHelper.AVALARA_SELECTED_RECORDS_LIMIT; i++) {
                Billing_Line__c testBillingLine = new Billing_Line__c(
                    Billing__c = testBillings.get(i).Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Hours_Units__c = 1,
                    Product__c = testProduct.Id,
                    Rate__c = 1000,
                    Revenue_GL_Account__c = testData.glAccounts[10].Id
                );
                testBillingLines.add(testBillingLine);
            }
            insert testBillingLines;

            Test.startTest();
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.post(testBillings);

            System.assertEquals(false, postResults.get(0).isSuccess);
            System.assertEquals(AbstractPostHandler.TAX_RECORD_COUNT_LIMIT_EXCEEDED_HELP_TEXT, postResults.get(0).errors.get(0).message);
        }
    }

    @IsTest
    private static void testPostAndCalculateAvalaraTaxesBillingOverApplied_HLP() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .enableAvaTaxCalculation();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            //create taxable product
            Product2 testProduct = new Product2(
                Name = 'Jewelry',
                Expense_GL_Account__c = testData.glAccounts[12].Id,
                Revenue_GL_Account__c = testData.glAccounts[10].Id,
                Accounting_Type__c = 'Taxable Product'
            );
            insert testProduct;

            Billing__c testBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c+3,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Status__c = 'Approved',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = System.today() + 30,
                Billing_Street__c = '999 Billing Street',
                Billing_City__c = 'BillingCity',
                Billing_State__c = 'CA',
                Billing_Country__c = 'US',
                Billing_PostalCode__c = '94104',
                Shipping_Street__c = '888 Shipping Street',
                Shipping_City__c = 'ShippingCity',
                Shipping_State__c = 'CA',
                Shipping_Country__c = 'US',
                Shipping_PostalCode__c = '90100'
            );
            insert testBilling;

            Billing_Line__c testBillingLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 1,
                Product__c = testProduct.Id,
                Rate__c = 10,
                Revenue_GL_Account__c = testData.glAccounts[10].Id,
                Tax_Amount2__c = 200
            );
            insert testBillingLine;

            Billing_Cash_Receipt__c testBCR = new Billing_Cash_Receipt__c(
                Cash_Receipt__c = testData.cashReceipts[0].Id,
                Billing__c = testBilling.Id,
                Accounting_Period__c = testData.acctPeriods[2].Id,
                Applied_Amount__c = 210
            );
            insert testBCR;

            testBillingLine = [SELECT Id, Name, Rate__c, Hours_Units__c, Tax_Amount2__c FROM Billing_Line__c WHERE Id = :testBillingLine.Id LIMIT 1];
            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(testBilling, new List<Billing_Line__c>{testBillingLine}, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            HttpProxy.setMock(xPostCreateOrAdjustTransactionRequestMock);

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Billing__c>{testBilling});
            Test.stopTest();

            System.assertEquals(false, postResults.get(0).isSuccess);
            System.assertEquals(String.format(SObjectActions.OVER_APPLIED_ERROR, new List<String> {'Billing'}), postResults.get(0).errors.get(0).message);
        }
    }

    @IsTest
    private static void testPostAndCalculateAvalaraTaxesBillingOverApplied_LLP() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .setLineLevelPost()
            .createCashReceipts()
            .enableAvaTaxCalculation();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            //create taxable product
            Product2 testProduct = new Product2(
                Name = 'Jewelry',
                Expense_GL_Account__c = testData.glAccounts[12].Id,
                Revenue_GL_Account__c = testData.glAccounts[10].Id,
                Accounting_Type__c = 'Taxable Product'
            );
            insert testProduct;

            Billing__c testBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c+3,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Status__c = 'Approved',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = System.today() + 30,
                Billing_Street__c = '999 Billing Street',
                Billing_City__c = 'BillingCity',
                Billing_State__c = 'CA',
                Billing_Country__c = 'US',
                Billing_PostalCode__c = '94104',
                Shipping_Street__c = '888 Shipping Street',
                Shipping_City__c = 'ShippingCity',
                Shipping_State__c = 'CA',
                Shipping_Country__c = 'US',
                Shipping_PostalCode__c = '90100',
                Ledger__c = testData.ledgers[0].Id
            );
            insert testBilling;

            Billing_Line__c testBillingLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 1,
                Product__c = testProduct.Id,
                Rate__c = 100,//taxable amount
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            insert testBillingLine;

            Billing_Line__c salesTaxBillingLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 1,
                Product__c = AvaTaxHelper.getSalesTaxProductId(testBilling),
                Rate__c = 10,//Tax Calculated
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            insert salesTaxBillingLine;

            Billing_Cash_Receipt__c testBCR = new Billing_Cash_Receipt__c(
                Cash_Receipt__c = testData.cashReceipts[0].Id,
                Billing__c = testBilling.Id,
                Accounting_Period__c = testData.acctPeriods[2].Id,
                Applied_Amount__c = 110//Full Amount application
            );
            insert testBCR;
            Test.stopTest();

            testBillingLine = [SELECT Id, Name, Rate__c, Hours_Units__c, Tax_Amount2__c FROM Billing_Line__c WHERE Id = :testBillingLine.Id LIMIT 1];
            //AvaTax call will give us calculated tax amount using 5% tax rate (which is less then tax rate used for salesTaxBillingLine)
            //So we expect over-application error b/c new tax amount is less then prior
            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(testBilling, new List<Billing_Line__c>{testBillingLine}, 5),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Billing__c>{testBilling});
            

            System.assertEquals(false, postResults.get(0).isSuccess);
            System.assertEquals(AbstractPostHandler.BALANCE_OVERAPPLIED_HELP_TEXT, postResults.get(0).errors.get(0).message);
        }
    }

    //===================== Header Level Posting ===========================================

    @isTest
    private static void testBillingHeaderLevelPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost()
            .createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testData.billings.get(0)});

            System.assertEquals(true, results[0].isSuccess, (results[0].errors != NULL && !results[0].errors.isEmpty() ? results[0].errors[0].message : 'Billing has been posted'));

            System.assertEquals(
                2,
            [SELECT COUNT() FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id]
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Billing__c WHERE Id = :testData.billings.get(0).Id].Status__c
            );

            System.assertEquals(
                450,
                [SELECT Amount__c FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id][0].Amount__c
            );

            System.assertEquals(
                -450,
                [SELECT Amount__c FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id][1].Amount__c
            );
        }
    }

    @isTest
    private static void testBillingHeaderLevelPostRounding() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost();
        Test.startTest();
        testData.createBillings();

            //half up rounding scale of 2 will round to 1.24
            testData.billingLines.get(0).Hours_Units__c = 1;
            testData.billingLines.get(0).Rate__c = 1.244;
            update testData.billingLines.get(0);

            //half up rounding scale of 2 will round to 1.25
            testData.billingLines.get(1).Hours_Units__c = 1;
            testData.billingLines.get(1).Rate__c = 1.245;
            update testData.billingLines.get(1);
            

        System.runAs(testData.users.get(1)) {
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testData.billings.get(0)});
            Test.stopTest();

            System.assertEquals(true, results[0].isSuccess, (results[0].errors != NULL && !results[0].errors.isEmpty() ? results[0].errors[0].message : 'Billing has been posted'));
            System.assertEquals(
                2.49,
                [SELECT Amount__c FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id][0].Amount__c
            );
        }
    }

    @IsTest
    private static void testBillingHeaderLevelBatchPosting() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings().setHeaderLevelPost();

        System.runAs(testData.users.get(1)) {
            Billing__c testBill1 = testData.billings.get(0);
            Billing__c testBill2 = testData.billings.get(1);
            

            Test.startTest();
            AbstractPostHandler postHandler = new BillingPostHandler();
            postHandler.post(new List<Billing__c>{testBill1, testBill2});
            Test.stopTest();

            System.assertEquals(2, [SELECT count() FROM Billing__c WHERE Status__c = 'Posted']);
            System.assertEquals(
                2,
            [SELECT COUNT() FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id]
            );

            System.assertEquals(
                2,
            [SELECT COUNT() FROM Transaction__c WHERE Billing__c = :testData.billings.get(1).Id]
            );
        }
    }

    @isTest
    private static void testBillingHeaderLevelPostSeparateTransactionsByProduct() {
        TestDataSuite testData = TestDataSuite.getInstance().setHeaderLevelPost().createBillings().createProducts();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.billingLines.get(0).Product__c = testData.products[0].Id;
            update testData.billingLines.get(0);

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testData.billings.get(0)});

            System.assertEquals(true, results[0].isSuccess, (results[0].errors != NULL && !results[0].errors.isEmpty() ? results[0].errors[0].message : 'Billing has been posted'));

            System.assertEquals(
                3,
            [SELECT COUNT() FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id]
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Billing__c WHERE Id = :testData.billings.get(0).Id].Status__c
            );

            System.assertEquals(
                0,
                [SELECT SUM(Amount__c) sum FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id GROUP BY Billing__c].get(0).get('sum')
            );
        }
    }

    @isTest
    private static void testBillingHeaderLevelPostSeparateTransactionsByProject() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost()
            .createBillings()
            .createProjects()
            .createProjectTasks();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.billingLines.get(0).Project__c = testData.projects[0].Id;
            testData.billingLines.get(0).Project_Task__c = testData.projectTasks[0].Id;
            update testData.billingLines.get(0);

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testData.billings.get(0)});

            System.assertEquals(true, results[0].isSuccess, (results[0].errors != NULL && !results[0].errors.isEmpty() ? results[0].errors[0].message : 'Billing has been posted'));

            System.assertEquals(
                3,
            [SELECT COUNT() FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id]
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Billing__c WHERE Id = :testData.billings.get(0).Id].Status__c
            );
            System.assertEquals(
                0,
                [SELECT SUM(Amount__c) sum FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id GROUP BY Billing__c].get(0).get('sum')
            );
        }
    }

    @isTest
    private static void testBillingHeaderLevelPostSeparateTransactionsByProjectTask() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost()
            .createBillings()
            .createProjects()
            .createProjectTasks();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.billingLines.get(0).Project__c = testData.projects[0].Id;
            testData.billingLines.get(0).Project_Task__c = testData.projectTasks[0].Id;
            testData.billingLines.get(1).Project__c = testData.projects[0].Id;
            testData.billingLines.get(1).Project_Task__c = testData.projectTasks[1].Id;
            update testData.billingLines;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testData.billings.get(0)});

            System.assertEquals(true, results[0].isSuccess, (results[0].errors != NULL && !results[0].errors.isEmpty() ? results[0].errors[0].message : 'Billing has been posted'));

            System.assertEquals(
                3,
            [SELECT COUNT() FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id]
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Billing__c WHERE Id = :testData.billings.get(0).Id].Status__c
            );
            System.assertEquals(
                0,
                [SELECT SUM(Amount__c) sum FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id GROUP BY Billing__c].get(0).get('sum')
            );
        }
    }

    @isTest
    private static void testBillingHeaderLevelPostSeparateTransactionsByGLAccount() {
        TestDataSuite testData = TestDataSuite.getInstance().setHeaderLevelPost().createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.billingLines.get(0).Revenue_GL_Account__c = testData.glAccounts[18].Id;
            testData.billingLines.get(1).Revenue_GL_Account__c = testData.glAccounts[27].Id;
            update testData.billingLines;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testData.billings.get(0)});

            System.assertEquals(true, results[0].isSuccess, (results[0].errors != NULL && !results[0].errors.isEmpty() ? results[0].errors[0].message : 'Billing has been posted'));

            System.assertEquals(
                3,
            [SELECT COUNT() FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id]
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Billing__c WHERE Id = :testData.billings.get(0).Id].Status__c
            );
            System.assertEquals(
                0,
                [SELECT SUM(Amount__c) sum FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id GROUP BY Billing__c].get(0).get('sum')
            );
        }
    }

    @isTest
    private static void testBillingHeaderLevelPostSeparateTransactionsByGLAV() {
        TestDataSuite testData = TestDataSuite.getInstance().setHeaderLevelPost().createBillings().createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.billingLines.get(0).GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            testData.billingLines.get(1).GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            update testData.billingLines;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testData.billings.get(0)});

            System.assertEquals(true, results[0].isSuccess, (results[0].errors != NULL && !results[0].errors.isEmpty() ? results[0].errors[0].message : 'Billing has been posted'));

            System.assertEquals(
                3,
            [SELECT COUNT() FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id]
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Billing__c WHERE Id = :testData.billings.get(0).Id].Status__c
            );
            System.assertEquals(
                0,
                [SELECT SUM(Amount__c) sum FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id GROUP BY Billing__c].get(0).get('sum')
            );
        }
    }

    @isTest
    private static void testBillingHeaderLevelPostSeparateTransactionsByTimeCard() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost();
        Test.startTest();
        testData.createProjects()
            .createProjectTasks()
            .createTimeCards()
            .createBillings()
            .createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            List<Accounting_Variable__c> timeCardsVariables = new List<Accounting_Variable__c>();

            timeCardsVariables.add(
                new Accounting_Variable__c(
                    Name = 'TC1',
                    Active__c = true,
                    Type__c = 'Time Card Variable 1'
                )
            );
            timeCardsVariables.add(
                new Accounting_Variable__c(
                    Name = 'TC2',
                    Active__c = true,
                    Type__c = 'Time Card Variable 2'
                )
            );

            insert timeCardsVariables;

            testData.billingLines.get(0).Time_Card_Variable_1__c = timeCardsVariables[0].Id;
            testData.billingLines.get(1).Time_Card_Variable_2__c = timeCardsVariables[1].Id;
            update testData.billingLines;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testData.billings.get(0)});

            System.assertEquals(true, results[0].isSuccess, (results[0].errors != NULL && !results[0].errors.isEmpty() ? results[0].errors[0].message : 'Billing has been posted'));

            System.assertEquals(
                3,
            [SELECT COUNT() FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id]
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Billing__c WHERE Id = :testData.billings.get(0).Id].Status__c
            );
            System.assertEquals(
                0,
                [SELECT SUM(Amount__c) sum FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id GROUP BY Billing__c].get(0).get('sum')
            );
        }
    }

    @isTest
    private static void testBillingHeaderLevelPostSuccessWithTax() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost();
        Test.startTest();
        testData.createTaxGroups()
            .createBillings();

        System.runAs(testData.users.get(1)) {

            testData.billingLines.get(0).Tax_Group__c = testData.taxGroups[0].Id;
            testData.billingLines.get(1).Tax_Group__c = testData.taxGroups[0].Id;
            update testData.billingLines;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testData.billings.get(0)});

            System.assertEquals(true, results[0].isSuccess, (results[0].errors != NULL && !results[0].errors.isEmpty() ? results[0].errors[0].message : 'Billing has been posted'));

            System.assertEquals(
                3,
            [SELECT COUNT() FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id]
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Billing__c WHERE Id = :testData.billings.get(0).Id].Status__c
            );

            System.assertEquals(
                495,
                [SELECT Amount__c FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id][0].Amount__c
            );

            System.assertEquals(
                -450,
                [SELECT Amount__c FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id][1].Amount__c
            );
            System.assertEquals(
                -45,
                [SELECT Amount__c FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id][2].Amount__c
            );
        }
    }

    @isTest
    private static void testBillingHeaderLevelPostSuccessWithSeparateTaxTransactionByGLAccount() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost();
        Test.startTest();
        testData.createTaxGroups()
            .createBillings();

        System.runAs(testData.users.get(1)) {

            testData.taxRates[2].Sales_Tax_Liability_GL_Account__c = testData.glAccounts[23].Id;
            update testData.taxRates[2];

            testData.billingLines.get(0).Tax_Group__c = testData.taxGroups[0].Id;
            testData.billingLines.get(1).Tax_Group__c = testData.taxGroups[2].Id;
            update testData.billingLines;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testData.billings.get(0)});

            System.assertEquals(true, results[0].isSuccess, (results[0].errors != NULL && !results[0].errors.isEmpty() ? results[0].errors[0].message : 'Billing has been posted'));

            System.assertEquals(
                4,
            [SELECT COUNT() FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id]
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Billing__c WHERE Id = :testData.billings.get(0).Id].Status__c
            );

            System.assertEquals(
                477.50,
                [SELECT Amount__c FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id][0].Amount__c
            );

            System.assertEquals(
                -450,
                [SELECT Amount__c FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id][1].Amount__c
            );
            System.assertEquals(
                -20,
                [SELECT Amount__c FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id][2].Amount__c
            );
            System.assertEquals(
                -7.5,
                [SELECT Amount__c FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id][3].Amount__c
            );
        }
    }

    @isTest
    private static void testBillingHeaderLevelPostSuccessWithSeparateTaxTransactionByGLAV() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost();
        Test.startTest();
        testData.createTaxGroups()
            .createAccountingVariables()
            .createBillings();

        System.runAs(testData.users.get(1)) {

            testData.billingLines.get(0).Tax_Group__c = testData.taxGroups[0].Id;
            testData.billingLines.get(1).Tax_Group__c = testData.taxGroups[0].Id;

            testData.billingLines.get(0).GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            testData.billingLines.get(1).GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            update testData.billingLines;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testData.billings.get(0)});

            System.assertEquals(true, results[0].isSuccess, (results[0].errors != NULL && !results[0].errors.isEmpty() ? results[0].errors[0].message : 'Billing has been posted'));

            System.assertEquals(
                5,
            [SELECT COUNT() FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id]
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Billing__c WHERE Id = :testData.billings.get(0).Id].Status__c
            );

            System.assertEquals(
                495,
                [SELECT Amount__c FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id][0].Amount__c
            );

            System.assertEquals(
                -200,
                [SELECT Amount__c FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id][1].Amount__c
            );
            System.assertEquals(
                -250,
                [SELECT Amount__c FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id][2].Amount__c
            );
            System.assertEquals(
                -20,
                [SELECT Amount__c FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id][3].Amount__c
            );
            System.assertEquals(
                -25,
                [SELECT Amount__c FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id][4].Amount__c
            );
        }
    }

    @isTest
    private static void testBillingHeaderLevelPostSuccessWithSeparateTaxTransactionByTC() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost();
        Test.startTest();
        testData.createTaxGroups()
            .createAccountingVariables()
            .createBillings();

        System.runAs(testData.users.get(1)) {

            List<Accounting_Variable__c> tcAccountingVariables = new List<Accounting_Variable__c>();

            tcAccountingVariables.add(
                new Accounting_Variable__c(
                    Name = 'TC1',
                    Active__c = true,
                    Type__c = 'Time Card Variable 1'
                )
            );

            tcAccountingVariables.add(
                new Accounting_Variable__c(
                    Name = 'TC2',
                    Active__c = true,
                    Type__c = 'Time Card Variable 2'
                )
            );

            insert tcAccountingVariables;

            testData.billingLines.get(0).Tax_Group__c = testData.taxGroups[0].Id;
            testData.billingLines.get(1).Tax_Group__c = testData.taxGroups[0].Id;

            testData.billingLines.get(0).Time_Card_Variable_1__c = tcAccountingVariables[0].Id;
            testData.billingLines.get(1).Time_Card_Variable_2__c = tcAccountingVariables[1].Id;
            update testData.billingLines;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testData.billings.get(0)});

            System.assertEquals(true, results[0].isSuccess, (results[0].errors != NULL && !results[0].errors.isEmpty() ? results[0].errors[0].message : 'Billing has been posted'));

            System.assertEquals(
                5,
            [SELECT COUNT() FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id]
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Billing__c WHERE Id = :testData.billings.get(0).Id].Status__c
            );

            System.assertEquals(
                495,
                [SELECT Amount__c FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id][0].Amount__c
            );

            System.assertEquals(
                -200,
                [SELECT Amount__c FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id][1].Amount__c
            );
            System.assertEquals(
                -250,
                [SELECT Amount__c FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id][2].Amount__c
            );
            System.assertEquals(
                -20,
                [SELECT Amount__c FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id][3].Amount__c
            );
            System.assertEquals(
                -25,
                [SELECT Amount__c FROM Transaction__c WHERE Billing__c = :testData.billings.get(0).Id][4].Amount__c
            );
        }
    }

    @IsTest
    private static void testAvaTaxCalcOnPostWithMixedCurrenciesLLP_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .setLineLevelPost();

            System.runAs(testData.users.get(1)) {
                String theNewCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(theNewCurrencyIsoCode)) {
                    return;
                }

                //Enable Avalara Tax Calculation
                testData.enableAvaTaxCalculation();
                //create taxable product
                Product2 testProduct = new Product2(
                    Name = 'Jewelry',
                    Expense_GL_Account__c = testData.glAccounts[12].Id,
                    Revenue_GL_Account__c = testData.glAccounts[10].Id,
                    Accounting_Type__c = 'Taxable Product'
                );
                insert testProduct;

                List<Billing__c> billings = new List<Billing__c>();
                Billing__c testBillingBaseCurrency = new Billing__c(
                    Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                    Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c+3,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Customer__c = testData.accounts[0].Id,
                    Status__c = 'Approved',
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Billing_Format__c = testData.billingFormats[0].Id,
                    Due_Date2__c = System.today() + 30,
                    Billing_Street__c = '999 Billing Street',
                    Billing_City__c = 'BillingCity',
                    Billing_State__c = 'CA',
                    Billing_Country__c = 'US',
                    Billing_PostalCode__c = '94104',
                    Shipping_Street__c = '888 Shipping Street',
                    Shipping_City__c = 'ShippingCity',
                    Shipping_State__c = 'CA',
                    Shipping_Country__c = 'US',
                    Shipping_PostalCode__c = '90100',
                    Currency_Conversion_Rate__c = 1.0,
                    Ledger__c = testData.ledgers[0].Id
                );
                billings.add(testBillingBaseCurrency);

                Billing__c testBillingForeignCurrency = new Billing__c(
                    Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                    Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c+3,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Customer__c = testData.accounts[0].Id,
                    Status__c = 'Approved',
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Billing_Format__c = testData.billingFormats[0].Id,
                    Due_Date2__c = System.today() + 30,
                    Billing_Street__c = '999 Billing Street',
                    Billing_City__c = 'BillingCity',
                    Billing_State__c = 'CA',
                    Billing_Country__c = 'US',
                    Billing_PostalCode__c = '94104',
                    Shipping_Street__c = '888 Shipping Street',
                    Shipping_City__c = 'ShippingCity',
                    Shipping_State__c = 'CA',
                    Shipping_Country__c = 'US',
                    Shipping_PostalCode__c = '90100',
                    Currency_Conversion_Rate__c = 2.0,
                    Ledger__c = testData.ledgers[0].Id
                );
                testBillingForeignCurrency.put('CurrencyIsoCode', theNewCurrencyIsoCode);
                billings.add(testBillingForeignCurrency);
                insert billings;

                List<Billing_Line__c> lines = new List<Billing_Line__c>();
                Billing_Line__c testBillingLineBaseCurrency = new Billing_Line__c(
                    Billing__c = testBillingBaseCurrency.Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Hours_Units__c = 1,
                    Product__c = testProduct.Id,
                    Rate__c = 1000,
                    Revenue_GL_Account__c = testData.glAccounts[10].Id
                );
                lines.add(testBillingLineBaseCurrency);

                Billing_Line__c testBillingLineForeignCurrency = new Billing_Line__c(
                    Billing__c = testBillingForeignCurrency.Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Hours_Units__c = 1,
                    Product__c = testProduct.Id,
                    Rate__c = 1000,
                    Revenue_GL_Account__c = testData.glAccounts[10].Id
                );
                lines.add(testBillingLineForeignCurrency);
                insert lines;

                //re-query billing line to have all necessary fields populated
                List<Billing_Line__c> testBillingLines = [
                    SELECT Id, Name, Hours_Units__c, Rate__c
                    FROM Billing_Line__c
                    WHERE Id IN :lines
                ];

                List<String> responseBodyValues = new List<String>{
                    //response body for Billing with base currency
                    testData.getCreateAvaTaxTransactionResponseBody(testBillingBaseCurrency, new List<Billing_Line__c>{testBillingLines[0]}, 10),
                    //response body for Billing with foreign currency
                    testData.getCreateAvaTaxTransactionResponseBody(testBillingForeignCurrency, new List<Billing_Line__c>{testBillingLines[1]}, 10)
                };

                SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                    200,
                    'Complete',
                    responseBodyValues,
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );

                Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

                Test.startTest();
                AbstractPostHandler postHandler = new BillingPostHandler();
                List<PostResult> postResults = postHandler.post(billings);
                Test.stopTest();

                System.assertEquals(true, postResults.get(0).isSuccess);

                List<Billing_Line__c> salesTaxLines = [
                    SELECT Id, Billing__r.Status__c, Hours_Units__c, Rate__c
                    FROM Billing_Line__c
                    WHERE Billing__c IN :billings
                    AND Product__c = :AvaTaxHelper.getSalesTaxProductId(testBillingBaseCurrency)
                ];

                System.assertNotEquals(true, salesTaxLines.isEmpty(), 'sales tax line has not been created');
                System.assertEquals(billings.size(), salesTaxLines.size());
                System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, salesTaxLines.get(0).Billing__r.Status__c);
                System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, salesTaxLines.get(1).Billing__r.Status__c);
                System.assertEquals(
                    testBillingLineBaseCurrency.Hours_Units__c * testBillingLineBaseCurrency.Rate__c / 10,
                    salesTaxLines.get(0).Rate__c
                );
                System.assertEquals(
                    testBillingLineForeignCurrency.Hours_Units__c * testBillingLineForeignCurrency.Rate__c / 10,
                    salesTaxLines.get(1).Rate__c
                );
            }

        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    private static void testAvaTaxCalcOnPostWithMixedCurrenciesHLP_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency();

            System.runAs(testData.users.get(1)) {
                String theNewCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(theNewCurrencyIsoCode)) {
                    return;
                }

                //Enable Avalara Tax Calculation
                testData.enableAvaTaxCalculation();
                //create taxable product
                Product2 testProduct = new Product2(
                    Name = 'Jewelry',
                    Expense_GL_Account__c = testData.glAccounts[12].Id,
                    Revenue_GL_Account__c = testData.glAccounts[10].Id,
                    Accounting_Type__c = 'Taxable Product'
                );
                insert testProduct;

                List<Billing__c> billings = new List<Billing__c>();
                Billing__c testBillingBaseCurrency = new Billing__c(
                    Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                    Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c+3,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Customer__c = testData.accounts[0].Id,
                    Status__c = 'Approved',
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Billing_Format__c = testData.billingFormats[0].Id,
                    Due_Date2__c = System.today() + 30,
                    Billing_Street__c = '999 Billing Street',
                    Billing_City__c = 'BillingCity',
                    Billing_State__c = 'CA',
                    Billing_Country__c = 'US',
                    Billing_PostalCode__c = '94104',
                    Shipping_Street__c = '888 Shipping Street',
                    Shipping_City__c = 'ShippingCity',
                    Shipping_State__c = 'CA',
                    Shipping_Country__c = 'US',
                    Shipping_PostalCode__c = '90100',
                    Currency_Conversion_Rate__c = 1.0
                );
                billings.add(testBillingBaseCurrency);

                Billing__c testBillingForeignCurrency = new Billing__c(
                    Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                    Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c+3,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Customer__c = testData.accounts[0].Id,
                    Status__c = 'Approved',
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Billing_Format__c = testData.billingFormats[0].Id,
                    Due_Date2__c = System.today() + 30,
                    Billing_Street__c = '999 Billing Street',
                    Billing_City__c = 'BillingCity',
                    Billing_State__c = 'CA',
                    Billing_Country__c = 'US',
                    Billing_PostalCode__c = '94104',
                    Shipping_Street__c = '888 Shipping Street',
                    Shipping_City__c = 'ShippingCity',
                    Shipping_State__c = 'CA',
                    Shipping_Country__c = 'US',
                    Shipping_PostalCode__c = '90100',
                    Currency_Conversion_Rate__c = 2.0
                );
                testBillingForeignCurrency.put('CurrencyIsoCode', theNewCurrencyIsoCode);
                billings.add(testBillingForeignCurrency);
                insert billings;

                List<Billing_Line__c> lines = new List<Billing_Line__c>();
                Billing_Line__c testBillingLineBaseCurrency = new Billing_Line__c(
                    Billing__c = testBillingBaseCurrency.Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Hours_Units__c = 1,
                    Product__c = testProduct.Id,
                    Rate__c = 1000,
                    Revenue_GL_Account__c = testData.glAccounts[10].Id
                );
                lines.add(testBillingLineBaseCurrency);

                Billing_Line__c testBillingLineForeignCurrency = new Billing_Line__c(
                    Billing__c = testBillingForeignCurrency.Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Hours_Units__c = 1,
                    Product__c = testProduct.Id,
                    Rate__c = 1000,
                    Revenue_GL_Account__c = testData.glAccounts[10].Id
                );
                lines.add(testBillingLineForeignCurrency);
                insert lines;

                //re-query billing line to have all necessary fields populated
                List<Billing_Line__c> testBillingLines = [
                    SELECT Id, Name, Hours_Units__c, Rate__c
                    FROM Billing_Line__c
                    WHERE Id IN :lines
                ];

                List<String> responseBodyValues = new List<String>{
                    //response body for Billing with base currency
                    testData.getCreateAvaTaxTransactionResponseBody(testBillingBaseCurrency, new List<Billing_Line__c>{testBillingLines[0]}, 10),
                    //response body for Billing with foreign currency
                    testData.getCreateAvaTaxTransactionResponseBody(testBillingForeignCurrency, new List<Billing_Line__c>{testBillingLines[1]}, 10)
                };

                SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                    200,
                    'Complete',
                    responseBodyValues,
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );

                Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

                Test.startTest();
                AbstractPostHandler postHandler = new BillingPostHandler();
                List<PostResult> postResults = postHandler.post(billings);
                Test.stopTest();

                System.assertEquals(true, postResults.get(0).isSuccess);

                billings = [SELECT Id, Status__c FROM Billing__c WHERE Id IN :billings];

                System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, billings[0].Status__c);
                System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, billings[1].Status__c);

                Billing_Line__c checkBillingLineBaseCurrency =
                    [SELECT Id, Tax_Amount2__c FROM Billing_Line__c WHERE Billing__c = :testBillingBaseCurrency.Id];
                Billing_Line__c checkBillingLineForeignCurrency =
                    [SELECT Id, Tax_Amount2__c FROM Billing_Line__c WHERE Billing__c = :testBillingForeignCurrency.Id];

                System.assertEquals(
                    testBillingLineBaseCurrency.Hours_Units__c * testBillingLineBaseCurrency.Rate__c / 10,
                    checkBillingLineBaseCurrency.Tax_Amount2__c
                );
                System.assertEquals(
                    testBillingLineForeignCurrency.Hours_Units__c * testBillingLineForeignCurrency.Rate__c / 10,
                    checkBillingLineForeignCurrency.Tax_Amount2__c
                );
            }

        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @Istest
    private static void sumDecimalResultTest() {
        //ensure sumDecimalResult method is rounding the decimal values correctly based on the scale
        AbstractPostHandler postHandler = new BillingPostHandler();
        Decimal roundDown = 1.4444444;
        Decimal roundUp = 1.5555555;
        for (Integer i = 1 ; i < 7; i++) {
            system.assertEquals(rounddown.setscale(i, RoundingMode.HALF_UP) + roundUp.setscale(i, RoundingMode.HALF_UP), 
                                postHandler.sumDecimalResult(roundUp, roundDown, i));
        }

    }

    @isTest
    private static void testLedgerWithEmptyTaxSettingError() {
        TestDataSuite testData = TestDataSuite.getInstance().setHeaderLevelPost().createBillings().createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Ledger__c selectedLedger = LedgerHandler.getInstanceWithSharing(true).getLedgerById(testData.ledgers[0].Id);
            selectedLedger.Tax_Settings__c = null;
            update selectedLedger;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testData.billings.get(0)});

            System.assertEquals(false, results[0].isSuccess, TaxService.getNoTaxSettingErrorMessage(false));
        }
    }

    @isTest
    private static void testAvalaraMultipleLicenseError() {
        TestDataSuite testData = TestDataSuite.getInstance().setHeaderLevelPost().createBillings().enableAvaTaxCalculation();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            AvaTax_License__c newLicense = new AvaTax_License__c();
            newLicense.Active_AvaTax_Endpoint__c = GlobalVariables.AVALARA_REST_ENDPOINT;
            newLicense.AvaTax_Account_ID__c = 'AvataxAccountId1';
            newLicense.AvaTax_License_Key__c = 'AvataxLicenseKey1';
            insert newLicense;

            Tax_Settings__c taxSetting = new Tax_Settings__c();
            taxSetting.Tax_Settings_Method__c = TaxSettingsActions.AVA_TAX_METHOD;
            taxSetting.Origin_Address__c = testData.addressObjects[0].Id;
            taxSetting.Sales_Tax_GL_Account__c = testData.glAccounts[28].Id;
            taxSetting.AvaTax_License__c = newLicense.Id;
            taxSetting.Sales_Tax_Product__c = testData.products[5].Id;
            taxSetting.Sales_Tax_Calculation_Mode__c = 'Shipment';
            insert taxSetting;

            Ledger__c selectedLedger = LedgerHandler.getInstanceWithSharing(true).getLedgerById(testData.ledgers[2].Id);
            selectedLedger.Tax_Settings__c = taxSetting.Id;
            selectedLedger.Sales_Tax_Company_Code__c = 'TEST_COMPANY';
            update selectedLedger;

            Billing__c bill = testData.billings.get(0).clone(false, true);
            bill.Ledger__c = selectedLedger.Id;
            insert bill;

            Billing_Line__c billLine = testData.billingLines.get(0).clone(false, true);
            billLine.Billing__c = bill.Id;
            insert billLine;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testData.billings.get(0), bill});

            System.assertEquals(false, results[0].isSuccess);
            System.assertEquals(Label.MULTIPLE_AVALARA_LICENSE_ERROR, results[0].errors[0].message);
            Test.stopTest();
        }
    }

    //TODO Need refactoring to avoid 101 Query error

//    @IsTest
//    public static void testUnpostAvaTaxBillingWithLockedTransaction() {
//        TestDataSuite testData = TestDataSuite.getInstance()
//            .enableAvaTaxCalculation();
//        Test.startTest();
//        testData.createBillings(true);
//
//        System.runAs(testData.users.get(1)) {
//            for (Billing__c bill : [SELECT Locked_In_AvaTax__c FROM Billing__c]) {
//                System.assert(!bill.Locked_In_AvaTax__c);
//            }
//            SingleRequestMock xGetListTransactionByCompanyRequestMock = new SingleRequestMock(
//                200,
//                'Complete',
//                getListTransactionByCompanyResponseBody([SELECT Id, Name, Total__c, Sales_Tax3__c FROM Billing__c], 10),
//                new Map<String, String>{'Content-Type' => 'application/json'}
//            );
//
//            Test.setMock(HttpCalloutMock.class, xGetListTransactionByCompanyRequestMock);
//
//            BillingPostService.unpostBillings([SELECT Id FROM Billing__c]);
//
//            Test.stopTest();
//            for (Billing__c bill : [SELECT Locked_In_AvaTax__c FROM Billing__c]) {
//                System.assert(bill.Locked_In_AvaTax__c);
//            }
//        }
//    }

    @IsTest
    public static void testPostWithSoftClosedAcctPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            // Test accounting period is closed error
            Billing__c testBilling = testData.billings[0];
            testBilling.Status__c = 'Approved';
            update testBilling;

            AccountingPeriodActions.isFirstRun = false;
            Accounting_Period__c testAcctPeriod = testData.acctPeriods[0];
            testAcctPeriod.Close_AR__c = true;
            update testAcctPeriod;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testRoundingTaxAmountAdjustment() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost();
        Test.startTest();
        testData.createTaxGroups()
            .createBillings();

        System.runAs(testData.users.get(1)) {
            Tax_Group__c tg = new Tax_Group__c (
                Name = 'TaxGroupNew',
                Tax_Type__c = 'Sales and Purchase'
            );
            insert tg;

            List<Tax_Rate__c> taxRates = new List<Tax_Rate__c>();
            taxRates.add(
                new Tax_Rate__c(
                    Name = 'TR1',
                    Tax_Group__c = tg.Id,
                    Tax_Rate__c = 4.9,
                    Sales_Tax_Liability_GL_Account__c = testData.glAccounts[7].Id,
                    Purchase_Tax_Expense_GL_Account__c = testData.glAccounts[24].Id
                )
            );

            taxRates.add(
                new Tax_Rate__c(
                    Name = 'TR2',
                    Tax_Group__c = tg.Id,
                    Tax_Rate__c = 5.1,
                    Sales_Tax_Liability_GL_Account__c = testData.glAccounts[6].Id,
                    Purchase_Tax_Expense_GL_Account__c = testData.glAccounts[23].Id
                )
            );
            insert taxRates;

            Billing__c newBill = testData.billings[0].clone();
            insert newBill;

            Billing_Line__c newBillLine =  testData.billingLines.get(0).clone();
            newBillLine.Billing__c = newBill.Id;
            newBillLine.Tax_Group__c = tg.Id;
            newBillLine.Hours_Units__c = 455;
            newBillLine.Rate__c = 1;
            insert newBillLine;


            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{newBill});

            System.assertEquals(true, results[0].isSuccess, (results[0].errors != NULL && !results[0].errors.isEmpty() ? results[0].errors[0].message : 'Billing has been posted'));

            System.assertEquals(
                4,
                [SELECT COUNT() FROM Transaction__c WHERE Billing__c = :newBill.Id]
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Billing__c WHERE Id = :newBill.Id].Status__c
            );

            System.assertEquals(
                500.5,
                [SELECT Amount__c FROM Transaction__c WHERE Billing__c = :newBill.Id][0].Amount__c
            );

            System.assertEquals(
                -455,
                [SELECT Amount__c FROM Transaction__c WHERE Billing__c = :newBill.Id][1].Amount__c
            );
            System.assertEquals(
                -22.30,
                [SELECT Amount__c FROM Transaction__c WHERE Billing__c = :newBill.Id][2].Amount__c
            );
            System.assertEquals(
                -23.20,
                [SELECT Amount__c FROM Transaction__c WHERE Billing__c = :newBill.Id][3].Amount__c
            );
        }

    }

    @IsTest
    private static void testTaxInclusiveTaxGroup() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost();
        Test.startTest();
        testData.createTaxGroups()
            .createBillings();

        System.runAs(testData.users[1]) {
            // setup tax groups
            Set<Id> taxGroupIds = new Set<Id>{ testData.taxGroups[0].Id, testData.taxGroups[2].Id };
            List<Tax_Group__c> taxGroups = [SELECT Id, Combined_Tax_Rate__c, (SELECT Sales_Tax_Liability_GL_Account__c FROM Tax_Rates__r) FROM Tax_Group__c WHERE Id IN :taxGroupIds];
            Tax_Group__c inclusiveTaxGroup = taxGroups[0];
            Tax_Group__c exclusiveTaxGroup = taxGroups[1];
            inclusiveTaxGroup.Tax_Inclusive__c = true;
            update inclusiveTaxGroup;

            // setup billing and lines
            Billing__c billing = testData.billings[0];
            Billing_Line__c line1 = testData.billingLines[0];
            Billing_Line__c line2 = testData.billingLines[1];

            line1.Hours_Units__c = 1;
            line1.Rate__c = 100;
            line1.Tax_Group__c = inclusiveTaxGroup.Id;

            line2.Hours_Units__c = 1;
            line2.Rate__c = 100;
            line2.Tax_Group__c = exclusiveTaxGroup.Id;

            update new List<Billing_Line__c>{ line1, line2 };
            
            Set<Id> lineIds = new Set<Id>{ line1.Id, line2.Id };
            List<Billing_Line__c> lines = [SELECT Id, Tax_Amount2__c, Total__c, Sub_Total__c, Revenue_GL_Account__c FROM Billing_Line__c WHERE Id IN :lineIds];
            line1 = line1.Id == lines[0].Id ? lines[0] : lines[1];
            line2 = line2.Id == lines[0].Id ? lines[0] : lines[1];

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{billing});

            // billing posted successfully
            Assert.isTrue(results[0].isSuccess);

            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            Id arControlAccount = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT)?.GL_Account__c;

            List<Transaction__c> txns = [SELECT Amount__c, GL_Account__c, GL_Account__r.Name FROM Transaction__c WHERE Billing__c = :billing.Id];
            for (Transaction__c txn : txns) {
                // should be = subtotal
                if (txn.GL_Account__c == line1.Revenue_GL_Account__c) {
                    Assert.areEqual((line1.Sub_Total__c + line2.Sub_Total__c) * -1, txn.Amount__c);
                } else if (txn.GL_Account__c == arControlAccount) {
                    Assert.areEqual(line1.Total__c + line2.Total__c, txn.Amount__c);
                } else if (txn.GL_Account__c == inclusiveTaxGroup.Tax_Rates__r[0].Sales_Tax_Liability_GL_Account__c) {
                    Assert.areEqual((line1.Tax_Amount2__c + line2.Tax_Amount2__c) * -1, txn.Amount__c);
                } else {
                    Assert.fail('Unexpected GL Account: ' + txn.GL_Account__r.Name);
                }
            }

            Test.stopTest();
        }
    }

    @IsTest
    private static void testTaxInclusiveTaxGroupRounding() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost();
        Test.startTest();
        testData.createTaxGroups()
            .createBillings();

        System.runAs(testData.users[1]) {
            // setup tax groups
            Tax_Group__c taxGroup = testData.taxGroups[0].clone(false, true, false, false);
            taxGroup.Tax_Inclusive__c = true;
            insert taxGroup;

            GL_Account__c taxAccount1 = testData.glAccounts[6].clone(false, true, false, false);
            taxAccount1.Name = '11111-Sales Tax 1';
            GL_Account__c taxAccount2 = testData.glAccounts[6].clone(false, true, false, false);
            taxAccount1.Name = '11112-Sales Tax 2';
            GL_Account__c taxAccount3 = testData.glAccounts[6].clone(false, true, false, false);
            taxAccount1.Name = '11113-Sales Tax 3';
            List<GL_Account__c> taxAccounts = new List<GL_Account__c>{ taxAccount1, taxAccount2, taxAccount3 };
            insert taxAccounts;

            Tax_Rate__c taxRate1 = testData.taxRates[0].clone(false, true, false, false);
            taxRate1.Name = 'SalesTaxRate1';
            taxRate1.Tax_Group__c = taxGroup.Id;
            taxRate1.Tax_Rate__c = 2.986;
            taxRate1.Sales_Tax_Liability_GL_Account__c = taxAccounts[0].Id;
            Tax_Rate__c taxRate2 = testData.taxRates[0].clone(false, true, false, false);
            taxRate2.Name = 'SalesTaxRate2';
            taxRate2.Tax_Group__c = taxGroup.Id;
            taxRate2.Tax_Rate__c = 1.755;
            taxRate2.Sales_Tax_Liability_GL_Account__c = taxAccounts[1].Id;
            Tax_Rate__c taxRate3 = testData.taxRates[0].clone(false, true, false, false);
            taxRate3.Name = 'SalesTaxRate3';
            taxRate3.Tax_Group__c = taxGroup.Id;
            taxRate3.Tax_Rate__c = 0.291;
            taxRate3.Sales_Tax_Liability_GL_Account__c = taxAccounts[2].Id;
            insert new List<Tax_Rate__c>{ taxRate1, taxRate2, taxRate3 };

            Set<Id> taxGroupIds = new Set<Id>{ taxGroup.Id, testData.taxGroups[2].Id };
            List<Tax_Group__c> taxGroups = [SELECT Id, Combined_Tax_Rate__c, (SELECT Sales_Tax_Liability_GL_Account__c FROM Tax_Rates__r) FROM Tax_Group__c WHERE Id IN :taxGroupIds];
            Tax_Group__c inclusiveTaxGroup = taxGroups[0].Id == taxGroup.Id ? taxGroups[0] : taxGroups[1];
            Tax_Group__c exclusiveTaxGroup = taxGroups[0].Id == taxGroup.Id ? taxGroups[1] : taxGroups[0];

            // setup billing and lines
            Billing__c billing = testData.billings[0];
            Billing_Line__c line1 = testData.billingLines[0];
            Billing_Line__c line2 = testData.billingLines[1];

            line1.Hours_Units__c = 1;
            line1.Rate__c = 111.12;
            line1.Tax_Group__c = inclusiveTaxGroup.Id;

            line2.Hours_Units__c = 1;
            line2.Rate__c = 100;
            line2.Tax_Group__c = exclusiveTaxGroup.Id;

            update new List<Billing_Line__c>{ line1, line2 };
            
            Set<Id> lineIds = new Set<Id>{ line1.Id, line2.Id };
            List<Billing_Line__c> lines = [SELECT Id, Tax_Amount2__c, Total__c, Sub_Total__c, Revenue_GL_Account__c FROM Billing_Line__c WHERE Id IN :lineIds];
            line1 = line1.Id == lines[0].Id ? lines[0] : lines[1];
            line2 = line2.Id == lines[0].Id ? lines[0] : lines[1];

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{billing});

            // billing posted successfully
            Assert.isTrue(results[0].isSuccess);

            // billing total tax should be sum of tax from all lines
            billing = [SELECT Id, Sales_Tax3__c, Sub_Total__c, Total__c FROM Billing__c WHERE Id = :billing.Id];
            Assert.areEqual(line1.Tax_Amount2__c + line2.Tax_Amount2__c, billing.Sales_Tax3__c);

            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            Id arControlAccount = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT)?.GL_Account__c;

            List<Transaction__c> txns = [SELECT Amount__c, GL_Account__c, GL_Account__r.Name FROM Transaction__c WHERE Billing__c = :billing.Id];
            Decimal txnTax = 0;
            for (Transaction__c txn : txns) {
                if  (txn.GL_Account__c == exclusiveTaxGroup.Tax_Rates__r[0].Sales_Tax_Liability_GL_Account__c
                        || txn.GL_Account__c == inclusiveTaxGroup.Tax_Rates__r[0].Sales_Tax_Liability_GL_Account__c 
                        || txn.GL_Account__c == inclusiveTaxGroup.Tax_Rates__r[1].Sales_Tax_Liability_GL_Account__c
                        || txn.GL_Account__c == inclusiveTaxGroup.Tax_Rates__r[2].Sales_Tax_Liability_GL_Account__c) {
                    txnTax += txn.Amount__c;
                } else if (txn.GL_Account__c == line1.Revenue_GL_Account__c) {
                    Assert.areEqual(billing.Sub_Total__c * -1, txn.Amount__c);
                } else if (txn.GL_Account__c == arControlAccount) {
                    Assert.areEqual(Billing.Total__c, txn.Amount__c);
                } else {
                    Assert.fail('Unexpected GL Account: ' + txn.GL_Account__r.Name);
                }
            }
            
            // total taxes from billing should equal total taxes from txns
            Assert.areEqual(billing.Sales_Tax3__c * -1, txnTax);

            Test.stopTest();
        }
    }

    @IsTest
    private static void testTaxInclusiveTaxGroupRounding2() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost();
        Test.startTest();
        testData.createTaxGroups()
            .createBillings();

        System.runAs(testData.users[1]) {
            // setup tax groups
            Tax_Group__c taxGroup = testData.taxGroups[0].clone(false, true, false, false);
            taxGroup.Tax_Inclusive__c = true;
            insert taxGroup;

            GL_Account__c taxAccount1 = testData.glAccounts[6].clone(false, true, false, false);
            taxAccount1.Name = '11111-Sales Tax 1';
            GL_Account__c taxAccount2 = testData.glAccounts[6].clone(false, true, false, false);
            taxAccount1.Name = '11112-Sales Tax 2';
            List<GL_Account__c> taxAccounts = new List<GL_Account__c>{ taxAccount1, taxAccount2 };
            insert taxAccounts;

            Tax_Rate__c taxRate1 = testData.taxRates[0].clone(false, true, false, false);
            taxRate1.Name = 'SalesTaxRate1';
            taxRate1.Tax_Group__c = taxGroup.Id;
            taxRate1.Tax_Rate__c = 9.031;
            taxRate1.Sales_Tax_Liability_GL_Account__c = taxAccounts[0].Id;
            Tax_Rate__c taxRate2 = testData.taxRates[0].clone(false, true, false, false);
            taxRate2.Name = 'SalesTaxRate2';
            taxRate2.Tax_Group__c = taxGroup.Id;
            taxRate2.Tax_Rate__c = 5.468;
            taxRate2.Sales_Tax_Liability_GL_Account__c = taxAccounts[1].Id;
            insert new List<Tax_Rate__c>{ taxRate1, taxRate2 };

            taxGroup = [SELECT Id, Combined_Tax_Rate__c, (SELECT Sales_Tax_Liability_GL_Account__c FROM Tax_Rates__r) FROM Tax_Group__c WHERE Id = :taxGroup.Id];

            // setup billing and lines
            Billing__c billing = testData.billings[0];
            Billing_Line__c line = testData.billingLines[0];

            line.Hours_Units__c = 70;
            line.Rate__c = 3.35;
            line.Tax_Group__c = taxGroup.Id;


            update new List<Billing_Line__c>{ line };
            delete testData.billingLines[1];
            
            line = [SELECT Id, Tax_Amount2__c, Total__c, Sub_Total__c, Revenue_GL_Account__c FROM Billing_Line__c WHERE Id = :line.Id];

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{billing});

            // billing posted successfully
            Assert.isTrue(results[0].isSuccess);

            // billing total tax should be sum of tax from all lines
            billing = [SELECT Id, Sales_Tax3__c, Sub_Total__c, Total__c  FROM Billing__c WHERE Id = :billing.Id];
            Assert.areEqual(line.Tax_Amount2__c, billing.Sales_Tax3__c);

            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            Id arControlAccount = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT)?.GL_Account__c;

            List<Transaction__c> txns = [SELECT Amount__c, GL_Account__c FROM Transaction__c WHERE Billing__c = :billing.Id];
            Decimal txnTax = 0;
            for (Transaction__c txn : txns) {
                if  (txn.GL_Account__c == taxGroup.Tax_Rates__r[0].Sales_Tax_Liability_GL_Account__c 
                        || txn.GL_Account__c == taxGroup.Tax_Rates__r[1].Sales_Tax_Liability_GL_Account__c) {
                    txnTax += txn.Amount__c;
                } else if (txn.GL_Account__c == line.Revenue_GL_Account__c) {
                    Assert.areEqual(billing.Sub_Total__c * -1, txn.Amount__c);
                } else if (txn.GL_Account__c == arControlAccount) {
                    Assert.areEqual(Billing.Total__c, txn.Amount__c);
                } else {
                    Assert.fail('Unexpected GL Account: ' + txn.GL_Account__r.Name);
                }
            }
            // total taxes from billing should equal total taxes from txns
            Assert.areEqual(billing.Sales_Tax3__c * -1, txnTax);

            Test.stopTest();
        }
    }

    @IsTest
    private static void testTaxInclusiveTaxGroupRounding_MC() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        try {
            testData.enableMultiCurrency();
        } catch(TestDataSuite.TestDataSuiteException ex) {
            //skip this test if MC is not enabled
            return;
        }

        testData.setHeaderLevelPost()
            .createTaxGroups()
            .createBillings();

        System.runAs(testData.users[1]) {
            String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
            if (String.isBlank(newCurrencyIsoCode)) {
                return;
            }

            // setup tax groups
            Tax_Group__c taxGroup = testData.taxGroups[0].clone(false, true, false, false);
            taxGroup.Tax_Inclusive__c = true;
            insert taxGroup;

            GL_Account__c taxAccount1 = testData.glAccounts[6].clone(false, true, false, false);
            taxAccount1.Name = '11111-Sales Tax 1';
            GL_Account__c taxAccount2 = testData.glAccounts[6].clone(false, true, false, false);
            taxAccount1.Name = '11112-Sales Tax 2';
            List<GL_Account__c> taxAccounts = new List<GL_Account__c>{ taxAccount1, taxAccount2 };
            insert taxAccounts;

            Tax_Rate__c taxRate1 = testData.taxRates[0].clone(false, true, false, false);
            taxRate1.Name = 'SalesTaxRate1';
            taxRate1.Tax_Group__c = taxGroup.Id;
            taxRate1.Tax_Rate__c = 9.031;
            taxRate1.Sales_Tax_Liability_GL_Account__c = taxAccounts[0].Id;
            Tax_Rate__c taxRate2 = testData.taxRates[0].clone(false, true, false, false);
            taxRate2.Name = 'SalesTaxRate2';
            taxRate2.Tax_Group__c = taxGroup.Id;
            taxRate2.Tax_Rate__c = 5.468;
            taxRate2.Sales_Tax_Liability_GL_Account__c = taxAccounts[1].Id;
            insert new List<Tax_Rate__c>{ taxRate1, taxRate2 };

            taxGroup = [SELECT Id, Combined_Tax_Rate__c, (SELECT Sales_Tax_Liability_GL_Account__c FROM Tax_Rates__r) FROM Tax_Group__c WHERE Id = :taxGroup.Id];

            // setup billing and lines
            Billing__c billing = testData.billings[0].clone(false, true, false, false);
            billing.put('CurrencyIsoCode', newCurrencyIsoCode);
            insert billing;

            Billing_Line__c line = testData.billingLines[0].clone(false, true, false, false);
            line.Hours_Units__c = 70;
            line.Rate__c = 3.35;
            line.Tax_Group__c = taxGroup.Id;
            line.Billing__c = billing.Id;
            line.put('CurrencyIsoCode', newCurrencyIsoCode);
            insert line;
            
            line = [SELECT Id, Tax_Amount2__c, Total__c, Sub_Total__c, Revenue_GL_Account__c FROM Billing_Line__c WHERE Id = :line.Id];

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{billing});

            // billing posted successfully
            Assert.isTrue(results[0].isSuccess);

            // billing total tax should be sum of tax from all lines
            billing = [SELECT Id, Sales_Tax3__c, Sub_Total__c, Total__c FROM Billing__c WHERE Id = :billing.Id];
            Assert.areEqual(line.Tax_Amount2__c, billing.Sales_Tax3__c);

            List<Transaction__c> txns = [SELECT Amount__c, GL_Account__c, GL_Account__r.Name, Currency_Conversion_Rate__c FROM Transaction__c WHERE Billing__c = :billing.Id];
            Decimal txnTax = 0;
            Decimal conversionRate = 1;
            for (Transaction__c txn : txns) {
                if  (txn.GL_Account__c == taxGroup.Tax_Rates__r[0].Sales_Tax_Liability_GL_Account__c 
                        || txn.GL_Account__c == taxGroup.Tax_Rates__r[1].Sales_Tax_Liability_GL_Account__c) {
                    txnTax += txn.Amount__c;
                    conversionRate = txn.Currency_Conversion_Rate__c;
                }
            }

            // total taxes from billing should equal total taxes from txns
            Assert.areEqual(((billing.Sales_Tax3__c * -1) / conversionRate).setScale(2, RoundingMode.HALF_UP), txnTax);

            Test.stopTest();
        }
    }

    @IsTest
    public static void testCashBasisPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing__c testBilling = testData.billings[0];
            testBilling.Ledger__c = testData.ledgers[3].Id;
            testBilling.Status__c = 'Approved';
            update testBilling;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, results[0].isSuccess);
            System.assert([SELECT Id FROM Transaction__c WHERE Billing__c = :testBilling.Id].isEmpty());
        }

    }

    //======================================================================================
    //===================== UTILITY METHODS =================================================
    //======================================================================================

    private static List<Billing_Line__c> createBillingLines(String masterId, String productId, Date masterDate, Integer quantity) {
        List<Billing_Line__c> result = new List<Billing_Line__c>();
        for (Integer i = 0; i < quantity; i++) {
            Billing_Line__c tempBL = new Billing_Line__c(
                Billing__c = masterId,
                Hours_Units__c = 1,
                Rate__c = i + 5,
                Product__c = productId,
                Date__c = masterDate
            );
            result.add(tempBL);
        }
        return result;
    }

    private static String getListTransactionByCompanyResponseBody(List<Billing__c> billings, Decimal taxDiff) {
        AvaTaxService.FetchResultTransactionModel result = new AvaTaxService.FetchResultTransactionModel();
        List<AvaTaxService.TransactionModel> models = new List<AvaTaxService.TransactionModel>();
        for (Billing__c bill : billings) {
            AvaTaxService.TransactionModel tempTransactionModel = new AvaTaxService.TransactionModel();
            tempTransactionModel.id = 000000000000000;
            tempTransactionModel.code = bill.Name;
            tempTransactionModel.companyId = 12345;
            tempTransactionModel.avaTaxDate = Date.today();
            tempTransactionModel.locked = true;
            tempTransactionModel.totalTax = bill.Sales_Tax3__c + taxDiff;
            models.add(tempTransactionModel);
        }
        result.setValue(models);
        return JSON.serialize(result);
    }

}