@IsTest
public with sharing class StripeProcessorV1Test {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    // create customer
    @IsTest
    static void testCreateCustomer() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            HttpCalloutMock mock = StripeServiceTest.createResponseGenerators();
            Test.setMock(HttpCalloutMock.class, mock);

            Test.startTest();
            Payment_Processor_Customer__c customer =  new Payment_Processor_Customer__c(
                Account__c = testData.accounts.get(0).Id,
                Processor__c = testData.paymentProcessors.get(0).Id
            );

            StripeProcessorV1 stripe = new StripeProcessorV1();
            customer = stripe.createCustomer(customer);
            Test.stopTest();

            List<Payment_Processor_Customer__c> customers = [
                SELECT Id, External_Id__c, Account__c, Processor__c
                FROM Payment_Processor_Customer__c
                WHERE Id = :customer.Id
            ];
            System.assert(customers != null && !customers.isEmpty());
            System.assertNotEquals(null, customers.get(0).External_Id__c);
            System.assertEquals(testData.accounts.get(0).Id, customers.get(0).Account__c);
            System.assertEquals(testData.paymentProcessors.get(0).Id, customers.get(0).Processor__c);
        }
    }

    // create payment method: customer doesn't exist
    @IsTest
    static void testCreatePaymentMethodNoAccount() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Payment_Method__c pm = new Payment_Method__c(
                Payment_Processor__c = testData.paymentProcessors.get(0).Id,
                Customer__c = FinancialSuiteUtils.getFakeId(Account.SObjectType),
                External_Id__c = 'abc123',
                Payment_Method_Type__c = 'Credit Card'
            );
            StripeProcessorV1 stripe = new StripeProcessorV1();
            
            Exception expectedEx;
            try {
                stripe.createPaymentMethod(pm, StripeServiceTest.TOKEN_ID);
            } catch (StripeProcessorV1.StripeProcessorV1Exception e) {
                expectedEx = e;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            System.assertEquals(Label.ERR_PAYMENT_METHOD_ACCT_MISSING, expectedEx.getMessage());
        }
    }

    // create payment method: no customer exists yet (in SF)
    @IsTest
    static void testCreatePaymentMethodNoCustomer() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            MultiRequestMock mock = (MultiRequestMock) StripeServiceTest.createResponseGenerators();
            String body = '{' +
                '"id": "cus_9M8lj1ufREF2SR",' +
                '"object": "customer",' +
                '"account_balance": 0,' +
                '"created": 1476193171,' +
                '"currency": "usd",' +
                '"default_source": "card_193QTfGKbd1fBtzkOvmzCTXw",' +
                '"sources": {' +
                    '"stripeObject": "list",' +
                    '"stripeData": [' +
                        '{' +
                            '"id": "card_193QTfGKbd1fBtzkOvmzCTXw",' +
                            '"object": "card",' +
                            '"address_city": null,' +
                            '"address_country": null,' +
                            '"address_line1": null,' +
                            '"address_line1_check": null,' +
                            '"address_line2": null,' +
                            '"address_state": null,' +
                            '"address_zip": null,' +
                            '"address_zip_check": null,' +
                            '"brand": "Discover",' +
                            '"country": "US",' +
                            '"customer": "cus_9M8lj1ufREF2SR",' +
                            '"cvc_check": "pass",' +
                            '"dynamic_last4": null,' +
                            '"exp_month": 8,' +
                            '"exp_year": 2019,' +
                            '"fingerprint": "' + StripeServiceTest.FINGERPRINT + '",' +
                            '"funding": "credit",' +
                            '"last4": "1117",' +
                            '"metadata": {' +
                            '},' +
                            '"name": "Test",' +
                            '"tokenization_method": null' +
                        '}' +
                    ']' +
                '}' +
            '}';
            SingleRequestMock createCustomerMock = new SingleRequestMock(
                200,
                'Complete',
                body,
                new Map<String, String>{'Content-Type' => 'application/json'}
            );
            mock.addRequestMock(StripeService.CUSTOMER_URL, createCustomerMock);
            Test.setMock(HttpCalloutMock.class, mock);

            List<Payment_Method__c> methods = [
                SELECT Id 
                FROM Payment_Method__c 
                WHERE Payment_Processor__c = :testData.paymentProcessors.get(0).Id 
                AND Customer__c = :testData.accounts.get(0).Id
            ];
            System.assertEquals(0, methods.size());

            Test.startTest();
            StripeProcessorV1 stripe = new StripeProcessorV1();
            stripe.createPaymentMethod(new Payment_Method__c(
                Payment_Processor__c = testData.paymentProcessors.get(0).Id,
                Customer__c = testData.accounts.get(0).Id,
                External_Id__c = StripeServiceTest.TOKEN_ID,
                Payment_Method_Type__c = 'Credit Card'
            ), StripeServiceTest.TOKEN_ID);
            Test.stopTest();

            methods = [
                SELECT Id 
                FROM Payment_Method__c 
                WHERE Payment_Processor__c = :testData.paymentProcessors.get(0).Id 
                AND Customer__c = :testData.accounts.get(0).Id
            ];
            System.assertEquals(1, methods.size());
        }
    }

    // create payment method: customer already exists (in SF)
    @IsTest
    static void testCreatePaymentMethodCustomerExists() {
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

            List<Payment_Method__c> methods = [
                SELECT Id 
                FROM Payment_Method__c 
                WHERE Payment_Processor__c = :c.Processor__c 
                AND Customer__c = :c.Account__c
            ];
            System.assertEquals(0, methods.size());

            Test.startTest();
            StripeProcessorV1 stripe = new StripeProcessorV1();
            stripe.createPaymentMethod(new Payment_Method__c(
                Payment_Processor__c = c.Processor__c,
                Customer__c = c.Account__c,
                External_Id__c = StripeServiceTest.TOKEN_ID,
                Payment_Method_Type__c = 'Credit Card'
            ), StripeServiceTest.TOKEN_ID);
            Test.stopTest();

            methods = [
                SELECT Id 
                FROM Payment_Method__c 
                WHERE Payment_Processor__c = :c.Processor__c 
                AND Customer__c = :c.Account__c
            ];
            System.assertEquals(1, methods.size());
        }
    }

    // cc sale
    @IsTest
    static void testCCSale() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            HttpCalloutMock mock = StripeServiceTest.createResponseGenerators();
            Test.setMock(HttpCalloutMock.class, mock);

            Payment_Processor_Customer__c customer =  new Payment_Processor_Customer__c(
                Account__c = testData.accounts.get(0).Id,
                Processor__c = testData.paymentProcessors.get(0).Id,
                External_Id__c = 'StripeCustomerId_Success'
            );
            insert customer;

            Payment_Method__c pm = new Payment_Method__c(
                Payment_Processor__c = customer.Processor__c,
                Customer__c = customer.Account__c,
                External_Id__c = 'StripeCustomerId_Success',
                Last_Four_Digits__c = '1234',
                Type__c = 'Visa',
                Expiration_Month__c = '01',
                Expiration_Year__c = '99',
                Payment_Method_Type__c = 'Credit Card'
            );
            insert pm;

            Cash_Receipt__c cr = new Cash_Receipt__c(
                Amount__c = 100,
                Account__c = testData.accounts[0].Id,
                Bank_Account__c = testData.glAccounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id
            );

            Test.startTest();
            StripeProcessorV1 stripe = new StripeProcessorV1();
            List<PaymentSaleItem> activity = stripe.ccSale(new List<PaymentSaleItem> { new PaymentSaleItem(pm, cr)});
            Test.stopTest();

            System.assertNotEquals(null, activity[0].paymentActivity);
            System.assertEquals(cr.Id, activity[0].paymentActivity.Cash_Receipt__c);
            System.assertEquals(pm.Id, activity[0].paymentActivity.Payment_Method__c);
            System.assertEquals('Success', activity[0].paymentActivity.Status__c);
        }
    }

    // cc sale bulk
    @IsTest
    static void testCCSaleBulk() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            HttpCalloutMock mock = StripeServiceTest.createResponseGenerators();
            Test.setMock(HttpCalloutMock.class, mock);

            Payment_Processor_Customer__c customer =  new Payment_Processor_Customer__c(
                    Account__c = testData.accounts.get(0).Id,
                    Processor__c = testData.paymentProcessors.get(0).Id,
                    External_Id__c = 'StripeCustomerId_Success'
            );
            insert customer;

            Payment_Method__c pm = new Payment_Method__c(
                    Payment_Processor__c = customer.Processor__c,
                    Customer__c = customer.Account__c,
                    External_Id__c = 'StripeCustomerId_Success',
                    Last_Four_Digits__c = '1234',
                    Type__c = 'Visa',
                    Expiration_Month__c = '01',
                    Expiration_Year__c = '99',
                    Payment_Method_Type__c = 'Credit Card'
            );
            insert pm;

            Cash_Receipt__c cr = new Cash_Receipt__c(
                    Amount__c = 100,
                    Account__c = testData.accounts[0].Id,
                    Bank_Account__c = testData.glAccounts[0].Id,
                    Accounting_Period__c = testData.acctPeriods[0].Id
            );

            Test.startTest();
            StripeProcessorV1 stripe = new StripeProcessorV1();
            List<PaymentSaleItem> saleItems = stripe.ccSale(new List<PaymentSaleItem>{new PaymentSaleItem(pm, cr, null)});
            Test.stopTest();

            System.assertNotEquals(null, saleItems);
            System.assert(!saleItems.isEmpty());
            System.assertEquals(cr.Id, saleItems[0].paymentActivity.Cash_Receipt__c);
            System.assertEquals(pm.Id, saleItems[0].paymentActivity.Payment_Method__c);
            System.assertEquals('Success', saleItems[0].paymentActivity.Status__c);
        }
    }

    // cc sale bulk: missing customer
    @IsTest
    static void testCCSaleBulkNoCustomer() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            HttpCalloutMock mock = StripeServiceTest.createResponseGenerators();
            Test.setMock(HttpCalloutMock.class, mock);

            Payment_Method__c pm = new Payment_Method__c(
                    Payment_Processor__c = testData.paymentProcessors.get(0).Id,
                    Customer__c = testData.accounts.get(0).Id,
                    External_Id__c = 'StripeCustomerId_Success',
                    Last_Four_Digits__c = '1234',
                    Type__c = 'Visa',
                    Expiration_Month__c = '01',
                    Expiration_Year__c = '99',
                    Payment_Method_Type__c = 'Credit Card'
            );
            insert pm;

            Cash_Receipt__c cr = new Cash_Receipt__c(
                    Amount__c = 100
            );

            Test.startTest();
            StripeProcessorV1 stripe = new StripeProcessorV1();
            List<PaymentSaleItem> saleItems = stripe.ccSale(new List<PaymentSaleItem>{new PaymentSaleItem(pm, cr, null)});
            Test.stopTest();

            System.assertNotEquals(null, saleItems);
            System.assert(!saleItems.isEmpty());
            System.assertEquals(Label.ERR_PAYMENTS_NO_CUSTOMER_FOR_PMT_METHOD, saleItems[0].errors.errorsHolder[0].get('message'));
        }
    }

    // cc sale bulk
    @IsTest
    static void testCCSaleBulkCRNotSaved() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            HttpCalloutMock mock = StripeServiceTest.createResponseGenerators();
            Test.setMock(HttpCalloutMock.class, mock);

            Payment_Processor_Customer__c customer =  new Payment_Processor_Customer__c(
                    Account__c = testData.accounts.get(0).Id,
                    Processor__c = testData.paymentProcessors.get(0).Id,
                    External_Id__c = 'StripeCustomerId_Success'
            );
            insert customer;

            Payment_Method__c pm = new Payment_Method__c(
                    Payment_Processor__c = customer.Processor__c,
                    Customer__c = customer.Account__c,
                    External_Id__c = 'StripeCustomerId_Success',
                    Last_Four_Digits__c = '1234',
                    Type__c = 'Visa',
                    Expiration_Month__c = '01',
                    Expiration_Year__c = '99',
                    Payment_Method_Type__c = 'Credit Card'
            );
            insert pm;

            Cash_Receipt__c cr = new Cash_Receipt__c(
                    Amount__c = 100,
                    Account__c = testData.accounts[0].Id,
                    Bank_Account__c = testData.glAccounts[0].Id
            );

            Test.startTest();
            StripeProcessorV1 stripe = new StripeProcessorV1();
            List<PaymentSaleItem> saleItems = stripe.ccSale(new List<PaymentSaleItem>{new PaymentSaleItem(pm, cr, null)});
            Test.stopTest();

            System.assertNotEquals(null, saleItems);
            System.assert(!saleItems.isEmpty());
            System.assertEquals(false,saleItems[0].errors.errorsHolder[0].get('message').contains(Label.ERR_PAYMENTS_STRIPE_CREATE_CHARGE_CR));
        }
    }

    // cc sale idempotentcy error
    @IsTest
    static void testCCSaleIdempotencyError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            String requestLogUrl = 'https://dashboard.stripe.com/test/logs/req_5aqv4vAvnVGu4d?t=1677266245';
            HttpCalloutMock mockResp = new SingleRequestMock(
                400,
                'Bad Request',
                '{' +
                    '"error": {' +
                        '"message": "Keys for idempotent requests can only be used with the same parameters they were first used with. Try using a key other than \'2\' if you meant to execute a different request.",' +
                        '"request_log_url": "' + requestLogUrl + '",' +
                        '"type": "idempotency_error"' +
                    '}' +
                '}',
                new Map<String, String>{'Content-Type' => 'application/json'}
            );
            Test.setMock(HttpCalloutMock.class, mockResp);

            Payment_Processor_Customer__c customer =  new Payment_Processor_Customer__c(
                Account__c = testData.accounts.get(0).Id,
                Processor__c = testData.paymentProcessors.get(0).Id,
                External_Id__c = 'StripeCustomerId_Success'
            );
            insert customer;

            Payment_Method__c pm = new Payment_Method__c(
                Payment_Processor__c = customer.Processor__c,
                Customer__c = customer.Account__c,
                External_Id__c = 'StripeCustomerId_Success',
                Last_Four_Digits__c = '1234',
                Type__c = 'Visa',
                Expiration_Month__c = '01',
                Expiration_Year__c = '99',
                Payment_Method_Type__c = 'Credit Card'
            );
            insert pm;

            Cash_Receipt__c cr = new Cash_Receipt__c(
                Amount__c = 100,
                Account__c = testData.accounts[0].Id,
                Bank_Account__c = testData.glAccounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id
            );

            Test.startTest();
            StripeProcessorV1 stripe = new StripeProcessorV1();
            List<PaymentSaleItem> activity = stripe.ccSale(new List<PaymentSaleItem> { new PaymentSaleItem(pm, cr)});
            Test.stopTest();

            Assert.isNotNull(activity);
            Assert.areEqual(1, activity.size());
            Assert.isNotNull(activity[0].errors);
            Assert.areEqual(Label.ERR_PAYMENTS_DUPLICATE_FOUND + ' ' + requestLogUrl, activity[0].errors.errorsHolder[0].get('message'));
            Assert.isNotNull(activity[0].paymentActivity);
            Assert.areEqual(PaymentActivityHelper.ERROR_STATUS, activity[0].paymentActivity.Status__c);
        }
    }

    // cc sale idempotency replay
    @IsTest
    static void testCCSaleIdempotencyReplay() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            HttpCalloutMock mock = StripeServiceTest.createResponseGenerators();
            Test.setMock(HttpCalloutMock.class, mock);

            Payment_Processor_Customer__c customer =  new Payment_Processor_Customer__c(
                Account__c = testData.accounts.get(0).Id,
                Processor__c = testData.paymentProcessors.get(0).Id,
                External_Id__c = 'StripeCustomerId_Success'
            );
            insert customer;

            Payment_Method__c pm = new Payment_Method__c(
                Payment_Processor__c = customer.Processor__c,
                Customer__c = customer.Account__c,
                External_Id__c = 'StripeCustomerId_Success',
                Last_Four_Digits__c = '1234',
                Type__c = 'Visa',
                Expiration_Month__c = '01',
                Expiration_Year__c = '99',
                Payment_Method_Type__c = 'Credit Card'
            );
            insert pm;

            Cash_Receipt__c cr = new Cash_Receipt__c(
                Amount__c = 100,
                Account__c = testData.accounts[0].Id,
                Bank_Account__c = testData.glAccounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Payment_Reference__c = 'ch_193QTxGKbd1fBtzkpIMfgZS1'
            );
            insert cr;
            cr = [SELECT Id, Name FROM Cash_Receipt__c WHERE Id = :cr.Id];

            Cash_Receipt__c duplicateCr = new Cash_Receipt__c(
                Amount__c = 100,
                Account__c = testData.accounts[0].Id,
                Bank_Account__c = testData.glAccounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id
            );

            Test.startTest();
            StripeProcessorV1 stripe = new StripeProcessorV1();
            List<PaymentSaleItem> activity = stripe.ccSale(new List<PaymentSaleItem> { new PaymentSaleItem(pm, duplicateCr)});
            Test.stopTest();

            Assert.isNotNull(activity);
            Assert.areEqual(1, activity.size());
            Assert.isNotNull(activity[0].errors);
            Assert.areEqual(Label.ERR_PAYMENTS_DUPLICATE_FOUND + ' ' + SObjectType.Cash_Receipt__c.getLabel() + ' ' + cr.Name, activity[0].errors.errorsHolder[0].get('message'));
        }
    }
            
    // getPaymentActivityStatus - success
    @IsTest
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

            SingleRequestMock resp = new SingleRequestMock(
                200,
                'Complete',
                StripeServiceTest.getChargeResponseBody(),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Map<String, HttpCalloutMock> resps = new Map<String, HttpCalloutMock>{
                StripeService.CHARGE_URL + '/' + cr.Payment_Reference__c => resp
            };

            HttpCalloutMock multiMock = new MultiRequestMock(resps);

            Test.setMock(HttpCalloutMock.class, multiMock);
            
            Test.startTest();
            StripeProcessorV1 proc = new StripeProcessorV1();
            List<Payment_Activity__c> updates = proc.getPaymentActivityStatus(activities);
            Test.stopTest();

            System.assertEquals(1, updates.size());
            System.assertEquals('Success', updates.get(0).Status__c);
        }
    }

    // getPaymentActivityStatus - mixed processors - success
    @IsTest
    static void testGetPaymentActivityStatusMixedProcs() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            List<Payment_Processor_Customer__c> ppcs = new List<Payment_Processor_Customer__c>{
                new Payment_Processor_Customer__c(
                    Account__c = testData.accounts.get(0).Id,
                    Processor__c = testData.paymentProcessors.get(0).Id,
                    External_Id__c = 'abc123'
                ),
                new Payment_Processor_Customer__c(
                    Account__c = testData.accounts.get(0).Id,
                    Processor__c = testData.paymentProcessors.get(1).Id,
                    External_Id__c = 'def456'
                )
            };
            insert ppcs;

            List<Payment_Method__c> pms = new List<Payment_Method__c> {
                new Payment_Method__c(
                    Type__c = 'Visa',
                    Status__c = StripeService.PAYMENT_METHOD_STATUS_ACTIVE,
                    Expiration_Month__c = '12',
                    Expiration_Year__c = '2099',
                    Last_Four_Digits__c = '4444',
                    External_Id__c = 'stripe-card-1',
                    Customer__c = ppcs[0].Account__c,
                    Default__c = false,
                    Payment_Processor__c = ppcs[0].Processor__c
                ),
                new Payment_Method__c(
                    Type__c = 'Visa',
                    Status__c = StripeService.PAYMENT_METHOD_STATUS_ACTIVE,
                    Expiration_Month__c = '11',
                    Expiration_Year__c = '2098',
                    Last_Four_Digits__c = '4445',
                    External_Id__c = 'stripe-card-2',
                    Customer__c = ppcs[1].Account__c,
                    Default__c = false,
                    Payment_Processor__c = ppcs[1].Processor__c
                )
            };
            insert pms; 

            List<Cash_Receipt__c> crs = new List<Cash_Receipt__c>{
                new Cash_Receipt__c(
                    Account__c = ppcs[0].Account__c,
                    Amount__c = 100,
                    Payment_Reference__c = '0000000994',
                    Receipt_Date__c = testData.acctPeriods[0].Start_Date__c,
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Purpose__c = 'Customer Receipt',
                    Bank_Account__c = testData.glAccounts.get(0).Id,
                    Credit_GL_Account__c = testData.glAccounts.get(16).Id,
                    Payment_Processor__c = pms[0].Payment_Processor__c
                ),
                new Cash_Receipt__c(
                    Account__c = ppcs[1].Account__c,
                    Amount__c = 100,
                    Payment_Reference__c = '0000000995',
                    Receipt_Date__c = testData.acctPeriods[0].Start_Date__c,
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Purpose__c = 'Customer Receipt',
                    Bank_Account__c = testData.glAccounts.get(0).Id,
                    Credit_GL_Account__c = testData.glAccounts.get(16).Id,
                    Payment_Processor__c = pms[1].Payment_Processor__c
                )
            };
            insert crs;

            List<Payment_Activity__c> pas = new List<Payment_Activity__c>{
                new Payment_Activity__c(
                    Amount__c = crs[0].Amount__c,
                    Cash_Receipt__c = crs[0].Id,
                    Payment_Method__c = pms[0].Id,
                    Status__c = 'Pending',
                    Type__c = 'Payment'
                ),
                new Payment_Activity__c(
                    Amount__c = crs[1].Amount__c,
                    Cash_Receipt__c = crs[1].Id,
                    Payment_Method__c = pms[1].Id,
                    Status__c = 'Pending',
                    Type__c = 'Payment'
                )
            }; 
            insert pas;

            Set<Id> paIds = new Set<Id>();
            for (Payment_Activity__c pa : pas) {
                paIds.add(pa.Id);
            }

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
                WHERE Id IN :paIds
            ];

            SingleRequestMock resp = new SingleRequestMock(
                200,
                'Complete',
                StripeServiceTest.getChargeResponseBody(),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Map<String, HttpCalloutMock> resps = new Map<String, HttpCalloutMock>{
                StripeService.CHARGE_URL + '/' + crs[0].Payment_Reference__c => resp,
                StripeService.CHARGE_URL + '/' + crs[1].Payment_Reference__c => resp
            };

            HttpCalloutMock multiMock = new MultiRequestMock(resps);

            Test.setMock(HttpCalloutMock.class, multiMock);
            
            Test.startTest();
            StripeProcessorV1 proc = new StripeProcessorV1();
            List<Payment_Activity__c> updates = proc.getPaymentActivityStatus(activities);
            Test.stopTest();

            System.assertEquals(2, updates.size());
            System.assertEquals('Success', updates.get(0).Status__c);
            System.assertEquals('Success', updates.get(1).Status__c);
        }
    }

    // getPaymentActivityStatus - error
    @IsTest
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

            SingleRequestMock resp = new SingleRequestMock(
                200,
                'Complete',
                StripeServiceTest.getErrorResponse(),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Map<String, HttpCalloutMock> resps = new Map<String, HttpCalloutMock>{
                StripeService.CHARGE_URL + '/' + cr.Payment_Reference__c => resp
            };

            HttpCalloutMock multiMock = new MultiRequestMock(resps);

            Test.setMock(HttpCalloutMock.class, multiMock);
            
            Test.startTest();
            StripeProcessorV1 proc = new StripeProcessorV1();
            List<Payment_Activity__c> updates = proc.getPaymentActivityStatus(activities);
            Test.stopTest();

            System.assertEquals(1, updates.size());
            System.assertEquals('Error', updates.get(0).Status__c);
        }
    }

    // getPaymentActivityStatus - partial failure
    @IsTest
    static void testGetPaymentActivityStatusPartialFaiulre() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            List<Payment_Processor_Customer__c> ppcs = new List<Payment_Processor_Customer__c>{
                new Payment_Processor_Customer__c(
                    Account__c = testData.accounts.get(0).Id,
                    Processor__c = testData.paymentProcessors.get(0).Id,
                    External_Id__c = 'abc123'
                ),
                new Payment_Processor_Customer__c(
                    Account__c = testData.accounts.get(0).Id,
                    Processor__c = testData.paymentProcessors.get(1).Id,
                    External_Id__c = 'def456'
                )
            };
            insert ppcs;

            List<Payment_Method__c> pms = new List<Payment_Method__c> {
                new Payment_Method__c(
                    Type__c = 'Visa',
                    Status__c = StripeService.PAYMENT_METHOD_STATUS_ACTIVE,
                    Expiration_Month__c = '12',
                    Expiration_Year__c = '2099',
                    Last_Four_Digits__c = '4444',
                    External_Id__c = 'stripe-card-1',
                    Customer__c = ppcs[0].Account__c,
                    Default__c = false,
                    Payment_Processor__c = ppcs[0].Processor__c
                ),
                new Payment_Method__c(
                    Type__c = 'Visa',
                    Status__c = StripeService.PAYMENT_METHOD_STATUS_ACTIVE,
                    Expiration_Month__c = '11',
                    Expiration_Year__c = '2098',
                    Last_Four_Digits__c = '4445',
                    External_Id__c = 'stripe-card-2',
                    Customer__c = ppcs[1].Account__c,
                    Default__c = false,
                    Payment_Processor__c = ppcs[1].Processor__c
                )
            };
            insert pms; 

            List<Cash_Receipt__c> crs = new List<Cash_Receipt__c>{
                new Cash_Receipt__c(
                    Account__c = ppcs[0].Account__c,
                    Amount__c = 100,
                    Payment_Reference__c = '0000000994',
                    Receipt_Date__c = testData.acctPeriods[0].Start_Date__c,
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Purpose__c = 'Customer Receipt',
                    Bank_Account__c = testData.glAccounts.get(0).Id,
                    Credit_GL_Account__c = testData.glAccounts.get(16).Id,
                    Payment_Processor__c = pms[0].Payment_Processor__c
                ),
                new Cash_Receipt__c(
                    Account__c = ppcs[1].Account__c,
                    Amount__c = 100,
                    Payment_Reference__c = '0000000995',
                    Receipt_Date__c = testData.acctPeriods[0].Start_Date__c,
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Purpose__c = 'Customer Receipt',
                    Bank_Account__c = testData.glAccounts.get(0).Id,
                    Credit_GL_Account__c = testData.glAccounts.get(16).Id,
                    Payment_Processor__c = pms[1].Payment_Processor__c
                )
            };
            insert crs;

            List<Payment_Activity__c> pas = new List<Payment_Activity__c>{
                new Payment_Activity__c(
                    Amount__c = crs[0].Amount__c,
                    Cash_Receipt__c = crs[0].Id,
                    Payment_Method__c = pms[0].Id,
                    Status__c = 'Pending',
                    Type__c = 'Payment'
                ),
                new Payment_Activity__c(
                    Amount__c = crs[1].Amount__c,
                    Cash_Receipt__c = crs[1].Id,
                    Payment_Method__c = pms[1].Id,
                    Status__c = 'Pending',
                    Type__c = 'Payment'
                )
            }; 
            insert pas;

            Set<Id> paIds = new Set<Id>();
            for (Payment_Activity__c pa : pas) {
                paIds.add(pa.Id);
            }

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
                WHERE Id IN :paIds
            ];

            SingleRequestMock respSuccess = new SingleRequestMock(
                200,
                'Complete',
                StripeServiceTest.getChargeResponseBody(),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );
            SingleRequestMock respError = new SingleRequestMock(
                200,
                'Complete',
                StripeServiceTest.getErrorResponse(),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Map<String, HttpCalloutMock> resps = new Map<String, HttpCalloutMock>{
                StripeService.CHARGE_URL + '/' + crs[0].Payment_Reference__c => respSuccess,
                StripeService.CHARGE_URL + '/' + crs[1].Payment_Reference__c => respError
            };

            HttpCalloutMock multiMock = new MultiRequestMock(resps);

            Test.setMock(HttpCalloutMock.class, multiMock);
            
            Test.startTest();
            StripeProcessorV1 proc = new StripeProcessorV1();
            List<Payment_Activity__c> updates = proc.getPaymentActivityStatus(activities);
            Test.stopTest();

            System.assertEquals(2, updates.size());
            Payment_Activity__c success = updates[0].Id == pas[0].Id ? updates[0] : updates[1];
            Payment_Activity__c error = updates[0].Id == pas[1].Id ? updates[0] : updates[1];
            System.assertEquals('Success', success.Status__c);
            System.assertEquals('Error', error.Status__c);
        }
    }

    // delete payment method
    @IsTest
    static void testDeletePaymentMethod() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPaymentProcessors();

        System.runAs(testData.users[1]) {
            SingleRequestMock getDeleteStripeCardGeneratorSuccess = new SingleRequestMock(
                200,
                'Complete',
                '{"deleted": true, "id": "StripeCardId"}',
                new Map<String, String>{'Content-Type' => 'application/json'}
            );
            Test.setMock(HttpCalloutMock.class, getDeleteStripeCardGeneratorSuccess);

            Payment_Processor_Customer__c customer =  new Payment_Processor_Customer__c(
                    Account__c = testData.accounts.get(0).Id,
                    Processor__c = testData.paymentProcessors.get(0).Id,
                    External_Id__c = 'StripeCustomerId_Success'
            );
            insert customer;

            Payment_Method__c pm = new Payment_Method__c(
                    Payment_Processor__c = customer.Processor__c,
                    Customer__c = customer.Account__c,
                    External_Id__c = 'StripeCustomerId_Success',
                    Last_Four_Digits__c = '1234',
                    Type__c = 'Visa',
                    Expiration_Month__c = '01',
                    Expiration_Year__c = '99',
                    Payment_Method_Type__c = 'Credit Card'
            );
            insert pm;

            // allow deletion for test
            ApexPages.StandardController stdCtrl = new ApexPages.StandardController(pm);
            PaymentMethodDeleteController ctrl = new PaymentMethodDeleteController(stdCtrl);
            ctrl.isDeletionAllowed = true;
            PaymentMethodActions.deleteController = ctrl;

            Test.startTest();
            StripeProcessorV1 stripe = new StripeProcessorV1();
            stripe.deletePaymentMethod(pm);
            Test.stopTest();


            List<Payment_Method__c> pms = [SELECT Id FROM Payment_Method__c WHERE Id = :pm.Id];
            System.assertEquals(0, pms.size());
        }
    }

    // get payment methods
    @IsTest
    static void testGetPaymentMethods() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            MultiRequestMock multiCalloutMockInstance = (MultiRequestMock) StripeServiceTest.createResponseGenerators();
            multiCalloutMockInstance.addRequestMock(
                StripeService.CUSTOMER_URL + '/StripeCustomerId_Success/sources?object=bank_account&limit=' + StripeService.RECEIVE_STRIPE_SOURCES_LIMIT,
                new SingleRequestMock(
                    200,
                    'Complete',
                    '{' +
                    '"object": "list",' +
                    '"url": "/v1/customers/cus_9M8lj1ufREF2SR/sources",' +
                    '"has_more": false,' +
                    '"data": [' +
                    '{' +
                    '"id": "ba_1949TyGKbd1fBtzklrzAHIIv",' +
                    '"object": "bank_account",' +
                    '"address_city": null,' +
                    '"address_country": null,' +
                    '"address_line1": null,' +
                    '"address_line1_check": null,' +
                    '"address_line2": null,' +
                    '"address_state": null,' +
                    '"address_zip": null,' +
                    '"address_zip_check": null,' +
                    '"brand": "Discover",' +
                    '"country": "US",' +
                    '"customer": "cus_9M8lj1ufREF2SR",' +
                    '"cvc_check": "pass",' +
                    '"dynamic_last4": null,' +
                    '"exp_month": 8,' +
                    '"exp_year": 2019,' +
                    '"fingerprint": "' + StripeServiceTest.FINGERPRINT + '",' +
                    '"funding": "credit",' +
                    '"last4": "1117",' +
                    '"metadata": {' +
                    '},' +
                    '"name": "Test",' +
                    '"tokenization_method": null' +
                    '}' +
                    ']' +
                    '}',
                    new Map<String, String>{'Content-Type' => 'application/json'}
                )
            );
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            Test.startTest();
            Payment_Processor_Customer__c customer =  new Payment_Processor_Customer__c(
                Account__c = testData.accounts.get(0).Id,
                Processor__c = testData.paymentProcessors.get(0).Id,
                External_Id__c = 'StripeCustomerId_Success'
            );

            StripeProcessorV1 stripe = new StripeProcessorV1();
            List<Payment_Method__c> pm = stripe.getPaymentMethods(customer);
            Test.stopTest();

            System.assertEquals(2, pm.size());
        }
    }

    // delete update method
    @IsTest
    static void testUpdatePaymentMethod() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPaymentProcessors();

        System.runAs(testData.users[1]) {
            HttpCalloutMock mock = StripeServiceTest.createResponseGenerators();
            Test.setMock(HttpCalloutMock.class, mock);

            Payment_Processor_Customer__c customer =  new Payment_Processor_Customer__c(
                    Account__c = testData.accounts.get(0).Id,
                    Processor__c = testData.paymentProcessors.get(0).Id,
                    External_Id__c = 'StripeCustomerId_Success'
            );
            insert customer;

            Payment_Method__c pm = new Payment_Method__c(
                    Payment_Processor__c = customer.Processor__c,
                    Customer__c = customer.Account__c,
                    External_Id__c = 'StripeCardId',
                    Last_Four_Digits__c = '1234',
                    Type__c = 'Visa',
                    Expiration_Month__c = '01',
                    Expiration_Year__c = '99',
                    Payment_Method_Type__c = 'Credit Card'
            );
            insert pm;

            Test.startTest();
            pm.Card_Holder_Name__c = 'Example Name';
            pm.Expiration_Year__c = '98';
            pm.Expiration_Month__c = '02';
            pm.Status__c = 'Active';
            StripeProcessorV1 stripe = new StripeProcessorV1();
            Payment_Method__c updatedPM = stripe.updatePaymentMethod(pm);
            Test.stopTest();

            System.assertEquals(updatedPM.Card_Holder_Name__c, 'Example Name');
            System.assertEquals(updatedPM.Expiration_Year__c, '98');
            System.assertEquals(updatedPM.Expiration_Month__c, '02');
            System.assertEquals(updatedPM.Status__c, 'Active');

            List<Payment_Method__c> pms = [
                SELECT Card_Holder_Name__c, Expiration_Year__c, Expiration_Month__c, Status__c 
                FROM Payment_Method__c 
                WHERE Id = :pm.Id
            ];
            System.assertEquals(1, pms.size());
            updatedPM = pms.get(0);
            System.assertEquals(updatedPM.Card_Holder_Name__c, 'Example Name');
            System.assertEquals(updatedPM.Expiration_Year__c, '98');
            System.assertEquals(updatedPM.Expiration_Month__c, '02');
            System.assertEquals(updatedPM.Status__c, 'Active');
        }
    }

    // non-implemented methods
    @IsTest
    static void testNotImplemented() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            
            StripeProcessorV1 stripe = new StripeProcessorV1();
            
            try {
                stripe.deleteCustomer(null);
                System.assert(false);
            } catch (Exception e) {
                System.assertEquals('Not Implemented', e.getMessage());
            }

            try {
                stripe.getCustomer(null);
                System.assert(false);
            } catch (Exception e) {
                System.assertEquals('Not Implemented', e.getMessage());
            }
            
            try {
                stripe.getCustomers(null);
                System.assert(false);
            } catch (Exception e) {
                System.assertEquals('Not Implemented', e.getMessage());
            }
            
            try {
                stripe.updateCustomer(null);
                System.assert(false);
            } catch (Exception e) {
                System.assertEquals('Not Implemented', e.getMessage());
            }

            try {
                stripe.getPaymentMethod(null);
                System.assert(false);
            } catch (Exception e) {
                System.assertEquals('Not Implemented', e.getMessage());
            }
            
            try {
                stripe.ccAuthorization(null);
                System.assert(false);
            } catch (Exception e) {
                System.assertEquals('Not Implemented', e.getMessage());
            }
            
            try {
                stripe.ccCapture(null);
                System.assert(false);
            } catch (Exception e) {
                System.assertEquals('Not Implemented', e.getMessage());
            }

            try {
                stripe.ccCredit(null);
                System.assert(false);
            } catch (Exception e) {
                System.assertEquals('Not Implemented', e.getMessage());
            }

            try {
                stripe.ccRefund(null);
                System.assert(false);
            } catch (Exception e) {
                System.assertEquals('Not Implemented', e.getMessage());
            }
            
            try {
                stripe.ccVoid(null);
                System.assert(false);
            } catch (Exception e) {
                System.assertEquals('Not Implemented', e.getMessage());
            }
            
            try {
                stripe.achCredit(null);
                System.assert(false);
            } catch (Exception e) {
                System.assertEquals('Not Implemented', e.getMessage());
            }
            
            try {
                stripe.achRefund(null);
                System.assert(false);
            } catch (Exception e) {
                System.assertEquals('Not Implemented', e.getMessage());
            }
            
            try {
                stripe.achVoid(null);
                System.assert(false);
            } catch (Exception e) {
                System.assertEquals('Not Implemented', e.getMessage());
            }
 
            Test.stopTest();
        }
    }

}