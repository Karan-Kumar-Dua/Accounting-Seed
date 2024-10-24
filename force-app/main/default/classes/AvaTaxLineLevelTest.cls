@IsTest
private class AvaTaxLineLevelTest {

    @IsTest
    private static void testEstimateTax() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .setLineLevelPost()
            .createBillings()
            .enableAvaTaxCalculation();

        System.runAs(testData.users.get(1)) {

            Billing__c testBilling = testData.billings[0];
            //set Product for all related Billing Lines
            testData.billingLines[0].Product__c = testData.products[3].Id;
            testData.billingLines[1].Product__c = testData.products[3].Id;
            update new List<Billing_Line__c>{testData.billingLines[0], testData.billingLines[1]};

            Test.startTest();
            //re-query billing line to have all necessary fields populated
            List<Billing_Line__c> testBillingLines = [
                SELECT Id, Name, Hours_Units__c, Rate__c
                FROM Billing_Line__c
                WHERE Billing__c = :testBilling.Id
            ];

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(testBilling, testBillingLines, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            BillingSalesAvaTax controller = new BillingSalesAvaTax(new ApexPages.StandardController(testBilling));
            System.assertEquals(false, controller.isProcessed);

            controller.estimateTax();

            System.assertNotEquals(true, controller.billingLinesWithEstimatedTaxAmount.isEmpty());
            Decimal estimatedTaxAmountLine0 = testData.billingLines[0].Hours_Units__c * testData.billingLines[0].Rate__c / 10;
            Decimal estimatedTaxAmountLine1 = testData.billingLines[1].Hours_Units__c * testData.billingLines[1].Rate__c / 10;
            System.assertEquals(estimatedTaxAmountLine0 + estimatedTaxAmountLine1, controller.billingLinesWithEstimatedTaxAmount.values()[0].billingLine.Rate__c);
        }
    }

    @IsTest
    private static void testCommitTax() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .setLineLevelPost()
            .createBillings()
            .enableAvaTaxCalculation();

        System.runAs(testData.users.get(1)) {

            Billing__c testBilling = testData.billings[0];
            //set Product for all related Billing Lines
            testData.billingLines[0].Product__c = testData.products[3].Id;
            testData.billingLines[1].Product__c = testData.products[3].Id;
            update new List<Billing_Line__c>{testData.billingLines[0], testData.billingLines[1]};

            Test.startTest();
            //re-query billing line to have all necessary fields populated
            List<Billing_Line__c> testBillingLines = [
                SELECT Id, Name, Hours_Units__c, Rate__c
                FROM Billing_Line__c
                WHERE Billing__c = :testBilling.Id
            ];

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(testBilling, testBillingLines, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            testBilling = [SELECT Id, Ledger__c, Sub_Total__c FROM Billing__c WHERE Id =: testBilling.Id LIMIT 1];
            BillingSalesAvaTax controller = new BillingSalesAvaTax(new ApexPages.StandardController(testBilling));
            System.assertEquals(false, controller.isProcessed);

            controller.commitTax();

            List<Billing_Line__c> salesTaxLines = [
                SELECT Id, Rate__c, Revenue_GL_Account__c
                FROM Billing_Line__c
                WHERE Billing__c = :testBilling.Id
                AND Product__c = :AvaTaxHelper.getSalesTaxProductId(testBilling)
            ];

            System.assertNotEquals(true, salesTaxLines.isEmpty());
            System.assertEquals(1, salesTaxLines.size());
            Decimal estimatedTaxAmountLine0 = testData.billingLines[0].Hours_Units__c * testData.billingLines[0].Rate__c / 10;
            Decimal estimatedTaxAmountLine1 = testData.billingLines[1].Hours_Units__c * testData.billingLines[1].Rate__c / 10;
            System.assertEquals(estimatedTaxAmountLine0 + estimatedTaxAmountLine1, salesTaxLines[0].Rate__c);
            System.assertEquals(AvaTaxHelper.getAvaTaxGLAccount(testBilling), salesTaxLines[0].Revenue_GL_Account__c);
        }
    }
}