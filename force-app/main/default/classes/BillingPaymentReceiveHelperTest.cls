@IsTest
public class BillingPaymentReceiveHelperTest {

    public class MockCardsResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('"[ {brand" : "Visa", "country" :"US", "customer" :"cus_Mdva1aWB0L3QWu", "exp_month":"12", "exp_year":"2024", "id" : "card_1Luz0RA01FsEK3NDMLOtPneU" , "last4":"4242"}, {brand" : "Visa", "country" :"US", "customer" :"cus_Mdva1aWB0L3QWu", "exp_month":"12", "exp_year":"2024", "id" : "card_1Luz0RA01FsEK3NDMLOtPneU" , "last4":"4242"}]');
            res.setStatusCode(200);
            return res;
        }
    }

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
                    Status__c = 'Open'
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
    public static void testGetPaymentProcessors(){
        Test.setMock(HttpCalloutMock.class, new MockCardsResponse());

        TestDataSuite testData = TestDataSuite.getInstance()
            .createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Test.startTest();
            HttpCalloutMock multiCalloutMockInstance = StripeServiceTest.createResponseGenerators();
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(0).Id, Processor__c = testData.paymentProcessors.get(1).Id, External_Id__c='123');
            insert ppc;

            BillingPaymentReceiveHelper.PaymentWrapper pwNull = BillingPaymentReceiveHelper.getPaymentProcessors('');
            BillingPaymentReceiveHelper.PaymentWrapper pw = BillingPaymentReceiveHelper.getPaymentProcessors(String.valueOf(testData.accounts[0].get('Id')));

            BillingPaymentReceiveHelper.PaymentWrapper pwWrapper = new BillingPaymentReceiveHelper.PaymentWrapper(new List<AbstractLWCHelper.CustomSelectOption>(),
                            new Map<Id,List<AbstractLWCHelper.CustomSelectOption>>(), '1234567','8909090', new List<Payment_Method__c>());

            List<SelectOption> opts = new List<SelectOption>();
            opts.add(new SelectOption('Test Value', 'Test Key'));

            List<AbstractLWCHelper.CustomSelectOption> resultLst=  BillingPaymentReceiveHelper.preparePaymentProcessors(opts);
            
            System.assertEquals(1,resultLst.size());
            System.assertEquals('Test Key',resultLst[0].label);

            Map<Id,List<SelectOption>> optMap = new Map<Id,List<SelectOption>>();
            optMap.put(ppc.Id,opts);

            BillingPaymentReceiveHelper.getPaymentMethodsWithProcessors(optMap);

            System.assertEquals(true, pw.noDataAvailable);
            System.assertEquals(null, pwNull);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testGetWrappedBillings() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createCashReceipts()
            .createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Test.startTest();
            BillingPaymentReceiveHelper.BillingPaymentWrapper wrappedData = BillingPaymentReceiveHelper.getWrappedBillings(String.valueOf(testData.billings.get(0).Id));

            System.assertNotEquals(null, wrappedData.bill);
            System.assertEquals(450, wrappedData.billBillingTotal);
            System.assertEquals(0, wrappedData.billCrAdjustment);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testReceivePaymentCheck() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createCashReceipts()
            .createPaymentProcessors();

        Cash_Receipt__c cReciept = new Cash_Receipt__c(
            Account__c = testData.accounts.get(1).Id,
            Amount__c = 400,
            Status__c = 'Approved',
            Receipt_Date__c = System.today(),
            Purpose__c = 'Customer Receipt',
            Payment_Reference__c = '12345',
            Accounting_Period__c = testData.acctPeriods.get(0).Id
        );

        System.runAs(testData.users[1]) {
            Test.startTest();
            Date d = testData.acctPeriods[0].Start_Date__c;
            Map<String, Object> params = new Map<String, Object>{
                    'totalPaymentAmount' => 5,
                    'amount' => '5',
                    'adjustment-gl-account' => testData.glAccounts[0].Id,
                    'discount-amount' => '1',
                    'bank-account' => testData.glAccounts[0].Id,
                    'payment-reference' => '34tgererger',
                    'payment-date' => d.year() + '-' + d.month() + '-' + d.day(),
                    'payment-type' => 'Check',
                    'recordId' => testData.billings[0].Id,
                    'cashReceipt' => cReciept,
                    'convenienceFees' => 2
                   
            };
            Map<String, Object> result = BillingPaymentReceiveHelper.receivePayment(params);

            System.assert(result != null);
            System.assert(((List<Object>)result.get('errors')).isEmpty());
            Test.stopTest();
        }
    }

    @IsTest
    static void testGetWrappedBillingsCashFlowDefault() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashFlowCategories(true)
            .createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            BillingPaymentReceiveHelper.BillingPaymentWrapper result;
            result = BillingPaymentReceiveHelper.getWrappedBillings(testData.billings[0].Id);
            List<Accounting_Settings__c> settings = [SELECT Default_Cash_Receipt_Category__c FROM Accounting_Settings__c LIMIT 1];
            Assert.areEqual(settings[0].Default_Cash_Receipt_Category__c, result.cashReceipt.Cash_Flow_Category__c);
            Test.stopTest();
        }
    }
    @IsTest
    public static void testGetWrappedBillingsWithFieldSet(){
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createCashReceipts()
            .createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Test.startTest();
            BillingPaymentReceiveHelper.BillingPaymentWrapper wrappedData = BillingPaymentReceiveHelper.getWrappedBillings(String.valueOf(testData.billings.get(0).Id));

            Assert.areNotEqual(null, wrappedData.bill);
            Assert.areEqual(450, wrappedData.billBillingTotal);
            Assert.areEqual(0, wrappedData.billCrAdjustment);
            Assert.areNotEqual(0,wrappedData.fieldSetColumns.mainColumns.size());
            Assert.areEqual(7,wrappedData.fieldSetColumns.mainColumns.size());
            Assert.areEqual(0,wrappedData.fieldSetColumns.extraColumns.size());
            Assert.areEqual(0,wrappedData.fieldSetColumns.requiredColumns.size());
            Test.stopTest();
        }
    }

}