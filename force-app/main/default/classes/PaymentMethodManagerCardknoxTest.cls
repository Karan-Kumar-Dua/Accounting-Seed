@isTest
public with sharing class PaymentMethodManagerCardknoxTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
        Keys__c key = new Keys__c();
        key.Name = 'cardknox1';
        key.KeyId__c = 'cardknox1';
        key.Value_1__c = 'testxkey';
        key.Value_2__c = 'testifieldskey';
        INSERT key;
    }

    @IsTest
    public static void testClassConstructor() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Payment_Processor__c proc = testData.paymentProcessors.get(0);

            Test.startTest();
            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.accounts[0]);
            PaymentMethodManagerCardknox controller = new PaymentMethodManagerCardknox(stdController);
            controller.selectedProcessor = proc.Id;
            
            System.assertEquals(0, controller.ccPaymentMethods.size(), 'There are card type payment methods available');
            System.assertEquals(0, controller.achPaymentMethods.size(), 'There are check type payment methods available');
            System.assertEquals(proc.Id, controller.selectedProcessor, 'The Selected Processor Id is not matching');
            Test.stopTest();
        }
    }
    @IsTest
    public static void testClassConstructorError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Payment_Processor__c proc = testData.paymentProcessors.get(0);

            Test.startTest();
            PaymentMethodManagerCardknox controller = new PaymentMethodManagerCardknox(null);
            
            List<Apexpages.Message> msgs = ApexPages.getMessages();
            System.assertEquals(1, msgs.size(), 'Page has no errors');

            Test.stopTest();
        }
    }
    @IsTest
    public static void testCreditCardInputs() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Payment_Processor__c proc = testData.paymentProcessors.get(0);

            Test.startTest();
            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.accounts[0]);
            PaymentMethodManagerCardknox controller = new PaymentMethodManagerCardknox(stdController);
            controller.selectedProcessor = proc.Id;

            PageReference pageRef = Page.PaymentMethodManagerCardknox;
            pageRef.getParameters().put('cardToken', '12345654321');
            pageRef.getParameters().put('expMonth', '12');
            pageRef.getParameters().put('expYear', '2024');
            pageRef.getParameters().put('holderName', 'example user');
            Test.setCurrentPage(pageRef);

            controller.creditCardInputs();
            
            List<Apexpages.Message> msgs = ApexPages.getMessages();
            System.assertEquals(1, msgs.size(), 'Page has no errors');
            System.assertEquals(proc.Id, controller.selectedProcessor, 'The Selected Processor Id is not matching');
            Test.stopTest();
        }
    }
    @IsTest
    public static void testAchInputs() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Payment_Processor__c proc = testData.paymentProcessors.get(0);

            Test.startTest();
            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.accounts[0]);
            PaymentMethodManagerCardknox controller = new PaymentMethodManagerCardknox(stdController);
            controller.selectedProcessor = proc.Id;

            PageReference pageRef = Page.PaymentMethodManagerCardknox;
            pageRef.getParameters().put('achToken', '12345654321');
            pageRef.getParameters().put('routing', '12345678');
            pageRef.getParameters().put('name', 'Test');
            Test.setCurrentPage(pageRef);

            PageReference pageRefRes =  controller.achInputs();
            
            System.assertEquals(null, pageRefRes, 'Page Reference has a value in it');
            List<Apexpages.Message> msgs = ApexPages.getMessages();
            System.assertEquals(1, msgs.size(), 'Page has no errors');
            Test.stopTest();
        }
    }

    @IsTest
    public static void testSwitchStatus() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Payment_Processor__c proc = testData.paymentProcessors.get(0);

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = proc.Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Credit Card', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Type__c ='Visa');

            INSERT pm;
            
            Test.startTest();
            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.accounts[0]);
            PaymentMethodManagerCardknox controller = new PaymentMethodManagerCardknox(stdController);
            controller.selectedProcessor = proc.Id;
            controller.payMethodIdForChangeStatus = pm.Id;
            
            PageReference pageRefRes =  controller.switchStatusOfPaymentMethod();
            
            System.assertEquals(null, pageRefRes, 'Page Reference has a value in it');
            System.assertEquals('Inactive', [SELECT Status__c FROM Payment_Method__c][0].Status__c, 'Payment Method is Active');
            Test.stopTest();
        }
    }
    @IsTest
    public static void testSwitchStatusToInActive() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Payment_Processor__c proc = testData.paymentProcessors.get(0);

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = proc.Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Credit Card', Status__c='Inactive',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Type__c ='Visa');

            INSERT pm;
            
            Test.startTest();
            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.accounts[0]);
            PaymentMethodManagerCardknox controller = new PaymentMethodManagerCardknox(stdController);
            controller.selectedProcessor = proc.Id;
            controller.payMethodIdForChangeStatus = pm.Id;

            PageReference pageRefRes =  controller.switchStatusOfPaymentMethod();
            
            System.assertEquals(null, pageRefRes, 'Page Reference has a value in it');
            System.assertEquals('Active', [SELECT Status__c FROM Payment_Method__c][0].Status__c, 'Payment Method is InActive');
            Test.stopTest();
        }
    }
    @IsTest
    public static void testSwitchStatusWithError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Payment_Processor__c proc = testData.paymentProcessors.get(0);
          
            Test.startTest();
            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.accounts[0]);
            PaymentMethodManagerCardknox controller = new PaymentMethodManagerCardknox(stdController);
            controller.selectedProcessor = proc.Id;

            PageReference pageRefRes =  controller.switchStatusOfPaymentMethod();
            System.assertEquals(null, pageRefRes, 'Page Reference has a value in it');

            List<Apexpages.Message> msgs = ApexPages.getMessages();
            System.assertEquals(1, msgs.size(), 'Page has no errors');
            Test.stopTest();
        }
    }
    @IsTest
    public static void testSetDefaultPaymentMethod() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Payment_Processor__c proc = testData.paymentProcessors.get(0);
            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = proc.Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Credit Card', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Type__c ='Visa');

            INSERT pm;

            Test.startTest();
            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.accounts[0]);
            PaymentMethodManagerCardknox controller = new PaymentMethodManagerCardknox(stdController);
            controller.selectedProcessor = proc.Id;
            controller.payMethodIdForSetDefault = pm.Id;

            PageReference pageRefRes =  controller.setDefaultPaymentMethod();
            System.assertEquals(null, pageRefRes, 'Page Reference has a value in it');

            List<Apexpages.Message> msgs = ApexPages.getMessages();
            System.assertEquals(1, msgs.size(), 'Page has no errors');
            Test.stopTest();
        }
    }
    @IsTest
    public static void testUpdateProcessor() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Payment_Processor__c proc = testData.paymentProcessors.get(2);

            Test.startTest();
            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.accounts[0]);
            PaymentMethodManagerCardknox controller = new PaymentMethodManagerCardknox(stdController);
            controller.selectedProcessor = proc.Id;

            PageReference pageRefRes =  controller.updateProcessor();
            System.assertEquals(null, pageRefRes, 'Page Reference has a value in it');
            System.assertEquals(proc.Id, controller.selectedProcessor, 'Processor Id is not matching');

            List<Apexpages.Message> msgs = ApexPages.getMessages();
            System.debug(msgs);
            System.assertEquals(0, msgs.size(), 'Page has no errors');
            Test.stopTest();
        }
    }
    @IsTest
    public static void testGetCardnoxMonth() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {

            PaymentMethodManagerCardknox pmCard = new PaymentMethodManagerCardknox(null);
            Test.startTest();
            Assert.areEqual('01',pmCard.getCreditCardMonth('1'));
            Assert.areEqual('11',pmCard.getCreditCardMonth('11'));
            Test.stopTest();
        }
    }
    @IsTest
    public static void testGetCardnoxYear() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            PaymentMethodManagerCardknox pmCard = new PaymentMethodManagerCardknox(null);
            
            Test.startTest();
            String response = '';
            response = pmCard.getCreditCardYear('1');
            Assert.areEqual((String.valueOf(System.today().year()).left(4 - response.length()) + response),response);
            response = pmCard.getCreditCardYear('23');
            Assert.areEqual((String.valueOf(System.today().year()).left(4 - response.length()) + response),response);
            response = pmCard.getCreditCardYear('023');
            Assert.areEqual((String.valueOf(System.today().year()).left(4 - response.length()) + response),response);
            response = pmCard.getCreditCardYear('2025');
            Assert.areEqual((String.valueOf(System.today().year()).left(4 - response.length()) + response),response);
            Test.stopTest();
        }
    }
}