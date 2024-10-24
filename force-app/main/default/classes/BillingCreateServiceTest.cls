@IsTest
private class BillingCreateServiceTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testCreateBillingSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            BillingCreateService.BillingModel model = TestDataSuite.getBillingModel();
            model.customerId = testData.accounts[1].Id;
            List<RestResult> createResult = BillingCreateService.createBilling(model);
            List<Billing__c> res = [SELECT Id, Status__c FROM Billing__c WHERE Customer__c = :testData.accounts[1].Id];
            List<Billing_Line__c> resLine = [SELECT Id FROM Billing_Line__c WHERE Billing__c = :res[0].Id];
            System.assertEquals(true, createResult[0].isSuccess);
            System.assertEquals(1, res.size());
            System.assertEquals('Approved', res[0].Status__c);
            System.assertEquals(1, resLine.size());
        }
    }

    @IsTest
    private static void testCreateBillingAndPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            BillingCreateService.BillingModel model = TestDataSuite.getBillingModel();
            model.customerId = testData.accounts[1].Id;
            List<RestResult> createResult = BillingCreateService.createBillingAndPost(model);
            Test.stopTest();
            List<Billing__c> res = [SELECT Id, Status__c FROM Billing__c WHERE Customer__c = :testData.accounts[1].Id];
            List<Billing_Line__c> resLine = [SELECT Id FROM Billing_Line__c WHERE Billing__c = :res[0].Id];
            System.assertEquals(true, createResult[0].isSuccess);
            System.assertEquals(1, res.size());
            System.assertEquals('Posted', res[0].Status__c);
            System.assertEquals(1, resLine.size());
        }
    }

    @IsTest
    private static void testCreateBillingWithCustomMappingSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            BillingCreateService.BillingModel model = TestDataSuite.getBillingModel();
            model.customerId = testData.accounts[1].Id;
            model.fieldMappings.put('billingComment', 'test Comment');
            model.billingLines[0].fieldMappings.put('comment', 'test Line Comment');

            List<RestResult> createResult = BillingCreateService.createBilling(model);
            List<Billing__c> res = [SELECT Id, Status__c, Billing_Comment__c FROM Billing__c WHERE Customer__c = :testData.accounts[1].Id];
            List<Billing_Line__c> resLine = [SELECT Id, Comment__c FROM Billing_Line__c WHERE Billing__c = :res[0].Id];
            System.assertEquals(true, createResult[0].isSuccess);
            System.assertEquals(1, res.size());
            System.assertEquals(1, resLine.size());
            System.assertEquals(NULL, res[0].Billing_Comment__c);
            System.assertEquals(NULL, resLine[0].Comment__c);
        }
    }

    @IsTest
    private static void testCreateBillingIgnoreWrongFieldMappingSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            BillingCreateService.BillingModel model = TestDataSuite.getBillingModel();
            model.customerId = testData.accounts[1].Id;
            model.fieldMappings.put('wrongField', 'test Wrong');
            model.billingLines[0].fieldMappings.put('wrongLineField', 'test Wrong Line');

            List<RestResult> createResult = BillingCreateService.createBilling(model);
            List<Billing__c> res = [SELECT Id FROM Billing__c WHERE Customer__c = :testData.accounts[1].Id];
            List<Billing_Line__c> resLine = [SELECT Id FROM Billing_Line__c WHERE Billing__c = :res[0].Id];
            System.assertEquals(true, createResult[0].isSuccess);
            System.assertEquals(1, res.size());
            System.assertEquals(1, resLine.size());
        }
    }

    @IsTest
    private static void testCreateBillingRequiredFieldError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            BillingCreateService.BillingModel model = TestDataSuite.getBillingModel();
            List<RestResult> createResult = BillingCreateService.createBilling(model);

            System.assertEquals(BillingCreateService.REQUIRED_FIELD_ERROR, createResult[0].errors[0].message);
        }
    }

    @IsTest
    private static void testCreateBillingUnitPriceRequiredFieldError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            BillingCreateService.BillingModel model = TestDataSuite.getBillingModel();
            model.customerId = testData.accounts[1].Id;
            model.billingLines[0].unitPrice = NULL;
            List<RestResult> createResult = BillingCreateService.createBilling(model);

            System.assertEquals(BillingCreateService.REQUIRED_FIELD_ERROR, createResult[0].errors[0].message);
        }
    }

    @IsTest
    private static void testCreateBillingQuantityRequiredFieldError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            BillingCreateService.BillingModel model = TestDataSuite.getBillingModel();
            model.customerId = testData.accounts[1].Id;
            model.billingLines[0].quantity = NULL;
            List<RestResult> createResult = BillingCreateService.createBilling(model);

            System.assertEquals(BillingCreateService.REQUIRED_FIELD_ERROR, createResult[0].errors[0].message);
        }
    }

    @IsTest
    private static void testCreateBillingDataTypeError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            BillingCreateService.BillingModel model = TestDataSuite.getBillingModel();
            model.customerId = testData.accounts[1].Id;
            model.fieldMappings.put('currencyConversionRate', String.valueOf(System.today()));
            List<RestResult> createResult = BillingCreateService.createBilling(model);

            System.assertEquals(BillingCreateService.BILLING_MODEL_ERROR, createResult[0].errors[0].message);
        }
    }

    @IsTest
    private static void testCreateBillingAccountingPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            BillingCreateService.BillingModel model = TestDataSuite.getBillingModel();
            model.customerId = testData.accounts[1].Id;
            model.billingDate = Date.newInstance(1800, 10, 12);
            List<RestResult> createResult = BillingCreateService.createBilling(model);

            System.assertEquals(BillingCreateService.NO_PERIOD_ERROR_MESSAGE, createResult[0].errors[0].message);
        }
    }

    @IsTest
    private static void testValidatePostResult() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            List<PostResult> postResults = new List<PostResult>();
            List<PostResult.PostErrorResult> postErrorResults = new List<PostResult.PostErrorResult>();
            postErrorResults.add(new PostResult.PostErrorResult(NULL, 'Test Error'));
            postResults.add(new PostResult(false, NULL, postErrorResults));

            List<RestResult> restResults = BillingCreateService.validatePostResult(postResults);

            System.assertEquals('Test Error', restResults[0].errors[0].message);
            System.assertEquals('Post Result Error', restResults[0].errors[0].statusCode);
        }
    }

    @IsTest
    private static void testRequiredFieldCheck() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            BillingCreateService.BillingModel model = TestDataSuite.getBillingModel();
            System.assert(!BillingCreateService.requiredFieldCheck(model));

            model.customerId = testData.accounts[1].Id;
            System.assert(BillingCreateService.requiredFieldCheck(model));
        }
    }

    @IsTest
    private static void testNormalizeKey() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            String standardField = 'CurrencyIsoCode';
            String customWithPQField = 'PQ__Custom_Field__c';
            String customField = 'Custom_Field__c';

            System.assertEquals('currencyisocode', BillingCreateService.normalizeKey(standardField));
            System.assertEquals('customfield', BillingCreateService.normalizeKey(customWithPQField));
            System.assertEquals('customfield', BillingCreateService.normalizeKey(customField));

        }
    }

    @IsTest
    private static void testGetFieldMappings() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Set<String> fieldList = new Set<String>{GlobalVariables.PACKAGE_QUALIFIER + 'Billing_Comment__c'};
            BillingCreateService.BillingModel model = TestDataSuite.getBillingModel();
            model.fieldMappings.put('billingComment', 'test Comment');
            model.fieldMappings.put('testField', 'test Comment');

            Map<String, String> result = BillingCreateService.getFieldMappings(BillingCreateService.billingFieldMap, model.fieldMappings, fieldList);

            System.assert(result.isEmpty());
        }
    }

    @IsTest
    private static void testGetBillingFromModel() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            BillingCreateService.BillingModel model = TestDataSuite.getBillingModel();
            model.customerId = testData.accounts[1].Id;

            Billing__c result = BillingCreateService.getBillingFromModel(model);

            System.assertEquals(testData.accounts[1].Id, result.Customer__c);
            System.assertEquals(Date.newInstance(1991, 10, 12), result.Date__c);
        }
    }

    @IsTest
    private static void testGetBillingLinesFromModel() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            BillingCreateService.BillingModel model = TestDataSuite.getBillingModel();
            model.customerId = testData.accounts[1].Id;

            List<Billing_Line__c> result = BillingCreateService.getBillingLinesFromModel(model.billingLines, testData.billings[0]);

            System.assertEquals(testData.billings[0].Id, result[0].Billing__c);
            System.assertEquals(Date.newInstance(1991, 10, 12), result[0].Date__c);
            System.assertEquals(10.00, result[0].Rate__c);
            System.assertEquals(1, result[0].Hours_Units__c);
        }
    }

    @IsTest
    private static void testGetBilling() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            BillingCreateService.BillingModel model = TestDataSuite.getBillingModel();
            model.customerId = testData.accounts[1].Id;
            Billing__c result = BillingCreateService.getBilling(model);

            System.assertEquals(testData.accounts[1].Id, result.Customer__c);
            System.assertEquals(Date.newInstance(1991, 10, 12), result.Date__c);
            System.assertEquals(Date.newInstance(1991, 10, 20), result.Due_Date2__c);
        }
    }

    @IsTest
    private static void testGetBillingLine() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings().createProducts().createAccountingVariables();

        System.runAs(testData.users[1]) {
            BillingCreateService.BillingModel model = TestDataSuite.getBillingModel();
            model.billingLines[0].productId = testData.products[0].Id;
            model.billingLines[0].comment = 'test comment';
            model.billingLines[0].revenueGLAccountId = testData.glAccounts[10].Id;
            model.billingLines[0].glAccountVariable1 = testData.accountingVariables1[0].Id;
            model.billingLines[0].glAccountVariable2 = testData.accountingVariables2[0].Id;
            model.billingLines[0].glAccountVariable3 = testData.accountingVariables3[0].Id;
            model.billingLines[0].glAccountVariable4 = testData.accountingVariables4[0].Id;

            Billing_Line__c result = BillingCreateService.getBillingLines(model.billingLines[0], testData.billings[0].Id);

            System.assertEquals(testData.billings[0].Id, result.Billing__c);
            System.assertEquals(Date.newInstance(1991, 10, 12), result.Date__c);
            System.assertEquals(10.00, result.Rate__c);
            System.assertEquals(1, result.Hours_Units__c);
            System.assertEquals(15.00, result.List_Price__c);
            System.assertEquals('test comment', result.Comment__c);
            System.assertEquals(testData.products[0].Id, result.Product__c);
            System.assertEquals(testData.glAccounts[10].Id, result.Revenue_GL_Account__c);
            System.assertEquals(testData.accountingVariables1[0].Id, result.GL_Account_Variable_1__c);
            System.assertEquals(testData.accountingVariables2[0].Id, result.GL_Account_Variable_2__c);
            System.assertEquals(testData.accountingVariables3[0].Id, result.GL_Account_Variable_3__c);
            System.assertEquals(testData.accountingVariables4[0].Id, result.GL_Account_Variable_4__c);
        }
    }

    @IsTest
    public static void testCreateBillingWithAvalaraSalesTaxHLP() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createProducts()
            .enableAvaTaxCalculation();

        System.runAs(testData.users[1]) {
            BillingCreateService.BillingModel model = TestDataSuite.getBillingModel();
            model.customerId = testData.accounts[1].Id;
            model.billingLines[0].productId = testData.products[3].Id;

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(model, 50),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();

            List<RestResult> result = BillingCreateService.createBilling(model);

            List<Billing_Line__c> checkedBLine = [
                SELECT Id, Tax_Amount2__c
                FROM Billing_Line__c
                WHERE Billing__c = :result[0].id
            ];

            System.assertEquals(
                5,
                checkedBLine[0].Tax_Amount2__c
            );
        }

    }

    @IsTest
    public static void testCreateBillingWithAvalaraSalesTaxLLP() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createBillings()
            .createProducts()
            .enableAvaTaxCalculation();

        System.runAs(testData.users[1]) {
            BillingCreateService.BillingModel model = TestDataSuite.getBillingModel();
            model.ledgerId = testData.ledgers[0].Id;
            model.customerId = testData.accounts[1].Id;
            model.billingLines[0].productId = testData.products[3].Id;

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(model, 50),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();
            List<RestResult> result = BillingCreateService.createBilling(model);

            List<Billing_Line__c> salesTaxLines = [
                SELECT Id, Rate__c
                FROM Billing_Line__c
                WHERE Product__c = :AvaTaxHelper.getSalesTaxProductId([SELECT Ledger__c FROM Billing__c WHERE Id = :result[0].id])
                AND Billing__c = :result[0].id
            ];

            System.assertNotEquals(true, salesTaxLines.isEmpty());
        }

    }

    @IsTest
    public static void testCreateBillingWithAvalaraSalesTaxWithoutLinesHLP() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createProducts()
            .enableAvaTaxCalculation();

        System.runAs(testData.users[1]) {
            BillingCreateService.BillingModel model = TestDataSuite.getBillingModel();
            model.customerId = testData.accounts[1].Id;
            model.billingLines = new List<BillingCreateService.BillingLineModel>();

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(model, 50),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();

            List<RestResult> result = BillingCreateService.createBilling(model);

            List<Billing_Line__c> checkedBLine = [
                SELECT Id, Tax_Amount2__c
                FROM Billing_Line__c
                WHERE Billing__c = :result[0].id
            ];
            List<Billing__c> res = [SELECT Id, Status__c FROM Billing__c WHERE Id = :result[0].id];

            System.assertEquals(true, checkedBLine.isEmpty());
            System.assertEquals(false, res.isEmpty());
        }

    }

    @IsTest
    public static void testCreateBillingWithAvalaraSalesTaxWithoutLinesLLP() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createBillings()
            .createProducts()
            .enableAvaTaxCalculation();

        System.runAs(testData.users[1]) {
            BillingCreateService.BillingModel model = TestDataSuite.getBillingModel();
            model.customerId = testData.accounts[1].Id;
            model.billingLines = new List<BillingCreateService.BillingLineModel>();

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(model, 50),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();

            List<RestResult> result = BillingCreateService.createBilling(model);

            List<Billing_Line__c> checkedBLine = [
                SELECT Id, Tax_Amount2__c
                FROM Billing_Line__c
                WHERE Billing__c = :result[0].id
            ];
            List<Billing__c> res = [SELECT Id, Status__c FROM Billing__c WHERE Id = :result[0].id];

            System.assertEquals(true, checkedBLine.isEmpty());
            System.assertEquals(false, res.isEmpty());
        }

    }

    @IsTest
    public static void testCreateBillingWithNativeSalesTaxWithoutLines() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createProducts();

        System.runAs(testData.users[1]) {
            BillingCreateService.BillingModel model = TestDataSuite.getBillingModel();
            model.customerId = testData.accounts[1].Id;
            model.billingLines = NULL;

            Test.startTest();

            List<RestResult> result = BillingCreateService.createBilling(model);

            List<Billing_Line__c> salesTaxLines = [
                SELECT Id, Rate__c
                FROM Billing_Line__c
                WHERE Product__c = :AvaTaxHelper.getSalesTaxProductId(testData.billings[1])
                AND Billing__c = :result[0].id
            ];
            List<Billing__c> res = [SELECT Id, Status__c FROM Billing__c WHERE Id = :result[0].id];
            System.assertEquals(true, salesTaxLines.isEmpty());
            System.assertEquals(false, res.isEmpty());
        }

    }
}