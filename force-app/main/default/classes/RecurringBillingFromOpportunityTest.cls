@isTest
public class RecurringBillingFromOpportunityTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true, true, true);
    }

    @isTest
    public static void testOppIsNoAccountError() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true);

        System.runAs(testData.users[1]) {
            Test.startTest();
            Opportunity opp = new Opportunity();
            opp.Name = 'Test Opp';
            opp.CloseDate = System.today();
            opp.StageName = 'Closed Won';
            insert opp;

            ApexPages.StandardController controller = new ApexPages.StandardController(opp);
            RecurringBillingFromOpportunity rbo = new RecurringBillingFromOpportunity(controller);

            System.assertEquals(RecurringBillingFromOpportunity.NO_ACCOUNT_ERROR, ApexPages.getMessages()[0].getDetail());
        }

    }

    @isTest
    public static void testRecurringBillingsExistConfirmation() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true);

        System.runAs(testData.users[1]) {
            Test.startTest();
            Opportunity opp = new Opportunity();
            opp.Name = 'Test Opp';
            opp.CloseDate = System.today();
            opp.StageName = 'Closed Won';
            opp.accountId = testData.accounts[0].Id;
            opp.Amount = 200;
            insert opp;

            Recurring_Billing__c rBill = new Recurring_Billing__c();
            rBill.Customer__c = testData.accounts[0].Id;
            rBill.Opportunity__c = opp.Id;
            rBill.Billing_Frequency__c = 'Monthly';
            rBill.Next_Billing_Date__c = System.today() + 30;
            insert rBill;

            ApexPages.StandardController controller = new ApexPages.StandardController(opp);
            RecurringBillingFromOpportunity rbo = new RecurringBillingFromOpportunity(controller);

            System.assertEquals(
                RecurringBillingFromOpportunity.RECURRING_BILLING_EXISTS_WARNING,
                ApexPages.getMessages()[0].getSummary()
            );
        }

    }

    @isTest
    public static void testCreateRecurringBillingsNoOppProductsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true);

        System.runAs(testData.users[1]) {
            Test.startTest();
            Opportunity opp = new Opportunity();
            opp.Name = 'Test Opp';
            opp.AccountId = testData.accounts[0].Id;
            opp.CloseDate = System.today() - 1;
            opp.StageName = 'Closed Won';
            opp.Amount = 200;
            insert opp;

            System.assertEquals(true, [SELECT isWon FROM Opportunity WHERE Id = :opp.Id].isWon);
            ApexPages.StandardController controller = new ApexPages.StandardController(opp);
            RecurringBillingFromOpportunity rbo = new RecurringBillingFromOpportunity(controller);
            rbo.mainDTO.recurringBilling.Billing_Frequency__c = 'Monthly';
            rbo.createRecurringBilling();

            System.assertEquals(1, [SELECT count() FROM Recurring_Billing__c WHERE Opportunity__c = :opp.Id]);
            System.assertEquals(
                1,
                [SELECT count() FROM Recurring_Billing_Line__c WHERE Recurring_Billing__r.Opportunity__c = :opp.Id]
            );
        }

    }

    @IsTest
    public static void testIsOpportunityDiscountTrue() {
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
                pbeList.add(
                    new PricebookEntry(
                        Product2Id = product.Id,
                        PriceBook2Id = pricebookId,
                        UnitPrice = 4000,
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
            RecurringBillingFromOpportunity rbo = new RecurringBillingFromOpportunity(controller);
            System.assertEquals(true, rbo.isProductDiscount);
        }
    }

    @IsTest
    public static void testIsOpportunityDiscountFalse() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true);

        System.runAs(testData.users[1]) {
            Test.startTest();
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
            RecurringBillingFromOpportunity rbo = new RecurringBillingFromOpportunity(controller);

            System.assertEquals(false, rbo.isProductDiscount);
        }
    }

    @IsTest
    public static void testCreateRecurringBillingsOppProductsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true);

        System.runAs(testData.users[1]) {
            Test.startTest();
            Opportunity opp = new Opportunity();
            opp.Name = 'Test Opp';
            opp.AccountId = testData.accounts[0].Id;
            opp.CloseDate = System.today() - 1;
            opp.StageName = 'Closed Won';
            opp.Amount = 200;
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
                        isActive = true
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

            System.assertEquals(true, [SELECT isWon FROM Opportunity WHERE Id = :opp.Id].isWon);
            ApexPages.StandardController controller = new ApexPages.StandardController(opp);
            RecurringBillingFromOpportunity rbo = new RecurringBillingFromOpportunity(controller);
            rbo.mainDTO.recurringBilling.Billing_Frequency__c = 'Monthly';
            rbo.createRecurringBilling();

            System.assertEquals(1, [SELECT count() FROM Recurring_Billing__c WHERE Opportunity__c = :opp.Id]);
            System.assertEquals(
                4,
                [SELECT count() FROM Recurring_Billing_Line__c Where Recurring_Billing__r.Opportunity__c = :opp.Id]
            );
        }
    }

    @IsTest
    public static void testCreateRecurringBillingsOppProductsSuccessWithInitBilling() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true);

        System.runAs(testData.users[1]) {
            Test.startTest();
            Opportunity opp = new Opportunity();
            opp.Name = 'Test Opp';
            opp.AccountId = testData.accounts[0].Id;
            opp.CloseDate = Date.newInstance(1992, 1, 15);
            opp.StageName = 'Closed Won';
            opp.Amount = 200;
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
                        IsActive = true
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

            System.assertEquals(true, [SELECT isWon FROM Opportunity WHERE Id = :opp.Id].isWon);
            ApexPages.StandardController controller = new ApexPages.StandardController(opp);
            RecurringBillingFromOpportunity rbo = new RecurringBillingFromOpportunity(controller);
            rbo.mainDTO.recurringBilling.Billing_Frequency__c = 'Monthly';
            rbo.createInitialBilling = true;
            rbo.createRecurringBilling();

            System.assertEquals(1, [SELECT count() FROM Billing__c WHERE Opportunity__c = :opp.Id]);
            System.assertEquals(1, [SELECT count() FROM Recurring_Billing__c WHERE Opportunity__c = :opp.Id]);
            System.assertEquals(
                testData.ledgers[0].Id,
                [SELECT Id, Ledger__c FROM Billing__c WHERE Opportunity__c = :opp.Id].Ledger__c
            );
            System.assertEquals(
                testData.ledgers[0].Id,
                [SELECT Id, Ledger__c FROM Recurring_Billing__c WHERE Opportunity__c = :opp.Id].Ledger__c
            );
            System.assertEquals(4, [SELECT count() FROM Billing_Line__c Where Billing__r.Opportunity__c = :opp.Id]);
            System.assertEquals(4, [SELECT count() FROM Recurring_Billing_Line__c Where Recurring_Billing__r.Opportunity__c = :opp.Id]);
        }

    }

    @IsTest
    public static void testCreateRecurringBillingsOppProductsWithInitBillingNoPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true);

        System.runAs(testData.users[1]) {
            Test.startTest();
            Opportunity opp = new Opportunity();
            opp.Name = 'Test Opp';
            opp.AccountId = testData.accounts[0].Id;
            opp.CloseDate = Date.newInstance(1991, 9, 01);//we dont have period for this date
            opp.StageName = 'Closed Won';
            opp.Amount = 200;
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
                        IsActive = true
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

            System.assertEquals(true, [SELECT isWon FROM Opportunity WHERE Id = :opp.Id].isWon);
            ApexPages.StandardController controller = new ApexPages.StandardController(opp);
            RecurringBillingFromOpportunity rbo = new RecurringBillingFromOpportunity(controller);
            rbo.mainDTO.recurringBilling.Billing_Frequency__c = 'Monthly';
            rbo.createInitialBilling = true;
            rbo.createRecurringBilling();

            System.assertEquals(true, rbo.isError);
            System.assertEquals(
                RecurringBillingFromOpportunity.ACCOUNTING_PERIOD_DOES_NOT_EXIST_ERROR,
                ApexPages.getMessages()[0].getSummary()
            );
        }

    }

    @IsTest
    public static void testCreateRecurringBillingsSkippingSalesTaxLine() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true)
            .setLineLevelPost()
            .enableAvaTaxCalculation();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Opportunity opp = new Opportunity();
            opp.Name = 'Test Opp';
            opp.AccountId = testData.accounts[0].Id;
            opp.CloseDate = System.today() - 1;
            opp.StageName = 'Closed Won';
            opp.Amount = 200;
            insert opp;

            Id pricebookId = Test.getStandardPriceBookId();
            OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
            PricebookEntry[] pbeList = new List<PriceBookEntry>();
            Product2[] productList = new List<Product2>();

            for (Integer i = 0; i < 4; i++) {
                productList.add(new Product2(Name = 'Test ' + i, Revenue_GL_Account__c = testData.glAccounts[16].Id));
            }
            insert productList;
            //add Avalara Product in list
            productList.addAll([SELECT Id FROM Product2 WHERE Id = :testData.settings.Avalara_Tax_Product__c]);

            for (Product2 product : productList) {
                pbeList.add(
                    new PricebookEntry(
                        Product2Id = product.Id,
                        PriceBook2Id = pricebookId,
                        UnitPrice = 4000,
                        IsActive = true
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

            System.assertEquals(true, [SELECT IsWon FROM Opportunity WHERE Id = :opp.Id].IsWon);
            ApexPages.StandardController controller = new ApexPages.StandardController(opp);
            RecurringBillingFromOpportunity rbo = new RecurringBillingFromOpportunity(controller);
            rbo.mainDTO.recurringBilling.Billing_Frequency__c = 'Monthly';
            rbo.createRecurringBilling();

            System.assertEquals(1, [SELECT count() FROM Recurring_Billing__c WHERE Opportunity__c = :opp.Id]);
            System.assertEquals(
                4, [
                    SELECT count() FROM Recurring_Billing_Line__c Where Recurring_Billing__r.Opportunity__c = :opp.Id
                ]
            );//There were 5 lines in the Opp but one line was skipped because Avalara is enabled
        }
    }

    @IsTest
    public static void testCreateRecurringBillingsOppProductsSuccessWithInitBillingInheritTaxGroup() {
        TestDataSuite testData = TestDataSuite.getInstance(false, true, true).createTaxGroups();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Opportunity opp = new Opportunity();
            opp.Name = 'Test Opp';
            opp.AccountId = testData.accounts[0].Id;
            opp.CloseDate = Date.newInstance(1992, 1, 15);
            opp.StageName = 'Closed Won';
            opp.Amount = 200;
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
                        IsActive = true
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
                        Tax_Group__c = testData.taxGroups[2].Id
                    )
                );
            }
            insert oliList;

            System.assertEquals(true, [SELECT isWon FROM Opportunity WHERE Id = :opp.Id].isWon);
            ApexPages.StandardController controller = new ApexPages.StandardController(opp);
            RecurringBillingFromOpportunity rbo = new RecurringBillingFromOpportunity(controller);
            rbo.mainDTO.recurringBilling.Billing_Frequency__c = 'Monthly';
            rbo.createInitialBilling = true;
            rbo.createRecurringBilling();

            System.assertEquals(1, [SELECT count() FROM Billing__c WHERE Opportunity__c = :opp.Id]);
            System.assertEquals(1, [SELECT count() FROM Recurring_Billing__c WHERE Opportunity__c = :opp.Id]);
            System.assertEquals(
                testData.ledgers[0].Id,
                [SELECT Id, Ledger__c FROM Billing__c WHERE Opportunity__c = :opp.Id].Ledger__c
            );
            System.assertEquals(
                testData.ledgers[0].Id,
                [SELECT Id, Ledger__c FROM Recurring_Billing__c WHERE Opportunity__c = :opp.Id].Ledger__c
            );

            System.assertEquals(4, [SELECT count() FROM Billing_Line__c Where Billing__r.Opportunity__c = :opp.Id]);
            System.assertEquals(4, [SELECT count() FROM Recurring_Billing_Line__c Where Recurring_Billing__r.Opportunity__c = :opp.Id]);

            List<Billing_Line__c> resultBillingLines = [SELECT Tax_Group__c FROM Billing_Line__c Where Billing__r.Opportunity__c = :opp.Id];
            for (Billing_Line__c line : resultBillingLines) {
                System.assertEquals(testData.taxGroups[2].Id, line.Tax_Group__c);
            }

            List<Recurring_Billing_Line__c> resultRBillingLines = [SELECT Tax_Group__c FROM Recurring_Billing_Line__c Where Recurring_Billing__r.Opportunity__c = :opp.Id];
            for (Recurring_Billing_Line__c line : resultRBillingLines) {
                System.assertEquals(testData.taxGroups[2].Id, line.Tax_Group__c);
            }
        }

    }

}