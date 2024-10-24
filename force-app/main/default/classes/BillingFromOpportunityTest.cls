@IsTest
public class BillingFromOpportunityTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true, true, true);
    }

    @IsTest
    public static void testNoAccountError() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true);

        System.runAs(testData.users[1]) {
            //create Closed Won Opportunity without Account
            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity 1234',
                CloseDate = Date.newInstance(1992, 1, 1),
                StageName = 'Closed Won',
                Amount = 100
            );
            insert opp;

            Opportunity newOpp = [
                SELECT Name, CloseDate, StageName, AccountId, IsWon, Amount, Description
                FROM Opportunity
                WHERE Id = :opp.Id
            ];
            ApexPages.StandardController controller = new ApexPages.StandardController(newOpp);
            BillingFromOpportunity cb = new BillingFromOpportunity(controller);
            //NO_ACCOUNT_ERROR expected
            System.assertEquals(AbstractBillingFromSource.NO_ACCOUNT_ERROR, ApexPages.getMessages()[0].getSummary());
        }

    }

    @IsTest
    public static void testNoAccountingPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true);

        System.runAs(testData.users[1]) {
            Account acct = new Account(Name = 'Test Account 1234');
            insert acct;

            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity 1234',
                CloseDate = Date.newInstance(1979, 1, 1),
                StageName = 'Closed Won',
                AccountId = acct.Id,
                Amount = 100
            );
            insert opp;

            Opportunity newOpp = [
                SELECT Name, CloseDate, StageName, AccountId, IsWon, Amount, Description
                FROM Opportunity
                WHERE Id = :opp.Id
            ];
            ApexPages.StandardController controller = new ApexPages.StandardController(newOpp);
            BillingFromOpportunity cb = new BillingFromOpportunity(controller);

            cb.createBilling();

            System.assertEquals(AbstractBillingFromSource.ACCOUNTING_PERIOD_ERROR, ApexPages.getMessages()[0].getSummary());
        }
    }

    @IsTest
    public static void testNoAccountingPeriodErrorAndThenActual() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true);

        System.runAs(testData.users[1]) {
            Account acct = new Account(Name = 'Test Account 1234');
            insert acct;

            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity 1234',
                CloseDate = Date.newInstance(1979, 1, 1),
                StageName = 'Closed Won',
                AccountId = acct.Id,
                Amount = 100
            );
            insert opp;

            Opportunity newOpp = [
                SELECT Name, CloseDate, StageName, AccountId, IsWon, Amount, Description
                FROM Opportunity
                WHERE Id = :opp.Id
            ];
            ApexPages.StandardController controller = new ApexPages.StandardController(newOpp);
            BillingFromOpportunity cb = new BillingFromOpportunity(controller);
            cb.billingsOpportunityWrappers[0].bill.Date__c = Date.newInstance(1979, 1, 5);
            cb.createBilling();

            System.assertEquals(AbstractBillingFromSource.ACCOUNTING_PERIOD_ERROR, ApexPages.getMessages()[0].getSummary());

            cb.billingsOpportunityWrappers[0].bill.Date__c = Date.newInstance(1992, 1, 2);
            cb.createBilling();
            System.assertEquals(cb.billingsOpportunityWrappers[0].bill.Id, [SELECT Id FROM Billing__c WHERE Opportunity__c = :opp.Id].Id);
        }
    }

    @IsTest
    public static void testBillingAlreadyExistsError() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true).createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Account acct = new Account(Name = 'Test Account 1234');
            insert acct;

            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity 1234',
                CloseDate = Date.newInstance(1992, 1, 1),
                StageName = 'Closed Won',
                AccountId = acct.Id,
                Amount = 100
            );
            insert opp;

            testData.billings[0].Opportunity__c = opp.Id;
            update testData.billings[0];

            Opportunity newOpp = [
                SELECT Name, CloseDate, StageName, AccountId, IsWon, Amount, Description
                FROM Opportunity
                WHERE Id = :opp.Id
            ];

            ApexPages.StandardController controller = new ApexPages.StandardController(newOpp);
            BillingFromOpportunity cb = new BillingFromOpportunity(controller);

            System.assertEquals(
                String.format(
                    AbstractBillingFromSource.BILLING_EXISTS_WARNING,
                    new List<String>{newOpp.getSObjectType().getDescribe().getName()}
                ),
                ApexPages.getMessages()[0].getSummary()
            );
            Test.stopTest();
        }

    }

    @IsTest
    public static void testCreateBillingSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true);

        System.runAs(testData.users[1]) {
            Test.startTest();
            Account acct = new Account(Name = 'Test Account 1234');
            insert acct;

            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity 1234',
                CloseDate = Date.newInstance(1974, 1, 1),
                StageName = 'Closed Won',
                AccountId = acct.Id,
                Description = 'This is a test',
                Amount = 100
            );
            insert opp;

            Id pricebookId = Test.getStandardPriceBookId();
            OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
            PricebookEntry[] pbeList = new List<PriceBookEntry>();
            Product2[] productList = new List<Product2>();

            for (Integer i = 0; i < 4; i++) {
                productList.add(new Product2(Name = 'Test ' + i, Revenue_GL_Account__c = testData.glAccounts[16].Id));
            }

            insert productList;

            for (Product2 product : productList) {
                pbeList.add(
                    new PricebookEntry(
                        Product2Id = product.Id,
                        PriceBook2Id = pricebookId,
                        UnitPrice = 2000,
                        isActive = true,
                        UseStandardPrice = false
                    )
                );
            }

            insert pbeList;

            for (PricebookEntry pbe : pbeList) {
                oliList.add(
                    new OpportunityLineItem(
                        PriceBookEntryId = pbe.Id,
                        OpportunityId = opp.Id,
                        Quantity = 2,
                        UnitPrice = 2000
                    )
                );
            }

            insert oliList;

            Opportunity newOpp = [
                SELECT Id, Name, CloseDate, StageName, AccountId, IsWon, Amount, Description
                FROM Opportunity
                WHERE Id = :opp.Id
            ];
            ApexPages.StandardController controller = new ApexPages.StandardController(newOpp);
            BillingFromOpportunity cb = new BillingFromOpportunity(controller);
            cb.billingsOpportunityWrappers[0].bill.Date__c = Date.newInstance(1992, 1, 2);

            cb.createBilling();

            String defaultStatusValue;
            for (Schema.PicklistEntry pickListEntry : Billing__c.Status__c.getDescribe().getPicklistValues()) {
                if (pickListEntry.isDefaultValue()) {
                    defaultStatusValue = pickListEntry.getValue();
                }
            }

            System.assertEquals(false, cb.showCommandButton);
            System.assertEquals(cb.billingsOpportunityWrappers[0].bill.Id, [SELECT Id FROM Billing__c WHERE Opportunity__c = :opp.Id].Id);

            System.assertEquals(
                opp.Description, [
                    SELECT Billing_Comment__c
                    FROM Billing__c
                    WHERE Opportunity__c = :cb.billingsOpportunityWrappers[0].opportunity.Id
                ].Billing_Comment__c
            );

            System.assertEquals(
                defaultStatusValue,
                [SELECT Status__c FROM Billing__c WHERE Opportunity__c = :cb.billingsOpportunityWrappers[0].opportunity.Id].Status__c
            );

            System.assertEquals(4, [SELECT COUNT() FROM OpportunityLineItem WHERE OpportunityId = :cb.billingsOpportunityWrappers[0].opportunity.Id]);

            System.assertEquals([
                    SELECT SUM(UnitPrice)
                    FROM OpportunityLineItem
                    WHERE OpportunityId = :cb.billingsOpportunityWrappers[0].opportunity.Id
                ], [
                    SELECT SUM(Rate__c)
                    FROM Billing_Line__c
                    WHERE Billing__c = :cb.billingsOpportunityWrappers[0].bill.Id
                ]
            );

            System.assertEquals([
                    SELECT SUM(TotalPrice)
                    FROM OpportunityLineItem
                    WHERE OpportunityId = :cb.billingsOpportunityWrappers[0].opportunity.Id
                ], [
                    SELECT SUM(Total__c)
                    FROM Billing_Line__c
                    WHERE Billing__c = :cb.billingsOpportunityWrappers[0].bill.Id
                ]
            );
            Test.stopTest();
        }
    }

    @IsTest
    public static void  testCreateBillingNoLinesSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true);

        System.runAs(testData.users[1]) {
            Account acct = new Account(Name = 'Test Account 1234');
            insert acct;

            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity 1234',
                CloseDate = Date.newInstance(1992, 1, 1),
                StageName = 'Closed Won',
                AccountId = acct.id,
                Amount = 1200
            );
            insert opp;

            Opportunity newOpp = [
                SELECT Name, CloseDate, StageName, AccountId, IsWon, Amount, Description
                FROM Opportunity
                WHERE Id = :opp.Id
            ];

            ApexPages.StandardController controller = new ApexPages.StandardController(newOpp);
            BillingFromOpportunity cb = new BillingFromOpportunity(controller);

            cb.createBillingAndPost();

            System.assertEquals(false, cb.showCommandButton);
            System.assertEquals(cb.billingsOpportunityWrappers[0].bill.Id, [SELECT Id FROM Billing__c WHERE Opportunity__c = :cb.billingsOpportunityWrappers[0].opportunity.Id].Id);
        }

    }

    @IsTest
    public static void  testCreateBillingNoAccPeriodBillingError() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true);

        System.runAs(testData.users[1]) {
            Account acct = new Account(Name = 'Test Account 1234');
            insert acct;

            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity 1234',
                CloseDate = Date.newInstance(1992, 1, 1),
                StageName = 'Closed Won',
                accountId = acct.id,
                amount = 1200
            );
            insert opp;

            Opportunity newOpp = [
                SELECT Name, CloseDate, StageName, AccountId, IsWon, Amount, Description
                FROM Opportunity
                WHERE Id = :opp.Id
            ];

            ApexPages.StandardController controller = new ApexPages.StandardController(newOpp);
            BillingFromOpportunity cb = new BillingFromOpportunity(controller);

            cb.billingsOpportunityWrappers[0].bill.Date__c = Date.valueOf('1983-10-11');
            cb.createBilling();

            System.assertEquals(true, cb.showCommandButton);
            System.assertEquals(AbstractBillingFromSource.ACCOUNTING_PERIOD_ERROR, ApexPages.getMessages()[0].getSummary());
            System.assertEquals(NULL, cb.billingsOpportunityWrappers[0].bill.Id);
        }

    }

    @IsTest
    public static void  testCreateBillingNoLinesError() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true);

        System.runAs(testData.users[1]) {
            Account acct = new Account(Name = 'Test Account 1234');
            insert acct;

            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity 1234',
                CloseDate = Date.newInstance(1992, 1, 1),
                StageName = 'Closed Won',
                accountId = acct.id,
                amount = 1200
            );
            insert opp;

            Opportunity newOpp = [
                SELECT Name, CloseDate, StageName, AccountId, IsWon, Amount, Description
                FROM Opportunity
                WHERE Id = :opp.Id
            ];
            ApexPages.StandardController controller = new ApexPages.StandardController(newOpp);
            BillingFromOpportunity cb = new BillingFromOpportunity(controller);
            for (AbstractBillingFromSource.BillingLineWrapper bl : cb.wrappedLines) {
                bl.isSelected = false;
            }

            cb.createBilling();

            System.assertEquals(true, cb.showCommandButton);
            System.assertEquals(AbstractBillingFromSource.NO_RBLINES_SELECTED_ERROR, ApexPages.getMessages()[0].getSummary());
            System.assertEquals(NULL, cb.billingsOpportunityWrappers[0].bill.Id);
        }

    }

    @IsTest
    public static void testCreateBillingCashSaleModeSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true);

        System.runAs(testData.users[1]) {
            Test.startTest();
            Account acct = new Account(Name = 'Test Account 1234');
            insert acct;

            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity 1234',
                CloseDate = Date.newInstance(1992, 1, 1),
                StageName = 'Closed Won',
                AccountId = acct.Id,
                Amount = 100
            );
            insert opp;

            Id pricebookId = Test.getStandardPriceBookId();
            OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
            PricebookEntry[] pbeList = new List<PriceBookEntry>();
            Product2[] productList = new List<Product2>();

            for (Integer i = 0; i < 4; i++) {
                productList.add(new Product2(Name = 'Test ' + i, Revenue_GL_Account__c = testData.glAccounts[16].Id));
            }

            insert productList;

            for (Product2 product : productList) {
                pbeList.add(new PricebookEntry(Product2Id = product.Id, PriceBook2Id = pricebookId, UnitPrice = 4000, isActive = true, UseStandardPrice = false));
            }

            insert pbeList;

            for (PricebookEntry pbe : pbeList) {
                oliList.add(new OpportunityLineItem(PriceBookEntryId = pbe.Id, OpportunityId = opp.Id, Quantity = 2, UnitPrice = 4000));
            }

            insert oliList;

            Opportunity newOpp = [
                SELECT Name, CloseDate, StageName, AccountId, IsWon, Amount, Description
                FROM Opportunity
                WHERE Id = :opp.Id
            ];

            ApexPages.StandardController controller = new ApexPages.StandardController(newOpp);
            BillingFromOpportunity cb = new BillingFromOpportunity(controller);
            cb.isCashSale = true;
            cb.billingsOpportunityWrappers[0].bill.Status__c = 'In Process';

            System.assertNotEquals(NULL, cb.createBilling());
            System.assertEquals(1, [SELECT count() FROM Billing__c WHERE Id = :cb.billingsOpportunityWrappers[0].bill.Id]);
            System.assertEquals(1, [SELECT count() FROM Billing_Cash_Receipt__c WHERE Billing__c = :cb.billingsOpportunityWrappers[0].bill.Id]);
            Test.stopTest();
        }

    }

    @IsTest
    public static void testCreateBillingDiscountTotalPriceSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true);

        System.runAs(testData.users[1]) {
            Account acct = new Account(Name = 'Test Account 1234');
            insert acct;

            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity 1234',
                CloseDate = Date.newInstance(1992, 1, 1),
                StageName = 'Closed Won',
                AccountId = acct.Id
            );
            insert opp;

            Id pricebookId = Test.getStandardPriceBookId();
            OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
            PricebookEntry[] pbeList = new List<PriceBookEntry>();
            Product2[] productList = new List<Product2>();

            for (Integer i = 0; i < 4; i++) {
                productList.add(new Product2(Name = 'Test ' + i, Revenue_GL_Account__c = testData.glAccounts[16].Id));
            }

            insert productList;

            for (Product2 product : productList) {
                pbeList.add(
                    new PricebookEntry(
                        Product2Id = product.Id,
                        PriceBook2Id = pricebookId,
                        UnitPrice = 1000,
                        IsActive = true,
                        UseStandardPrice = false
                    )
                );
            }

            insert pbeList;

            for (PricebookEntry pbe : pbeList) {
                oliList.add(
                    new OpportunityLineItem(
                        PriceBookEntryId = pbe.Id,
                        OpportunityId = opp.Id,
                        Quantity = 2,
                        UnitPrice = 1000,
                        Discount = 10
                    )
                );
            }

            insert oliList;

            Opportunity newOpp = [
                SELECT Name, CloseDate, StageName, AccountId, IsWon, Amount, Description
                FROM Opportunity
                WHERE Id = :opp.Id
            ];
            ApexPages.StandardController controller = new ApexPages.StandardController(newOpp);
            BillingFromOpportunity cb = new BillingFromOpportunity(controller);

            if (cb.createBilling() != NULL) {

                System.assertEquals(false, cb.showCommandButton);
                System.assertEquals(
                    cb.billingsOpportunityWrappers[0].bill.Id,
                    [SELECT Id FROM Billing__c WHERE Opportunity__c = :cb.billingsOpportunityWrappers[0].opportunity.Id].Id
                );
                System.assertEquals(
                    4,
                    [SELECT COUNT() FROM OpportunityLineItem WHERE OpportunityId = :cb.billingsOpportunityWrappers[0].opportunity.Id]
                );

                Map<Id, OpportunityLineItem> oppProdMap = new Map<Id, OpportunityLineItem>([
                    SELECT Id, ListPrice, UnitPrice, TotalPrice, Discount, Quantity, PricebookEntry.Product2Id
                    FROM OpportunityLineItem
                    WHERE OpportunityId = :cb.billingsOpportunityWrappers[0].opportunity.Id
                ]);

                for (Billing_Line__c billLine : [SELECT Total__c,
                                                        Rate__c,
                                                        Hours_Units__c,
                                                        Product__c,
                                                        Discount_Amt__c,
                                                        Discount_Pct__c,
                                                        List_Price__c,
                                                        Opportunity_Product_Id__c
                                                FROM Billing_Line__c
                                                WHERE Billing__c = :cb.billingsOpportunityWrappers[0].bill.Id]) {

                    OpportunityLineItem oli = oppProdMap.get(billLine.Opportunity_Product_Id__c);

                    System.assertEquals(oli.ListPrice, billLine.List_Price__c);
                    System.assertEquals(oli.TotalPrice, billLine.Total__c);
                    System.assertEquals(oli.UnitPrice * ((100 - oli.Discount) / 100), billLine.Rate__c);
                    System.assertEquals(oli.Quantity, billLine.Hours_Units__c);
                    System.assertEquals(oli.ListPrice - (oli.UnitPrice * ((100 - oli.Discount) / 100)), billLine.Discount_Amt__c);
                    System.assertEquals(oli.Discount, billLine.Discount_Pct__c);
                }
            }
            else {
                System.assert(ApexPages.getMessages().get(0).getDetail().contains(Label.INF_FLS_PERMISSION));
            }
        }

    }

    @IsTest
    public static void  testCreateBillingDiscountUnitPriceSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true);

        System.runAs(testData.users[1]) {
            Account acct = new Account(Name = 'Test Account 1234');
            insert acct;

            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity 1234',
                CloseDate = Date.newInstance(1992, 1, 1),
                StageName = 'Closed Won',
                AccountId = acct.Id,
                Amount = 100
            );
            insert opp;

            Id pricebookId = Test.getStandardPriceBookId();
            OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
            PricebookEntry[] pbeList = new List<PriceBookEntry>();
            Product2[] productList = new List<Product2>();

            for (Integer i = 0; i < 4; i++) {
                productList.add(new Product2(Name = 'Test ' + i, Revenue_GL_Account__c = testData.glAccounts[16].Id));
            }

            insert productList;

            for (Product2 product : productList) {
                pbeList.add(
                    new PricebookEntry(
                        Product2Id = product.Id,
                        PriceBook2Id = pricebookId,
                        UnitPrice = 4000,
                        isActive = true,
                        UseStandardPrice = false
                    )
                );
            }

            insert pbeList;

            for (PricebookEntry pbe : pbeList) {
                oliList.add(
                    new OpportunityLineItem(
                        PriceBookEntryId = pbe.Id,
                        OpportunityId = opp.Id,
                        Quantity = 2,
                        Discount = 10,
                        UnitPrice = 4000
                    )
                );
            }

            insert oliList;

            Opportunity newOpp = [
                SELECT Name, CloseDate, StageName, AccountId, IsWon, Amount, Description
                FROM Opportunity
                WHERE Id = :opp.Id
            ];
            ApexPages.StandardController controller = new ApexPages.StandardController(newOpp);
            BillingFromOpportunity cb = new BillingFromOpportunity(controller);

            if (cb.createBilling() != null) {

                System.assertEquals(false, cb.showCommandButton);
                System.assertEquals(
                    cb.billingsOpportunityWrappers[0].bill.Id,
                    [SELECT Id FROM Billing__c WHERE Opportunity__c = :cb.billingsOpportunityWrappers[0].opportunity.Id].Id
                );
                System.assertEquals(
                    4,
                    [SELECT count() FROM OpportunityLineItem WHERE OpportunityId = :cb.billingsOpportunityWrappers[0].opportunity.Id]
                );

                Map<Id, OpportunityLineItem> oppProdMap = new Map<Id, OpportunityLineItem>([
                    SELECT Id, ListPrice, UnitPrice, Discount, Quantity, PricebookEntry.Product2Id
                    FROM OpportunityLineItem
                    WHERE OpportunityId = :cb.billingsOpportunityWrappers[0].opportunity.Id
                ]);

                for (Billing_Line__c billLine : [SELECT Total__c,
                                                        Rate__c,
                                                        Hours_Units__c,
                                                        Product__c,
                                                        Discount_Amt__c,
                                                        Discount_Pct__c,
                                                        List_Price__c,
                                                        Opportunity_Product_Id__c
                                                FROM Billing_Line__c
                                                WHERE Billing__c = :cb.billingsOpportunityWrappers[0].bill.Id]) {

                    OpportunityLineItem oli = oppProdMap.get(billLine.Opportunity_Product_Id__c);
                    System.assertEquals(oli.UnitPrice, billLine.List_Price__c);
                    System.assertEquals(oli.UnitPrice * ((100 - oli.Discount) / 100), billLine.Rate__c);
                    System.assertEquals(oli.Quantity, billLine.Hours_Units__c);
                    System.assertEquals(oli.Discount, billLine.Discount_Pct__c);
                }
            }
            else {
                System.assert(ApexPages.getMessages().get(0).getDetail().contains(Label.INF_FLS_PERMISSION));
            }

        }

    }

    @IsTest
    public static void testIsOpportunityDiscountTrue() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true);

        System.runAs(testData.users[1]) {
            Account acct = new Account(Name = 'Test Account 1234');
            insert acct;

            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity 1234',
                CloseDate = Date.newInstance(1992, 1, 1),
                StageName = 'Closed Won',
                accountId = acct.Id,
                Amount = 100
            );
            insert opp;

            Id pricebookId = Test.getStandardPriceBookId();
            OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
            PricebookEntry[] pbeList = new List<PriceBookEntry>();
            Product2[] productList = new List<Product2>();

            for (Integer i = 0; i < 4; i++) {
                productList.add(new Product2(Name = 'Test ' + i, Revenue_GL_Account__c = testData.glAccounts[16].Id));
            }

            insert productList;

            for (Product2 product : productList) {
                pbeList.add(
                    new PricebookEntry(
                        Product2Id = product.Id,
                        PriceBook2Id = pricebookId,
                        UnitPrice = 4000,
                        isActive = true,
                        UseStandardPrice = false
                    )
                );
            }

            insert pbeList;

            for (PricebookEntry pbe : pbeList) {
                oliList.add(
                    new OpportunityLineItem(
                        PriceBookEntryId = pbe.Id,
                        OpportunityId = opp.Id,
                        Quantity = 2,
                        UnitPrice = 4000,
                        Discount = .33
                    )
                );
            }

            insert oliList;

            Opportunity newOpp = [
                SELECT Name, CloseDate, StageName, AccountId, IsWon, Amount, Description
                FROM Opportunity
                WHERE Id = :opp.Id
            ];

            ApexPages.StandardController controller = new ApexPages.StandardController(newOpp);
            BillingFromOpportunity cb = new BillingFromOpportunity(controller);
            System.assertEquals(true, DomainUtils.isDiscountIncludedInOpportunityLineItems(new Set<Id>{opp.Id}));
        }
    }

    @IsTest
    public static void testIsOpportunityDiscountFalse() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true);

        System.runAs(testData.users[1]) {
            Account acct = new Account(Name = 'Test Account 1234');
            insert acct;

            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity 1234',
                CloseDate = Date.newInstance(1992, 1, 1),
                StageName = 'Closed Won',
                accountId = acct.Id,
                Amount = 100
            );
            insert opp;

            Id pricebookId = Test.getStandardPriceBookId();
            OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
            PricebookEntry[] pbeList = new List<PriceBookEntry>();
            Product2[] productList = new List<Product2>();

            for (Integer i = 0; i < 4; i++) {
                productList.add(new Product2(Name = 'Test ' + i, Revenue_GL_Account__c = testData.glAccounts[16].Id));
            }

            insert productList;

            for (Product2 product : productList) {
                pbeList.add(
                    new PricebookEntry(
                        Product2Id = product.Id,
                        PriceBook2Id = pricebookId,
                        UnitPrice = 4000,
                        isActive = true,
                        UseStandardPrice = false
                    )
                );
            }

            insert pbeList;

            for (PricebookEntry pbe : pbeList) {
                oliList.add(
                    new OpportunityLineItem(
                        PriceBookEntryId = pbe.Id,
                        OpportunityId = opp.Id,
                        Quantity = 2,
                        UnitPrice = 4000
                    )
                );
            }

            insert oliList;

            Opportunity newOpp = [
                SELECT Name, CloseDate, StageName, AccountId, IsWon, Amount, Description
                FROM Opportunity
                WHERE Id = :opp.Id
            ];
            ApexPages.StandardController controller = new ApexPages.StandardController(newOpp);
            BillingFromOpportunity cb = new BillingFromOpportunity(controller);

            System.assertEquals(false, DomainUtils.isDiscountIncludedInOpportunityLineItems(new Set<Id>{opp.Id}));
        }
    }

    @IsTest
    public static void testCreateBillingCashSaleModeAndChangedProductPrice() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true);

        System.runAs(testData.users[1]) {
            Test.startTest();
            Account acct = new Account(Name = 'Test Account 1234');
            insert acct;

            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity 1234',
                CloseDate = Date.newInstance(1992, 1, 1),
                StageName = 'Closed Won',
                AccountId = acct.Id,
                Amount = 100
            );
            insert opp;

            Id pricebookId = Test.getStandardPriceBookId();
            List<OpportunityLineItem> oliList = new List<OpportunityLineItem>();
            List<PriceBookEntry> pbeList = new List<PriceBookEntry>();
            List<Product2> productList = new List<Product2>();

            for (Integer i = 0; i < 4; i++) {
                //not AR or AP control GL account only!
                productList.add(new Product2(Name = 'Test ' + i, Revenue_GL_Account__c = testData.glAccounts[16].Id));
            }

            insert productList;

            for (Product2 product : productList) {
                pbeList.add(
                    new PricebookEntry(
                        Product2Id = product.Id,
                        PriceBook2Id = pricebookId,
                        UnitPrice = 2000,
                        isActive = true,
                        UseStandardPrice = false
                    )
                );
            }

            insert pbeList;

            for (PricebookEntry pbe : pbeList) {
                oliList.add(
                    new OpportunityLineItem(
                        PriceBookEntryId = pbe.Id,
                        OpportunityId = opp.Id,
                        Quantity = 2,
                        UnitPrice = 2000,
                        Discount = 0
                    )
                );
            }

            insert oliList;

            Opportunity newOpp = [
                SELECT Name, CloseDate, StageName, AccountId, IsWon, Amount, Description
                FROM Opportunity
                WHERE Id = :opp.Id
            ];
            ApexPages.StandardController controller = new ApexPages.StandardController(newOpp);
            BillingFromOpportunity cb = new BillingFromOpportunity(controller);
            cb.isCashSale = true;

            for (AbstractBillingFromSource.BillingLineWrapper wrappedLine : cb.wrappedLines) {
                Decimal oldPrice = wrappedLine.billingLineRec.Rate__c;//2000
                Decimal newPrice = oldPrice + 1000;
                wrappedLine.billingLineRec.Rate__c = newPrice;//expected 3000 for each product
            }

            System.assertNotEquals(NULL, cb.createBilling());
            //check results section ================================================================================
            Billing__c billForCheck = [
                SELECT  Id,
                        Balance__c,
                        Received_Amount__c,
                        Total__c
                FROM Billing__c
                WHERE Id = :cb.billingsOpportunityWrappers[0].bill.Id
            ];

            System.assertEquals(24000, billForCheck.Total__c);//(3000*2)*4
            System.assertEquals(24000, billForCheck.Received_Amount__c);//roll-up from Billing Cash Receipts records
            System.assertEquals(0, billForCheck.Balance__c);//total - received

            Billing_Cash_Receipt__c crForCheck = [
                SELECT  Id,
                        Applied_Amount__c,
                        Cash_Receipt__r.Amount__c
                FROM Billing_Cash_Receipt__c
                WHERE Billing__c = :cb.billingsOpportunityWrappers[0].bill.Id

            ];
            //Billing Cash Receipt and Cash Receipt should have the same Amount
            System.assertEquals(24000, crForCheck.Applied_Amount__c);//Billing Cash Receipt Amount
            System.assertEquals(24000, crForCheck.Cash_Receipt__r.Amount__c);//Cash Receipt Amount
            //======================================================================================================
            Test.stopTest();
        }

    }

    @IsTest
    public static void testCreateListBillingSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true);

        System.runAs(testData.users[1]) {
            Account acct = new Account(Name = 'Test Account 1234');
            insert acct;

            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity 1234',
                CloseDate = Date.newInstance(1974, 1, 1),
                StageName = 'Closed Won',
                AccountId = acct.Id,
                Description = 'This is a test',
                Amount = 100
            );
            insert opp;

            Id pricebookId = Test.getStandardPriceBookId();
            OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
            PricebookEntry[] pbeList = new List<PriceBookEntry>();
            Product2[] productList = new List<Product2>();

            for (Integer i = 0; i < 4; i++) {
                //not AR or AP control GL account only!
                productList.add(new Product2(Name = 'Test ' + i, Revenue_GL_Account__c = testData.glAccounts[16].Id));
            }

            insert productList;

            for (Product2 product : productList) {
                pbeList.add(
                    new PricebookEntry(
                        Product2Id = product.Id,
                        PriceBook2Id = pricebookId,
                        UnitPrice = 2000,
                        isActive = true,
                        UseStandardPrice = false
                    )
                );
            }
            insert pbeList;

            for (PricebookEntry pbe : pbeList) {
                oliList.add(
                    new OpportunityLineItem(
                        PriceBookEntryId = pbe.Id,
                        OpportunityId = opp.Id,
                        Quantity = 2,
                        UnitPrice = 2000
                    )
                );
            }
            insert oliList;

            Opportunity newOpp = [
                SELECT Id, Name, CloseDate, StageName, AccountId, IsWon, Amount, Description
                FROM Opportunity
                WHERE Id = :opp.Id
            ];
            ApexPages.StandardSetController controller = new ApexPages.StandardSetController(new List<Opportunity> {newOpp});
            controller.setSelected(controller.getRecords());

            Test.startTest();
            BillingFromOpportunity cb = new BillingFromOpportunity(controller);
            cb.billingsOpportunityWrappers[0].bill.Date__c = Date.newInstance(1992, 1, 2);

            cb.createBillingAndPost();

            Test.stopTest();

            System.assertEquals(false, cb.showCommandButton);
            System.assertEquals(cb.billingsOpportunityWrappers[0].bill.Id, [SELECT Id FROM Billing__c WHERE Opportunity__c = :opp.Id].Id);
            System.assertEquals(testData.ledgers[0].Id, [SELECT Id, Ledger__c FROM Billing__c WHERE Opportunity__c = :opp.Id].Ledger__c);

            System.assertEquals(
                opp.Description, [
                    SELECT Billing_Comment__c
                    FROM Billing__c
                    WHERE Opportunity__c = :cb.billingsOpportunityWrappers[0].opportunity.Id
                ].Billing_Comment__c
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Billing__c WHERE Opportunity__c = :cb.billingsOpportunityWrappers[0].opportunity.Id].Status__c
            );

            System.assertEquals(4, [SELECT count() FROM OpportunityLineItem WHERE OpportunityId = :cb.billingsOpportunityWrappers[0].opportunity.Id]);

            System.assertEquals([
                    SELECT SUM(UnitPrice)
                    FROM OpportunityLineItem
                    WHERE OpportunityId = :cb.billingsOpportunityWrappers[0].opportunity.Id
                ], [
                    SELECT SUM(Rate__c)
                    FROM Billing_Line__c
                    WHERE Billing__c = :cb.billingsOpportunityWrappers[0].bill.Id
                ]
            );

            System.assertEquals([
                    SELECT SUM(TotalPrice)
                    FROM OpportunityLineItem
                    WHERE OpportunityId = :cb.billingsOpportunityWrappers[0].opportunity.Id
                ], [
                    SELECT SUM(Total__c)
                    FROM Billing_Line__c
                    WHERE Billing__c = :cb.billingsOpportunityWrappers[0].bill.Id
                ]
            );
        }
    }

    @IsTest
    public static void testCreateListBillingCashReceiptAndDepositSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true);

        System.runAs(testData.users[1]) {
            Test.startTest();
            Account acct = new Account(Name = 'Test Account 1234');
            insert acct;

            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity 1234',
                CloseDate = Date.newInstance(1974, 1, 1),
                StageName = 'Closed Won',
                AccountId = acct.Id,
                Description = 'This is a test',
                Amount = 100
            );
            insert opp;

            Id pricebookId = Test.getStandardPriceBookId();
            OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
            PricebookEntry[] pbeList = new List<PriceBookEntry>();
            Product2[] productList = new List<Product2>();

            for (Integer i = 0; i < 4; i++) {
                //not AR or AP control GL account only!
                productList.add(new Product2(Name = 'Test ' + i, Revenue_GL_Account__c = testData.glAccounts[16].Id));
            }

            insert productList;

            for (Product2 product : productList) {
                pbeList.add(
                    new PricebookEntry(
                        Product2Id = product.Id,
                        PriceBook2Id = pricebookId,
                        UnitPrice = 2000,
                        isActive = true,
                        UseStandardPrice = false
                    )
                );
            }

            insert pbeList;

            for (PricebookEntry pbe : pbeList) {
                oliList.add(
                    new OpportunityLineItem(
                        PriceBookEntryId = pbe.Id,
                        OpportunityId = opp.Id,
                        Quantity = 2,
                        UnitPrice = 2000
                    )
                );
            }

            insert oliList;

            Opportunity newOpp = [
                SELECT Id, Name, CloseDate, StageName, AccountId, IsWon, Amount, Description
                FROM Opportunity
                WHERE Id = :opp.Id
            ];
            ApexPages.StandardSetController controller = new ApexPages.StandardSetController(new List<Opportunity> {newOpp});
            controller.setSelected(controller.getRecords());
            BillingFromOpportunity cb = new BillingFromOpportunity(controller);
            cb.billingsOpportunityWrappers[0].bill.Date__c = Date.newInstance(1992, 1, 2);
            cb.isCashSale = true;
            cb.isDeposit = true;
            cb.createBillingAndPost();
            Test.stopTest();

            System.assertEquals(false, cb.showCommandButton);

            Cash_Receipt__c cr = [
                SELECT Id, Bank_Deposit__c
                FROM Cash_Receipt__c
                WHERE Id = :[SELECT Id, Cash_Receipt__c FROM Billing_Cash_Receipt__c WHERE Billing__c = :cb.billingsOpportunityWrappers[0].bill.Id].Cash_Receipt__c
            ];

            System.assertEquals(1, [SELECT COUNT() FROM Billing__c WHERE Id = :cb.billingsOpportunityWrappers[0].bill.Id]);
            System.assertEquals(1, [SELECT COUNT() FROM Cash_Receipt__c WHERE Id = :cr.Id]);
            System.assertEquals(1, [SELECT COUNT() FROM Billing_Cash_Receipt__c WHERE Billing__c = :cb.billingsOpportunityWrappers[0].bill.Id]);
            System.assertEquals(1, [SELECT COUNT() FROM Bank_Deposit__c WHERE Id = :cr.Bank_Deposit__c]);

            System.assertEquals(
                opp.Description, [
                    SELECT Billing_Comment__c
                    FROM Billing__c
                    WHERE Opportunity__c = :cb.billingsOpportunityWrappers[0].opportunity.Id
                ].Billing_Comment__c
            );

            System.assertEquals(
                'Posted',
                [SELECT Status__c FROM Billing__c WHERE Opportunity__c = :cb.billingsOpportunityWrappers[0].opportunity.Id].Status__c
            );

            System.assertEquals(4, [SELECT COUNT() FROM OpportunityLineItem WHERE OpportunityId = :cb.billingsOpportunityWrappers[0].opportunity.Id]);

            System.assertEquals([
                SELECT SUM(UnitPrice)
                FROM OpportunityLineItem
                WHERE OpportunityId = :cb.billingsOpportunityWrappers[0].opportunity.Id
            ], [
                SELECT SUM(Rate__c)
                FROM Billing_Line__c
                WHERE Billing__c = :cb.billingsOpportunityWrappers[0].bill.Id
            ]
            );

            System.assertEquals([
                SELECT SUM(TotalPrice)
                FROM OpportunityLineItem
                WHERE OpportunityId = :cb.billingsOpportunityWrappers[0].opportunity.Id
            ], [
                SELECT SUM(Total__c)
                FROM Billing_Line__c
                WHERE Billing__c = :cb.billingsOpportunityWrappers[0].bill.Id
            ]
            );
        }
    }

    @IsTest
    public static void testCreateListBillingCashReceiptAndDepositWhenAutopostNotEnabled() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true).disableAutoPostSourceDocuments();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Account acct = new Account(Name = 'Test Account 1234');
            insert acct;

            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity 1234',
                CloseDate = Date.newInstance(1974, 1, 1),
                StageName = 'Closed Won',
                AccountId = acct.Id,
                Description = 'This is a test',
                Amount = 100
            );
            insert opp;

            Id pricebookId = Test.getStandardPriceBookId();
            OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
            PricebookEntry[] pbeList = new List<PriceBookEntry>();
            Product2[] productList = new List<Product2>();

            for (Integer i = 0; i < 4; i++) {
                //not AR or AP control GL account only!
                productList.add(new Product2(Name = 'Test ' + i, Revenue_GL_Account__c = testData.glAccounts[16].Id));
            }

            insert productList;

            for (Product2 product : productList) {
                pbeList.add(
                    new PricebookEntry(
                        Product2Id = product.Id,
                        PriceBook2Id = pricebookId,
                        UnitPrice = 2000,
                        IsActive = true,
                        UseStandardPrice = false
                    )
                );
            }

            insert pbeList;

            for (PricebookEntry pbe : pbeList) {
                oliList.add(
                    new OpportunityLineItem(
                        PriceBookEntryId = pbe.Id,
                        OpportunityId = opp.Id,
                        Quantity = 2,
                        UnitPrice = 2000
                    )
                );
            }

            insert oliList;

            Opportunity newOpp = [
                SELECT Id, Name, CloseDate, StageName, AccountId, IsWon, Amount, Description
                FROM Opportunity
                WHERE Id = :opp.Id
            ];
            ApexPages.StandardSetController controller = new ApexPages.StandardSetController(new List<Opportunity> {newOpp});
            controller.setSelected(controller.getRecords());
            BillingFromOpportunity cb = new BillingFromOpportunity(controller);
            cb.billingsOpportunityWrappers[0].bill.Date__c = Date.newInstance(1992, 1, 2);
            cb.isCashSale = true;
            cb.isDeposit = true;
            cb.createBilling();
            Test.stopTest();

            System.assertEquals(false, cb.showCommandButton);

            Cash_Receipt__c cr = [
                SELECT Id, Bank_Deposit__c, Status__c
                FROM Cash_Receipt__c
                WHERE Id = :[SELECT Id, Cash_Receipt__c FROM Billing_Cash_Receipt__c WHERE Billing__c = :cb.billingsOpportunityWrappers[0].bill.Id].Cash_Receipt__c
            ];

            System.assertEquals(1, [SELECT COUNT() FROM Billing__c WHERE Id = :cb.billingsOpportunityWrappers[0].bill.Id]);
            System.assertEquals(1, [SELECT COUNT() FROM Cash_Receipt__c WHERE Id = :cr.Id]);
            System.assertEquals(1, [SELECT COUNT() FROM Billing_Cash_Receipt__c WHERE Billing__c = :cb.billingsOpportunityWrappers[0].bill.Id]);
            System.assertEquals(1, [SELECT COUNT() FROM Bank_Deposit__c WHERE Id = :cr.Bank_Deposit__c]);
            System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, cr.Status__c);
        }
    }

    @IsTest
    public static void testCreateListBillingCashReceiptAndDepositWhenAutopostNotEnabledFailedDuringPosting() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true).disableAutoPostSourceDocuments();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Account acct = new Account(Name = 'Test Account 1234');
            insert acct;

            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity 1234',
                CloseDate = Date.newInstance(1974, 1, 1),
                StageName = 'Closed Won',
                AccountId = acct.Id,
                Description = 'This is a test',
                Amount = 100
            );
            insert opp;

            Id pricebookId = Test.getStandardPriceBookId();
            OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
            PricebookEntry[] pbeList = new List<PriceBookEntry>();
            Product2[] productList = new List<Product2>();

            for (Integer i = 0; i < 4; i++) {
                //not AR or AP control GL account only!
                productList.add(new Product2(Name = 'Test ' + i, Revenue_GL_Account__c = testData.glAccounts[16].Id));
            }

            insert productList;

            for (Product2 product : productList) {
                pbeList.add(
                    new PricebookEntry(
                        Product2Id = product.Id,
                        PriceBook2Id = pricebookId,
                        UnitPrice = 2000,
                        IsActive = true,
                        UseStandardPrice = false
                    )
                );
            }

            insert pbeList;

            for (PricebookEntry pbe : pbeList) {
                oliList.add(
                    new OpportunityLineItem(
                        PriceBookEntryId = pbe.Id,
                        OpportunityId = opp.Id,
                        Quantity = 2,
                        UnitPrice = 2000
                    )
                );
            }

            insert oliList;

            Opportunity newOpp = [
                SELECT Id, Name, CloseDate, StageName, AccountId, IsWon, Amount, Description
                FROM Opportunity
                WHERE Id = :opp.Id
            ];
            ApexPages.StandardSetController controller = new ApexPages.StandardSetController(new List<Opportunity> {newOpp});
            controller.setSelected(controller.getRecords());
            //enable Cash Flow Statement feature on Accounting Setting but without setting of any defaults
            //this will lead to empty Cash Flow Category field on Cash Receipt record and this will enforce error during CR posting routine
            Accounting_Settings__c setting = AccountingSettingsHandler.getAccountingSettings();
            setting.Enable_Cash_Flow_Statement__c = true;
            AccountingSettingsActions.isPreventUpdateOverride = true;
            update setting;
            //====================================================================================================
            BillingFromOpportunity cb = new BillingFromOpportunity(controller);
            cb.billingsOpportunityWrappers[0].bill.Date__c = Date.newInstance(1992, 1, 2);
            cb.isCashSale = true;
            cb.isDeposit = true;
            cb.createBilling();
            Test.stopTest();

            System.assertEquals(BillingFromOpportunity.CASH_RECEIPT_POSTING_ERROR, ApexPages.getMessages()[0].getDetail());
        }
    }

    @IsTest
    public static void testCreateListBillingCashReceiptAndDepositSuccess_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance(false, true, true).enableMultiCurrency();

            System.runAs(testData.users[1]) {
                String newCurrency = SObjectActionsTest.getTheNewCurrencyIsoCode();

                if (String.isBlank(newCurrency)) {
                    return;
                }

                Test.startTest();

                Account acct = new Account(Name = 'Test Account 1234');
                acct.put('CurrencyIsoCode', UserInfo.getDefaultCurrency());
                insert acct;
                Account acct2 = new Account(Name = 'Test Account 1324');
                acct2.put('CurrencyIsoCode', newCurrency);
                insert acct2;

                List<Opportunity> opportunities = new List<Opportunity>();
                Opportunity opp = new Opportunity(
                    Name = 'Test Opportunity 1234',
                    CloseDate = Date.newInstance(1974, 1, 1),
                    StageName = 'Closed Won',
                    AccountId = acct.Id,
                    Description = 'This is a test',
                    Amount = 100
                );
                opp.put('CurrencyIsoCode', newCurrency);
                opportunities.add(opp);
                Opportunity opp2 = new Opportunity(
                    Name = 'Test Opportunity 1324',
                    CloseDate = Date.newInstance(1974, 1, 1),
                    StageName = 'Closed Won',
                    AccountId = acct2.Id,
                    Description = 'This is a test',
                    Amount = 100
                );
                opp2.put('CurrencyIsoCode', newCurrency);
                opportunities.add(opp2);
                insert opportunities;

                Set<Id> ids = new Set<Id> {opp.Id, opp2.Id};
                List<Opportunity> newOpp = Database.query(
                    'SELECT Id, Name, CloseDate, StageName, AccountId, IsWon, Amount, Description, CurrencyIsoCode ' +
                    'FROM Opportunity ' +
                    'WHERE Id IN :ids'
                );

                ApexPages.StandardSetController controller = new ApexPages.StandardSetController(newOpp);
                controller.setSelected(controller.getRecords());

                BillingFromOpportunity cb = new BillingFromOpportunity(controller);
                cb.billingsOpportunityWrappers[0].bill.Date__c = Date.newInstance(1992, 1, 2);
                cb.billingsOpportunityWrappers[1].bill.Date__c = Date.newInstance(1992, 1, 2);
                cb.isCashSale = true;
                cb.isDeposit = true;
                cb.createBilling();

                System.assertEquals(false, cb.showCommandButton);
                Cash_Receipt__c cr1 = Database.query(
                    'SELECT Id, Bank_Deposit__c, CurrencyIsoCode FROM Cash_Receipt__c WHERE Id = \'' + [SELECT Id, Cash_Receipt__c FROM Billing_Cash_Receipt__c WHERE Billing__c = :cb.billingsOpportunityWrappers[0].bill.Id].Cash_Receipt__c + '\'');
                Cash_Receipt__c cr2 = Database.query('SELECT Id, Bank_Deposit__c, CurrencyIsoCode FROM Cash_Receipt__c WHERE Id = \'' + [SELECT Id, Cash_Receipt__c FROM Billing_Cash_Receipt__c WHERE Billing__c = :cb.billingsOpportunityWrappers[1].bill.Id].Cash_Receipt__c + '\'');
                System.assertEquals(opp.get('CurrencyIsoCode'), cr2.get('CurrencyIsoCode'));
                System.assertEquals(opp2.get('CurrencyIsoCode'), cr1.get('CurrencyIsoCode'));

                Billing__c bill1 = Database.query('SELECT Id, CurrencyIsoCode FROM Billing__c WHERE Id = \'' + cb.billingsOpportunityWrappers[0].bill.Id + '\'');
                Billing__c bill2 = Database.query('SELECT Id, CurrencyIsoCode FROM Billing__c WHERE Id = \'' + cb.billingsOpportunityWrappers[1].bill.Id + '\'');
                System.assertEquals(opp.get('CurrencyIsoCode'), bill2.get('CurrencyIsoCode'));
                System.assertEquals(opp2.get('CurrencyIsoCode'), bill1.get('CurrencyIsoCode'));

                Bank_Deposit__c bd1 = Database.query('SELECT Id, CurrencyIsoCode FROM Bank_Deposit__c WHERE Id = \'' + cr1.Bank_Deposit__c + '\'');
                Bank_Deposit__c bd2 = Database.query('SELECT Id, CurrencyIsoCode FROM Bank_Deposit__c WHERE Id = \'' + cr2.Bank_Deposit__c + '\'');

                System.assertEquals(opp.get('CurrencyIsoCode'), bd2.get('CurrencyIsoCode'));
                System.assertEquals(opp2.get('CurrencyIsoCode'), bd1.get('CurrencyIsoCode'));

            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }

    }

    @IsTest
    public static void  testDifferentRevenueGLAccountSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true);

        System.runAs(testData.users[1]) {
            Account acct = new Account(Name = 'Test Account 1234');
            insert acct;

            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity 1234',
                CloseDate = Date.newInstance(1992, 1, 1),
                StageName = 'Closed Won',
                AccountId = acct.Id,
                Amount = 100
            );
            insert opp;

            Id pricebookId = Test.getStandardPriceBookId();
            OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
            PricebookEntry[] pbeList = new List<PriceBookEntry>();
            Product2[] productList = new List<Product2>();

            for (Integer i = 0; i < 4; i++) {
                productList.add(new Product2(Name = 'Test ' + i, Revenue_GL_Account__c = NULL));
            }
            insert productList;

            productList[0].Revenue_GL_Account__c = testData.glAccounts[17].Id;
            productList[1].Revenue_GL_Account__c = testData.glAccounts[17].Id;
            update productList;

            for (Product2 product : productList) {
                pbeList.add(new PricebookEntry(Product2Id = product.Id, PriceBook2Id = pricebookId, UnitPrice = 4000, isActive = true, UseStandardPrice = false));
            }
            insert pbeList;

            for (PricebookEntry pbe : pbeList) {
                oliList.add(new OpportunityLineItem(PriceBookEntryId = pbe.Id, OpportunityId = opp.Id, Quantity = 2, UnitPrice = 4000));
            }
            insert oliList;

            Opportunity newOpp = [
                SELECT Name, CloseDate, StageName, AccountId, IsWon, Amount, Description
                FROM Opportunity
                WHERE Id = :opp.Id
            ];
            ApexPages.StandardController controller = new ApexPages.StandardController(newOpp);
            BillingFromOpportunity cb = new BillingFromOpportunity(controller);

            System.assertNotEquals(NULL, cb.createBilling());

            List<Billing_Line__c> billLines = [
                SELECT Id, Billing__c, Revenue_GL_Account__c
                FROM Billing_Line__c
                WHERE Billing__c = :cb.billingsOpportunityWrappers[0].bill.Id
            ];

            System.assertEquals(testData.glAccounts[17].Id, billLines[0].Revenue_GL_Account__c);
            System.assertEquals(testData.glAccounts[17].Id, billLines[1].Revenue_GL_Account__c);
            System.assertEquals(testData.glAccounts[10].Id, billLines[2].Revenue_GL_Account__c);
            System.assertEquals(testData.glAccounts[10].Id, billLines[3].Revenue_GL_Account__c);
        }

    }

    @IsTest
    public static void testCreateBillingWithAvalaraEnabledOnCreateAndPost() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true).enableAvaTaxCalculation().setHeaderLevelPost();

        System.runAs(testData.users[1]) {
            Account acct = new Account(Name = 'Test Account 1234');
            insert acct;

            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity 1234',
                CloseDate = Date.newInstance(1992, 1, 2),
                StageName = 'Closed Won',
                AccountId = acct.Id,
                Description = 'This is a test',
                Amount = 0
            );
            insert opp;

            Id pricebookId = Test.getStandardPriceBookId();
            List<OpportunityLineItem> oliList = new List<OpportunityLineItem>();
            List<PriceBookEntry> pbeList = new List<PriceBookEntry>();
            List<Product2> productList = new List<Product2>();

            for (Integer i = 0; i < 4; i++) {
                productList.add(new Product2(Name = 'Test ' + i));
            }
            insert productList;

            for (Product2 product : productList) {
                pbeList.add(
                    new PricebookEntry(
                        Product2Id = product.Id,
                        PriceBook2Id = pricebookId,
                        UnitPrice = 100,
                        IsActive = true,
                        UseStandardPrice = false
                    )
                );
            }
            insert pbeList;

            for (PricebookEntry pbe : pbeList) {
                oliList.add(
                    new OpportunityLineItem(
                        PriceBookEntryId = pbe.Id,
                        OpportunityId = opp.Id,
                        Quantity = 2,
                        UnitPrice = 100
                    )
                );
            }
            insert oliList;

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(opp, oliList, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();

            ApexPages.StandardController controller = new ApexPages.StandardController(opp);
            BillingFromOpportunity cb = new BillingFromOpportunity(controller);
            System.assertEquals(4, cb.billingsOpportunityWrappers.get(0).billLines.size());

            cb.createBillingAndPost();

            Test.stopTest();

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, [
                    SELECT Id, Status__c FROM Billing__c WHERE Opportunity__c = :opp.Id
                ].Status__c
            );
        }
    }

    @IsTest
    public static void testCreateListBillingWithAvaTaxCalcOnInitialPageLoadHLP() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true)
            .enableAvaTaxCalculation();

        System.runAs(testData.users[1]) {
            Account acct = new Account(Name = 'Test Account 1234');
            insert acct;

            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity 1234',
                CloseDate = Date.today().addDays(-10),
                StageName = 'Closed Won',
                AccountId = acct.Id,
                Description = 'This is a test',
                Amount = 0
            );
            insert opp;

            Id pricebookId = Test.getStandardPriceBookId();
            List<OpportunityLineItem> oliList = new List<OpportunityLineItem>();
            List<PriceBookEntry> pbeList = new List<PriceBookEntry>();
            List<Product2> productList = new List<Product2>();

            for (Integer i = 0; i < 4; i++) {
                productList.add(new Product2(Name = 'Test ' + i));
            }
            insert productList;

            for (Product2 product : productList) {
                pbeList.add(
                    new PricebookEntry(
                        Product2Id = product.Id,
                        PriceBook2Id = pricebookId,
                        UnitPrice = 100,
                        isActive = true,
                        UseStandardPrice = false
                    )
                );
            }
            insert pbeList;

            for (PricebookEntry pbe : pbeList) {
                oliList.add(
                    new OpportunityLineItem(
                        PriceBookEntryId = pbe.Id,
                        OpportunityId = opp.Id,
                        Quantity = 2,
                        UnitPrice = 100
                    )
                );
            }
            insert oliList;

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(opp, oliList, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();

            ApexPages.StandardController controller = new ApexPages.StandardController(opp);
            BillingFromOpportunity cb = new BillingFromOpportunity(controller);

            System.assertEquals((100 * 2 * 4)/*subtotal*/ + ((100 * 2 * 4) * 0.10)/*Tax Amount*/, cb.billingsOpportunityWrappers.get(0).getTotalAmount());
        }
    }

    @IsTest
    public static void testCreateBillingWithAvalaraSalesTaxLineOnInitialPageLoad() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true)
            .setLineLevelPost()
            .enableAvaTaxCalculation();

        System.runAs(testData.users[1]) {
            Account acct = new Account(Name = 'Test Account 1234');
            insert acct;

            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity 1234',
                CloseDate = Date.today().addDays(-10),
                StageName = 'Closed Won',
                AccountId = acct.Id,
                Description = 'This is a test',
                Amount = 0
            );
            insert opp;

            Id pricebookId = Test.getStandardPriceBookId();
            List<OpportunityLineItem> oliList = new List<OpportunityLineItem>();
            List<PriceBookEntry> pbeList = new List<PriceBookEntry>();
            List<Product2> productList = new List<Product2>();

            for (Integer i = 0; i < 4; i++) {
                productList.add(new Product2(Name = 'Test ' + i));
            }
            insert productList;

            for (Product2 product : productList) {
                pbeList.add(
                    new PricebookEntry(
                        Product2Id = product.Id,
                        PriceBook2Id = pricebookId,
                        UnitPrice = 100,
                        isActive = true,
                        UseStandardPrice = false
                    )
                );
            }
            insert pbeList;

            for (PricebookEntry pbe : pbeList) {
                oliList.add(
                    new OpportunityLineItem(
                        PriceBookEntryId = pbe.Id,
                        OpportunityId = opp.Id,
                        Quantity = 2,
                        UnitPrice = 100
                    )
                );
            }
            insert oliList;

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(opp, oliList, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();

            ApexPages.StandardController controller = new ApexPages.StandardController(opp);
            BillingFromOpportunity cb = new BillingFromOpportunity(controller);

            System.assertEquals(4 + 1, cb.billingsOpportunityWrappers.get(0).billLines.size());
            System.assertEquals(
                (100 * 2 * 4) * cb.billingsOpportunityWrappers.get(0).getCurrencyConversionRate() / 10,
                cb.billingsOpportunityWrappers.get(0).billLines.get(4).billingLineRec.Rate__c
            );
        }
    }

    @IsTest
    public static void testCreateBillingWithAvalaraSalesTaxLineOnCreate() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true)
            .setLineLevelPost()
            .enableAvaTaxCalculation();

        System.runAs(testData.users[1]) {
            Account acct = new Account(Name = 'Test Account 1234');
            insert acct;

            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity 1234',
                CloseDate = Date.newInstance(1992, 1, 2),
                StageName = 'Closed Won',
                AccountId = acct.Id,
                Description = 'This is a test',
                Amount = 0
            );
            insert opp;

            Id pricebookId = Test.getStandardPriceBookId();
            List<OpportunityLineItem> oliList = new List<OpportunityLineItem>();
            List<PriceBookEntry> pbeList = new List<PriceBookEntry>();
            List<Product2> productList = new List<Product2>();

            for (Integer i = 0; i < 4; i++) {
                productList.add(new Product2(Name = 'Test ' + i));
            }
            insert productList;

            for (Product2 product : productList) {
                pbeList.add(
                    new PricebookEntry(
                        Product2Id = product.Id,
                        PriceBook2Id = pricebookId,
                        UnitPrice = 100,
                        isActive = true,
                        UseStandardPrice = false
                    )
                );
            }
            insert pbeList;

            for (PricebookEntry pbe : pbeList) {
                oliList.add(
                    new OpportunityLineItem(
                        PriceBookEntryId = pbe.Id,
                        OpportunityId = opp.Id,
                        Quantity = 2,
                        UnitPrice = 100
                    )
                );
            }
            insert oliList;

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(opp, oliList, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();

            ApexPages.StandardController controller = new ApexPages.StandardController(opp);
            BillingFromOpportunity cb = new BillingFromOpportunity(controller);

            System.assertEquals(4 + 1, cb.billingsOpportunityWrappers.get(0).billLines.size());
            System.assertEquals(
                (100 * 2 * 4) * cb.billingsOpportunityWrappers.get(0).getCurrencyConversionRate() / 10,
                cb.billingsOpportunityWrappers.get(0).billLines.get(4).billingLineRec.Rate__c
            );

            cb.createBilling();
            Test.stopTest();

            System.assertNotEquals(
                true, [
                    SELECT Id, Rate__c
                    FROM Billing_Line__c
                    WHERE Product__c = :AvaTaxHelper.getSalesTaxProductId(cb.billingsOpportunityWrappers.get(0).bill)
                ].isEmpty()
            );
        }
    }

    @IsTest
    public static void testDeselectAllLinesAvaTaxOnCreate_HLP() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true)
            .enableAvaTaxCalculation();

        System.runAs(testData.users[1]) {
            Account acct = new Account(Name = 'Test Account 1234');
            insert acct;

            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity 1234',
                CloseDate = Date.newInstance(1992, 1, 2),
                StageName = 'Closed Won',
                AccountId = acct.Id,
                Description = 'This is a test',
                Amount = 0
            );
            insert opp;

            Id pricebookId = Test.getStandardPriceBookId();
            List<OpportunityLineItem> oliList = new List<OpportunityLineItem>();
            List<PriceBookEntry> pbeList = new List<PriceBookEntry>();
            List<Product2> productList = new List<Product2>();

            for (Integer i = 0; i < 4; i++) {
                productList.add(new Product2(Name = 'Test ' + i));
            }
            insert productList;

            for (Product2 product : productList) {
                pbeList.add(
                    new PricebookEntry(
                        Product2Id = product.Id,
                        PriceBook2Id = pricebookId,
                        UnitPrice = 100,
                        IsActive = true,
                        UseStandardPrice = false
                    )
                );
            }
            insert pbeList;

            for (PricebookEntry pbe : pbeList) {
                oliList.add(
                    new OpportunityLineItem(
                        PriceBookEntryId = pbe.Id,
                        OpportunityId = opp.Id,
                        Quantity = 2,
                        UnitPrice = 100
                    )
                );
            }
            insert oliList;

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(opp, oliList, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();

            ApexPages.StandardController controller = new ApexPages.StandardController(opp);
            BillingFromOpportunity cb = new BillingFromOpportunity(controller);

            System.assertEquals(4, cb.billingsOpportunityWrappers.get(0).billLines.size());
            System.assertEquals(
                (100 * 2) * cb.billingsOpportunityWrappers.get(0).getCurrencyConversionRate() / 10,
                cb.billingsOpportunityWrappers.get(0).billLines.get(0).billingLineRec.Tax_Amount2__c
            );

            for (BillingFromOpportunity.BillingOpportunityWrapper billOppWrapper : cb.billingsOpportunityWrappers) {
                for (AbstractBillingFromSource.BillingLineWrapper wrappedLine : billOppWrapper.billLines) {
                    wrappedLine.isSelected = false;
                }
            }

            cb.createBilling();
            Test.stopTest();

            System.assertEquals(AbstractBillingFromSource.NO_RBLINES_SELECTED_ERROR, ApexPages.getMessages()[0].getSummary());
        }
    }

    @IsTest
    public static void testCreateBillingWithAvalaraSalesTaxLineOnCreateAndPost() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true)
            .setLineLevelPost()
            .enableAvaTaxCalculation();

        System.runAs(testData.users[1]) {
            Account acct = new Account(Name = 'Test Account 1234');
            insert acct;

            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity 1234',
                CloseDate = Date.newInstance(1992, 1, 2),
                StageName = 'Closed Won',
                AccountId = acct.Id,
                Description = 'This is a test',
                Amount = 0
            );
            insert opp;

            Id pricebookId = Test.getStandardPriceBookId();
            List<OpportunityLineItem> oliList = new List<OpportunityLineItem>();
            List<PriceBookEntry> pbeList = new List<PriceBookEntry>();
            List<Product2> productList = new List<Product2>();

            for (Integer i = 0; i < 4; i++) {
                productList.add(new Product2(Name = 'Test ' + i));
            }
            insert productList;

            for (Product2 product : productList) {
                pbeList.add(
                    new PricebookEntry(
                        Product2Id = product.Id,
                        PriceBook2Id = pricebookId,
                        UnitPrice = 100,
                        IsActive = true,
                        UseStandardPrice = false
                    )
                );
            }
            insert pbeList;

            for (PricebookEntry pbe : pbeList) {
                oliList.add(
                    new OpportunityLineItem(
                        PriceBookEntryId = pbe.Id,
                        OpportunityId = opp.Id,
                        Quantity = 2,
                        UnitPrice = 100
                    )
                );
            }
            insert oliList;

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(opp, oliList, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();

            ApexPages.StandardController controller = new ApexPages.StandardController(opp);
            BillingFromOpportunity cb = new BillingFromOpportunity(controller);

            System.assertEquals(4 + 1, cb.billingsOpportunityWrappers.get(0).billLines.size());
            System.assertEquals(
                (100 * 2 * 4) * cb.billingsOpportunityWrappers.get(0).getCurrencyConversionRate() / 10,
                cb.billingsOpportunityWrappers.get(0).billLines.get(4).billingLineRec.Rate__c
            );

            cb.createBillingAndPost();

            Test.stopTest();

            List<Billing_Line__c> salesTaxLines = [
                SELECT Id, Rate__c, Billing__r.Status__c
                FROM Billing_Line__c
                WHERE Product__c = :AvaTaxHelper.getSalesTaxProductId(cb.billingsOpportunityWrappers.get(0).bill)
            ];

            System.assertNotEquals(true, salesTaxLines.isEmpty());
            System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, salesTaxLines[0].Billing__r.Status__c);
        }
    }

    @IsTest
    public static void testCreateBillingWithAvalaraSalesTaxLineOnInitialPageLoad_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance(false, true, true)
                .enableMultiCurrency()
                .setLineLevelPost()
                .enableAvaTaxCalculation();

            System.runAs(testData.users[1]) {

                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Account acct = new Account(Name = 'Test Account 1234');
                insert acct;

                Opportunity opp = new Opportunity(
                    Name = 'Test Opportunity 1234',
                    CloseDate = Date.today().addDays(-10),
                    StageName = 'Closed Won',
                    AccountId = acct.Id,
                    Description = 'This is a test',
                    Amount = 0
                );
                opp.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert opp;

                Id pricebookId = Test.getStandardPriceBookId();
                List<OpportunityLineItem> oliList = new List<OpportunityLineItem>();
                List<PriceBookEntry> pbeList = new List<PriceBookEntry>();
                List<Product2> productList = new List<Product2>();

                for (Integer i = 0; i < 4; i++) {
                    productList.add(new Product2(Name = 'Test ' + i));
                }
                insert productList;

                for (Product2 product : productList) {
                    PricebookEntry tempPBE = new PricebookEntry(
                        Product2Id = product.Id,
                        PriceBook2Id = pricebookId,
                        UnitPrice = 100,
                        IsActive = true,
                        UseStandardPrice = false
                    );
                    tempPBE.put('CurrencyIsoCode', newCurrencyIsoCode);
                    pbeList.add(tempPBE);
                }
                insert pbeList;

                for (PricebookEntry pbe : pbeList) {
                    oliList.add(
                        new OpportunityLineItem(
                            PriceBookEntryId = pbe.Id,
                            OpportunityId = opp.Id,
                            Quantity = 2,
                            UnitPrice = 100
                        )
                    );
                }
                insert oliList;

                SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                    200,
                    'Complete',
                    testData.getCreateAvaTaxTransactionResponseBody(opp, oliList, 10),
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );

                Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

                Test.startTest();

                ApexPages.StandardController controller = new ApexPages.StandardController(opp);
                BillingFromOpportunity cb = new BillingFromOpportunity(controller);

                System.assertEquals(4 + 1, cb.billingsOpportunityWrappers.get(0).billLines.size());
                System.assertEquals(
                    (100 * 2 * 4) * cb.billingsOpportunityWrappers.get(0).getCurrencyConversionRate() / 10,
                    cb.billingsOpportunityWrappers.get(0).billLines.get(4).billingLineRec.Rate__c
                );
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    public static void testCreateBillingWithAvaTaxCalcLedgerChangedToNonUsdHLP_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance(false, true, true)
                .enableMultiCurrency()
                .enableAvaTaxCalculation();

            System.runAs(testData.users[1]) {

                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode) || newCurrencyIsoCode.equalsIgnoreCase('USD')) {
                    return;
                }

                Account acct = new Account(Name = 'Test Account 1234');
                insert acct;

                Opportunity opp = new Opportunity(
                    Name = 'Test Opportunity 1234',
                    CloseDate = Date.today().addDays(-10),
                    StageName = 'Closed Won',
                    AccountId = acct.Id,
                    Description = 'This is a test',
                    Amount = 0
                );
                opp.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert opp;

                Id pricebookId = Test.getStandardPriceBookId();
                List<OpportunityLineItem> oliList = new List<OpportunityLineItem>();
                List<PriceBookEntry> pbeList = new List<PriceBookEntry>();
                List<Product2> productList = new List<Product2>();

                for (Integer i = 0; i < 4; i++) {
                    productList.add(new Product2(Name = 'Test ' + i));
                }
                insert productList;

                for (Product2 product : productList) {
                    PricebookEntry tempPBE = new PricebookEntry(
                        Product2Id = product.Id,
                        PriceBook2Id = pricebookId,
                        UnitPrice = 100,
                        IsActive = true,
                        UseStandardPrice = false
                    );
                    tempPBE.put('CurrencyIsoCode', newCurrencyIsoCode);
                    pbeList.add(tempPBE);
                }
                insert pbeList;

                for (PricebookEntry pbe : pbeList) {
                    oliList.add(
                        new OpportunityLineItem(
                            PriceBookEntryId = pbe.Id,
                            OpportunityId = opp.Id,
                            Quantity = 2,
                            UnitPrice = 100
                        )
                    );
                }
                insert oliList;

                SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                    200,
                    'Complete',
                    testData.getCreateAvaTaxTransactionResponseBody(opp, oliList, 10),
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );

                Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

                Test.startTest();

                ApexPages.StandardController controller = new ApexPages.StandardController(opp);
                BillingFromOpportunity cb = new BillingFromOpportunity(controller);

                System.assertEquals(4, cb.billingsOpportunityWrappers.get(0).billLines.size());
                System.assertEquals(
                    (100 * 2) * cb.billingsOpportunityWrappers.get(0).getCurrencyConversionRate() / 10,
                    cb.billingsOpportunityWrappers.get(0).billLines.get(0).billingLineRec.Tax_Amount2__c
                );
                LedgerHandler.reset();
                //Create ledger with non-USD currency
                Ledger__c nonUsdLedger = new Ledger__c(
                    Name = 'Actual-Non-USD',
                    Type__c = 'Transactional',
                    Default_Bank_Account__c = testData.glAccounts[0].Id,
                    Default_Billing_Format__c = testData.billingFormats[0].Id,
                    Billing_Outstanding_Statement_Format__c = testData.billingFormats[2].Id,
                    Billing_Activity_Statement_Format__c = testData.billingFormats[3].Id
                );
                nonUsdLedger.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert nonUsdLedger;

                //Select this new ledger on the screen
                cb.billingsOpportunityWrappers[0].bill.Ledger__c = nonUsdLedger.Id;
                cb.createBilling();
                System.assertEquals(
                    NULL,
                    cb.billingsOpportunityWrappers[0].billLines[0].billingLineRec.Tax_Amount2__c
                );
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

}