@IsTest
public with sharing class CxTxnsUpdaterTest {
    
    @TestSetup
    static void setupTestData(){
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testDateRangeIteratorStartEqualEnd() {
        // total range to iterate over
        CxTxnsUpdater.DateRange range = new CxTxnsUpdater.DateRange(
            DateTime.newInstanceGMT(2023, 1, 1, 1, 1, 1), // 2023-01-01 01:01:01
            DateTime.newInstanceGMT(2023, 1, 1, 1, 1, 1)  // 2023-01-01 01:01:01
        );

        Integer step = 60; // iterage based on 60 day increments

        List<CxTxnsUpdater.DateRange> windows = runDateRangeIterator(range, step);

        // expected windows
        Assert.areEqual(0, windows.size());
    }

    @IsTest
    static void testDateRangeIteratorRangeLessThanDay() {
        // total range to iterate over
        CxTxnsUpdater.DateRange range = new CxTxnsUpdater.DateRange(
            DateTime.newInstanceGMT(2023, 1, 1, 1, 1, 1), // 2023-01-01 01:01:01
            DateTime.newInstanceGMT(2023, 1, 1, 1, 1, 2)  // 2023-01-01 01:01:02
        );

        Integer step = 60; // iterage based on 60 day increments

        List<CxTxnsUpdater.DateRange> windows = runDateRangeIterator(range, step);

        // expected windows
        Assert.areEqual(1, windows.size());
        // 2022-11-11 11:11:11 - 2023-01-01 01:01:01
        Assert.areEqual(range.startDate(), windows[0].startDate());
        Assert.areEqual(range.endDate(), windows[0].endDate());
    }

    @IsTest
    static void testDateRangeIteratorRangeLessThanStep() {
        // total range to iterate over
        CxTxnsUpdater.DateRange range = new CxTxnsUpdater.DateRange(
            DateTime.newInstanceGMT(2022, 11, 11, 11, 11, 11), // 2022-11-11 11:11:11
            DateTime.newInstanceGMT(2023, 1, 1, 1, 1, 1)       // 2023-01-01 01:01:01
        );

        Integer step = 60; // iterage based on 60 day increments

        List<CxTxnsUpdater.DateRange> windows = runDateRangeIterator(range, step);

        // expected windows
        Assert.areEqual(1, windows.size());
        // 2022-11-11 11:11:11 - 2023-01-01 01:01:01
        Assert.areEqual(range.startDate(), windows[0].startDate());
        Assert.areEqual(range.endDate(), windows[0].endDate());
    }

    @IsTest
    static void testDateRangeIteratorRangeMoreThanStep() {
        // total range to iterate over
        CxTxnsUpdater.DateRange range = new CxTxnsUpdater.DateRange(
            DateTime.newInstanceGMT(2022, 11, 11, 11, 11, 11), // 2022-11-11 11:11:11
            DateTime.newInstanceGMT(2023, 4, 4, 4, 4, 4)       // 2023-04-04 04:04:04
        );

        Integer step = 60; // iterage based on 60 day increments

        List<CxTxnsUpdater.DateRange> windows = runDateRangeIterator(range, step);

        // expected windows
        Assert.areEqual(3, windows.size());
        // 2022-11-11 11:11:11 - 2023-01-10 11:11:11
        Assert.areEqual(range.startDate(), windows[0].startDate());
        Assert.areEqual(range.startDate().addDays(step), windows[0].endDate());
        // 2023-01-10 11:11:11 - 2023-03-11 11:11:11
        Assert.areEqual(range.startDate().addDays(step), windows[1].startDate());
        Assert.areEqual(range.startDate().addDays(step*2), windows[1].endDate());
        // 2023-03-11 11:11:11 - 2023-04-04 04:04:04
        Assert.areEqual(range.startDate().addDays(step*2), windows[2].startDate());
        Assert.areEqual(range.endDate(), windows[2].endDate());
    }

    @IsTest
    static void testUpdateActivities() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            // batch report item / 1 batch
            CardknoxService.BatchReportData reportItem = new CardknoxService.BatchReportData();
            reportItem.xBatch = '18500580';
            reportItem.xBatchDate = '5/1/2023';
            reportItem.xBatchTime = '12:00:45 PM';
            reportItem.xTotalCount = '3';
            reportItem.xTotalAmount = '306.85';
            reportItem.xSaleCount = '3';
            reportItem.xSaleAmount = '306.85';
            reportItem.xVisaSaleCount = '3';
            reportItem.xVisaSaleAmount = '306.85';
            reportItem.xMCSaleCount = null;
            reportItem.xMCSaleAmount = null;
            reportItem.xAchSaleCount = null;
            reportItem.xAchSaleAmount = null;

            // batch report with 1 batch
            List<CardknoxService.BatchReportData> reportData = new List<CardknoxService.BatchReportData>{ reportItem };

            // report header
            CardknoxService.BatchReport report = new CardknoxService.BatchReport();
            report.xReportData = reportData;
            report.xResult = 'S';
            report.xStatus = 'Success';
            report.xError = '';
            report.xErrorCode = '00000';
            report.xRefNum = '10100711512';
            report.xAvsResultCode = '';
            report.xAvsResult = 'Unmapped AVS response';
            report.xCvvResultCode = '';
            report.xCvvResult = 'No CVV data available';
            report.xRecordsReturned = String.valueOf(reportData.size());
            report.xAdditionalData = '';
            report.xDate = '5/1/2023 4:15:35 PM';

            Payment_Processor__c processor = testData.paymentProcessors[2];

            Payment_Processor_Customer__c customer = new Payment_Processor_Customer__c(
                Account__c = testData.accounts.get(1).Id, 
                Processor__c = processor.Id, 
                External_Id__c = '123'
            );
            insert customer;

            Payment_Method__c paymentMethod = new Payment_Method__c(
                Customer__c = customer.Account__c, 
                Payment_Processor__c = processor.Id, 
                External_Id__c = '123',
                Last_Four_Digits__c = '4242',
                Payment_Method_Type__c = 'Credit Card', 
                Status__c = 'Active',
                Expiration_Month__c = '12',
                Expiration_Year__c = '2224',
                Type__c = 'Visa',
                Default__c = true
            );
            insert paymentMethod;

            Cash_Receipt__c cashReceipt = new Cash_Receipt__c(
                Account__c = customer.Account__c,
                Credit_GL_Account__c = testData.glAccounts[1].Id,
                Amount__c = 400,
                Status__c = 'Approved',
                Receipt_Date__c = Date.newInstance(2023,5,1),
                Purpose__c = 'Customer Receipt',
                Payment_Reference__c = '123456789',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Payment_Processor__c = processor.Id
            );
            insert cashReceipt;

            Payment_Activity__c paymentActivity = new Payment_Activity__c(
                Type__c = PaymentActivityHelper.PAYMENT_TYPE,
                Status__c = PaymentActivityHelper.PENDING_STATUS,
                Amount__c = 9.99,
                Payment_Method__c = paymentMethod.Id,
                Cash_Receipt__c = cashReceipt.Id,
                Merchant_Reference__c = cashReceipt.Payment_Reference__c,
                Merchant_Batch_Id__c = reportItem.xBatch
            );
            insert paymentActivity;

            List<Payment_Activity__c> activities = getPaymentActivities(new Set<Id>{processor.Id}, new Set<String>());

            // create mock services
            GenericMock mockSrvc = new GenericMock();
            mockSrvc.registerResponse('getTransactionBatchReport', report);
            CxClient clientSrvc = (CxClient) Test.createStub(CxClient.class, mockSrvc);         

            CxAJRLogger logger = new CxAJRLogger();
            // initialize test subject
            CxTxnsUpdater cx = new CxTxnsUpdater(clientSrvc, logger);

            // test the method
            Test.startTest();
            cx.updateActivities(activities, DateTime.now());
            Test.stopTest();
            
            // verify bank deposit created
            List<Bank_Deposit__c> bankDeposit = [SELECT Id, Merchant_Batch_Id__c, Amount__c, Ledger_Amount__c, Deposit_Date__c, Bank_Account__c FROM Bank_Deposit__c];
            Assert.areEqual(1, bankDeposit.size());
            Assert.areEqual(reportItem.xBatch, bankDeposit[0].Merchant_Batch_Id__c);
            Assert.areEqual(cashReceipt.Amount__c, bankDeposit[0].Amount__c);
            Assert.areEqual(bankDeposit[0].Amount__c, bankDeposit[0].Ledger_Amount__c);
            Assert.areEqual(reportItem.xBatchDateTimeUTC().dateGMT(), bankDeposit[0].Deposit_Date__c);
            Assert.areEqual(processor.Merchant_GL_Account__c, bankDeposit[0].Bank_Account__c);
            Assert.areEqual(1, [SELECT count() FROM Cash_Receipt__c WHERE Bank_Deposit__c = :bankDeposit[0].Id]);
        }
    }
    
    @IsTest
    static void testUpdateActivitiesWith61DaysDifference() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();
        
        System.runAs(testData.users.get(1)) {
            // batch report item / 1 batch
            CardknoxService.BatchReportData reportItem1 = new CardknoxService.BatchReportData();
            reportItem1.xBatch = '18500580';
            reportItem1.xBatchDate = System.today().format();
            reportItem1.xBatchTime = '12:00:45 PM';
            reportItem1.xTotalCount = '3';
            reportItem1.xTotalAmount = '306.85';
            reportItem1.xSaleCount = '3';
            reportItem1.xSaleAmount = '306.85';
            reportItem1.xVisaSaleCount = '3';
            reportItem1.xVisaSaleAmount = '306.85';
            reportItem1.xMCSaleCount = '';
            reportItem1.xMCSaleAmount = '';
            reportItem1.xAchSaleCount = '';
            reportItem1.xAchSaleAmount = '';

            CardknoxService.BatchReportData reportItem2 = new CardknoxService.BatchReportData();
            reportItem2.xBatch = '18500581';
            reportItem2.xBatchDate = System.today().addDays(61).format();
            reportItem2.xBatchTime = '12:00:45 PM';
            reportItem2.xTotalCount = '3';
            reportItem2.xTotalAmount = '306.85';
            reportItem2.xSaleCount = '3';
            reportItem2.xSaleAmount = '306.85';
            reportItem2.xVisaSaleCount = '3';
            reportItem2.xVisaSaleAmount = '306.85';
            reportItem2.xMCSaleCount = null;
            reportItem2.xMCSaleAmount = null;
            reportItem2.xAchSaleCount = null;
            reportItem2.xAchSaleAmount = null;

            CardknoxService.BatchReportData reportItem3 = new CardknoxService.BatchReportData();
            reportItem3.xBatch = '18500582';
            reportItem3.xBatchDate = System.today().addDays(121).format();
            reportItem3.xBatchTime = '12:00:45 PM';
            reportItem3.xTotalCount = '3';
            reportItem3.xTotalAmount = '306.85';
            reportItem3.xSaleCount = '3';
            reportItem3.xSaleAmount = '306.85';
            reportItem3.xVisaSaleCount = '3';
            reportItem3.xVisaSaleAmount = '306.85';
            reportItem3.xMCSaleCount = '';
            reportItem3.xMCSaleAmount = '';
            reportItem3.xAchSaleCount = '';
            reportItem3.xAchSaleAmount = '';

            // report header
            CardknoxService.BatchReport report1 = new CardknoxService.BatchReport();
            report1.xReportData = new List<CardknoxService.BatchReportData>{reportItem1};
            report1.xResult = 'S';
            report1.xStatus = 'Success';
            report1.xError = '';
            report1.xErrorCode = '00000';
            report1.xRefNum = '10100711512';
            report1.xAvsResultCode = '';
            report1.xAvsResult = 'Unmapped AVS response';
            report1.xCvvResultCode = '';
            report1.xCvvResult = 'No CVV data available';
            report1.xRecordsReturned = '1';
            report1.xAdditionalData = '';
            report1.xDate = '5/1/2023 4:15:35 PM';

             // report header
             CardknoxService.BatchReport report2 = new CardknoxService.BatchReport();
             report2.xReportData = new List<CardknoxService.BatchReportData>{reportItem2};
             report2.xResult = 'S';
             report2.xStatus = 'Success';
             report2.xError = '';
             report2.xErrorCode = '00000';
             report2.xRefNum = '10100711512';
             report2.xAvsResultCode = '';
             report2.xAvsResult = 'Unmapped AVS response';
             report2.xCvvResultCode = '';
             report2.xCvvResult = 'No CVV data available';
             report2.xRecordsReturned = '1';
             report2.xAdditionalData = '';
             report2.xDate = '5/1/2023 4:15:35 PM';

              // report header
            CardknoxService.BatchReport report3 = new CardknoxService.BatchReport();
            report3.xReportData = new List<CardknoxService.BatchReportData>{reportItem3};
            report3.xResult = 'S';
            report3.xStatus = 'Success';
            report3.xError = '';
            report3.xErrorCode = '00000';
            report3.xRefNum = '10100711512';
            report3.xAvsResultCode = '';
            report3.xAvsResult = 'Unmapped AVS response';
            report3.xCvvResultCode = '';
            report3.xCvvResult = 'No CVV data available';
            report3.xRecordsReturned = '1';
            report3.xAdditionalData = '';
            report3.xDate = '5/1/2023 4:15:35 PM';

            Payment_Processor__c processor = testData.paymentProcessors[2];
            processor.Last_Sync__c = Datetime.now().addDays(-121);
            update processor;

            Payment_Processor_Customer__c customer = new Payment_Processor_Customer__c(
                Account__c = testData.accounts.get(1).Id, 
                Processor__c = processor.Id, 
                External_Id__c = '123'
            );
            insert customer;

            Payment_Method__c paymentMethod = new Payment_Method__c(
                Customer__c = customer.Account__c, 
                Payment_Processor__c = processor.Id, 
                External_Id__c = '123',
                Last_Four_Digits__c = '4242',
                Payment_Method_Type__c = 'Credit Card', 
                Status__c = 'Active',
                Expiration_Month__c = '12',
                Expiration_Year__c = '2224',
                Type__c = 'Visa',
                Default__c = true
            );
            insert paymentMethod;

            List<Cash_Receipt__c> cashReceipts = new List<Cash_Receipt__c>();

            cashReceipts.add(new Cash_Receipt__c(
                Account__c = customer.Account__c,
                Bank_Account__c = processor.Merchant_GL_Account__c,
                Amount__c = 400,
                Status__c = 'Approved',
                Receipt_Date__c = System.today(),
                Purpose__c = 'Customer Receipt',
                Payment_Reference__c = '1234',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Payment_Processor__c = processor.Id
            ));
            cashReceipts.add(new Cash_Receipt__c(
                Account__c = customer.Account__c,
                Bank_Account__c = processor.Merchant_GL_Account__c,
                Amount__c = 200,
                Status__c = 'Approved',
                Receipt_Date__c = System.today().addDays(-61),
                Purpose__c = 'Customer Receipt',
                Payment_Reference__c = '12345',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Payment_Processor__c = processor.Id
            ));
            cashReceipts.add(new Cash_Receipt__c(
                Account__c = customer.Account__c,
                Bank_Account__c = processor.Merchant_GL_Account__c,
                Amount__c = 200,
                Status__c = 'Approved',
                Receipt_Date__c = System.today().addDays(-121),
                Purpose__c = 'Customer Receipt',
                Payment_Reference__c = '12346',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Payment_Processor__c = processor.Id
            ));

            insert cashReceipts;

            Payment_Activity__c paymentActivity1 = new Payment_Activity__c(
                Type__c = PaymentActivityHelper.PAYMENT_TYPE,
                Status__c = PaymentActivityHelper.PENDING_STATUS,
                Amount__c = 9.99,
                Payment_Method__c = paymentMethod.Id,
                Cash_Receipt__c = cashReceipts[0].Id,
                Merchant_Reference__c = '1234',
                Merchant_Batch_Id__c = reportItem1.xBatch,
                Payment_Date__c = cashReceipts[0].Receipt_Date__c
            );
            Payment_Activity__c paymentActivity2 = new Payment_Activity__c(
                Type__c = PaymentActivityHelper.PAYMENT_TYPE,
                Status__c = PaymentActivityHelper.PENDING_STATUS,
                Amount__c = 9.99,
                Payment_Method__c = paymentMethod.Id,
                Cash_Receipt__c = cashReceipts[1].Id,
                Merchant_Reference__c = '12345',
                Merchant_Batch_Id__c = reportItem2.xBatch,
                Payment_Date__c = cashReceipts[1].Receipt_Date__c
            );
            Payment_Activity__c paymentActivity3 = new Payment_Activity__c(
                Type__c = PaymentActivityHelper.PAYMENT_TYPE,
                Status__c = PaymentActivityHelper.PENDING_STATUS,
                Amount__c = 9.99,
                Payment_Method__c = paymentMethod.Id,
                Cash_Receipt__c = cashReceipts[2].Id,
                Merchant_Reference__c = '12346',
                Merchant_Batch_Id__c = reportItem3.xBatch,
                Payment_Date__c = cashReceipts[2].Receipt_Date__c
            );
            insert new List<Payment_Activity__c>{paymentActivity1,paymentActivity2,paymentActivity3};

            List<Payment_Activity__c> activities = getPaymentActivities(new Set<Id>{processor.Id}, new Set<String>());
            // create mock services
            GenericMock mockSrvc = new GenericMock();
            mockSrvc.registerResponse('getTransactionBatchReport', report1);
            mockSrvc.registerResponse('getTransactionBatchReport', report2);
            mockSrvc.registerResponse('getTransactionBatchReport', report3);
            CxClient clientSrvc = (CxClient) Test.createStub(CxClient.class, mockSrvc);       

            CxAJRLogger logger = new CxAJRLogger();
            // initialize test subject
            CxTxnsUpdater cx = new CxTxnsUpdater(clientSrvc, logger);

            // test the method
            Test.startTest();
            cx.updateActivities(activities, DateTime.now());
            Test.stopTest();

            // verify bank deposit created
            List<Bank_Deposit__c> bankDeposits = [SELECT Id, Merchant_Batch_Id__c, Amount__c, Ledger_Amount__c,Deposit_Date__c FROM Bank_Deposit__c ORDER BY Merchant_Batch_Id__c ASC];
            Assert.areEqual(3, bankDeposits.size());
            Assert.areEqual(reportItem1.xBatch, bankDeposits[0].Merchant_Batch_Id__c);
            Assert.areEqual(400.00, bankDeposits[0].Amount__c);
            Assert.areEqual(bankDeposits[0].Amount__c, bankDeposits[0].Ledger_Amount__c);
            Assert.areEqual(reportItem1.xBatchDateTimeUTC().dateGMT(), bankDeposits[0].Deposit_Date__c);
            Assert.areEqual(reportItem2.xBatch, bankDeposits[1].Merchant_Batch_Id__c);
            Assert.areEqual(200.00, bankDeposits[1].Amount__c);
            Assert.areEqual(bankDeposits[1].Amount__c, bankDeposits[1].Ledger_Amount__c);
            Assert.areEqual(reportItem2.xBatchDateTimeUTC().dateGMT(), bankDeposits[1].Deposit_Date__c);
            Assert.areEqual(reportItem3.xBatch, bankDeposits[2].Merchant_Batch_Id__c);
            Assert.areEqual(200.00, bankDeposits[2].Amount__c);
            Assert.areEqual(bankDeposits[2].Amount__c, bankDeposits[2].Ledger_Amount__c);
            Assert.areEqual(reportItem3.xBatchDateTimeUTC().dateGMT(), bankDeposits[2].Deposit_Date__c);

            // make sure all the cash receipts gets their bank deposit
            Assert.areEqual(3, [SELECT count() FROM Cash_Receipt__c WHERE Bank_Deposit__c IN :bankDeposits]);
            
            // make sure no payment activities are returned 
            Assert.areEqual(0, getPaymentActivities(new Set<Id>{processor.Id}, new Set<String>()).size());

            // there should be 3 payment activities
            Assert.areEqual(3, [SELECT Id FROM Payment_Activity__c].size());
        }
    }

    @IsTest
    static void testUpdateActivitiesDepositCorrect() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .createPaymentProcessors()
            .createCashReceipts();
        
        System.runAs(testData.users.get(1)) {
            CardknoxService.BatchReport report = getBatchReport();

            Payment_Processor__c processor = testData.paymentProcessors[2];

            Payment_Processor_Customer__c customer = getPaymentProcessorCustomer(testData.accounts[1].Id, processor.Id);
            insert customer;

            Payment_Method__c paymentMethod = getPaymentMethod(customer.Account__c, processor.Id);
            insert paymentMethod;

            Cash_Receipt__c cashReceipt = testData.cashReceipts[0];
            cashReceipt.Payment_Reference__c = '1234567890';
            cashReceipt.Payment_Processor__c = processor.Id;
            cashReceipt.Amount__c = Decimal.valueOf(report.xReportData[0].xTotalAmount);
            cashReceipt.Account__c = customer.Account__c;
            update cashReceipt;

            Payment_Activity__c paymentActivity = getPaymentActivity(paymentMethod, cashReceipt);
            paymentActivity.Merchant_Batch_Id__c = report.xReportData[0].xBatch;
            insert paymentActivity;

            List<Payment_Activity__c> activities = getPaymentActivities(new Set<Id>{processor.Id}, new Set<String>());

            Test.startTest();

            // create mock services
            GenericMock mockSrvc = new GenericMock();
            mockSrvc.registerResponse('getTransactionBatchReport', report);
            CxClient clientSrvc = (CxClient) Test.createStub(CxClient.class, mockSrvc);        

            CxAJRLogger logger = new CxAJRLogger();
            // initialize test subject
            CxTxnsUpdater cx = new CxTxnsUpdater(clientSrvc, logger);
            // run test
            CxTxnsUpdater.ProcessedBankDeposits results = cx.updateActivities(activities, DateTime.now());

            // verify first run resutls
            Assert.areEqual(1, results.successfulBDIds.size());
            Assert.isTrue(results.failedBDIds.isEmpty());
            List<Bank_Deposit__c> deposits = [SELECT Id, Amount__c, Ledger_Amount__c FROM Bank_Deposit__c WHERE Id IN :results.successfulBDIds];
            Assert.areEqual(1, deposits.size());
            Assert.areEqual(cashReceipt.Amount__c, deposits[0].Amount__c);
            Assert.areEqual(deposits[0].Amount__c, deposits[0].Ledger_Amount__c);

            // add more records and test bank deposit correctly updated

            // insert more records for the same cx batch
            cashReceipt = cashReceipt.clone(false,true,false,false);
            cashReceipt.Payment_Reference__c = report.xReportData[0].xBatch;
            cashReceipt.Payment_Processor__c = processor.Id;
            cashReceipt.Amount__c = decimal.valueOf(report.xReportData[0].xTotalAmount);
            cashReceipt.Account__c = customer.Account__c;
            insert cashReceipt;

            paymentActivity = getPaymentActivity(paymentMethod, cashReceipt);
            paymentActivity.Merchant_Batch_Id__c = report.xReportData[0].xBatch;
            insert paymentActivity;

            activities = getPaymentActivities(new Set<Id>{processor.Id}, new Set<String>());

            // create mock services
            mockSrvc = new GenericMock();
            mockSrvc.registerResponse('getTransactionBatchReport', report);
            clientSrvc = (CxClient) Test.createStub(CxClient.class, mockSrvc);     

            // initialize test subject
            cx = new CxTxnsUpdater(clientSrvc, logger);
            // run test

            // verify 2nd run results
            results = cx.updateActivities(activities, DateTime.now());
            Assert.areEqual(1, results.successfulBDIds.size());
            Assert.isTrue(results.failedBDIds.isEmpty());
            deposits = [SELECT Id, Amount__c, Ledger_Amount__c FROM Bank_Deposit__c WHERE Id IN :results.successfulBDIds];
            Assert.areEqual(1, deposits.size());
            Assert.areEqual(cashReceipt.Amount__c * 2, deposits[0].Amount__c);
            Assert.areEqual(deposits[0].Amount__c, deposits[0].Ledger_Amount__c);

            Test.stopTest();
        }
    }

    @IsTest
    static void testUpdateActivitiesMultipleRuns() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .createPaymentProcessors()
            .createCashReceipts();
        
        System.runAs(testData.users.get(1)) {
            CardknoxService.BatchReport report = getBatchReport();

            Payment_Processor__c processor = testData.paymentProcessors[2];

            Payment_Processor_Customer__c customer = getPaymentProcessorCustomer(testData.accounts[1].Id, processor.Id);
            insert customer;

            Payment_Method__c paymentMethod = getPaymentMethod(customer.Account__c, processor.Id);
            insert paymentMethod;

            Cash_Receipt__c cashReceipt = testData.cashReceipts[0];
            cashReceipt.Payment_Reference__c = '1234567890';
            cashReceipt.Payment_Processor__c = processor.Id;
            cashReceipt.Amount__c = decimal.valueOf(report.xReportData[0].xTotalAmount);
            cashReceipt.Account__c = customer.Account__c;
            update cashReceipt;

            Payment_Activity__c paymentActivity = getPaymentActivity(paymentMethod, cashReceipt);
            paymentActivity.Merchant_Batch_Id__c = report.xReportData[0].xBatch;
            insert paymentActivity;

            List<Payment_Activity__c> activities = getPaymentActivities(new Set<Id>{processor.Id}, new Set<String>());

            Test.startTest();

            // create mock services
            GenericMock mockSrvc = new GenericMock();
            mockSrvc.registerResponse('getTransactionBatchReport', report);
            CxClient clientSrvc = (CxClient) Test.createStub(CxClient.class, mockSrvc);     

            CxAJRLogger logger = new CxAJRLogger();
            // initialize test subject
            CxTxnsUpdater cx = new CxTxnsUpdater(clientSrvc, logger);
            // run test
            CxTxnsUpdater.ProcessedBankDeposits results = cx.updateActivities(activities, DateTime.now());

            // verify first run resutls
            Assert.areEqual(1, results.successfulBDIds.size());
            Assert.isTrue(results.failedBDIds.isEmpty());
            List<Bank_Deposit__c> deposits = [SELECT Id, Amount__c, Ledger_Amount__c FROM Bank_Deposit__c];
            Assert.areEqual(1, deposits.size());
            Assert.areEqual(cashReceipt.Amount__c, deposits[0].Amount__c);
            Assert.areEqual(deposits[0].Amount__c, deposits[0].Ledger_Amount__c);

            // re-run with same data, results should be the same

            // get updated payment activity
            activities = getPaymentActivities(new Set<Id>{processor.Id}, new Set<String>());

            // create mock services
            mockSrvc = new GenericMock();
            mockSrvc.registerResponse('getTransactionBatchReport', report);
            clientSrvc = (CxClient) Test.createStub(CxClient.class, mockSrvc); 

            // initialize test subject
            cx = new CxTxnsUpdater(clientSrvc, logger);
            // run test
            results = cx.updateActivities(activities, DateTime.now());

            // verify first run resutls
            Assert.isTrue(results.successfulBDIds.isEmpty());
            Assert.isTrue(results.failedBDIds.isEmpty());
            deposits = [SELECT Id, Amount__c, Ledger_Amount__c FROM Bank_Deposit__c];
            Assert.areEqual(1, deposits.size());
            Assert.areEqual(cashReceipt.Amount__c, deposits[0].Amount__c);
            Assert.areEqual(deposits[0].Amount__c, deposits[0].Ledger_Amount__c);

            Test.stopTest();
        }
    }

    @IsTest
    static void testUpdateActivitiesMultiProcessor() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .createPaymentProcessors()
            .createCashReceipts();
        
        System.runAs(testData.users.get(1)) {
            CardknoxService.BatchReport report1 = getBatchReport();
            CardknoxService.BatchReport report2 = getBatchReport();

            Payment_Processor__c processor1 = testData.paymentProcessors[2];
            Payment_Processor__c processor2 = testData.paymentProcessors[3];

            Payment_Processor_Customer__c customer1 = getPaymentProcessorCustomer(testData.accounts[1].Id, processor1.Id);
            Payment_Processor_Customer__c customer2 = getPaymentProcessorCustomer(testData.accounts[1].Id, processor2.Id);
            
            insert new List<Payment_Processor_Customer__c>{customer1, customer2};

            Payment_Method__c paymentMethod1 = getPaymentMethod(customer1.Account__c, processor1.Id);
            Payment_Method__c paymentMethod2 = getPaymentMethod(customer2.Account__c, processor2.Id);
            
            insert paymentMethod1;
            insert paymentMethod2;

            Cash_Receipt__c cashReceipt1 = testData.cashReceipts[0].clone(false,true,false,false);
            cashReceipt1.Payment_Reference__c = '1234567890';
            cashReceipt1.Payment_Processor__c = processor1.Id;
            cashReceipt1.Amount__c = Decimal.valueOf(report1.xReportData[0].xTotalAmount);
            cashReceipt1.Account__c = customer1.Account__c;

            Cash_Receipt__c cashReceipt2 = testData.cashReceipts[0].clone(false,true,false,false);
            cashReceipt2.Payment_Reference__c = '1234567891';
            cashReceipt2.Payment_Processor__c = processor2.Id;
            cashReceipt2.Amount__c = Decimal.valueOf(report2.xReportData[0].xTotalAmount);
            cashReceipt2.Account__c = customer2.Account__c;

            insert new List<Cash_Receipt__c>{cashReceipt1, cashReceipt2};

            Payment_Activity__c paymentActivity1 = getPaymentActivity(paymentMethod1, cashReceipt1);
            paymentActivity1.Merchant_Batch_Id__c = report1.xReportData[0].xBatch;
            paymentActivity1.Payment_Date__c = System.now().addDays(-1);
            Payment_Activity__c paymentActivity2 = getPaymentActivity(paymentMethod2, cashReceipt2);
            paymentActivity2.Merchant_Batch_Id__c = report2.xReportData[0].xBatch;
            paymentActivity1.Payment_Date__c = System.now().addDays(-3);

            insert new List<Payment_Activity__c>{paymentActivity1, paymentActivity2};

            List<Payment_Activity__c> activities = getPaymentActivities(new Set<Id>{processor1.Id, processor2.Id}, new Set<String>());

            Test.startTest();

            // create mock services
            GenericMock mockSrvc = new GenericMock();
            mockSrvc.registerResponse('getTransactionBatchReport', report1); // processor 1 callout
            mockSrvc.registerResponse('getTransactionBatchReport', report2); // processor 2 callout
            CxClient clientSrvc = (CxClient) Test.createStub(CxClient.class, mockSrvc);      

            CxAJRLogger logger = new CxAJRLogger();
            // initialize test subject
            CxTxnsUpdater cx = new CxTxnsUpdater(clientSrvc, logger);
            // run test
            CxTxnsUpdater.ProcessedBankDeposits results = cx.updateActivities(activities, DateTime.now());

            // verify resutls
            Assert.areEqual(2, results.successfulBDIds.size());
            Assert.isTrue(results.failedBDIds.isEmpty());
            List<Bank_Deposit__c> deposits = [SELECT Id, Amount__c, Ledger_Amount__c, Merchant_Batch_Id__c, Bank_Account__c FROM Bank_Deposit__c WHERE Id IN :results.successfulBDIds];
            Assert.areEqual(2, deposits.size());
            for (Bank_Deposit__c deposit : deposits) {
                if (report1.xReportData[0].xBatch == deposit.Merchant_Batch_Id__c) {
                    Assert.areEqual(cashReceipt1.Amount__c, deposit.Ledger_Amount__c);
                    Assert.areEqual(deposit.Amount__c, deposit.Ledger_Amount__c);
                    Assert.areEqual(processor1.Merchant_GL_Account__c, deposit.Bank_Account__c);
                } else if (report2.xReportData[0].xBatch == deposit.Merchant_Batch_Id__c) {
                    Assert.areEqual(cashReceipt2.Amount__c, deposit.Ledger_Amount__c);
                    Assert.areEqual(deposit.Amount__c, deposit.Ledger_Amount__c);
                    Assert.areEqual(processor2.Merchant_GL_Account__c, deposit.Bank_Account__c);
                } else {
                    Assert.fail('unexpected merchant batch id');
                }
            }

            Test.stopTest();
        }
    }

    @IsTest
    static void testUpdateActivitiesMultiLedger() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .createPaymentProcessors()
            .createCashReceipts();
        
        System.runAs(testData.users.get(1)) {
            CardknoxService.BatchReport report = getBatchReport();

            Payment_Processor__c processor = testData.paymentProcessors[2];

            Payment_Processor_Customer__c customer = getPaymentProcessorCustomer(testData.accounts[1].Id, processor.Id);
            insert customer;

            Payment_Method__c paymentMethod = getPaymentMethod(customer.Account__c, processor.Id);
            insert paymentMethod;

            Cash_Receipt__c cashReceipt1 = testData.cashReceipts[0].clone(false,true,false,false);
            cashReceipt1.Payment_Reference__c = '1234567890';
            cashReceipt1.Payment_Processor__c = processor.Id;
            cashReceipt1.Amount__c = decimal.valueOf(report.xReportData[0].xTotalAmount);
            cashReceipt1.Account__c = customer.Account__c;
            cashReceipt1.Ledger__c = testData.ledgers[0].Id;

            Cash_Receipt__c cashReceipt2 = cashReceipt1.clone(false,true,false,false);
            cashReceipt2.Payment_Reference__c = '1234567891';
            cashReceipt2.Ledger__c = testData.ledgers[2].Id;

            insert new List<Cash_Receipt__c>{cashReceipt1, cashReceipt2};

            Payment_Activity__c paymentActivity1 = getPaymentActivity(paymentMethod, cashReceipt1);
            paymentActivity1.Merchant_Batch_Id__c = report.xReportData[0].xBatch;

            Payment_Activity__c paymentActivity2 = getPaymentActivity(paymentMethod, cashReceipt2);
            paymentActivity2.Merchant_Batch_Id__c = report.xReportData[0].xBatch;

            insert new List<Payment_Activity__c>{paymentActivity1, paymentActivity2};

            List<Payment_Activity__c> activities = getPaymentActivities(new Set<Id>{processor.Id}, new Set<String>());

            Test.startTest();

            // create mock services
            GenericMock mockSrvc = new GenericMock();
            mockSrvc.registerResponse('getTransactionBatchReport', report);
            CxClient clientSrvc = (CxClient) Test.createStub(CxClient.class, mockSrvc);

            CxAJRLogger logger = new CxAJRLogger();
            // initialize test subject
            CxTxnsUpdater cx = new CxTxnsUpdater(clientSrvc, logger);
            // run test
            CxTxnsUpdater.ProcessedBankDeposits results = cx.updateActivities(activities, DateTime.now());

            // verify first run resutls
            Assert.areEqual(2, results.successfulBDIds.size());
            Assert.isTrue(results.failedBDIds.isEmpty());
            List<Bank_Deposit__c> deposits = [SELECT Id, Amount__c, Ledger_Amount__c, Ledger__c, Bank_Account__c FROM Bank_Deposit__c WHERE Id IN :results.successfulBDIds];
            Assert.areEqual(2, deposits.size());
            for (Bank_Deposit__c deposit : deposits) {
                Assert.areEqual(deposit.Bank_Account__c, processor.Merchant_GL_Account__c);
                if (deposit.Ledger__c == cashReceipt1.Ledger__c) {
                    Assert.areEqual(cashReceipt1.Amount__c, deposit.Ledger_Amount__c);
                    Assert.areEqual(deposit.Amount__c, deposit.Ledger_Amount__c);
                } else if (deposit.Ledger__c == cashReceipt2.Ledger__c) {
                    Assert.areEqual(cashReceipt2.Amount__c, deposit.Ledger_Amount__c);
                    Assert.areEqual(deposit.Amount__c, deposit.Ledger_Amount__c);
                } else {
                    Assert.fail('unexpected ledger');
                }
            }

            Test.stopTest();
        }
    }

    @IsTest
    static void testUpdateActivitiesMultiCurrencyRestrictions() {
        TestDataSuite testData = TestDataSuite.getInstance();

        try {
            testData.enableMultiCurrency();
            MultiCurrencyHandler.isMultiCurrencyEnabled = true;
        } catch (TestDataSuite.TestDataSuiteException e) {
            // MC not enabled for org
            return;
        }

        testData.disableAutoPostSourceDocuments()
            .createPaymentProcessors()
            .createCashReceipts();
        
        System.runAs(testData.users.get(1)) {
            String ledgerCurrency = LedgerHandler.getLedgerCurrency(testData.ledgers[0].Id);
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

            CardknoxService.BatchReport report = getBatchReport();

            Payment_Processor__c processor = testData.paymentProcessors[2];

            Payment_Processor_Customer__c customer = getPaymentProcessorCustomer(testData.accounts[1].Id, processor.Id);
            insert customer;

            Payment_Method__c paymentMethod = getPaymentMethod(customer.Account__c, processor.Id);
            insert paymentMethod;

            Cash_Receipt__c cashReceipt = testData.cashReceipts[0];
            cashReceipt.Payment_Reference__c = '1234567890';
            cashReceipt.Payment_Processor__c = processor.Id;
            cashReceipt.Amount__c = decimal.valueOf(report.xReportData[0].xTotalAmount);
            cashReceipt.Account__c = customer.Account__c;
            cashReceipt.Ledger__c = testData.ledgers[0].Id;
            cashReceipt.put('CurrencyIsoCode', nonLedgerCurrency);
            update cashReceipt;

            Payment_Activity__c paymentActivity = getPaymentActivity(paymentMethod, cashReceipt);
            paymentActivity.Merchant_Batch_Id__c = report.xReportData[0].xBatch;
            paymentActivity.put('CurrencyIsoCode', nonLedgerCurrency);
            insert paymentActivity;

            List<Payment_Activity__c> activities = getPaymentActivities(new Set<Id>{processor.Id}, new Set<String>());

            Test.startTest();

            // create mock services
            GenericMock mockSrvc = new GenericMock();
            mockSrvc.registerResponse('getTransactionBatchReport', report);
            CxClient clientSrvc = (CxClient) Test.createStub(CxClient.class, mockSrvc);

            CxAJRLogger logger = new CxAJRLogger();
            // initialize test subject
            CxTxnsUpdater cx = new CxTxnsUpdater(clientSrvc, logger);
            // run test
            CxTxnsUpdater.ProcessedBankDeposits results = cx.updateActivities(activities, DateTime.now());

            // verify first run resutls
            Assert.isTrue(results.successfulBDIds.isEmpty());
            Assert.isTrue(results.failedBDIds.isEmpty());
            List<Bank_Deposit__c> deposits = [SELECT Id, Amount__c, Ledger_Amount__c FROM Bank_Deposit__c];
            Assert.isTrue(deposits.isEmpty());

            Test.stopTest();
        }
    }

    @IsTest
    static void testGetEarliestPaymentDate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .createPaymentProcessors()
            .createCashReceipts();
    
        System.runAs(testData.users.get(1)) {
            Payment_Processor__c processor = testData.paymentProcessors[2];

            Payment_Processor_Customer__c customer = new Payment_Processor_Customer__c(
                Account__c = testData.accounts.get(1).Id, 
                Processor__c = processor.Id, 
                External_Id__c = '123'
            );
            insert customer;

            Payment_Method__c paymentMethod = new Payment_Method__c(
                Customer__c = customer.Account__c, 
                Payment_Processor__c = processor.Id, 
                External_Id__c = '123',
                Last_Four_Digits__c = '4242',
                Payment_Method_Type__c = 'Credit Card', 
                Status__c = 'Active',
                Expiration_Month__c = '12',
                Expiration_Year__c = '2224',
                Type__c = 'Visa',
                Default__c = true
            );
            insert paymentMethod;

            List<Cash_Receipt__c> cashReceipts = new List<Cash_Receipt__c>{
                new Cash_Receipt__c(
                    Account__c = customer.Account__c,
                    Credit_GL_Account__c = testData.glAccounts[1].Id,
                    Amount__c = 400,
                    Status__c = 'Approved',
                    Receipt_Date__c = Date.newInstance(2023,2,2),
                    Purpose__c = 'Customer Receipt',
                    Payment_Reference__c = '123456789',
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Payment_Processor__c = processor.Id
                ),
                new Cash_Receipt__c(
                    Account__c = customer.Account__c,
                    Credit_GL_Account__c = testData.glAccounts[1].Id,
                    Amount__c = 400,
                    Status__c = 'Approved',
                    Receipt_Date__c = Date.newInstance(2023,1,1),
                    Purpose__c = 'Customer Receipt',
                    Payment_Reference__c = '123456789',
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Payment_Processor__c = processor.Id
                )
            };
            insert cashReceipts;

            List<Payment_Activity__c> paymentActivities = new List<Payment_Activity__c> {
                new Payment_Activity__c(
                    Type__c = PaymentActivityHelper.PAYMENT_TYPE,
                    Status__c = PaymentActivityHelper.PENDING_STATUS,
                    Amount__c = 9.99,
                    Payment_Method__c = paymentMethod.Id,
                    Cash_Receipt__c = cashReceipts[0].Id,
                    Merchant_Reference__c = cashReceipts[0].Payment_Reference__c,
                    Merchant_Batch_Id__c = '123',
                    Payment_Date__c = Date.newInstance(2023,2,2)
                ),
                new Payment_Activity__c(
                    Type__c = PaymentActivityHelper.PAYMENT_TYPE,
                    Status__c = PaymentActivityHelper.PENDING_STATUS,
                    Amount__c = 9.99,
                    Payment_Method__c = paymentMethod.Id,
                    Cash_Receipt__c = cashReceipts[1].Id,
                    Merchant_Reference__c = cashReceipts[1].Payment_Reference__c,
                    Merchant_Batch_Id__c = '321'
                )
            };
            insert paymentActivities;

            paymentActivities[1].Payment_Date__c = null;
            update paymentActivities[1];

            List<Payment_Activity__c> activities = getPaymentActivities(new Set<Id>{testData.paymentProcessors[2].Id}, new Set<String>());

            Test.startTest();
            DateTime earliest = CxTxnsUpdater.getEarliestPaymentDate(activities);
            Test.stopTest();

            Assert.areEqual(cashReceipts[1].Receipt_Date__c, earliest);
        }

    }

    private static List<Payment_Activity__c> getPaymentActivities(Set<Id> processorIds, Set<String> excludeMerchantBatchIds) {
        Database.QueryLocator loc = DomainUtils.getQueryLocatorForCxTxnsUpdateBatch(Date.newInstance(3000,01,01), processorIds, excludeMerchantBatchIds);
        Database.QueryLocatorIterator itr = loc.iterator();
        List<Payment_Activity__c> activities = new List<Payment_Activity__c>();
        Integer breaker = 0; // infinite loop safety
        while (itr.hasNext() && breaker < 100) {
            activities.add((Payment_Activity__c)itr.next());
            breaker++;
        }
        return activities;
    }    

    private static Payment_Processor_Customer__c getPaymentProcessorCustomer(Id customer, Id processor) {
        return new Payment_Processor_Customer__c(
            Account__c = customer, 
            Processor__c = processor, 
            External_Id__c = customer + '' + processor
        );
    }

    private static Payment_Method__c getPaymentMethod(Id customer, Id processor) {
        return new Payment_Method__c(
            Customer__c = customer, 
            Payment_Processor__c = processor, 
            External_Id__c = customer + '' + processor,
            Last_Four_Digits__c = '4242',
            Payment_Method_Type__c = 'Credit Card', 
            Status__c = 'Active',
            Expiration_Month__c = '12',
            Expiration_Year__c = '2224',
            Type__c = 'Visa',
            Default__c = true
        );
    }

    private static Payment_Activity__c getPaymentActivity(Payment_Method__c pm, Cash_Receipt__c cr) {
        return new Payment_Activity__c(
            Type__c = PaymentActivityHelper.PAYMENT_TYPE,
            Status__c = PaymentActivityHelper.PENDING_STATUS,
            Amount__c = cr.Amount__c,
            Fee__c = (cr.Amount__c * 0.018).setScale(2, System.RoundingMode.HALF_UP),
            Payment_Method__c = pm.Id,
            Cash_Receipt__c = cr.Id,
            Merchant_Reference__c = cr.Payment_Reference__c
        );
    }

    private static CardknoxService.BatchReport getBatchReport() {
        // batch report item / 1 batch
        CardknoxService.BatchReportData reportItem = new CardknoxService.BatchReportData();
        reportItem.xBatch = String.valueof(Integer.valueOf((Math.random() * 10000000)));
        reportItem.xBatchDate = '5/1/2023';
        reportItem.xBatchTime = '12:00:45 PM';
        reportItem.xTotalCount = '1';
        reportItem.xTotalAmount = '101.01';
        reportItem.xSaleCount = '1';
        reportItem.xSaleAmount = '101.01';
        reportItem.xVisaSaleCount = '1';
        reportItem.xVisaSaleAmount = '101.01';
        reportItem.xMCSaleCount = '';
        reportItem.xMCSaleAmount = '';
        reportItem.xAchSaleCount = '';
        reportItem.xAchSaleAmount = '';

        // batch report with 1 batch
        List<CardknoxService.BatchReportData> reportData = new List<CardknoxService.BatchReportData>{ reportItem };

        // report header
        CardknoxService.BatchReport report = new CardknoxService.BatchReport();
        report.xReportData = reportData;
        report.xResult = 'S';
        report.xStatus = 'Success';
        report.xError = '';
        report.xErrorCode = '00000';
        report.xRefNum = String.valueof(Integer.valueOf((Math.random() * 10000000)));
        report.xAvsResultCode = '';
        report.xAvsResult = 'Unmapped AVS response';
        report.xCvvResultCode = '';
        report.xCvvResult = 'No CVV data available';
        report.xRecordsReturned = String.valueOf(reportData.size());
        report.xAdditionalData = '';
        report.xDate = '5/1/2023 4:15:35 PM';

        return report;
    }

    private static List<CxTxnsUpdater.DateRange> runDateRangeIterator(CxTxnsUpdater.DateRange range, Integer step) {
        // create the iterator
        Iterator<CxTxnsUpdater.DateRange> itr = range.iterator(step);

        List<CxTxnsUpdater.DateRange> windows = new List<CxTxnsUpdater.DateRange>();
        Integer breaker = 50; // break after 50 iterations to avoid any infinite loops
        // iteratbe until end
        while (itr.hasNext()) {
            windows.add(itr.next());
            if (breaker == 0) {
                Assert.fail('infinite loop detected, breaking');
            }
            breaker--;
        }

        return windows;
    }
}