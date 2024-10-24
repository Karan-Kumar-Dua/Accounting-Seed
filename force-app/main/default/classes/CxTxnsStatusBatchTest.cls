@IsTest
public with sharing class CxTxnsStatusBatchTest {
    
    @TestSetup
    static void setupTestData(){
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testStart() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPaymentProcessors()
            .createCashReceipts();
        
        System.runAs(testData.users[1]) {

            Payment_Method__c paymentMethod = getPaymentMethod(testData.accounts[0], testData.paymentProcessors[2]);
            insert paymentMethod;

            List<Payment_Activity__c> activities = new List<Payment_Activity__c>{
                new Payment_Activity__c(
                    Payment_Method__c = paymentMethod.Id,
                    Status__c = PaymentActivityHelper.PENDING_STATUS,
                    Amount__c = 100,
                    Cash_Receipt__c = null,
                    Merchant_Batch_Id__c = '12345'
                ),
                new Payment_Activity__c(
                    Payment_Method__c = paymentMethod.Id,
                    Status__c = PaymentActivityHelper.SUCCESS_STATUS,
                    Amount__c = testData.cashReceipts[0].Amount__c,
                    Cash_Receipt__c = testData.cashReceipts[0].Id,
                    Merchant_Batch_Id__c = '12345'
                )
            };
            insert activities;

            Test.startTest();
            CxTxnsStatusBatch job = new CxTxnsStatusBatch(null, null, null, null);
            Database.QueryLocator jobScope = job.start(null);
            List<Payment_Activity__c> activitiesInScope = (List<Payment_Activity__c>) Database.query(jobScope.getQuery());
            Test.stopTest();

            Assert.areEqual(activities.size(), activitiesInScope.size());
        }
    }

    @IsTest
    static void testExecute() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPaymentProcessors()
            .createCashReceipts();
        
        System.runAs(testData.users[1]) {
            Payment_Method__c paymentMethod = getPaymentMethod(testData.accounts[0], testData.paymentProcessors[2]);
            insert paymentMethod;

            List<Payment_Activity__c> activities = new List<Payment_Activity__c>{
                new Payment_Activity__c(
                    Payment_Method__c = paymentMethod.Id,
                    Status__c = PaymentActivityHelper.PENDING_STATUS,
                    Amount__c = 100,
                    Cash_Receipt__c = null,
                    Merchant_Batch_Id__c = '12345'
                ),
                new Payment_Activity__c(
                    Payment_Method__c = paymentMethod.Id,
                    Status__c = PaymentActivityHelper.SUCCESS_STATUS,
                    Amount__c = testData.cashReceipts[0].Amount__c,
                    Cash_Receipt__c = testData.cashReceipts[0].Id,
                    Merchant_Batch_Id__c = '12345'
                )
            };
            insert activities;

            GenericMock mock = new GenericMock();
            mock.registerResponse('getPaymentActivityStatus', activities);
            PaymentGateway paymentGateway = (PaymentGateway) Test.createStub(PaymentGateway.class, mock);

            CxAJRLogger logger = new CxAJRLogger();

            Test.startTest();
            CxTxnsStatusBatch job = new CxTxnsStatusBatch(DateTime.now(), new Set<Id>{ testData.paymentProcessors[2].Id }, logger, paymentGateway);
            Database.executeBatch(job, 10);
            Test.stopTest();

            List<Automated_Job_Results__c> ajrs = [SELECT Failed__c FROM Automated_Job_Results__c];
            Assert.areEqual(1, ajrs.size());
            Assert.areEqual(0, ajrs[0].Failed__c);
        }
    }

    @IsTest
    static void testErrorOnCallout() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPaymentProcessors()
            .createCashReceipts();
        
        System.runAs(testData.users[1]) {
            Payment_Method__c paymentMethod = getPaymentMethod(testData.accounts[0], testData.paymentProcessors[2]);
            insert paymentMethod;

            List<Payment_Activity__c> activities = new List<Payment_Activity__c>{
                new Payment_Activity__c(
                    Payment_Method__c = paymentMethod.Id,
                    Status__c = PaymentActivityHelper.PENDING_STATUS,
                    Amount__c = 100,
                    Cash_Receipt__c = null,
                    Merchant_Batch_Id__c = '12345'
                ),
                new Payment_Activity__c(
                    Payment_Method__c = paymentMethod.Id,
                    Status__c = PaymentActivityHelper.SUCCESS_STATUS,
                    Amount__c = testData.cashReceipts[0].Amount__c,
                    Cash_Receipt__c = testData.cashReceipts[0].Id
                )
            };
            insert activities;

            GenericMock mock = new GenericMock();
            mock.registerResponse('getPaymentActivityStatus', new PaymentGateway.PaymentGatewayException('Test Error'));
            PaymentGateway paymentGateway = (PaymentGateway) Test.createStub(PaymentGateway.class, mock);

            CxAJRLogger logger = new CxAJRLogger();

            Test.startTest();
            CxTxnsStatusBatch job = new CxTxnsStatusBatch(DateTime.now(), new Set<Id>{ testData.paymentProcessors[2].Id }, logger, paymentGateway);
            Database.executeBatch(job, 10);
            Test.stopTest();

            List<Automated_Job_Results__c> ajrs = [SELECT Failed__c FROM Automated_Job_Results__c];
            Assert.areEqual(1, ajrs.size());
            Assert.areEqual(1, ajrs[0].Failed__c);
        }
    }

    @IsTest
    static void testUpdatePendingToVoid() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPaymentProcessors()
            .createCashReceipts();
        
        System.runAs(testData.users[1]) {
            Payment_Method__c paymentMethod = getPaymentMethod(testData.accounts[0], testData.paymentProcessors[2]);
            insert paymentMethod;

            Payment_Activity__c activity = new Payment_Activity__c(
                Payment_Method__c = paymentMethod.Id,
                Status__c = PaymentActivityHelper.PENDING_STATUS,
                Amount__c = 100,
                Cash_Receipt__c = testData.cashReceipts[0].Id,
                Merchant_Batch_Id__c = '12345'
            );
            insert activity;

            activity.Status__c = PaymentActivityHelper.VOID_STATUS;

            GenericMock mock = new GenericMock();
            mock.registerResponse('getPaymentActivityStatus', new List<Payment_Activity__c>{activity});
            PaymentGateway paymentGateway = (PaymentGateway) Test.createStub(PaymentGateway.class, mock);

            CxAJRLogger logger = new CxAJRLogger();

            Test.startTest();
            CxTxnsStatusBatch job = new CxTxnsStatusBatch(DateTime.now(), new Set<Id>{ testData.paymentProcessors[2].Id }, logger, paymentGateway);
            Database.QueryLocator jobScope = job.start(null);
            List<Payment_Activity__c> activitiesInScope = (List<Payment_Activity__c>) Database.query(jobScope.getQuery());
            job.execute(null, activitiesInScope);
            Test.stopTest();

            Assert.areEqual(0, job.batchesWithPendingPayments.size());
            Assert.areEqual(1, job.voids.size());
            Assert.isTrue(job.voids.contains(activity.Cash_Receipt__c));
            Assert.areEqual(PaymentActivityHelper.VOID_STATUS, [SELECT Status__c FROM Payment_Activity__c WHERE Id = :activity.Id].Status__c);
        }
    }

    @IsTest
    static void testUpdatePendingToError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPaymentProcessors()
            .createCashReceipts();
        
        System.runAs(testData.users[1]) {
            Payment_Method__c paymentMethod = getPaymentMethod(testData.accounts[0], testData.paymentProcessors[2]);
            insert paymentMethod;

            Payment_Activity__c activity = new Payment_Activity__c(
                Payment_Method__c = paymentMethod.Id,
                Status__c = PaymentActivityHelper.PENDING_STATUS,
                Amount__c = 100,
                Cash_Receipt__c = testData.cashReceipts[0].Id,
                Merchant_Batch_Id__c = '12345'
            );
            insert activity;

            activity.Status__c = PaymentActivityHelper.ERROR_STATUS;

            GenericMock mock = new GenericMock();
            mock.registerResponse('getPaymentActivityStatus', new List<Payment_Activity__c>{activity});
            PaymentGateway paymentGateway = (PaymentGateway) Test.createStub(PaymentGateway.class, mock);

            CxAJRLogger logger = new CxAJRLogger();

            Test.startTest();
            CxTxnsStatusBatch job = new CxTxnsStatusBatch(DateTime.now(), new Set<Id>{ testData.paymentProcessors[2].Id }, logger, paymentGateway);
            Database.QueryLocator jobScope = job.start(null);
            List<Payment_Activity__c> activitiesInScope = (List<Payment_Activity__c>) Database.query(jobScope.getQuery());
            job.execute(null, activitiesInScope);
            Test.stopTest();

            Assert.areEqual(0, job.batchesWithPendingPayments.size());
            Assert.areEqual(1, job.voids.size()); // Voided because the errant payment should be voided in AS
            Assert.isTrue(job.voids.contains(activity.Cash_Receipt__c));
            Assert.areEqual(PaymentActivityHelper.ERROR_STATUS, [SELECT Status__c FROM Payment_Activity__c WHERE Id = :activity.Id].Status__c);
        }
    }

    @IsTest
    static void testUpdateSuccessToVoid() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPaymentProcessors()
            .createCashReceipts();
        
        System.runAs(testData.users[1]) {
            Payment_Method__c paymentMethod = getPaymentMethod(testData.accounts[0], testData.paymentProcessors[2]);
            insert paymentMethod;

            Payment_Activity__c activity = new Payment_Activity__c(
                Payment_Method__c = paymentMethod.Id,
                Status__c = PaymentActivityHelper.PENDING_STATUS,
                Amount__c = 100,
                Cash_Receipt__c = testData.cashReceipts[0].Id,
                Merchant_Batch_Id__c = '12345'
            );
            insert activity;

            activity.Status__c = PaymentActivityHelper.VOID_STATUS;

            GenericMock mock = new GenericMock();
            mock.registerResponse('getPaymentActivityStatus', new List<Payment_Activity__c>{activity});
            PaymentGateway paymentGateway = (PaymentGateway) Test.createStub(PaymentGateway.class, mock);

            CxAJRLogger logger = new CxAJRLogger();

            Test.startTest();
            CxTxnsStatusBatch job = new CxTxnsStatusBatch(DateTime.now(), new Set<Id>{ testData.paymentProcessors[2].Id }, logger, paymentGateway);
            Database.QueryLocator jobScope = job.start(null);
            List<Payment_Activity__c> activitiesInScope = (List<Payment_Activity__c>) Database.query(jobScope.getQuery());
            job.execute(null, activitiesInScope);
            Test.stopTest();

            Assert.areEqual(0, job.batchesWithPendingPayments.size());
            Assert.areEqual(1, job.voids.size());
            Assert.isTrue(job.voids.contains(activity.Cash_Receipt__c));
            Assert.areEqual(PaymentActivityHelper.VOID_STATUS, [SELECT Status__c FROM Payment_Activity__c WHERE Id = :activity.Id].Status__c);
        }
    }

    @IsTest
    static void testUpdatePendingToSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPaymentProcessors()
            .createCashReceipts();
        
        System.runAs(testData.users[1]) {
            Payment_Method__c paymentMethod = getPaymentMethod(testData.accounts[0], testData.paymentProcessors[2]);
            insert paymentMethod;

            Payment_Activity__c activity = new Payment_Activity__c(
                Payment_Method__c = paymentMethod.Id,
                Status__c = PaymentActivityHelper.PENDING_STATUS,
                Amount__c = 100,
                Cash_Receipt__c = testData.cashReceipts[0].Id,
                Merchant_Batch_Id__c = '12345'
            );
            insert activity;

            activity.Status__c = PaymentActivityHelper.SUCCESS_STATUS;

            GenericMock mock = new GenericMock();
            mock.registerResponse('getPaymentActivityStatus', new List<Payment_Activity__c>{activity});
            PaymentGateway paymentGateway = (PaymentGateway) Test.createStub(PaymentGateway.class, mock);

            CxAJRLogger logger = new CxAJRLogger();

            Test.startTest();
            CxTxnsStatusBatch job = new CxTxnsStatusBatch(DateTime.now(), new Set<Id>{ testData.paymentProcessors[2].Id }, logger, paymentGateway);
            Database.QueryLocator jobScope = job.start(null);
            List<Payment_Activity__c> activitiesInScope = (List<Payment_Activity__c>) Database.query(jobScope.getQuery());
            job.execute(null, activitiesInScope);
            Test.stopTest();

            Assert.areEqual(0, job.batchesWithPendingPayments.size());
            Assert.areEqual(0, job.voids.size());
            Assert.areEqual(PaymentActivityHelper.SUCCESS_STATUS, [SELECT Status__c FROM Payment_Activity__c WHERE Id = :activity.Id].Status__c);
        }
    }

    @IsTest
    static void testUpdatePendingToPending() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPaymentProcessors()
            .createCashReceipts();
        
        System.runAs(testData.users[1]) {
            Payment_Method__c paymentMethod = getPaymentMethod(testData.accounts[0], testData.paymentProcessors[2]);
            insert paymentMethod;

            Payment_Activity__c activity = new Payment_Activity__c(
                Payment_Method__c = paymentMethod.Id,
                Status__c = PaymentActivityHelper.PENDING_STATUS,
                Amount__c = 100,
                Cash_Receipt__c = testData.cashReceipts[0].Id,
                Merchant_Batch_Id__c = '12345'
            );
            insert activity;

            activity.Status__c = PaymentActivityHelper.PENDING_STATUS;

            GenericMock mock = new GenericMock();
            mock.registerResponse('getPaymentActivityStatus', new List<Payment_Activity__c>{activity});
            PaymentGateway paymentGateway = (PaymentGateway) Test.createStub(PaymentGateway.class, mock);

            CxAJRLogger logger = new CxAJRLogger();

            Test.startTest();
            CxTxnsStatusBatch job = new CxTxnsStatusBatch(DateTime.now(), new Set<Id>{ testData.paymentProcessors[2].Id }, logger, paymentGateway);
            Database.QueryLocator jobScope = job.start(null);
            List<Payment_Activity__c> activitiesInScope = (List<Payment_Activity__c>) Database.query(jobScope.getQuery());
            job.execute(null, activitiesInScope);
            Test.stopTest();

            Assert.areEqual(1, job.batchesWithPendingPayments.size());
            Assert.isTrue(job.batchesWithPendingPayments.contains(activity.Merchant_Batch_Id__c));
            Assert.areEqual(0, job.voids.size());
            Assert.areEqual(PaymentActivityHelper.PENDING_STATUS, [SELECT Status__c FROM Payment_Activity__c WHERE Id = :activity.Id].Status__c);
        }
    }

    private static Payment_Method__c getPaymentMethod(Account customer, Payment_Processor__c processor) {
        return new Payment_Method__c(
            Customer__c = customer.Id, 
            Payment_Processor__c = processor.Id, 
            External_Id__c = customer.Id + '' + processor.Id,
            Last_Four_Digits__c = '4242',
            Payment_Method_Type__c = 'Credit Card', 
            Status__c = 'Active',
            Expiration_Month__c = '12',
            Expiration_Year__c = '2224',
            Type__c = 'Visa',
            Default__c = true
        );
    }
}