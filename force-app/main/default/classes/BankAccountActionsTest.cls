@IsTest
public with sharing class BankAccountActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    private static String getObjectLabel() {
        schema.SObjectType sObjType = Bank_Account__c.sobjectType;
        Schema.DescribeSObjectResult dr = sObjType.getDescribe();
        return dr.getLabel();
    }

    @IsTest
    public static void testBankAccountRequiredFields() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createBankAccounts();

        System.runAs(testData.users[1]) {
            
            Bank_Account__c bankAccount = [SELECT Id, Enable_for_Payment_Services__c, Payor_Name__c FROM Bank_Account__c WHERE Name = 'Test Account1'];
            bankAccount.Payor_Name__c = 'Test Payor';
            bankAccount.Ledger__c = testData.ledgers[0].Id;
            //This is giving no error since Payment Services are not enabled
            update bankAccount;

            DMLException dmlEx;
            //This will give error since Payment Services are enabled
            try {
                bankAccount.Enable_for_Payment_Services__c = true;
                update bankAccount;
            }

            catch(DMLException ex) {
                dmlEx = ex;
            }
            Assert.areEqual('This field is required for Payment Services.', dmlEx.getDmlMessage(0));
        }
    }

    @IsTest 
    public static void testBankAccountObjectRestrictOnPaymentFeatureDisable(){
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Test.startTest();

            try {
                testData.createBankAccounts();
            }
            catch(DMLException ex) {
                APAutomationControl control = new APAutomationControl();
                List<Schema.SObjectField> fields = control.getFieldGrants().get(AcctSeed__Bank_Account__c.SObjectType);
                String fieldLabels = control.getFieldLabels(fields);
                Assert.isNotNull(ex);
                Assert.isTrue(ex.getMessage().contains(String.format(Label.ERR_FIELDS_PAYMENT_SERVICES_FEATURE_DISABLED,new List<String>{fieldLabels})));
            }

            Test.stopTest();
        }
    }

    @IsTest 
    public static void testBankAccountObjectRestrictOnPaymentFeatureEnable(){
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Test.startTest();

                FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);    
                TestDataSuite testBAs = testData.createBankAccounts();

            Test.stopTest();

            Assert.areEqual(3, testBAs.bankAccounts.size());
        }

    }

    @IsTest 
    public static void testUpdateBankAccountObjectRestrictOnPaymentFeatureDisable(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createBankAccounts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, False);
            try {
                Bank_Account__c bankAccount = [SELECT Id, Enable_for_Payment_Services__c, Payor_Name__c FROM Bank_Account__c WHERE Name = 'Test Account1'];
                bankAccount.Account_Number__c = '123456789';
                update bankAccount;

            }
            catch(DMLException ex) {
                Assert.isNotNull(ex);
                Assert.isTrue(ex.getMessage().contains(String.format(Label.ERR_OBJECT_FEATURE_DISABLED, new List<String>{getObjectLabel()})));
            }

            Test.stopTest();
        }
    }

    @IsTest 
    public static void testUpdateBankAccountObjectRestrictOnPaymentFeatureEnable(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createBankAccounts();

        System.runAs(testData.users[1]) {
            Test.startTest();

                Bank_Account__c bankAccount = [SELECT Id, Enable_for_Payment_Services__c, Payor_Name__c FROM Bank_Account__c WHERE Name = 'Test Account1'];
                bankAccount.Account_Number__c = '123456789';
                update bankAccount;

            Test.stopTest();

            Assert.areEqual('123456789', [SELECT Account_Number__c FROM Bank_Account__c WHERE Id = :bankAccount.Id].Account_Number__c);
        }
    }
    
    @IsTest 
    public static void testCallAwsToPostPayload(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createBankAccounts();

        System.runAs(testData.users[1]) {
            List<Bank_Account__c> bankAccountToUpsert = new List<Bank_Account__c>();
            Test.startTest();
                //Setting of mock
                SingleRequestMock awsSuccess = new SingleRequestMock(
                    200,
                    'Complete',
                    AwsServiceTest.CREATE_BANK_ACCOUNT_JSON , 
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );
    
                Test.setMock(HttpCalloutMock.class, awsSuccess); 

                Boolean isSuccess = false;
                try {
                    Bank_Account__c bankAccount = new Bank_Account__c(
                        Name = 'Test Account1',
                        Account_Number__c = '123456789',
                        Routing_Number__c = '123456789',
                        Enable_for_Payment_Services__c = true
                    );
                    bankAccountToUpsert.add(bankAccount);
                    Bank_Account__c existingBc = [Select Id,Enable_for_Payment_Services__c from  Bank_Account__c where  Name = 'Test Account1'];
                    existingBc.Enable_for_Payment_Services__c = true;
                    existingBc.Account_Number__c = '123456789';
                    existingBc.Routing_Number__c = '123456789';
                    bankAccountToUpsert.add(existingBc);
                    upsert bankAccountToUpsert;
                    isSuccess = true;
                }
                catch(Exception ex) {
                    isSuccess = false;
                }
                Assert.areEqual(true,isSuccess);
                

            Test.stopTest();

        }
    }

    @IsTest 
    public static void testCallAwsToPostPayloadForUpdate(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createBankAccounts();

        System.runAs(testData.users[1]) {
            Test.startTest();
                //Setting of mock
                SingleRequestMock awsSuccess = new SingleRequestMock(
                    200,
                    'Complete',
                    AwsServiceTest.UPDATE_BANK_ACCOUNT_JSON , 
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );
    
                Test.setMock(HttpCalloutMock.class, awsSuccess); 

                Boolean isSuccess = false;
                try {
                    Bank_Account__c bankAccount = new Bank_Account__c(
                        Name = 'Test Account1',
                        Payment_Services_Enrollment_Status__c = 'Not Enrolled',
                        Account_Number__c = '123456789',
                        Routing_Number__c = '123456789',
                        Enable_for_Payment_Services__c = true
                    );
                   insert bankAccount;
                    Bank_Account__c existingBc = [Select Id,Routing_Number__c from  Bank_Account__c where  Name = 'Test Account1'][0];
                    existingBc.Routing_Number__c = '123456789';
                   
                    update existingBc;
                    isSuccess = true;
                }
                catch(Exception ex) {
                    isSuccess = false;
                }
                Assert.areEqual(true,isSuccess);
                

            Test.stopTest();

        }
    }

    @IsTest 
    public static void testCallAwsToPostPayloadForUpdateAccountType(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createBankAccounts();

        System.runAs(testData.users[1]) {
            Test.startTest();
                //Setting of mock
                SingleRequestMock awsSuccess = new SingleRequestMock(
                    200,
                    'Complete',
                    AwsServiceTest.CREATE_BANK_ACCOUNT_JSON , 
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );
    
                Test.setMock(HttpCalloutMock.class, awsSuccess); 

                Boolean isSuccess = false;
                try {
                    Bank_Account__c bankAccount = new Bank_Account__c(
                        Name = 'Test Account1',
                        Payment_Services_Enrollment_Status__c = 'Not Enrolled',
                        Account_Number__c = '123456789',
                        Routing_Number__c = '123456789',
                        Enable_for_Payment_Services__c = true
                    );
                   insert bankAccount;
                    Bank_Account__c existingBc = [Select Id,Account_Type__c from  Bank_Account__c where  Name = 'Test Account1'][0];
                    existingBc.Account_Type__c = 'Checking';
                   
                    upsert existingBc;
                    isSuccess = true;
                }
                catch(Exception ex) {
                    isSuccess = false;
                }
                Assert.areEqual(true,isSuccess);
                

            Test.stopTest();

        }
    }

    @IsTest 
    public static void testCallAwsToPostPayloadForUpdateBankAccountId(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createBankAccounts();

        System.runAs(testData.users[1]) {
            Test.startTest();
                //Setting of mock
                SingleRequestMock awsSuccess = new SingleRequestMock(
                    200,
                    'Complete',
                    AwsServiceTest.CREATE_BANK_ACCOUNT_JSON , 
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );
    
                Test.setMock(HttpCalloutMock.class, awsSuccess); 

                Boolean isSuccess = false;
                try {
                    Bank_Account__c bankAccount = new Bank_Account__c(
                        Name = 'Test Account1',
                        Payment_Services_Enrollment_Status__c = 'Not Enrolled',
                        Account_Number__c = '123456789',
                        Routing_Number__c = '123456789',
                        Enable_for_Payment_Services__c = true
                    );
                   insert bankAccount;
                    Bank_Account__c existingBc = [Select Id,Payment_Services_Bank_Account_ID__c from  Bank_Account__c where  Name = 'Test Account1'][0];
                    existingBc.Payment_Services_Bank_Account_ID__c = '12345';
                   
                    update existingBc;
                    isSuccess = true;
                }
                catch(Exception ex) {
                    isSuccess = false;
                }
                Assert.areEqual(true,isSuccess);
                

            Test.stopTest();

        }
    }

    
    
    @IsTest 
    public static void testCallAwsToPostPayloadForUpdateName(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createBankAccounts();

        System.runAs(testData.users[1]) {
            Test.startTest();
                //Setting of mock
                SingleRequestMock awsSuccess = new SingleRequestMock(
                    200,
                    'Complete',
                    AwsServiceTest.CREATE_BANK_ACCOUNT_JSON , 
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );
    
                Test.setMock(HttpCalloutMock.class, awsSuccess); 

                Boolean isSuccess = false;
                try {
                    Bank_Account__c bankAccount = new Bank_Account__c(
                        Name = 'Test Account1',
                        Payment_Services_Enrollment_Status__c = 'Not Enrolled',
                        Account_Number__c = '123456789',
                        Routing_Number__c = '123456789',
                        Enable_for_Payment_Services__c = true
                    );
                   insert bankAccount;
                    Bank_Account__c existingBc = [Select Id,Name from  Bank_Account__c where  Name = 'Test Account1'][0];
                    existingBc.Name = 'Bank Account';
                   
                    update existingBc;
                    isSuccess = true;
                }
                catch(Exception ex) {
                    isSuccess = false;
                }
                Assert.areEqual(true,isSuccess);
                

            Test.stopTest();

        }
    }

    @IsTest 
    public static void testCallAwsToPostPayloadForUpdatePayorEmail(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createBankAccounts();

        System.runAs(testData.users[1]) {
            Test.startTest();
                //Setting of mock
                SingleRequestMock awsSuccess = new SingleRequestMock(
                    200,
                    'Complete',
                    AwsServiceTest.CREATE_BANK_ACCOUNT_JSON , 
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );
    
                Test.setMock(HttpCalloutMock.class, awsSuccess); 

                Boolean isSuccess = false;
                try {
                    Bank_Account__c bankAccount = new Bank_Account__c(
                        Name = 'Test Account1',
                        Payment_Services_Enrollment_Status__c = 'Not Enrolled',
                        Account_Number__c = '123456789',
                        Routing_Number__c = '123456789',
                        Enable_for_Payment_Services__c = true
                    );
                   insert bankAccount;
                    Bank_Account__c existingBc = [Select Id,Payor_Email__c from  Bank_Account__c where  Name = 'Test Account1'][0];
                    existingBc.Payor_Email__c = 'abc@gmail.com';
                   
                    update existingBc;
                    isSuccess = true;
                }
                catch(Exception ex) {
                    isSuccess = false;
                }
                Assert.areEqual(true,isSuccess);
                

            Test.stopTest();

        }
    }

    @IsTest 
    public static void testCallAwsToPostPayloadForUpdateAccountNumber(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createBankAccounts();

        System.runAs(testData.users[1]) {
            Test.startTest();
                //Setting of mock
                SingleRequestMock awsSuccess = new SingleRequestMock(
                    200,
                    'Complete',
                    AwsServiceTest.CREATE_BANK_ACCOUNT_JSON , 
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );
    
                Test.setMock(HttpCalloutMock.class, awsSuccess); 

                Boolean isSuccess = false;
                try {
                    Bank_Account__c bankAccount = new Bank_Account__c(
                        Name = 'Test Account1',
                        Payment_Services_Enrollment_Status__c = 'Not Enrolled',
                        Account_Number__c = '123456789',
                        Routing_Number__c = '123456789',
                        Enable_for_Payment_Services__c = true
                    );
                   insert bankAccount;
                    Bank_Account__c existingBc = [Select Id,Account_Number__c from  Bank_Account__c where  Name = 'Test Account1'][0];
                    existingBc.Account_Number__c = '123456';
                   
                    update existingBc;
                    isSuccess = true;
                }
                catch(Exception ex) {
                    isSuccess = false;
                }
                Assert.areEqual(true,isSuccess);
                

            Test.stopTest();

        }
    }


    @isTest
    public static void testPreventEnablePaymentServiceUncheck() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True); 
        TestDataSuite testData = TestDataSuite.getInstance();
        
        System.runAs(testData.users.get(1)) {
            Test.startTest(); 
            try{
                SingleRequestMock awsSuccess = new SingleRequestMock(
                    200,
                    'Complete',
                    AwsServiceTest.CREATE_BANK_ACCOUNT_JSON , 
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );
                Test.setMock(HttpCalloutMock.class, awsSuccess);
                
                Bank_Account__c bankAccount = new Bank_Account__c(
                    Name = 'Test Account1',
                    Payment_Services_Enrollment_Status__c = 'Not Enrolled',
                    Account_Number__c = '123456789',
                    Routing_Number__c = '123456789',
                    Enable_for_Payment_Services__c = true
                );
                insert bankAccount;

                Bank_Account__c existingBc = [Select Id,Enable_for_Payment_Services__c from  Bank_Account__c where  Name = 'Test Account1'];
                Assert.isTrue(existingBc.Enable_for_Payment_Services__c);
                existingBc.Enable_for_Payment_Services__c = false; 
                update existingBc;
            }
            catch(Exception ex){
                Schema.DescribeFieldResult describeRes = Bank_Account__c.Enable_for_Payment_Services__c.getDescribe();
                Schema.sObjectField token = describeRes.getSObjectField();                
                Assert.isNotNull(ex);
                Assert.areEqual(String.format(Label.ERROR_PAYMENT_SERVICE_UNCHECKED,new List<String>{token.getDescribe().getLabel()}), ex.getDmlMessage(0));             
            } 
            Test.stopTest();
        }    
    }

    @isTest
    public static void testSetEnablePaymentService() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True); 
        TestDataSuite testData = TestDataSuite.getInstance();
        
        System.runAs(testData.users.get(1)) {
            Test.startTest(); 
                SingleRequestMock awsSuccess = new SingleRequestMock(
                    200,
                    'Complete',
                    AwsServiceTest.CREATE_BANK_ACCOUNT_JSON , 
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );
                Test.setMock(HttpCalloutMock.class, awsSuccess);
                
                Bank_Account__c bankAccount = new Bank_Account__c(
                    Name = 'Test Account1',
                    Payment_Services_Enrollment_Status__c = 'Not Enrolled',
                    Account_Number__c = '123456789',
                    Routing_Number__c = '123456789',
                    Enable_for_Payment_Services__c = true
                );
                insert bankAccount;

                Bank_Account__c existingBc = [Select Id,Enable_for_Payment_Services__c from  Bank_Account__c where  Name = 'Test Account1'];
                Assert.isTrue(existingBc.Enable_for_Payment_Services__c);
                existingBc.Payment_Services_Enrollment_Status__c = 'Denied';
                update existingBc;
                
            Test.stopTest();
            existingBc = [Select Id,Enable_for_Payment_Services__c from  Bank_Account__c where  Name = 'Test Account1'];
            Assert.isFalse(existingBc.Enable_for_Payment_Services__c);
        }    
    }

    @isTest
    public static void testUpdatePaymentServiceEnrollmentStatus() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
                SingleRequestMock awsSuccess = new SingleRequestMock(
                    200,
                    'Complete',
                    AwsServiceTest.CREATE_BANK_ACCOUNT_JSON ,
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );
                Test.setMock(HttpCalloutMock.class, awsSuccess);

                Bank_Account__c bankAccount = new Bank_Account__c(
                    Name = 'Test Account1',
                    Payment_Services_Enrollment_Status__c = 'Not Enrolled',
                    Account_Number__c = '123456789',
                    Routing_Number__c = '123456789',
                    Enable_for_Payment_Services__c = true
                );
                insert bankAccount;

                bankAccount.Payment_Services_Bank_Account_ID__c = '123456789';
                update bankAccount;

                Bank_Account__c existingBc = [Select Id,Payment_Services_Enrollment_Status__c from  Bank_Account__c where  Name = 'Test Account1'];
                System.assertEquals(existingBc.Payment_Services_Enrollment_Status__c,'Enrolled');
            Test.stopTest();

        }
    }

    @IsTest
    public static void testCallAwsToPostPayloadForUpdateSignatureBlock(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createBankAccounts();

        System.runAs(testData.users[1]) {
            Test.startTest();
                //Setting of mock
                SingleRequestMock awsSuccess = new SingleRequestMock(
                    200,
                    'Complete',
                    AwsServiceTest.CREATE_BANK_ACCOUNT_JSON ,
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );

                Test.setMock(HttpCalloutMock.class, awsSuccess);

                Boolean isSuccess = false;
                try {
                    Bank_Account__c bankAccount = new Bank_Account__c(
                        Name = 'Test Account1',
                        Payment_Services_Enrollment_Status__c = 'Not Enrolled',
                        Account_Number__c = '123456789',
                        Routing_Number__c = '123456789',
                        Enable_for_Payment_Services__c = true
                    );
                   insert bankAccount;
                    Bank_Account__c existingBc = [Select Id,Account_Number__c,Signature_Block__c from  Bank_Account__c where  Name = 'Test Account1'][0];
                    existingBc.Signature_Block__c = '123456';

                    update existingBc;
                    isSuccess = true;
                }
                catch(Exception ex) {
                    isSuccess = false;
                }
                Assert.areEqual(true,isSuccess);
            Test.stopTest();

        }
    }

    @isTest
    public static void testUpdatePayerName() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Boolean isSuccessfullyUpdated = false; 
            Test.startTest();
                SingleRequestMock awsSuccess = new SingleRequestMock(
                    200,
                    'Complete',
                    AwsServiceTest.CREATE_BANK_ACCOUNT_JSON ,
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );
                Test.setMock(HttpCalloutMock.class, awsSuccess);
                try{
                    Bank_Account__c bankAccount = new Bank_Account__c(
                    Name = 'Test Account1',
                    Payment_Services_Enrollment_Status__c = 'Not Enrolled',
                    Account_Number__c = '123456789',
                    Routing_Number__c = '123456789',
                    Enable_for_Payment_Services__c = true
                    );
                    insert bankAccount;

                    bankAccount.Payor_Name__c = '123456789';
                    bankAccount.Payor_Email__c = 'abc@abc111.com';
                    update bankAccount;
                    isSuccessfullyUpdated = true;
                }catch(Exception e){
                    isSuccessfullyUpdated = false;
                }
                Assert.areEqual(isSuccessfullyUpdated, true);
            Test.stopTest();

        }
    }
}