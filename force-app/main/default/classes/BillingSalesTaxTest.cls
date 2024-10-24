@IsTest
private class BillingSalesTaxTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testBillingSalesTaxPostedError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .setLineLevelPost();

        System.runAs(testData.users[1]) {
            Test.startTest();

            Billing__c testBilling = testData.billings[0];
            testBilling.Status__c = 'Approved';
            update testBilling;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            //Confirm posted
            System.assertEquals(true, results[0].isSuccess);

            PageReference pRef = Page.BillingSalesTax;
            pRef.getParameters().put('ID', testData.billings[0].Id);
            Test.setCurrentPage(pRef);
            ApexPages.StandardController con = new ApexPages.StandardController(testData.billings[0]);
            BillingSalesTax ext = new BillingSalesTax(con);
            PageReference ref = ext.init();

            System.assertEquals(BillingSalesTax.POSTED_RECORD_ERROR_MESSAGE, ApexPages.getMessages()[0].getDetail());
        }

    }

    @IsTest
    private static void testBillingSalesTaxAppliedError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .setLineLevelPost();

        System.runAs(testData.users[1]) {
            Test.startTest();

            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
            bcm.Billing_Invoice__c = testData.billings[0].Id;
            bcm.Billing_Credit_Memo__c = testData.billings[3].Id;
            bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
            bcm.Amount__c = -10;
            insert bcm;

            PageReference pRef = Page.BillingSalesTax;
            pRef.getParameters().put('ID', testData.billings[0].Id);
            Test.setCurrentPage(pRef);
            ApexPages.StandardController con = new ApexPages.StandardController(testData.billings[0]);
            BillingSalesTax ext = new BillingSalesTax(con);
            PageReference ref = ext.init();

            System.assertEquals(BillingSalesTax.APPLIED_RECORD_ERROR_MESSAGE, ApexPages.getMessages()[0].getDetail());
        }

    }

    @IsTest
    private static void testBillingSalesTaxNoTaxableProducts() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProducts()
            .createBillings()
            .setLineLevelPost();

        System.runAs(testData.users[1]) {
            testData.billingLines[0].Product__c = testData.products[0].Id;
            testData.billingLines[1].Product__c = testData.products[1].Id;
            update testData.billingLines;

            PageReference pRef = Page.BillingSalesTax;
            pRef.getParameters().put('ID', testData.billings[0].Id);
            Test.setCurrentPage(pRef);
            ApexPages.StandardController con = new ApexPages.StandardController(testData.billings[0]);
            BillingSalesTax ext = new BillingSalesTax(con);
            PageReference ref = ext.init();
            System.assertEquals(BillingSalesTax.NO_TAXABLE_PRODUCTS_MESSAGE, ApexPages.getMessages()[0].getDetail());
        }

    }

    @IsTest
    private static void testBillingSalesTaxNoAvailableTaxes() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProducts()
            .createBillings()
            .setLineLevelPost();

        System.runAs(testData.users[1]) {
            Test.startTest();

            testData.billingLines[0].Product__c = testData.products[3].Id;
            testData.billingLines[1].Product__c = testData.products[4].Id;
            update testData.billingLines;

            System.assertEquals(1, [SELECT COUNT() FROM Billing_Line__c WHERE Product__r.Accounting_Type__c = 'Tax Rate']);

            PageReference pRef = Page.BillingSalesTax;
            pRef.getParameters().put('ID', testData.billings[0].Id);
            Test.setCurrentPage(pRef);
            ApexPages.StandardController con = new ApexPages.StandardController(testData.billings[0]);
            BillingSalesTax ext = new BillingSalesTax(con);
            PageReference ref = ext.init();

            String expectedErrorMessage =
                String.format(
                    BillingSalesTax.NO_AVAILABLE_TAXES,
                    new List<String>{
                        ext.theBilling.Customer__r.Name,
                        BillingSalesTax.APPLICABLE_TYPES_OF_TAXES[0],
                        BillingSalesTax.APPLICABLE_TYPES_OF_TAXES[1]
                    }
                );

            System.assertEquals(expectedErrorMessage, ApexPages.getMessages()[0].getDetail());
        }
    }

    @IsTest
    private static void testBillingSalesTaxTaxableProductsExisted() {
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

            System.assertEquals(1, [SELECT count() FROM Billing_Line__c WHERE Product__r.Accounting_Type__c = 'Tax Rate']);

            PageReference pRef = Page.BillingSalesTax;
            pRef.getParameters().put('ID', testData.billings[0].Id);
            Test.setCurrentPage(pRef);
            ApexPages.StandardController con = new ApexPages.StandardController(testData.billings[0]);
            BillingSalesTax ext = new BillingSalesTax(con);
            ext.init();
            PageReference ref = ext.save();
            //Expected:
            //1. All existed Billing lines where Product__r.Accounting_Type__c = 'Tax Rate' are deleted
            //2. One new Billing lines where Product__r.Accounting_Type__c = 'Tax Rate' is created
            //3. Redirected to the parent record detail page
            System.assert(String.valueOf(ref).contains(testData.billings[0].Id));
            System.assertEquals(1, [SELECT count() FROM Billing_Line__c WHERE Product__r.Accounting_Type__c = 'Tax Rate']);
            System.assertEquals(1, ext.taxTableData.size());
            System.assertEquals(testData.products[3].Name, ext.taxTableData[0].taxableProducts.values()[0].values()[0]);
            System.assertEquals(
                ext.taxTableData[0].taxAmountTotal,
                [SELECT Id, Rate__c FROM Billing_Line__c WHERE Product__r.Accounting_Type__c = 'Tax Rate'].Rate__c
            );
        }
    }

    @IsTest
    private static void testRoundingTax() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProducts()
            .createBillings()
            .createAccountTaxes()
            .setLineLevelPost();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billingLines[0].Product__c = testData.products[3].Id;
            testData.billingLines[1].Product__c = testData.products[3].Id;
            testData.billingLines[0].Rate__c = 10.105;
            testData.billingLines[1].Rate__c = 10.105;
            testData.billingLines[1].Hours_Units__c = 20;
            update testData.billingLines;

            Decimal result = (((testData.billingLines[0].Rate__c * testData.billingLines[0].Hours_Units__c) * 0.055)
                    + ((testData.billingLines[1].Rate__c * testData.billingLines[1].Hours_Units__c) * 0.055)).setScale(2, System.RoundingMode.HALF_UP);

            PageReference pRef = Page.BillingSalesTax;
            pRef.getParameters().put('ID', testData.billings[0].Id);
            Test.setCurrentPage(pRef);
            ApexPages.StandardController con = new ApexPages.StandardController(testData.billings[0]);
            BillingSalesTax ext = new BillingSalesTax(con);
            ext.init();
            PageReference ref = ext.save();

            System.assertEquals(
                result, [
                    SELECT Id, Rate__c, Billing__c
                    FROM Billing_Line__c
                    WHERE Product__r.Accounting_Type__c = 'Tax Rate'
                    AND Billing__c = :testData.billings[0].Id
                ].Rate__c
            );
        }
    }

    @IsTest
    public static void testNoLongerSupportedMessageShown() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProducts()
            .createBillings()
            .createAccountTaxes()
            .setHeaderLevelPost();

        System.runAs(testData.users[1]) {
            Test.startTest();
            ApexPages.StandardController con = new ApexPages.StandardController(testData.billings[0]);
            BillingSalesTax ext = new BillingSalesTax(con);
            ext.init();

            System.assertEquals(HeaderLevelTaxHelper.NO_SUPPORT_INFO_MESSAGE, ApexPages.getMessages()[0].getDetail());
        }
    }

}