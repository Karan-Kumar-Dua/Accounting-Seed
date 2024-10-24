@IsTest
public with sharing class CxTxnsImporterTest {
    
    private static String CORPORATE_CURRENCY = MultiCurrencyHandler.CORPORATE_CURRENCY;

    @TestSetup
    static void setupTestData(){
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testImportCCTxnWithInvoice() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings()
            .createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            // the billing which is being received
            Billing__c invoice = [
                SELECT Id, Name,Date__c, Balance__c, Payment_Processor__c, Customer__c, Ledger__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];
            invoice.Payment_Processor__c = paymentProcessor.Id;
            update invoice;
            
            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '';
            reportItem.xResponseError = '';
            reportItem.xResponseResult = 'Approved';
            reportItem.xCommand = 'cc:sale';
            reportItem.xStatus = '';
            reportItem.xResponseBatch = '0';
            reportItem.xCustom19 = invoice.Id;   // tied to invoice
            reportItem.xInvoice = invoice.Name;   // invoice name
            reportItem.xCustomerID = '';
            reportItem.xCurrency = CORPORATE_CURRENCY;
            reportItem.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = invoice.Balance__c;    // for entire invoice amount
            reportItem.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            Datetime endDate = Datetime.now();
            Datetime syncToDate = cx.import(5, endDate.addDays(-1), endDate);
            Test.stopTest();

            // verify sync date returned
            Assert.areEqual(endDate, syncToDate);

            // verify payment method created
            List<Payment_Method__c> paymentMethod = getPaymentMethods(new Set<Id>{ invoice.Customer__c });
            Assert.areEqual(1, paymentMethod.size());
            Assert.areEqual(invoice.Customer__c, paymentMethod[0].Customer__c);
            Assert.areEqual(paymentProcessor.Id, paymentMethod[0].Payment_Processor__c);
            Assert.isTrue(paymentMethod[0].External_Id__c.contains(PaymentMethodActions.PLACEHOLDER_CARD_EXTERNAL_ID));
            Assert.areEqual(PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE, paymentMethod[0].Payment_Method_Type__c);
            Assert.areEqual(PaymentMethodActions.PLACEHOLDER_TYPE, paymentMethod[0].Type__c);
            Assert.areEqual(PaymentMethodActions.PLACEHOLDER_LAST_FOUR, paymentMethod[0].Last_Four_Digits__c);
            Assert.areEqual(PaymentMethodActions.PLACEHOLDER_EXPIRATION_MONTH, paymentMethod[0].Expiration_Month__c);
            Assert.areEqual(PaymentMethodActions.PLACEHOLDER_EXPIRATION_YEAR, paymentMethod[0].Expiration_Year__c);

            // verify cash receipt created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, cashReceipt.size());
            Assert.areEqual(reportItem.xAmount, cashReceipt[0].Amount__c);
            Assert.areEqual(invoice.Customer__c, cashReceipt[0].Account__c);
            Assert.areEqual(reportItem.xEnteredDateUTC().date(), cashReceipt[0].Receipt_Date__c);
            Assert.areEqual(CashReceiptActions.PAYMENT_TYPE_ELECTRONIC, cashReceipt[0].Payment_Type__c);
            Assert.areEqual(reportItem.xRefNum, cashReceipt[0].Payment_Reference__c);
            Assert.areEqual(paymentProcessor.Id, cashReceipt[0].Payment_Processor__c);
            Assert.areEqual(invoice.Ledger__c, cashReceipt[0].Ledger__c);
            Assert.areEqual(paymentProcessor.Merchant_GL_Account__c, cashReceipt[0].Bank_Account__c);

            // verify payment activity created
            List<Payment_Activity__c> paymentActivity = getPaymentActivities(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, paymentActivity.size());
            Assert.areEqual(paymentMethod[0].Id, paymentActivity[0].Payment_Method__c);
            Assert.areEqual(cashReceipt[0].Id, paymentActivity[0].Cash_Receipt__c);
            Assert.areEqual(reportItem.xAmount, paymentActivity[0].Amount__c);
            Assert.isNull(paymentActivity[0].Error_Message__c);
            Assert.isNull(paymentActivity[0].Error_Type__c);
            Assert.areEqual(PaymentActivityHelper.PAYMENT_TYPE, paymentActivity[0].Type__c);
            Assert.areEqual(reportItem.xProcessingFee, paymentActivity[0].Fee__c);
            Assert.areEqual(reportItem.xRefNum, paymentActivity[0].Merchant_Reference__c);
            Assert.areEqual(reportItem.xResponseBatch, paymentActivity[0].Merchant_Batch_Id__c);
            Assert.areEqual(PaymentActivityHelper.SUCCESS_STATUS, paymentActivity[0].Status__c);

            // verify billing cash receipt created
            List<Billing_Cash_Receipt__c> billingCashReceipt = getBillingCashReceipts(new Set<Id>{ invoice.Id });
            Assert.areEqual(1, billingCashReceipt.size());
            Assert.areEqual(reportItem.xAmount, billingCashReceipt[0].Applied_Amount__c);
            Assert.areEqual(reportItem.xCustom19, billingCashReceipt[0].Billing__c);
            Assert.areEqual(reportItem.xInvoice, billingCashReceipt[0].Billing__r.Name);
            Assert.areEqual(cashReceipt[0].Id, billingCashReceipt[0].Cash_Receipt__c);
        }
    }

    @IsTest
    static void testImportACHTxnWithInvoice() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings()
            .createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            // the billing which is being received
            Billing__c invoice = [
                SELECT Id, Name,Date__c, Balance__c, Payment_Processor__c, Customer__c, Ledger__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];
            invoice.Payment_Processor__c = paymentProcessor.Id;
            update invoice;
            
            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '';
            reportItem.xResponseError = '';
            reportItem.xResponseResult = 'Approved';
            reportItem.xCommand = 'check:sale';
            reportItem.xStatus = '16';
            reportItem.xResponseBatch = '0';
            reportItem.xCustom19 = invoice.Id;   // tied to invoice
            reportItem.xInvoice = invoice.Name;   // invoice name
            reportItem.xCustomerID = '';
            reportItem.xCurrency = CORPORATE_CURRENCY;
            reportItem.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = invoice.Balance__c;    // for entire invoice amount
            reportItem.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            Datetime endDate = Datetime.now();
            Datetime syncToDate = cx.import(5, endDate.addDays(-1), endDate);
            Test.stopTest();

            // verify sync date returned
            Assert.areEqual(endDate, syncToDate);

            // verify payment method created
            List<Payment_Method__c> paymentMethod = getPaymentMethods(new Set<Id>{ invoice.Customer__c });
            Assert.areEqual(1, paymentMethod.size());
            Assert.areEqual(invoice.Customer__c, paymentMethod[0].Customer__c);
            Assert.areEqual(paymentProcessor.Id, paymentMethod[0].Payment_Processor__c);
            Assert.isTrue(paymentMethod[0].External_Id__c.contains(PaymentMethodActions.PLACEHOLDER_ACH_EXTERNAL_ID));
            Assert.areEqual(PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE, paymentMethod[0].Payment_Method_Type__c);

            // verify cash receipt created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, cashReceipt.size());
            Assert.areEqual(reportItem.xAmount, cashReceipt[0].Amount__c);
            Assert.areEqual(invoice.Customer__c, cashReceipt[0].Account__c);
            Assert.areEqual(reportItem.xEnteredDateUTC().date(), cashReceipt[0].Receipt_Date__c);
            Assert.areEqual(CashReceiptActions.PAYMENT_TYPE_ELECTRONIC, cashReceipt[0].Payment_Type__c);
            Assert.areEqual(reportItem.xRefNum, cashReceipt[0].Payment_Reference__c);
            Assert.areEqual(paymentProcessor.Id, cashReceipt[0].Payment_Processor__c);
            Assert.areEqual(invoice.Ledger__c, cashReceipt[0].Ledger__c);
            Assert.areEqual(paymentProcessor.Merchant_GL_Account__c, cashReceipt[0].Bank_Account__c);

            // verify payment activity created
            List<Payment_Activity__c> paymentActivity = getPaymentActivities(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, paymentActivity.size());
            Assert.areEqual(paymentMethod[0].Id, paymentActivity[0].Payment_Method__c);
            Assert.areEqual(cashReceipt[0].Id, paymentActivity[0].Cash_Receipt__c);
            Assert.areEqual(reportItem.xAmount, paymentActivity[0].Amount__c);
            Assert.isNull(paymentActivity[0].Error_Message__c);
            Assert.isNull(paymentActivity[0].Error_Type__c);
            Assert.areEqual(PaymentActivityHelper.PAYMENT_TYPE, paymentActivity[0].Type__c);
            Assert.areEqual(reportItem.xProcessingFee, paymentActivity[0].Fee__c);
            Assert.areEqual(reportItem.xRefNum, paymentActivity[0].Merchant_Reference__c);
            Assert.areEqual(reportItem.xResponseBatch, paymentActivity[0].Merchant_Batch_Id__c);
            Assert.areEqual(PaymentActivityHelper.SUCCESS_STATUS, paymentActivity[0].Status__c);

            // verify billing cash receipt created
            List<Billing_Cash_Receipt__c> billingCashReceipt = getBillingCashReceipts(new Set<Id>{ invoice.Id });
            Assert.areEqual(1, billingCashReceipt.size());
            Assert.areEqual(reportItem.xAmount, billingCashReceipt[0].Applied_Amount__c);
            Assert.areEqual(reportItem.xCustom19, billingCashReceipt[0].Billing__c);
            Assert.areEqual(reportItem.xInvoice, billingCashReceipt[0].Billing__r.Name);
            Assert.areEqual(cashReceipt[0].Id, billingCashReceipt[0].Cash_Receipt__c);
        }
    }

    @IsTest
    static void testImportOnePlaceholderPmtMethodCreated() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            // the billing which is being received
            Billing__c invoice = [
                SELECT Id, Name,Date__c, Balance__c, Payment_Processor__c, Customer__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];
            invoice.Payment_Processor__c = paymentProcessor.Id;
            update invoice;
            
            // report item / 1 txn
            CardknoxService.ReportData reportItem1 = new CardknoxService.ReportData();
            reportItem1.xRefNum = '1234';
            reportItem1.xErrorCode = '';
            reportItem1.xResponseError = '';
            reportItem1.xResponseResult = 'Approved';
            reportItem1.xCommand = 'check:sale';
            reportItem1.xStatus = '16';
            reportItem1.xResponseBatch = '0';
            reportItem1.xCustom19 = invoice.Id;   // tied to invoice
            reportItem1.xInvoice = invoice.Name;   // invoice name
            reportItem1.xCustomerID = '';
            reportItem1.xCurrency = CORPORATE_CURRENCY;
            reportItem1.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem1.xAmount = (invoice.Balance__c / 3).setScale(2, System.RoundingMode.HALF_UP);
            reportItem1.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            CardknoxService.ReportData reportItem2 = new CardknoxService.ReportData();
            reportItem2.xRefNum = '4321';
            reportItem2.xErrorCode = '';
            reportItem2.xResponseError = '';
            reportItem2.xResponseResult = 'Approved';
            reportItem2.xCommand = 'check:sale';
            reportItem2.xStatus = '16';
            reportItem2.xResponseBatch = '0';
            reportItem2.xCustom19 = invoice.Id;   // tied to invoice
            reportItem2.xInvoice = invoice.Name;   // invoice name
            reportItem2.xCustomerID = '';
            reportItem2.xCurrency = CORPORATE_CURRENCY;
            reportItem2.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem2.xAmount = (invoice.Balance__c / 3).setScale(2, System.RoundingMode.HALF_UP);
            reportItem2.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 2 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem1, reportItem2 };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            Test.startTest();
            cx.import(5, Datetime.now().addDays(-1), Datetime.now());
            Test.stopTest();

            // verify payment method created
            List<Payment_Method__c> paymentMethod = getPaymentMethods(new Set<Id>{ invoice.Customer__c });
            Assert.areEqual(1, paymentMethod.size());
        }
    }

    @IsTest
    static void testImportUseExistingPlaceholderPmtMethod() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings()
            .createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            // the billing which is being received
            Billing__c invoice = [
                SELECT Id, Name,Date__c, Balance__c, Payment_Processor__c, Customer__c, Ledger__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];
            invoice.Payment_Processor__c = paymentProcessor.Id;
            update invoice;

            Payment_Method__c paymentMethod = new Payment_Method__c(
                Customer__c = invoice.Customer__c,
                External_Id__c = PaymentMethodActions.PLACEHOLDER_CARD_EXTERNAL_ID,
                External_Use_Only__c = true,
                Payment_Processor__c = paymentProcessor.Id,
                Last_Four_Digits__c = PaymentMethodActions.PLACEHOLDER_LAST_FOUR,
                Payment_Method_Type__c = PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE,
                Type__c = PaymentMethodActions.PLACEHOLDER_TYPE,
                Expiration_Month__c = PaymentMethodActions.PLACEHOLDER_EXPIRATION_MONTH,
                Expiration_Year__c = PaymentMethodActions.PLACEHOLDER_EXPIRATION_YEAR
            );
            insert paymentMethod;
            
            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '';
            reportItem.xResponseError = '';
            reportItem.xResponseResult = 'Approved';
            reportItem.xCommand = 'cc:sale';
            reportItem.xStatus = '';
            reportItem.xResponseBatch = '0';
            reportItem.xCustom19 = invoice.Id;   // tied to invoice
            reportItem.xInvoice = invoice.Name;   // invoice name
            reportItem.xCustomerID = '';
            reportItem.xCurrency = CORPORATE_CURRENCY;
            reportItem.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = invoice.Balance__c;    // for entire invoice amount
            reportItem.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            cx.import(5, Datetime.now().addDays(-1), Datetime.now());
            Test.stopTest();

            // verify payment method created
            List<Payment_Method__c> paymentMethods = getPaymentMethods(new Set<Id>{ invoice.Customer__c });
            Assert.areEqual(1, paymentMethods.size());
            Assert.areEqual(paymentMethod.Id, paymentMethods[0].Id);  

            List<Payment_Activity__c> paymentActivities = getPaymentActivities(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, paymentActivities.size());
            Assert.areEqual(paymentMethod.Id, paymentActivities[0].Payment_Method__c, 'The existing payment method should be used. Transaction is Card and payment method is Card.');
        }
    }

    @IsTest
    static void testImportWrongExistingPlaceholderPmtMethod() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings()
            .createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            // the billing which is being received
            Billing__c invoice = [
                SELECT Id, Name,Date__c, Balance__c, Payment_Processor__c, Customer__c, Ledger__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];
            invoice.Payment_Processor__c = paymentProcessor.Id;
            update invoice;

            Payment_Method__c paymentMethod = new Payment_Method__c(
                Customer__c = invoice.Customer__c,
                External_Id__c = PaymentMethodActions.PLACEHOLDER_CARD_EXTERNAL_ID,
                External_Use_Only__c = true,
                Payment_Processor__c = paymentProcessor.Id,
                Last_Four_Digits__c = PaymentMethodActions.PLACEHOLDER_LAST_FOUR,
                Payment_Method_Type__c = PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE,
                Type__c = PaymentMethodActions.PLACEHOLDER_TYPE,
                Expiration_Month__c = PaymentMethodActions.PLACEHOLDER_EXPIRATION_MONTH,
                Expiration_Year__c = PaymentMethodActions.PLACEHOLDER_EXPIRATION_YEAR
            );
            insert paymentMethod;
            
            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '';
            reportItem.xResponseError = '';
            reportItem.xResponseResult = 'Approved';
            reportItem.xCommand = 'check:sale';
            reportItem.xStatus = '16';
            reportItem.xResponseBatch = '0';
            reportItem.xCustom19 = invoice.Id;   // tied to invoice
            reportItem.xInvoice = invoice.Name;   // invoice name
            reportItem.xCustomerID = '';
            reportItem.xCurrency = CORPORATE_CURRENCY;
            reportItem.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = invoice.Balance__c;    // for entire invoice amount
            reportItem.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            cx.import(5, Datetime.now().addDays(-1), Datetime.now());
            Test.stopTest();

            // verify payment method created
            List<Payment_Method__c> paymentMethods = getPaymentMethods(new Set<Id>{ invoice.Customer__c });
            Assert.areEqual(2, paymentMethods.size(), 'Expecting the existing card payment method and the new ach payment method.');

            List<Payment_Activity__c> paymentActivities = getPaymentActivities(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, paymentActivities.size());
            Assert.areNotEqual(paymentMethod.Id, paymentActivities[0].Payment_Method__c, 'A new payment method should have been created. Transaction is ACH and existing payment method is Card.');
        }
    }

    @IsTest
    static void testImportInvoiceOverpayment() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings()
            .createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            // amount to overpay
            Decimal overpaymentAmount = 10.00;

            // the processor used to make payments
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            // the billing which is being received
            Billing__c invoice = [
                SELECT Id, Name, Date__c, Balance__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];
            invoice.Payment_Processor__c = paymentProcessor.Id;
            update invoice;
            
            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '';
            reportItem.xResponseError = '';
            reportItem.xResponseResult = 'Approved';
            reportItem.xCommand = 'cc:sale';
            reportItem.xStatus = '';
            reportItem.xResponseBatch = '0';
            reportItem.xCustom19 = invoice.Id;   // tied to invoice
            reportItem.xInvoice = invoice.Name;   // invoice name
            reportItem.xCustomerID = '';
            reportItem.xCurrency = CORPORATE_CURRENCY;
            reportItem.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = invoice.Balance__c + overpaymentAmount;    // for entire invoice amount
            reportItem.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            cx.import(5, Datetime.now().addDays(-1), Datetime.now());
            Test.stopTest();

            // verify cash receipt created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, cashReceipt.size());
            Assert.areEqual(reportItem.xAmount, cashReceipt[0].Amount__c, 'Cash receipt amount should equal the transaction amount.');

            // verify billing cash receipt created
            List<Billing_Cash_Receipt__c> billingCashReceipt = getBillingCashReceipts(new Set<Id>{ invoice.Id });
            Assert.areEqual(1, billingCashReceipt.size());
            Assert.areEqual(invoice.Balance__c, billingCashReceipt[0].Applied_Amount__c, 'The cash receipt should not be overapplied to the invoice.');
        }
    }

    @IsTest
    static void testImportInvoiceDoublePayment() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings()
            .createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            // the processor used to make payments
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            // the billing which is being received
            Billing__c invoice = [
                SELECT Id, Name, Date__c, Balance__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];
            invoice.Payment_Processor__c = paymentProcessor.Id;
            update invoice;
            
            // report item / 1 txn
            CardknoxService.ReportData reportItem1 = new CardknoxService.ReportData();
            reportItem1.xRefNum = '1234';
            reportItem1.xErrorCode = '';
            reportItem1.xResponseError = '';
            reportItem1.xResponseResult = 'Approved';
            reportItem1.xCommand = 'cc:sale';
            reportItem1.xStatus = '';
            reportItem1.xResponseBatch = '0';
            reportItem1.xCustom19 = invoice.Id;   // tied to invoice
            reportItem1.xInvoice = invoice.Name;   // invoice name
            reportItem1.xCustomerID = '';
            reportItem1.xCurrency = CORPORATE_CURRENCY;
            reportItem1.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem1.xAmount = invoice.Balance__c;    // for entire invoice amount
            reportItem1.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            CardknoxService.ReportData reportItem2 = new CardknoxService.ReportData();
            reportItem2.xRefNum = '4321';
            reportItem2.xErrorCode = '';
            reportItem2.xResponseError = '';
            reportItem2.xResponseResult = 'Approved';
            reportItem2.xCommand = 'cc:sale';
            reportItem2.xStatus = '';
            reportItem2.xResponseBatch = '0';
            reportItem2.xCustom19 = invoice.Id;   // tied to invoice
            reportItem2.xInvoice = invoice.Name;   // invoice name
            reportItem2.xCustomerID = '';
            reportItem2.xCurrency = CORPORATE_CURRENCY;
            reportItem2.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem2.xAmount = invoice.Balance__c;    // for entire invoice amount
            reportItem2.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 2 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem1, reportItem2 };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            cx.import(5, Datetime.now().addDays(-1), Datetime.now());
            Test.stopTest();

            // verify cash receipt created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem1.xRefNum, reportItem2.xRefNum });
            Assert.areEqual(2, cashReceipt.size());
            Assert.areEqual(reportItem1.xAmount + reportItem2.xAmount, cashReceipt[0].Amount__c + cashReceipt[1].Amount__c, 'Cash receipts total should equal transactions total.');

            // verify billing cash receipt created
            List<Billing_Cash_Receipt__c> billingCashReceipt = getBillingCashReceipts(new Set<Id>{ invoice.Id });
            Assert.areEqual(1, billingCashReceipt.size());
            Assert.areEqual(invoice.Balance__c, billingCashReceipt[0].Applied_Amount__c, 'The cash receipt should not be overapplied to the invoice.');
        }
    }

    @IsTest
    static void testImportInvoiceSplitPayment() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings()
            .createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            // the processor used to make payments
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            // the billing which is being received
            Billing__c invoice = [
                SELECT Id, Name, Date__c, Balance__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];
            invoice.Payment_Processor__c = paymentProcessor.Id;
            update invoice;
            
            // report item / 1 txn
            CardknoxService.ReportData reportItem1 = new CardknoxService.ReportData();
            reportItem1.xRefNum = '1234';
            reportItem1.xErrorCode = '';
            reportItem1.xResponseError = '';
            reportItem1.xResponseResult = 'Approved';
            reportItem1.xCommand = 'cc:sale';
            reportItem1.xStatus = '';
            reportItem1.xResponseBatch = '0';
            reportItem1.xCustom19 = invoice.Id;   // tied to invoice
            reportItem1.xInvoice = invoice.Name;   // invoice name
            reportItem1.xCustomerID = '';
            reportItem1.xCurrency = CORPORATE_CURRENCY;
            reportItem1.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem1.xAmount = (invoice.Balance__c / 2).setScale(2, System.RoundingMode.HALF_UP);    // for entire invoice amount
            reportItem1.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            CardknoxService.ReportData reportItem2 = new CardknoxService.ReportData();
            reportItem2.xRefNum = '4321';
            reportItem2.xErrorCode = '';
            reportItem2.xResponseError = '';
            reportItem2.xResponseResult = 'Approved';
            reportItem2.xCommand = 'cc:sale';
            reportItem2.xStatus = '';
            reportItem2.xResponseBatch = '0';
            reportItem2.xCustom19 = invoice.Id;   // tied to invoice
            reportItem2.xInvoice = invoice.Name;   // invoice name
            reportItem2.xCustomerID = '';
            reportItem2.xCurrency = CORPORATE_CURRENCY;
            reportItem2.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem2.xAmount = (invoice.Balance__c / 2).setScale(2, System.RoundingMode.HALF_UP);    // for entire invoice amount
            reportItem2.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 2 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem1, reportItem2 };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            cx.import(5, Datetime.now().addDays(-1), Datetime.now());
            Test.stopTest();

            // verify cash receipt created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem1.xRefNum, reportItem2.xRefNum });
            Assert.areEqual(2, cashReceipt.size());
            Assert.areEqual(reportItem1.xAmount + reportItem2.xAmount, cashReceipt[0].Amount__c + cashReceipt[1].Amount__c);

            // verify billing cash receipt created
            List<Billing_Cash_Receipt__c> billingCashReceipt = getBillingCashReceipts(new Set<Id>{ invoice.Id });
            Assert.areEqual(2, billingCashReceipt.size());
            Assert.areEqual(reportItem1.xAmount + reportItem2.xAmount, billingCashReceipt[0].Applied_Amount__c + billingCashReceipt[1].Applied_Amount__c);
        }
    }

    @IsTest
    static void testImportCCTxnWithCustomer() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            // the customer who made the payment
            Payment_Processor_Customer__c customer = new Payment_Processor_Customer__c(
                Account__c = testData.accounts[0].Id,
                Processor__c = paymentProcessor.Id,
                External_Id__c = 'xyz789'
            );  
            insert customer;          
            
            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '';
            reportItem.xResponseError = '';
            reportItem.xResponseResult = 'Approved';
            reportItem.xCommand = 'cc:sale';
            reportItem.xStatus = '';
            reportItem.xResponseBatch = '0';
            reportItem.xInvoice = '';
            reportItem.xCustom19 = '';
            reportItem.xCustomerID = customer.External_Id__c;   // tied to customer
            reportItem.xCurrency = CORPORATE_CURRENCY;
            reportItem.xEnteredDate = Datetime.newInstanceGmt(testData.acctPeriods[0].Start_Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = 29.95;    // for entire invoice amount
            reportItem.xProcessingFee = (reportItem.xAmount * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            Test.startTest();
            cx.import(5, Datetime.now().addDays(-1), Datetime.now());
            Test.stopTest();

            // verify payment method created
            List<Payment_Method__c> paymentMethod = getPaymentMethods(new Set<Id>{ customer.Account__c });
            Assert.areEqual(1, paymentMethod.size());
            Assert.areEqual(customer.Account__c, paymentMethod[0].Customer__c);
            Assert.areEqual(paymentProcessor.Id, paymentMethod[0].Payment_Processor__c);
            Assert.isTrue(paymentMethod[0].External_Id__c.contains(PaymentMethodActions.PLACEHOLDER_CARD_EXTERNAL_ID));
            Assert.areEqual(PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE, paymentMethod[0].Payment_Method_Type__c);
            Assert.areEqual(PaymentMethodActions.PLACEHOLDER_TYPE, paymentMethod[0].Type__c);
            Assert.areEqual(PaymentMethodActions.PLACEHOLDER_LAST_FOUR, paymentMethod[0].Last_Four_Digits__c);
            Assert.areEqual(PaymentMethodActions.PLACEHOLDER_EXPIRATION_MONTH, paymentMethod[0].Expiration_Month__c);
            Assert.areEqual(PaymentMethodActions.PLACEHOLDER_EXPIRATION_YEAR, paymentMethod[0].Expiration_Year__c);

            // verify cash receipt created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, cashReceipt.size());
            Assert.areEqual(reportItem.xAmount, cashReceipt[0].Amount__c);
            Assert.areEqual(customer.Account__c, cashReceipt[0].Account__c);
            Assert.areEqual(reportItem.xEnteredDateUTC().date(), cashReceipt[0].Receipt_Date__c);
            Assert.areEqual(CashReceiptActions.PAYMENT_TYPE_ELECTRONIC, cashReceipt[0].Payment_Type__c);
            Assert.areEqual(reportItem.xRefNum, cashReceipt[0].Payment_Reference__c);
            Assert.areEqual(paymentProcessor.Id, cashReceipt[0].Payment_Processor__c);
            Assert.areEqual(paymentProcessor.Merchant_GL_Account__c, cashReceipt[0].Bank_Account__c);

            // verify payment activity created
            List<Payment_Activity__c> paymentActivity = getPaymentActivities(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, paymentActivity.size());
            Assert.areEqual(paymentMethod[0].Id, paymentActivity[0].Payment_Method__c);
            Assert.areEqual(cashReceipt[0].Id, paymentActivity[0].Cash_Receipt__c);
            Assert.areEqual(reportItem.xAmount, paymentActivity[0].Amount__c);
            Assert.isNull(paymentActivity[0].Error_Message__c);
            Assert.isNull(paymentActivity[0].Error_Type__c);
            Assert.areEqual(PaymentActivityHelper.PAYMENT_TYPE, paymentActivity[0].Type__c);
            Assert.areEqual(reportItem.xProcessingFee, paymentActivity[0].Fee__c);
            Assert.areEqual(reportItem.xRefNum, paymentActivity[0].Merchant_Reference__c);
            Assert.areEqual(reportItem.xResponseBatch, paymentActivity[0].Merchant_Batch_Id__c);
            Assert.areEqual(PaymentActivityHelper.SUCCESS_STATUS, paymentActivity[0].Status__c);

            // verify billing cash receipt created
            List<Billing_Cash_Receipt__c> billingCashReceipt = [SELECT Id FROM Billing_Cash_Receipt__c WHERE Cash_Receipt__c = :cashReceipt[0].Id];
            Assert.areEqual(0, billingCashReceipt.size());
        }
    }

    @IsTest
    static void testImportMultipleCalls() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings()
            .createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            // the billing which is being received
            Billing__c invoice = [
                SELECT Id, Name, Date__c, Balance__c, Payment_Processor__c, Customer__c, Ledger__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];
            invoice.Payment_Processor__c = paymentProcessor.Id;
            update invoice;
            
            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '';
            reportItem.xResponseError = '';
            reportItem.xResponseResult = 'Approved';
            reportItem.xCommand = 'cc:sale';
            reportItem.xStatus = '';
            reportItem.xResponseBatch = '0';
            reportItem.xCustom19 = invoice.Id;   // tied to invoice
            reportItem.xInvoice = invoice.Name;   // invoice name
            reportItem.xCustomerID = '';
            reportItem.xCurrency = CORPORATE_CURRENCY;
            reportItem.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = invoice.Balance__c;    // for entire invoice amount
            reportItem.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            Datetime endTime = Datetime.now();
            Datetime startTime = endTime.addDays(-1);
            // run 2x to verify no duplicate data created
            cx.import(5, startTime, endTime);
            cx.import(5, startTime, endTime);
            Test.stopTest();

            // verify payment method created
            List<Payment_Method__c> paymentMethod = getPaymentMethods(new Set<Id>{ invoice.Customer__c });
            Assert.areEqual(1, paymentMethod.size());
            Assert.areEqual(invoice.Customer__c, paymentMethod[0].Customer__c);
            Assert.areEqual(paymentProcessor.Id, paymentMethod[0].Payment_Processor__c);
            Assert.isTrue(paymentMethod[0].External_Id__c.contains(PaymentMethodActions.PLACEHOLDER_CARD_EXTERNAL_ID));
            Assert.areEqual(PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE, paymentMethod[0].Payment_Method_Type__c);
            Assert.areEqual(PaymentMethodActions.PLACEHOLDER_TYPE, paymentMethod[0].Type__c);
            Assert.areEqual(PaymentMethodActions.PLACEHOLDER_LAST_FOUR, paymentMethod[0].Last_Four_Digits__c);
            Assert.areEqual(PaymentMethodActions.PLACEHOLDER_EXPIRATION_MONTH, paymentMethod[0].Expiration_Month__c);
            Assert.areEqual(PaymentMethodActions.PLACEHOLDER_EXPIRATION_YEAR, paymentMethod[0].Expiration_Year__c);

            // verify cash receipt created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, cashReceipt.size());
            Assert.areEqual(reportItem.xAmount, cashReceipt[0].Amount__c);
            Assert.areEqual(invoice.Customer__c, cashReceipt[0].Account__c);
            Assert.areEqual(reportItem.xEnteredDateUTC().date(), cashReceipt[0].Receipt_Date__c);
            Assert.areEqual(CashReceiptActions.PAYMENT_TYPE_ELECTRONIC, cashReceipt[0].Payment_Type__c);
            Assert.areEqual(reportItem.xRefNum, cashReceipt[0].Payment_Reference__c);
            Assert.areEqual(paymentProcessor.Id, cashReceipt[0].Payment_Processor__c);
            Assert.areEqual(invoice.Ledger__c, cashReceipt[0].Ledger__c);
            Assert.areEqual(paymentProcessor.Merchant_GL_Account__c, cashReceipt[0].Bank_Account__c);

            // verify payment activity created
            List<Payment_Activity__c> paymentActivity = getPaymentActivities(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, paymentActivity.size());
            Assert.areEqual(paymentMethod[0].Id, paymentActivity[0].Payment_Method__c);
            Assert.areEqual(cashReceipt[0].Id, paymentActivity[0].Cash_Receipt__c);
            Assert.areEqual(reportItem.xAmount, paymentActivity[0].Amount__c);
            Assert.isNull(paymentActivity[0].Error_Message__c);
            Assert.isNull(paymentActivity[0].Error_Type__c);
            Assert.areEqual(PaymentActivityHelper.PAYMENT_TYPE, paymentActivity[0].Type__c);
            Assert.areEqual(reportItem.xProcessingFee, paymentActivity[0].Fee__c);
            Assert.areEqual(reportItem.xRefNum, paymentActivity[0].Merchant_Reference__c);
            Assert.areEqual(reportItem.xResponseBatch, paymentActivity[0].Merchant_Batch_Id__c);
            Assert.areEqual(PaymentActivityHelper.SUCCESS_STATUS, paymentActivity[0].Status__c);

            // verify billing cash receipt created
            List<Billing_Cash_Receipt__c> billingCashReceipt = getBillingCashReceipts(new Set<Id>{ invoice.Id });
            Assert.areEqual(1, billingCashReceipt.size());
            Assert.areEqual(reportItem.xAmount, billingCashReceipt[0].Applied_Amount__c);
            Assert.areEqual(reportItem.xCustom19, billingCashReceipt[0].Billing__c);
            Assert.areEqual(reportItem.xInvoice, billingCashReceipt[0].Billing__r.Name);
            Assert.areEqual(cashReceipt[0].Id, billingCashReceipt[0].Cash_Receipt__c);
        }
    }

    @IsTest
    static void testImportHasMore() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            // the billing which is being received
            Billing__c invoice = [
                SELECT Id, Name, Date__c, Balance__c, Payment_Processor__c, Customer__c, Ledger__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];
            invoice.Payment_Processor__c = paymentProcessor.Id;
            update invoice;
            
            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '';
            reportItem.xResponseError = '';
            reportItem.xResponseResult = 'Approved';
            reportItem.xCommand = 'cc:sale';
            reportItem.xStatus = '';
            reportItem.xResponseBatch = '0';
            reportItem.xCustom19 = invoice.Id;   // tied to invoice
            reportItem.xInvoice = invoice.Name;   // invoice name
            reportItem.xCustomerID = '';
            reportItem.xCurrency = CORPORATE_CURRENCY;
            reportItem.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = invoice.Balance__c;    // for entire invoice amount
            reportItem.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            Test.startTest();
            Datetime endDate = Datetime.now();
            Datetime syncToDate = cx.import(1, endDate.addDays(-5), endDate);
            Test.stopTest();

            // verify sync date returned
            Assert.areEqual(reportItem.xEnteredDateUTC(), syncToDate);
        }
    }

    @IsTest
    static void testImportInferCurrency() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings()
            .createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            // the billing which is being received
            Billing__c invoice = [
                SELECT Id, Name, Date__c, Balance__c, Payment_Processor__c, Customer__c, Ledger__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];
            invoice.Payment_Processor__c = paymentProcessor.Id;
            update invoice;
            
            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '';
            reportItem.xResponseError = '';
            reportItem.xResponseResult = 'Approved';
            reportItem.xCommand = 'cc:sale';
            reportItem.xStatus = '';
            reportItem.xResponseBatch = '0';
            reportItem.xCustom19 = invoice.Id;   // tied to invoice
            reportItem.xInvoice = invoice.Name;   // invoice name
            reportItem.xCustomerID = '';
            reportItem.xCurrency = '';
            reportItem.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = invoice.Balance__c;    // for entire invoice amount
            reportItem.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            Datetime endDate = Datetime.now();
            cx.import(5, endDate.addDays(-1), endDate);
            Test.stopTest();

            // verify payment method created
            List<Payment_Method__c> paymentMethod = getPaymentMethods(new Set<Id>{ invoice.Customer__c });
            Assert.areEqual(1, paymentMethod.size());

            // verify cash receipt created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, cashReceipt.size());

            // verify payment activity created
            List<Payment_Activity__c> paymentActivity = getPaymentActivities(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, paymentActivity.size());

            // verify billing cash receipt created
            List<Billing_Cash_Receipt__c> billingCashReceipt = getBillingCashReceipts(new Set<Id>{ invoice.Id });
            Assert.areEqual(1, billingCashReceipt.size());
        }
    }

    @IsTest
    static void testImportFilterInvalidCurrency() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings()
            .createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            // the billing which is being received
            Billing__c invoice = [
                SELECT Id, Name, Date__c, Balance__c, Payment_Processor__c, Customer__c, Ledger__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];
            invoice.Payment_Processor__c = paymentProcessor.Id;
            update invoice;
            
            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '';
            reportItem.xResponseError = '';
            reportItem.xResponseResult = 'Approved';
            reportItem.xCommand = 'cc:sale';
            reportItem.xStatus = '';
            reportItem.xResponseBatch = '0';
            reportItem.xCustom19 = invoice.Id;   // tied to invoice
            reportItem.xInvoice = invoice.Name;   // invoice name
            reportItem.xCustomerID = '';
            reportItem.xCurrency = 'ZZZ';
            reportItem.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = invoice.Balance__c;    // for entire invoice amount
            reportItem.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            Datetime endDate = Datetime.now();
            Datetime syncToDate = cx.import(5, endDate.addDays(-1), endDate);
            Test.stopTest();

            // verify sync date returned
            Assert.areEqual(endDate, syncToDate);

            // verify payment method created
            List<Payment_Method__c> paymentMethod = getPaymentMethods(new Set<Id>{ invoice.Customer__c });
            Assert.isTrue(paymentMethod.isEmpty());

            // verify cash receipt created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem.xRefNum });
            Assert.isTrue(cashReceipt.isEmpty());
         
            // verify payment activity created
            List<Payment_Activity__c> paymentActivity = getPaymentActivities(new Set<String>{ reportItem.xRefNum });
            Assert.isTrue(paymentActivity.isEmpty());
        
            // verify billing cash receipt created
            List<Billing_Cash_Receipt__c> billingCashReceipt = getBillingCashReceipts(new Set<Id>{ invoice.Id });
            Assert.isTrue(billingCashReceipt.isEmpty());
        }
    }

    @IsTest
    static void testImportErrorTxn() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            // the customer who made the payment
            Payment_Processor_Customer__c customer = new Payment_Processor_Customer__c(
                Account__c = testData.accounts[0].Id,
                Processor__c = paymentProcessor.Id,
                External_Id__c = 'xyz789'
            );  
            insert customer;     
            
            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '1257';
            reportItem.xResponseError = 'An error occurred.';
            reportItem.xResponseResult = 'Error';
            reportItem.xCommand = 'cc:sale';
            reportItem.xStatus = '0';
            reportItem.xResponseBatch = '';
            reportItem.xInvoice = '';
            reportItem.xCustom19 = '';
            reportItem.xCustomerID = customer.External_Id__c;
            reportItem.xCurrency = CORPORATE_CURRENCY;
            reportItem.xEnteredDate = Datetime.newInstanceGmt(testData.acctPeriods[0].Start_Date__c.addDays(5), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = 9.99;
            reportItem.xProcessingFee = 0.18;

            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            Test.startTest();
            Datetime endDate = Datetime.now();
            Datetime syncToDate = cx.import(5, endDate.addDays(-1), endDate);
            Test.stopTest();

            // verify sync date returned
            Assert.areEqual(endDate, syncToDate);

            // verify payment method created
            List<Payment_Method__c> paymentMethod = getPaymentMethods(new Set<Id>{ customer.Account__c });
            Assert.areEqual(1, paymentMethod.size());

            // verify cash receipt created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem.xRefNum });
            Assert.isTrue(cashReceipt.isEmpty());

            // verify payment activity created
            List<Payment_Activity__c> paymentActivity = getPaymentActivities(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, paymentActivity.size());
            Assert.areEqual(paymentMethod[0].Id, paymentActivity[0].Payment_Method__c);
            Assert.isNull(paymentActivity[0].Cash_Receipt__c);
            Assert.areEqual(reportItem.xAmount, paymentActivity[0].Amount__c);
            Assert.areEqual(reportItem.xResponseError, paymentActivity[0].Error_Message__c);
            Assert.areEqual(reportItem.xErrorCode, paymentActivity[0].Error_Type__c);
            Assert.areEqual(PaymentActivityHelper.PAYMENT_TYPE, paymentActivity[0].Type__c);
            Assert.areEqual(reportItem.xProcessingFee, paymentActivity[0].Fee__c);
            Assert.areEqual(reportItem.xRefNum, paymentActivity[0].Merchant_Reference__c);
            Assert.isNull(paymentActivity[0].Merchant_Batch_Id__c);
            Assert.areEqual(PaymentActivityHelper.ERROR_STATUS, paymentActivity[0].Status__c);
        }
    }

    @IsTest
    static void testImportCCTxnWithInvalidInvoice() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            // the customer who made the payment
            Payment_Processor_Customer__c customer = new Payment_Processor_Customer__c(
                Account__c = testData.accounts[0].Id,
                Processor__c = paymentProcessor.Id,
                External_Id__c = 'xyz789'
            );  
            insert customer;          
            
            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '';
            reportItem.xResponseError = '';
            reportItem.xResponseResult = 'Approved';
            reportItem.xCommand = 'cc:sale';
            reportItem.xStatus = '';
            reportItem.xResponseBatch = '0';
            reportItem.xCustom19 = 'abc123'; // non-salesforce id
            reportItem.xInvoice = 'abc123'; // non-salesforce id
            reportItem.xCustomerID = customer.External_Id__c;   // tied to customer
            reportItem.xCurrency = CORPORATE_CURRENCY;
            reportItem.xEnteredDate = Datetime.newInstanceGmt(testData.acctPeriods[0].Start_Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = 29.95;    // for entire invoice amount
            reportItem.xProcessingFee = (reportItem.xAmount * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            Test.startTest();
            cx.import(5, Datetime.now().addDays(-1), Datetime.now());
            Test.stopTest();

            // verify payment method created
            List<Payment_Method__c> paymentMethod = getPaymentMethods(new Set<Id>{ customer.Account__c });
            Assert.areEqual(1, paymentMethod.size());
            Assert.areEqual(customer.Account__c, paymentMethod[0].Customer__c);
            Assert.areEqual(paymentProcessor.Id, paymentMethod[0].Payment_Processor__c);
            Assert.isTrue(paymentMethod[0].External_Id__c.contains(PaymentMethodActions.PLACEHOLDER_CARD_EXTERNAL_ID));
            Assert.areEqual(PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE, paymentMethod[0].Payment_Method_Type__c);
            Assert.areEqual(PaymentMethodActions.PLACEHOLDER_TYPE, paymentMethod[0].Type__c);
            Assert.areEqual(PaymentMethodActions.PLACEHOLDER_LAST_FOUR, paymentMethod[0].Last_Four_Digits__c);
            Assert.areEqual(PaymentMethodActions.PLACEHOLDER_EXPIRATION_MONTH, paymentMethod[0].Expiration_Month__c);
            Assert.areEqual(PaymentMethodActions.PLACEHOLDER_EXPIRATION_YEAR, paymentMethod[0].Expiration_Year__c);

            // verify cash receipt created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, cashReceipt.size());
            Assert.areEqual(reportItem.xAmount, cashReceipt[0].Amount__c);
            Assert.areEqual(customer.Account__c, cashReceipt[0].Account__c);
            Assert.areEqual(reportItem.xEnteredDateUTC().date(), cashReceipt[0].Receipt_Date__c);
            Assert.areEqual(CashReceiptActions.PAYMENT_TYPE_ELECTRONIC, cashReceipt[0].Payment_Type__c);
            Assert.areEqual(reportItem.xRefNum, cashReceipt[0].Payment_Reference__c);
            Assert.areEqual(paymentProcessor.Id, cashReceipt[0].Payment_Processor__c);
            Assert.areEqual(paymentProcessor.Merchant_GL_Account__c, cashReceipt[0].Bank_Account__c);

            // verify payment activity created
            List<Payment_Activity__c> paymentActivity = getPaymentActivities(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, paymentActivity.size());
            Assert.areEqual(paymentMethod[0].Id, paymentActivity[0].Payment_Method__c);
            Assert.areEqual(cashReceipt[0].Id, paymentActivity[0].Cash_Receipt__c);
            Assert.areEqual(reportItem.xAmount, paymentActivity[0].Amount__c);
            Assert.isNull(paymentActivity[0].Error_Message__c);
            Assert.isNull(paymentActivity[0].Error_Type__c);
            Assert.areEqual(PaymentActivityHelper.PAYMENT_TYPE, paymentActivity[0].Type__c);
            Assert.areEqual(reportItem.xProcessingFee, paymentActivity[0].Fee__c);
            Assert.areEqual(reportItem.xRefNum, paymentActivity[0].Merchant_Reference__c);
            Assert.areEqual(reportItem.xResponseBatch, paymentActivity[0].Merchant_Batch_Id__c);
            Assert.areEqual(PaymentActivityHelper.SUCCESS_STATUS, paymentActivity[0].Status__c);

            // verify billing cash receipt created
            List<Billing_Cash_Receipt__c> billingCashReceipt = [SELECT Id FROM Billing_Cash_Receipt__c WHERE Cash_Receipt__c = :cashReceipt[0].Id];
            Assert.areEqual(0, billingCashReceipt.size());
        }
    }

    @IsTest
    static void testImportBillingInForeignCurrency() {
        TestDataSuite testData = TestDataSuite.getInstance();
        try {
            testData.enableMultiCurrency();
            MultiCurrencyHandler.isMultiCurrencyEnabled = true;
        } catch (TestDataSuite.TestDataSuiteException e) {
            // MC not enabled for org
            return;
        }
        testData.createBillings().createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            // the billing which is being received
            Billing__c invoice = [
                SELECT Id, Name, Date__c, Balance__c, Payment_Processor__c, Customer__c, Ledger__c,Currency_Conversion_Rate__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];

            String ledgerCurrency = LedgerHandler.getLedgerCurrency(invoice.Ledger__c);
            String nonLedgerCurrency;
            List<SObject> allCurrencies = Database.query('SELECT Id, IsoCode FROM CurrencyType LIMIT 2');
            for (SObject eachCurrency : allCurrencies) {
                if (eachCurrency.get('IsoCode') != ledgerCurrency) {
                    nonLedgerCurrency = (String) eachCurrency.get('IsoCode');
                    break;
                }
            }

            if (String.isBlank(nonLedgerCurrency)) {
                // only single currency available
                return;
            }
            invoice.Currency_Conversion_Rate__c = 1.2;
            invoice.Payment_Processor__c = paymentProcessor.Id;
            invoice.put('CurrencyIsoCode', nonLedgerCurrency);
            
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Schema.SObjectType.Billing__c.fields.getMap().get('CurrencyIsoCode'),
                                                        Billing__c.Currency_Conversion_Rate__c});

            update invoice;
            TriggerObserver.reset();
            
            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '';
            reportItem.xResponseError = '';
            reportItem.xResponseResult = 'Approved';
            reportItem.xCommand = 'cc:sale';
            reportItem.xStatus = '';
            reportItem.xResponseBatch = '0';
            reportItem.xCustom19 = invoice.Id;   // tied to invoice
            reportItem.xInvoice = invoice.Name;   // invoice name
            reportItem.xCustomerID = '';
            reportItem.xCurrency = ledgerCurrency;
            reportItem.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = invoice.Balance__c;    // for entire invoice amount
            reportItem.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            Test.startTest();
            Datetime endDate = Datetime.now();
            Datetime syncToDate = cx.import(5, endDate.addDays(-1), endDate);
            Test.stopTest();

            // verify sync date returned
            Assert.areEqual(endDate, syncToDate);

            // verify payment method created
            List<Payment_Method__c> paymentMethod = getPaymentMethods(new Set<Id>{ invoice.Customer__c });
            Assert.areEqual(1, paymentMethod.size());

            // verify cash receipt created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, cashReceipt.size());
        
            // verify payment activity created
            List<Payment_Activity__c> paymentActivity = getPaymentActivities(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, paymentActivity.size());
        
            // verify billing cash receipt created
            List<Billing_Cash_Receipt__c> billingCashReceipt = getBillingCashReceipts(new Set<Id>{ invoice.Id });
            Assert.isTrue(billingCashReceipt.isEmpty());
        }
    }

    @IsTest
    static void testImportNoCustomerInfo() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            // the customer who made the payment
            Payment_Processor_Customer__c customer = new Payment_Processor_Customer__c(
                Account__c = testData.accounts[0].Id,
                Processor__c = paymentProcessor.Id,
                External_Id__c = 'xyz789'
            );  
            insert customer;          
            
            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '';
            reportItem.xResponseError = '';
            reportItem.xResponseResult = 'Approved';
            reportItem.xCommand = 'cc:sale';
            reportItem.xStatus = '';
            reportItem.xResponseBatch = '0';
            reportItem.xInvoice = '';
            reportItem.xCustom19 = '';
            reportItem.xCustomerID = '';
            reportItem.xCurrency = CORPORATE_CURRENCY;
            reportItem.xEnteredDate = Datetime.newInstanceGmt(testData.acctPeriods[0].Start_Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = 29.95;    // for entire invoice amount
            reportItem.xProcessingFee = (reportItem.xAmount * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            Test.startTest();
            cx.import(5, Datetime.now().addDays(-1), Datetime.now());
            Test.stopTest();

            // verify payment method not created
            List<Payment_Method__c> paymentMethod = getPaymentMethods(new Set<Id>{ customer.Account__c });
            Assert.isTrue(paymentMethod.isEmpty());

            // verify cash receipt not created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem.xRefNum });
            Assert.isTrue(cashReceipt.isEmpty());

            // verify payment activity not created
            List<Payment_Activity__c> paymentActivity = getPaymentActivities(new Set<String>{ reportItem.xRefNum });
            Assert.isTrue(paymentActivity.isEmpty());
        }
    }

    @IsTest
    static void testImportBlankCustomerID() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            // the customer who made the payment
            Payment_Processor_Customer__c customer = new Payment_Processor_Customer__c(
                Account__c = testData.accounts[0].Id,
                Processor__c = paymentProcessor.Id,
                External_Id__c = 'xyz789'
            );  
            insert customer;          
            
            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '';
            reportItem.xResponseError = '';
            reportItem.xResponseResult = 'Approved';
            reportItem.xCommand = 'cc:sale';
            reportItem.xStatus = '';
            reportItem.xResponseBatch = '0';
            reportItem.xInvoice = '';
            reportItem.xCustom19 = '';
            reportItem.xCustomerID = '   ';
            reportItem.xCurrency = CORPORATE_CURRENCY;
            reportItem.xEnteredDate = Datetime.newInstanceGmt(testData.acctPeriods[0].Start_Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = 29.95;    // for entire invoice amount
            reportItem.xProcessingFee = (reportItem.xAmount * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            Test.startTest();
            cx.import(5, Datetime.now().addDays(-1), Datetime.now());
            Test.stopTest();

            // verify payment method not created
            List<Payment_Method__c> paymentMethod = getPaymentMethods(new Set<Id>{ customer.Account__c });
            Assert.isTrue(paymentMethod.isEmpty());

            // verify cash receipt not created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem.xRefNum });
            Assert.isTrue(cashReceipt.isEmpty());

            // verify payment activity not created
            List<Payment_Activity__c> paymentActivity = getPaymentActivities(new Set<String>{ reportItem.xRefNum });
            Assert.isTrue(paymentActivity.isEmpty());
        }
    }

    @IsTest
    static void testImportCCTxnWithoutCustomer() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '';
            reportItem.xResponseError = '';
            reportItem.xResponseResult = 'Approved';
            reportItem.xCommand = 'cc:sale';
            reportItem.xStatus = '';
            reportItem.xResponseBatch = '0';
            reportItem.xInvoice = null;   // not tied to any invoice
            reportItem.xCustomerID = null;
            reportItem.xEnteredDate = Datetime.newInstanceGmt(Date.today().addDays(-1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = 400;    
            reportItem.xProcessingFee = 10;
            reportItem.xBillFirstName = 'Test';
            reportItem.xBillLastName = 'User';
            reportItem.xBillCompany = 'Test Company';
            reportItem.xBillStreet = 'Odiana';
            reportItem.xBillCity = 'Lake';
            reportItem.xBillState = 'LA';
            reportItem.xBillZip = '23889';
            reportItem.xBillCountry = 'America';


            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            Test.startTest();
            cx.import(5, Datetime.now().addDays(-1), Datetime.now());
            Test.stopTest();

            // verify payment method should not get created
            Assert.areEqual(0, [SELECT ID From Payment_Method__c].size());

            // verify cash receipt should not get created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(0, cashReceipt.size());

            // verify payment activity should not get created
            List<Payment_Activity__c> paymentActivity = getPaymentActivities(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(0, paymentActivity.size());

            // verify billing cash receipt should not get created
            Assert.areEqual(0, [SELECT ID From Billing_Cash_Receipt__c].size());

            // verify the transaction Import error should get created
            List<Transaction_Import_Error__c> transactionalImportError = getTransactionImportErrorByRefNum(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, transactionalImportError.size());
            Assert.areEqual(reportItem.xRefNum, transactionalImportError[0].Merchant_Reference__c);
            Assert.areEqual(reportItem.xCommand, transactionalImportError[0].Type__c);
            Assert.areEqual(reportItem.xAmount, transactionalImportError[0].Amount__c);
            Assert.areEqual(reportItem.xProcessingFee, transactionalImportError[0].Fee__c);
            Assert.areEqual(reportItem.xBillCompany, transactionalImportError[0].Billing_Name__c);
            Assert.areEqual(reportItem.xBillStreet, transactionalImportError[0].Billing_Street__c);
            Assert.areEqual(reportItem.xBillCity, transactionalImportError[0].Billing_City__c);
            Assert.areEqual(reportItem.xBillZip, transactionalImportError[0].Billing_Postal_Code__c);
            Assert.areEqual(reportItem.xBillCountry, transactionalImportError[0].Billing_Country__c);
            Assert.areEqual(reportItem.xBillState, transactionalImportError[0].Billing_State__c);
            Assert.areEqual(Label.ERR_CARDKNOX_MISSING_CUSTOMER_INFO, transactionalImportError[0].Error__c);
        }
    }

    @IsTest
    static void testImportCCTxnWithCustomerFromPPC() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            // the customer who made the payment
            Payment_Processor_Customer__c customer = new Payment_Processor_Customer__c(
                Account__c = testData.accounts[0].Id,
                Processor__c = paymentProcessor.Id,
                External_Id__c = 'xyz789'
            );  
            insert customer;          

            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '';
            reportItem.xResponseError = '';
            reportItem.xResponseResult = 'Approved';
            reportItem.xCommand = 'cc:sale';
            reportItem.xStatus = '';
            reportItem.xResponseBatch = '0';
            reportItem.xInvoice = '';
            reportItem.xCustomerID = customer.External_Id__c;   // tied to customer
            reportItem.xEnteredDate = Datetime.newInstanceGmt(testData.acctPeriods[0].Start_Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = 29.95;    // for entire invoice amount
            reportItem.xProcessingFee = (reportItem.xAmount * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            Test.startTest();
            cx.import(5, Datetime.now().addDays(-1), Datetime.now());
            Test.stopTest();

            // verify cash receipt created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, cashReceipt.size());
            Assert.areEqual(reportItem.xAmount, cashReceipt[0].Amount__c);
            Assert.areEqual(testData.accounts[0].Id, cashReceipt[0].Account__c);
            Assert.areEqual(CashReceiptActions.PAYMENT_TYPE_ELECTRONIC, cashReceipt[0].Payment_Type__c);
            Assert.areEqual(reportItem.xRefNum, cashReceipt[0].Payment_Reference__c);
            Assert.areEqual(paymentProcessor.Id, cashReceipt[0].Payment_Processor__c);
            Assert.areEqual(paymentProcessor.Merchant_GL_Account__c, cashReceipt[0].Bank_Account__c);
        }
    }

    @IsTest
    static void testImportCCTxnWithCustomerFromBillingCustomer() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            // the processor used to make payments
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            // the billing which is being received
            Billing__c invoice = [
                SELECT Id, Name,Date__c, Balance__c,Customer__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];
            invoice.Payment_Processor__c = paymentProcessor.Id;
            invoice.Customer__c = testData.accounts[1].Id;
            update invoice;

            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '';
            reportItem.xResponseError = '';
            reportItem.xResponseResult = 'Approved';
            reportItem.xCommand = 'cc:sale';
            reportItem.xStatus = '';
            reportItem.xResponseBatch = '0';
            reportItem.xInvoice = invoice.Name;   // tied to invoice
            reportItem.xCustom19 = invoice.Id;   // tied to invoice
            reportItem.xCustomerID = '';
            reportItem.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = invoice.Balance__c;
            reportItem.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            Test.startTest();
            cx.import(5, Datetime.now().addDays(-1), Datetime.now());
            Test.stopTest();

            // verify cash receipt created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, cashReceipt.size());
            Assert.areEqual(testData.accounts[1].Id, cashReceipt[0].Account__c);
        }
    }

    @IsTest
    static void testLogOnActivityWithBatchProcess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '';
            reportItem.xResponseError = '';
            reportItem.xResponseResult = 'Approved';
            reportItem.xCommand = 'cc:sale';
            reportItem.xStatus = '';
            reportItem.xResponseBatch = '0';
            reportItem.xInvoice = null;   // not tied to any invoice
            reportItem.xCustomerID = null;
            reportItem.xEnteredDate = Datetime.newInstanceGmt(Date.today().addDays(-1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = 400;    
            reportItem.xProcessingFee = 10;
            reportItem.xBillFirstName = 'Test';
            reportItem.xBillLastName = 'User';
            reportItem.xBillCompany = 'Test Company';
            reportItem.xBillStreet = 'Odiana';
            reportItem.xBillCity = 'Lake';
            reportItem.xBillState = 'LA';
            reportItem.xBillZip = '23889';
            reportItem.xBillCountry = 'America';


            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            Test.startTest();
            cx.import(5, Datetime.now().addDays(-1), Datetime.now());
            Test.stopTest();

            // verify the transaction Import error should get created
            List<Transaction_Import_Error__c> transactionalImportError = getTransactionImportErrorByRefNum(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, transactionalImportError.size());
            Assert.areEqual(reportItem.xRefNum, transactionalImportError[0].Merchant_Reference__c);
            Assert.areEqual(reportItem.xCommand, transactionalImportError[0].Type__c);
            Assert.areEqual(reportItem.xAmount, transactionalImportError[0].Amount__c);
            Assert.areEqual(reportItem.xProcessingFee, transactionalImportError[0].Fee__c);
            Assert.areEqual(reportItem.xBillCompany, transactionalImportError[0].Billing_Name__c);
            Assert.areEqual(reportItem.xBillStreet, transactionalImportError[0].Billing_Street__c);
            Assert.areEqual(reportItem.xBillCity, transactionalImportError[0].Billing_City__c);
            Assert.areEqual(reportItem.xBillZip, transactionalImportError[0].Billing_Postal_Code__c);
            Assert.areEqual(reportItem.xBillCountry, transactionalImportError[0].Billing_Country__c);
            Assert.areEqual(reportItem.xBillState, transactionalImportError[0].Billing_State__c);

            List<Task> tasks = getTasksByTransactionId(new Set<Id> {transactionalImportError[0].Id});
            Assert.areEqual(1,tasks.size());
            Assert.areEqual(CxTxnsImporter.ERR_COULD_NOT_IMPORT_TRANSACTION, tasks[0].Subject);
            Assert.areEqual(CxTxnsImporter.TRANSACTION_FAILED_COMMENT, tasks[0].Description);
            Assert.areEqual(Date.today(), tasks[0].ActivityDate);
            Assert.areEqual(testData.users.get(1).Id, tasks[0].OwnerId);
            Assert.areEqual(transactionalImportError[0].Id, tasks[0].WhatId);
            Assert.areEqual(CxTxnsImporter.NOT_STARTED, tasks[0].Status);

        }
    }

    @IsTest
    static void testImportTransactionDifferentCurrency() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings().createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            // the billing which is being received
            Billing__c invoice = [
                SELECT Id, Date__c, Balance__c, Payment_Processor__c, Customer__c, Ledger__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];

            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '';
            reportItem.xResponseError = '';
            reportItem.xResponseResult = 'Approved';
            reportItem.xCommand = 'cc:sale';
            reportItem.xStatus = '';
            reportItem.xResponseBatch = '0';
            reportItem.xInvoice = invoice.Id;   // tied to invoice
            reportItem.xCustomerID = '';
            reportItem.xCurrency = 'CAD';
            reportItem.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = invoice.Balance__c;    // for entire invoice amount
            reportItem.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            Test.startTest();
            Datetime endDate = Datetime.now();
            Datetime syncToDate = cx.import(5, endDate.addDays(-1), endDate);
            Test.stopTest();

            // verify sync date returned
            Assert.areEqual(endDate, syncToDate);

            // verify payment method should not created
            List<Payment_Method__c> paymentMethod = getPaymentMethods(new Set<Id>{ invoice.Customer__c });
            Assert.areEqual(0, paymentMethod.size());

            // verify cash receipt should not created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(0, cashReceipt.size());
        
            // verify payment activity should not created
            List<Payment_Activity__c> paymentActivity = getPaymentActivities(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(0, paymentActivity.size());
        
            // verify billing cash receipt should not created
            List<Billing_Cash_Receipt__c> billingCashReceipt = getBillingCashReceipts(new Set<Id>{ invoice.Id });
            Assert.isTrue(billingCashReceipt.isEmpty());
        }
    }

    @IsTest
    static void testImportTxnMultiProcessor() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor1 = testData.paymentProcessors[2];
            Payment_Processor__c paymentProcessor2 = testData.paymentProcessors[3];

            // the billing which is being received
            List<Id> invoiceIds = new List<Id>{ testData.billings[0].Id, testData.billings[1].Id };
            List<Billing__c> invoices = [
                SELECT Id, Name,Date__c, Balance__c, Payment_Processor__c, Customer__c, Ledger__c
                FROM Billing__c
                WHERE Id = :invoiceIds
            ];
            invoices[0].Payment_Processor__c = paymentProcessor1.Id;
            invoices[1].Payment_Processor__c = paymentProcessor2.Id;
            update invoices;
            
            // report item / 1 txn for processor 1
            CardknoxService.ReportData reportItem1 = new CardknoxService.ReportData();
            reportItem1.xRefNum = '1234';
            reportItem1.xErrorCode = '';
            reportItem1.xResponseError = '';
            reportItem1.xResponseResult = 'Approved';
            reportItem1.xCommand = 'cc:sale';
            reportItem1.xStatus = '';
            reportItem1.xResponseBatch = '0';
            reportItem1.xCustom19 = invoices[0].Id;   // tied to invoice
            reportItem1.xInvoice = invoices[0].Name;   // invoice name
            reportItem1.xCustomerID = '';
            reportItem1.xCurrency = CORPORATE_CURRENCY;
            reportItem1.xEnteredDate = Datetime.newInstanceGmt(invoices[0].Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem1.xAmount = invoices[0].Balance__c;    // for entire invoice amount
            reportItem1.xProcessingFee = (invoices[0].Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 1 txn for processor 1
            List<CardknoxService.ReportData> reportData1 = new List<CardknoxService.ReportData>{ reportItem1 };

            // report header for processor 1
            CardknoxService.Report report1 = new CardknoxService.Report();
            report1.xStatus = 'Success';
            report1.xRefNum = '5678';
            report1.xResult = 'S';
            report1.xError = '';
            report1.xRecordsReturned = String.valueOf(reportData1.size());
            report1.xReportData = reportData1;

            // report item / 1 txn for processor 2
            CardknoxService.ReportData reportItem2 = new CardknoxService.ReportData();
            reportItem2.xRefNum = '12345';
            reportItem2.xErrorCode = '';
            reportItem2.xResponseError = '';
            reportItem2.xResponseResult = 'Approved';
            reportItem2.xCommand = 'cc:sale';
            reportItem2.xStatus = '';
            reportItem2.xResponseBatch = '0';
            reportItem2.xCustom19 = invoices[1].Id;   // tied to invoice
            reportItem2.xInvoice = invoices[1].Name;   // invoice name
            reportItem2.xCustomerID = '';
            reportItem2.xCurrency = CORPORATE_CURRENCY;
            reportItem2.xEnteredDate = Datetime.newInstanceGmt(invoices[1].Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem2.xAmount = invoices[1].Balance__c;    // for entire invoice amount
            reportItem2.xProcessingFee = (invoices[1].Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 1 txn for processor 2
            List<CardknoxService.ReportData> reportData2 = new List<CardknoxService.ReportData>{ reportItem2 };

            // report header for processor 2
            CardknoxService.Report report2 = new CardknoxService.Report();
            report2.xStatus = 'Success';
            report2.xRefNum = '45678';
            report2.xResult = 'S';
            report2.xError = '';
            report2.xRecordsReturned = String.valueOf(reportData2.size());
            report2.xReportData = reportData2;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report1);
            mock.registerResponse('getTransactions', report2);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxAJRLogger logger = new CxAJRLogger();
            CxTxnsImporter cx1 = new CxTxnsImporter(srvc, paymentProcessor1, logger);
            CxTxnsImporter cx2 = new CxTxnsImporter(srvc, paymentProcessor2, logger);

            // test the method
            Test.startTest();
            Datetime endDate = Datetime.now();
            cx1.import(5, endDate.addDays(-1), endDate);
            cx2.import(5, endDate.addDays(-1), endDate);
            Test.stopTest();

            // verify payment methods created for each processor even though they are for same customer
            List<Payment_Method__c> paymentMethod = getPaymentMethods(new Set<Id>{ invoices[0].Customer__c }); // both invoices are for same customer
            Assert.areEqual(2, paymentMethod.size());
            Assert.areNotEqual(paymentMethod[0].Payment_Processor__c, paymentMethod[1].Payment_Processor__c);
            Assert.isTrue(paymentMethod[0].External_Id__c.contains(PaymentMethodActions.PLACEHOLDER_CARD_EXTERNAL_ID));
            Assert.isTrue(paymentMethod[1].External_Id__c.contains(PaymentMethodActions.PLACEHOLDER_CARD_EXTERNAL_ID));
        }
    }

    @IsTest
    static void testImportTxnConvenienceFeePayInFull() {
        // test = pay in full with convenience fee
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings()
            .createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[3];

            // the billing which is being received
            Billing__c invoice = [
                SELECT Id, Name,Date__c, Balance__c, Payment_Processor__c, Customer__c, Ledger__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];
            invoice.Payment_Processor__c = paymentProcessor.Id;
            update invoice;
            
            Decimal convenienceFee = 2.27;

            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '';
            reportItem.xResponseError = '';
            reportItem.xResponseResult = 'Approved';
            reportItem.xCommand = 'cc:sale';
            reportItem.xStatus = '';
            reportItem.xResponseBatch = '0';
            reportItem.xCustom09 = String.valueOf(invoice.Balance__c);    // origianl amount
            reportItem.xCustom10 = String.valueOf(convenienceFee);        // convenience fee
            reportItem.xCustom19 = invoice.Id;    // tied to invoice
            reportItem.xInvoice = invoice.Name;   // invoice name
            reportItem.xCustomerID = '';
            reportItem.xCurrency = CORPORATE_CURRENCY;
            reportItem.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = invoice.Balance__c;    // for invoice amount + convenience fee
            reportItem.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            Datetime endDate = Datetime.now();
            cx.import(5, endDate.addDays(-1), endDate);
            Test.stopTest();

            // verify cash receipt created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, cashReceipt.size());
            Assert.areEqual(reportItem.xAmount, cashReceipt[0].Amount__c);
            Assert.areEqual(paymentProcessor.Merchant_GL_Account__c, cashReceipt[0].Bank_Account__c);
            Assert.areEqual(Decimal.valueOf(reportItem.xCustom10), cashReceipt[0].Convenience_Fees_Charged__c);

            // verify payment activity created
            List<Payment_Activity__c> paymentActivity = getPaymentActivities(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, paymentActivity.size());
            Assert.areEqual(cashReceipt[0].Id, paymentActivity[0].Cash_Receipt__c);
            Assert.areEqual(reportItem.xAmount, paymentActivity[0].Amount__c);
            Assert.areEqual(reportItem.xProcessingFee, paymentActivity[0].Fee__c);
            Assert.areEqual(Decimal.valueOf(reportItem.xCustom09), paymentActivity[0].Original_Amount__c);
            Assert.areEqual(Decimal.valueOf(reportItem.xCustom10), paymentActivity[0].Convenience_Fee__c);

            // verify billing cash receipt created
            List<Billing_Cash_Receipt__c> billingCashReceipt = getBillingCashReceipts(new Set<Id>{ invoice.Id });
            Assert.areEqual(1, billingCashReceipt.size());
            Assert.areEqual(cashReceipt[0].Id, billingCashReceipt[0].Cash_Receipt__c);
            Assert.areEqual(invoice.Id, billingCashReceipt[0].Billing__c);
            Assert.areEqual(reportItem.xAmount - convenienceFee, billingCashReceipt[0].Applied_Amount__c);
            Assert.areEqual(convenienceFee, [SELECT Id, Balance__c FROM Billing__c WHERE Id = :invoice.Id].Balance__c);
        }
    }

    @IsTest
    static void testImportTxnConvenienceFeeOverpay() {
        // test = overpayment with convenience fee
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings()
            .createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[3];

            // the billing which is being received
            Billing__c invoice = [
                SELECT Id, Name,Date__c, Balance__c, Payment_Processor__c, Customer__c, Ledger__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];
            invoice.Payment_Processor__c = paymentProcessor.Id;
            update invoice;
            
            Decimal convenienceFee = 2.27;
            Decimal overpayment = 101.01;

            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '';
            reportItem.xResponseError = '';
            reportItem.xResponseResult = 'Approved';
            reportItem.xCommand = 'cc:sale';
            reportItem.xStatus = '';
            reportItem.xResponseBatch = '0';
            reportItem.xCustom09 = String.valueOf(invoice.Balance__c + overpayment);    // origianl amount
            reportItem.xCustom10 = String.valueOf(convenienceFee);        // convenience fee
            reportItem.xCustom19 = invoice.Id;    // tied to invoice
            reportItem.xInvoice = invoice.Name;   // invoice name
            reportItem.xCustomerID = '';
            reportItem.xCurrency = CORPORATE_CURRENCY;
            reportItem.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = invoice.Balance__c + overpayment;    // for invoice amount + convenience fee
            reportItem.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            Datetime endDate = Datetime.now();
            cx.import(5, endDate.addDays(-1), endDate);
            Test.stopTest();

            // verify cash receipt created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, cashReceipt.size());
            Assert.areEqual(reportItem.xAmount, cashReceipt[0].Amount__c);
            Assert.areEqual(paymentProcessor.Merchant_GL_Account__c, cashReceipt[0].Bank_Account__c);
            Assert.areEqual(Decimal.valueOf(reportItem.xCustom10), cashReceipt[0].Convenience_Fees_Charged__c);

            // verify payment activity created
            List<Payment_Activity__c> paymentActivity = getPaymentActivities(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, paymentActivity.size());
            Assert.areEqual(cashReceipt[0].Id, paymentActivity[0].Cash_Receipt__c);
            Assert.areEqual(reportItem.xAmount, paymentActivity[0].Amount__c);
            Assert.areEqual(reportItem.xProcessingFee, paymentActivity[0].Fee__c);
            Assert.areEqual(Decimal.valueOf(reportItem.xCustom09), paymentActivity[0].Original_Amount__c);
            Assert.areEqual(Decimal.valueOf(reportItem.xCustom10), paymentActivity[0].Convenience_Fee__c);

            // verify billing cash receipt created
            List<Billing_Cash_Receipt__c> billingCashReceipt = getBillingCashReceipts(new Set<Id>{ invoice.Id });
            Assert.areEqual(1, billingCashReceipt.size());
            Assert.areEqual(cashReceipt[0].Id, billingCashReceipt[0].Cash_Receipt__c);
            Assert.areEqual(invoice.Id, billingCashReceipt[0].Billing__c);
            Assert.areEqual(reportItem.xAmount - overpayment, billingCashReceipt[0].Applied_Amount__c);
            Assert.areEqual(0, [SELECT Id, Balance__c FROM Billing__c WHERE Id = :invoice.Id].Balance__c);
        }
    }

    @IsTest
    static void testImportTxnConvenienceFeeUnderpay() {
        // test = underpayment with convenience fee
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings()
            .createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[3];

            // the billing which is being received
            Billing__c invoice = [
                SELECT Id, Name,Date__c, Balance__c, Payment_Processor__c, Customer__c, Ledger__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];
            invoice.Payment_Processor__c = paymentProcessor.Id;
            update invoice;
            
            Decimal convenienceFee = 2.27;
            Decimal underpayment = 2.99;

            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '';
            reportItem.xResponseError = '';
            reportItem.xResponseResult = 'Approved';
            reportItem.xCommand = 'cc:sale';
            reportItem.xStatus = '';
            reportItem.xResponseBatch = '0';
            reportItem.xCustom09 = String.valueOf(invoice.Balance__c - underpayment);    // origianl amount
            reportItem.xCustom10 = String.valueOf(convenienceFee);        // convenience fee
            reportItem.xCustom19 = invoice.Id;    // tied to invoice
            reportItem.xInvoice = invoice.Name;   // invoice name
            reportItem.xCustomerID = '';
            reportItem.xCurrency = CORPORATE_CURRENCY;
            reportItem.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = invoice.Balance__c - underpayment + convenienceFee;    // for invoice amount + convenience fee
            reportItem.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            Datetime endDate = Datetime.now();
            cx.import(5, endDate.addDays(-1), endDate);
            Test.stopTest();

            // verify cash receipt created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, cashReceipt.size());
            Assert.areEqual(reportItem.xAmount, cashReceipt[0].Amount__c);
            Assert.areEqual(paymentProcessor.Merchant_GL_Account__c, cashReceipt[0].Bank_Account__c);
            Assert.areEqual(Decimal.valueOf(reportItem.xCustom10), cashReceipt[0].Convenience_Fees_Charged__c);

            // verify payment activity created
            List<Payment_Activity__c> paymentActivity = getPaymentActivities(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, paymentActivity.size());
            Assert.areEqual(cashReceipt[0].Id, paymentActivity[0].Cash_Receipt__c);
            Assert.areEqual(reportItem.xAmount, paymentActivity[0].Amount__c);
            Assert.areEqual(reportItem.xProcessingFee, paymentActivity[0].Fee__c);
            Assert.areEqual(Decimal.valueOf(reportItem.xCustom09), paymentActivity[0].Original_Amount__c);
            Assert.areEqual(Decimal.valueOf(reportItem.xCustom10), paymentActivity[0].Convenience_Fee__c);

            // verify billing cash receipt created
            List<Billing_Cash_Receipt__c> billingCashReceipt = getBillingCashReceipts(new Set<Id>{ invoice.Id });
            Assert.areEqual(1, billingCashReceipt.size());
            Assert.areEqual(cashReceipt[0].Id, billingCashReceipt[0].Cash_Receipt__c);
            Assert.areEqual(invoice.Id, billingCashReceipt[0].Billing__c);
            Assert.areEqual(reportItem.xAmount - convenienceFee, billingCashReceipt[0].Applied_Amount__c);
            Assert.areEqual(underpayment, [SELECT Id, Balance__c FROM Billing__c WHERE Id = :invoice.Id].Balance__c);
        }
    }

    @IsTest
    static void testImportTxnConvenienceFeeMultipay() {
        // test = multiple payments with convenience fees
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings()
            .createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[3];

            // the billing which is being received
            Billing__c invoice = [
                SELECT Id, Name,Date__c, Balance__c, Payment_Processor__c, Customer__c, Ledger__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];
            invoice.Payment_Processor__c = paymentProcessor.Id;
            update invoice;
            
            Decimal convenienceFee = 2.27;

            // report items / txns
            CardknoxService.ReportData reportItem1 = new CardknoxService.ReportData();
            reportItem1.xRefNum = '1234';
            reportItem1.xErrorCode = '';
            reportItem1.xResponseError = '';
            reportItem1.xResponseResult = 'Approved';
            reportItem1.xCommand = 'cc:sale';
            reportItem1.xStatus = '';
            reportItem1.xResponseBatch = '0';
            reportItem1.xCustom09 = String.valueOf((invoice.Balance__c * 0.5).setScale(2, System.RoundingMode.HALF_UP));    // origianl amount
            reportItem1.xCustom10 = String.valueOf(convenienceFee);        // convenience fee
            reportItem1.xCustom19 = invoice.Id;    // tied to invoice
            reportItem1.xInvoice = invoice.Name;   // invoice name
            reportItem1.xCustomerID = '';
            reportItem1.xCurrency = CORPORATE_CURRENCY;
            reportItem1.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem1.xAmount = invoice.Balance__c * 0.5 + convenienceFee;    // for invoice amount + convenience fee
            reportItem1.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            CardknoxService.ReportData reportItem2 = new CardknoxService.ReportData();
            reportItem2.xRefNum = '1235';
            reportItem2.xErrorCode = '';
            reportItem2.xResponseError = '';
            reportItem2.xResponseResult = 'Approved';
            reportItem2.xCommand = 'cc:sale';
            reportItem2.xStatus = '';
            reportItem2.xResponseBatch = '0';
            reportItem2.xCustom09 = String.valueOf((invoice.Balance__c * 0.35).setScale(2, System.RoundingMode.HALF_UP));    // origianl amount
            reportItem2.xCustom10 = String.valueOf(convenienceFee);        // convenience fee
            reportItem2.xCustom19 = invoice.Id;    // tied to invoice
            reportItem2.xInvoice = invoice.Name;   // invoice name
            reportItem2.xCustomerID = '';
            reportItem2.xCurrency = CORPORATE_CURRENCY;
            reportItem2.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem2.xAmount = invoice.Balance__c * 0.35 + convenienceFee;    // for invoice amount + convenience fee
            reportItem2.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            CardknoxService.ReportData reportItem3 = new CardknoxService.ReportData();
            reportItem3.xRefNum = '1236';
            reportItem3.xErrorCode = '';
            reportItem3.xResponseError = '';
            reportItem3.xResponseResult = 'Approved';
            reportItem3.xCommand = 'cc:sale';
            reportItem3.xStatus = '';
            reportItem3.xResponseBatch = '0';
            reportItem3.xCustom09 = String.valueOf((invoice.Balance__c * 0.35).setScale(2, System.RoundingMode.HALF_UP));    // origianl amount
            reportItem3.xCustom10 = String.valueOf(convenienceFee);        // convenience fee
            reportItem3.xCustom19 = invoice.Id;    // tied to invoice
            reportItem3.xInvoice = invoice.Name;   // invoice name
            reportItem3.xCustomerID = '';
            reportItem3.xCurrency = CORPORATE_CURRENCY;
            reportItem3.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem3.xAmount = invoice.Balance__c * 0.35 + convenienceFee;    // for invoice amount + convenience fee
            reportItem3.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            CardknoxService.ReportData reportItem4 = new CardknoxService.ReportData();
            reportItem4.xRefNum = '1237';
            reportItem4.xErrorCode = '';
            reportItem4.xResponseError = '';
            reportItem4.xResponseResult = 'Approved';
            reportItem4.xCommand = 'cc:sale';
            reportItem4.xStatus = '';
            reportItem4.xResponseBatch = '0';
            reportItem4.xCustom09 = String.valueOf((invoice.Balance__c * 0.15).setScale(2, System.RoundingMode.HALF_UP));    // origianl amount
            reportItem4.xCustom10 = String.valueOf(convenienceFee);        // convenience fee
            reportItem4.xCustom19 = invoice.Id;    // tied to invoice
            reportItem4.xInvoice = invoice.Name;   // invoice name
            reportItem4.xCustomerID = '';
            reportItem4.xCurrency = CORPORATE_CURRENCY;
            reportItem4.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem4.xAmount = invoice.Balance__c * 0.15 + convenienceFee;    // for invoice amount + convenience fee
            reportItem4.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 3 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem1, reportItem2, reportItem3, reportItem4 };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            Datetime endDate = Datetime.now();
            cx.import(5, endDate.addDays(-1), endDate);
            Test.stopTest();

            // verify cash receipt created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem1.xRefNum, reportItem2.xRefNum, reportItem3.xRefNum, reportItem4.xRefNum });
            Assert.areEqual(4, cashReceipt.size());

            // verify payment activity created
            List<Payment_Activity__c> paymentActivity = getPaymentActivities(new Set<String>{ reportItem1.xRefNum, reportItem2.xRefNum, reportItem3.xRefNum, reportItem4.xRefNum });
            Assert.areEqual(4, paymentActivity.size());

            // verify billing cash receipt created
            List<Billing_Cash_Receipt__c> billingCashReceipt = getBillingCashReceipts(new Set<Id>{ invoice.Id });
            Assert.areEqual(3, billingCashReceipt.size()); // reportItem1 and reportItem2 and reportItem3 reduce invoice balance to 0 so reportItem4 doesn't create billing cash receipt

            Assert.areEqual(0, [SELECT Id, Balance__c FROM Billing__c WHERE Id = :invoice.Id].Balance__c);
        }
    }

    @IsTest
    static void testImportTxnConvenienceFeeNoInvoice() {
        // test = no associated invoice with convenience fees
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[3];

            Payment_Processor_Customer__c cust = new Payment_Processor_Customer__c(
                Processor__c = paymentProcessor.Id,
                Account__c = testData.accounts[0].Id,
                External_Id__c = 'c123456'
            );
            insert cust;

            Decimal amount = 101.01;
            Decimal convenienceFee = 1.01;

            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '';
            reportItem.xResponseError = '';
            reportItem.xResponseResult = 'Approved';
            reportItem.xCommand = 'cc:sale';
            reportItem.xStatus = '';
            reportItem.xResponseBatch = '0';
            reportItem.xCustom09 = String.valueOf(amount); // origianl amount
            reportItem.xCustom10 = String.valueOf(convenienceFee); // convenience fee
            reportItem.xCustomerID = cust.External_Id__c;
            reportItem.xCurrency = CORPORATE_CURRENCY;
            reportItem.xEnteredDate = Datetime.newInstanceGmt(testData.acctPeriods[0].Start_Date__c.addDays(5), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = amount + convenienceFee; // for invoice amount + convenience fee
            reportItem.xProcessingFee = (amount * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            Test.startTest();
            Datetime endDate = Datetime.now();
            cx.import(5, endDate.addDays(-1), endDate);
            Test.stopTest();

            // verify cash receipt created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, cashReceipt.size());
            Assert.areEqual(reportItem.xAmount, cashReceipt[0].Amount__c);
            Assert.areEqual(paymentProcessor.Merchant_GL_Account__c, cashReceipt[0].Bank_Account__c);
            Assert.areEqual(Decimal.valueOf(reportItem.xCustom10), cashReceipt[0].Convenience_Fees_Charged__c);

            // verify payment activity created
            List<Payment_Activity__c> paymentActivity = getPaymentActivities(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, paymentActivity.size());
            Assert.areEqual(cashReceipt[0].Id, paymentActivity[0].Cash_Receipt__c);
            Assert.areEqual(reportItem.xAmount, paymentActivity[0].Amount__c);
            Assert.areEqual(reportItem.xProcessingFee, paymentActivity[0].Fee__c);
            Assert.areEqual(Decimal.valueOf(reportItem.xCustom09), paymentActivity[0].Original_Amount__c);
            Assert.areEqual(Decimal.valueOf(reportItem.xCustom10), paymentActivity[0].Convenience_Fee__c);
        }
    }

    @IsTest
    static void testImportTxnWithTIECustomer() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '';
            reportItem.xResponseError = '';
            reportItem.xResponseResult = 'Approved';
            reportItem.xCommand = 'cc:sale';
            reportItem.xStatus = '';
            reportItem.xResponseBatch = '0';
            reportItem.xInvoice = null;   // not tied to any invoice
            reportItem.xCustomerID = null;
            reportItem.xEnteredDate = Datetime.newInstanceGmt(testData.acctPeriods[0].End_Date__c.addDays(-1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = 400;    
            reportItem.xProcessingFee = 10;
            reportItem.xBillFirstName = 'Test';
            reportItem.xBillLastName = 'User';
            reportItem.xBillCompany = 'Test Company';
            reportItem.xBillStreet = 'Odiana';
            reportItem.xBillCity = 'Lake';
            reportItem.xBillState = 'LA';
            reportItem.xBillZip = '23889';
            reportItem.xBillCountry = 'America';


            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // create a TIE w/ customer
            Transaction_Import_Error__c tie = new Transaction_Import_Error__c(
                Payment_Processor__c = paymentProcessor.Id,
                Merchant_Reference__c = reportItem.xRefNum,
                Type__c = reportItem.xCommand,
                Amount__c = reportItem.xAmount,
                Fee__c = reportItem.xProcessingFee,
                Billing_Name__c = reportItem.xBillCompany,
                Billing_Street__c = reportItem.xBillStreet,
                Billing_City__c = reportItem.xBillCity,
                Billing_Postal_Code__c = reportItem.xBillZip,
                Billing_Country__c = reportItem.xBillCountry,
                Billing_State__c = reportItem.xBillState,
                Error__c = Label.ERR_CARDKNOX_MISSING_CUSTOMER_INFO,
                Customer__c = testData.accounts[0].Id
            );
            insert tie;

            // test the method
            Test.startTest();
            cx.import(5, Datetime.now().addDays(-1), Datetime.now());
            Test.stopTest();

            // verify payment method created
            List<Payment_Method__c> paymentMethod = getPaymentMethods(new Set<Id>{ tie.Customer__c });
            Assert.areEqual(1, paymentMethod.size());

            // verify cash receipt created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, cashReceipt.size());
            Assert.areEqual(tie.Customer__c, cashReceipt[0].Account__c);
            Assert.areEqual(cashReceipt[0].Amount__c, cashReceipt[0].Balance__c);

            // verify payment activity created
            List<Payment_Activity__c> paymentActivity = getPaymentActivities(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, paymentActivity.size());

            // verify transaction import error deleted
            List<Transaction_Import_Error__c> transactionImportError = getTransactionImportErrorByRefNum(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(0, transactionImportError.size());
        }
    }

    @IsTest
    static void testImportTxnWithTIEBilling() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings()
            .createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            // the billing which is being received
            Billing__c invoice = [
                SELECT Id, Name,Date__c, Balance__c, Payment_Processor__c, Customer__c, Ledger__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];
            invoice.Payment_Processor__c = paymentProcessor.Id;
            update invoice;
            
            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '';
            reportItem.xResponseError = '';
            reportItem.xResponseResult = 'Approved';
            reportItem.xCommand = 'cc:sale';
            reportItem.xStatus = '';
            reportItem.xResponseBatch = '0';
            reportItem.xCustom19 = null;   // tied to invoice
            reportItem.xInvoice = null;   // invoice name
            reportItem.xCustomerID = '';
            reportItem.xCurrency = CORPORATE_CURRENCY;
            reportItem.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = invoice.Balance__c;    // for entire invoice amount
            reportItem.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // create a TIE w/ customer
            Transaction_Import_Error__c tie = new Transaction_Import_Error__c(
                Payment_Processor__c = paymentProcessor.Id,
                Merchant_Reference__c = reportItem.xRefNum,
                Type__c = reportItem.xCommand,
                Amount__c = reportItem.xAmount,
                Fee__c = reportItem.xProcessingFee,
                Billing_Name__c = reportItem.xBillCompany,
                Billing_Street__c = reportItem.xBillStreet,
                Billing_City__c = reportItem.xBillCity,
                Billing_Postal_Code__c = reportItem.xBillZip,
                Billing_Country__c = reportItem.xBillCountry,
                Billing_State__c = reportItem.xBillState,
                Error__c = Label.ERR_CARDKNOX_MISSING_CUSTOMER_INFO,
                Billing__c = invoice.Id
            );
            insert tie;

            // test the method
            cx.import(5, Datetime.now().addDays(-1), Datetime.now());
            Test.stopTest();

            // verify payment method created
            List<Payment_Method__c> paymentMethod = getPaymentMethods(new Set<Id>{ invoice.Customer__c });
            Assert.areEqual(1, paymentMethod.size());

            // verify cash receipt created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, cashReceipt.size());
            Assert.areEqual(invoice.Customer__c, cashReceipt[0].Account__c);

            // verify payment activity created
            List<Payment_Activity__c> paymentActivity = getPaymentActivities(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, paymentActivity.size());

            // verify billing cash receipt created
            List<Billing_Cash_Receipt__c> billingCashReceipt = getBillingCashReceipts(new Set<Id>{ invoice.Id });
            Assert.areEqual(1, billingCashReceipt.size());
            Assert.areEqual(invoice.Id, billingCashReceipt[0].Billing__c);

            // verify transaction import error deleted
            List<Transaction_Import_Error__c> transactionImportError = getTransactionImportErrorByRefNum(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(0, transactionImportError.size());
        }
    }

    @IsTest
    static void testImportTxnWithTIEBillingAndCustomer() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings()
            .createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            // the billing which is being received
            Billing__c invoice = [
                SELECT Id, Name,Date__c, Balance__c, Payment_Processor__c, Customer__c, Ledger__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];
            invoice.Payment_Processor__c = paymentProcessor.Id;
            update invoice;
            
            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '';
            reportItem.xResponseError = '';
            reportItem.xResponseResult = 'Approved';
            reportItem.xCommand = 'cc:sale';
            reportItem.xStatus = '';
            reportItem.xResponseBatch = '0';
            reportItem.xCustom19 = null;   // tied to invoice
            reportItem.xInvoice = null;   // invoice name
            reportItem.xCustomerID = '';
            reportItem.xCurrency = CORPORATE_CURRENCY;
            reportItem.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = invoice.Balance__c;    // for entire invoice amount
            reportItem.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // create a TIE w/ customer
            Transaction_Import_Error__c tie = new Transaction_Import_Error__c(
                Payment_Processor__c = paymentProcessor.Id,
                Merchant_Reference__c = reportItem.xRefNum,
                Type__c = reportItem.xCommand,
                Amount__c = reportItem.xAmount,
                Fee__c = reportItem.xProcessingFee,
                Billing_Name__c = reportItem.xBillCompany,
                Billing_Street__c = reportItem.xBillStreet,
                Billing_City__c = reportItem.xBillCity,
                Billing_Postal_Code__c = reportItem.xBillZip,
                Billing_Country__c = reportItem.xBillCountry,
                Billing_State__c = reportItem.xBillState,
                Error__c = Label.ERR_CARDKNOX_MISSING_CUSTOMER_INFO,
                Billing__c = invoice.Id,
                Customer__c = testData.accounts[1].Id
            );
            insert tie;
            Assert.areNotEqual(invoice.Customer__c, tie.Customer__c);

            // test the method
            cx.import(5, Datetime.now().addDays(-1), Datetime.now());
            Test.stopTest();

            // verify payment method created
            List<Payment_Method__c> paymentMethod = getPaymentMethods(new Set<Id>{ invoice.Customer__c });
            Assert.areEqual(1, paymentMethod.size());

            // verify cash receipt created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, cashReceipt.size());
            Assert.areEqual(invoice.Customer__c, cashReceipt[0].Account__c);

            // verify payment activity created
            List<Payment_Activity__c> paymentActivity = getPaymentActivities(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, paymentActivity.size());

            // verify billing cash receipt created
            List<Billing_Cash_Receipt__c> billingCashReceipt = getBillingCashReceipts(new Set<Id>{ invoice.Id });
            Assert.areEqual(1, billingCashReceipt.size());
            Assert.areEqual(invoice.Id, billingCashReceipt[0].Billing__c);

            // verify transaction import error deleted
            List<Transaction_Import_Error__c> transactionImportError = getTransactionImportErrorByRefNum(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(0, transactionImportError.size());
        }
    }

    @IsTest
    static void testImportPendingACHTxnWithInvoice() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createPaymentProcessors();
        // test the method
        Test.startTest();
        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            // the billing which is being received
            Billing__c invoice = [
                SELECT Id, Name,Date__c, Balance__c, Payment_Processor__c, Customer__c, Ledger__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];
            invoice.Payment_Processor__c = paymentProcessor.Id;
            update invoice;
            
            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '';
            reportItem.xResponseError = '';
            reportItem.xResponseResult = 'Approved';
            reportItem.xCommand = 'check:sale';
            reportItem.xStatus = '0';
            reportItem.xResponseBatch = '0';
            reportItem.xCustom19 = invoice.Id;   // tied to invoice
            reportItem.xInvoice = invoice.Name;   // invoice name
            reportItem.xCustomerID = '';
            reportItem.xCurrency = CORPORATE_CURRENCY;
            reportItem.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = invoice.Balance__c;    // for entire invoice amount
            reportItem.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            
            Datetime endDate = Datetime.now();
            Datetime syncToDate = cx.import(5, endDate.addDays(-1), endDate);
            Test.stopTest();

            // verify sync date returned
            Assert.areEqual(endDate, syncToDate);

            // verify payment method created
            List<Payment_Method__c> paymentMethod = getPaymentMethods(new Set<Id>{ invoice.Customer__c });
            Assert.areEqual(1, paymentMethod.size());
            Assert.areEqual(invoice.Customer__c, paymentMethod[0].Customer__c);
            Assert.areEqual(paymentProcessor.Id, paymentMethod[0].Payment_Processor__c);
            Assert.isTrue(paymentMethod[0].External_Id__c.contains(PaymentMethodActions.PLACEHOLDER_ACH_EXTERNAL_ID));
            Assert.areEqual(PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE, paymentMethod[0].Payment_Method_Type__c);

            // verify cash receipt created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, cashReceipt.size());
            Assert.areEqual(reportItem.xAmount, cashReceipt[0].Amount__c);
            Assert.areEqual(invoice.Customer__c, cashReceipt[0].Account__c);
            Assert.areEqual(reportItem.xEnteredDateUTC().date(), cashReceipt[0].Receipt_Date__c);
            Assert.areEqual(CashReceiptActions.PAYMENT_TYPE_ELECTRONIC, cashReceipt[0].Payment_Type__c);
            Assert.areEqual(reportItem.xRefNum, cashReceipt[0].Payment_Reference__c);
            Assert.areEqual(paymentProcessor.Id, cashReceipt[0].Payment_Processor__c);
            Assert.areEqual(invoice.Ledger__c, cashReceipt[0].Ledger__c);
            Assert.areEqual(paymentProcessor.Merchant_GL_Account__c, cashReceipt[0].Bank_Account__c);

            // verify payment activity created
            List<Payment_Activity__c> paymentActivity = getPaymentActivities(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, paymentActivity.size());
            Assert.areEqual(paymentMethod[0].Id, paymentActivity[0].Payment_Method__c);
            Assert.areEqual(cashReceipt[0].Id, paymentActivity[0].Cash_Receipt__c);
            Assert.areEqual(reportItem.xAmount, paymentActivity[0].Amount__c);
            Assert.isNull(paymentActivity[0].Error_Message__c);
            Assert.isNull(paymentActivity[0].Error_Type__c);
            Assert.areEqual(PaymentActivityHelper.PAYMENT_TYPE, paymentActivity[0].Type__c);
            Assert.areEqual(reportItem.xProcessingFee, paymentActivity[0].Fee__c);
            Assert.areEqual(reportItem.xRefNum, paymentActivity[0].Merchant_Reference__c);
            Assert.areEqual(reportItem.xResponseBatch, paymentActivity[0].Merchant_Batch_Id__c);
            Assert.areEqual(PaymentActivityHelper.PENDING_STATUS, paymentActivity[0].Status__c);

            // verify billing cash receipt created
            List<Billing_Cash_Receipt__c> billingCashReceipt = getBillingCashReceipts(new Set<Id>{ invoice.Id });
            Assert.areEqual(1, billingCashReceipt.size());
            Assert.areEqual(reportItem.xAmount, billingCashReceipt[0].Applied_Amount__c);
            Assert.areEqual(reportItem.xCustom19, billingCashReceipt[0].Billing__c);
            Assert.areEqual(reportItem.xInvoice, billingCashReceipt[0].Billing__r.Name);
            Assert.areEqual(cashReceipt[0].Id, billingCashReceipt[0].Cash_Receipt__c);
        }
    }

    @IsTest
    static void testImportAwaitingResponseACHTxnWithInvoice() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createPaymentProcessors();
        // test the method
        Test.startTest();
        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            // the billing which is being received
            Billing__c invoice = [
                SELECT Id, Name,Date__c, Balance__c, Payment_Processor__c, Customer__c, Ledger__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];
            invoice.Payment_Processor__c = paymentProcessor.Id;
            update invoice;
            
            // report item / 1 txn
            CardknoxService.ReportData reportItem = new CardknoxService.ReportData();
            reportItem.xRefNum = '1234';
            reportItem.xErrorCode = '';
            reportItem.xResponseError = '';
            reportItem.xResponseResult = 'Approved';
            reportItem.xCommand = 'check:sale';
            reportItem.xStatus = '6';
            reportItem.xResponseBatch = '0';
            reportItem.xCustom19 = invoice.Id;   // tied to invoice
            reportItem.xInvoice = invoice.Name;   // invoice name
            reportItem.xCustomerID = '';
            reportItem.xCurrency = CORPORATE_CURRENCY;
            reportItem.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem.xAmount = invoice.Balance__c;    // for entire invoice amount
            reportItem.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 1 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            
            Datetime endDate = Datetime.now();
            Datetime syncToDate = cx.import(5, endDate.addDays(-1), endDate);
            Test.stopTest();

            // verify sync date returned
            Assert.areEqual(endDate, syncToDate);

            // verify payment method created
            List<Payment_Method__c> paymentMethod = getPaymentMethods(new Set<Id>{ invoice.Customer__c });
            Assert.areEqual(1, paymentMethod.size());
            Assert.areEqual(invoice.Customer__c, paymentMethod[0].Customer__c);
            Assert.areEqual(paymentProcessor.Id, paymentMethod[0].Payment_Processor__c);
            Assert.isTrue(paymentMethod[0].External_Id__c.contains(PaymentMethodActions.PLACEHOLDER_ACH_EXTERNAL_ID));
            Assert.areEqual(PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE, paymentMethod[0].Payment_Method_Type__c);

            // verify cash receipt created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, cashReceipt.size());
            Assert.areEqual(reportItem.xAmount, cashReceipt[0].Amount__c);
            Assert.areEqual(invoice.Customer__c, cashReceipt[0].Account__c);
            Assert.areEqual(reportItem.xEnteredDateUTC().date(), cashReceipt[0].Receipt_Date__c);
            Assert.areEqual(CashReceiptActions.PAYMENT_TYPE_ELECTRONIC, cashReceipt[0].Payment_Type__c);
            Assert.areEqual(reportItem.xRefNum, cashReceipt[0].Payment_Reference__c);
            Assert.areEqual(paymentProcessor.Id, cashReceipt[0].Payment_Processor__c);
            Assert.areEqual(invoice.Ledger__c, cashReceipt[0].Ledger__c);
            Assert.areEqual(paymentProcessor.Merchant_GL_Account__c, cashReceipt[0].Bank_Account__c);

            // verify payment activity created
            List<Payment_Activity__c> paymentActivity = getPaymentActivities(new Set<String>{ reportItem.xRefNum });
            Assert.areEqual(1, paymentActivity.size());
            Assert.areEqual(paymentMethod[0].Id, paymentActivity[0].Payment_Method__c);
            Assert.areEqual(cashReceipt[0].Id, paymentActivity[0].Cash_Receipt__c);
            Assert.areEqual(reportItem.xAmount, paymentActivity[0].Amount__c);
            Assert.isNull(paymentActivity[0].Error_Message__c);
            Assert.isNull(paymentActivity[0].Error_Type__c);
            Assert.areEqual(PaymentActivityHelper.PAYMENT_TYPE, paymentActivity[0].Type__c);
            Assert.areEqual(reportItem.xProcessingFee, paymentActivity[0].Fee__c);
            Assert.areEqual(reportItem.xRefNum, paymentActivity[0].Merchant_Reference__c);
            Assert.areEqual(reportItem.xResponseBatch, paymentActivity[0].Merchant_Batch_Id__c);
            Assert.areEqual(PaymentActivityHelper.PENDING_STATUS, paymentActivity[0].Status__c);

            // verify billing cash receipt created
            List<Billing_Cash_Receipt__c> billingCashReceipt = getBillingCashReceipts(new Set<Id>{ invoice.Id });
            Assert.areEqual(1, billingCashReceipt.size());
            Assert.areEqual(reportItem.xAmount, billingCashReceipt[0].Applied_Amount__c);
            Assert.areEqual(reportItem.xCustom19, billingCashReceipt[0].Billing__c);
            Assert.areEqual(reportItem.xInvoice, billingCashReceipt[0].Billing__r.Name);
            Assert.areEqual(cashReceipt[0].Id, billingCashReceipt[0].Cash_Receipt__c);
        }
    }

    @IsTest
    static void testImportTxnWithVoidStatus() {
        // test = multiple payments with convenience fees
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings()
            .createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[3];

            // the billing which is being received
            Billing__c invoice = [
                SELECT Id, Name,Date__c, Balance__c, Payment_Processor__c, Customer__c, Ledger__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];
            invoice.Payment_Processor__c = paymentProcessor.Id;
            update invoice;
            
            Decimal convenienceFee = 2.27;

            // report items / txns
            CardknoxService.ReportData reportItem1 = new CardknoxService.ReportData();
            reportItem1.xRefNum = '1234';
            reportItem1.xErrorCode = '';
            reportItem1.xResponseError = '';
            reportItem1.xResponseResult = 'Approved';
            reportItem1.xCommand = 'cc:sale';
            reportItem1.xStatus = '';
            reportItem1.xResponseBatch = '0';
            reportItem1.xCustom09 = String.valueOf((invoice.Balance__c * 0.5).setScale(2, System.RoundingMode.HALF_UP));    // origianl amount
            reportItem1.xCustom10 = String.valueOf(convenienceFee);        // convenience fee
            reportItem1.xCustom19 = invoice.Id;    // tied to invoice
            reportItem1.xInvoice = invoice.Name;   // invoice name
            reportItem1.xCustomerID = '';
            reportItem1.xCurrency = CORPORATE_CURRENCY;
            reportItem1.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem1.xAmount = invoice.Balance__c * 0.5 + convenienceFee;    // for invoice amount + convenience fee
            reportItem1.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);
            reportItem1.xVoid = CxTxnsImporter.VOID_STATUS_CARDKNOX_VALUE;


            // report with 3 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem1};

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            Datetime endDate = Datetime.now();
            cx.import(5, endDate.addDays(-1), endDate);
            Test.stopTest();

            // verify that no cash receipts are created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem1.xRefNum});
            Assert.areEqual(0, cashReceipt.size());

            // verify payment activity created with void status
            List<Payment_Activity__c> paymentActivity = getPaymentActivities(new Set<String>{ reportItem1.xRefNum});
            Assert.areEqual(1, paymentActivity.size());
            
            Assert.areEqual(reportItem1.xAmount, paymentActivity[0].Amount__c);
            Assert.isNotNull(paymentActivity[0].Payment_Method__c);
            Assert.isNull(paymentActivity[0].Error_Message__c);
            Assert.isNull(paymentActivity[0].Error_Type__c);
            Assert.areEqual(PaymentActivityHelper.PAYMENT_TYPE, paymentActivity[0].Type__c);
            Assert.areEqual(reportItem1.xProcessingFee, paymentActivity[0].Fee__c);
            Assert.areEqual(reportItem1.xRefNum, paymentActivity[0].Merchant_Reference__c);
            Assert.areEqual(reportItem1.xResponseBatch, paymentActivity[0].Merchant_Batch_Id__c);
            Assert.areEqual(PaymentActivityHelper.VOID_STATUS, paymentActivity[0].Status__c);

            // verify no billing cash receipts are created
            List<Billing_Cash_Receipt__c> billingCashReceipt = getBillingCashReceipts(new Set<Id>{ invoice.Id });
            Assert.areEqual(0, billingCashReceipt.size());
        }
    }
    @IsTest
    static void testImportTxnVoidStatusMultiple() {
        // test = multiple payments with convenience fees
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings()
            .createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[3];

            // the billing which is being received
            Billing__c invoice = [
                SELECT Id, Name,Date__c, Balance__c, Payment_Processor__c, Customer__c, Ledger__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];
            invoice.Payment_Processor__c = paymentProcessor.Id;
            update invoice;
            
            Decimal convenienceFee = 2.27;

            // report items / txns
            CardknoxService.ReportData reportItem1 = new CardknoxService.ReportData();
            reportItem1.xRefNum = '1234';
            reportItem1.xErrorCode = '';
            reportItem1.xResponseError = '';
            reportItem1.xResponseResult = 'Approved';
            reportItem1.xCommand = 'cc:sale';
            reportItem1.xStatus = '';
            reportItem1.xResponseBatch = '0';
            reportItem1.xCustom09 = String.valueOf((invoice.Balance__c * 0.5).setScale(2, System.RoundingMode.HALF_UP));    // origianl amount
            reportItem1.xCustom10 = String.valueOf(convenienceFee);        // convenience fee
            reportItem1.xCustom19 = invoice.Id;    // tied to invoice
            reportItem1.xInvoice = invoice.Name;   // invoice name
            reportItem1.xCustomerID = '';
            reportItem1.xCurrency = CORPORATE_CURRENCY;
            reportItem1.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem1.xAmount = invoice.Balance__c * 0.5 + convenienceFee;    // for invoice amount + convenience fee
            reportItem1.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);
            reportItem1.xVoid = CxTxnsImporter.VOID_STATUS_CARDKNOX_VALUE;

            CardknoxService.ReportData reportItem2 = new CardknoxService.ReportData();
            reportItem2.xRefNum = '1235';
            reportItem2.xErrorCode = '';
            reportItem2.xResponseError = '';
            reportItem2.xResponseResult = 'Approved';
            reportItem2.xCommand = 'cc:sale';
            reportItem2.xStatus = '';
            reportItem2.xResponseBatch = '0';
            reportItem2.xCustom09 = String.valueOf((invoice.Balance__c * 0.35).setScale(2, System.RoundingMode.HALF_UP));    // origianl amount
            reportItem2.xCustom10 = String.valueOf(convenienceFee);        // convenience fee
            reportItem2.xCustom19 = invoice.Id;    // tied to invoice
            reportItem2.xInvoice = invoice.Name;   // invoice name
            reportItem2.xCustomerID = '';
            reportItem2.xCurrency = CORPORATE_CURRENCY;
            reportItem2.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem2.xAmount = invoice.Balance__c * 0.35 + convenienceFee;    // for invoice amount + convenience fee
            reportItem2.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);
            reportItem2.xVoid = CxTxnsImporter.VOID_STATUS_CARDKNOX_VALUE;

            CardknoxService.ReportData reportItem3 = new CardknoxService.ReportData();
            reportItem3.xRefNum = '1236';
            reportItem3.xErrorCode = '';
            reportItem3.xResponseError = '';
            reportItem3.xResponseResult = 'Approved';
            reportItem3.xCommand = 'cc:sale';
            reportItem3.xStatus = '';
            reportItem3.xResponseBatch = '0';
            reportItem3.xCustom09 = String.valueOf((invoice.Balance__c * 0.35).setScale(2, System.RoundingMode.HALF_UP));    // origianl amount
            reportItem3.xCustom10 = String.valueOf(convenienceFee);        // convenience fee
            reportItem3.xCustom19 = invoice.Id;    // tied to invoice
            reportItem3.xInvoice = invoice.Name;   // invoice name
            reportItem3.xCustomerID = '';
            reportItem3.xCurrency = CORPORATE_CURRENCY;
            reportItem3.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem3.xAmount = invoice.Balance__c * 0.35 + convenienceFee;    // for invoice amount + convenience fee
            reportItem3.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            CardknoxService.ReportData reportItem4 = new CardknoxService.ReportData();
            reportItem4.xRefNum = '1237';
            reportItem4.xErrorCode = '';
            reportItem4.xResponseError = '';
            reportItem4.xResponseResult = 'Approved';
            reportItem4.xCommand = 'cc:sale';
            reportItem4.xStatus = '';
            reportItem4.xResponseBatch = '0';
            reportItem4.xCustom09 = String.valueOf((invoice.Balance__c * 0.15).setScale(2, System.RoundingMode.HALF_UP));    // origianl amount
            reportItem4.xCustom10 = String.valueOf(convenienceFee);        // convenience fee
            reportItem4.xCustom19 = invoice.Id;    // tied to invoice
            reportItem4.xInvoice = invoice.Name;   // invoice name
            reportItem4.xCustomerID = '';
            reportItem4.xCurrency = CORPORATE_CURRENCY;
            reportItem4.xEnteredDate = Datetime.newInstanceGmt(invoice.Date__c.addDays(1), Time.newInstance(0,0,0,1)).format('M/d/yyyy h:mm:ss a');
            reportItem4.xAmount = invoice.Balance__c * 0.15 + convenienceFee;    // for invoice amount + convenience fee
            reportItem4.xProcessingFee = (invoice.Balance__c * 0.018).setScale(2, System.RoundingMode.HALF_UP);

            // report with 3 txn
            List<CardknoxService.ReportData> reportData = new List<CardknoxService.ReportData>{ reportItem1, reportItem2, reportItem3, reportItem4 };

            // report header
            CardknoxService.Report report = new CardknoxService.Report();
            report.xStatus = 'Success';
            report.xRefNum = '5678';
            report.xResult = 'S';
            report.xError = '';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xReportData = reportData;

            // create mocked service to avoid http response mocking
            GenericMock mock = new GenericMock();
            mock.registerResponse('getTransactions', report);

            CxClient srvc = (CxClient) Test.createStub(CxClient.class, mock);
            CxTxnsImporter cx = new CxTxnsImporter(srvc, paymentProcessor, new CxAJRLogger());

            // test the method
            Datetime endDate = Datetime.now();
            cx.import(5, endDate.addDays(-1), endDate);
            Test.stopTest();

            // verify only 2 cash receipts are created
            List<Cash_Receipt__c> cashReceipt = getCashReceipts(new Set<String>{ reportItem1.xRefNum, reportItem2.xRefNum, reportItem3.xRefNum, reportItem4.xRefNum });
            Assert.areEqual(2, cashReceipt.size());

            //make sure the report item 3 has created the cash receipt
            Assert.areEqual(reportItem3.xAmount, cashReceipt[0].Amount__c);
            Assert.areEqual(invoice.Customer__c, cashReceipt[0].Account__c);
            Assert.areEqual(reportItem3.xEnteredDateUTC().date(), cashReceipt[0].Receipt_Date__c);
            Assert.areEqual(CashReceiptActions.PAYMENT_TYPE_ELECTRONIC, cashReceipt[0].Payment_Type__c);
            Assert.areEqual(reportItem3.xRefNum, cashReceipt[0].Payment_Reference__c);
            Assert.areEqual(paymentProcessor.Id, cashReceipt[0].Payment_Processor__c);
            Assert.areEqual(invoice.Ledger__c, cashReceipt[0].Ledger__c);
            Assert.areEqual(paymentProcessor.Merchant_GL_Account__c, cashReceipt[0].Bank_Account__c);

            //make sure the report item 4 has created the cash receipt
            Assert.areEqual(reportItem4.xAmount, cashReceipt[1].Amount__c);
            Assert.areEqual(invoice.Customer__c, cashReceipt[1].Account__c);
            Assert.areEqual(reportItem4.xEnteredDateUTC().date(), cashReceipt[1].Receipt_Date__c);
            Assert.areEqual(CashReceiptActions.PAYMENT_TYPE_ELECTRONIC, cashReceipt[1].Payment_Type__c);
            Assert.areEqual(reportItem4.xRefNum, cashReceipt[1].Payment_Reference__c);
            Assert.areEqual(paymentProcessor.Id, cashReceipt[1].Payment_Processor__c);
            Assert.areEqual(invoice.Ledger__c, cashReceipt[1].Ledger__c);
            Assert.areEqual(paymentProcessor.Merchant_GL_Account__c, cashReceipt[1].Bank_Account__c);

            // verify payment activities created
            List<Payment_Activity__c> paymentActivity = getPaymentActivities(new Set<String>{ reportItem1.xRefNum, reportItem2.xRefNum, reportItem3.xRefNum, reportItem4.xRefNum });
            Assert.areEqual(4, paymentActivity.size());
            
            //paymentActivity[0] should be in void status
            Assert.areEqual(reportItem1.xAmount, paymentActivity[0].Amount__c);
            Assert.isNotNull(paymentActivity[0].Payment_Method__c);
            Assert.isNull(paymentActivity[0].Error_Message__c);
            Assert.isNull(paymentActivity[0].Error_Type__c);
            Assert.areEqual(PaymentActivityHelper.PAYMENT_TYPE, paymentActivity[0].Type__c);
            Assert.areEqual(reportItem1.xProcessingFee, paymentActivity[0].Fee__c);
            Assert.areEqual(reportItem1.xRefNum, paymentActivity[0].Merchant_Reference__c);
            Assert.areEqual(reportItem1.xResponseBatch, paymentActivity[0].Merchant_Batch_Id__c);
            Assert.areEqual(PaymentActivityHelper.VOID_STATUS, paymentActivity[0].Status__c);

            //paymentActivity[1] should be in void status
            Assert.isNotNull(paymentActivity[1].Payment_Method__c);
            Assert.areEqual(reportItem2.xAmount, paymentActivity[1].Amount__c);
            Assert.isNull(paymentActivity[1].Error_Message__c);
            Assert.isNull(paymentActivity[1].Error_Type__c);
            Assert.areEqual(PaymentActivityHelper.PAYMENT_TYPE, paymentActivity[1].Type__c);
            Assert.areEqual(reportItem2.xProcessingFee, paymentActivity[1].Fee__c);
            Assert.areEqual(reportItem2.xRefNum, paymentActivity[1].Merchant_Reference__c);
            Assert.areEqual(reportItem2.xResponseBatch, paymentActivity[1].Merchant_Batch_Id__c);
            Assert.areEqual(PaymentActivityHelper.VOID_STATUS, paymentActivity[1].Status__c);

            //paymentActivity[2] should be in Success status
            Assert.isNotNull(paymentActivity[2].Payment_Method__c);
            Assert.areEqual(reportItem3.xAmount, paymentActivity[2].Amount__c);
            Assert.isNull(paymentActivity[2].Error_Message__c);
            Assert.isNull(paymentActivity[2].Error_Type__c);
            Assert.areEqual(PaymentActivityHelper.PAYMENT_TYPE, paymentActivity[2].Type__c);
            Assert.areEqual(reportItem3.xProcessingFee, paymentActivity[2].Fee__c);
            Assert.areEqual(reportItem3.xRefNum, paymentActivity[2].Merchant_Reference__c);
            Assert.areEqual(reportItem3.xResponseBatch, paymentActivity[2].Merchant_Batch_Id__c);
            Assert.areEqual(PaymentActivityHelper.SUCCESS_STATUS, paymentActivity[2].Status__c);

            //paymentActivity[2] should be in Success status
            Assert.isNotNull(paymentActivity[3].Payment_Method__c);
            Assert.areEqual(reportItem4.xAmount, paymentActivity[3].Amount__c);
            Assert.isNull(paymentActivity[3].Error_Message__c);
            Assert.isNull(paymentActivity[3].Error_Type__c);
            Assert.areEqual(PaymentActivityHelper.PAYMENT_TYPE, paymentActivity[3].Type__c);
            Assert.areEqual(reportItem4.xProcessingFee, paymentActivity[3].Fee__c);
            Assert.areEqual(reportItem4.xRefNum, paymentActivity[3].Merchant_Reference__c);
            Assert.areEqual(reportItem4.xResponseBatch, paymentActivity[3].Merchant_Batch_Id__c);
            Assert.areEqual(PaymentActivityHelper.SUCCESS_STATUS, paymentActivity[3].Status__c);

            // verify billing cash receipt created
            List<Billing_Cash_Receipt__c> billingCashReceipt = getBillingCashReceipts(new Set<Id>{ invoice.Id });
            //reportitem 1 and 2 is in void status 
            //reportitem 3 and reportitem 4 should only create one-one bcr
            Assert.areEqual(2, billingCashReceipt.size()); 

            //make sure correct bcr is created for the correct cr
            Assert.areEqual(reportItem3.xAmount, billingCashReceipt[0].Applied_Amount__c + convenienceFee);
            Assert.areEqual(reportItem3.xCustom19, billingCashReceipt[0].Billing__c);
            Assert.areEqual(reportItem3.xInvoice, billingCashReceipt[0].Billing__r.Name);
            Assert.areEqual(cashReceipt[0].Id, billingCashReceipt[0].Cash_Receipt__c);

            //make sure correct bcr is created for the correct cr
            Assert.areEqual(reportItem4.xAmount, billingCashReceipt[1].Applied_Amount__c + convenienceFee);
            Assert.areEqual(reportItem4.xCustom19, billingCashReceipt[1].Billing__c);
            Assert.areEqual(reportItem4.xInvoice, billingCashReceipt[1].Billing__r.Name);
            Assert.areEqual(cashReceipt[1].Id, billingCashReceipt[1].Cash_Receipt__c);
        }
    }
    private static List<Billing_Cash_Receipt__c> getBillingCashReceipts(Set<Id> invoiceIds) {
        return [
            SELECT
                Id
              , Applied_Amount__c
              , Billing__c
              , Billing__r.Name
              , Cash_Receipt__c
            FROM Billing_Cash_Receipt__c
            WHERE Billing__c IN :invoiceIds
        ];
    }

    private static List<Cash_Receipt__c> getCashReceipts(Set<String> refNums) {
        return [
            SELECT
                Id
              , Amount__c
              , Account__c
              , Receipt_Date__c
              , Payment_Type__c
              , Payment_Reference__c
              , Payment_Processor__c
              , Ledger__c
              , Bank_Account__c
              , Convenience_Fees_Charged__c
              , Balance__c
            FROM Cash_Receipt__c
            WHERE Payment_Reference__c IN :refNums
        ];
    }

    private static List<Payment_Activity__c> getPaymentActivities(Set<String> refNums) {
        return [
            SELECT 
                Id
              , Amount__c
              , Error_Message__c
              , Error_Type__c
              , Type__c
              , Fee__c
              , Status__c
              , Merchant_Batch_Id__c
              , Merchant_Reference__c
              , Payment_Method__c
              , Cash_Receipt__c
              , Original_Amount__c
              , Convenience_Fee__c 
            FROM Payment_Activity__c 
            WHERE Merchant_Reference__c = :refNums
        ];
    }

    private static List<Payment_Method__c> getPaymentMethods(Set<Id> customerIds) {
        return [
            SELECT
                Id
                , Last_Four_Digits__c
                , Payment_Method_Type__c
                , Payment_Processor__c
                , External_Id__c
                , Customer__c
                , Expiration_Month__c
                , Expiration_Year__c
                , Type__c
                , Routing_Number__c
                , Bank_Account_Type__c
                , Bank_Name__c
            FROM Payment_Method__c
            WHERE Customer__c = :customerIds
        ];
    }

    private static List<Transaction_Import_Error__c> getTransactionImportErrorByRefNum(Set<String> refNumbers) {
        return [
            SELECT
                Id
                , Merchant_Reference__c
                , Type__c
                , Amount__c
                , Payment_Processor__c
                , Customer__c
                , Fee__c 
                , Date__c
                , Error__c 
                , Billing__c
                , Billing_Name__c 
                , Billing_Street__c 
                , Billing_City__c 
                , Billing_State__c 
                , Billing_Postal_Code__c  
                , Billing_Country__c 
            FROM Transaction_Import_Error__c
            WHERE Merchant_Reference__c = :refNumbers
        ];
    }

    private static List<Task> getTasksByTransactionId(Set<Id> transactionErrorIds) {
        return [
            SELECT
                Id
                , WhatId
                , Status
                , Subject
                , OwnerId
                , Description
                , ActivityDate 
                , Priority
            FROM Task
            WHERE WhatId = :transactionErrorIds
        ];
    }

}