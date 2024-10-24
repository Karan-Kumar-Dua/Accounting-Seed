@isTest
private class TaxServiceInvocableTest {
    private static final String ERROR_HIGH_LEVEL_POST = Label.TAX_SERVICE_HLP_ERROR_INVOCABLE;
    private static final String ERR_NOT_VALID_TAX_SETTING_METHOD = Label.ERR_NOT_VALID_TAX_SETTING_METHOD;
    private static final String TAX_SERVICE_AVALARA_ERROR_INVOCABLE = Label.TAX_SERVICE_AVALARA_ERROR_INVOCABLE;

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    @isTest
    private static void testCalcTaxForBilling() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProducts()
            .createBillings()
            .createAccountTaxes()
            .setLineLevelPost();
            

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Ledger__c = testData.ledgers[0].Id;
            update testData.billings;
            testData.billingLines[0].Product__c = testData.products[3].Id;
            testData.billingLines[1].Product__c = testData.products[4].Id;
            update testData.billingLines;
            
            List<Billing__c> billing = new List<Billing__c>{testData.billings[0]};

            for(TaxServiceResultInvocable taxResult : TaxServiceInvocable.calcTax( new List<List<Billing__c>> {billing})) {

                Assert.isTrue(taxResult.isSuccess);
                for(TaxServiceResultLineType resultLine :  taxResult.results) {
                    Assert.isTrue(resultLine.isSuccess);
                    Assert.areEqual(resultLine.sourceRecordId, resultLine.sourceObj.Id);
                    Assert.areEqual(testData.billings[0].Id, resultLine.sourceObj.Id);
        
                }
            }
            Test.stopTest();
        }
    }

    @isTest
    private static void testCalcTaxForBillingError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProducts()
            .createBillings()
            .createAccountTaxes()
            .setLineLevelPost();
            

        System.runAs(testData.users[1]) {
            Test.startTest();

            testData.billingLines[0].Product__c = testData.products[3].Id;
            testData.billingLines[1].Product__c = testData.products[4].Id;
            update testData.billingLines;
            
            List<Billing__c> billing = new List<Billing__c>{testData.billings[0]};

            for(TaxServiceResultInvocable taxResult : TaxServiceInvocable.calcTax( new List<List<Billing__c>> {billing})) {

                Assert.isFalse(taxResult.isSuccess);
                for(TaxServiceResultLineType resultLine :  taxResult.results) {
                    Assert.isFalse(resultLine.isSuccess);
                    Assert.areEqual(testData.billings[0].Id, resultLine.sourceRecordId);
                }
            }
            Test.stopTest();
        }
    }

    @isTest
    private static void testCalcTaxForBillingHLP() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProducts()
            .createBillings()
            .createAccountTaxes();
            

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Ledger__c = testData.ledgers[0].Id;
            update testData.billings;
            testData.billingLines[0].Product__c = testData.products[3].Id;
            testData.billingLines[1].Product__c = testData.products[4].Id;
            update testData.billingLines;
            
            List<Billing__c> billing = new List<Billing__c>{testData.billings[0]};

            try {
                TaxServiceInvocable.calcTax( new List<List<Billing__c>> {billing});
            }

            catch(Exception e) {
                Assert.areEqual(ERROR_HIGH_LEVEL_POST, e.getMessage());
            }
            Test.stopTest();
        }
    }

    @IsTest
    public static void testCalculateTaxForAvalara() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createBillings()
            .createProducts()
            .enableAvaTaxCalculation();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Billing__c testBilling =[SELECT Id, Ledger__c, Date__c,Status__c FROM Billing__c WHERE Id = :testData.billings[0].Id];
            delete [SELECT Id FROM Billing_Line__c WHERE Billing__c = :testBilling.Id];
            Product2 taxableProduct = testData.products[3];

            Billing_Line__c taxableLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testBilling.Date__c,
                Hours_Units__c = 25,
                Rate__c = 10,
                Product__c = taxableProduct.Id
            );

            insert taxableLine;

            List<Billing__c> billing = new List<Billing__c>{testBilling};
            for(TaxServiceResultInvocable taxResult : TaxServiceInvocable.calcTax( new List<List<Billing__c>> {billing})) {

                Assert.isTrue(taxResult.isSuccess);
                for(TaxServiceResultLineType resultLine :  taxResult.results) {
                    Assert.isFalse(resultLine.isSuccess);
                    Assert.areEqual(testData.billings[0].Id, resultLine.sourceRecordId);
                }
            }
           
            Test.stopTest();
        }
    }
}