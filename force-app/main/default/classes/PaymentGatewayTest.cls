@IsTest
public with sharing class PaymentGatewayTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    // create customer: missing input
    @IsTest
    static void testCreateCustomerMissingInput() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            PaymentGateway gtwy = new PaymentGateway();
            
            Exception expectedEx;
            try {
                gtwy.createCustomer(null);
                Assert.fail(Label.ERR_X_IS_REQUIRED + ' Exception expected.');
            } catch (PaymentGateway.PaymentGatewayException e) {
                expectedEx = e;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            String expectedMsg = String.format(
                Label.ERR_X_IS_REQUIRED,
                new List<String> {SObjectType.Payment_Processor_Customer__c.getLabel()}
            );
            System.assertEquals(expectedMsg, expectedEx.getMessage());
        }
    }

    // create customer: input already has id
    @IsTest
    static void testCreateCustomerInputHasId() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Payment_Processor_Customer__c customer =  new Payment_Processor_Customer__c(
                Id = FinancialSuiteUtils.getFakeId(Payment_Processor_Customer__c.SObjectType)
            );
            PaymentGateway gtwy = new PaymentGateway();
            
            Exception expectedEx;
            try {
                gtwy.createCustomer(customer);
                Assert.fail(Label.ERR_X_ALREADY_EXISTS + ' Exception expected.');
            } catch (PaymentGateway.PaymentGatewayException e) {
                expectedEx = e;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            String expectedMsg = String.format(
                Label.ERR_X_ALREADY_EXISTS,
                new List<String> {SObjectType.Payment_Processor_Customer__c.getLabel()}
            );
            expectedMsg += ' ' + customer.Id;
            System.assertEquals(expectedMsg, expectedEx.getMessage());
        }
    }

    // create customer: missing payment processor
    @IsTest
    static void testCreateCustomerMissingProcessor() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Payment_Processor_Customer__c customer =  new Payment_Processor_Customer__c(
                Account__c = testData.accounts.get(0).Id
            );

            PaymentGateway gtwy = new PaymentGateway();
            
            Exception expectedEx;
            try {
                gtwy.createCustomer(customer);
                Assert.fail(Label.ERR_X_IS_REQUIRED + ' Exception expected.');
            } catch (PaymentGateway.PaymentGatewayException e) {
                expectedEx = e;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            String expectedMsg = String.format(
                Label.ERR_X_IS_REQUIRED,
                new List<String> {Payment_Processor_Customer__c.Processor__c.getDescribe().getLabel()}
            );
            System.assertEquals(expectedMsg, expectedEx.getMessage());
        }
    }

    // create customer: missing customer (account)
    @IsTest
    static void testCreateCustomerMissingCustomer() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Payment_Processor_Customer__c customer =  new Payment_Processor_Customer__c(
                Processor__c = testData.paymentProcessors.get(0).Id
            );

            PaymentGateway gtwy = new PaymentGateway();
            
            Exception expectedEx;
            try {
                gtwy.createCustomer(customer);
                Assert.fail(Label.ERR_X_IS_REQUIRED + ' Exception expected.');
            } catch (PaymentGateway.PaymentGatewayException e) {
                expectedEx = e;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            String expectedMsg = String.format(
                Label.ERR_X_IS_REQUIRED,
                new List<String> {Payment_Processor_Customer__c.Account__c.getDescribe().getLabel()}
            );
            System.assertEquals(expectedMsg, expectedEx.getMessage());
        }
    }

    // create customer: already exists in SF
    @IsTest
    static void testCreateCustomerExistsSF() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Payment_Processor_Customer__c customer =  new Payment_Processor_Customer__c(
                Account__c = testData.accounts.get(0).Id,
                Processor__c = testData.paymentProcessors.get(0).Id,
                External_Id__c = 'abc123'
            );
            insert customer;

            PaymentGateway gtwy = new PaymentGateway();
            
            Exception expectedEx;
            try {
            gtwy.createCustomer(new Payment_Processor_Customer__c(
                    Account__c = customer.Account__c,
                    Processor__c = customer.Processor__c
                ));
                Assert.fail(Label.ERR_X_ALREADY_EXISTS + ' Exception expected.');
            } catch (PaymentGateway.PaymentGatewayException e) {
                expectedEx = e;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            String expectedMsg = String.format(
                Label.ERR_X_ALREADY_EXISTS,
                new List<String> {SObjectType.Payment_Processor_Customer__c.getLabel()}
            );
            expectedMsg += ' ' + customer.Id;
            System.assertEquals(expectedMsg, expectedEx.getMessage());
        }
    }

    // create payment method: missing input
    @IsTest
    static void testCreatePaymentMethodMissingInput() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            PaymentGateway gtwy = new PaymentGateway();
            
            Exception expectedEx;
            try {
                gtwy.createPaymentMethod(null, 'tok_oainvrowiunbguins');
                Assert.fail(Label.ERR_X_IS_REQUIRED + ' Exception expected.');
            } catch (PaymentGateway.PaymentGatewayException e) {
                expectedEx = e;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            String expectedMsg = String.format(
                Label.ERR_X_IS_REQUIRED,
                new List<String> {SObjectType.Payment_Method__c.getLabel()}
            );
            System.assertEquals(expectedMsg, expectedEx.getMessage());
        }
    }

    // create payment method: missing token
    @IsTest
    static void testCreatePaymentMethodMissingToken() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            PaymentGateway gtwy = new PaymentGateway();
            
            Exception expectedEx;
            try {
                gtwy.createPaymentMethod(new Payment_Method__c(), null);
                Assert.fail(Label.ERR_X_IS_REQUIRED + ' Exception expected.');
            } catch (PaymentGateway.PaymentGatewayException e) {
                expectedEx = e;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            String expectedMsg = String.format(
                Label.ERR_X_IS_REQUIRED,
                new List<String> {'token'}
            );
            System.assertEquals(expectedMsg, expectedEx.getMessage());
        }
    }

    // create payment method: input already has id
    @IsTest
    static void testCreatePaymentMethodInputHasId() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Payment_Method__c pm = new Payment_Method__c(
                Id = FinancialSuiteUtils.getFakeId(Payment_Method__c.SObjectType)
            );
            PaymentGateway gtwy = new PaymentGateway();
            
            Exception expectedEx;
            try {
                gtwy.createPaymentMethod(pm, 'tok_osnfbilunaewiubn');
                Assert.fail(Label.ERR_X_ALREADY_EXISTS + ' Exception expected.');
            } catch (PaymentGateway.PaymentGatewayException e) {
                expectedEx = e;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            String expectedMsg = String.format(
                Label.ERR_X_ALREADY_EXISTS,
                new List<String> {SObjectType.Payment_Method__c.getLabel()}
            );
            expectedMsg += ' ' + pm.Id;
            System.assertEquals(expectedMsg, expectedEx.getMessage());
        }
    }

    // create payment method: input missing payment processor
    @IsTest
    static void testCreatePaymentMethodMissingProcessor() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Payment_Method__c pm = new Payment_Method__c(
                Customer__c = testData.accounts.get(0).Id,
                External_Id__c = 'abc123',
                Payment_Method_Type__c = 'Credit Card'
            );
            PaymentGateway gtwy = new PaymentGateway();
            
            Exception expectedEx;
            try {
                gtwy.createPaymentMethod(pm, 'tok_onawouenbiuna');
                Assert.fail(Label.ERR_X_IS_REQUIRED + ' Exception expected.');
            } catch (PaymentGateway.PaymentGatewayException e) {
                expectedEx = e;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            String expectedMsg = String.format(
                Label.ERR_X_IS_REQUIRED,
                new List<String> {Payment_Method__c.Payment_Processor__c.getDescribe().getLabel()}
            );
            System.assertEquals(expectedMsg, expectedEx.getMessage());
        }
    }

    // create payment method: input missing payment method type
    @IsTest
    static void testCreatePaymentMethodMissingPaymentMethodType() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Payment_Method__c pm = new Payment_Method__c(
                Customer__c = testData.accounts.get(0).Id,
                External_Id__c = 'abc123',
                Payment_Processor__c = testData.paymentProcessors.get(0).Id
            );
            PaymentGateway gtwy = new PaymentGateway();
            
            Exception expectedEx;
            try {
                gtwy.createPaymentMethod(pm, 'tok_oanbvieaunwdbvw');
                Assert.fail(Label.ERR_X_IS_REQUIRED + ' Exception expected.');
            } catch (PaymentGateway.PaymentGatewayException e) {
                expectedEx = e;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            String expectedMsg = String.format(
                Label.ERR_X_IS_REQUIRED,
                new List<String> {Payment_Method__c.Payment_Method_Type__c.getDescribe().getLabel()}
            );
            System.assertEquals(expectedMsg, expectedEx.getMessage());
        }
    }

    // create payment method: input missing customer
    @IsTest
    static void testCreatePaymentMethodMissingCustomer() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();
 
        System.runAs(testData.users[1]) {
            Test.startTest();
            Payment_Method__c pm = new Payment_Method__c(
                Payment_Processor__c = testData.paymentProcessors.get(0).Id,
                External_Id__c = 'abc123',
                Payment_Method_Type__c = 'Credit Card'
            );
            PaymentGateway gtwy = new PaymentGateway();
            
            Exception expectedEx;
            try {
                gtwy.createPaymentMethod(pm, 'tok_ovnaewoubnkjandsfbnad');
                Assert.fail(Label.ERR_X_IS_REQUIRED + ' Exception expected.');
            } catch (PaymentGateway.PaymentGatewayException e) {
                expectedEx = e;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            String expectedMsg = String.format(
                Label.ERR_X_IS_REQUIRED,
                new List<String> {Payment_Method__c.Customer__c.getDescribe().getLabel()}
            );
            System.assertEquals(expectedMsg, expectedEx.getMessage());
        }
    }

    // create payment method: already exists in SF (not stripe)
    @IsTest
    static void testCreatePaymentMethodExistsSF() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            HttpCalloutMock mock = StripeServiceTest.createResponseGenerators();
            Test.setMock(HttpCalloutMock.class, mock);

            Payment_Processor_Customer__c c = new Payment_Processor_Customer__c(
                Processor__c = testData.paymentProcessors.get(0).Id,
                Account__c = testData.accounts.get(0).Id,
                External_Id__c = 'StripeCustomerId_Success'
            );
            insert c;

            Payment_Method__c pm = new Payment_Method__c(
                Payment_Processor__c = c.Processor__c,
                Customer__c = c.Account__c,
                External_Id__c = 'StripeCustomerId_Success',
                Last_Four_Digits__c = '1234',
                Type__c = 'Visa',
                Expiration_Month__c = '01',
                Expiration_Year__c = '99',
                Payment_Method_Type__c = 'Credit Card'
            );
            insert pm;

            Test.startTest();
            PaymentGateway gtwy = new PaymentGateway();
            Exception expectedEx;
            try {
                gtwy.createPaymentMethod(new Payment_Method__c(
                    Payment_Processor__c = c.Processor__c,
                    Customer__c = c.Account__c,
                    External_Id__c = StripeServiceTest.TOKEN_ID,
                    Last_Four_Digits__c = '1234',
                    Type__c = 'Visa',
                    Expiration_Month__c = '01',
                    Expiration_Year__c = '99',
                    Payment_Method_Type__c = 'Credit Card'
                ), 'tok_ljnliswvonalwefbnlsfnb');
                Assert.fail(Label.ERR_DUPLICATED_PAYMENT_METHOD + ' Exception expected.');
            } catch (PaymentGateway.PaymentGatewayException e) {
                expectedEx = e;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            System.assertEquals(Label.ERR_DUPLICATED_PAYMENT_METHOD, expectedEx.getMessage());
        }
    }

    @IsTest
    static void testSaleCustomerMismatch() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Payment_Method__c pm = new Payment_Method__c(
                Customer__c = testData.accounts[0].Id,
                Payment_Method_Type__c = 'Credit Card'
            );

            Cash_Receipt__c cr = new Cash_Receipt__c(
                Account__c = testData.accounts[1].Id,
                Amount__c = 100,
                Bank_Account__c = testData.glAccounts[0].Id,
                Accounting_Period__c = testData.accounts[0].Id
            );

            Test.startTest();
            PaymentGateway gtwy = new PaymentGateway();
            Exception expectedEx;
            try {
                gtwy.sale(new List<PaymentSaleItem> { new PaymentSaleItem(pm, cr)});
            } catch (PaymentGateway.PaymentGatewayException e) {
                expectedEx = e;
            }
            Test.stopTest();

            System.assertEquals(null, expectedEx);
        }
    }

    @IsTest
    static void testSaleInvalidAmount() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Payment_Method__c pm = new Payment_Method__c(
                Customer__c = testData.accounts[0].Id,
                Payment_Method_Type__c = 'Bank Account'
            );

            List<Cash_Receipt__c> crs = new List<Cash_Receipt__c>{
                new Cash_Receipt__c(
                    Account__c = testData.accounts[0].Id,
                    Amount__c = null,
                    Bank_Account__c = testData.glAccounts[0].Id,
                    Accounting_Period__c = testData.accounts[0].Id
                ),
                new Cash_Receipt__c(
                    Account__c = testData.accounts[0].Id,
                    Amount__c = 0,
                    Bank_Account__c = testData.glAccounts[0].Id,
                    Accounting_Period__c = testData.accounts[0].Id
                ),
                new Cash_Receipt__c(
                    Account__c = testData.accounts[0].Id,
                    Amount__c = -100,
                    Bank_Account__c = testData.glAccounts[0].Id,
                    Accounting_Period__c = testData.accounts[0].Id
                )
            };

            Test.startTest();

            PaymentGateway gtwy = new PaymentGateway();
            for (Cash_Receipt__c cr : crs) {
                Exception expectedEx;
                try {
                    gtwy.sale(new List<PaymentSaleItem> { new PaymentSaleItem(pm, cr)});
                } catch (PaymentGateway.PaymentGatewayException e) {
                    expectedEx = e;
                }
                System.assertEquals(null, expectedEx);
            }
            
            Test.stopTest();
        }
    }

    @IsTest
    static void testSaleNoAccountingPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Payment_Method__c pm = new Payment_Method__c(
                Customer__c = testData.accounts[0].Id,
                Payment_Method_Type__c = 'Credit Card'
            );

            Cash_Receipt__c cr = new Cash_Receipt__c(
                Account__c = testData.accounts[0].Id,
                Amount__c = 100,
                Bank_Account__c = testData.glAccounts[0].Id
            );

            Test.startTest();
            PaymentGateway gtwy = new PaymentGateway();
            Exception expectedEx;
            try {
                gtwy.sale(new List<PaymentSaleItem> { new PaymentSaleItem(pm, cr)});
            } catch (PaymentGateway.PaymentGatewayException e) {
                expectedEx = e;
            }
            Test.stopTest();

            System.assertEquals(null, expectedEx);
        }
    }

    @IsTest
    static void testSaleBulkMissingCustomer() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Payment_Method__c pm = new Payment_Method__c(
                    Payment_Method_Type__c = 'Credit Card'
            );

            Cash_Receipt__c cr = new Cash_Receipt__c(
                    Amount__c = 100,
                    Bank_Account__c = testData.glAccounts[0].Id,
                    Accounting_Period__c = testData.accounts[0].Id
            );

            Test.startTest();
            PaymentGateway gtwy = new PaymentGateway();
            List<PaymentSaleItem> saleItems = gtwy.sale(new List<PaymentSaleItem>{new PaymentSaleItem(pm, cr, null)});
            Test.stopTest();

            System.assertNotEquals(null, saleItems);
            System.assert(!saleItems.isEmpty());
            System.assertEquals(
                    String.format(Label.ERR_X_IS_REQUIRED, new List<String>{Payment_Method__c.Customer__c.getDescribe().getLabel()}),
                    saleItems[0].errors.errorsHolder[0].get('message')
            );
        }
    }

    @IsTest
    static void testSaleBulkCustomerMismatch() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Payment_Method__c pm = new Payment_Method__c(
                    Customer__c = testData.accounts[0].Id,
                    Payment_Method_Type__c = 'Credit Card'
            );

            Cash_Receipt__c cr = new Cash_Receipt__c(
                    Account__c = testData.accounts[1].Id,
                    Amount__c = 100,
                    Bank_Account__c = testData.glAccounts[0].Id,
                    Accounting_Period__c = testData.accounts[0].Id
            );

            Test.startTest();
            PaymentGateway gtwy = new PaymentGateway();
            List<PaymentSaleItem> saleItems = gtwy.sale(new List<PaymentSaleItem>{new PaymentSaleItem(pm, cr, null)});
            Test.stopTest();

            System.assertNotEquals(null, saleItems);
            System.assert(!saleItems.isEmpty());
            System.assertEquals(Label.ERR_PAYMENTS_CREATE_CHARGE_ACCOUNT_MISMATCH, saleItems[0].errors.errorsHolder[0].get('message'));
        }
    }

    static void testGetPaymentActivityStatus() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Payment_Processor_Customer__c ppc =  new Payment_Processor_Customer__c(
                Account__c = testData.accounts.get(0).Id,
                Processor__c = testData.paymentProcessors.get(0).Id,
                External_Id__c = 'abc123'
            );
            insert ppc;

            Payment_Method__c pm = new Payment_Method__c(
                Type__c = 'Visa',
                Status__c = StripeService.PAYMENT_METHOD_STATUS_ACTIVE,
                Expiration_Month__c = '12',
                Expiration_Year__c = '2099',
                Last_Four_Digits__c = '4444',
                External_Id__c = 'stripe-card-1',
                Customer__c = ppc.Account__c,
                Default__c = true,
                Payment_Processor__c = ppc.Processor__c
            );
            insert pm; 

            Cash_Receipt__c cr = new Cash_Receipt__c(
                Account__c = ppc.Account__c,
                Amount__c = 100,
                Payment_Reference__c = '0000000994',
                Receipt_Date__c = testData.acctPeriods[0].Start_Date__c,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Credit_GL_Account__c = testData.glAccounts.get(16).Id,
                Payment_Processor__c = pm.Payment_Processor__c
            );
            insert cr;

            Payment_Activity__c activity = new Payment_Activity__c(
                Amount__c = cr.Amount__c,
                Cash_Receipt__c = cr.Id,
                Payment_Method__c = pm.Id,
                Status__c = 'Pending',
                Type__c = 'Payment'
            ); 
            insert activity;

            List<Payment_Activity__c> activities = [
                SELECT
                    Id,
                    Name,
                    Cash_Receipt__c,
                    Cash_Receipt__r.Name,
                    Cash_Receipt__r.Payment_Reference__c,
                    Status__c,
                    Amount__c,
                    Error_Message__c,
                    Error_Type__c,
                    Payment_Method__c,
                    Payment_Method__r.External_Id__c,
                    Type__c,
                    Payment_Method__r.Payment_Processor__c,
                    Payment_Method__r.Payment_Processor__r.Type__c
                FROM Payment_Activity__c
                WHERE Id = :activity.Id
            ];

            Test.startTest();
            PaymentProcessorMock mockProcessor = new PaymentProcessorMock();
            Payment_Activity__c resp = activity.clone(true,true,true,true);
            resp.Status__c = 'Success';
            mockProcessor.registerResponse('getPaymentActivityStatus', new List<Payment_Activity__c>{ resp });
            PaymentProcessor processor = (PaymentProcessor) Test.createStub(PaymentProcessor.class, mockProcessor);
            
            PaymentProcessorFactoryMock mockFactory = new PaymentProcessorFactoryMock(processor);
            PaymentProcessorFactory factory = (PaymentProcessorFactory) Test.createStub(PaymentProcessorFactory.class, mockFactory);

            PaymentGateway gtwy = new PaymentGateway();
            gtwy.factory = factory;
            List<Payment_Activity__c> results = gtwy.getPaymentActivityStatus(activities);
            Test.stopTest();

            System.assertEquals(1, results.size());
            System.assertEquals('Success', results[0].Status__c);
        }
    }

    @IsTest
    static void testSaleBulkPaymentTypeNotSupported() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Payment_Method__c pm = new Payment_Method__c(
                    Customer__c = testData.accounts[0].Id,
                    Payment_Processor__c = testData.paymentProcessors[0].Id,
                    Payment_Method_Type__c = 'BTC'
            );

            Cash_Receipt__c cr = new Cash_Receipt__c(
                    Account__c = testData.accounts[0].Id,
                    Amount__c = 100,
                    Bank_Account__c = testData.glAccounts[0].Id,
                    Accounting_Period__c = testData.accounts[0].Id
            );

            Test.startTest();
            PaymentGateway gtwy = new PaymentGateway();
            List<PaymentSaleItem> saleItems = gtwy.sale(new List<PaymentSaleItem>{new PaymentSaleItem(pm, cr, null)});
            Test.stopTest();

            System.assertNotEquals(null, saleItems);
            System.assert(!saleItems.isEmpty());
            System.assertEquals(Label.ERR_PAYMENTS_UNSUPPORTED_PAYMENT_MEHTHOD_TYPE, saleItems[0].errors.errorsHolder[0].get('message'));
        }
    }

    @IsTest
    static void testSaleBulkInvalidAmount() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Payment_Method__c pm = new Payment_Method__c(
                    Customer__c = testData.accounts[0].Id,
                    Payment_Method_Type__c = 'Bank Account'
            );

            List<Cash_Receipt__c> crs = new List<Cash_Receipt__c>{
                    new Cash_Receipt__c(
                            Account__c = testData.accounts[0].Id,
                            Amount__c = null,
                            Bank_Account__c = testData.glAccounts[0].Id,
                            Accounting_Period__c = testData.accounts[0].Id
                    ),
                    new Cash_Receipt__c(
                            Account__c = testData.accounts[0].Id,
                            Amount__c = 0,
                            Bank_Account__c = testData.glAccounts[0].Id,
                            Accounting_Period__c = testData.accounts[0].Id
                    ),
                    new Cash_Receipt__c(
                            Account__c = testData.accounts[0].Id,
                            Amount__c = -100,
                            Bank_Account__c = testData.glAccounts[0].Id,
                            Accounting_Period__c = testData.accounts[0].Id
                    )
            };

            Test.startTest();

            PaymentGateway gtwy = new PaymentGateway();
            List<PaymentSaleItem> saleItems = new List<PaymentSaleItem>();
            for (Cash_Receipt__c cr : crs) {
                saleItems.add(new PaymentSaleItem(pm, cr, null));
            }
            saleItems = gtwy.sale(saleItems);

            Test.stopTest();

            System.assertNotEquals(null, saleItems);
            for (PaymentSaleItem saleItem : saleItems) {
                System.assertEquals(Label.ERR_PAYMENTS_SALE_NEGATIVE_AMOUNT, saleItem.errors.errorsHolder[0].get('message'));
            }
        }
    }

    @IsTest
    static void testSaleBulkNoAccount() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Payment_Method__c pm = new Payment_Method__c(
                    Customer__c = testData.accounts[0].Id,
                    Payment_Method_Type__c = 'Credit Card'
            );

            Cash_Receipt__c cr = new Cash_Receipt__c(
                    Account__c = testData.accounts[0].Id,
                    Amount__c = 100,
                    Accounting_Period__c = testData.accounts[0].Id
            );

            Test.startTest();
            PaymentGateway gtwy = new PaymentGateway();
            List<PaymentSaleItem> saleItems = gtwy.sale(new List<PaymentSaleItem>{new PaymentSaleItem(pm, cr, null)});
            Test.stopTest();

            System.assertNotEquals(null, saleItems);
            System.assertEquals(
                    String.format(Label.ERR_X_IS_REQUIRED, new List<String>{Cash_Receipt__c.Bank_Account__c.getDescribe().getLabel()}),
                    saleItems[0].errors.errorsHolder[0].get('message')
            );
        }
    }

    @IsTest
    static void testSaleBulkNoAccountingPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Payment_Method__c pm = new Payment_Method__c(
                    Customer__c = testData.accounts[0].Id,
                    Payment_Method_Type__c = 'Credit Card'
            );

            Cash_Receipt__c cr = new Cash_Receipt__c(
                    Account__c = testData.accounts[0].Id,
                    Amount__c = 100,
                    Bank_Account__c = testData.glAccounts[0].Id
            );

            Test.startTest();
            PaymentGateway gtwy = new PaymentGateway();
            List<PaymentSaleItem> saleItems = gtwy.sale(new List<PaymentSaleItem>{new PaymentSaleItem(pm, cr, null)});
            Test.stopTest();

            System.assertNotEquals(null, saleItems);
            System.assertEquals(
                    String.format(Label.ERR_X_IS_REQUIRED, new List<String>{Cash_Receipt__c.Accounting_Period__c.getDescribe().getLabel()}),
                    saleItems[0].errors.errorsHolder[0].get('message')
            );
        }
    }
    @isTest
    static void testPreProcessSaleWithJPY() {
        TestDataSuite testData = TestDataSuite.getInstance();
        try {
            testData.enableMultiCurrency();
            MultiCurrencyHandler.isMultiCurrencyEnabled = true;
        } catch (TestDataSuite.TestDataSuiteException e) {
            // MC not enabled for org
            return;
        }
        System.runAs(testData.users[1]) {
            Cash_Receipt__c cReciept = new Cash_Receipt__c(
                Account__c = testData.accounts.get(1).Id,
                Amount__c = 400.90,
                Status__c = 'Approved',
                Receipt_Date__c = System.today(),
                Purpose__c = 'Customer Receipt',
                Payment_Reference__c = '12345',
                Accounting_Period__c = testData.acctPeriods.get(0).Id
            );
            cReciept.put('CurrencyISOCode','JPY');

            PaymentSaleItem item = new PaymentSaleItem(null, cReciept);
            PaymentGateway.preProcessSale(item);

            Assert.areEqual(400, item.cashReceipt.Amount__c);
        }
    }
    @isTest
    static void testPreProcessSaleWithUSD() {
        TestDataSuite testData = TestDataSuite.getInstance();
        try {
            testData.enableMultiCurrency();
            MultiCurrencyHandler.isMultiCurrencyEnabled = true;
        } catch (TestDataSuite.TestDataSuiteException e) {
            // MC not enabled for org
            return;
        }

        System.runAs(testData.users[1]) {
            Decimal amount = 400.90;
            Cash_Receipt__c cReciept = new Cash_Receipt__c(
                Account__c = testData.accounts.get(1).Id,
                Amount__c = amount,
                Status__c = 'Approved',
                Receipt_Date__c = System.today(),
                Purpose__c = 'Customer Receipt',
                Payment_Reference__c = '12345',
                Accounting_Period__c = testData.acctPeriods.get(0).Id
            );
            cReciept.put('CurrencyISOCode','USD');

            PaymentSaleItem item = new PaymentSaleItem(null, cReciept);
            PaymentGateway.preProcessSale(item);

            Assert.areEqual(amount, item.cashReceipt.Amount__c);
        }
    }

    @isTest
    static void testPreProcessSaleRounding() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Decimal amount = 400.99999999999;
            Decimal conversion = 0.2511111111;
            Decimal fees = 12.3456789;

            Cash_Receipt__c cReciept = new Cash_Receipt__c(
                Account__c = testData.accounts.get(1).Id,
                Amount__c = amount,
                Currency_Conversion_Rate__c = conversion,
                Convenience_Fees_Charged__c = fees,
                Status__c = 'Approved',
                Receipt_Date__c = System.today(),
                Purpose__c = 'Customer Receipt',
                Payment_Reference__c = '12345',
                Accounting_Period__c = testData.acctPeriods.get(0).Id
            );

            PaymentSaleItem item = new PaymentSaleItem(null, cReciept);
            PaymentGateway.preProcessSale(item);

            Assert.areEqual(amount.setScale(2, RoundingMode.HALF_UP), item.cashReceipt.Amount__c);
            Assert.areEqual(conversion.setScale(6, RoundingMode.HALF_UP), item.cashReceipt.Currency_Conversion_Rate__c);
            Assert.areEqual(fees.setScale(2, RoundingMode.HALF_UP), item.cashReceipt.Convenience_Fees_Charged__c);
        }
    }
    // void Missing inputs errors
    @IsTest
    static void testVoidMissingActivity() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            PaymentGateway gtwy = new PaymentGateway();
            
            Exception expectedEx;
            try {
                gtwy.voidTransaction(null);
                Assert.fail(Label.ERR_X_IS_REQUIRED + ' Exception expected.');
            } catch (PaymentGateway.PaymentGatewayException e) {
                expectedEx = e;
            }

            Assert.areNotEqual(null, expectedEx);
            String expectedMsg = String.format(
                Label.ERR_X_IS_REQUIRED,
                new List<String> {SObjectType.Payment_Activity__c.getLabel()}
            );
            Assert.areEqual(expectedMsg, expectedEx.getMessage());

            expectedEx = null;

            try {
                gtwy.voidTransaction(null);
                Assert.fail(Label.ERR_X_IS_REQUIRED + ' Exception expected.');
            } catch (PaymentGateway.PaymentGatewayException e) {
                expectedEx = e;
            }
            Test.stopTest();

            Assert.areNotEqual(null, expectedEx);
            expectedMsg = String.format(
                Label.ERR_X_IS_REQUIRED,
                new List<String> {SObjectType.Payment_Activity__c.getLabel()}
            );
            Assert.areEqual(expectedMsg, expectedEx.getMessage());
        }
    }
    @IsTest
    static void testVoidMissingMerchantReference() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Payment_Activity__c activity = new Payment_Activity__c(
                Merchant_Reference__c = ''
            );
            PaymentGateway gtwy = new PaymentGateway();
            
            Exception expectedEx;
            try {
                gtwy.voidTransaction(activity);
                Assert.fail(Label.ERR_X_IS_REQUIRED + ' Exception expected.');
            } catch (PaymentGateway.PaymentGatewayException e) {
                expectedEx = e;
            }

            Assert.areNotEqual(null, expectedEx);
            String expectedMsg = String.format(
                Label.ERR_X_IS_REQUIRED,
                new List<String> {Payment_Activity__c.Merchant_Reference__c.getDescribe().getLabel()}
            );
            Assert.areEqual(expectedMsg, expectedEx.getMessage());

            expectedEx = null;

            try {
                gtwy.voidTransaction(activity);
                Assert.fail(Label.ERR_X_IS_REQUIRED + ' Exception expected.');
            } catch (PaymentGateway.PaymentGatewayException e) {
                expectedEx = e;
            }
            Test.stopTest();

            Assert.areNotEqual(null, expectedEx);
            expectedMsg = String.format(
                Label.ERR_X_IS_REQUIRED,
                new List<String> {Payment_Activity__c.Merchant_Reference__c.getDescribe().getLabel()}
            );
            Assert.areEqual(expectedMsg, expectedEx.getMessage());
        }
    }
    @IsTest
    static void testVoidMissingCashReceipt() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Payment_Activity__c activity = new Payment_Activity__c(
                Cash_Receipt__c = null,
                Merchant_Reference__c = '1234'
            );
            PaymentGateway gtwy = new PaymentGateway();
            
            Exception expectedEx;
            try {
                gtwy.voidTransaction(activity);
                Assert.fail(Label.ERR_X_IS_REQUIRED + ' Exception expected.');
            } catch (PaymentGateway.PaymentGatewayException e) {
                expectedEx = e;
            }

            Assert.areNotEqual(null, expectedEx);
            String expectedMsg = String.format(
                Label.ERR_X_IS_REQUIRED,
                new List<String> {SObjectType.Cash_Receipt__c.getLabel()}
            );
            Assert.areEqual(expectedMsg, expectedEx.getMessage());

            expectedEx = null;

            try {
                gtwy.voidTransaction(activity);
                Assert.fail(Label.ERR_X_IS_REQUIRED + ' Exception expected.');
            } catch (PaymentGateway.PaymentGatewayException e) {
                expectedEx = e;
            }
            Test.stopTest();

            Assert.areNotEqual(null, expectedEx);
            expectedMsg = String.format(
                Label.ERR_X_IS_REQUIRED,
                new List<String> {SObjectType.Cash_Receipt__c.getLabel()}
            );
            Assert.areEqual(expectedMsg, expectedEx.getMessage());
        }
    }
    @IsTest
    static void testVoidMissingPaymentProcessor() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();

            Payment_Processor__c pp = testData.paymentProcessors[3];

            Cash_Receipt__c cReciept = new Cash_Receipt__c(
                Account__c = testData.accounts.get(1).Id,
                Amount__c = 400,
                Status__c = 'Approved',
                Receipt_Date__c = System.today(),
                Purpose__c = 'Customer Receipt',
                Payment_Reference__c = '12345',
                Accounting_Period__c = testData.acctPeriods.get(0).Id,
                Convenience_Fees_Charged__c = 10
            );

            INSERT cReciept;

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = pp.Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = pp.Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Bank Account', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Bank_Account_Type__c ='Individual',Default__c=true);
            INSERT pm;

            Payment_Activity__c activity = new Payment_Activity__c(
                Amount__c = cReciept.Amount__c,
                Payment_Method__c = pm.Id,
                Cash_Receipt__c = cReciept.Id,
                Merchant_Reference__c = cReciept.Payment_Reference__c
            );

            insert activity;

            List<Payment_Activity__c> activites = [SELECT Id, Cash_Receipt__r.Payment_Processor__c,Cash_Receipt__c, Merchant_Reference__c FROM Payment_Activity__c WHERE Id = :activity.Id];
            Assert.areEqual(1, activites.size());

            PaymentGateway gtwy = new PaymentGateway();
            
            Exception expectedEx;
            try {
                gtwy.voidTransaction(activites[0]);
                Assert.fail(Label.ERR_X_IS_REQUIRED + ' Exception expected.');
            } catch (PaymentGateway.PaymentGatewayException e) {
                expectedEx = e;
            }

            Assert.areNotEqual(null, expectedEx);
            String expectedMsg = String.format(
                Label.ERR_X_IS_REQUIRED,
                new List<String> {SObjectType.Payment_Processor__c.getLabel()}
            );
            Assert.areEqual(expectedMsg, expectedEx.getMessage());

            expectedEx = null;

            try {
                gtwy.voidTransaction(activites[0]);
                Assert.fail(Label.ERR_X_IS_REQUIRED + ' Exception expected.');
            } catch (PaymentGateway.PaymentGatewayException e) {
                expectedEx = e;
            }
            Test.stopTest();

            Assert.areNotEqual(null, expectedEx);
            expectedMsg = String.format(
                Label.ERR_X_IS_REQUIRED,
                new List<String> {SObjectType.Payment_Processor__c.getLabel()}
            );
            Assert.areEqual(expectedMsg, expectedEx.getMessage());
        }
    }
    @IsTest
    static void testVoidInvalidPaymentMethodType() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();

            Payment_Processor__c pp = testData.paymentProcessors[3];

            Cash_Receipt__c cReciept = new Cash_Receipt__c(
                Account__c = testData.accounts.get(1).Id,
                Amount__c = 400,
                Status__c = 'Approved',
                Receipt_Date__c = System.today(),
                Purpose__c = 'Customer Receipt',
                Payment_Reference__c = '12345',
                Accounting_Period__c = testData.acctPeriods.get(0).Id,
                Convenience_Fees_Charged__c = 10,
                Payment_Processor__c = pp.Id
            );

            INSERT cReciept;

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = pp.Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = pp.Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Virtual Card', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Default__c=true);
            INSERT pm;

            Payment_Activity__c activity = new Payment_Activity__c(
                Amount__c = cReciept.Amount__c,
                Payment_Method__c = pm.Id,
                Cash_Receipt__c = cReciept.Id,
                Merchant_Reference__c = cReciept.Payment_Reference__c
            );

            insert activity;

            List<Payment_Activity__c> activites = [SELECT Id, Cash_Receipt__r.Payment_Processor__c,Cash_Receipt__c, 
                                                    Merchant_Reference__c,Payment_Method__r.Payment_Method_Type__c,
                                                    Payment_Method__c  
                                                    FROM Payment_Activity__c WHERE Id = :activity.Id];
            Assert.areEqual(1, activites.size());

            PaymentGateway gtwy = new PaymentGateway();
            
            Exception expectedEx;
            try {
                gtwy.voidTransaction(activites[0]);
                Assert.fail(Label.ERR_X_IS_REQUIRED + ' Exception expected.');
            } catch (PaymentGateway.PaymentGatewayException e) {
                expectedEx = e;
            }

            Assert.areNotEqual(null, expectedEx);
            Assert.areEqual(expectedEx.getMessage(), Label.ERR_CARDKNOX_INVALID_PAYMENT_METHOD_TYPE);

            expectedEx = null;

            try {
                gtwy.voidTransaction(activites[0]);
                Assert.fail(Label.ERR_X_IS_REQUIRED + ' Exception expected.');
            } catch (PaymentGateway.PaymentGatewayException e) {
                expectedEx = e;
            }
            Test.stopTest();

            Assert.areNotEqual(null, expectedEx);
            Assert.areEqual(expectedEx.getMessage(), Label.ERR_CARDKNOX_INVALID_PAYMENT_METHOD_TYPE);
        }
    }
    static void testGetPaymentActivityStatusError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Payment_Processor_Customer__c ppc =  new Payment_Processor_Customer__c(
                Account__c = testData.accounts.get(0).Id,
                Processor__c = testData.paymentProcessors.get(0).Id,
                External_Id__c = 'abc123'
            );
            insert ppc;

            Payment_Method__c pm = new Payment_Method__c(
                Type__c = 'Visa',
                Status__c = StripeService.PAYMENT_METHOD_STATUS_ACTIVE,
                Expiration_Month__c = '12',
                Expiration_Year__c = '2099',
                Last_Four_Digits__c = '4444',
                External_Id__c = 'stripe-card-1',
                Customer__c = ppc.Account__c,
                Default__c = true,
                Payment_Processor__c = ppc.Processor__c
            );
            insert pm; 

            Cash_Receipt__c cr = new Cash_Receipt__c(
                Account__c = ppc.Account__c,
                Amount__c = 100,
                Payment_Reference__c = '0000000994',
                Receipt_Date__c = testData.acctPeriods[0].Start_Date__c,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Credit_GL_Account__c = testData.glAccounts.get(16).Id,
                Payment_Processor__c = pm.Payment_Processor__c
            );
            insert cr;

            Payment_Activity__c activity = new Payment_Activity__c(
                Amount__c = cr.Amount__c,
                Cash_Receipt__c = cr.Id,
                Payment_Method__c = pm.Id,
                Status__c = 'Pending',
                Type__c = 'Payment'
            ); 
            insert activity;

            List<Payment_Activity__c> activities = [
                SELECT
                    Id,
                    Name,
                    Cash_Receipt__c,
                    Cash_Receipt__r.Name,
                    Cash_Receipt__r.Payment_Reference__c,
                    Status__c,
                    Amount__c,
                    Error_Message__c,
                    Error_Type__c,
                    Payment_Method__c,
                    Payment_Method__r.External_Id__c,
                    Type__c,
                    Payment_Method__r.Payment_Processor__c,
                    Payment_Method__r.Payment_Processor__r.Type__c
                FROM Payment_Activity__c
                WHERE Id = :activity.Id
            ];

            Test.startTest();
            PaymentProcessorMock mockProcessor = new PaymentProcessorMock();
            Payment_Activity__c resp = activity.clone(true,true,true,true);
            resp.Status__c = 'Error';
            mockProcessor.registerResponse('getPaymentActivityStatus', new List<Payment_Activity__c>{ resp });
            PaymentProcessor processor = (PaymentProcessor) Test.createStub(PaymentProcessor.class, mockProcessor);
            
            PaymentProcessorFactoryMock mockFactory = new PaymentProcessorFactoryMock(processor);
            PaymentProcessorFactory factory = (PaymentProcessorFactory) Test.createStub(PaymentProcessorFactory.class, mockFactory);

            PaymentGateway gtwy = new PaymentGateway();
            gtwy.factory = factory;
            List<Payment_Activity__c> results = gtwy.getPaymentActivityStatus(activities);
            Test.stopTest();

            System.assertEquals(1, results.size());
            System.assertEquals('Error', results[0].Status__c);
        }
    }

    public class PaymentProcessorFactoryMock implements System.StubProvider {
        private PaymentProcessor pmtProc;

        public PaymentProcessorFactoryMock(PaymentProcessor pmtProc) {
            this.pmtProc = pmtProc;
        }

        public Object handleMethodCall(
                Object stubbedObject,
                String stubbedMethodName,
                Type returnType,
                List<Type> listOfParamTypes,
                List<String> listOfParamNames,
                List<Object> listOfArgs) {

            if (stubbedMethodName == 'getPaymentProcessor') {
                return pmtProc;
            }
            return null;
        }
    }

    public class PaymentProcessorMock implements System.StubProvider {
        private Map<String,Object> resps;

        public PaymentProcessorMock() {
            this.resps = new Map<String,Object>();
        }

        public void registerResponse(String methodName, Object response) {
            resps.put(methodName, response);
        }

        public Object handleMethodCall(
                Object stubbedObject,
                String stubbedMethodName,
                Type returnType,
                List<Type> listOfParamTypes,
                List<String> listOfParamNames,
                List<Object> listOfArgs) {

            if (resps.containsKey(stubbedMethodName)) {
                return resps.get(stubbedMethodName);
            }
            return null;
        }
    }

}