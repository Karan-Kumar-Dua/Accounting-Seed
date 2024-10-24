@IsTest
private class OpportunitySalesAvaTaxTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true, true, true);
    }

    @IsTest
    private static void testEstimateTaxLLP() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true)
            .setLineLevelPost()
            .enableAvaTaxCalculation();

        System.runAs(testData.users.get(1)) {
            //add Sales Tax Product to the Standard PriceBook
            Product2 salesTaxProduct = testData.products[5];
            Id standardPriceBookId = Test.getStandardPricebookId();
            List<PricebookEntry> pbEntries = new List<PricebookEntry>();
            PricebookEntry salesTaxPricebookEntry = new PricebookEntry(
                Product2Id = salesTaxProduct.Id,
                PriceBook2Id = standardPriceBookId,
                UnitPrice = 0,
                IsActive = true,
                UseStandardPrice = false
            );
            pbEntries.add(salesTaxPricebookEntry);
            //add Product to the Standard PriceBook
            PricebookEntry testProductPricebookEntry = new PricebookEntry(
                Product2Id = testData.products[3].Id,
                PriceBook2Id = standardPriceBookId,
                UnitPrice = 100,
                IsActive = true,
                UseStandardPrice = false
            );
            pbEntries.add(testProductPricebookEntry);
            insert pbEntries;

            Opportunity testOpportunity = new Opportunity(
                Name = 'TestOpp',
                AccountId = testData.accounts[0].Id,
                CloseDate = Date.today(),
                StageName = 'Closed Won'
            );
            insert testOpportunity;

            OpportunityLineItem testOpportunityLine = new OpportunityLineItem(
                OpportunityId = testOpportunity.Id,
                PricebookEntryId = testProductPricebookEntry.Id,
                Quantity = 1,
                UnitPrice = testProductPricebookEntry.UnitPrice
            );
            insert testOpportunityLine;

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(testOpportunity, new List<OpportunityLineItem>{testOpportunityLine}, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();
            OpportunitySalesAvaTax controller = new OpportunitySalesAvaTax(new ApexPages.StandardController(testOpportunity));
            System.assertEquals(false, controller.isError);

            controller.estimateTax();
            System.assertNotEquals(true, controller.oppLineItemsWithEstimatedTaxAmount.isEmpty());
            System.assertEquals(testOpportunityLine.UnitPrice * 10/100, controller.oppLineItemsWithEstimatedTaxAmount[0].opportunityLineItem.UnitPrice);
        }
    }

    @IsTest
    private static void testEstimateTaxHLP() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true)
            .createProducts()
            .enableAvaTaxCalculation();

        System.runAs(testData.users.get(1)) {
            //add Sales Tax Product to the Standard PriceBook
            Product2 salesTaxProduct = testData.products[5];
            Id standardPriceBookId = Test.getStandardPricebookId();
            List<PricebookEntry> pbEntries = new List<PricebookEntry>();
            PricebookEntry salesTaxPricebookEntry = new PricebookEntry(
                Product2Id = salesTaxProduct.Id,
                PriceBook2Id = standardPriceBookId,
                UnitPrice = 0,
                IsActive = true,
                UseStandardPrice = false
            );
            pbEntries.add(salesTaxPricebookEntry);
            //add Product to the Standard PriceBook
            PricebookEntry testProductPricebookEntry = new PricebookEntry(
                Product2Id = testData.products[3].Id,
                PriceBook2Id = standardPriceBookId,
                UnitPrice = 100,
                IsActive = true,
                UseStandardPrice = false
            );
            pbEntries.add(testProductPricebookEntry);
            insert pbEntries;

            Opportunity testOpportunity = new Opportunity(
                Name = 'TestOpp',
                AccountId = testData.accounts[0].Id,
                CloseDate = Date.today(),
                StageName = 'Closed Won'
            );
            insert testOpportunity;

            OpportunityLineItem testOpportunityLine = new OpportunityLineItem(
                OpportunityId = testOpportunity.Id,
                PricebookEntryId = testProductPricebookEntry.Id,
                Quantity = 1,
                UnitPrice = testProductPricebookEntry.UnitPrice
            );
            insert testOpportunityLine;

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(testOpportunity, new List<OpportunityLineItem>{testOpportunityLine}, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();
            OpportunitySalesAvaTax controller = new OpportunitySalesAvaTax(new ApexPages.StandardController(testOpportunity));
            System.assertEquals(false, controller.isError);

            controller.estimateTax();
            System.assertNotEquals(true, controller.oppLineItemsWithEstimatedTaxAmount.isEmpty());
            System.assertEquals(testOpportunityLine.UnitPrice * 10/100, controller.oppLineItemsWithEstimatedTaxAmount[0].getLineTaxAmount());

        }
    }

    @IsTest
    private static void testPrepareTaxLineModelWhenDiscountIncluded() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true)
            .createProducts()
            .enableAvaTaxCalculation();

        System.runAs(testData.users.get(1)) {
            //add Sales Tax Product to the Standard PriceBook
            Product2 salesTaxProduct = testData.products[5];
            Id standardPriceBookId = Test.getStandardPricebookId();
            List<PricebookEntry> pbEntries = new List<PricebookEntry>();
            PricebookEntry salesTaxPricebookEntry = new PricebookEntry(
                Product2Id = salesTaxProduct.Id,
                PriceBook2Id = standardPriceBookId,
                UnitPrice = 0,
                IsActive = true,
                UseStandardPrice = false
            );
            pbEntries.add(salesTaxPricebookEntry);
            //add Product to the Standard PriceBook
            PricebookEntry testProductPricebookEntry = new PricebookEntry(
                Product2Id = testData.products[3].Id,
                PriceBook2Id = standardPriceBookId,
                UnitPrice = 100,
                IsActive = true,
                UseStandardPrice = false
            );
            pbEntries.add(testProductPricebookEntry);
            insert pbEntries;

            Opportunity testOpportunity = new Opportunity(
                Name = 'TestOpp',
                AccountId = testData.accounts[0].Id,
                CloseDate = Date.today(),
                StageName = 'Closed Won'
            );
            insert testOpportunity;

            OpportunityLineItem testOpportunityLine = new OpportunityLineItem(
                OpportunityId = testOpportunity.Id,
                PricebookEntryId = testProductPricebookEntry.Id,
                Quantity = 1,
                Discount = 10,
                UnitPrice = testProductPricebookEntry.UnitPrice
            );
            insert testOpportunityLine;

            Test.startTest();
            Opportunity sourceRecord = AvaTaxHelper.queryOpportunityById(testOpportunity.Id);
            //since this test is eligible only if user has read access to the Discount field on OpportunityLineItem
            //we will check access first
            if (Schema.OpportunityLineItem.Discount.getDescribe().isAccessible()) {
                List<OpportunityLineItem> sourceRecordLines = AvaTaxHelper.queryTaxableOpportunityLineItemsByOpportunityId(testOpportunity, testData.ledgers[0].Id);
                AvaTaxHelper.sourceRecord = sourceRecord;
                AvaTaxHelper.sourceRecordLines = sourceRecordLines;
                List<AvaTaxService.LineItemModel> lines = AvaTaxHelper.getOpportunityLines();
                System.assertNotEquals(true, lines.isEmpty());
                System.assertEquals(testOpportunityLine.UnitPrice * ((100 - testOpportunityLine.Discount) / 100), lines[0].amount);
            }
        }
    }

    @IsTest
    private static void testCommitTaxLLP() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true)
            .setLineLevelPost()
            .enableAvaTaxCalculation();

        System.runAs(testData.users.get(1)) {
            //add Sales Tax Product to the Standard PriceBook
            Product2 salesTaxProduct = testData.products[5];
            Id standardPriceBookId = Test.getStandardPricebookId();
            List<PricebookEntry> pbEntries = new List<PricebookEntry>();
            PricebookEntry salesTaxPricebookEntry = new PricebookEntry(
                Product2Id = salesTaxProduct.Id,
                PriceBook2Id = standardPriceBookId,
                UnitPrice = 0,
                isActive = true,
                UseStandardPrice = false
            );
            pbEntries.add(salesTaxPricebookEntry);
            //add Product to the Standard PriceBook
            PricebookEntry testProductPricebookEntry = new PricebookEntry(
                Product2Id = testData.products[3].Id,
                PriceBook2Id = standardPriceBookId,
                UnitPrice = 100,
                IsActive = true,
                UseStandardPrice = false
            );
            pbEntries.add(testProductPricebookEntry);
            insert pbEntries;

            Opportunity testOpportunity = new Opportunity(
                Name = 'TestOpp',
                AccountId = testData.accounts[0].Id,
                CloseDate = Date.today(),
                StageName = 'Closed Won'
            );
            insert testOpportunity;

            OpportunityLineItem testOpportunityLine = new OpportunityLineItem(
                OpportunityId = testOpportunity.Id,
                PricebookEntryId = testProductPricebookEntry.Id,
                Quantity = 1,
                UnitPrice = testProductPricebookEntry.UnitPrice
            );
            insert testOpportunityLine;

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(testOpportunity, new List<OpportunityLineItem>{testOpportunityLine}, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();
            OpportunitySalesAvaTax controller = new OpportunitySalesAvaTax(new ApexPages.StandardController(testOpportunity));
            System.assertEquals(false, controller.isError);

            controller.commitTax();
            TaxService.sobjectByLedgerId = new Map<SObject, Id> {testOpportunity => testData.ledgers[0].Id};
            List<OpportunityLineItem> salesTaxLines = [
                SELECT Id, UnitPrice
                FROM OpportunityLineItem
                WHERE OpportunityId = :testOpportunity.Id
                AND Product2Id = :AvaTaxHelper.getSalesTaxProductId(testOpportunity)
            ];

            System.assertNotEquals(true, salesTaxLines.isEmpty());
            System.assertEquals(1, salesTaxLines.size());
            System.assertEquals(testOpportunityLine.UnitPrice * 10/100, salesTaxLines[0].UnitPrice);
        }
    }

    @IsTest
    private static void testCommitTaxHLP() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true)
            .createProducts()
            .enableAvaTaxCalculation();

        System.runAs(testData.users.get(1)) {
            //add Sales Tax Product to the Standard PriceBook
            Product2 salesTaxProduct = testData.products[5];
            Id standardPriceBookId = Test.getStandardPricebookId();
            List<PricebookEntry> pbEntries = new List<PricebookEntry>();
            PricebookEntry salesTaxPricebookEntry = new PricebookEntry(
                Product2Id = salesTaxProduct.Id,
                PriceBook2Id = standardPriceBookId,
                UnitPrice = 0,
                IsActive = true,
                UseStandardPrice = false
            );
            pbEntries.add(salesTaxPricebookEntry);
            //add Product to the Standard PriceBook
            PricebookEntry testProductPricebookEntry = new PricebookEntry(
                Product2Id = testData.products[3].Id,
                PriceBook2Id = standardPriceBookId,
                UnitPrice = 100,
                IsActive = true,
                UseStandardPrice = false
            );
            pbEntries.add(testProductPricebookEntry);
            insert pbEntries;

            Opportunity testOpportunity = new Opportunity(
                Name = 'TestOpp',
                AccountId = testData.accounts[0].Id,
                CloseDate = Date.today(),
                StageName = 'Closed Won'
            );
            insert testOpportunity;

            OpportunityLineItem testOpportunityLine = new OpportunityLineItem(
                OpportunityId = testOpportunity.Id,
                PricebookEntryId = testProductPricebookEntry.Id,
                Quantity = 1,
                UnitPrice = testProductPricebookEntry.UnitPrice
            );
            insert testOpportunityLine;

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(testOpportunity, new List<OpportunityLineItem>{testOpportunityLine}, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();
            OpportunitySalesAvaTax controller = new OpportunitySalesAvaTax(new ApexPages.StandardController(testOpportunity));
            System.assertEquals(false, controller.isError);

            controller.commitTax();

            List<OpportunityLineItem> opportunityLineItemsToValidate = [
                SELECT Id, UnitPrice, Tax_Amount__c
                FROM OpportunityLineItem
                WHERE OpportunityId = :testOpportunity.Id
            ];

            System.assertEquals(testOpportunityLine.UnitPrice * 10/100, opportunityLineItemsToValidate[0].Tax_Amount__c);
        }
    }

    @IsTest
    private static void testPageLoadNoLineForCalcTax() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true).enableAvaTaxCalculation();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Opportunity testOpportunity = new Opportunity(
                Name = 'TestOpp',
                AccountId = testData.accounts[0].Id,
                CloseDate = Date.today(),
                StageName = 'Closed Won'
            );
            insert testOpportunity;

            OpportunitySalesAvaTax controller = new OpportunitySalesAvaTax(new ApexPages.StandardController(testOpportunity));
            System.assertEquals(AbstractAvaTaxController.NO_LINES_ERROR_MESSAGE, ApexPages.getMessages()[0].getDetail());
        }
    }

    @IsTest
    private static void testPageLoadNonUSDCurrencyOnLedger_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance(false, true, true)
                .enableMultiCurrency()
                .enableAvaTaxCalculation();

            System.runAs(testData.users.get(1)) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Ledger__c testLedger = new Ledger__c(
                    Name = 'Actual 3',
                    Type__c = 'Transactional',
                    Default_Bank_Account__c = testData.glAccounts[0].Id,
                    Default_Billing_Format__c = testData.billingFormats[0].Id,
                    Billing_Outstanding_Statement_Format__c = testData.billingFormats[2].Id,
                    Billing_Activity_Statement_Format__c = testData.billingFormats[3].Id
                );
                testLedger.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert testLedger;

                Opportunity testOpportunity = new Opportunity(
                    Name = 'TestOpp',
                    AccountId = testData.accounts[0].Id,
                    CloseDate = Date.today(),
                    StageName = 'Closed Won'
                );
                testOpportunity.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert testOpportunity;

                //add Sales Tax Product to the Standard PriceBook
                Product2 salesTaxProduct = testData.products[5];
                Id standardPriceBookId = Test.getStandardPricebookId();
                List<PricebookEntry> pbEntries = new List<PricebookEntry>();
                PricebookEntry salesTaxPricebookEntry = new PricebookEntry(
                    Product2Id = salesTaxProduct.Id,
                    PriceBook2Id = standardPriceBookId,
                    UnitPrice = 0,
                    IsActive = true,
                    UseStandardPrice = false
                );
                salesTaxPricebookEntry.put('CurrencyIsoCode', newCurrencyIsoCode);
                pbEntries.add(salesTaxPricebookEntry);
                //add Product to the Standard PriceBook
                PricebookEntry testProductPricebookEntry = new PricebookEntry(
                    Product2Id = testData.products[3].Id,
                    PriceBook2Id = standardPriceBookId,
                    UnitPrice = 100,
                    IsActive = true,
                    UseStandardPrice = false
                );
                testProductPricebookEntry.put('CurrencyIsoCode', newCurrencyIsoCode);
                pbEntries.add(testProductPricebookEntry);
                insert pbEntries;

                OpportunityLineItem testOpportunityLine = new OpportunityLineItem(
                    OpportunityId = testOpportunity.Id,
                    PricebookEntryId = testProductPricebookEntry.Id,
                    Quantity = 1,
                    UnitPrice = testProductPricebookEntry.UnitPrice
                );
                insert testOpportunityLine;

                Test.startTest();
                OpportunitySalesAvaTax controller = new OpportunitySalesAvaTax(new ApexPages.StandardController(testOpportunity));
                controller.selectedLedger = testLedger.Id;
                controller.changeLedger();
                System.assertEquals(AbstractAvaTaxController.INCORRECT_CURRENCY_ERROR_MESSAGE, ApexPages.getMessages()[0].getDetail());
            }
        }
        catch (Exception ex) {

        }
    }

}