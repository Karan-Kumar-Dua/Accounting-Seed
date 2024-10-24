@IsTest
public class BillingPaymentReceiveTest {

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

    @IsTest
    public static void testCreateItemsPartialCheck() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {

            PageReference pageRef = Page.BillingPaymentReceivePartial;
            pageRef.getParameters().put('id', testData.billings[0].Id);
            Test.setCurrentPage(pageRef);

            Test.startTest();

            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.billings[0]);
            BillingPaymentReceive controller = new BillingPaymentReceive(stdController);
            controller.selectedTransactionType = 'Check';
            controller.wrappedBillings[0].cashReceipt.Payment_Reference__c = 'test-payment-ref-xxx';

            System.assertEquals(1, controller.wrappedBillings.size());

            controller.createItems();

            List<Cash_Receipt__c> newCashReceipts = [
                SELECT Id, Receipt_Date__c, Accounting_Period__c
                FROM Cash_Receipt__c
                WHERE Payment_Reference__c = 'test-payment-ref-xxx'
            ];

            List<Billing_Cash_Receipt__c> newBillingCashReceipts = [
                SELECT Id, Applied_Date__c, Accounting_Period__c
                FROM Billing_Cash_Receipt__c
                WHERE Billing__c = :testData.billings[0].Id
            ];

            System.assertEquals(1, newCashReceipts.size());
            System.assertEquals(1, newBillingCashReceipts.size());
            System.assertEquals(newCashReceipts[0].Receipt_Date__c, newBillingCashReceipts[0].Applied_Date__c);
            System.assertEquals(newCashReceipts[0].Accounting_Period__c, newBillingCashReceipts[0].Accounting_Period__c);

