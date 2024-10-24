@IsTest
private class BillingSalesAvaTaxTest {

    @IsTest
    private static void testEstimateTaxHLP() {
        TestDataSuite testData = TestDataSuite.getInstance(true);
        testData.createProducts();
        testData.createBillings();
        testData.enableAvaTaxCalculation();

        System.runAs(testData.users.get(1)) {

            Billing__c testBilling = testData.billings[0];
            //set Product for all related Billing Lines
            testData.billingLines[0].Product__c = testData.products[3].Id;
            testData.billingLines[1].Product__c = testData.products[3].Id;
            BillingLineActions.isSkipLineUpdateTrigger4LDV = true;
            update new List<Billing_Line__c>{testData.billingLines[0], testData.billingLines[1]};
            BillingLineActions.isSkipLineUpdateTrigger4LDV = false;

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

            Test.startTest();
            BillingSalesAvaTax controller = new BillingSalesAvaTax(new ApexPages.StandardController(testBilling));
            System.assertEquals(false, controller.isProcessed);

            controller.estimateTax();
            System.assertNotEquals(true, controller.billingLinesWithEstimatedTaxAmount.isEmpty());
            System.assertEquals(
                testData.billingLines[0].Hours_Units__c * testData.billingLines[0].Rate__c / 10,
                controller.billingLinesWithEstimatedTaxAmount.values()[0].billingLine.Tax_Amount2__c
            );
            System.assertEquals(
                testData.billingLines[1].Hours_Units__c * testData.billingLines[1].Rate__c / 10,
                controller.billingLinesWithEstimatedTaxAmount.values()[1].billingLine.Tax_Amount2__c
            );
        }
    }

