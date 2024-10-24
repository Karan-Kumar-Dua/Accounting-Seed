@IsTest
private class PaymentActivityACHStatusBatchTest {
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testBatchExecutionSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Payment_Processor_Customer__c ppc =  new Payment_Processor_Customer__c(
                Account__c = testData.accounts.get(0).Id,
                Processor__c = testData.paymentProcessors.get(0).Id,
                External_Id__c = 'abc123'
            );
            insert ppc;

            Payment_Method__c testPaymentMethod = new Payment_Method__c(
                Card_Holder_Name__c = 'Test Holder Name',
                Bank_Account_Type__c = 'Individual',
                Bank_Name__c = 'Test Bank',
                Customer__c = testData.accounts[0].Id,
                Expiration_Month__c = '12',
                Expiration_Year__c = '2020',
                External_Id__c = 'external_id',
                Last_Four_Digits__c = '1234',
                Payment_Method_Type__c = PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE,
                Status__c = 'Active',
                Verification_Status__c = 'verified',
                Payment_Processor__c = ppc.Processor__c
            );
            insert testPaymentMethod;

            Payment_Activity__c testPaymentActivity = new Payment_Activity__c(
                Amount__c = 100,
                Cash_Receipt__c = testData.cashReceipts[0].Id,
                Payment_Method__c = testPaymentMethod.Id,
                Status__c = 'Pending',
                Type__c = 'Payment'
            );
            insert testPaymentActivity;

            SingleRequestMock stripeChargeResponseMock = new SingleRequestMock(
                200,
                'Complete',
                getStripeChargeResponseSuccess(),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, stripeChargeResponseMock);

