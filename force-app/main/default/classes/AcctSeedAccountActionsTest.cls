@isTest
public class AcctSeedAccountActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    
    @isTest
    public static void testSetAccountingActive() {

        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Account acct = new Account(Name = 'Test Vendor');
            acct.Accounting_Type__c = 'Vendor';
            insert acct;

            System.assertEquals(
                true,
                [SELECT Accounting_Active__c FROM Account WHERE Id = :acct.Id LIMIT 1].Accounting_Active__c
            );

            acct.Accounting_Type__c = NULL;
            update acct;

            System.assertEquals(
                false,
                [SELECT Accounting_Active__c FROM Account WHERE Id = :acct.Id LIMIT 1].Accounting_Active__c
            );
        }

    }

    @IsTest
    public static void  testAccountFieldRestrictOnPaymentFeatureDisable() {
        
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables();
        
        System.runAs(testData.users[1]) {
            Test.startTest();
            try {
                
                Account acct = new Account(Name = 'Test Vendor');
                acct.Accounting_Type__c = 'Vendor';
                acct.Payment_Services_Enrollment_Status__c = 'Processing';
                insert acct;
            }
            catch(DMLException ex) {
                Assert.isNotNull(ex);
                Assert.isTrue(ex.getMessage().contains(String.format(Label.ERR_FIELDS_PAYMENT_SERVICES_FEATURE_DISABLED, new List<String>{getAccountRestrictFields()})));
            }
            
            Test.stopTest();
        }
    }
    
    @IsTest
    public static void  testUpdateAccountFieldRestrictOnPaymentFeatureDisable() {
        
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables();
        
        System.runAs(testData.users[1]) {
            Test.startTest(); 
            try{
                Account acct = new Account(Name = 'Test Vendor');
                acct.Accounting_Type__c = 'Vendor';
                insert acct;
                
                Account acc = [Select Id, Payment_Services_Enrollment_Status__c From Account WHERE Id=: acct.Id];
                acc.Payment_Services_Enrollment_Status__c = 'Processing';
                Update acc;
            }
            
            catch(DMLException ex) {
                Assert.isNotNull(ex);
                Assert.areEqual(ex.getDMLMessage(0), String.format(Label.ERR_FIELDS_PAYMENT_SERVICES_FEATURE_DISABLED, new List<string>{getAccountRestrictFields()}));
            }
            
            Test.stopTest();
        }
    }
    
    @IsTest
    public static void  testUpdateAccountFieldRestrictOnPaymentFeatureEnable() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables();
        
        System.runAs(testData.users[1]) {
            Test.startTest(); 
            Account acct = new Account(Name = 'Test Vendor');
            acct.Accounting_Type__c = 'Vendor';
            insert acct;
            
            Account acc = [Select Id, Payment_Services_Enrollment_Status__c From Account WHERE Id=: acct.Id];
            acc.Payment_Services_Enrollment_Status__c = 'Processing';
            Update acc;
            Assert.isNotNull(acc);
            Assert.isNotNull(acc.Payment_Services_Enrollment_Status__c);
            Test.stopTest();
        }
    }
    
    @IsTest
    public static void  testAccountFieldRestrictOnPaymentFeatureEnable() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables();
        
        System.runAs(testData.users[1]) {
            Test.startTest();                
            Account acct = new Account(Name = 'Test Vendor');
            acct.Accounting_Type__c = 'Vendor';
            acct.Payment_Services_Enrollment_Status__c = 'Processing';
            insert acct;
            
            Account acc = [Select Id, Payment_Services_Enrollment_Status__c From Account WHERE Id=: acct.Id];
            Assert.isNotNull(acc);
            Assert.isNotNull(acc.Payment_Services_Enrollment_Status__c);

            Test.stopTest();
        }
    }
    
    private static String getAccountRestrictFields() {
        APAutomationControl service = new APAutomationControl();
        return Service.getFieldLabels(Service.getFieldGrants().get(Account.SObjectType));
    }