    @IsTest
    private static void testCalcTaxHeaderSectionValuesHLP() {
        TestDataSuite testData = TestDataSuite.getInstance(true);
        testData.createProducts();
        testData.createBillings(false);
        testData.enableAvaTaxCalculation();

        System.runAs(testData.users.get(1)) {
            Billing__c testBilling = testData.billings[0];
            //set Product for all related Billing Lines
            testData.billingLines[0].Product__c = testData.products[3].Id;
            testData.billingLines[1].Product__c = testData.products[3].Id;
            BillingLineActions.isSkipLineUpdateTrigger4LDV = true;
            update new List<Billing_Line__c>{testData.billingLines[0], testData.billingLines[1]};

            //insert Non-Taxable Billing Line (no product)
            Billing_Line__c noProductBillingLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 20,
                Rate__c = 10,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            insert noProductBillingLine;
            BillingLineActions.isSkipLineUpdateTrigger4LDV = false;
            Test.startTest();
            //re-query taxable billing lines to have all necessary fields populated
            List<Billing_Line__c> testBillingLines = [
                SELECT Id, Name, Hours_Units__c, Rate__c
                FROM Billing_Line__c
                WHERE Billing__c = :testBilling.Id
                AND Product__c != NULL
            ];
            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(testBilling, testBillingLines, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            BillingSalesAvaTax controller = new BillingSalesAvaTax(new ApexPages.StandardController(
                [SELECT Id, Sub_Total__c, Sales_Tax3__c, Total__c FROM Billing__c WHERE Id = :testBilling.Id]
            ));
            System.assertEquals(false, controller.isProcessed);

            controller.estimateTax();
            System.assertNotEquals(true, controller.billingLinesWithEstimatedTaxAmount.isEmpty());
            System.assertEquals(
                testData.billingLines[0].Hours_Units__c * testData.billingLines[0].Rate__c / 10,
                controller.billingLinesWithEstimatedTaxAmount.values()[0].billingLine.Tax_Amount2__c
            );
            System.assertEquals(
                testData.billingLines[1].Hours_Units__c * testData.billingLines[1].Rate__c / 10,
                controller.billingLinesWithEstimatedTaxAmount.values()[1].billingLine.Tax_Amount2__c
            );
            controller.commitTax();
            //re-query Billing record to get Sub Total field populated
            Billing__c billing = [SELECT Id, Total__c, Sales_Tax3__c FROM Billing__c WHERE Id = :testBilling.Id];
            System.assertEquals(billing.Sales_Tax3__c, controller.estimatedTaxAmount);
            System.assertEquals(billing.Total__c, controller.estimatedTotal);
        }
    }

    @IsTest
    private static void testEstimateTaxLLP() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .setLineLevelPost()
            .createBillings()
            .enableAvaTaxCalculation();

        System.runAs(testData.users.get(1)) {

            Billing__c testBilling = testData.billings[0];
            //set Product for all related Billing Lines
            testData.billingLines[0].Product__c = testData.products[3].Id;
            testData.billingLines[1].Product__c = testData.products[3].Id;
            BillingLineActions.isSkipLineUpdateTrigger4LDV = true;
            update new List<Billing_Line__c>{testData.billingLines[0], testData.billingLines[1]};
            BillingLineActions.isSkipLineUpdateTrigger4LDV = false;

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

            Test.startTest();
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
    private static void testCommitTaxHLP() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createProducts()
            .createBillings()
            .enableAvaTaxCalculation();

        System.runAs(testData.users.get(1)) {

            Billing__c testBilling = testData.billings[0];
            //set Product for all related Billing Lines
            testData.billingLines[0].Product__c = testData.products[3].Id;
            testData.billingLines[1].Product__c = testData.products[3].Id;
            BillingLineActions.isSkipLineUpdateTrigger4LDV = true;
            update new List<Billing_Line__c>{testData.billingLines[0], testData.billingLines[1]};
            BillingLineActions.isSkipLineUpdateTrigger4LDV = false;

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

            Test.startTest();
            BillingSalesAvaTax controller = new BillingSalesAvaTax(new ApexPages.StandardController(testBilling));
            System.assertEquals(false, controller.isProcessed);

            controller.commitTax();

            List<Billing_Line__c> checkedBLines = [
                SELECT Id, Billing__r.Status__c, Hours_Units__c, Rate__c, Tax_Amount2__c
                FROM Billing_Line__c
                WHERE Id IN :testBillingLines
            ];

            System.assertEquals(
                testData.billingLines[0].Hours_Units__c * testData.billingLines[0].Rate__c / 10,
                checkedBLines[0].Tax_Amount2__c
            );
            System.assertEquals(
                testData.billingLines[1].Hours_Units__c * testData.billingLines[1].Rate__c / 10,
                checkedBLines[1].Tax_Amount2__c
            );
        }
    }

    @IsTest
    private static void testCommitTaxLLP() {
        TestDataSuite testData = TestDataSuite.getInstance(true);
        testData.setLineLevelPost();
        testData.createBillings();
        testData.enableAvaTaxCalculation();
        testData.createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            Billing__c testBilling = testData.billings[0];
            //set Product for all related Billing Lines
            testData.billingLines[0].Product__c = testData.products[3].Id;
            testData.billingLines[1].Product__c = testData.products[3].Id;
            BillingLineActions.isSkipLineUpdateTrigger4LDV = true;
            update new List<Billing_Line__c>{testData.billingLines[0], testData.billingLines[1]};
            BillingLineActions.isSkipLineUpdateTrigger4LDV = false;

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
            testBilling = [SELECT Id, Ledger__c, Sub_Total__c FROM Billing__c WHERE Id =: testBilling.Id LIMIT 1];
			Product2 prod = [SELECT Id, GL_Account_Variable_1__c, GL_Account_Variable_2__c, GL_Account_Variable_3__c, GL_Account_Variable_4__c FROM Product2 WHERE Id = :AvaTaxHelper.getSalesTaxProductId(testBilling)];
            prod.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            prod.GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            prod.GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            prod.GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update prod;

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();
            testBilling = [SELECT Id, Ledger__c, Sub_Total__c FROM Billing__c WHERE Id =: testBilling.Id LIMIT 1];
            BillingSalesAvaTax controller = new BillingSalesAvaTax(new ApexPages.StandardController(testBilling));
            System.assertEquals(false, controller.isProcessed);
            controller.commitTax();
            List<Billing_Line__c> salesTaxLines = [
                SELECT Id, Rate__c, Revenue_GL_Account__c, GL_Account_Variable_1__c, GL_Account_Variable_2__c, GL_Account_Variable_3__c, GL_Account_Variable_4__c
                FROM Billing_Line__c
                WHERE Billing__c = :testBilling.Id
                AND Product__c = :AvaTaxHelper.getSalesTaxProductId(testBilling)
            ];
            System.assertNotEquals(true, salesTaxLines.isEmpty());
            System.assertEquals(1, salesTaxLines.size());
            Decimal estimatedTaxAmountLine0 = testData.billingLines[0].Hours_Units__c * testData.billingLines[0].Rate__c / 10;
            Decimal estimatedTaxAmountLine1 = testData.billingLines[1].Hours_Units__c * testData.billingLines[1].Rate__c / 10;
            System.assertEquals(estimatedTaxAmountLine0 + estimatedTaxAmountLine1, salesTaxLines[0].Rate__c);
            System.assertEquals(estimatedTaxAmountLine0 + estimatedTaxAmountLine1, salesTaxLines[0].Rate__c);
            System.assertEquals(prod.GL_Account_Variable_1__c, salesTaxLines[0].GL_Account_Variable_1__c);
            System.assertEquals(prod.GL_Account_Variable_2__c, salesTaxLines[0].GL_Account_Variable_2__c);
            System.assertEquals(prod.GL_Account_Variable_3__c, salesTaxLines[0].GL_Account_Variable_3__c);
            System.assertEquals(prod.GL_Account_Variable_4__c, salesTaxLines[0].GL_Account_Variable_4__c);
        }
    }

