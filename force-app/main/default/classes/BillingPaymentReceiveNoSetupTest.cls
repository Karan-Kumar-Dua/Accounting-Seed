@IsTest
private class BillingPaymentReceiveNoSetupTest {

    @IsTest
    public static void testCreateItemsPartialCreditCard() {
        TestDataSuite testData = TestDataSuite.getInstance(true);
        initializeAccountingPeriods();
        testData.createBillings();
        testData.createCashReceipts();
        testData.createPaymentProcessors();

        System.runAs(testData.users[1]) {
            testData.settings.Stripe_Connected_Account_Id__c = 'acct_9SDF3jgnfpoaicwE8';
            update testData.settings;

            Account acct = testData.accounts[0];
            acct.Stripe_Customer_Id__c = 'stripe-customer-1';
            update acct;

            Payment_Processor_Customer__c cust = new Payment_Processor_Customer__c(
                Account__c = acct.Id,
                Processor__c = testData.paymentProcessors.get(0).Id,
                External_Id__c = 'stripe-customer-1'
            );
            insert cust;

            Payment_Method__c paymentMethod = new Payment_Method__c(
                Type__c = 'Visa',
                Status__c = 'Active',
                Expiration_Month__c = '12',
                Expiration_Year__c = '2099',
                Last_Four_Digits__c = '4444',
                External_Id__c = 'stripe-card-1',
                Customer__c = acct.Id,
                Default__c = true,
                Payment_Processor__c = testData.paymentProcessors.get(0).Id
            );
            insert paymentMethod;

            //We have to isolate the code below from any preceded DML operations, because of callouts made during its execution
            Test.startTest();
            //==================================================================================================================

            PageReference pageRef = Page.BillingPaymentReceivePartial;
            pageRef.getParameters().put('id', testData.billings[0].Id);
            Test.setCurrentPage(pageRef);
            Decimal chargedAmount = 150;
            HttpCalloutMock multiCalloutMockInstance = createResponseGenerators(
                chargedAmount, MultiCurrencyHandler.CORPORATE_CURRENCY
            );
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.billings[0]);
            BillingPaymentReceive controller = new BillingPaymentReceive(stdController);
            controller.selectedTransactionType = 'Electronic';
            controller.wrappedBillings[0].pmProvider.selectedSourceId = 'stripe-card-1';

            System.assertEquals(1, controller.wrappedBillings.size());

            controller.createItems();

            System.assertEquals(1, [SELECT COUNT() FROM Cash_Receipt__c WHERE Payment_Reference__c = 'charge-id']);
            System.assertEquals(1, [SELECT COUNT() FROM Payment_Activity__c WHERE Payment_Method__c = :paymentMethod.Id]);
            System.assertEquals(1, [SELECT COUNT() FROM Billing_Cash_Receipt__c WHERE Billing__c = :testData.billings[0].Id]);
            //=========================================================================================================
            Test.stopTest();
            //=========================================================================================================
        }

    }

    @IsTest
    public static void testLineLimitExceededError() {
        TestDataSuite testData = TestDataSuite.getInstance(true);
        initializeAccountingPeriods();
        testData.createBillings();
        testData.createPaymentProcessors();

        System.runAs(testData.users[1]) {
            AccountingSettingsHandler.acctSeedSettings = NULL;
            testData.settings.Stripe_Connected_Account_Id__c = 'testStripe';
            update testData.settings;

            List<Account> accounts = new List<Account>();
            for (Integer i = 0; i < 51; i++ ) {
                Account acct = testData.accounts[0].clone();
                acct.Name += String.valueOf(i);
                acct.Stripe_Customer_Id__c = 'stripe-customer-1';
                accounts.add(acct);
            }
            insert accounts;

            List<Payment_Processor_Customer__c> customers = new List<Payment_Processor_Customer__c>();
            for (Account acct : accounts) {
                customers.add(new Payment_Processor_Customer__c(
                    Account__c = acct.Id,
                    Processor__c = testData.paymentProcessors.get(0).Id,
                    External_Id__c = 'stripe-customer-1'
                ));
            }
            insert customers;

            List<Payment_Method__c> paymentMethods = new List<Payment_Method__c>();
            PaymentMethodActions.isPreventUpdateOverride = true;
            for (Account acct : accounts) {
                Payment_Method__c paymentMethod = new Payment_Method__c(
                    Type__c = 'Visa',
                    Status__c = 'Active',
                    Expiration_Month__c = '12',
                    Expiration_Year__c = '2099',
                    Last_Four_Digits__c = '4444',
                    External_Id__c = 'stripe-card-1' + acct.Name,
                    Customer__c = acct.Id,
                    Default__c = true,
                    Payment_Processor__c = testData.paymentProcessors.get(0).Id
                );
                paymentMethods.add(paymentMethod);
            }
            insert paymentMethods;
            PaymentMethodActions.isPreventUpdateOverride = false;
            List<Billing__c> billings = new List<Billing__c>();
            for (Account acct : accounts) {
                billings.add(new Billing__c(
                    Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                    Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c+3,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Customer__c = acct.Id,
                    Status__c = 'Approved',
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Billing_Format__c = testData.billingFormats[0].Id,
                    Due_Date2__c = System.today() + 30
                )
                );
            }
            insert billings;

            //We have to isolate the code below from any preceded DML operations, because of callouts made during its execution
            Test.startTest();
            //==================================================================================================================

            PageReference pageRef = Page.BillingPaymentReceiveBatch;
            Test.setCurrentPage(pageRef);
            Decimal chargedAmount = 150;
            HttpCalloutMock multiCalloutMockInstance = createResponseGenerators(
                chargedAmount, MultiCurrencyHandler.CORPORATE_CURRENCY
            );
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            ApexPages.StandardSetController stdSetController = new ApexPages.StandardSetController(billings);
            stdSetController.setSelected(billings);

            BillingPaymentReceive controller = new BillingPaymentReceive(stdSetController);
            System.assertEquals(BillingPaymentReceive.LINE_LIMIT_EXCEEDED_ERROR_MESSAGE, ApexPages.getMessages()[0].getDetail());
            System.assertEquals(0, controller.wrappedBillings.size());
            System.assertEquals(1, ApexPages.getMessages().size());

            Test.stopTest();
        }
    }

    @IsTest
    public static void testCreateItemsPartialCreditCardWithDiscount() {
        TestDataSuite testData = TestDataSuite.getInstance(true);
        initializeAccountingPeriods();
        testData.createBillings(false);
        testData.disableAutoPostSourceDocuments();
        testData.createCashReceipts();
        testData.createPaymentProcessors();

        System.runAs(testData.users[1]) {
            testData.settings.Stripe_Connected_Account_Id__c = 'acct_9SDF3jgnfpoaicwE8';
            update testData.settings;

            Account acct = testData.accounts[0];
            acct.Stripe_Customer_Id__c = 'stripe-customer-1';
            update acct;

            testData.settings.Stripe_Connected_Account_Id__c = 'stripe-customer-1';
            update testData.settings;

            testData.billings[0].Discount_Due_Date__c = System.today().addDays(1);
            testData.billings[0].Discount_Percent__c = 10;
            update testData.billings[0];

            Payment_Processor_Customer__c cust = new Payment_Processor_Customer__c(
                Account__c = acct.Id,
                Processor__c = testData.paymentProcessors.get(0).Id,
                External_Id__c = 'stripe-customer-1'
            );
            insert cust;

            Payment_Method__c paymentMethod = new Payment_Method__c(
                Type__c = 'Visa',
                Status__c = 'Active',
                Expiration_Month__c = '12',
                Expiration_Year__c = '2099',
                Last_Four_Digits__c = '4444',
                External_Id__c = 'stripe-card-1',
                Customer__c = acct.Id,
                Default__c = true,
                Payment_Processor__c = testData.paymentProcessors.get(0).Id
            );
            insert paymentMethod;

            //We have to isolate the code below from any preceded DML operations, because of callouts made during its execution
            Test.startTest();
            //=======================================================================================================

            PageReference pageRef = Page.BillingPaymentReceivePartial;
            pageRef.getParameters().put('id', testData.billings[0].Id);
            Test.setCurrentPage(pageRef);
            Decimal chargedAmount = 150;
            HttpCalloutMock multiCalloutMockInstance = createResponseGenerators(
                chargedAmount, MultiCurrencyHandler.CORPORATE_CURRENCY
            );
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.billings[0]);
            BillingPaymentReceive controller = new BillingPaymentReceive(stdController);
            controller.selectedTransactionType = 'Electronic';
            controller.wrappedBillings[0].pmProvider.selectedSourceId = 'stripe-card-1';
            controller.wrappedBillings[0].proxyBillingCashReceipt.Adjustment_Amount__c = 45;//Discount/Adjustment Amount
            controller.wrappedBillings[0].cashReceipt.Amount__c = chargedAmount;//Amount - Discount/Adjustment Amount

            System.assertEquals(1, controller.wrappedBillings.size());

            controller.createItems();

            List<Cash_Receipt__c> newCashReceipts = [
                SELECT Id, Receipt_Date__c
                FROM Cash_Receipt__c
                WHERE Payment_Reference__c = 'charge-id'
            ];

            List<Billing_Cash_Receipt__c> newBillingCashReceipts = [
                SELECT Id, Applied_Date__c, Applied_Amount__c, Adjustment_Amount__c
                FROM Billing_Cash_Receipt__c
                WHERE Billing__c = :testData.billings[0].Id
            ];

            System.assertEquals(1, newCashReceipts.size());
            System.assertEquals(1, newBillingCashReceipts.size());
            System.assertEquals(1, [SELECT COUNT() FROM Payment_Activity__c WHERE Payment_Method__c = :paymentMethod.Id]);
            System.assertEquals(chargedAmount, newBillingCashReceipts[0].Applied_Amount__c);
            System.assertEquals(45, newBillingCashReceipts[0].Adjustment_Amount__c);
            System.assertEquals(newCashReceipts[0].Receipt_Date__c, newBillingCashReceipts[0].Applied_Date__c);

            //=======================================================================================
            Test.stopTest();
            //=======================================================================================
        }

    }


    //==========================================================================================================
    //================================ Create Multi-Response Generator =========================================
    //==========================================================================================================
    private static MultiRequestMock createResponseGenerators(Decimal amount, String chargeCurrency) {
        //======
        SingleRequestMock xGetAllCustomerCardsRequestMock1 = new SingleRequestMock(
            200,
            'Complete',
            getAllCustomerCardsResponseBody1(),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        //======
        SingleRequestMock xGetAllCustomerCardsRequestMock2 = new SingleRequestMock(
            200,
            'Complete',
            getAllCustomerCardsResponseBody2(),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        //======
        SingleRequestMock xGetAllCustomerBankAccountsRequestMock1 = new SingleRequestMock(
            200,
            'Complete',
            getAllCustomerBankAccountsResponseBody1(),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        //======
        SingleRequestMock xGetAllCustomerBankAccountsRequestMock2 = new SingleRequestMock(
            200,
            'Complete',
            getAllCustomerBankAccountsResponseBody2(),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        //======
        SingleRequestMock xPostCreateChargeRequestMock = new SingleRequestMock(
            200,
            'Complete',
            getCreateChargeResponseBody(amount, chargeCurrency),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
        endpoint2TestResp.put(StripeService.CHARGE_URL, xPostCreateChargeRequestMock);
        endpoint2TestResp.put(
            StripeService.CUSTOMER_URL + '/' + 'stripe-customer-1' + '/sources?object=card&limit=' +
                StripeService.RECEIVE_STRIPE_SOURCES_LIMIT,
            xGetAllCustomerCardsRequestMock1
        );
        endpoint2TestResp.put(
            StripeService.CUSTOMER_URL + '/' + 'stripe-customer-2' + '/sources?object=card&limit=' +
                StripeService.RECEIVE_STRIPE_SOURCES_LIMIT,
            xGetAllCustomerCardsRequestMock2
        );
        endpoint2TestResp.put(
            StripeService.CUSTOMER_URL + '/' + 'stripe-customer-1' + '/sources?object=bank_account&limit=' +
                StripeService.RECEIVE_STRIPE_SOURCES_LIMIT,
            xGetAllCustomerBankAccountsRequestMock1
        );
        endpoint2TestResp.put(
            StripeService.CUSTOMER_URL + '/' + 'stripe-customer-2' + '/sources?object=bank_account&limit=' +
                StripeService.RECEIVE_STRIPE_SOURCES_LIMIT,
            xGetAllCustomerBankAccountsRequestMock2
        );

        MultiRequestMock multiCalloutMockInstance = new MultiRequestMock(endpoint2TestResp);

        return multiCalloutMockInstance;
    }

    //==========================================================================================================
    //================================ JSON Response Bodies ====================================================
    //==========================================================================================================
    private static String getCreateChargeResponseBody(Decimal amount, String chargeCurrency) {
        StripeService.StripeCharge newCharge = new StripeService.StripeCharge();
        newCharge.id = 'charge-id';
        newCharge.status = 'succeeded';
        newCharge.source = new StripeService.StripeSource();
        newCharge.source.id = 'source-id';
        newCharge.source.status = 'verified';
        newCharge.amount = StripeService.prepareAmountForStripe(amount, chargeCurrency);
        newCharge.stripeCurrency = chargeCurrency.toLowerCase();

        return JSON.serialize(newCharge);
    }

    private static String getAllCustomerCardsResponseBody1() {
        StripeService.StripeSource card = new StripeService.StripeSource();
        card.id = 'stripe-card-1';
        card.stripeObject = 'card';
        card.account_holder_name = 'Test Account';
        card.account_holder_type = NULL;
        card.bank_name = NULL;
        card.country = 'US';
        card.fingerprint = 'fingerprint1';
        card.last4 = '4444';
        card.status = NULL;
        card.routing_number = NULL;
        card.customer = 'stripe-customer-1';
        card.brand = 'Visa';
        card.exp_month = 12;
        card.exp_year = 2099;
        card.name = 'stripe-card-1';
        card.metadata = new StripeService.StripeSourceMetadata();
        card.metadata.status = 'Active';

        List<StripeService.StripeSource> sources = new List<StripeService.StripeSource>{card};
        Map<String, Object> dataMap = new Map<String, Object>{
            'data' => sources
        };

        return JSON.serialize(dataMap);
    }

    private static String getAllCustomerBankAccountsResponseBody1() {
        StripeService.StripeSource bank = new StripeService.StripeSource();
        bank.id = 'stripe-bank-1';
        bank.stripeObject = 'bank_account';
        bank.account_holder_name = 'Test Account';
        bank.account_holder_type = 'individual';
        bank.bank_name = 'Test Bank';
        bank.country = 'US';
        bank.fingerprint = 'fingerprint2';
        bank.last4 = '5555';
        bank.status = 'verified';
        bank.routing_number = '000000011';
        bank.customer = 'stripe-customer-1';
        bank.brand = 'Visa';
        bank.exp_month = 12;
        bank.exp_year = 2099;
        bank.name = 'stripe-bank-1';
        bank.metadata = new StripeService.StripeSourceMetadata();
        bank.metadata.status = 'Active';

        List<StripeService.StripeSource> sources = new List<StripeService.StripeSource>{bank};
        Map<String, Object> dataMap = new Map<String, Object>{
            'data' => sources
        };

        return JSON.serialize(dataMap);
    }

    private static String getAllCustomerCardsResponseBody2() {
        StripeService.StripeSource card = new StripeService.StripeSource();
        card.id = 'stripe-card-2';
        card.stripeObject = 'card';
        card.account_holder_name = 'Test Account';
        card.account_holder_type = NULL;
        card.bank_name = NULL;
        card.country = 'US';
        card.fingerprint = 'fingerprint2';
        card.last4 = '6666';
        card.status = NULL;
        card.routing_number = NULL;
        card.customer = 'stripe-customer-2';
        card.brand = 'Visa';
        card.exp_month = 12;
        card.exp_year = 2099;
        card.name = 'stripe-card-2';
        card.metadata = new StripeService.StripeSourceMetadata();
        card.metadata.status = 'Active';

        List<StripeService.StripeSource> sources = new List<StripeService.StripeSource>{card};
        Map<String, Object> dataMap = new Map<String, Object>{
            'data' => sources
        };

        return JSON.serialize(dataMap);
    }

    private static String getAllCustomerBankAccountsResponseBody2() {
        StripeService.StripeSource bank = new StripeService.StripeSource();
        bank.id = 'stripe-bank-2';
        bank.stripeObject = 'bank_account';
        bank.account_holder_name = 'Test Account';
        bank.account_holder_type = 'individual';
        bank.bank_name = 'Test Bank';
        bank.country = 'US';
        bank.fingerprint = 'fingerprint2';
        bank.last4 = '7777';
        bank.status = 'verified';
        bank.routing_number = '000000011';
        bank.customer = 'stripe-customer-2';
        bank.brand = 'Visa';
        bank.exp_month = 12;
        bank.exp_year = 2099;
        bank.name = 'stripe-bank-2';
        bank.metadata = new StripeService.StripeSourceMetadata();
        bank.metadata.status = 'Active';

        List<StripeService.StripeSource> sources = new List<StripeService.StripeSource>{bank};
        Map<String, Object> dataMap = new Map<String, Object>{
            'data' => sources
        };

        return JSON.serialize(dataMap);
    }

    private static void initializeAccountingPeriods() {
        Date acctDate = Date.newInstance(System.today().year(), System.today().month() - 3, 1);
        List<Accounting_Period__c> acctPeriods = new List<Accounting_Period__c>();
        for (Integer i = 0; i < 15; i++) {
            acctPeriods.add(
                new Accounting_Period__c(
                    Name =
                        String.valueOf(acctDate.year()) + '-' +
                            (acctDate.month() > 9 ? String.valueOf(acctDate.month()) : '0' + String.valueOf(acctDate.month())),
                    Start_Date__c = Date.newInstance(acctDate.year(), acctDate.month(), 1),
                    End_Date__c = Date.newInstance(
                        acctDate.year(), acctDate.month(), Date.daysInMonth(acctDate.year(), acctDate.month())
                    ),
                    Status__c = AccountingPeriodActions.OPEN_STATUS
                )
            );
            if (acctDate.month() == 12) {
                acctDate = Date.newInstance(acctDate.year() + 1, 1, 1);
            }
            else {
                acctDate = acctDate.addMonths(1);
            }
        }
        insert acctPeriods;
    }

}