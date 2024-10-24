@isTest
private class PaymentManagerTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite testData = TestDataSuite.getInstance(true);
        System.runAs(testData.users.get(1)) {
            initializeAccountingPeriods();
        }
    }

    private static void initializeAccountingPeriods() {
        Date acctDate = Date.newInstance(System.today().year(), System.today().month() - 3, 1);
        List<Accounting_Period__c> acctPeriods = new List<Accounting_Period__c>();
        for (Integer i = 0; i < 15; i++) {
            acctPeriods.add(
                new Accounting_Period__c(
                    Name = String.valueOf(acctDate.year()) + '-' +
                        (acctDate.month() > 9 ? String.valueOf(acctDate.month()) : '0' + String.valueOf(acctDate.month())),
                    Start_Date__c = Date.newInstance(acctDate.year(), acctDate.month(), 1),
                    End_Date__c = Date.newInstance(acctDate.year(), acctDate.month(), Date.daysInMonth(acctDate.year(),acctDate.month())),
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

    @IsTest
    public static void testCreateChargeWithExistingPaymentMethod() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            testData.settings.Stripe_Connected_Account_Id__c = 'acct_9SDF3jgnfpoaicwE8';
            update testData.settings;

            Account acct = new Account(
                Name = 'Test Account 1234',
                Stripe_Customer_Id__c = 'stripe-customer-1'
            );
            insert acct;

            Payment_Processor_Customer__c cust = new Payment_Processor_Customer__c(
                Account__c = acct.Id,
                Processor__c = testData.paymentProcessors.get(0).Id,
                External_Id__c = 'stripe-customer-1'
            );
            insert cust;

            PaymentMethodActions.isPreventUpdateOverride = true;
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

            Payment_Method__c paymentMethod2 = new Payment_Method__c(
                Type__c = 'Visa',
                Status__c = 'Active',
                Expiration_Month__c = '12',
                Expiration_Year__c = '2099',
                Last_Four_Digits__c = '5555',
                External_Id__c = 'stripe-bank-1',
                Customer__c = acct.Id,
                Default__c = true,
                Payment_Processor__c = testData.paymentProcessors.get(0).Id
            );
            insert paymentMethod2;
            PaymentMethodActions.isPreventUpdateOverride = false;

            PageReference pageRef = Page.PaymentManager;
            pageRef.getParameters().put('id', acct.Id);
            Test.setCurrentPage(pageRef);
            Decimal chargedAmount = 150;
            HttpCalloutMock multiCalloutMockInstance = createResponseGenerators(
                chargedAmount, MultiCurrencyHandler.CORPORATE_CURRENCY
            );
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            Test.startTest();
            ApexPages.StandardController stdController = new ApexPages.StandardController(acct);
            PaymentManager controller = new PaymentManager(stdController);
            System.assertEquals(2, controller.pmProvider.sourceIdToExistingPaymentMethodMap.size());
            //auto select default card
            System.assertEquals('stripe-bank-1', controller.pmProvider.selectedSourceId);

            controller.amountObject.Amount__c = 0;
            controller.pmProvider.selectedSourceId = NULL;
            controller.totalAmount = 150;
            controller.submitPayment();
            System.assertEquals(' ' + SObjectActions.REQUIRED_FIELD_ERROR, controller.amountError);
            System.assertEquals(true, controller.isAmountError);
            System.assertEquals(true, controller.isSourceNotSelected);

            controller.amountObject.Amount__c = 150;
            controller.pmProvider.selectedSourceId = 'stripe-bank-1';
            controller.submitPayment();
            System.assertEquals(1, [SELECT COUNT() FROM Cash_Receipt__c WHERE Payment_Reference__c = 'charge-id']);
            System.assertEquals(1, [SELECT COUNT() FROM Payment_Activity__c WHERE Payment_Method__c = :paymentMethod2.Id]);

            controller.amountObject.Amount__c = -1;
            controller.submitPayment();
            System.assertEquals(' ' + Label.COMMON_MUST_BE_POSITIVE_NUMBER, controller.amountError);

            Test.stopTest();
        }

    }

    @IsTest
    public static void testCreateChargeWithoutExistingPaymentMethod() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            testData.settings.Stripe_Connected_Account_Id__c = 'acct_9SDF3jgnfpoaicwE8';
            update testData.settings;

            Account acct = new Account(
                Name = 'Test Account 1234',
                Stripe_Customer_Id__c = 'stripe-customer-1'
            );
            insert acct;

            Payment_Processor_Customer__c cust = new Payment_Processor_Customer__c(
                Account__c = acct.Id,
                Processor__c = testData.paymentProcessors.get(0).Id,
                External_Id__c = 'stripe-customer-1'
            );
            insert cust;

            PageReference pageRef = Page.PaymentManager;
            pageRef.getParameters().put('id', acct.Id);
            Test.setCurrentPage(pageRef);
            Decimal chargedAmount = 150;
            HttpCalloutMock multiCalloutMockInstance = createResponseGenerators(
                chargedAmount, MultiCurrencyHandler.CORPORATE_CURRENCY
            );
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            Test.startTest();

            ApexPages.StandardController stdController = new ApexPages.StandardController(acct);
            PaymentManager controller = new PaymentManager(stdController);

            controller.amountObject.Amount__c = 150;
            controller.pmProvider.selectedSourceId = 'stripe-card-1';
            controller.totalAmount = 150;
            controller.submitPayment();
            List<Payment_Method__c> paymentMethods = [SELECT Id FROM Payment_Method__c WHERE Customer__c = :acct.Id];
            System.assertEquals(1, paymentMethods.size());
            System.assertEquals(1, [SELECT COUNT() FROM Payment_Activity__c WHERE Payment_Method__c = :paymentMethods[0].Id]);

            Test.stopTest();
        }

    }

    @isTest
    public static void testInitialPageLoad() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Account acct = new Account(
                Name = 'Test Account 1234',
                Stripe_Customer_Id__c = 'stripe-customer-1'
            );
            insert acct;

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

            PageReference pageRef = Page.PaymentManager;
            pageRef.getParameters().put('id', acct.Id);
            Test.setCurrentPage(pageRef);
            Decimal chargedAmount = 150;
            HttpCalloutMock multiCalloutMockInstance = createResponseGenerators(
                chargedAmount, MultiCurrencyHandler.CORPORATE_CURRENCY
            );
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            Test.startTest();
            ApexPages.StandardController stdController = new ApexPages.StandardController(acct);
            PaymentManager controller = new PaymentManager(stdController);

            System.assertEquals(2, controller.pmProvider.sources.size());
        }

    }

    @isTest
    public static void testIsNotOpenAccountingPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.accounts[0]);
            PaymentManager pm = new PaymentManager(stdController);

            pm.receiptDate = Date.newInstance(1970, 1, 1);
            System.assertEquals(true, pm.isNotOpenAccountingPeriod());
        }
    }

    @isTest
    public static void testPaymentSoftClosePeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Date newDate = Date.newInstance(1991, 10, 16);
            Accounting_Period__c testAcctPeriod = [SELECT Id, Close_AP__c, Start_Date__c FROM Accounting_Period__c WHERE Status__c = :AccountingPeriodActions.OPEN_STATUS AND Start_Date__c < :newDate AND End_Date__c > :newDate];
            testAcctPeriod.Close_AR__c = true;
            update testAcctPeriod;
            
            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.accounts[0]);
            PaymentManager pm = new PaymentManager(stdController);

            pm.receiptDate = Date.newInstance(1991, 10, 16);
            System.assertEquals(true, pm.isNotOpenAccountingPeriod());
        }
    }

    @isTest
    public static void testIsNotOpenAccountingPeriodSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.accounts[0]);
            PaymentManager pm = new PaymentManager(stdController);

            pm.receiptDate = Date.newInstance(1991, 10, 1);
            System.assertEquals(false, pm.isNotOpenAccountingPeriod());
        }

    }

    @IsTest
    public static void testNoActiveStripeCards() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Account acct = new Account(
                Name = 'Test Account 1234',
                Stripe_Customer_Id__c = 'cus_testgRdoZP08pT'
            );
            insert acct;

            PaymentMethodActions.isPreventUpdateOverride = true;
            Payment_Method__c paymentMethod = new Payment_Method__c(
                Type__c = 'Visa',
                Status__c = StripeService.PAYMENT_METHOD_STATUS_INACTIVE,
                Expiration_Month__c = '12',
                Expiration_Year__c = '2099',
                Last_Four_Digits__c = '4444',
                External_Id__c = 'stripe-card-1',
                Customer__c = acct.Id,
                Default__c = true,
                Payment_Processor__c = testData.paymentProcessors.get(0).Id
            );
            insert paymentMethod;

            Payment_Method__c paymentMethod2 = new Payment_Method__c(
                Type__c = 'Visa',
                Status__c = StripeService.PAYMENT_METHOD_STATUS_INACTIVE,
                Expiration_Month__c = '12',
                Expiration_Year__c = '2099',
                Last_Four_Digits__c = '5555',
                External_Id__c = 'stripe-bank-1',
                Customer__c = acct.Id,
                Default__c = true,
                Payment_Processor__c = testData.paymentProcessors.get(0).Id
            );
            insert paymentMethod2;
            PaymentMethodActions.isPreventUpdateOverride = false;

            PageReference pageRef = Page.PaymentManager;
            pageRef.getParameters().put('id', acct.Id);
            Test.setCurrentPage(pageRef);
            Decimal chargedAmount = 150;
            HttpCalloutMock multiCalloutMockInstance = createResponseGenerators(
                chargedAmount, MultiCurrencyHandler.CORPORATE_CURRENCY
            );
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            ApexPages.StandardController stdController = new ApexPages.StandardController(acct);
            PaymentManager controller = new PaymentManager(stdController);
            System.assert(controller.noStripeConnectedId);
            Test.stopTest();
        }

    }

    @IsTest
    public static void testAutoPopulateCurrencyAndBankAccount() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createPaymentProcessors();
            String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
            if (String.isBlank(newCurrencyIsoCode)) {
                return;
            }

            System.runAs(testData.users[1]) {
                //create new Bank GL Account
                GL_Account__c newBankGlAccount = testData.glAccounts[0].clone(false, true, false, false);
                newBankGlAccount.Name = '1000-Cash-NEW';
                newBankGlAccount.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert newBankGlAccount;
                //create Ledger in foreign currency
                Ledger__c newLedger = new Ledger__c(
                    Name = 'Actual-NEW',
                    Type__c = 'Transactional',
                    Default_Bank_Account__c = newBankGlAccount.Id,
                    Default_Billing_Format__c = testData.billingFormats[0].Id,
                    Billing_Outstanding_Statement_Format__c = testData.billingFormats[2].Id,
                    Billing_Activity_Statement_Format__c = testData.billingFormats[3].Id
                );
                newLedger.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert newLedger;

                Account acct = new Account(
                    Name = 'Test Account 1234',
                    Stripe_Customer_Id__c = 'stripe-customer-1'
                );
                insert acct;

                Payment_Processor_Customer__c cust = new Payment_Processor_Customer__c(
                    Account__c = acct.Id,
                    Processor__c = testData.paymentProcessors[0].Id,
                    External_Id__c = 'cus_voijwvjoanse8vwervnsp98dv'
                );
                insert cust;

                PaymentMethodActions.isPreventUpdateOverride = true;
                Payment_Method__c paymentMethod = new Payment_Method__c(
                    Type__c = 'Visa',
                    Status__c = 'Active',
                    Expiration_Month__c = '12',
                    Expiration_Year__c = '2099',
                    Last_Four_Digits__c = '4444',
                    External_Id__c = 'stripe-card-1',
                    Customer__c = cust.Account__c,
                    Default__c = true,
                    Payment_Processor__c = cust.Processor__c
                );
                insert paymentMethod;

                PageReference pageRef = Page.PaymentManager;
                pageRef.getParameters().put('id', acct.Id);
                Test.setCurrentPage(pageRef);

                Decimal chargedAmount = 150;
                HttpCalloutMock multiCalloutMockInstance = createResponseGenerators(
                    chargedAmount, MultiCurrencyHandler.CORPORATE_CURRENCY
                );
                Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

                Test.startTest();
                ApexPages.StandardController stdController = new ApexPages.StandardController(acct);
                PaymentManager controller = new PaymentManager(stdController);

                System.assertEquals(testData.ledgers[0].Id, controller.amountObject.Ledger__c);
                String oldLedgerId = testData.ledgers[0].Id;
                Ledger__c oldLedger = Database.query('SELECT Id, CurrencyIsoCode FROM Ledger__c WHERE Id = :oldLedgerId');
                System.assertEquals((String) oldLedger.get('CurrencyIsoCode'), controller.selectedCurrency);

                controller.amountObject.Ledger__c = newLedger.Id;
                LedgerHandler.reset();
                controller.changeLedger();

                System.assertEquals((String) newLedger.get('CurrencyIsoCode'), controller.selectedCurrency);
                System.assertEquals(newLedger.Default_Bank_Account__c, controller.amountObject.Bank_Account__c);
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    public static void testCreateChargeWithExistingPaymentMethod_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createPaymentProcessors();

            String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
            if (String.isBlank(newCurrencyIsoCode)) {
                return;
            }

            System.runAs(testData.users[1]) {
                Account acct = new Account(
                    Name = 'Test Account 1234'
                );
                insert acct;

                Payment_Processor_Customer__c cust = new Payment_Processor_Customer__c(
                    Account__c = acct.Id,
                    Processor__c = testData.paymentProcessors[0].Id,
                    External_Id__c = 'stripe-customer-1'
                );
                insert cust;

                PaymentMethodActions.isPreventUpdateOverride = true;
                Payment_Method__c paymentMethod = new Payment_Method__c(
                    Type__c = 'Visa',
                    Status__c = 'Active',
                    Expiration_Month__c = '12',
                    Expiration_Year__c = '2099',
                    Last_Four_Digits__c = '4444',
                    External_Id__c = 'stripe-card-1',
                    Customer__c = cust.Account__c,
                    Default__c = true,
                    Payment_Processor__c = cust.Processor__c
                );
                insert paymentMethod;

                Payment_Method__c paymentMethod2 = new Payment_Method__c(
                    Type__c = 'Visa',
                    Status__c = 'Active',
                    Expiration_Month__c = '12',
                    Expiration_Year__c = '2099',
                    Last_Four_Digits__c = '5555',
                    External_Id__c = 'stripe-bank-1',
                    Customer__c = cust.Account__c,
                    Default__c = true,
                    Payment_Processor__c = cust.Processor__c
                );
                insert paymentMethod2;
                PaymentMethodActions.isPreventUpdateOverride = false;

                PageReference pageRef = Page.PaymentManager;
                pageRef.getParameters().put('id', acct.Id);
                Test.setCurrentPage(pageRef);

                Decimal chargedAmount = 150;
                HttpCalloutMock multiCalloutMockInstance = createResponseGenerators(chargedAmount, newCurrencyIsoCode);
                Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

                Test.startTest();
                ApexPages.StandardController stdController = new ApexPages.StandardController(acct);
                PaymentManager controller = new PaymentManager(stdController);
                controller.selectedCurrency = newCurrencyIsoCode;
                System.assertEquals(2, controller.pmProvider.sources.size());
                //auto select default card
                System.assertEquals('stripe-bank-1', controller.pmProvider.selectedSourceId);

                controller.amountObject.Amount__c = 150;
                controller.totalAmount = 150;
                controller.pmProvider.selectedSourceId = 'stripe-bank-1';
                controller.submitPayment();

                System.assertEquals(1, [SELECT COUNT() FROM Cash_Receipt__c WHERE Payment_Reference__c = 'charge-id']);
                System.assertEquals(1, [SELECT COUNT() FROM Payment_Activity__c WHERE Payment_Method__c = :paymentMethod2.Id]);
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @isTest
    public static void testTestModeWarning() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Payment_Processor__c proc = testData.paymentProcessors.get(0).clone(false,true,false,false);
            proc.Test_Mode__c = true;
            insert proc;

            Account acct = new Account(
                Name = 'Test Account 1234',
                Stripe_Customer_Id__c = 'stripe-customer-1'
            );
            insert acct;

            Payment_Processor_Customer__c cust = new Payment_Processor_Customer__c(
                Account__c = acct.Id,
                Processor__c = proc.Id,
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
                Payment_Processor__c = proc.Id
            );
            insert paymentMethod;

            PageReference pageRef = Page.PaymentManager;
            pageRef.getParameters().put('id', acct.Id);
            Test.setCurrentPage(pageRef);
            Decimal chargedAmount = 150;
            HttpCalloutMock multiCalloutMockInstance = createResponseGenerators(
                chargedAmount, MultiCurrencyHandler.CORPORATE_CURRENCY
            );
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            Test.startTest();
            ApexPages.StandardController stdController = new ApexPages.StandardController(acct);
            PaymentManager controller = new PaymentManager(stdController);
            ApexPages.Message[] pageMessages = ApexPages.getMessages();
            System.assertEquals(1, pageMessages.size());
            System.equals(Label.INFO_PAYMENTS_PROCESSOR_TEST_MODE, pageMessages[0].getSummary());
            Test.stopTest();
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

}