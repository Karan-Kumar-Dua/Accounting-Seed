@IsTest
public with sharing class CxTxnsUpdateBatchTest {
    @TestSetup
    static void setupTestData(){
        TestDataSuite testData = TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testCxTxnsUpdateBatchSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            HttpCalloutMock multiCalloutMockInstance = createResponseGeneratorSuccessOneRecord();
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            Payment_Processor__c pp = testData.paymentProcessors[2];

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(
                Account__c = testData.accounts.get(1).Id, 
                Processor__c = pp.Id, 
                External_Id__c='123'
            );
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(
                Customer__c = testData.accounts.get(1).Id, 
                Payment_Processor__c = pp.Id, 
                External_Id__c = '123',        
                Last_Four_Digits__c = '4242',
                Payment_Method_Type__c = 'Credit Card',
                Status__c = 'Active',
                Expiration_Month__c = '12',
                Expiration_Year__c = '2224',
                Type__c = 'Visa',
                Default__c = true
            );
            INSERT pm;

            Cash_Receipt__c cReciept = new Cash_Receipt__c(
                Account__c = testData.accounts.get(1).Id,
                Credit_GL_Account__c = testData.glAccounts[1].Id,
                Amount__c = 400,
                Status__c = 'Approved',
                Receipt_Date__c = Date.newInstance(2023,4,28),
                Purpose__c = 'Customer Receipt',
                Payment_Reference__c = '1234',
                Accounting_Period__c = testData.acctPeriods.get(0).Id,
                Payment_Processor__c = testData.paymentProcessors[2].Id
            );
            INSERT cReciept;

            Payment_Activity__c pa = new Payment_Activity__c(
                Type__c = 'Payment',
                Status__c = 'Pending',
                Amount__c = cReciept.Amount__c,
                Payment_Method__c = pm.Id,
                Cash_Receipt__c = cReciept.Id,
                Merchant_Reference__c = cReciept.Payment_Reference__c,
                Merchant_Batch_Id__c = '77377',
                Payment_Date__c = System.now().addDays(-1)
            );
            INSERT pa;

            Test.startTest();
            Database.executeBatch(new CxTxnsUpdateBatch(System.now(),new Set<Id> {pp.Id}, new Set<String>(), new CxAJRLogger()), 200);
            Test.stopTest();

            List<Bank_Deposit__c> bankDeposits = [SELECT Id, Bank_Account__c, Merchant_Batch_Id__c, Amount__c FROM Bank_Deposit__c];
            List<Payment_Activity__c> paymentActivities = [SELECT Id, Merchant_Reference__c, Merchant_Batch_Id__c FROM Payment_Activity__c];

            System.assert(!bankDeposits.isEmpty());
            System.assertEquals(pp.Merchant_GL_Account__c, bankDeposits[0].Bank_Account__c);
            System.assertEquals('77377', bankDeposits[0].Merchant_Batch_Id__c);
            System.assert(!paymentActivities.isEmpty());
            System.assertEquals('1234', paymentActivities[0].Merchant_Reference__c);
            System.assertEquals('77377', paymentActivities[0].Merchant_Batch_Id__c);
            System.assertEquals([SELECT Id,Bank_Deposit__c FROM Cash_Receipt__c][0].Bank_Deposit__c, bankDeposits[0].Id);
            System.assertEquals(400, bankDeposits[0].Amount__c);
        }
    }
    @IsTest
    public static void testCxTxnsUpdateBatchSuccessWithTwoCR() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            HttpCalloutMock multiCalloutMockInstance = createResponseGeneratorSuccess();
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

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

            List<Cash_Receipt__c> cashReceipts = new List<Cash_Receipt__c>();

            cashReceipts.add(new Cash_Receipt__c(
                Account__c = customer.Account__c,
                Credit_GL_Account__c = testData.glAccounts[1].Id,
                Amount__c = 400,
                Status__c = 'Approved',
                Receipt_Date__c = System.today(),
                Purpose__c = 'Customer Receipt',
                Payment_Reference__c = '1234',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Payment_Processor__c = processor.Id,
                Ledger__c = testData.ledgers[0].Id
            ));
            cashReceipts.add(new Cash_Receipt__c(
                Account__c = customer.Account__c,
                Credit_GL_Account__c = testData.glAccounts[1].Id,
                Amount__c = 200,
                Status__c = 'Approved',
                Purpose__c = 'Customer Receipt',
                Payment_Reference__c = '1235',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Payment_Processor__c = processor.Id,
                Ledger__c = testData.ledgers[2].Id
            ));

            insert cashReceipts;

            Payment_Activity__c paymentActivity1 = new Payment_Activity__c(
                Type__c = PaymentActivityHelper.PAYMENT_TYPE,
                Status__c = PaymentActivityHelper.PENDING_STATUS,
                Amount__c = 9.99,
                Payment_Method__c = paymentMethod.Id,
                Cash_Receipt__c = cashReceipts[0].Id,
                Merchant_Reference__c = '1234',
                Merchant_Batch_Id__c = '18500580'
            );
            Payment_Activity__c paymentActivity2 = new Payment_Activity__c(
                Type__c = PaymentActivityHelper.PAYMENT_TYPE,
                Status__c = PaymentActivityHelper.PENDING_STATUS,
                Amount__c = 9.99,
                Payment_Method__c = paymentMethod.Id,
                Cash_Receipt__c = cashReceipts[1].Id,
                Merchant_Reference__c = '1235',
                Merchant_Batch_Id__c = '18500581',
                Payment_Date__c = System.now().addDays(-1)
            );
        
            insert new List<Payment_Activity__c>{paymentActivity1,paymentActivity2};

            Test.startTest();
            Database.executeBatch(new CxTxnsUpdateBatch(System.now(),new Set<Id> {processor.Id}, new Set<String>(), new CxAJRLogger()), 200);
            Test.stopTest();

            // verify bank deposit created
            List<Bank_Deposit__c> bankDeposits = [SELECT Id, Merchant_Batch_Id__c, Amount__c, Ledger_Amount__c,Deposit_Date__c FROM Bank_Deposit__c];

            Assert.areEqual(2, [SELECT count() FROM Cash_Receipt__c WHERE Bank_Deposit__c IN :bankDeposits]);
            Assert.areEqual('18500580',[SELECT Id,Merchant_Batch_Id__c FROM Bank_Deposit__c][0].Merchant_Batch_Id__c);
            Assert.areEqual('18500581',[SELECT Id,Merchant_Batch_Id__c FROM Bank_Deposit__c][1].Merchant_Batch_Id__c);
            Assert.areEqual('1234',[SELECT Id,Merchant_Reference__c FROM Payment_Activity__c][0].Merchant_Reference__c);
            Assert.areEqual('1235',[SELECT Id,Merchant_Reference__c FROM Payment_Activity__c][1].Merchant_Reference__c);
            Assert.areEqual('18500580',[SELECT Id,Merchant_Batch_Id__c FROM Payment_Activity__c][0].Merchant_Batch_Id__c);
            Assert.areEqual('18500581',[SELECT Id,Merchant_Batch_Id__c FROM Payment_Activity__c][1].Merchant_Batch_Id__c);
            Assert.areEqual([SELECT Id,Bank_Deposit__c FROM Cash_Receipt__c][0].Bank_Deposit__c,
                                [SELECT Id,Merchant_Batch_Id__c FROM Bank_Deposit__c][0].Id);
            Assert.areEqual([SELECT Id,Bank_Deposit__c FROM Cash_Receipt__c][1].Bank_Deposit__c,
                                [SELECT Id,Merchant_Batch_Id__c FROM Bank_Deposit__c][1].Id);
            Assert.areEqual(400,[SELECT Id,Amount__c FROM Bank_Deposit__c][0].Amount__c);
            Assert.areEqual(200,[SELECT Id,Amount__c FROM Bank_Deposit__c][1].Amount__c);
            Assert.areEqual(400,[SELECT Id,Ledger_Amount__c FROM Bank_Deposit__c][0].Ledger_Amount__c);
            Assert.areEqual(200,[SELECT Id,Ledger_Amount__c FROM Bank_Deposit__c][1].Ledger_Amount__c);
            Assert.areEqual(testData.ledgers[0].Id,[SELECT Id,Ledger__c FROM Bank_Deposit__c][0].Ledger__c);
            Assert.areEqual(testData.ledgers[2].Id,[SELECT Id,Ledger__c FROM Bank_Deposit__c][1].Ledger__c);
        }
    }
    @IsTest
    public static void testCxTxnsUpdateBatchSuccessWithUpdateDeposit() {
        HttpCalloutMock multiCalloutMockInstance = createResponseGeneratorSuccessOneRecord();
        Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors().createBankDeposits();

        System.runAs(testData.users.get(1)) {
            Bank_Deposit__c deposit = testData.bankDeposits[0];
            deposit.Merchant_Batch_Id__c = '77377';
            deposit.Amount__c = 200;
            deposit.Deposit_Date__c = System.today();
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c, Bank_Deposit__c.Deposit_Date__c});
            UPDATE deposit;
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c, Bank_Deposit__c.Deposit_Date__c});

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(
                Account__c = testData.accounts.get(1).Id, 
                Processor__c = testData.paymentProcessors[2].Id, 
                External_Id__c = '123'
            );
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(
                Customer__c = testData.accounts.get(1).Id, 
                Payment_Processor__c = testData.paymentProcessors[2].Id, 
                External_Id__c ='123',
                Last_Four_Digits__c = '4242',
                Payment_Method_Type__c = 'Credit Card', 
                Status__c = 'Active',
                Expiration_Month__c = '12',
                Expiration_Year__c = '2224',
                Type__c = 'Visa',
                Default__c = true
            );
            INSERT pm;

            Cash_Receipt__c cReciept = new Cash_Receipt__c(
                Account__c = testData.accounts.get(1).Id,
                Credit_GL_Account__c = testData.glAccounts[1].Id,
                Amount__c = 400,
                Status__c = 'Approved',
                Purpose__c = 'Customer Receipt',
                Payment_Reference__c = '1234',
                Accounting_Period__c = testData.acctPeriods.get(0).Id,
                Payment_Processor__c = testData.paymentProcessors[2].Id
            );
            INSERT cReciept;

            Payment_Activity__c pa = new Payment_Activity__c(
                Type__c = 'Payment',
                Status__c = 'Pending',
                Amount__c = 1,
                Payment_Method__c = pm.Id,
                Cash_Receipt__c = cReciept.Id, 
                Merchant_Batch_Id__c = '77377',
                Merchant_Reference__c = '1234',
                Payment_Date__c = System.now().addDays(-5)
            );
            INSERT pa;
            
            Test.startTest();
            Database.executeBatch(new CxTxnsUpdateBatch(System.now(), new Set<Id> {testData.paymentProcessors[2].Id}, new Set<String>(), new CxAJRLogger()), 200);
            Test.stopTest();
            
            List<Payment_Activity__c> activityResults = [SELECT Id, Merchant_Reference__c, Merchant_Batch_Id__c FROM Payment_Activity__c];
            List<Bank_Deposit__c> depositResults = [SELECT Id, Merchant_Batch_Id__c, Amount__c, Ledger_Amount__c, Ledger__c FROM Bank_Deposit__c];
            List<Cash_Receipt__c> receiptResults = [SELECT Id, Bank_Deposit__c FROM Cash_Receipt__c];

            System.assertEquals(2, depositResults.size());
            System.assertEquals('77377', depositResults[0].Merchant_Batch_Id__c);
            System.assertEquals('1234', activityResults[0].Merchant_Reference__c);
            System.assertEquals('77377', activityResults[0].Merchant_Batch_Id__c);
            System.assertEquals(deposit.Id, receiptResults[0].Bank_Deposit__c);
            System.assertEquals(600, depositResults[0].Amount__c);
            System.assertEquals(600, depositResults[0].Ledger_Amount__c);
            System.assertEquals(testData.ledgers[0].Id, depositResults[0].Ledger__c);
        }
    }
    @IsTest
    public static void testCxTxnsUpdateBatchError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            HttpCalloutMock multiCalloutMockInstance = createResponseGeneratorError();
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            Payment_Processor__c pp = testData.paymentProcessors[2];

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = pp.Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = testData.paymentProcessors[2].Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Credit Card', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Type__c ='Visa',Default__c=true);
            INSERT pm;

            Cash_Receipt__c cReciept = new Cash_Receipt__c(
                        Account__c = testData.accounts.get(1).Id,
                        Amount__c = 400,
                        Status__c = 'Approved',
                        Receipt_Date__c = System.today(),
                        Purpose__c = 'Customer Receipt',
                        Payment_Reference__c = '1234',
                        Accounting_Period__c = testData.acctPeriods.get(0).Id,
                        Payment_Processor__c = testData.paymentProcessors[2].Id
                    );
            INSERT cReciept;
            Payment_Activity__c pa = new Payment_Activity__c(Type__c='Payment',Status__c='Pending',Amount__c=1,
                                    Payment_Method__c = pm.Id,Cash_Receipt__c = cReciept.Id, Merchant_Batch_Id__c = '7737');

            INSERT pa;
            Test.startTest();
            Database.executeBatch(new CxTxnsUpdateBatch(System.now(),new Set<Id> {pp.Id}, new Set<String>(), new CxAJRLogger()), 200);
            Test.stopTest();

            System.assertEquals(0,[SELECT Id,Merchant_Batch_Id__c FROM Bank_Deposit__c].size());
            System.assertEquals(null,[SELECT Id,Bank_Deposit__c FROM Cash_Receipt__c][0].Bank_Deposit__c);
        }
    }
    @IsTest
    public static void testCxTxnsUpdateBatchSuccessWithAJRCreation() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            HttpCalloutMock multiCalloutMockInstance = createResponseGeneratorSuccessOneRecord();
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            Payment_Processor__c pp = testData.paymentProcessors[2];

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = pp.Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = testData.paymentProcessors[2].Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Credit Card', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Type__c ='Visa',Default__c=true);
            INSERT pm;

            Cash_Receipt__c cReciept = new Cash_Receipt__c(
                        Account__c = testData.accounts.get(1).Id,
                        Credit_GL_Account__c = testData.glAccounts[1].Id,
                        Amount__c = 400,
                        Status__c = 'Approved',
                        Purpose__c = 'Customer Receipt',
                        Payment_Reference__c = '1234',
                        Accounting_Period__c = testData.acctPeriods.get(0).Id,
                        Payment_Processor__c = testData.paymentProcessors[2].Id,
                        Receipt_Date__c = System.today().addDays(-35)
                    );
            INSERT cReciept;

            Assert.areEqual(0,[SELECT Id,Name,Processed__c,Succeeded__c FROM Automated_Job_Results__c].size());

            Test.startTest();
            Database.executeBatch(new CxTxnsUpdateBatch(System.now(),new Set<Id> {pp.Id}, new Set<String>(), new CxAJRLogger()), 200);
            Test.stopTest();

            Assert.areEqual(1,[SELECT Id,Name,Processed__c,Succeeded__c FROM Automated_Job_Results__c].size());
            Assert.areEqual(1,[SELECT Id,Name,Processed__c FROM Automated_Job_Results__c][0].Processed__c);
            Assert.areEqual(1,[SELECT Id,Name,Succeeded__c FROM Automated_Job_Results__c][0].Succeeded__c);
        }
    }
    private static MultiRequestMock createResponseGeneratorSuccess() {
        SingleRequestMock xMockReportingResponse = new SingleRequestMock(
            200,
            'Complete',
            '{"SoftwareName" : "ACME Inc.","SoftwareVersion" : "2.0","xCommand" : "Report:Transaction","xReportData" : [{"xBatch":"18500580","xBatchDate": "'+System.today().format()+'","xBatchTime":"12:00:45 PM","xTotalCount":"3","xTotalAmount":"200","xSaleAmount":"300","xSaleCount":"3","xVisaSaleCount" :"3","xVisaSaleAmount":"200","xMCSaleCount":"","xMCSaleAmount":"","xAchSaleCount":"","xAchSaleAmount":""},{"xBatch":"18500581","xBatchDate": "'+System.today().format()+'","xBatchTime":"12:00:45 PM","xTotalCount":"3","xTotalAmount":"200","xSaleAmount":"300","xSaleCount":"3","xVisaSaleCount" :"3","xVisaSaleAmount":"200","xMCSaleCount":"","xMCSaleAmount":"","xAchSaleCount":"","xAchSaleAmount":""}]}',
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        SingleRequestMock xMockBatchResponse = new SingleRequestMock(
            200,
            'Complete',
            '{"SoftwareName" : "ACME Inc.","SoftwareVersion" : "2.0","xCommand" : "Report:Batch","xReportData" : [{"xRefNum":"1234","xBatch":"18500580","xBatchDate": "4/11/2023","xBatchTime":"12:00:45 PM","xTotalCount":"3","xTotalAmount":"200","xSaleAmount":"300","xSaleCount":"3","xVisaSaleCount" :"3","xVisaSaleAmount":"200","xMCSaleCount":"","xMCSaleAmount":"","xAchSaleCount":"","xAchSaleAmount":""},{"xBatch":"18500581","xBatchDate": "4/11/2023","xBatchTime":"12:00:45 PM","xTotalCount":"3","xTotalAmount":"200","xSaleAmount":"300","xSaleCount":"3","xVisaSaleCount" :"3","xVisaSaleAmount":"200","xMCSaleCount":"","xMCSaleAmount":"","xAchSaleCount":"","xAchSaleAmount":""}]}',
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
        endpoint2TestResp.put(CardknoxService.REPORT_ENDPOINT , xMockReportingResponse);
        endpoint2TestResp.put(CardknoxService.REPORT_ENDPOINT+'/batch' , xMockBatchResponse);

        MultiRequestMock multiCalloutMockInstance = new MultiRequestMock(endpoint2TestResp);

        return multiCalloutMockInstance;
    }
    private static MultiRequestMock createResponseGeneratorError() {
        SingleRequestMock xMockBatchResponse = new SingleRequestMock(
            200,
            'Complete',
            '{"SoftwareName" : "ACME Inc.","SoftwareVersion" : "2.0","xCommand" : "Report:Batch", "xStatus" : "E", "xError" : "internal error", "xErrorCode" : "1111"',
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
        endpoint2TestResp.put(CardknoxService.REPORT_ENDPOINT+'/batch' , xMockBatchResponse);

        MultiRequestMock multiCalloutMockInstance = new MultiRequestMock(endpoint2TestResp);

        return multiCalloutMockInstance;
    }
    private static MultiRequestMock createResponseGeneratorSuccessOneRecord() {
        SingleRequestMock xMockReportingResponse = new SingleRequestMock(
            200,
            'Complete',
            '{"SoftwareName" : "ACME Inc.","SoftwareVersion" : "2.0","xCommand" : "Report:Transaction","xReportData" : [{"xBatch":"77377","xBatchDate":"5/1/2023","xBatchTime":"12:00:45 PM","xErrorCode":"0000","xResponseError":"","xRefNum":"1234","xStatus":"Success","xResponseBatch":"77377","xProcessingFee":"2"}]}',
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        SingleRequestMock xMockBatchResponse = new SingleRequestMock(
            200,
            'Complete',
            '{"SoftwareName" : "ACME Inc.","SoftwareVersion" : "2.0","xCommand" : "Report:Batch","xReportData" : [{"xBatch":"77377","xBatchDate":"5/1/2023","xBatchTime":"12:00:45 PM"}]}',
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
        endpoint2TestResp.put(CardknoxService.REPORT_ENDPOINT , xMockReportingResponse);
        endpoint2TestResp.put(CardknoxService.REPORT_ENDPOINT+'/batch' , xMockBatchResponse);

        MultiRequestMock multiCalloutMockInstance = new MultiRequestMock(endpoint2TestResp);

        return multiCalloutMockInstance;
    }
}