@IsTest
private class OpportunitySalesTaxTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true, true, true);
    }

    @IsTest
    public static void testNoAccountOnOpportunity() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true);

        System.runAs(testData.users.get(1)) {
            Opportunity testOpp = new Opportunity(
                Name = 'Test Opp',
                StageName = 'Closed Won',
                CloseDate = Date.today()
            );
            insert testOpp;

            ApexPages.StandardController stdController = new ApexPages.StandardController(testOpp);
            OpportunitySalesTax controller = new OpportunitySalesTax(stdController);

            controller.init();

            System.assertEquals(false, controller.isValidationPassed);
            System.assertEquals(OpportunitySalesTax.NO_ACCOUNT_ERROR_MESSAGE, ApexPages.getMessages().get(0).getSummary());
        }
    }

    @IsTest
    public static void testNoLinesOnOpportunity() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true);

        System.runAs(testData.users.get(1)) {
            Opportunity testOpp = new Opportunity(
                Name = 'Test Opp',
                StageName = 'Closed Won',
                CloseDate = Date.today(),
                AccountId = testData.accounts.get(0).Id
            );
            insert testOpp;

            ApexPages.StandardController stdController = new ApexPages.StandardController(testOpp);
            OpportunitySalesTax controller = new OpportunitySalesTax(stdController);

            controller.init();

            System.assertEquals(false, controller.isValidationPassed);
            System.assertEquals(OpportunitySalesTax.NO_OPPORTUNITY_PRODUCT_LINE_MESSAGE, ApexPages.getMessages().get(0).getSummary());
        }
    }

    @IsTest
    public static void testOpportunitySalesTaxNoTaxableProducts() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true).setLineLevelPost().createProducts();

        System.runAs(testData.users[1]) {
            Opportunity testOpp = new Opportunity(
                Name = 'Test Opp',
                StageName = 'Closed Won',
                CloseDate = Date.today(),
                AccountId = testData.accounts.get(0).Id
            );
            insert testOpp;

            Id pricebookId = Test.getStandardPriceBookId();
            PricebookEntry pbEntry = new PricebookEntry(
                Product2Id = testData.products[0].Id,
                PriceBook2Id = pricebookId,
                UnitPrice = 100,
                isActive = true,
                UseStandardPrice = false
            );
            insert pbEntry;

            OpportunityLineItem oppLineItem = new OpportunityLineItem(
                PriceBookEntryId = pbEntry.Id,
                OpportunityId = testOpp.Id,
                Quantity = 2,
                UnitPrice = 100
            );
            insert oppLineItem;

            ApexPages.StandardController stdController = new ApexPages.StandardController(testOpp);
            OpportunitySalesTax controller = new OpportunitySalesTax(stdController);

            controller.init();

            System.assertEquals(false, controller.isValidationPassed);
            System.assertEquals(OpportunitySalesTax.NO_TAXABLE_PRODUCTS_MESSAGE, ApexPages.getMessages().get(0).getSummary());
        }

    }

    @IsTest
    public static void testOpportunitySalesTaxNoAvailableTaxes() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true).setLineLevelPost().createProducts();

        System.runAs(testData.users[1]) {
            Opportunity testOpp = new Opportunity(
                Name = 'Test Opp',
                StageName = 'Closed Won',
                CloseDate = Date.today(),
                AccountId = testData.accounts.get(0).Id
            );
            insert testOpp;

            Id pricebookId = Test.getStandardPriceBookId();
            PricebookEntry pbEntry = new PricebookEntry(
                Product2Id = testData.products[3].Id,
                PriceBook2Id = pricebookId,
                UnitPrice = 100,
                isActive = true,
                UseStandardPrice = false
            );
            insert pbEntry;

            OpportunityLineItem oppLineItem = new OpportunityLineItem(
                PriceBookEntryId = pbEntry.Id,
                OpportunityId = testOpp.Id,
                Quantity = 2,
                UnitPrice = 100
            );
            insert oppLineItem;

            ApexPages.StandardController stdController = new ApexPages.StandardController(testOpp);
            OpportunitySalesTax controller = new OpportunitySalesTax(stdController);

            controller.init();

            System.assertEquals(false, controller.isValidationPassed);

            String expectedErrorMessage =
                String.format(
                    OpportunitySalesTax.NO_AVAILABLE_TAXES,
                    new List<String>{
                        controller.theOpportunity.Account.Name,
                        OpportunitySalesTax.APPLICABLE_TYPES_OF_TAXES[0],
                        OpportunitySalesTax.APPLICABLE_TYPES_OF_TAXES[1]
                    }
                );

            System.assertEquals(expectedErrorMessage, ApexPages.getMessages()[0].getDetail());
        }
    }

    @IsTest
    public static void testOpportunitySalesTaxesTotalInitLLP() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true).setLineLevelPost().createProducts().createAccountTaxes();

        System.runAs(testData.users[1]) {
            Opportunity testOpp = new Opportunity(
                Name = 'Test Opp',
                StageName = 'Closed Won',
                CloseDate = Date.today(),
                AccountId = testData.accounts.get(0).Id
            );
            insert testOpp;

            Id pricebookId = Test.getStandardPriceBookId();
            PricebookEntry pbEntry = new PricebookEntry(
                Product2Id = testData.products[3].Id,
                PriceBook2Id = pricebookId,
                UnitPrice = 100,
                isActive = true,
                UseStandardPrice = false
            );
            insert pbEntry;

            PricebookEntry pbEntry2 = new PricebookEntry(
                Product2Id = testData.products[4].Id,
                PriceBook2Id = pricebookId,
                UnitPrice = 50,
                isActive = true,
                UseStandardPrice = false
            );
            insert pbEntry2;

            OpportunityLineItem oppLineItem = new OpportunityLineItem(
                PriceBookEntryId = pbEntry.Id,
                OpportunityId = testOpp.Id,
                Quantity = 2,
                UnitPrice = 100,
                Discount = 10
            );
            insert oppLineItem;

            ApexPages.StandardController stdController = new ApexPages.StandardController(testOpp);
            OpportunitySalesTax controller = new OpportunitySalesTax(stdController);

            controller.init();

            System.assertEquals(true, controller.isValidationPassed);
            System.assertEquals(180, controller.dobTotal[0]);
        }
    }

    @IsTest
    public static void testOpportunitySalesTaxHLP() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true).createProducts().createTaxGroups();

        System.runAs(testData.users[1]) {
            Opportunity testOpp = new Opportunity(
                Name = 'Test Opp',
                StageName = 'Closed Won',
                CloseDate = Date.today(),
                AccountId = testData.accounts.get(0).Id
            );
            insert testOpp;

            Id pricebookId = Test.getStandardPriceBookId();
            PricebookEntry pbEntry = new PricebookEntry(
                Product2Id = testData.products[3].Id,
                PriceBook2Id = pricebookId,
                UnitPrice = 100,
                isActive = true,
                UseStandardPrice = false
            );
            insert pbEntry;

            OpportunityLineItem oppLineItem = new OpportunityLineItem(
                PriceBookEntryId = pbEntry.Id,
                OpportunityId = testOpp.Id,
                Quantity = 2,
                UnitPrice = 100,
                Tax_Group__c = testData.taxGroups[0].Id
            );
            insert oppLineItem;

            ApexPages.StandardController stdController = new ApexPages.StandardController(testOpp);
            OpportunitySalesTax controller = new OpportunitySalesTax(stdController);

            controller.init();

            System.assertEquals(true, controller.isValidationPassed);
            System.assertEquals(200, controller.hlpOpportunityDataWrapper.opportunityLineItems[0].getLineSubTotal());
            System.assertEquals(220, controller.hlpOpportunityDataWrapper.opportunityLineItems[0].getLineTotal());
            System.assertEquals(220, controller.hlpOpportunityDataWrapper.getEstimatedTotal());
            System.assertEquals(testOpp.Id, controller.hlpOpportunityDataWrapper.opportunity.Id);
            System.assertEquals(1, controller.hlpOpportunityDataWrapper.opportunityLineItems.size());
        }
    }

    @IsTest
    public static void testOpportunitySalesTaxWithDiscountHLP() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true).createProducts().createTaxGroups();

        System.runAs(testData.users[1]) {
            Opportunity testOpp = new Opportunity(
                Name = 'Test Opp',
                StageName = 'Closed Won',
                CloseDate = Date.today(),
                AccountId = testData.accounts.get(0).Id
            );
            insert testOpp;

            Id pricebookId = Test.getStandardPriceBookId();
            PricebookEntry pbEntry = new PricebookEntry(
                Product2Id = testData.products[3].Id,
                PriceBook2Id = pricebookId,
                UnitPrice = 100,
                isActive = true,
                UseStandardPrice = false
            );
            insert pbEntry;

            OpportunityLineItem oppLineItem = new OpportunityLineItem(
                PriceBookEntryId = pbEntry.Id,
                OpportunityId = testOpp.Id,
                Quantity = 2,
                UnitPrice = 100,
                Discount = 10,
                Tax_Group__c = testData.taxGroups[0].Id
            );
            insert oppLineItem;

            ApexPages.StandardController stdController = new ApexPages.StandardController(testOpp);
            OpportunitySalesTax controller = new OpportunitySalesTax(stdController);

            controller.init();

            System.assertEquals(true, controller.isValidationPassed);
            System.assertEquals(180, controller.hlpOpportunityDataWrapper.opportunityLineItems[0].getLineSubTotal());
            System.assertEquals(198, controller.hlpOpportunityDataWrapper.opportunityLineItems[0].getLineTotal());
            System.assertEquals(198, controller.hlpOpportunityDataWrapper.getEstimatedTotal());
            System.assertEquals(testOpp.Id, controller.hlpOpportunityDataWrapper.opportunity.Id);
            System.assertEquals(1, controller.hlpOpportunityDataWrapper.opportunityLineItems.size());
        }
    }

    public static testmethod void testAccountPayablePurchaseTaxTaxableProductsExisted() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true)
            .setLineLevelPost()
            .createProducts()
            .createAccountTaxes();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Opportunity testOpp = new Opportunity(
                Name = 'Test Opp',
                StageName = 'Closed Won',
                CloseDate = Date.today(),
                AccountId = testData.accounts.get(0).Id
            );
            insert testOpp;

            Id pricebookId = Test.getStandardPriceBookId();
            PricebookEntry pbEntry = new PricebookEntry(
                Product2Id = testData.products[3].Id,
                PriceBook2Id = pricebookId,
                UnitPrice = 100,
                isActive = true,
                UseStandardPrice = false
            );
            insert pbEntry;

            PricebookEntry pbEntry2 = new PricebookEntry(
                Product2Id = testData.products[4].Id,
                PriceBook2Id = pricebookId,
                UnitPrice = 50,
                isActive = true,
                UseStandardPrice = false
            );
            insert pbEntry2;

            OpportunityLineItem oppLineItem = new OpportunityLineItem(
                PriceBookEntryId = pbEntry.Id,
                OpportunityId = testOpp.Id,
                Quantity = 2,
                UnitPrice = 100,
                Discount = 10
            );
            insert oppLineItem;

            ApexPages.StandardController stdController = new ApexPages.StandardController(testOpp);
            OpportunitySalesTax controller = new OpportunitySalesTax(stdController);

            controller.init();

            System.assertEquals(true, controller.isValidationPassed);
            System.assertEquals(180, controller.dobTotal[0]);
            PageReference ref = controller.save();

            System.assertNotEquals(NULL, ref);
            System.assert(String.valueOf(ref).contains(testOpp.Id));
            System.assertEquals(
                1,
                [SELECT count() FROM OpportunityLineItem WHERE PriceBookEntry.Product2.Accounting_Type__c = 'Tax Rate']
            );
            System.assertEquals(1, controller.taxTableData.size());
            System.assertEquals(testData.products[3].Name, controller.taxTableData[0].taxableProducts.values()[0].values()[0]);
            System.assertEquals(
                controller.taxTableData[0].taxAmountTotal,
                [SELECT Id, UnitPrice FROM OpportunityLineItem WHERE PriceBookEntry.Product2.Accounting_Type__c = 'Tax Rate'].UnitPrice
            );
        }

    }

}