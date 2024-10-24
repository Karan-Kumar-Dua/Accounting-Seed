@IsTest
public class TaxGroupHandlerTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testSetTaxGroupByProductIds() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups();

        System.runAs(testData.users[1]) {
            Set<Id> productIds = new Map<Id, Product2>([SELECT Id FROM Product2 WHERE Id IN :testData.products]).keySet();

            TaxGroupHandler.getInstance().setTaxGroupsByProductIds(productIds).setTaxGroupsByTaxGroupIds();

            System.assertEquals(3, TaxGroupHandler.getInstance().getTaxGroupsMap().size());
            System.assert(TaxGroupHandler.getInstance().getTaxGroupsMap().containsKey(testData.taxGroups.get(0).Id));
            System.assert(TaxGroupHandler.getInstance().getTaxGroupsMap().containsKey(testData.taxGroups.get(1).Id));
            System.assert(TaxGroupHandler.getInstance().getTaxGroupsMap().containsKey(testData.taxGroups.get(2).Id));
        }
    }

    @IsTest
    private static void testGetTaxGroupByProductId() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups();

        System.runAs(testData.users[1]) {
            Map<Id, Product2> productMap = new Map<Id, Product2>([SELECT Id, Tax_Group__c FROM Product2 WHERE Id IN :testData.products AND Tax_Group__c != NULL]);

            TaxGroupHandler.getInstance().setTaxGroupsByProductIds(productMap.keySet()).setTaxGroupsByTaxGroupIds();

            System.assertEquals(3, TaxGroupHandler.getInstance().getTaxGroupsMap().size());
            Product2 prod = productMap.values()[0];
            System.assertEquals(prod.Tax_Group__c,TaxGroupHandler.getInstance().getTaxGroupByProductId(productMap.values()[0].Id).Id);
        }
    }

    @IsTest
    private static void testHasTaxGroupByProductId() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups();

        System.runAs(testData.users[1]) {
            Map<Id, Product2> productMap = new Map<Id, Product2>([SELECT Id FROM Product2 WHERE Id IN :testData.products AND Tax_Group__c != NULL]);

            TaxGroupHandler.getInstance().setTaxGroupsByProductIds(productMap.keySet()).setTaxGroupsByTaxGroupIds();

            System.assertEquals(3, TaxGroupHandler.getInstance().getTaxGroupsMap().size());
            Product2 prod = productMap.values()[0];
            System.assertEquals(true, TaxGroupHandler.getInstance().hasTaxGroupByProductId(prod.Id));
        }
    }

    @IsTest
    private static void testSetTaxGroupByTaxGroupIds() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups();

        System.runAs(testData.users[1]) {
            Set<Id> taxGroupIds = new Map<Id, Tax_Group__c>([SELECT Id FROM Tax_Group__c WHERE Id IN :testData.taxGroups]).keySet();

            TaxGroupHandler.getInstance().setTaxGroupsByTaxGroupIds(taxGroupIds);

            System.assertEquals(3, TaxGroupHandler.getInstance().getTaxGroupsMap().size());
            System.assert(TaxGroupHandler.getInstance().getTaxGroupsMap().containsKey(testData.taxGroups.get(0).Id));
            System.assert(TaxGroupHandler.getInstance().getTaxGroupsMap().containsKey(testData.taxGroups.get(1).Id));
            System.assert(TaxGroupHandler.getInstance().getTaxGroupsMap().containsKey(testData.taxGroups.get(2).Id));
        }
    }

    @IsTest
    private static void testGetTaxGroupByTaxGroupIds() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups();

        System.runAs(testData.users[1]) {
            Map<Id, Tax_Group__c> taxGroupMap = new Map<Id, Tax_Group__c>([SELECT Id FROM Tax_Group__c WHERE Id IN :testData.taxGroups]);

            TaxGroupHandler.getInstance().setTaxGroupsByTaxGroupIds(taxGroupMap.keySet());

            System.assertEquals(3, TaxGroupHandler.getInstance().getTaxGroupsMap().size());
            System.assertEquals(testData.taxGroups.get(0).Id, TaxGroupHandler.getInstance().getTaxGroup(testData.taxGroups.get(0).Id).Id);
        }
    }

    @IsTest
    private static void testHasTaxGroupByTaxGroupId() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups();

        System.runAs(testData.users[1]) {
            Map<Id, Product2> productMap = new Map<Id, Product2>([SELECT Id FROM Product2 WHERE Id IN :testData.products AND Tax_Group__c != NULL]);

            TaxGroupHandler.getInstance().setTaxGroupsByProductIds(productMap.keySet()).setTaxGroupsByTaxGroupIds();

            System.assertEquals(3, TaxGroupHandler.getInstance().getTaxGroupsMap().size());
            System.assertEquals(true, TaxGroupHandler.getInstance().hasTaxGroup(testData.taxGroups.get(0).Id));
        }
    }

    @IsTest
    private static void testSetTaxGroupBySObjectAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups()
            .createPayables();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Account_Payable_Line__c> accountPayableLines = new List<Account_Payable_Line__c>();
            accountPayableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = testData.payables.get(0).Id,
                    Unit_Cost__c = 50,
                    Date__c = System.today(),
                    Expense_GL_Account__c = testData.glAccounts.get(12).Id,
                    Product__c = testData.products[7].Id
                )
            );

            accountPayableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = testData.payables.get(0).Id,
                    Unit_Cost__c = 45,
                    Date__c = System.today(),
                    Product__c = testData.products[8].Id,
                    Expense_GL_Account__c = testData.glAccounts.get(12).Id
                )
            );

            accountPayableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = testData.payables.get(0).Id,
                    Unit_Cost__c = 30,
                    Date__c = System.today(),
                    Product__c = testData.products[7].Id,
                    Expense_GL_Account__c = testData.glAccounts.get(12).Id
                )
            );

            insert accountPayableLines;
            TaxGroupHandler.getInstance().setTaxGroupsBySObjects(accountPayableLines);

            System.assertEquals(2, TaxGroupHandler.getInstance().getTaxGroupsMap().size());
            System.assert(TaxGroupHandler.getInstance().getTaxGroupsMap().containsKey(testData.taxGroups.get(2).Id));
            System.assert(TaxGroupHandler.getInstance().getTaxGroupsMap().containsKey(testData.taxGroups.get(1).Id));
        }
    }

    @IsTest
    private static void testSetTaxGroupBySobjectBL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups()
            .createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Billing_Line__c> billingLines = new List<Billing_Line__c>();
            billingLines.add(
                new Billing_Line__c(
                    Billing__c = testData.billings[0].Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Hours_Units__c = 20,
                    Rate__c = 10,
                    Product__c = testData.products[6].Id
                )
            );

            billingLines.add(
                new Billing_Line__c(
                    Billing__c = testData.billings[0].Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Hours_Units__c = 20,
                    Rate__c = 10,
                    Product__c = testData.products[8].Id
                )
            );

            billingLines.add(
                new Billing_Line__c(
                    Billing__c = testData.billings[0].Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Hours_Units__c = 20,
                    Rate__c = 10,
                    Product__c = testData.products[8].Id
                )
            );

            insert billingLines;

            TaxGroupHandler.getInstance().setTaxGroupsBySObjects(billingLines);
            System.assertEquals(2, TaxGroupHandler.getInstance().getTaxGroupsMap().size());
            System.assert(TaxGroupHandler.getInstance().getTaxGroupsMap().containsKey(testData.taxGroups.get(0).Id));
            System.assert(TaxGroupHandler.getInstance().getTaxGroupsMap().containsKey(testData.taxGroups.get(2).Id));
            Test.stopTest();
        }
    }


}