@IsTest
private class VirtualCardServiceTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testVirtualCardBlockAndReturnFundSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createCashFlowCategories(true)
                .createPayables(false);

        System.runAs(testData.users[1]) {
            Test.startTest();
            Account_Payable__c testAccountPayable = testData.payables[5];
            testAccountPayable.Discount_Amount__c = 2;
            update testAccountPayable;

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> postResults = postHandler.post(testData.payables);
            System.assertEquals(true, postResults[0].isSuccess);

            testData.archiveOldAccountingPeriods();
            testData.createAccountingPeriodSetBasedOnCurrentDate();
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());

            //Pay this Payable
            AccountPayablePayPartial payController = new AccountPayablePayPartial(
                    new ApexPages.StandardController(testAccountPayable)
            );
            payController.uiCashDisbursement.Disbursement_Date__c = currentPeriod.Start_Date__c;
            payController.payPartial();
            //Query new CD created after Payable pay process
            Cash_Disbursement__c testCD = [SELECT Id, Vendor__c FROM Cash_Disbursement__c LIMIT 1];


            Payment_Processor__c pp = new Payment_Processor__c();
            pp.Type__c = 'Edenred';
            pp.Active__c = true;
            insert pp;

            //Create a JIT virtual card for this cash disbursement
            Payment_Method__c pm = new Payment_Method__c();
            pm.Payment_Processor__c = pp.Id;
            pm.Vendor__c = testCD.Vendor__c;
            pm.Status__c = 'Active';
            pm.External_Id__c = String.valueOf(System.now());
            pm.Payment_Method_Type__c = 'Virtual Card';
            pm.Last_Four_Digits__c = '1111';
            pm.Expiration_Month__c = String.valueOf(System.today().month() + 3);
            pm.Expiration_Year__c = String.valueOf(System.today().year() + 1);
            insert pm;

            testCD.Payment_Method__c = pm.Id;
            update testCD;


            //Post this CD
            ApexPages.StandardController controller = new ApexPages.StandardController(testCD);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();
            cdp.post();

            Test.setMock(HttpCalloutMock.class, new BlockAndReturnFundsMock());

            VirtualCardService.BlockAndReturnFunds v = new VirtualCardService.BlockAndReturnFunds(new List<Id>{pm.Id});
            System.enqueueJob(v);

            Test.stopTest();

            Payment_Method__c updatedPaymentMethod = [SELECT Id, Status__c, Available_Balance__c FROM Payment_Method__c WHERE Id = :pm.Id];
            system.assertEquals('Blocked', updatedPaymentMethod.Status__c);
            system.assertEquals(0, updatedPaymentMethod.Available_Balance__c);

        }
    }

    public class BlockAndReturnFundsMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse resp = new HttpResponse();
            string mockBody = '{"acceptedMerchants":[],"amount":3.5,"availableBalance":3.5,"blocked":true,"cardNumber":"XXXXXXXXXXXX3289","config":{"placeHolder":null},"created":"2023-11-02T18:15:13Z","cvc2":null,"exactAmount":true,"expirationMMYY":"0224","externalToken":"ZTzke9TZiqXOGqzC","firstName":"Virtual","id":27086326,"invoiceNumber":"1002","lastFour":"3289","lastName":"Card","notes":null,"numberOfTransactions":1,"poNumber":null,"usageTypes":["Restaurants","Fuel","Medical","Financial","Business","Legal/Ins.","Airline","Miscellaneous","Misc. Transport","Hotels","Maintenance","Car rentals"]}';
            resp.setStatusCode(200);
            resp.setStatus('Success');
            resp.setBody(mockBody);
            return resp;
        }
    }
}