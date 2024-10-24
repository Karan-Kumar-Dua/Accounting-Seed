@isTest
private class AccountPayablePurchaseTaxTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    public static testMethod void testAccountPayablePurchaseTaxPostedError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createPayables(true);

        System.runAs(testData.users[1]) {
            PageReference pRef = Page.AccountPayablePurchaseTax;
            pRef.getParameters().put('ID', testData.payables[0].Id);
            Test.setCurrentPage(pRef);
            ApexPages.StandardController con = new ApexPages.StandardController(testData.payables[0]);
            AccountPayablePurchaseTax ext = new AccountPayablePurchaseTax(con);
            PageReference ref = ext.init();

            System.assertEquals(AccountPayablePurchaseTax.POSTED_RECORD_ERROR_MESSAGE, ApexPages.getMessages()[0].getDetail());
        }

    }

    public static testMethod void testAccountPayablePurchaseTaxAppliedError() {
        TestDataSuite testData = TestDataSuite.getInstance().setLineLevelPost()
            .createPayables();

        System.runAs(testData.users[1]) {
            AP_Credit_Memo__c acm = new AP_Credit_Memo__c();
            acm.Account_Payable_Credit_Memo__c = testData.payables[4].Id;
            acm.Account_Payable_Invoice__c = testData.payables[0].Id;
            acm.Accounting_Period__c = testData.acctPeriods[2].Id;
            acm.Amount__c = -10;
            insert acm;

            PageReference pRef = Page.AccountPayablePurchaseTax;
            pRef.getParameters().put('ID', testData.payables[0].Id);
            Test.setCurrentPage(pRef);
            ApexPages.StandardController con = new ApexPages.StandardController(testData.payables[0]);
            AccountPayablePurchaseTax ext = new AccountPayablePurchaseTax(con);
            PageReference ref = ext.init();

            System.assertEquals(AccountPayablePurchaseTax.APPLIED_RECORD_ERROR_MESSAGE, ApexPages.getMessages()[0].getDetail());
        }

    }

    public static testMethod void testAccountPayablePurchaseTaxHeaderLevelPostingError() {
        TestDataSuite testData = TestDataSuite.getInstance().setHeaderLevelPost().createPayables(true);

        System.runAs(testData.users[1]) {
            PageReference pRef = Page.AccountPayablePurchaseTax;
            pRef.getParameters().put('ID', testData.payables[0].Id);
            Test.setCurrentPage(pRef);
            ApexPages.StandardController con = new ApexPages.StandardController(testData.payables[0]);
            AccountPayablePurchaseTax ext = new AccountPayablePurchaseTax(con);
            PageReference ref = ext.init();

            System.assertEquals(HeaderLevelTaxHelper.NO_SUPPORT_INFO_MESSAGE, ApexPages.getMessages()[0].getDetail());
        }

    }

    public static testmethod void testAccountPayablePurchaseTaxNoTaxableProducts() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createProducts()
            .createPayables();

        System.runAs(testData.users[1]) {
            testData.payableLines[0].Product__c = testData.products[0].Id;
            testData.payableLines[1].Product__c = testData.products[1].Id;
            update testData.payableLines;

            PageReference pRef = Page.AccountPayablePurchaseTax;
            pRef.getParameters().put('ID', testData.payables[0].Id);
            Test.setCurrentPage(pRef);
            ApexPages.StandardController con = new ApexPages.StandardController(testData.payables[0]);
            AccountPayablePurchaseTax ext = new AccountPayablePurchaseTax(con);
            PageReference ref = ext.init();
            System.assertEquals(AccountPayablePurchaseTax.NO_TAXABLE_PRODUCTS_MESSAGE, ApexPages.getMessages()[0].getDetail());
        }

    }

    public static testmethod void testAccountPayablePurchaseTaxNoProducts() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createProducts()
            .createPayables();

        System.runAs(testData.users[1]) {
            PageReference pRef = Page.AccountPayablePurchaseTax;
            pRef.getParameters().put('ID', testData.payables[0].Id);
            Test.setCurrentPage(pRef);
            ApexPages.StandardController con = new ApexPages.StandardController(testData.payables[0]);
            AccountPayablePurchaseTax ext = new AccountPayablePurchaseTax(con);
            ext.init();

            System.assertEquals(
                AccountPayablePurchaseTax.NO_PAYABLE_LINE_WITH_PRODUCT_MESSAGE,
                ApexPages.getMessages()[0].getDetail()
            );
        }

    }

    public static testmethod void testAccountPayablePurchaseTaxNoAvailableTaxes() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createProducts()
            .createPayables();

        System.runAs(testData.users[1]) {
            testData.payableLines[0].Product__c = testData.products[3].Id;
            testData.payableLines[1].Product__c = testData.products[4].Id;
            update testData.payableLines;

            System.assertEquals(
                1, [
                    SELECT count()
                    FROM Account_Payable_Line__c
                    WHERE Product__r.Accounting_Type__c = 'Tax Rate'
                ]
            );

            PageReference pRef = Page.AccountPayablePurchaseTax;
            pRef.getParameters().put('ID', testData.payables[0].Id);
            Test.setCurrentPage(pRef);
            ApexPages.StandardController con = new ApexPages.StandardController(testData.payables[0]);
            AccountPayablePurchaseTax ext = new AccountPayablePurchaseTax(con);
            PageReference ref = ext.init();

            String expectedErrorMessage =
                String.format(
                    AccountPayablePurchaseTax.NO_AVAILABLE_TAXES,
                    new List<String>{
                        ext.thePayable.Vendor__r.Name,
                        AccountPayablePurchaseTax.APPLICABLE_TYPES_OF_TAXES[0],
                        AccountPayablePurchaseTax.APPLICABLE_TYPES_OF_TAXES[1]
                    }
                );

            System.assertEquals(expectedErrorMessage, ApexPages.getMessages()[0].getDetail());
        }
    }

    public static testmethod void testAccountPayablePurchaseTaxTaxableProductsExisted() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createProducts()
            .createAccountTaxes()
            .createPayables();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.payableLines[0].Product__c = testData.products[3].Id;
            testData.payableLines[1].Product__c = testData.products[4].Id;
            update testData.payableLines;

            System.assertEquals(
                1,
                [SELECT count() FROM Account_Payable_Line__c WHERE Product__r.Accounting_Type__c = 'Tax Rate']
            );

            PageReference pRef = Page.AccountPayablePurchaseTax;
            pRef.getParameters().put('ID', testData.payables[0].Id);
            Test.setCurrentPage(pRef);
            ApexPages.StandardController con = new ApexPages.StandardController(testData.payables[0]);
            AccountPayablePurchaseTax ext = new AccountPayablePurchaseTax(con);
            ext.init();
            PageReference ref = ext.save();
            //Expected:
            //1. All existed Account Payable lines where Product__r.Accounting_Type__c = 'Tax Rate' are deleted
            //2. One new Account Payable lines where Product__r.Accounting_Type__c = 'Tax Rate' are created
            //3. Redirected to the parent record detail page
            System.assertNotEquals(NULL, ref);
            System.assert(String.valueOf(ref).contains(testData.payables[0].Id));
            System.assertEquals(
                1,
                [SELECT count() FROM Account_Payable_Line__c WHERE Product__r.Accounting_Type__c = 'Tax Rate']
            );
            System.assertEquals(1, ext.taxTableData.size());
            System.assertEquals(testData.products[3].Name, ext.taxTableData[0].taxableProducts.values()[0].values()[0]);
            System.assertEquals(
                ext.taxTableData[0].taxAmountTotal,
                [SELECT Id, Amount__c FROM Account_Payable_Line__c WHERE Product__r.Accounting_Type__c = 'Tax Rate'].Amount__c
            );
        }

    }

    public static testmethod void testRoundingTax() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createProducts()
            .createAccountTaxes()
            .createPayables();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.payableLines[0].Product__c = testData.products[3].Id;
            testData.payableLines[1].Product__c = testData.products[3].Id;
            testData.payableLines[0].Amount__c = 202.1;
            testData.payableLines[1].Amount__c = 202.1;
            update testData.payableLines;

            Decimal result = ((testData.payableLines[0].Amount__c * 0.055)
                    + (testData.payableLines[0].Amount__c * 0.055)).setScale(2, System.RoundingMode.HALF_UP);

            PageReference pRef = Page.AccountPayablePurchaseTax;
            pRef.getParameters().put('ID', testData.payables[0].Id);
            Test.setCurrentPage(pRef);
            ApexPages.StandardController con = new ApexPages.StandardController(testData.payables[0]);
            AccountPayablePurchaseTax ext = new AccountPayablePurchaseTax(con);
            ext.init();
            PageReference ref = ext.save();

            System.assertEquals(
                result, [
                    SELECT Id, Amount__c, Account_Payable__c
                    FROM Account_Payable_Line__c
                    WHERE Product__r.Accounting_Type__c = 'Tax Rate'
                    AND Account_Payable__c = :testData.payables[0].Id
                ].Amount__c
            );
        }

    }

    public static testMethod void testNoLongerSupportedMessageShown() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProducts()
            .createAccountTaxes()
            .createPayables()
            .setHeaderLevelPost();

        System.runAs(testData.users[1]) {
            Test.startTest();
            ApexPages.StandardController con = new ApexPages.StandardController(testData.payables[0]);
            AccountPayablePurchaseTax ext = new AccountPayablePurchaseTax(con);
            ext.init();

            System.assertEquals(HeaderLevelTaxHelper.NO_SUPPORT_INFO_MESSAGE, ApexPages.getMessages()[0].getDetail());
        }
    }

}