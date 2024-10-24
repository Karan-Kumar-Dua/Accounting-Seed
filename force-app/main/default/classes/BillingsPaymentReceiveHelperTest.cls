@IsTest
private class BillingsPaymentReceiveHelperTest {

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
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPaymentProcessors();

        System.runAs(testData.users.get(1)) {

            Test.startTest();

            initializeAccountingPeriods();
            Payment_Processor_Customer__c customer = new Payment_Processor_Customer__c(
                Processor__c = testData.paymentProcessors[0].Id,
                Account__c = testData.accounts[0].Id,
                External_Id__c = 'STRIPECUSTOMERID'
            );
            insert customer;

            Payment_Method__c testPM = new Payment_Method__c();
            testPM.Customer__c = customer.Account__c;
            testPM.Type__c = 'Visa';
            testPM.Card_Holder_Name__c = 'Mr. Yellow';
            testPM.Last_Four_Digits__c = '7878';
            testPM.Default__c = true;
            testPM.Expiration_Month__c = '05';
            testPM.Expiration_Year__c = '2020';
            testPM.External_Id__c = 'STRIPECARDID';
            testPM.Status__c = 'Active';
            testPM.Payment_Processor__c = customer.Processor__c;
            insert testPM;
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
    public static void testGetWrappedBillings() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings(false)
            .disableAutoPostSourceDocuments()
            .createCashReceipts()
            .createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.settings.Stripe_Connected_Account_Id__c = testData.paymentProcessors[0].Id;
            update testData.settings;

            String wrappedData = BillingsPaymentReceiveHelper.getBillings(new List<Id> {testData.billings.get(0).Id}, false);

            List<BillingsPaymentReceiveHelper.BillingPaymentWrapper> params
                = (List<BillingsPaymentReceiveHelper.BillingPaymentWrapper>) JSON.deserialize(wrappedData, List<BillingsPaymentReceiveHelper.BillingPaymentWrapper>.class);

            System.assertEquals(1, params.size());
            System.assertEquals(testData.billings.get(0).Id, params[0].Id);
        }
    }

    @IsTest
    public static void testGetAggregatedWrappedBillings() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .disableAutoPostSourceDocuments()
            .createCashReceipts()
            .createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.settings.Stripe_Connected_Account_Id__c = testData.paymentProcessors[0].Id;
            update testData.settings;

            List<Id> billingIds = new List<Id>();
            for (Billing__c bill : testData.billings) {
                billingIds.add(bill.Id);
            }

            String wrappedData = BillingsPaymentReceiveHelper.getBillings(billingIds, true);

            List<BillingsPaymentReceiveHelper.BillingPaymentWrapper> params
                = (List<BillingsPaymentReceiveHelper.BillingPaymentWrapper>) JSON.deserialize(wrappedData, List<BillingsPaymentReceiveHelper.BillingPaymentWrapper>.class);

            List<Id> resultBillingIds = new List<Id> {testData.billings.get(0).Id, testData.billings.get(1).Id};
            System.assertEquals(5, billingIds.size());
            System.assertEquals(1, params.size());
            System.assertEquals(resultBillingIds, params[0].billingIds);
        }
    }

    @IsTest
    public static void testGetBillingsWithApplications(){
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .disableAutoPostSourceDocuments()
            .createCashReceipts()
            .createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.settings.Stripe_Connected_Account_Id__c = testData.paymentProcessors[0].Id;
            update testData.settings;

            List<Billing__c> invoices = new List<Billing__c>{
                testData.billings[0],
                testData.billings[1]
            };
            Billing__c creditMemo = testData.billings[2];
            Cash_Receipt__c cashReceipt = testData.cashReceipts[0];

            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c(
                Billing_Invoice__c = invoices[0].Id,
                Billing_Credit_Memo__c = creditMemo.Id,
                Amount__c = 5,
                Accounting_Period__c = testData.acctPeriods[0].Id
            );
            insert bcm;

            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c(
                Billing__c = invoices[1].Id,
                Cash_Receipt__c = cashReceipt.Id,
                Applied_Amount__c = 5
            );
            insert bcr;

            List<Id> invoiceIds = new List<Id>{invoices[0].Id, invoices[1].Id};            
            String wrappedData = BillingsPaymentReceiveHelper.getBillings(invoiceIds, true);

            List<BillingsPaymentReceiveHelper.BillingPaymentWrapper> payments =
                (List<BillingsPaymentReceiveHelper.BillingPaymentWrapper>) JSON.deserialize(
                    wrappedData,
                    List<BillingsPaymentReceiveHelper.BillingPaymentWrapper>.class
                );

            List<AggregateResult> invoiceBalance = [SELECT SUM(Balance__c) balance FROM Billing__c WHERE Id IN :invoiceIds];

            Assert.areEqual(1, payments.size());
            Assert.areEqual(invoiceBalance[0].get('balance'), payments[0].paymentAmount);
        }
    }

}