            PaymentActivityACHStatusBatch batchInstance = new PaymentActivityACHStatusBatch();
            Test.startTest();
            Database.executeBatch(batchInstance);
            Test.stopTest();
            System.assertEquals('Success', [SELECT Status__c FROM Payment_Activity__c WHERE Id = :testPaymentActivity.Id].Status__c);
        }
    }

    @IsTest
    private static void testBatchExecutionDeclined() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Payment_Processor_Customer__c ppc =  new Payment_Processor_Customer__c(
                Account__c = testData.accounts.get(0).Id,
                Processor__c = testData.paymentProcessors.get(0).Id,
                External_Id__c = 'abc123'
            );
            insert ppc;

            Payment_Method__c testPaymentMethod = new Payment_Method__c(
                Card_Holder_Name__c = 'Test Holder Name',
                Bank_Account_Type__c = 'Individual',
                Bank_Name__c = 'Test Bank',
                Customer__c = testData.accounts[0].Id,
                Expiration_Month__c = '12',
                Expiration_Year__c = '2020',
                External_Id__c = 'external_id',
                Last_Four_Digits__c = '1234',
                Payment_Method_Type__c = PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE,
                Status__c = 'Active',
                Verification_Status__c = 'verified',
                Payment_Processor__c = ppc.Processor__c
            );
            insert testPaymentMethod;

            Payment_Activity__c testPaymentActivity = new Payment_Activity__c(
                Amount__c = 100,
                Cash_Receipt__c = testData.cashReceipts[0].Id,
                Payment_Method__c = testPaymentMethod.Id,
                Status__c = 'Pending',
                Type__c = 'Payment'
            );
            insert testPaymentActivity;

            SingleRequestMock stripeChargeResponseMock = new SingleRequestMock(
                200,
                'Complete',
                getStripeChargeResponseFailed(),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, stripeChargeResponseMock);

            PaymentActivityACHStatusBatch batchInstance = new PaymentActivityACHStatusBatch();
            Test.startTest();
            Database.executeBatch(batchInstance);
            Test.stopTest();
            System.assertEquals('Declined', [SELECT Status__c FROM Payment_Activity__c WHERE Id = :testPaymentActivity.Id].Status__c);
        }
    }

    @IsTest
    private static void testBatchExecutionStripeException() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Payment_Processor_Customer__c ppc =  new Payment_Processor_Customer__c(
                Account__c = testData.accounts.get(0).Id,
                Processor__c = testData.paymentProcessors.get(0).Id,
                External_Id__c = 'abc123'
            );
            insert ppc;

            Payment_Method__c testPaymentMethod = new Payment_Method__c(
                Card_Holder_Name__c = 'Test Holder Name',
                Bank_Account_Type__c = 'Individual',
                Bank_Name__c = 'Test Bank',
                Customer__c = testData.accounts[0].Id,
                Expiration_Month__c = '12',
                Expiration_Year__c = '2020',
                External_Id__c = 'external_id',
                Last_Four_Digits__c = '1234',
                Payment_Method_Type__c = PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE,
                Status__c = 'Active',
                Verification_Status__c = 'verified',
                Payment_Processor__c = ppc.Processor__c
            );
            insert testPaymentMethod;

            Payment_Activity__c testPaymentActivity = new Payment_Activity__c(
                Amount__c = 100,
                Cash_Receipt__c = NULL,//no reference
                Payment_Method__c = testPaymentMethod.Id,
                Status__c = 'Pending',
                Type__c = 'Payment'
            );
            insert testPaymentActivity;

            SingleRequestMock stripeChargeResponseMock = new SingleRequestMock(
                200,
                'Complete',
                getStripeErrorResponse(),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, stripeChargeResponseMock);

            PaymentActivityACHStatusBatch batchInstance = new PaymentActivityACHStatusBatch();
            Test.startTest();
            Database.executeBatch(batchInstance);
            Test.stopTest();
            System.assertEquals('Error', [SELECT Status__c FROM Payment_Activity__c WHERE Id = :testPaymentActivity.Id].Status__c);
        }
    }

    @IsTest
    private static void testBatchExecutionSuccessErrorActivity() {
        Test.setMock(HttpCalloutMock.class, new MockActivityStatusUpdateResponse());
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Payment_Processor_Customer__c ppc =  new Payment_Processor_Customer__c(
                Account__c = testData.accounts.get(0).Id,
                Processor__c = testData.paymentProcessors.get(2).Id,
                External_Id__c = 'abc123'
            );
            insert ppc;

            Payment_Method__c testPaymentMethod = new Payment_Method__c(
                Card_Holder_Name__c = 'Test Holder Name',
                Bank_Account_Type__c = 'Individual',
                Bank_Name__c = 'Test Bank',
                Customer__c = testData.accounts[0].Id,
                Expiration_Month__c = '12',
                Expiration_Year__c = '2020',
                External_Id__c = 'external_id',
                Last_Four_Digits__c = '1234',
                Payment_Method_Type__c = PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE,
                Status__c = 'Active',
                Verification_Status__c = 'verified',
                Payment_Processor__c = ppc.Processor__c
            );
            insert testPaymentMethod;

            Payment_Activity__c testPaymentActivity = new Payment_Activity__c(
                Amount__c = 100,
                Cash_Receipt__c = testData.cashReceipts[0].Id,
                Payment_Method__c = testPaymentMethod.Id,
                Status__c = 'Pending',
                Type__c = 'Payment',
                Merchant_Reference__c = '0'
            );
            insert testPaymentActivity;
            Assert.areEqual('Pending', [SELECT Status__c FROM Payment_Activity__c WHERE Id = :testPaymentActivity.Id].Status__c);

            PaymentActivityACHStatusBatch batchInstance = new PaymentActivityACHStatusBatch();
            Test.startTest();
            Database.executeBatch(batchInstance);
            Test.stopTest();
            Assert.areEqual('Error', [SELECT Status__c FROM Payment_Activity__c WHERE Id = :testPaymentActivity.Id].Status__c);
        }
    }
    @IsTest
    private static void testBatchExecutionSuccessVoidActivity() {
        Test.setMock(HttpCalloutMock.class, new MockActivityStatusUpdateVoidResponse());
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Payment_Processor_Customer__c ppc =  new Payment_Processor_Customer__c(
                Account__c = testData.accounts.get(0).Id,
                Processor__c = testData.paymentProcessors.get(2).Id,
                External_Id__c = 'abc123'
            );
            insert ppc;

            Payment_Method__c testPaymentMethod = new Payment_Method__c(
                Card_Holder_Name__c = 'Test Holder Name',
                Bank_Account_Type__c = 'Individual',
                Bank_Name__c = 'Test Bank',
                Customer__c = testData.accounts[0].Id,
                Expiration_Month__c = '12',
                Expiration_Year__c = '2020',
                External_Id__c = 'external_id',
                Last_Four_Digits__c = '1234',
                Payment_Method_Type__c = PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE,
                Status__c = 'Active',
                Verification_Status__c = 'verified',
                Payment_Processor__c = ppc.Processor__c
            );
            insert testPaymentMethod;

            Payment_Activity__c testPaymentActivity = new Payment_Activity__c(
                Amount__c = 100,
                Cash_Receipt__c = testData.cashReceipts[0].Id,
                Payment_Method__c = testPaymentMethod.Id,
                Status__c = 'Pending',
                Type__c = 'Payment',
                Merchant_Reference__c = '0'
            );
            insert testPaymentActivity;
            Assert.areEqual('Pending', [SELECT Status__c FROM Payment_Activity__c WHERE Id = :testPaymentActivity.Id].Status__c);

            PaymentActivityACHStatusBatch batchInstance = new PaymentActivityACHStatusBatch();
            Test.startTest();
            Database.executeBatch(batchInstance);
            Test.stopTest();
            Assert.areEqual('Void', [SELECT Status__c FROM Payment_Activity__c WHERE Id = :testPaymentActivity.Id].Status__c);
        }
    }
    private class MockActivityStatusUpdateVoidResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            String body = '{"xResult":"S","xStatus":"Success","xError":"","xRefNum":"10147562579","xReportingMaxTransactions":"5000","xRecordsReturned":"1","xReportData":[' +
                '{"xEnteredDate": "5/6/2024 6:10:05 AM","xRefNum":"0","xStatus":"0","xResponseResult":"Approved","xResponseError":"","xErrorCode":"0","xResponseBatch":"25020810","xCommand":"CC:Sale","xCurrency":"USD","xVoid":"1","xVoidable":"1"}' +
            + ']}';
            HttpResponse res = new HttpResponse();
            res.setHeader('Authorization', 'concretiodev80eb19edb91340e5b62e852d1a32be8d');
            res.setHeader('X-Recurring-Api-Version', '2.0');
            res.setBody(body);
            res.setStatusCode(200);
            return res;
        }
    }
    private class MockActivityStatusUpdateResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            String body = '{"xResult":"S","xStatus":"Success","xError":"","xRefNum":"10147562579","xReportingMaxTransactions":"5000","xRecordsReturned":"1","xReportData":[' +
                '{"xEnteredDate": "5/6/2024 6:10:05 AM","xRefNum":"0","xStatus":"0","xResponseResult":"Chargeback","xResponseError":"","xErrorCode":"0","xResponseBatch":"25020810","xCommand":"CC:Sale","xCurrency":"USD","xVoid":"0","xVoidable":"1"}' +
            + ']}';
            HttpResponse res = new HttpResponse();
            res.setHeader('Authorization', 'concretiodev80eb19edb91340e5b62e852d1a32be8d');
            res.setHeader('X-Recurring-Api-Version', '2.0');
            res.setBody(body);
            res.setStatusCode(200);
            return res;
        }
    }
    private static String getStripeChargeResponseSuccess() {
        StripeService.StripeCharge response = new StripeService.StripeCharge();
        response.id = '123456';
        response.amount = 100;
        response.description = 'test descr';
        response.status = 'succeeded';//The status of the payment is either succeeded, pending, or failed
        return JSON.serialize(response);
    }

    private static String getStripeChargeResponseFailed() {
        StripeService.StripeCharge response = new StripeService.StripeCharge();
        response.id = '12345';
        response.amount = 100;
        response.description = 'test descr';
        response.status = 'failed';//The status of the payment is either succeeded, pending, or failed
        response.failure_code = 'failure_code';
        response.failure_message = 'failure_message';
        return JSON.serialize(response);
    }

    private static String getStripeChargeResponseException() {
        StripeService.StripeCharge response = new StripeService.StripeCharge();
        response.id = '123456';
        response.amount = 100;
        response.description = 'test descr';
        response.status = 'succeeded';//The status of the payment is either succeeded, pending, or failed
        return JSON.serialize(response);
    }

    private static String getStripeErrorResponse() {
        return
            '{' +
                '"error": {' +
                '"code": "some_code",' +
                '"param": "some_param",' +
                '"message": "StripeErrorMessage",' +
                '"type": "some_type"' +
                '}' +
            '}';
    }
}