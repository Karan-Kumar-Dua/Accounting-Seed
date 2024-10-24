@IsTest
private class NativeTaxLineLevelTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void  testAccountPayableTaxTaxableProductsExisted() {
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

    @isTest
    private static void testBillingTaxTaxableProductsExisted() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createProducts()
            .createBillings()
            .createAccountTaxes()
            .createAccountingVariables();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billingLines[0].Product__c = testData.products[3].Id;
            testData.billingLines[1].Product__c = testData.products[4].Id;
            update testData.billingLines;

			Billing_Line__c billingLine = [SELECT Id, GL_Account_Variable_1__c, Product__c, GL_Account_Variable_2__c, GL_Account_Variable_3__c, GL_Account_Variable_4__c , Rate__c FROM Billing_Line__c WHERE Product__r.Accounting_Type__c = 'Tax Rate'];

			Product2 prod = [SELECT Id, GL_Account_Variable_1__c, GL_Account_Variable_2__c, GL_Account_Variable_3__c, GL_Account_Variable_4__c FROM Product2  WHERE Id = :billingLine.Product__c];
            prod.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            prod.GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            prod.GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            prod.GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update prod;

            System.assertEquals(1, [SELECT count() FROM Billing_Line__c WHERE Product__r.Accounting_Type__c = 'Tax Rate']);

            PageReference pRef = Page.BillingSalesTax;
            pRef.getParameters().put('ID', testData.billings[0].Id);
            Test.setCurrentPage(pRef);
            ApexPages.StandardController con = new ApexPages.StandardController(testData.billings[0]);
            BillingSalesTax ext = new BillingSalesTax(con);
            ext.init();
            PageReference ref = ext.save();
            
            Billing_Line__c bl = [SELECT Id, Rate__c, GL_Account_Variable_1__c, GL_Account_Variable_2__c, GL_Account_Variable_3__c, GL_Account_Variable_4__c FROM Billing_Line__c WHERE Product__r.Accounting_Type__c = 'Tax Rate'];
            //Expected:
            //1. All existed Billing lines where Product__r.Accounting_Type__c = 'Tax Rate' are deleted
            //2. One new Billing lines where Product__r.Accounting_Type__c = 'Tax Rate' is created
            //3. Redirected to the parent record detail page
            //4. GL Variables should be auto-populated from related product.
            System.assert(String.valueOf(ref).contains(testData.billings[0].Id));
            System.assertEquals(1, [SELECT count() FROM Billing_Line__c WHERE Product__r.Accounting_Type__c = 'Tax Rate']);
            System.assertEquals(1, ext.taxTableData.size());
            System.assertEquals(testData.products[3].Name, ext.taxTableData[0].taxableProducts.values()[0].values()[0]);
            System.assertEquals(
                ext.taxTableData[0].taxAmountTotal,
                [SELECT Id, Rate__c FROM Billing_Line__c WHERE Product__r.Accounting_Type__c = 'Tax Rate'].Rate__c
            );
            
            System.assertEquals(prod.GL_Account_Variable_1__c, bl.GL_Account_Variable_1__c);
            System.assertEquals(prod.GL_Account_Variable_2__c, bl.GL_Account_Variable_2__c);
            System.assertEquals(prod.GL_Account_Variable_3__c, bl.GL_Account_Variable_3__c);
            System.assertEquals(prod.GL_Account_Variable_4__c, bl.GL_Account_Variable_4__c);
            
        }
        
    }
     
}