    @IsTest
    private static void testPageLoadPostedBilling() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Billing__c testBilling = testData.billings[0];
            BillingSalesAvaTax controller = new BillingSalesAvaTax(new ApexPages.StandardController(testBilling));

            System.assertEquals(AbstractAvaTaxController.POSTED_RECORD_ERROR_MESSAGE, ApexPages.getMessages()[0].getDetail());
        }
    }

    @IsTest
    private static void testPageLoadAppliedBilling() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
            bcm.Billing_Invoice__c = testData.billings[0].Id;
            bcm.Billing_Credit_Memo__c = testData.billings[3].Id;
            bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
            bcm.Amount__c = -10;
            insert bcm;

            Billing__c testBilling = testData.billings[0];
            BillingSalesAvaTax controller = new BillingSalesAvaTax(new ApexPages.StandardController(testBilling));

            System.assertEquals(AbstractAvaTaxController.APPLIED_RECORD_ERROR_MESSAGE, ApexPages.getMessages()[0].getDetail());
        }
    }

    @IsTest
    private static void testPageLoadNoLineForCalcTaxLLP() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .setLineLevelPost()
            .createBillings()
            .enableAvaTaxCalculation();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Billing__c testBilling = testData.billings[0];
            BillingSalesAvaTax controller = new BillingSalesAvaTax(new ApexPages.StandardController(testBilling));
            System.assertEquals(AbstractAvaTaxController.NO_LINES_ERROR_MESSAGE, ApexPages.getMessages()[0].getDetail());
        }
    }

    @IsTest
    private static void testPageLoadNoLineForCalcTaxHLP() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .enableAvaTaxCalculation();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Billing__c testBilling = testData.billings[0];
            BillingSalesAvaTax controller = new BillingSalesAvaTax(new ApexPages.StandardController(testBilling));
            controller.estimateTax();
            System.assertEquals(AbstractAvaTaxController.NO_TAXABLE_LINES_FOUND_WARNING_MESSAGE, ApexPages.getMessages()[0].getDetail());
        }
    }

    @IsTest
    private static void testPageLoadNoAddressCalcTaxHLP() {
        TestDataSuite testData = TestDataSuite.getInstance(true);
        testData.createProducts();
        testData.createBillings();
        testData.enableAvaTaxCalculation();

        System.runAs(testData.users.get(1)) {
            Billing__c testBilling = testData.billings[1];
            //set Product for all related Billing Lines
            testData.billingLines[2].Product__c = testData.products[3].Id;
            testData.billingLines[3].Product__c = testData.products[3].Id;
            BillingLineActions.isSkipLineUpdateTrigger4LDV = true;
            update new List<Billing_Line__c>{testData.billingLines[2], testData.billingLines[3]};
            BillingLineActions.isSkipLineUpdateTrigger4LDV = false;
            //insert Non-Taxable Billing Line (no product)
            Billing_Line__c noProductBillingLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 20,
                Rate__c = 10,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            insert noProductBillingLine;
            //re-query taxable billing lines to have all necessary fields populated
            List<Billing_Line__c> testBillingLines = [
                SELECT Id, Name, Hours_Units__c, Rate__c
                FROM Billing_Line__c
                WHERE Billing__c = :testBilling.Id
                AND Product__c != NULL
            ];
            delete [SELECT Id FROM Address__c];
            TaxService.reset();
            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(testBilling, testBillingLines, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();
            BillingSalesAvaTax controller = new BillingSalesAvaTax(new ApexPages.StandardController(
                [SELECT Id, Sub_Total__c, Sales_Tax3__c, Total__c FROM Billing__c WHERE Id = :testBilling.Id]
            ));
            System.assertEquals(false, controller.isProcessed);
            controller.estimateTax();
            System.assertEquals(AbstractAvaTaxController.SHIPPING_ADDRESS_MISSING_WARNING_MESSAGE, ApexPages.getMessages()[0].getDetail());
        }
    }

    @IsTest
    private static void testPageLoadOverrideAddressCalcTaxHLP() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createProducts()
            .createBillings()
            .enableAvaTaxCalculation()
            .createAddressObjects();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Billing__c testBilling = testData.billings[1];
            testBilling.Destination_Address_Override__c = testData.addressObjects[0].Id;
            update testBilling;

            //set Product for all related Billing Lines
            testData.billingLines[0].Product__c = testData.products[3].Id;
            testData.billingLines[1].Product__c = testData.products[3].Id;
            update new List<Billing_Line__c>{testData.billingLines[0], testData.billingLines[1]};

            //insert Non-Taxable Billing Line (no product)
            Billing_Line__c noProductBillingLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 20,
                Rate__c = 10,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            insert noProductBillingLine;

            //re-query taxable billing lines to have all necessary fields populated
            List<Billing_Line__c> testBillingLines = [
                SELECT Id, Name, Hours_Units__c, Rate__c
                FROM Billing_Line__c
                WHERE Billing__c = :testBilling.Id
                AND Product__c != NULL
            ];

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(testBilling, testBillingLines, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            HttpProxy.setMock(xPostCreateOrAdjustTransactionRequestMock);

            BillingSalesAvaTax controller = new BillingSalesAvaTax(new ApexPages.StandardController(
                [SELECT Id, Sub_Total__c, Sales_Tax3__c, Total__c FROM Billing__c WHERE Id = :testBilling.Id]
            ));
            System.assertEquals(false, controller.isProcessed);

            controller.estimateTax();
            System.assert(ApexPages.getMessages().isEmpty() || !ApexPages.getMessages()[0].getDetail().contains(AbstractAvaTaxController.SHIPPING_ADDRESS_MISSING_WARNING_MESSAGE));
            Test.stopTest();
        }
    }

    @IsTest
    private static void testPageLoadNonUSDCurrencyOnLedger_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance(true)
                .enableMultiCurrency()
                .createBillings();

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
                Billing__c newBilling = testData.billings[0].clone(false, true);
                newBilling.Ledger__c = testLedger.Id;

                insert newBilling;

                Test.startTest();
                
                BillingSalesAvaTax controller = new BillingSalesAvaTax(new ApexPages.StandardController(newBilling));

                System.assertEquals(AbstractAvaTaxController.INCORRECT_CURRENCY_ERROR_MESSAGE, ApexPages.getMessages()[0].getDetail());
            }
        }
        catch (Exception ex) {

        }
    }

}