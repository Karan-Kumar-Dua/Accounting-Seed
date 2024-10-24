@isTest
public class PaymentMethodActionsTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    public static void testAttemptToSaveSeveralDuplicatedPaymentMethod() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Payment_Processor__c proc = testData.paymentProcessors.get(0);

            List<Payment_Method__c> duplicatedPMs = new List<Payment_Method__c>();
            Payment_Method__c testPM1 = new Payment_Method__c(
                Customer__c = testData.accounts[0].Id,
                Expiration_Month__c = '12',
                Expiration_Year__c = '2018',
                Type__c = 'VISA',
                Last_Four_Digits__c = '7845',
                Status__c = 'Active',
                External_Id__c = '123456789',
                Payment_Processor__c = proc.Id
            );

            Payment_Method__c testPM2 = new Payment_Method__c(
                Customer__c = testData.accounts[0].Id,
                Expiration_Month__c = '12',
                Expiration_Year__c = '2018',
                Type__c = 'VISA',
                Last_Four_Digits__c = '7845',
                Status__c = 'Active',
                External_Id__c = '987456321',
                Payment_Processor__c = proc.Id
            );

            duplicatedPMs.add(testPM1);
            duplicatedPMs.add(testPM2);

            Test.startTest();
            DmlException dmlEx;
            try {
                insert duplicatedPMs;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(PaymentMethodActions.DUPLICATED_PAYMENT_METHOD_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @isTest
    public static void testPreventCreateDuplicatedPaymentMethod() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Payment_Processor__c proc = testData.paymentProcessors.get(0);

            Payment_Method__c testPM = new Payment_Method__c(
                Customer__c = testData.accounts[0].Id,
                Expiration_Month__c = '12',
                Expiration_Year__c = '2018',
                Type__c = 'VISA',
                Last_Four_Digits__c = '7845',
                Status__c = 'Active',
                External_Id__c = '123456789',
                Payment_Processor__c = proc.Id
            );

            insert testPM;

            Payment_Method__c testDuplicatedPM = new Payment_Method__c(
                Customer__c = testData.accounts[0].Id,
                Expiration_Month__c = '12',
                Expiration_Year__c = '2018',
                Type__c = 'VISA',
                Last_Four_Digits__c = '7845',
                Status__c = 'Active',
                External_Id__c = '987456321',
                Payment_Processor__c = proc.Id
            );

            Test.startTest();

            DmlException dmlEx;
            try {
                insert testDuplicatedPM;
            }
            catch(DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(PaymentMethodActions.DUPLICATED_PAYMENT_METHOD_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @isTest
    public static void testRequiredFieldsMissingInsert() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Payment_Processor__c proc = testData.paymentProcessors.get(0);

            Payment_Method__c testPM = new Payment_Method__c(
                Customer__c = testData.accounts[0].Id,
                Expiration_Month__c = '12',
                Expiration_Year__c = '2018',
                Type__c = NULL,//required
                Last_Four_Digits__c = '7845',
                Status__c = NULL,//required
                External_Id__c = '123456789',
                Payment_Processor__c = proc.Id
            );

            Test.startTest();

            DmlException dmlEx;
            try {
                insert testPM;
            }
            catch(DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @isTest
    public static void testRequiredFieldsMissingUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Payment_Processor__c proc = testData.paymentProcessors.get(0);

            Payment_Method__c testPM = new Payment_Method__c(
                Customer__c = testData.accounts[0].Id,
                Expiration_Month__c = '12',
                Expiration_Year__c = '2018',
                Type__c = 'Visa',//required
                Last_Four_Digits__c = '7845',
                Status__c = 'Active',//required
                External_Id__c = '123456789',
                Payment_Processor__c = proc.Id
            );

            Test.startTest();

            DmlException dmlEx;
            try {
                insert testPM;
            }
            catch(DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);

            try {
                testPM.Type__c = NULL;
                testPM.Status__c = NULL;
                update testPM;
            }
            catch(DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @isTest
    public static void testOneDefaultPaymentMethod() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Payment_Processor__c proc = testData.paymentProcessors.get(0);

            //create two default PM
            Payment_Method__c testPM1 = new Payment_Method__c(
                Customer__c = testData.accounts[0].Id,
                Expiration_Month__c = '11',
                Expiration_Year__c = '2017',
                Type__c = 'MASTERCARD',
                Last_Four_Digits__c = '9999',
                Status__c = 'Active',
                External_Id__c = '123456789',
                Default__c = true,
                Payment_Processor__c = proc.Id
            );

            insert testPM1;

            Payment_Method__c testPM2 = new Payment_Method__c(
                Customer__c = testData.accounts[0].Id,
                Expiration_Month__c = '12',
                Expiration_Year__c = '2018',
                Type__c = 'VISA',
                Last_Four_Digits__c = '7845',
                Status__c = 'Active',
                External_Id__c = '987654321',
                Default__c = true,
                Payment_Processor__c = proc.Id
            );

            PaymentMethodActions.isFirstRun = true;
            insert testPM2;

            //expected: only one default PM in DB after insert
            System.assertEquals(1, [SELECT count() FROM Payment_Method__c WHERE Default__c = true AND Customer__c = :testData.accounts[0].Id]);

            //update non-default PM and try to make as default
            List<Payment_Method__c> nonDefaultPMs = [
                SELECT Id, Default__c
                FROM Payment_Method__c
                WHERE Default__c = false LIMIT 1
            ];
            nonDefaultPMs[0].Default__c = true;
            PaymentMethodActions.isFirstRun = true;
            PaymentMethodEditController pmEditController = new PaymentMethodEditController(nonDefaultPMs[0]);
            pmEditController.updateOnSFSideOnly();

            //expected: PM previously marked as Default is not Default anymore
            System.assertEquals(1, [SELECT count() FROM Payment_Method__c WHERE Default__c = true]);
        }

    }

    @IsTest
    public static void testPaymentMethodNoNullPointerExceptionInsert() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency(); //will throw an exception in case of non-MC org

            System.runAs(testData.users.get(1)) {
                DMLException dmlEx;

                Payment_Method__c pm = new Payment_Method__c();

                try {
                    insert pm;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }

                System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));

            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testOneDefaultPaymentMethodBulk() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Payment_Processor__c proc = testData.paymentProcessors.get(0);

            List<Payment_Method__c> methods = new List<Payment_Method__c>{
                new Payment_Method__c(
                    Customer__c = testData.accounts[0].Id,
                    Expiration_Month__c = '11',
                    Expiration_Year__c = '2017',
                    Type__c = 'MASTERCARD',
                    Last_Four_Digits__c = '9999',
                    Status__c = 'Active',
                    External_Id__c = '123456789',
                    Default__c = true,
                    Payment_Processor__c = proc.Id
                ),
                new Payment_Method__c(
                    Customer__c = testData.accounts[0].Id,
                    Expiration_Month__c = '12',
                    Expiration_Year__c = '2018',
                    Type__c = 'VISA',
                    Last_Four_Digits__c = '7845',
                    Status__c = 'Active',
                    External_Id__c = '987654321',
                    Default__c = true,
                    Payment_Processor__c = proc.Id
                ),
                new Payment_Method__c(
                    Customer__c = testData.accounts[0].Id,
                    Expiration_Month__c = '12',
                    Expiration_Year__c = '2018',
                    Type__c = 'VISA',
                    Last_Four_Digits__c = '7445',
                    Status__c = 'Active',
                    External_Id__c = '987654399',
                    Default__c = true,
                    Payment_Processor__c = proc.Id
                )
            };

            PaymentMethodActions.isFirstRun = true;
            insert methods;

            //expected: only one default PM in DB after insert
            Assert.areEqual(1, [SELECT count() FROM Payment_Method__c WHERE Default__c = true AND Customer__c = :testData.accounts[0].Id]);

            methods[2].Default__c = true;
            update methods[2];
            methods[0].Default__c = false;
            methods[1].Default__c = true;
            PaymentMethodActions.isFirstRun = true;
            update new List<Payment_Method__c>{ methods[0], methods[1] };
            //expected: only one default PM in DB after update
            Assert.areEqual(1, [SELECT count() FROM Payment_Method__c WHERE Default__c = true AND Customer__c = :testData.accounts[0].Id]);

            methods[2].Default__c = true;
            update methods[2];
            methods[0].Default__c = true;
            methods[1].Default__c = false;
            PaymentMethodActions.isFirstRun = true;
            update methods;
            //expected: only one default PM in DB after update
            Assert.areEqual(1, [SELECT count() FROM Payment_Method__c WHERE Default__c = true AND Customer__c = :testData.accounts[0].Id]);

            methods[2].Default__c = true;
            update methods[2];
            methods[0].Default__c = false;
            methods[1].Default__c = false;
            PaymentMethodActions.isFirstRun = true;
            update methods;
            //expected: only default PM in DB after update
            Assert.areEqual(1, [SELECT count() FROM Payment_Method__c WHERE Default__c = true AND Customer__c = :testData.accounts[0].Id]);

            methods[2].Default__c = true;
            update methods[2];
            methods[0].Default__c = true;
            methods[1].Default__c = true;
            PaymentMethodActions.isFirstRun = true;
            update methods;
            //expected: only one default PM in DB after update
            Assert.areEqual(1, [SELECT count() FROM Payment_Method__c WHERE Default__c = true AND Customer__c = :testData.accounts[0].Id]);

            methods[2].Default__c = false;
            update methods[2];
            methods[0].Default__c = false;
            methods[1].Default__c = false;
            PaymentMethodActions.isFirstRun = true;
            update methods;
            //expected: no one default PM in DB after update
            Assert.areEqual(0, [SELECT count() FROM Payment_Method__c WHERE Default__c = true AND Customer__c = :testData.accounts[0].Id]);
        }
    }


    @isTest
    public static void testBypassPreventDuplicatedPaymentMethodForAP() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Payment_Processor__c proc = new Payment_Processor__c(
                Type__c = PaymentProcessorActions.EDENRED_TYPE,
                PaymentSite_URL__c = 'https://example.accountingseed.com',
                Default_Ledger__c = testData.ledgers[0].Id
            );

            insert proc;

            Payment_Method__c testPM = new Payment_Method__c(
                Vendor__c = testData.accounts[0].Id,
                Expiration_Month__c = '12',
                Expiration_Year__c = '2018',
                Type__c = 'VISA',
                Last_Four_Digits__c = '7845',
                Status__c = 'Active',
                External_Id__c = '999999999',
                Payment_Processor__c = proc.Id
            );

            insert testPM;

            Payment_Method__c testDuplicatedPM = new Payment_Method__c(
                Vendor__c = testData.accounts[0].Id,
                Expiration_Month__c = '12',
                Expiration_Year__c = '2018',
                Type__c = 'VISA',
                Last_Four_Digits__c = '7845',
                Status__c = 'Active',
                External_Id__c = '888888888',
                Payment_Processor__c = proc.Id
            );

            Test.startTest();

            DmlException dmlEx;
            try {
                insert testDuplicatedPM;
            }
            catch(DmlException ex) {
                dmlEx = ex;
            }

            Assert.areEqual(NULL, dmlEx);
            Assert.areEqual(2, [SELECT Id FROM Payment_Method__c].size());
        }
    }

    @isTest
    public static void testOnlyOneDefaultAPPaymentMethod(){
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)){
            Boolean exceptionThrown = false;
            Payment_Processor__c paymentProcessor = testData.paymentProcessors.get(0);

            Payment_Method__c firstPaymentMethod = new Payment_Method__c(
                Vendor__c = testData.accounts[0].Id, 
                Expiration_Month__c = '02', 
                Expiration_Year__c = '2024', 
                Type__c = 'VISA', 
                Last_Four_Digits__c = '1111', 
                Status__c = 'Active', 
                External_Id__c = '345451921', 
                Default__c = true, 
                Payment_Processor__c = paymentProcessor.Id
            );

            insert firstPaymentMethod;

            Payment_Method__c secondPaymentMethod = new Payment_Method__c(
                Vendor__c = testData.accounts[0].Id, 
                Expiration_Month__c = '2', 
                Expiration_Year__c = '2019', 
                Type__c = 'VISA', 
                Last_Four_Digits__c = '7845', 
                Status__c = 'Active', 
                External_Id__c = '987456321', 
                Default__c = true, 
                Payment_Processor__c = paymentProcessor.Id
            );

            Test.startTest();
            try{
                insert secondPaymentMethod;
            } catch (Exception e){
                exceptionThrown = e.getMessage().contains(String.format(Label.ERR_DEFAULT_PAYMENT_METHOD, new List<String>{ testData.accounts[0].Name }));
            }
            Assert.isTrue(exceptionThrown);
            
            Test.stopTest();
        }
    }

    @isTest
    public static void testApAutoPostMessage() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True); 
        TestDataSuite testData = TestDataSuite.getInstance();
        
        System.runAs(testData.users.get(1)) {
            Test.startTest(); 
                Boolean exceptionThrown = false;
                try{
                    SingleRequestMock awsSuccess = new SingleRequestMock(
                        200,
                        'Complete',
                        AwsServiceTest.UPDATE_VENDOR_JSON,
                        new Map<String, String>{'Content-Type' => 'application/json'}
                    );
                    Test.setMock(HttpCalloutMock.class, awsSuccess);                 
                    //queueable 1 enable account for AP Auto
                    Account acct = testData.accounts[0];
                    acct.Enable_Payment_Services__c = true; 
                    update acct; 
                
                    //queueable 2
                    Payment_Method__c testPM = createDeafultPaymentMethod(acct.Id);
                    insert testPM;
                }
                catch(Exception ex){
                    exceptionThrown = true;
                } 
                System.assertEquals(false,exceptionThrown);
            Test.stopTest();
            //one job is queued from the acct update and 1 is queued from the PM insertion
            system.assertEquals(2, [SELECT Count() FROM AsyncApexJob WHERE ApexClass.Name = 'APAutomationService']);
        }    
    }

    @isTest
    public static void testApAutoPostMessageUpdateMonitoredField() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True); 
        TestDataSuite testData = TestDataSuite.getInstance();
        
        System.runAs(testData.users.get(1)) {
            Test.startTest(); 
                Boolean exceptionThrown = false;
                try{
                    SingleRequestMock awsSuccess = new SingleRequestMock(
                        200,
                        'Complete',
                        AwsServiceTest.UPDATE_VENDOR_JSON,
                        new Map<String, String>{'Content-Type' => 'application/json'}
                    );
                    Test.setMock(HttpCalloutMock.class, awsSuccess);
                    
                    //queueable 1 - enable account for AP Auto
                    Account acct = testData.accounts[0];
                    acct.Enable_Payment_Services__c = true; 
                    update acct; 
                    
                    //queueable 2
                    Payment_Method__c testPM = createDeafultPaymentMethod(acct.Id);
                    insert testPM;

                    //queueable 3
                    testPM.Account_Number__c = '123456789';
                    update testPM;
                }
                catch(Exception ex){
                    exceptionThrown = true;
                } 
                System.assertEquals(false,exceptionThrown);
            Test.stopTest();
            //one job is queued from the acct update,1 is queued from the PM insertion, 1 from the update becuase we monitor changes on acct number
            system.assertEquals(3, [SELECT Count() FROM AsyncApexJob WHERE ApexClass.Name = 'APAutomationService']);
        }    
    }

    @isTest
    public static void testApAutoPostMessageUpdateNonMonitoredField() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True); 
        TestDataSuite testData = TestDataSuite.getInstance();
        
        System.runAs(testData.users.get(1)) {
            Test.startTest(); 
                Boolean exceptionThrown = false;
                try{
                    SingleRequestMock awsSuccess = new SingleRequestMock(
                        200,
                        'Complete',
                        AwsServiceTest.UPDATE_VENDOR_JSON,
                        new Map<String, String>{'Content-Type' => 'application/json'}
                    );
                    Test.setMock(HttpCalloutMock.class, awsSuccess);
                
                    //queueable 1 - enable account for AP Auto
                    Account acct = testData.accounts[0];
                    acct.Enable_Payment_Services__c = true; 
                    update acct; 
                    
                    //queueable 2
                    Payment_Method__c testPM = createDeafultPaymentMethod(acct.Id);
                    insert testPM;

                    //NO queuebale for update, field is not montiored for changes
                    testPM.Expiration_Month__c = '01';
                    update testPM;
                }
                catch(Exception ex){
                    exceptionThrown = true;
                } 
                System.assertEquals(false,exceptionThrown);
            Test.stopTest();
            //one job is queued from the acct update,1 is queued from the PM insertion, 0 from the update becuase that is not a field we track changes on
            system.assertEquals(2, [SELECT Count() FROM AsyncApexJob WHERE ApexClass.Name = 'APAutomationService']);
        }    
    }

    @isTest
    public static void testCreateDefaultPMVendorNotAPAutoEnabled() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True); 
        TestDataSuite testData = TestDataSuite.getInstance();
        
        System.runAs(testData.users.get(1)) {
            Test.startTest(); 
                Boolean exceptionThrown = false;

                //this PM is not for a AP Enabled vendor so no SQS message should be sent for it on insert or update
                Payment_Method__c testPM = createDeafultPaymentMethod(testData.accounts[0].Id);
                insert testPM;
                System.assertEquals(false,exceptionThrown);
            Test.stopTest();
            system.assertEquals(0, [SELECT Count() FROM AsyncApexJob WHERE ApexClass.Name = 'APAutomationService']);
        }    
    }

    @isTest
    public static void testsetAPExternalID_PaymentServices_Bank() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Payment_Processor__c proc = testData.paymentProcessors.get(0);

            Payment_Method__c testPM = new Payment_Method__c(
                Vendor__c = testData.accounts[0].Id,
                Expiration_Month__c = '12',
                Expiration_Year__c = '2018',
                Type__c = 'VISA',
                Last_Four_Digits__c = '7845',
                Status__c = 'Active',
                External_Id__c = '123456789',
                Payment_Processor__c = proc.Id,
                Account_Number__c = '000005678',
                Routing_Number__c = '000001234',
                Payment_Method_Type__c = 'Bank Account',
                Bank_Account_Type__c = 'Business'
            );

            Test.startTest();
            insert testPM;

            testPM = [SELECT Id, Vendor__c, AP_External_Id__c, External_Id__c, Routing_Number__c, Account_Number__c FROM Payment_Method__c WHERE Id = :testPM.Id];
            Assert.isNotNull(testPM);
            Assert.areEqual(PaymentMethodActions.buildCompositeKeyForAPBankPaymentMethod(testPM), testPM.AP_External_Id__c);
            Assert.areEqual(PaymentMethodActions.buildCompositeKeyForAPBankPaymentMethod(testPM), testPM.External_Id__c);
        }
    }

    //Virtal Card PMs are created from Edenred and will have the card id set in the ext id fields
    @isTest
    public static void testsetAPExternalID_PaymentServices_VC() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Payment_Processor__c proc = testData.paymentProcessors.get(0);

            Payment_Method__c testPM = new Payment_Method__c(
                Vendor__c = testData.accounts[0].Id,
                Expiration_Month__c = '12',
                Expiration_Year__c = '2018',
                Type__c = 'VISA',
                Last_Four_Digits__c = '7845',
                Status__c = 'Active',
                External_Id__c = '123456789',
                Payment_Processor__c = proc.Id,
                Account_Number__c = '000005678',
                Routing_Number__c = '000001234',
                Payment_Method_Type__c = 'Virtual Card',
                AP_External_Id__c = '8675309'
            );

            Test.startTest();
            insert testPM;

            testPM = [SELECT Id, Vendor__c, AP_External_Id__c, External_Id__c, Routing_Number__c, Account_Number__c FROM Payment_Method__c WHERE Id = :testPM.Id];
            Assert.isNotNull(testPM);
            Assert.areEqual('8675309', testPM.AP_External_Id__c);
            Assert.areEqual('123456789', testPM.External_Id__c);
        }
    }

    @isTest
    public static void testsetAPExternalID_NONPaymentServices() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Payment_Processor__c proc = testData.paymentProcessors.get(0);

            Payment_Method__c testPM = new Payment_Method__c(
                Customer__c = testData.accounts[0].Id,
                Expiration_Month__c = '12',
                Expiration_Year__c = '2018',
                Type__c = 'VISA',
                Last_Four_Digits__c = '7845',
                Status__c = 'Active',
                External_Id__c = '123456789',
                Payment_Processor__c = proc.Id,
                Account_Number__c = '000005678',
                Routing_Number__c = '000001234',
                Payment_Method_Type__c = 'Bank Account',
                Bank_Account_Type__c = 'Business'
            );

            Test.startTest();
            insert testPM;

            testPM = [SELECT Id, Vendor__c, AP_External_Id__c, External_Id__c, Routing_Number__c, Account_Number__c FROM Payment_Method__c WHERE Id = :testPM.Id];
            Assert.isNotNull(testPM);
            Assert.isNull(testPM.AP_External_Id__c);
        }
    }

    @isTest
    public static void testAccountNumberWithoutDashAndSpace(){
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)){
            Boolean exceptionThrown = false;
            Payment_Processor__c paymentProcessor = testData.paymentProcessors.get(0);

            Payment_Method__c firstPaymentMethod = new Payment_Method__c(
                Vendor__c = testData.accounts[0].Id, 
                Expiration_Month__c = '02', 
                Expiration_Year__c = '2024', 
                Type__c = 'VISA', 
                Last_Four_Digits__c = '1111', 
                Status__c = 'Active', 
                External_Id__c = '345451921', 
                Default__c = true, 
                Payment_Processor__c = paymentProcessor.Id,
                Account_Number__c = '123 937'
            );

            Test.startTest();
            try{
                insert firstPaymentMethod;
            } catch (Exception e){
                exceptionThrown = e.getMessage().contains('The Account Number cannot contain any dashes or spaces.');
            }
            Assert.isTrue(exceptionThrown);
            
            Test.stopTest();
        }
    }

    private static Payment_Method__c createDeafultPaymentMethod(id acctId){
        TestDataSuite testData = TestDataSuite.getInstance();
        Payment_Processor__c proc = new Payment_Processor__c(
            Type__c = PaymentProcessorActions.EDENRED_TYPE,
            PaymentSite_URL__c = 'https://example.accountingseed.com',
            Default_Ledger__c = testData.ledgers[0].Id
        );

        insert proc;
        Payment_Method__c testPM = new Payment_Method__c(
                        Vendor__c = acctId,
                        Expiration_Month__c = '12',
                        Expiration_Year__c = '2018',
                        Type__c = 'VISA',
                        Last_Four_Digits__c = '7845',
                        Status__c = 'Active',
                        External_Id__c = '999999999',
                        Payment_Processor__c = proc.Id,
                        Default__c = true
                    );
        return testPM;
    }
}