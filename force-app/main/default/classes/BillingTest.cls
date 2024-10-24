@IsTest
private class BillingTest {

    @TestSetup
    static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testCreateBillingSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            //Create Model
            BillingModel model = new BillingModel();
            //Create Billing
            Billing__c testBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c + 3,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = System.today() + 30
            );
            model.bill = testBilling;
            //Create Billing Lines
            List<Billing_Line__c> billingLines = new List<Billing_Line__c>();
            Billing_Line__c testBillingLine1 = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 1,
                Rate__c = 100,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            billingLines.add(testBillingLine1);

            Billing_Line__c testBillingLine2 = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 2,
                Rate__c = 50,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            billingLines.add(testBillingLine2);
            model.billLines = billingLines;

            Test.startTest();
            ServiceResult sr = Billing.create(model);
            List<Billing__c> billings = [
                SELECT Id, (SELECT Id FROM Project_Billing_Lines__r) FROM Billing__c
            ];
            System.assertEquals(true, sr.isSuccess);
            System.assertNotEquals(true, billings.isEmpty());
            System.assertEquals(2, sr.results.size());
            System.assertEquals(true, sr.results[0].isSuccess);
            System.assertEquals(true, sr.results[1].isSuccess);
            Map<Id, Billing_Line__c> billingLinesInDbMap = new Map<Id, Billing_Line__c>(billings[0].Project_Billing_Lines__r);
            System.assertEquals(true, billingLinesInDbMap.containsKey(sr.results[0].data));
            System.assertEquals(true, billingLinesInDbMap.containsKey(sr.results[1].data));
        }
    }

    @IsTest
    static void testCreateBillingsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            //Create Models
            List<BillingModel> models = new List<BillingModel>();
            BillingModel model1 = new BillingModel();
            BillingModel model2 = new BillingModel();
            //Create Billings
            Billing__c testBilling1 = new Billing__c(
                Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c + 3,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = System.today() + 30
            );
            model1.bill = testBilling1;
            Billing__c testBilling2 = new Billing__c(
                Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c + 3,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = System.today() + 30
            );
            model2.bill = testBilling2;
            //Create Billing Lines
            List<Billing_Line__c> billingLines1 = new List<Billing_Line__c>();
            List<Billing_Line__c> billingLines2 = new List<Billing_Line__c>();
            Billing_Line__c testBillingLine11 = new Billing_Line__c(
                Billing__c = testBilling1.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 1,
                Rate__c = 100,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            billingLines1.add(testBillingLine11);

            Billing_Line__c testBillingLine12 = new Billing_Line__c(
                Billing__c = testBilling1.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 2,
                Rate__c = 50,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            billingLines1.add(testBillingLine12);
            model1.billLines = billingLines1;

            Billing_Line__c testBillingLine21 = new Billing_Line__c(
                Billing__c = testBilling2.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 1,
                Rate__c = 100,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            billingLines2.add(testBillingLine21);

            Billing_Line__c testBillingLine22 = new Billing_Line__c(
                Billing__c = testBilling2.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 2,
                Rate__c = 50,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            billingLines2.add(testBillingLine22);
            model2.billLines = billingLines2;
            models.add(model1);
            models.add(model2);

            Test.startTest();
            ServiceResult sr = Billing.create(models);
            Map<ID, Billing__c> billings = new Map<ID, Billing__c>([
                SELECT Id, (SELECT Id FROM Project_Billing_Lines__r) FROM Billing__c
            ]);

            System.assertEquals(true, sr.isSuccess);
            System.assertNotEquals(true, billings.isEmpty());
            System.assertEquals(2, sr.results.size(), 'The service result should contian an entry for each billing (2 total).');
            System.assertEquals(2, sr.results[0].results.size(), 'The service result for the (1st) billing should have 2 billing lines.');
            System.assertEquals(2, sr.results[1].results.size(), 'The service result for the (2nd) billing should have 2 billing lines.');

            System.assertEquals(true, sr.results[0].isSuccess, 'All service result elements should be successful');
            System.assertEquals(true, sr.results[1].isSuccess, 'All service result elements should be successful');
            System.assertEquals(true, sr.results[0].results[0].isSuccess, 'All service result elements should be successful');
            System.assertEquals(true, sr.results[0].results[1].isSuccess, 'All service result elements should be successful');
            System.assertEquals(true, sr.results[1].results[0].isSuccess, 'All service result elements should be successful');
            System.assertEquals(true, sr.results[1].results[1].isSuccess, 'All service result elements should be successful');
            
            Billing__c billingOne = billings.get(sr.results[0].data);
            System.assertNotEquals(null, billingOne, 'No billing found for corresponding service result');

            Map<ID, Billing_Line__c> billingLinesOne = new Map<ID, Billing_Line__c>(billingOne.Project_Billing_Lines__r);
            System.assertNotEquals(null, billingLinesOne.get(sr.results[0].results[0].data), 'No billing line found for corresponding service result.');
            System.assertNotEquals(null, billingLinesOne.get(sr.results[0].results[1].data), 'No billing line found for corresponding service result.');
                 
            Billing__c billingTwo = billings.get(sr.results[1].data);
            System.assertNotEquals(null, billingTwo, 'No billing found for corresponding service result');

            Map<ID, Billing_Line__c> billingLinesTwo = new Map<ID, Billing_Line__c>(billingTwo.Project_Billing_Lines__r);
            System.assertNotEquals(null, billingLinesTwo.get(sr.results[1].results[0].data), 'No billing line found for corresponding service result.');
            System.assertNotEquals(null, billingLinesTwo.get(sr.results[1].results[1].data), 'No billing line found for corresponding service result.');
        }
    }

    @IsTest
    static void testCreateBillingsLineSaveFailed() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            //Create Models
            List<BillingModel> models = new List<BillingModel>();
            BillingModel model1 = new BillingModel();
            BillingModel model2 = new BillingModel();
            //Create Billings
            Billing__c testBilling1 = new Billing__c(
                Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c + 3,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = System.today() + 30
            );
            model1.bill = testBilling1;
            Billing__c testBilling2 = new Billing__c(
                Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c + 3,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = System.today() + 30
            );
            model2.bill = testBilling2;
            //Create Billing Lines
            List<Billing_Line__c> billingLines1 = new List<Billing_Line__c>();
            List<Billing_Line__c> billingLines2 = new List<Billing_Line__c>();
            Billing_Line__c testBillingLine11 = new Billing_Line__c(
                Billing__c = testBilling1.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 1,
                Rate__c = 100,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            billingLines1.add(testBillingLine11);

            Billing_Line__c testBillingLine12 = new Billing_Line__c(
                Billing__c = testBilling1.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = NULL,//will cause DML error
                Rate__c = 50,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            billingLines1.add(testBillingLine12);
            model1.billLines = billingLines1;

            Billing_Line__c testBillingLine21 = new Billing_Line__c(
                Billing__c = testBilling2.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 1,
                Rate__c = 100,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            billingLines2.add(testBillingLine21);

            Billing_Line__c testBillingLine22 = new Billing_Line__c(
                Billing__c = testBilling2.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = NULL,//will cause DML error
                Rate__c = 50,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            billingLines2.add(testBillingLine22);
            model2.billLines = billingLines2;
            models.add(model1);
            models.add(model2);

            Test.startTest();
            ServiceResult sr = Billing.create(models);
            List<Billing__c> billings = [
                SELECT Id, (SELECT Id FROM Project_Billing_Lines__r) FROM Billing__c
            ];
            System.assertEquals(true, sr.isSuccess);
            System.assertNotEquals(true, billings.isEmpty());
            System.assertEquals(2, sr.results.size());
            System.assertEquals(2, sr.results[0].results.size());
            System.assertEquals(2, sr.results[1].results.size());
            System.assertEquals(billings[0].Project_Billing_Lines__r[0].Id, sr.results[0].results[0].data);
            System.assertEquals(true, sr.results[0].isSuccess);
            System.assertEquals(true, sr.results[0].results[0].isSuccess);
            System.assertEquals(false, sr.results[0].results[1].isSuccess);
            System.assertEquals(NULL, sr.results[0].results[1].data);
            System.assertEquals(billings[1].Project_Billing_Lines__r[0].Id, sr.results[1].results[0].data);
            System.assertEquals(true, sr.results[0].isSuccess);
            System.assertEquals(true, sr.results[0].results[0].isSuccess);
            System.assertEquals(false, sr.results[0].results[1].isSuccess);
            System.assertEquals(NULL, sr.results[1].results[1].data);
        }
    }

    @IsTest
    static void testCreateBillingNoDataProvided() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            //Create Model
            BillingModel model = new BillingModel();
            Test.startTest();
            ServiceResult sr = Billing.create(model);
            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(Billing.INVALID_RECORD_OR_ID, sr.errors.get(0).detail);
        }
    }

    @IsTest
    static void testCreateBillingNoModelProvided() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            //Create Model
            BillingModel model;
            Test.startTest();
            ServiceResult sr = Billing.create(model);
            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(Billing.NO_INPUT_DATA, sr.errors.get(0).detail);
        }
    }

    @IsTest
    static void testPostBillings() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        System.runAs(testData.users.get(1)) {
            Map<Id, Billing__c> billings = new Map<Id, Billing__c>([
                SELECT Id
                FROM Billing__c
            ]);
            Test.startTest();
            List<ServiceResult> postResults = Billing.post(new List<Id>(billings.keySet()));
            System.assertEquals(true, postResults.get(0).isSuccess);
            for (Billing__c bill : [SELECT Id, Status__c FROM Billing__c]) {
                System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, bill.Status__c);
            }
        }
    }

    @IsTest
    static void testPostBilling() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            ServiceResult postResult = Billing.post(testData.billings.get(0).Id);
            System.assertEquals(true, postResult.isSuccess);
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, [
                    SELECT Id, Status__c FROM Billing__c WHERE Id = :testData.billings.get(0).Id
                ].Status__c
            );
        }
    }

    @IsTest
    static void testUnPostBillings() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            ServiceResult postResult = Billing.unpost(testData.billings.get(0).Id);
            System.assertEquals(true, postResult.isSuccess);
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, [
                    SELECT Id, Status__c FROM Billing__c WHERE Id = :testData.billings.get(0).Id
                ].Status__c
            );
        }
    }

    @IsTest
    static void testRetrieveBilling() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            BillingModel billModel = Billing.retrieve(testData.billings.get(0).Id);

            Billing__c existedBill = [SELECT Id FROM Billing__c WHERE Id = :testData.billings.get(0).Id];
            List<Billing_Line__c> existedBillLines = [SELECT Id, Billing__c FROM Billing_Line__c WHERE Billing__c = :testData.billings.get(0).Id];

            System.assertEquals(existedBill.Id, billModel.bill.Id);
            System.assertEquals(existedBillLines.size(), billModel.billLines.size());
        }
    }

    @IsTest
    static void testRetrieveBillingForClone() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            BillingModel billModel = Billing.retrieve(testData.billings.get(0).Id, true);

            Billing__c existedBill = [SELECT Id FROM Billing__c WHERE Id = :testData.billings.get(0).Id];
            List<Billing_Line__c> existedBillLines = [SELECT Id, Billing__c FROM Billing_Line__c WHERE Billing__c = :testData.billings.get(0).Id];

            System.assertEquals(existedBill.Id, billModel.bill.Id);
            System.assertEquals(existedBillLines.size(), billModel.billLines.size());
        }
    }

    @IsTest
    static void testRetrieveBillingWrongId() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);
        Test.startTest();
        testData.createPayables(false);

        System.runAs(testData.users.get(1)) {
            BillingModel billModel = Billing.retrieve(Id.valueOf('333xa000003DIlo'));

            System.assertEquals(NULL, billModel.bill);
            System.assertEquals(NULL, billModel.billLines);

            billModel = Billing.retrieve(testData.payables.get(0).Id);

            System.assertEquals(NULL, billModel.bill);
            System.assertEquals(NULL, billModel.billLines);
        }
        Test.stopTest();
    }

    @IsTest
    static void testAttemptToUseCalcTaxServiceInNonAvalaraTaxCalcMode() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProducts()
            .createBillings();

        System.runAs(testData.users.get(1)) {
            Billing.BillingException billEx;
            try {
                Billing.calcTax(testData.billings[0].Id);
            }
            catch (Billing.BillingException ex) {
                billEx = ex;
            }
            System.assertNotEquals(NULL, billEx);
            System.assertEquals(APIServiceContext.AVATAX_CONTEXT_ONLY_ERROR, billEx.getMessage());
        }
    }

    @IsTest
    static void testCalcTaxHLP() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProducts()
            .createBillings(false)
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
            BillingModel result = Billing.calcTax(testBilling.Id);
            System.assertEquals(testBilling.Id, result.bill.Id);

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
    private static void testCalcTaxLLP() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.setLineLevelPost();
        testData.createBillings(false);
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

            testBilling = [SELECT Id, Ledger__c, Sub_Total__c FROM Billing__c WHERE Id =: testBilling.Id LIMIT 1];
            Test.startTest();
            BillingModel result = Billing.calcTax(testBilling.Id);
            System.assertEquals(testBilling.Id, result.bill.Id);
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

    @IsTest
    private static void testGeneratePDF() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Id billingId = testData.billings.get(0).Id;
            //Call Billing API generatePDF method
            Blob result = Billing.generatePDF(billingId);
            //Check result was received
            System.assertNotEquals(NULL, result);
            //Save result as attachment to the given Billing record
            ContentVersion file = new ContentVersion(
                ContentDocumentId = NULL,
                Title = 'Test PDF File',
                PathOnClient = 'Test PDF File',
                VersionData = result
            );
            insert file;

            file = DomainUtils.getFilesById(new Set<Id>{file.Id}).get(0);

            ContentDocumentLink cdLink = new ContentDocumentLink(
                ContentDocumentId = file.ContentDocumentId,
                LinkedEntityId = billingId,
                ShareType = 'I',
                Visibility = 'AllUsers'
            );
            insert cdLink;

            List<ContentVersion> attachments = DomainUtils.getFilesByLinkedEntityId(billingId);
            System.assertNotEquals(true, attachments.isEmpty());
        }
    }

}