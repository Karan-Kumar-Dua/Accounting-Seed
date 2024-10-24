@IsTest
private class PaymentMethodEditControllerTest {


    @TestSetup
    static void createTestData() {
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.createPaymentProcessors();
            Account testAccount = new Account(Name = 'TestAcc');
            testAccount.Stripe_Customer_Id__c = 'STRIPECUSTOMERID';
            insert testAccount;

            Payment_Method__c testPM = new Payment_Method__c();
            testPM.Customer__c = testAccount.Id;
            testPM.Type__c = 'Visa';
            testPM.Card_Holder_Name__c = 'Mr. Yellow';
            testPM.Last_Four_Digits__c = '7878';
            testPM.Default__c = true;
            testPM.Expiration_Month__c = '05';
            testPM.Expiration_Year__c = '2020';
            testPM.External_Id__c = 'STRIPECARDID';
            testPM.Status__c = 'Active';
            testPM.Payment_Processor__c = testData.paymentProcessors[0].Id;
            insert testPM;

            Payment_Processor_Customer__c cust = new Payment_Processor_Customer__c();
            cust.Account__c = testPM.Customer__c;
            cust.External_Id__c = 'cust_894nfvaosndeg98er';
            cust.Processor__c = testPM.Payment_Processor__c;
            insert cust;

            System.assertEquals(1, [SELECT count() FROM Payment_Method__c WHERE Card_Holder_Name__c = 'Mr. Yellow' LIMIT 1]);
        }

    }

    @IsTest
    static void testUpdateViaUI() {
        User contextUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(contextUser) {
            Test.setMock(HttpCalloutMock.class, new MockStripeCalloutsHandler());
            Payment_Method__c pm = [SELECT Id FROM Payment_Method__c WHERE Type__c = 'Visa' LIMIT 1];
            ApexPages.StandardController stdController = new ApexPages.StandardController(pm);
            PaymentMethodEditController controller = new PaymentMethodEditController(stdController);

            Test.startTest();
            controller.paymentMethod.Card_Holder_Name__c = 'Mr. Black';
            controller.paymentMethod.Expiration_Month__c = '10';
            controller.paymentMethod.Expiration_Year__c = '2018';
            controller.paymentMethod.Status__c = 'Inactive';
            controller.paymentMethod.Default__c = false;
            PageReference pr = controller.updateViaUI();
            Payment_Method__c paymentMethod = [SELECT Card_Holder_Name__c, Expiration_Month__c, Expiration_Year__c, Status__c, Default__c 
                                                FROM Payment_Method__c WHERE Id = :controller.paymentMethod.Id];
                                                
            System.assertEquals('Mr. Black', paymentMethod.Card_Holder_Name__c);
            System.assertEquals('10', paymentMethod.Expiration_Month__c);
            System.assertEquals('2018', paymentMethod.Expiration_Year__c);
            System.assertEquals('Inactive', paymentMethod.Status__c);
            System.assertEquals(false, paymentMethod.Default__c);
        }

    }

    @IsTest
    static void testUpdateOnSFSideOnly() {
        User contextUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(contextUser) {
            Payment_Method__c pm = [
                SELECT  Id,
                    Card_Holder_Name__c,
                    Expiration_Month__c,
                    Expiration_Year__c,
                    Status__c
                FROM Payment_Method__c
                WHERE Type__c = 'Visa' LIMIT 1
            ];

            pm.Card_Holder_Name__c = 'Mr. Black';
            pm.Expiration_Month__c = '10';
            pm.Expiration_Year__c = '2018';
            pm.Status__c = 'Inactive';

            Test.startTest();

            PaymentMethodEditController controller = new PaymentMethodEditController(pm);
            controller.updateOnSFSideOnly();
            System.assertEquals(1, [SELECT count() FROM Payment_Method__c WHERE Card_Holder_Name__c = 'Mr. Black' LIMIT 1]);
        }

    }

    @IsTest
    static void testEditViaUIWithException() {
        User contextUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(contextUser) {
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new MockStripeCalloutsHandler());
            Payment_Method__c pm = [SELECT Id FROM Payment_Method__c WHERE Type__c = 'Visa' LIMIT 1];
            ApexPages.StandardController stdController = new ApexPages.StandardController(pm);
            PaymentMethodEditController controller = new PaymentMethodEditController(stdController);
            controller.paymentMethod.Card_Holder_Name__c = 'Mr. Black';
            controller.paymentMethod.Expiration_Month__c = '10';
            controller.paymentMethod.Expiration_Year__c = '2018';
            controller.paymentMethod.Status__c = 'Inactive';
            controller.paymentMethod.Type__c = 'MasterCard';//will lead to DML Exception
            controller.updateViaUI();
            Test.stopTest();
            System.assertEquals(0, [SELECT count() FROM Payment_Method__c WHERE Card_Holder_Name__c = 'Mr. Black' LIMIT 1]);
            System.assertEquals(1, [SELECT count() FROM Payment_Method__c WHERE Card_Holder_Name__c = 'Mr. Yellow' LIMIT 1]);
        }
    }

    public class MockStripeCalloutsHandler implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            String endpoint = req.getEndpoint();
            HttpResponse res = new HttpResponse();
            String jsonResponse;
            jsonResponse =
            '{' +
                '"id": "STRIPECARDID",' +
                '"object": "card",' +
                '"brand": "Visa",' +
                '"country": "US",' +
                '"customer": "STRIPECUSTOMERID",' +
                '"cvc_check": null,' +
                '"dynamic_last4": null,' +
                '"exp_month": 5,' +
                '"exp_year": 2020,' +
                '"funding": "credit",' +
                '"last4": "4242",' +
                '"metadata": {' +
                '},' +
                '"name": "Mr. Yellow",' +
                '"tokenization_method": null' +
            '}';

            res.setHeader('Content-Type', 'application/json');
            res.setBody(jsonResponse);
            res.setStatusCode(200);
            return res;
        }
    }
}