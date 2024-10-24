@IsTest
public class AvaTaxExceptionReportControllerTest {

    @TestSetup
    private static void setupTestData() {
        LedgerActions.isPreventUpdateOverride = true;
        AccountingPeriodActions.isPreventUpdateOverride = true;
        GLAccountActions.isPreventUpdateOverride = true;
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createProducts();

        System.runAs(testData.users.get(1)) {
            //Add Avalara Product on the new billing line
            Billing_Line__c newBillingLine = new Billing_Line__c(
                Billing__c = testData.billings[0].Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 20,
                Rate__c = 10,
                Product__c = testData.products[5].Id,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            insert newBillingLine;

            for (Billing__c billing : testData.billings) {
                billing.Due_Date2__c = Date.today();
                billing.Date__c = Date.today().addDays(-10);
                billing.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED;
            }
            SourceDocumentUpdateFieldValidator.overridePreventUpdateStatusFieldPosted = true;
            update testData.billings;

            // AbstractPostHandler billPostHandler = new BillingPostHandler();
            // List<PostResult> postResults = billPostHandler.post(testData.billings);
            // System.assertEquals(true, postResults[0].isSuccess);
        }
    }

    @IsTest
    public static void testInitialPageLoad() {
        Test.startTest();//to avoid "You have uncommitted work pending. Please commit or rollback before calling out" exception
        TestDataSuite testData = TestDataSuite.getInstance().enableAvaTaxCalculation();

        System.runAs(testData.users.get(1)) {

            AvaTaxExceptionReportController controller = new AvaTaxExceptionReportController();

            System.assertEquals(Date.today().addDays(-30), controller.dateRangeProxyObj.Billing_Cycle_Start_Date__c);
            System.assertEquals(Date.today(), controller.dateRangeProxyObj.Billing_Cycle_End_Date__c);
        }
    }

    @IsTest
    public static void testRunSalesTaxReport() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance();
        LedgerActions.isPreventUpdateOverride = true;
        testData.enableAvaTaxCalculation();
        testData.setLineLevelPost();

        System.runAs(testData.users.get(1)) {
            SingleRequestMock xGetListTransactionByCompanyRequestMock = new SingleRequestMock(
                200,
                'Complete',
                getListTransactionByCompanyResponseBody([SELECT Id, Name, Total__c, Sales_Tax2__c FROM Billing__c], 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            HttpProxy.setMock(xGetListTransactionByCompanyRequestMock);

            AvaTaxExceptionReportController controller = new AvaTaxExceptionReportController();
            controller.runSalesTaxReport();

            System.assertEquals(true, controller.isReportLineExists);
            System.assertEquals(1, controller.taxExceptionReportLines.size());
            System.assertEquals(AvaTaxExceptionReportController.AMOUNT_MISMATCH, controller.taxExceptionReportLines[0].statusDescription);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testRunSalesTaxReportNoAvaTaxTransactions() {
        Test.startTest();
        LedgerActions.isPreventUpdateOverride = true;
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.enableAvaTaxCalculation().setLineLevelPost();

        System.runAs(testData.users.get(1)) {
            SingleRequestMock xGetListTransactionByCompanyRequestMock = new SingleRequestMock(
                200,
                'Complete',
                getListTransactionByCompanyResponseBody('custom-billing-name', 500, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            HttpProxy.setMock(xGetListTransactionByCompanyRequestMock);

            AvaTaxExceptionReportController controller = new AvaTaxExceptionReportController();
            controller.runSalesTaxReport();

            System.assertEquals(true, controller.isReportLineExists);
            System.assertEquals(1, controller.taxExceptionReportLines.size());
            System.assertEquals(AvaTaxExceptionReportController.NO_MATCHING_TRANSACTIONS, controller.taxExceptionReportLines[0].statusDescription);
        }
        Test.stopTest();
    }

    @IsTest
    public static void testRunSalesTaxReportNoAvaTaxTransactionsHLP() {
        Test.startTest();
        LedgerActions.isPreventUpdateOverride = true;
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.enableAvaTaxCalculation();

        System.runAs(testData.users.get(1)) {
            SingleRequestMock xGetListTransactionByCompanyRequestMock = new SingleRequestMock(
                200,
                'Complete',
                getListTransactionByCompanyResponseBody('custom-billing-name', 500, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            HttpProxy.setMock(xGetListTransactionByCompanyRequestMock);

            AvaTaxExceptionReportController controller = new AvaTaxExceptionReportController();
            controller.runSalesTaxReport();

            System.assertEquals(true, controller.isReportLineExists);
            System.assertEquals(1, controller.taxExceptionReportLines.size());
            System.assertEquals(AvaTaxExceptionReportController.NO_MATCHING_TRANSACTIONS, controller.taxExceptionReportLines[0].statusDescription);
        }
        Test.stopTest();
    }

    @IsTest
    public static void testRunSalesTaxReportHLP() {
        Test.startTest();
        LedgerActions.isPreventUpdateOverride = true;
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.enableAvaTaxCalculation();

        System.runAs(testData.users.get(1)) {
            SingleRequestMock xGetListTransactionByCompanyRequestMock = new SingleRequestMock(
                200,
                'Complete',
                getListTransactionByCompanyResponseBody([SELECT Id, Name, Total__c, Sales_Tax3__c FROM Billing__c], 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            HttpProxy.setMock(xGetListTransactionByCompanyRequestMock);

            AvaTaxExceptionReportController controller = new AvaTaxExceptionReportController();
            controller.runSalesTaxReport();

            System.assertEquals(true, controller.isReportLineExists);
            System.assertEquals(1, controller.taxExceptionReportLines.size());
            System.assertEquals(AvaTaxExceptionReportController.AMOUNT_MISMATCH, controller.taxExceptionReportLines[0].statusDescription);
        }
        Test.stopTest();
    }

    @IsTest
    public static void testRunSalesTaxReportMoreThenMaxLineLimitInProcessing() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            testData.createProducts();
            //For the test context the MAX_LINE_LIMIT will be decreased from 500 to 100
            //create {MAX_LINE_LIMIT} Billings each with 1 line with Product
            List<Billing__c> newBillings = new List<Billing__c>();
            List<Billing_Line__c> newBillingLines = new List<Billing_Line__c>();

            for (Integer i = 0; i < AvaTaxExceptionReportController.MAX_LINE_LIMIT + 1; i++) {
                Billing__c tempBilling = new Billing__c(
                    Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                    Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c + 3,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Customer__c = testData.accounts[0].Id,
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Billing_Format__c = testData.billingFormats[0].Id,
                    Due_Date2__c = testData.acctPeriods[0].End_Date__c + 30,
                    Ledger__c = testData.ledgers[0].Id
                );
                newBillings.add(tempBilling);
            }
            insert newBillings;

            for (Billing__c billing : newBillings) {
                Billing_Line__c tempBillingLine = new Billing_Line__c(
                    Billing__c = billing.Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c.addDays(10),
                    Hours_Units__c = 1,
                    Rate__c = 10 + Integer.valueOf(Math.random() * 10) + Integer.valueOf(Math.random() * 10) + Integer.valueOf(Math.random() * 10),
                    Revenue_GL_Account__c = testData.glAccounts[10].Id,
                    Product__c = testData.products[0].Id
                );
                newBillingLines.add(tempBillingLine);
            }
            insert newBillingLines;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.post(newBillings);
            System.assertEquals(true, postResults[0].isSuccess);

            testData.enableAvaTaxCalculation();
            AvaTaxExceptionReportController controller = new AvaTaxExceptionReportController();
            controller.dateRangeProxyObj.Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c.addDays(-1);
            controller.dateRangeProxyObj.Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c.addDays(30);
            controller.skipCallout = true;
            controller.testResponse = getListTransactionByCompanyResponseBodyMoreThen500();

            controller.runSalesTaxReport();
            Test.stopTest();
            System.assertEquals(true, controller.isReportLineExists);
            System.assertEquals(AvaTaxExceptionReportController.MAX_LINE_LIMIT, controller.taxExceptionReportLines.size());
            System.assertEquals(AvaTaxExceptionReportController.MAX_LINE_LIMIT_INFO_MESSAGE, ApexPages.getMessages()[0].getSummary());
        }
    }

    @IsTest
    public static void testOriginDestinationAddressOverrideAddressCompare() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            testData.createProducts();
            testData.createAddressObjects();

            List<Billing__c> newBillings = new List<Billing__c>();
            List<Billing_Line__c> newBillingLines = new List<Billing_Line__c>();
            List<Address__c> billingAddresses = [SELECT Id, Street__c, City__c, Postal_Code__c, State_Province__c, Country_Code__c FROM Address__c LIMIT 2];

            Billing__c tempBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c + 3,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = testData.acctPeriods[0].End_Date__c + 30,
                Ledger__c = testData.ledgers[0].Id,
                Origin_Address_Override__c = billingAddresses[0].Id,
                Destination_Address_Override__c = billingAddresses[1].Id
            );
            newBillings.add(tempBilling);
            insert newBillings;

            Billing_Line__c tempBillingLine = new Billing_Line__c(
                Billing__c = tempBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c.addDays(10),
                Hours_Units__c = 1,
                Rate__c = 10 + Integer.valueOf(Math.random() * 10) + Integer.valueOf(Math.random() * 10) + Integer.valueOf(Math.random() * 10),
                Revenue_GL_Account__c = testData.glAccounts[10].Id,
                Product__c = testData.products[0].Id
            );
            newBillingLines.add(tempBillingLine);
            insert newBillingLines;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.post(newBillings);
            System.assertEquals(true, postResults[0].isSuccess);

            testData.enableAvaTaxCalculation();
            AvaTaxExceptionReportController controller = new AvaTaxExceptionReportController();
            controller.dateRangeProxyObj.Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c.addDays(-1);
            controller.dateRangeProxyObj.Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c.addDays(30);
            controller.skipCallout = true;
            Billing__c targetBilling = [SELECT Id, Name FROM Billing__c WHERE Id = :newBillings[0].Id];

            controller.testResponse = getListTransactionWithAddresses(targetBilling.Name, testData, billingAddresses[0], billingAddresses[1]);

            controller.runSalesTaxReport();
            Test.stopTest();
            System.assertEquals(0, controller.taxExceptionReportLines.size());
        }
    }

    private static String getListTransactionByCompanyResponseBody(List<Billing__c> billings, Decimal taxDiff) {
        AvaTaxService.FetchResultTransactionModel result = new AvaTaxService.FetchResultTransactionModel();
        List<AvaTaxService.TransactionModel> models = new List<AvaTaxService.TransactionModel>();
        for (Billing__c bill : billings) {
            AvaTaxService.TransactionModel tempTransactionModel = new AvaTaxService.TransactionModel();
            tempTransactionModel.id = 000000000000000;
            tempTransactionModel.code = bill.Name;
            tempTransactionModel.companyId = 12345;
            tempTransactionModel.avaTaxDate = Date.today();
            tempTransactionModel.totalTax = ((AccountingSettingsHandler.isHeaderLevelPost()) ? bill.Sales_Tax3__c : bill.Sales_Tax2__c) + taxDiff;
            models.add(tempTransactionModel);
        }
        result.setValue(models);
        return JSON.serialize(result);
    }

    private static String getListTransactionByCompanyResponseBody(String billingName, Decimal taxAmount, Decimal taxRatePercent) {
        AvaTaxService.FetchResultTransactionModel result = new AvaTaxService.FetchResultTransactionModel();
        List<AvaTaxService.TransactionModel> models = new List<AvaTaxService.TransactionModel>();
        AvaTaxService.TransactionModel tempTransactionModel = new AvaTaxService.TransactionModel();
        tempTransactionModel.id = 000000000000000;
        tempTransactionModel.code = billingName;
        tempTransactionModel.companyId = 12345;
        tempTransactionModel.avaTaxDate = Date.today();
        tempTransactionModel.totalTax = taxAmount + (taxAmount * taxRatePercent / 100);
        models.add(tempTransactionModel);
        result.setValue(models);
        return JSON.serialize(result);
    }

    private static AvaTaxService.FetchResultTransactionModel getListTransactionByCompanyResponseBodyMoreThen500() {
        AvaTaxService.FetchResultTransactionModel result = new AvaTaxService.FetchResultTransactionModel();
        List<AvaTaxService.TransactionModel> response = new List<AvaTaxService.TransactionModel>();
        for (Integer i = 0; i < 501; i++) {
            AvaTaxService.TransactionModel tempTrans = new AvaTaxService.TransactionModel();
            tempTrans.id = 123456000 + i;
            tempTrans.code = 'dcca7719-74ad-451e-b65f-55d242379c2f';
            tempTrans.companyId = 12345;
            tempTrans.avaTaxDate = Date.today();
            tempTrans.totalTax = 62.5;
            response.add(tempTrans);
        }

        result.setValue(response);
        return result;
    }

    private static AvaTaxService.FetchResultTransactionModel getListTransactionWithAddresses(String billingName, TestDataSuite testData, Address__c originAddress, Address__c destAddress) {
        AvaTaxService.FetchResultTransactionModel result = new AvaTaxService.FetchResultTransactionModel();
        List<AvaTaxService.TransactionModel> models = new List<AvaTaxService.TransactionModel>();
        AvaTaxService.TransactionModel tempTransactionModel = new AvaTaxService.TransactionModel();
        tempTransactionModel.id = 000000000000000;
        tempTransactionModel.code = billingName;
        tempTransactionModel.companyId = 12345;
        tempTransactionModel.avaTaxDate = Date.today();
        tempTransactionModel.totalTax = 0;
        tempTransactionModel.addresses = new List<AvaTaxService.Addressinfo>();
        tempTransactionModel.addresses.add(testData.addressInfoFromAddressObject(originAddress));
        tempTransactionModel.addresses.add(testData.addressInfoFromAddressObject(destAddress));
        models.add(tempTransactionModel);
        result.setValue(models);
        return result;
    }
}