            Test.stopTest();
        }

    }

    @IsTest
    public static void testCreateItemsPartialCheckFutureBilling() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();

            Billing__c newBill = testData.billings[0].clone();
            newBill.Date__c = testData.acctPeriods[1].Start_Date__c.addDays(5);
            newBill.Accounting_Period__c = testData.acctPeriods[1].Id;
            insert newBill;

            Billing_Line__c line = testData.billingLines[0].clone();
            line.Billing__c = newBill.Id;
            line.Date__c = testData.acctPeriods[1].Start_Date__c.addDays(5);
            insert line;

            PageReference pageRef = Page.BillingPaymentReceivePartial;
            pageRef.getParameters().put('id', newBill.Id);
            Test.setCurrentPage(pageRef);

            ApexPages.StandardController stdController = new ApexPages.StandardController(newBill);
            BillingPaymentReceive controller = new BillingPaymentReceive(stdController);
            controller.selectedTransactionType = 'Check';
            controller.wrappedBillings[0].cashReceipt.Receipt_Date__c = testData.acctPeriods[0].Start_Date__c.addDays(10);
            controller.wrappedBillings[0].cashReceipt.Payment_Reference__c = 'test-payment-ref-xxx';

            System.assertEquals(1, controller.wrappedBillings.size());

            controller.createItems();

            List<Cash_Receipt__c> newCashReceipts = [
                SELECT Id, Receipt_Date__c, Accounting_Period__c
                FROM Cash_Receipt__c
                WHERE Payment_Reference__c = 'test-payment-ref-xxx'
            ];

            List<Billing_Cash_Receipt__c> newBillingCashReceipts = [
                SELECT Id, Applied_Date__c, Accounting_Period__c
                FROM Billing_Cash_Receipt__c
                WHERE Billing__c = :newBill.Id
            ];

            System.assertEquals(1, newCashReceipts.size());
            System.assertEquals(1, newBillingCashReceipts.size());
            System.assertEquals(testData.acctPeriods[0].Start_Date__c.addDays(10), newCashReceipts[0].Receipt_Date__c);
            System.assertEquals(testData.acctPeriods[0].Id, newCashReceipts[0].Accounting_Period__c);
            System.assertEquals(testData.acctPeriods[1].Start_Date__c, newBillingCashReceipts[0].Applied_Date__c);
            System.assertEquals(testData.acctPeriods[1].Id, newBillingCashReceipts[0].Accounting_Period__c);

            Test.stopTest();
        }

    }

    @IsTest
    public static void testCreateItemsBatchSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createPaymentProcessors();

        System.runAs(testData.users[1]) {
            AccountingSettingsHandler.acctSeedSettings = null;
            testData.settings.Stripe_Connected_Account_Id__c = 'testStripe';
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

            ApexPages.StandardSetController stdSetController = new ApexPages.StandardSetController(testData.billings);
            stdSetController.setSelected(testData.billings);

            BillingPaymentReceive controller = new BillingPaymentReceive(stdSetController);
            System.assertEquals(1, controller.wrappedBillings.size());
            controller.wrappedBillings[0].pmProvider.selectedSourceId = 'stripe-bank-1';

            controller.createItems();

            List<Cash_Receipt__c> newCashReceipts = [
                SELECT Id, Receipt_Date__c
                FROM Cash_Receipt__c
                WHERE Payment_Reference__c = 'charge-id'
            ];

            List<Billing_Cash_Receipt__c> newBillingCashReceipts = [
                SELECT Id, Applied_Date__c
                FROM Billing_Cash_Receipt__c
                WHERE Billing__c = :testData.billings[0].Id
            ];

            System.assertEquals(1, newCashReceipts.size());
            System.assertEquals(1, [SELECT COUNT() FROM Payment_Activity__c WHERE Payment_Method__c = :paymentMethod2.Id]);
            System.assertEquals(1, newBillingCashReceipts.size());
            System.assertEquals(newCashReceipts[0].Receipt_Date__c, newBillingCashReceipts[0].Applied_Date__c);
            System.assertEquals(BillingPaymentReceive.SUCCESS_PAYMENTS_MESSAGE, ApexPages.getMessages()[0].getDetail());
            //=========================================================================================================
            Test.stopTest();
            //=========================================================================================================
        }
    }

    @IsTest
    public static void testCreateItemsPartialCheckWithDiscount() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {

            testData.billings[0].Discount_Due_Date__c = System.today().addDays(1);
            testData.billings[0].Discount_Percent__c = 10;

            update testData.billings[0];

            PageReference pageRef = Page.BillingPaymentReceivePartial;
            pageRef.getParameters().put('id', testData.billings[0].Id);
            Test.setCurrentPage(pageRef);

            Test.startTest();

            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.billings[0]);
            BillingPaymentReceive controller = new BillingPaymentReceive(stdController);
            controller.selectedTransactionType = 'Check';
            controller.wrappedBillings[0].cashReceipt.Payment_Reference__c = 'test-payment-ref-xxx';
            controller.wrappedBillings[0].proxyBillingCashReceipt.Adjustment_Amount__c = 45;//Discount/Adjustment Amount
            controller.wrappedBillings[0].cashReceipt.Amount__c = 405;//Amount - Discount/Adjustment Amount

            System.assertEquals(1, controller.wrappedBillings.size());

            controller.createItems();

            Test.stopTest();

            List<Cash_Receipt__c> newCashReceipts = [
                SELECT Id, Receipt_Date__c
                FROM Cash_Receipt__c
                WHERE Payment_Reference__c = 'test-payment-ref-xxx'
            ];

            List<Billing_Cash_Receipt__c> newBillingCashReceipts = [
                SELECT Id, Applied_Date__c, Applied_Amount__c, Adjustment_Amount__c
                FROM Billing_Cash_Receipt__c
                WHERE Billing__c = :testData.billings[0].Id
            ];

            System.assertEquals(1, newCashReceipts.size());
            System.assertEquals(1, newBillingCashReceipts.size());
            System.assertEquals(405, newBillingCashReceipts[0].Applied_Amount__c);
            System.assertEquals(45, newBillingCashReceipts[0].Adjustment_Amount__c);
            System.assertEquals(newCashReceipts[0].Receipt_Date__c, newBillingCashReceipts[0].Applied_Date__c);
        }

    }

    @IsTest
    public static void testNoOpenAccountingPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {

            AccountingPeriodActions.isUpdateError = true;
            Accounting_Period__c selectedAP = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today().addDays(50));
            selectedAP.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update selectedAP;

            PageReference pageRef = Page.BillingPaymentReceivePartial;
            pageRef.getParameters().put('id', testData.billings[0].Id);
            Test.setCurrentPage(pageRef);

            Test.startTest();

            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.billings[0]);
            BillingPaymentReceive controller = new BillingPaymentReceive(stdController);
            controller.selectedTransactionType = 'Check';
            controller.wrappedBillings[0].cashReceipt.Payment_Reference__c = '1234';
            controller.wrappedBillings[0].cashReceipt.Receipt_Date__c = System.today().addDays(50);

            System.assertEquals(1, controller.wrappedBillings.size());

            controller.createItems();

            System.assertEquals(
                String.format(BillingPaymentReceive.NO_OPEN_PERIOD_ERROR_MESSAGE, new List<String>{System.today().addDays(50).format()}),
                ApexPages.getMessages()[0].getDetail()
            );
            Test.stopTest();
        }

    }

    @IsTest
    public static void testNoExistAccountingPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {

            AccountingPeriodActions.isUpdateError = true;

            PageReference pageRef = Page.BillingPaymentReceivePartial;
            pageRef.getParameters().put('id', testData.billings[0].Id);
            Test.setCurrentPage(pageRef);

            Test.startTest();

            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.billings[0]);
            BillingPaymentReceive controller = new BillingPaymentReceive(stdController);
            controller.selectedTransactionType = 'Check';
            controller.wrappedBillings[0].cashReceipt.Payment_Reference__c = '1234';
            controller.wrappedBillings[0].cashReceipt.Receipt_Date__c = System.today().addDays(720);

            System.assertEquals(1, controller.wrappedBillings.size());

            controller.createItems();

            System.assertEquals(BillingPaymentReceive.NO_EXIST_PERIOD_ERROR_MESSAGE, ApexPages.getMessages()[0].getDetail());
            Test.stopTest();
        }

    }

    @IsTest
    public static void testNegativeAmountError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {

            PageReference pageRef = Page.BillingPaymentReceivePartial;
            pageRef.getParameters().put('id', testData.billings[0].Id);
            Test.setCurrentPage(pageRef);

            Test.startTest();

            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.billings[0]);
            BillingPaymentReceive controller = new BillingPaymentReceive(stdController);
            controller.selectedTransactionType = 'Check';
            controller.wrappedBillings[0].cashReceipt.Payment_Reference__c = '1234';
            controller.wrappedBillings[0].cashReceipt.Amount__c = -20;

            System.assertEquals(1, controller.wrappedBillings.size());

            controller.createItems();

            System.assertEquals(BillingPaymentReceive.NEGATIVE_AMOUNT_ERROR_MESSAGE, ApexPages.getMessages()[0].getDetail());
            Test.stopTest();
        }

    }

    @IsTest
    public static void testZeroAmountError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {

            PageReference pageRef = Page.BillingPaymentReceivePartial;
            pageRef.getParameters().put('id', testData.billings[0].Id);
            Test.setCurrentPage(pageRef);

            Test.startTest();

            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.billings[0]);
            BillingPaymentReceive controller = new BillingPaymentReceive(stdController);
            controller.selectedTransactionType = 'Check';
            controller.wrappedBillings[0].cashReceipt.Payment_Reference__c = '1234';
            controller.wrappedBillings[0].cashReceipt.Amount__c = 0;

            System.assertEquals(1, controller.wrappedBillings.size());

            controller.createItems();

            System.assertEquals(BillingPaymentReceive.AMOUNT_ZERO_ERROR, ApexPages.getMessages()[0].getDetail());
            Test.stopTest();
        }

    }

    @IsTest
    public static void testNegativeAdjustmentAmount() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            PageReference pageRef = Page.BillingPaymentReceivePartial;
            pageRef.getParameters().put('id', testData.billings[0].Id);
            Test.setCurrentPage(pageRef);

            Test.startTest();

            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.billings[0]);
            BillingPaymentReceive controller = new BillingPaymentReceive(stdController);
            controller.selectedTransactionType = 'Check';
            controller.wrappedBillings[0].cashReceipt.Payment_Reference__c = '1234';
            controller.wrappedBillings[0].totalBalance = 450;//Billing's Total
            controller.wrappedBillings[0].proxyBillingCashReceipt.Adjustment_Amount__c = -100;
            //When Adjustment amount is negative:
            // CR Amount = Billing's Total + Adjustment Amount
            controller.wrappedBillings[0].cashReceipt.Amount__c = 550;

            System.assertEquals(1, controller.wrappedBillings.size());

            controller.createItems();

            Billing__c testBillingWithRelatedRecords = [
                SELECT
                    Id,
                (SELECT
                    Id,
                    Applied_Amount__c,
                    Adjustment_Amount__c,
                    Cash_Receipt__r.Amount__c,
                    Cash_Receipt__r.Applied_Amount__c,
                    Billing__r.Received_Amount__c,
                    Billing__r.Cash_Application_Adjustment_Amount__c,
                    Billing__r.Total__c
                FROM Billing_Cash_Receipts__r)
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];

            System.assertEquals(550, testBillingWithRelatedRecords.Billing_Cash_Receipts__r[0].Applied_Amount__c);
            System.assertEquals(-100, testBillingWithRelatedRecords.Billing_Cash_Receipts__r[0].Adjustment_Amount__c);
            System.assertEquals(550, testBillingWithRelatedRecords.Billing_Cash_Receipts__r[0].Cash_Receipt__r.Amount__c);
            System.assertEquals(550, testBillingWithRelatedRecords.Billing_Cash_Receipts__r[0].Cash_Receipt__r.Applied_Amount__c);
            System.assertEquals(550, testBillingWithRelatedRecords.Billing_Cash_Receipts__r[0].Billing__r.Received_Amount__c);
            System.assertEquals(-100, testBillingWithRelatedRecords.Billing_Cash_Receipts__r[0].Billing__r.Cash_Application_Adjustment_Amount__c);
            System.assertEquals(450, testBillingWithRelatedRecords.Billing_Cash_Receipts__r[0].Billing__r.Total__c);
        }

    }

    @IsTest
    public static void testPositiveAdjustmentAmount() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            PageReference pageRef = Page.BillingPaymentReceivePartial;
            pageRef.getParameters().put('Id', testData.billings[0].Id);
            Test.setCurrentPage(pageRef);

            Test.startTest();

            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.billings[0]);
            BillingPaymentReceive controller = new BillingPaymentReceive(stdController);
            controller.selectedTransactionType = 'Check';
            controller.wrappedBillings[0].cashReceipt.Payment_Reference__c = '1234';
            controller.wrappedBillings[0].totalBalance = 450;//Billing's Total
            controller.wrappedBillings[0].proxyBillingCashReceipt.Adjustment_Amount__c = 100;
            //When Adjustment amount is positive:
            // CR Amount = Billing's Total - Adjustment Amount
            controller.wrappedBillings[0].cashReceipt.Amount__c = 350;

            System.assertEquals(1, controller.wrappedBillings.size());

            controller.createItems();

            Billing__c testBillingWithRelatedRecords = [
                SELECT
                    Id,
                (SELECT
                    Id,
                    Applied_Amount__c,
                    Adjustment_Amount__c,
                    Cash_Receipt__r.Amount__c,
                    Cash_Receipt__r.Applied_Amount__c,
                    Billing__r.Received_Amount__c,
                    Billing__r.Cash_Application_Adjustment_Amount__c,
                    Billing__r.Total__c
                FROM Billing_Cash_Receipts__r)
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];

            System.assertEquals(350, testBillingWithRelatedRecords.Billing_Cash_Receipts__r[0].Applied_Amount__c);
            System.assertEquals(100, testBillingWithRelatedRecords.Billing_Cash_Receipts__r[0].Adjustment_Amount__c);
            System.assertEquals(350, testBillingWithRelatedRecords.Billing_Cash_Receipts__r[0].Cash_Receipt__r.Amount__c);
            System.assertEquals(350, testBillingWithRelatedRecords.Billing_Cash_Receipts__r[0].Cash_Receipt__r.Applied_Amount__c);
            System.assertEquals(350, testBillingWithRelatedRecords.Billing_Cash_Receipts__r[0].Billing__r.Received_Amount__c);
            System.assertEquals(100, testBillingWithRelatedRecords.Billing_Cash_Receipts__r[0].Billing__r.Cash_Application_Adjustment_Amount__c);
            System.assertEquals(450, testBillingWithRelatedRecords.Billing_Cash_Receipts__r[0].Billing__r.Total__c);
        }

    }

    @IsTest
    public static void testCreditMemoError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {

            PageReference pageRef = Page.BillingPaymentReceivePartial;
            pageRef.getParameters().put('id', testData.billings[3].Id);
            Test.setCurrentPage(pageRef);

            Test.startTest();

            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.billings[3]);
            BillingPaymentReceive controller = new BillingPaymentReceive(stdController);

            System.assertEquals(BillingPaymentReceive.NO_DATA_ERROR_MESSAGE, ApexPages.getMessages()[0].getDetail());
        }

    }

    @IsTest
    public static void testNoStripeConnectionError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createPaymentProcessors();

        System.runAs(testData.users[1]) {

            Account acct = testData.accounts[0];

            Payment_Processor_Customer__c cust = new Payment_Processor_Customer__c(
                Account__c = acct.Id,
                Processor__c = testData.paymentProcessors.get(0).Id,
                External_Id__c = 'stripe-customer-1'
            );
            insert cust;

            Payment_Method__c paymentMethod = new Payment_Method__c(
                Type__c = 'Visa',
                Status__c = 'Active',
                Expiration_Month__c = '1',
                Expiration_Year__c = '2019',
                Last_Four_Digits__c = '4444',
                External_Id__c = 'card_17ujweEbJdMP0Nek8KiKMUiW',
                Customer__c = acct.Id,
                Default__c = true,
                Payment_Processor__c = testData.paymentProcessors.get(0).Id
            );
            insert paymentMethod;

            Payment_Method__c paymentMethod2 = new Payment_Method__c(
                Type__c = 'Visa',
                Status__c = 'Active',
                Expiration_Month__c = '2',
                Expiration_Year__c = '2017',
                Last_Four_Digits__c = '4444',
                External_Id__c = 'card_17wYwjEbJdMP0NekIxtaOaHf',
                Customer__c = acct.Id,
                Default__c = true,
                Payment_Processor__c = testData.paymentProcessors.get(0).Id
            );
            insert paymentMethod2;

            PageReference pageRef = Page.BillingPaymentReceivePartial;
            pageRef.getParameters().put('id', testData.billings[0].Id);
            Test.setCurrentPage(pageRef);
            Decimal chargedAmount = 150;
            HttpCalloutMock multiCalloutMockInstance = createResponseGenerators(
                chargedAmount, MultiCurrencyHandler.CORPORATE_CURRENCY
            );
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            Test.startTest();

            ApexPages.StandardSetController stdSetController = new ApexPages.StandardSetController(testData.billings);
            stdSetController.setSelected(testData.billings);

            BillingPaymentReceive controller = new BillingPaymentReceive(stdSetController);

            System.assertEquals(BillingPaymentReceive.NO_DATA_ERROR_MESSAGE, ApexPages.getMessages()[0].getDetail());

            Test.stopTest();
        }

    }

    @IsTest
    public static void testNoAdjustmentAccountError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {

            PageReference pageRef = Page.BillingPaymentReceivePartial;
            pageRef.getParameters().put('id', testData.billings[0].Id);
            Test.setCurrentPage(pageRef);

            Test.startTest();

            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.billings[0]);
            BillingPaymentReceive controller = new BillingPaymentReceive(stdController);
            controller.selectedTransactionType = 'Check';
            controller.wrappedBillings[0].proxyBillingCashReceipt.Adjustment_GL_Account__c = NULL;
            controller.wrappedBillings[0].proxyBillingCashReceipt.Adjustment_Amount__c = 3;
            controller.wrappedBillings[0].cashReceipt.Payment_Reference__c = '1234';
            controller.wrappedBillings[0].cashReceipt.Amount__c = 15;
            controller.wrappedBillings[0].totalBalance = 20;

            System.assertEquals(1, controller.wrappedBillings.size());

            controller.createItems();

            System.assertEquals(BillingPaymentReceive.EMPTY_ADJUSTMENT_ACCOUNT_ERROR_MESSAGE, ApexPages.getMessages()[0].getDetail());
            Test.stopTest();
        }

    }

    //=================== Multi Currency section =======================================================
    @IsTest
    public static void testCreateItemsBatchSuccess_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createBillings();

            System.runAs(testData.users[1]) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                testData.settings.Stripe_Connected_Account_Id__c = 'stripeConnectedAccount';
                update testData.settings;

                Account acct1 = testData.accounts[0];
                acct1.Stripe_Customer_Id__c = 'stripe-customer-1';
                Account acct2 = testData.accounts[1];
                acct2.Stripe_Customer_Id__c = 'stripe-customer-2';
                update new List<Account>{acct1, acct2};

                //put new customer to one of existed Billing
                testData.billings.get(0).Customer__c = testData.accounts.get(1).Id;
                //put non default Ledger to one of existed Billings
                testData.billings.get(1).Ledger__c = testData.ledgers.get(2).Id;
                //put non-corporate currency to one of existed Billing
                testData.billings.get(2).put('CurrencyIsoCode', newCurrencyIsoCode);
                //mass update
                TriggerObserver.getInstance().unlockFields(
                    new Set<SObjectField>{
                        Billing__c.Customer__c,
                        Billing__c.Ledger__c,
                        Schema.SObjectType.Billing__c.fields.getMap().get('CurrencyIsoCode')
                    }
                );
                update new List<Billing__c>{testData.billings.get(0), testData.billings.get(1), testData.billings.get(2)};

                //convert negative Billing Lines to positive to have only Invoices
                for (Billing_Line__c bLine : testData.billingLines) {
                    if (bLine.Hours_Units__c < 0) {
                        bLine.Hours_Units__c = bLine.Hours_Units__c * -1;
                    }
                }
                update testData.billingLines;

                TriggerObserver.reset();

                Payment_Method__c paymentMethod = new Payment_Method__c(
                    Type__c = 'Visa',
                    Status__c = 'Active',
                    Expiration_Month__c = '12',
                    Expiration_Year__c = '2099',
                    Last_Four_Digits__c = '4444',
                    External_Id__c = 'stripe-card-1',
                    Customer__c = acct1.Id,
                    Default__c = true
                );
                insert paymentMethod;

                Payment_Method__c paymentMethod2 = new Payment_Method__c(
                    Type__c = 'Visa',
                    Status__c = 'Active',
                    Expiration_Month__c = '12',
                    Expiration_Year__c = '2099',
                    Last_Four_Digits__c = '4444',
                    External_Id__c = 'stripe-card-2',
                    Customer__c = acct2.Id,
                    Default__c = true
                );
                insert paymentMethod2;

                //We have to isolate the code below from any preceded DML operations, because of callouts made during its execution
                Test.startTest();
                //==================================================================================================================

                PageReference pageRef = Page.BillingPaymentReceiveBatch;
                Test.setCurrentPage(pageRef);
                Decimal chargedAmount = 150;
                HttpCalloutMock multiCalloutMockInstance = createResponseGenerators(chargedAmount, newCurrencyIsoCode);
                Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

                ApexPages.StandardSetController stdSetController = new ApexPages.StandardSetController(testData.billings);
                stdSetController.setSelected(testData.billings);

                BillingPaymentReceive controller = new BillingPaymentReceive(stdSetController);
                System.assertEquals(4, controller.wrappedBillings.size());
                controller.wrappedBillings[0].pmProvider.selectedSourceId = 'stripe-card-2';
                controller.wrappedBillings[1].pmProvider.selectedSourceId = 'stripe-card-1';
                controller.wrappedBillings[2].pmProvider.selectedSourceId = 'stripe-card-1';
                controller.wrappedBillings[3].pmProvider.selectedSourceId = 'stripe-card-1';

                controller.createItems();
                //=================================================================================================================
                Test.stopTest();
                //=================================================================================================================
                System.assertEquals(4, [SELECT COUNT() FROM Cash_Receipt__c WHERE Payment_Reference__c = 'charge-id']);
                System.assertEquals(3, [SELECT COUNT() FROM Payment_Activity__c WHERE Payment_Method__c = :paymentMethod.Id]);
                System.assertEquals(1, [SELECT COUNT() FROM Payment_Activity__c WHERE Payment_Method__c = :paymentMethod2.Id]);
                System.assertEquals(1, [SELECT COUNT() FROM Billing_Cash_Receipt__c WHERE Billing__c = :testData.billings[0].Id]);
                System.assertEquals(1, [SELECT COUNT() FROM Billing_Cash_Receipt__c WHERE Billing__c = :testData.billings[1].Id]);
                System.assertEquals(1, [SELECT COUNT() FROM Billing_Cash_Receipt__c WHERE Billing__c = :testData.billings[2].Id]);
                System.assertEquals(1, [SELECT COUNT() FROM Billing_Cash_Receipt__c WHERE Billing__c = :testData.billings[3].Id]);
                System.assertEquals(BillingPaymentReceive.SUCCESS_PAYMENTS_MESSAGE, ApexPages.getMessages()[0].getDetail());
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {
            //skip this test if MC is not enabled
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

    @IsTest
    public static void testSoftCloseCreateBillings() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
            
            System.runAs(testData.users[1]) {
                
                Accounting_Period__c period = [Select Id, Close_AR__c, Close_AP__c, Status__c From Accounting_Period__c
                                                WHERE Start_Date__c =: Date.newInstance(System.today().year(), System.today().month(), 1)];

                period.Close_AR__c = true;
                UPDATE period;

                PageReference pageRef = Page.BillingPaymentReceivePartial;
                pageRef.getParameters().put('Id', testData.billings[0].Id);
                Test.setCurrentPage(pageRef);

                Test.startTest();
                ApexPages.StandardController stdController = new ApexPages.StandardController(testData.billings[0]);
                BillingPaymentReceive controller = new BillingPaymentReceive(stdController);
                controller.selectedTransactionType = 'Check';
                controller.wrappedBillings[0].cashReceipt.Payment_Reference__c = '1234';
                controller.wrappedBillings[0].totalBalance = 450;//Billing's Total
                controller.wrappedBillings[0].proxyBillingCashReceipt.Adjustment_Amount__c = 100;
                controller.wrappedBillings[0].cashReceipt.Amount__c = 350;

                System.assertEquals(1, controller.wrappedBillings.size());

                controller.createItems();
                
                Billing__c testBillingWithRelatedRecords = [
                    SELECT
                        Id,
                    (SELECT
                        Id,
                        Applied_Amount__c,
                        Adjustment_Amount__c,
                        Cash_Receipt__r.Amount__c,
                        Cash_Receipt__r.Applied_Amount__c,
                        Billing__r.Received_Amount__c,
                        Billing__r.Cash_Application_Adjustment_Amount__c,
                        Billing__r.Total__c
                    FROM Billing_Cash_Receipts__r)
                    FROM Billing__c
                    WHERE Id = :testData.billings[0].Id
                ];
                Test.stopTest();

                Assert.isTrue(testBillingWithRelatedRecords.Billing_Cash_Receipts__r.size() == 0, 'Nothing has been inserted because related period is closed');
                Assert.isTrue(controller.isError);
                Assert.areEqual(100, controller.wrappedBillings[0].proxyBillingCashReceipt.Adjustment_Amount__c);
                Assert.areEqual(0, controller.wrappedBillings[0].proxyBillingCashReceipt.Applied_Amount__c);
            }
    }

    @IsTest
    public static void testSoftCloseCreateBillingsStripePayment() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
            
            System.runAs(testData.users[1]) {
                PageReference pageRef = Page.BillingPaymentReceivePartial;
                pageRef.getParameters().put('Id', testData.billings[0].Id);
                Test.setCurrentPage(pageRef);

                Test.startTest();
                Accounting_Period__c period = [Select Id, Close_AR__c, Close_AP__c, Status__c From Accounting_Period__c
                                                WHERE Id =: testData.billings[0].Accounting_Period__c];
                Period.Close_AR__c = True;
                UPDATE period;
                
                ApexPages.StandardController stdController = new ApexPages.StandardController(testData.billings[0]);
                BillingPaymentReceive controller = new BillingPaymentReceive(stdController);
                controller.selectedTransactionType = 'Electronic';
                controller.wrappedBillings[0].cashReceipt.Payment_Reference__c = '1234';
                controller.wrappedBillings[0].totalBalance = 450;//Billing's Total
                controller.wrappedBillings[0].proxyBillingCashReceipt.Adjustment_Amount__c = 100;
                controller.wrappedBillings[0].cashReceipt.Amount__c = 350;

                System.assertEquals(1, controller.wrappedBillings.size());

                controller.createItems();
                
                Billing__c testBillingWithRelatedRecords = [
                    SELECT
                        Id,
                    (SELECT
                        Id,
                        Applied_Amount__c,
                        Adjustment_Amount__c,
                        Cash_Receipt__r.Amount__c,
                        Cash_Receipt__r.Applied_Amount__c,
                        Billing__r.Received_Amount__c,
                        Billing__r.Cash_Application_Adjustment_Amount__c,
                        Billing__r.Total__c
                    FROM Billing_Cash_Receipts__r)
                    FROM Billing__c
                    WHERE Id = :testData.billings[0].Id
                ];
                Test.stopTest();

                Assert.isTrue(testBillingWithRelatedRecords.Billing_Cash_Receipts__r.size() == 0, 'Nothing has been inserted because related period is closed');
                Assert.isTrue(controller.isError);
                Assert.areEqual(100, controller.wrappedBillings[0].proxyBillingCashReceipt.Adjustment_Amount__c);
                Assert.areEqual(0, controller.wrappedBillings[0].proxyBillingCashReceipt.Applied_Amount__c);
            }
    }

    @IsTest
    public static void testSelectAvailableTypes() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            PageReference pageRef = Page.BillingPaymentReceivePartial;
            pageRef.getParameters().put('Id', testData.billings[0].Id);
            Test.setCurrentPage(pageRef);
            
            Test.startTest();
            
            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.billings[0]);
            BillingPaymentReceive controller = new BillingPaymentReceive(stdController);
            
            List<SelectOption> options = controller.getAvailableTypes();
            Assert.isNotNull(options);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testgetBankAccounts() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            PageReference pageRef = Page.BillingPaymentReceivePartial;
            pageRef.getParameters().put('Id', testData.billings[0].Id);
            Test.setCurrentPage(pageRef);
            
            Test.startTest();
            
            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.billings[0]);
            BillingPaymentReceive controller = new BillingPaymentReceive(stdController);
            
            List<SelectOption> options = controller.getBankAccounts();
            Assert.isNotNull(options);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testSoftCloseSelectedBillings() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        System.runAs(testData.users[1]) {
            List<Accounting_Period__c> periods = [Select Id, Close_AR__c From Accounting_Period__c WHERE Start_Date__c <=: Date.today() 
                                                AND END_Date__c >=: Date.today()];
            periods[0].Close_AR__c = True;
            UPDATE periods;
            
            Test.startTest();
            ApexPages.StandardSetController stdSetController = new ApexPages.StandardSetController(testData.billings);
            stdSetController.setSelected(new List<Billing__c>{testData.billings[0]});
            BillingPaymentReceive controller = new BillingPaymentReceive(stdSetController);
            Test.stopTest();
            
            Assert.isTrue(controller.isError);
            Assert.isTrue(controller.isDataAvailableError);
            Assert.areEqual(String.format(BillingPaymentReceive.NO_OPEN_PERIOD_ERROR_MESSAGE,new List<String>{Date.today().format()}), ApexPages.getMessages()[1].getDetail());
        }
    }

    @IsTest
    public static void testSoftCloseReceiptTypeErrors() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        System.runAs(testData.users[1]) {
            List<Accounting_Period__c> periods = [Select Id, Close_AR__c From Accounting_Period__c WHERE Start_Date__c <=: Date.today() 
                                                AND END_Date__c >=: Date.today()];
            periods[0].Close_AR__c = True;
            UPDATE periods;
            
            PageReference pageRef = Page.BillingPaymentReceivePartial;
            pageRef.getParameters().put('Id', testData.billings[0].Id);
            Test.setCurrentPage(pageRef);

            Test.startTest();
            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.billings[0]);
            BillingPaymentReceive controller = new BillingPaymentReceive(stdController);
            controller.selectedTransactionType = BillingPaymentReceive.STRIPE_PAYMENT_LABEL;
            PageReference pg = controller.checkReceiptTypeErrors();
            Test.stopTest();
            
            Assert.isNull(pg);
            Assert.areEqual(String.format(BillingPaymentReceive.NO_OPEN_PERIOD_ERROR_MESSAGE,new List<String>{Date.today().format()}), ApexPages.getMessages()[0].getDetail());
        }
    }

}