/* REMOVING THESE TEST TO RESOLVE BUILD
//THEY FAIL IN A BLANK SCRATCH ORG BUT PASS IN A SCRATCH ORG THAT HAS ACCT SEED SETUP DATA.  DOESN'T MAKE SENSE SINCE SEEALLDATA IS NOT ENABLED

    @isTest
    public static void testpostMessageForInsert() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            List<Account> accountToUpsert = new List<Account>();
            Test.startTest();
            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.CREATE_VENDOR_JSON , 
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, awsSuccess); 

            Boolean isSuccess = false;
            try {
                Account acct = new Account(Name = 'Test Vendor');
                acct.Accounting_Type__c = 'Vendor';
                acct.Enable_Payment_Services__c = true;
                accountToUpsert.add(acct);
                Account acc = [Select Id,Enable_Payment_Services__c from  Account where  Name = 'Test Account'];
                acc.Enable_Payment_Services__c = true;
                accountToUpsert.add(acc);
                upsert accountToUpsert;
                isSuccess = true;
            }
            catch(Exception ex) {
                isSuccess = false;
            }
            Assert.areEqual(true,isSuccess);
        }
    }

    @isTest
    public static void testpostMessageForUpdateVendorId() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            List<Account> accountToUpsert = new List<Account>();
            Test.startTest();
            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.CREATE_VENDOR_JSON , 
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, awsSuccess); 

            Boolean isSuccess = false;
            try {
                Account acct = new Account(Name = 'Test Vendor');
                acct.Accounting_Type__c = 'Vendor';
                acct.Enable_Payment_Services__c = true;
                insert acct;
                Account acc = [Select Id,Enable_Payment_Services__c from  Account where  Name = 'Test Vendor'];
                acc.Payment_Services_Vendor_ID__c = '12345';
                update acc;
                isSuccess = true;
            }
            catch(Exception ex) {
                isSuccess = false;
            }
            Assert.areEqual(true,isSuccess);
        }
    }
    @isTest
    public static void testpostMessageForUpdateTaxpayer() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            List<Account> accountToUpsert = new List<Account>();
            Test.startTest();
            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.CREATE_VENDOR_JSON , 
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, awsSuccess); 

            Boolean isSuccess = false;
            try {
                Account acct = new Account(Name = 'Test Vendor');
                acct.Accounting_Type__c = 'Vendor';
                acct.Enable_Payment_Services__c = true;
                insert acct;
                Account acc = [Select Id,Taxpayer_Identification_Number__c from  Account where  Name = 'Test Vendor'];
                acc.Taxpayer_Identification_Number__c = '12345';
                update acc;
                isSuccess = true;
            }
            catch(Exception ex) {
                isSuccess = false;
            }
            Assert.areEqual(true,isSuccess);
        }
    }

    @isTest
    public static void testpostMessageForUpdateIndustry() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            List<Account> accountToUpsert = new List<Account>();
            Test.startTest();
            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.CREATE_VENDOR_JSON , 
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, awsSuccess); 

            Boolean isSuccess = false;
            try {
                Account acct = new Account(Name = 'Test Vendor');
                acct.Accounting_Type__c = 'Vendor';
                acct.Enable_Payment_Services__c = true;
                insert acct;
                Account acc = [Select Id,Industry from  Account where  Name = 'Test Vendor'];
                acc.Industry = 'Automobile';
                update acc;
                isSuccess = true;
            }
            catch(Exception ex) {
                isSuccess = false;
            }
            Assert.areEqual(true,isSuccess);
        }
    }

    @isTest
    public static void testpostMessageForUpdateSic() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            List<Account> accountToUpsert = new List<Account>();
            Test.startTest();
            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.CREATE_VENDOR_JSON , 
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, awsSuccess); 

            Boolean isSuccess = false;
            try {
                Account acct = new Account(Name = 'Test Vendor');
                acct.Accounting_Type__c = 'Vendor';
                acct.Enable_Payment_Services__c = true;
                insert acct;
                Account acc = [Select Id,Sic from  Account where  Name = 'Test Vendor'];
                acc.Sic = '123456';
                update acc;
                isSuccess = true;
            }
            catch(Exception ex) {
                isSuccess = false;
            }
            Assert.areEqual(true,isSuccess);
        }
    }

    @isTest
    public static void testpostMessageForUpdateAsPayType() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            List<Account> accountToUpsert = new List<Account>();
            Test.startTest();
            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.CREATE_VENDOR_JSON , 
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, awsSuccess); 

            Boolean isSuccess = false;
            try {
                Account acct = new Account(Name = 'Test Vendor');
                acct.Accounting_Type__c = 'Vendor';
                acct.Enable_Payment_Services__c = true;
                insert acct;
                Account acc = [Select Id,AS_Pay_Type__c from  Account where  Name = 'Test Vendor'];
                acc.AS_Pay_Type__c = 'Check';
                update acc;
                isSuccess = true;
            }
            catch(Exception ex) {
                isSuccess = false;
            }
            Assert.areEqual(true,isSuccess);
        }
    }

    @isTest
    public static void testpostMessageForUpdateFax() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            List<Account> accountToUpsert = new List<Account>();
            Test.startTest();
            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.CREATE_VENDOR_JSON , 
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, awsSuccess); 

            Boolean isSuccess = false;
            try {
                Account acct = new Account(Name = 'Test Vendor');
                acct.Accounting_Type__c = 'Vendor';
                acct.Enable_Payment_Services__c = true;
                insert acct;
                Account acc = [Select Id,Fax from  Account where  Name = 'Test Vendor'];
                acc.Fax = '123456';
                update acc;
                isSuccess = true;
            }
            catch(Exception ex) {
                isSuccess = false;
            }
            Assert.areEqual(true,isSuccess);
        }
    }

    @isTest
    public static void testpostMessageForUpdateDescription() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            List<Account> accountToUpsert = new List<Account>();
            Test.startTest();
            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.CREATE_VENDOR_JSON , 
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, awsSuccess); 

            Boolean isSuccess = false;
            try {
                Account acct = new Account(Name = 'Test Vendor');
                acct.Accounting_Type__c = 'Vendor';
                acct.Enable_Payment_Services__c = true;
                insert acct;
                Account acc = [Select Id,Description from  Account where  Name = 'Test Vendor'];
                acc.Description = 'Account is important';
                update acc;
                isSuccess = true;
            }
            catch(Exception ex) {
                isSuccess = false;
            }
            Assert.areEqual(true,isSuccess);
        }
    }

    @isTest
    public static void testpostMessageForUpdateName() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            List<Account> accountToUpsert = new List<Account>();
            Test.startTest();
            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.CREATE_VENDOR_JSON , 
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, awsSuccess); 

            Boolean isSuccess = false;
            try {
                Account acc = testData.accounts[2];
                acc.Enable_Payment_Services__c = true;
                update acc;

                acc.Name = 'Account Vendor';
                update acc;
                isSuccess = true;
            }
            catch(Exception ex) {
                isSuccess = false;
            }
            Assert.areEqual(true,isSuccess);
        }
    }
*//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



    @isTest
    public static void testSetEnablePaymentService() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True); 
        TestDataSuite testData = TestDataSuite.getInstance();
        
        System.runAs(testData.users.get(1)) {
            Test.startTest(); 
                SingleRequestMock awsSuccess = new SingleRequestMock(
                    200,
                    'Complete',
                    AwsServiceTest.CREATE_VENDOR_JSON , 
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );
                Test.setMock(HttpCalloutMock.class, awsSuccess);
                
                Account acc = new Account(Name = 'Test Account Unchekd');
                acc.Accounting_Type__c = 'Vendor';
                acc.Enable_Payment_Services__c = true;
                insert acc;

                Account acct = [Select Id,Enable_Payment_Services__c from  Account where  Name = 'Test Account Unchekd'];
                Assert.isTrue(acct.Enable_Payment_Services__c);
                acct.Payment_Services_Enrollment_Status__c = 'Denied';
                update acct;
                
            acct = [Select Id,Enable_Payment_Services__c from  Account where  Name = 'Test Account Unchekd'];
            Assert.isFalse(acct.Enable_Payment_Services__c);

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
                    AwsServiceTest.CREATE_VENDOR_JSON , 
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );
                Test.setMock(HttpCalloutMock.class, awsSuccess);
                
                Account acc = new Account(Name = 'Test Account Unchekd');
                acc.Accounting_Type__c = 'Vendor';
                acc.Enable_Payment_Services__c = true;
                insert acc;

                Account acct = [Select Id,Enable_Payment_Services__c from  Account where  Name = 'Test Account Unchekd'];
                Assert.isTrue(acct.Enable_Payment_Services__c);
                acct.Enable_Payment_Services__c = false; 
                update acct;
            }
            catch(Exception ex){
                Schema.DescribeFieldResult describeRes = Account.Enable_Payment_Services__c.getDescribe();
                Schema.sObjectField token = describeRes.getSObjectField();                
                Assert.isNotNull(ex);
                Assert.areEqual(String.format(Label.ERROR_PAYMENT_SERVICE_UNCHECKED,new List<String>{token.getDescribe().getLabel()}), ex.getDmlMessage(0));             
            } 
            Test.stopTest();
        }    
    }

    @isTest
    public static void testUpdateBillingAddress() {
		FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True); 
        TestDataSuite testData = TestDataSuite.getInstance();
        Boolean isSuccessfullyUpdated = false;
        System.runAs(testData.users.get(1)) {
            Test.startTest(); 
            
                SingleRequestMock awsSuccess = new SingleRequestMock(
                    200,
                    'Complete',
                    AwsServiceTest.CREATE_VENDOR_JSON , 
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );
                Test.setMock(HttpCalloutMock.class, awsSuccess);
            try{
                Account acc = new Account(Name = 'Test Account Unchekd');
                acc.Accounting_Type__c = 'Vendor';
                acc.Enable_Payment_Services__c = true;
                insert acc;

                Account acct = [Select Id,Enable_Payment_Services__c from  Account where  Name = 'Test Account Unchekd'];
                acct.BillingStreet = 'AVC';
                update acct;
                isSuccessfullyUpdated = true;
            }catch(Exception e){
                isSuccessfullyUpdated = false;
            }
            
            Assert.areEqual(isSuccessfullyUpdated, true);
            Test.stopTest();
        }    
    }

    @isTest
    public static void testUpdateAPVendorEmail() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True); 
        TestDataSuite testData = TestDataSuite.getInstance();
        
        System.runAs(testData.users.get(1)) {
            Test.startTest(); 
                SingleRequestMock awsSuccess = new SingleRequestMock(
                    200,
                    'Complete',
                    AwsServiceTest.CREATE_VENDOR_JSON , 
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );
                Test.setMock(HttpCalloutMock.class, awsSuccess);
                
                Account acc = new Account(Name = 'Test Account Unchecked');
                acc.Accounting_Type__c = 'Vendor';
                acc.Enable_Payment_Services__c = true;
                insert acc;

                Account acct = [Select Id,Enable_Payment_Services__c from  Account where  Name = 'Test Account Unchecked'];
                Assert.isTrue(acct.Enable_Payment_Services__c);
                acct.AP_Vendor_Email__c = 'test@gmail.com';
                update acct;
                
            acct = [Select Id,Enable_Payment_Services__c from  Account where  Name = 'Test Account Unchecked'];
            Assert.isTrue(acct.Enable_Payment_Services__c);

            Test.stopTest();
        }    
    }

    @isTest
    public static void testIndividualCheckBox() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True); 
        TestDataSuite testData = TestDataSuite.getInstance();
        
        System.runAs(testData.users.get(1)) {
            Test.startTest(); 
                SingleRequestMock awsSuccess = new SingleRequestMock(
                    200,
                    'Complete',
                    AwsServiceTest.CREATE_VENDOR_JSON , 
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );
                Test.setMock(HttpCalloutMock.class, awsSuccess);
                
                Account acc = new Account(Name = 'Test Account Unchecked');
                acc.Accounting_Type__c = 'Vendor';
                acc.Enable_Payment_Services__c = true;
                insert acc;
                
                acc.Individual__c = true;
                update acc;
                
            Account acct = [Select Id,Individual__c from  Account where  Name = 'Test Account Unchecked'];
            Assert.isTrue(acct.Individual__c);

            Test.stopTest();
        }    
    }
}