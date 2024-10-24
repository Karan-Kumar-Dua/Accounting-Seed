@IsTest
public with sharing class PaymentProcessorActionsTest {
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testValidateTestModeSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            testData.paymentProcessors[0].Connected_Account_Token__c = null;
            testData.paymentProcessors[0].Active__c = false;

            update testData.paymentProcessors[0];

            System.assertEquals(false, [
                    SELECT Test_Mode__c 
                    FROM Payment_Processor__c 
                    WHERE Id = :testData.paymentProcessors[0].Id
                ].Test_Mode__c
            );

            testData.paymentProcessors[0].Test_Mode__c = true;

            update testData.paymentProcessors[0];

            System.assertEquals(true, [
                    SELECT Test_Mode__c 
                    FROM Payment_Processor__c 
                    WHERE Id = :testData.paymentProcessors[0].Id
                ].Test_Mode__c
            );
        }
    }

    @IsTest
    public static void testValidateTestModeError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Exception expectedEx;
            try {
                testData.paymentProcessors[0].Test_Mode__c = true;
                update testData.paymentProcessors[0];
            } catch(DmlException ex) {
                expectedEx = ex;
            }
            
            System.assertNotEquals(null, expectedEx);
            System.assertEquals(Label.ERR_PAYMENTS_PROC_TEST_MODE_LOCKED, expectedEx.getDmlMessage(0));
        }
    }
    @IsTest
    public static void testValidateLedgerAndActiveFieldForActive() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Exception expectedEx;
            try {
                Payment_Processor__c paymentPros = new Payment_Processor__c(Name=testData.paymentProcessors[0].Name,Type__c=testData.paymentProcessors[0].Type__c);
                paymentPros.Active__c = true;
                INSERT paymentPros;
            } catch(DmlException ex) {
                expectedEx = ex;
            }
            
            System.assertNotEquals(null, expectedEx);
            System.assertEquals(Label.ERR_PAYMENTS_CAN_NO_LONGER_ACTIVE, expectedEx.getDmlMessage(0));
        }
    }
    @IsTest
    public static void testValidateLedgerAndActiveFieldForActiveUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {

            Exception expectedEx;
            try {
                testData.paymentProcessors[0].Connected_Account_Token__c = '';
                testData.paymentProcessors[0].Active__c = true;
                update testData.paymentProcessors[0];
            } catch(DmlException ex) {
                expectedEx = ex;
            }
            
            System.assertNotEquals(null, expectedEx);
            System.assertEquals(Label.ERR_PAYMENTS_CAN_NO_LONGER_ACTIVE, expectedEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testValidateDefaultPaymentProcessorsBeforeInsert() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Exception expectedEx;
            try {
                Payment_Processor__c paymentPros = new Payment_Processor__c(Name=testData.paymentProcessors[0].Name,Type__c=testData.paymentProcessors[0].Type__c,Global_Default_Payment_Processor__c=true);
                INSERT paymentPros;
            } catch(Exception ex) {
                expectedEx = ex;
            }
            System.assertNotEquals(null, expectedEx);
            System.assertEquals(true,expectedEx.getMessage().contains(Label.ERR_PAYMENTS_CAN_NOT_GLOBAL_DEFAULT));
        }
    }
    
    @IsTest
    public static void testValidateDefaultPaymentProcessors() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {

            Exception expectedEx;
            try {
                testData.paymentProcessors[0].Global_Default_Payment_Processor__c = true;
                update testData.paymentProcessors[0];
            } catch(DmlException ex) {
                expectedEx = ex;
            }
            System.assertNotEquals(null, expectedEx);
            System.assertEquals(true,expectedEx.getMessage().contains(Label.ERR_PAYMENTS_CAN_NOT_GLOBAL_DEFAULT));
        }
    }
    @IsTest
    public static void testDeletePaymentProcessor() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            List<Payment_Processor__c> paymentProcessors = [SELECT Id, External_Key__c FROM Payment_Processor__c WHERE Id = :testData.paymentProcessors[2].Id];

            Assert.isNotNull(Keys__c.getValues(paymentProcessors[0].External_Key__c));

            Test.startTest();
            DELETE paymentProcessors[0];
            Test.stopTest();

            Assert.isNull(Keys__c.getValues(paymentProcessors[0].External_Key__c));
        }
    }
    @IsTest
    public static void testDefaultExternalKey() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {

            System.assertNotEquals(null, [SELECT External_Key__c 
                    FROM Payment_Processor__c 
                    WHERE Id = :testData.paymentProcessors[0].External_Key__c]);
        }
    }
    @IsTest
    public static void testShouldNoExternalKeyOnInsert() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            List<Payment_Processor__c> paymentProcessors = new List<Payment_Processor__c>();

            paymentProcessors.add(
                new Payment_Processor__c(
                    Type__c = PaymentProcessorActions.STRIPE_TYPE,
                    Active__c = true,
                    External_Key__c = 'testKey 1',
                    Connected_Account_Token__c = 'acct_vpaow8envp98wnweh'
                )
            );

            paymentProcessors.add(
                new Payment_Processor__c(
                    Type__c = PaymentProcessorActions.STRIPE_TYPE,
                    Active__c = true,
                    External_Key__c = 'testKey 2',
                    Connected_Account_Token__c = 'acct_8u92oinmlksnuogwvr'
                )
            );

            try{
                INSERT paymentProcessors;
            }catch(Exception ex){
                Assert.areEqual(ex.getMessage().contains(String.format(SourceDocumentUpdateFieldValidator.UPDATE_ERROR,new List<String>{
                    Payment_Processor__c.External_Key__c.getDescribe().getLabel()
                })),true);
            }
        }
    }
    @IsTest
    public static void testCantEditExternalKey() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Payment_Processor__c pp = testData.paymentProcessors[0];
            pp.External_Key__c = 'testKey';

            try{
                UPDATE pp;
            }catch(Exception ex){
                Assert.areEqual(ex.getMessage().contains(String.format(SourceDocumentUpdateFieldValidator.UPDATE_ERROR,new List<String>{
                    Payment_Processor__c.External_Key__c.getDescribe().getLabel()
                })),true);
            }
        }
    }
    @IsTest
    public static void testValidateLedgerFieldOnInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Payment_Processor__c pp = new Payment_Processor__c(Name='Test PP', Type__c='Cardknox',Connected_Account_Token__c='123456');
            try{
                INSERT pp;
            }catch(Exception ex){
                Assert.areNotEqual(null,ex.getMessage());
                Assert.areEqual(ex.getMessage().contains(String.format(Label.ERR_FIELD_VALUE_MISSING, new List<String> {
                    Payment_Processor__c.Default_Ledger__c.getDescribe().getLabel()
                })),true);
            
            }
        }
    }
    @isTest
    public static void testValidateLedgerFieldOnUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Payment_Processor__c pp = testData.paymentProcessors[2];
            pp.Default_Ledger__c = null;
            pp.Active__c = false;
            try{
                UPDATE pp;
            }catch(Exception ex){
                Assert.areNotEqual(null,ex.getMessage());
                Assert.areEqual(ex.getMessage().contains(String.format(Label.ERR_FIELD_VALUE_MISSING, new List<String> {
                    Payment_Processor__c.Default_Ledger__c.getDescribe().getLabel()
                })),true);
            }
        }
    }

    @IsTest
    public static void testValidateGLAccountsRequieredFields() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            
            Exception expectedEx;

            Payment_Processor__c p = testData.paymentProcessors[0];
            p.Bank_GL_Account__c = null;
            p.Merchant_GL_Account__c = null;
            p.Merchant_Fees_GL_Account__c = null;
            try {
                update p;
            } catch(DmlException ex) {
                Assert.fail('expected successful update when payment processor type is not Cardknox');
            }

            p = testData.paymentProcessors[2];
            p.Bank_GL_Account__c = null;
            p.Merchant_GL_Account__c = testData.paymentProcessors[3].Merchant_GL_Account__c;
            p.Merchant_Fees_GL_Account__c = testData.paymentProcessors[3].Merchant_Fees_GL_Account__c;
            try {
                update p;
            } catch(DmlException ex) {
                expectedEx = ex;
            }
            
            Assert.isNotNull(expectedEx);
            Assert.isTrue(expectedEx.getMessage().contains(
                String.format(Label.ERR_CARDKNOX_PMT_PROCESSOR_RQUIRED_FIELD, new List<String> {
                    Payment_Processor__c.Bank_GL_Account__c.getDescribe().getLabel()
                })
            ));

            p.Bank_GL_Account__c = testData.paymentProcessors[3].Bank_GL_Account__c;
            p.Merchant_GL_Account__c = null;
            p.Merchant_Fees_GL_Account__c = testData.paymentProcessors[3].Merchant_Fees_GL_Account__c;
            try {
                update p;
            } catch(DmlException ex) {
                expectedEx = ex;
            }

            Assert.isTrue(expectedEx.getMessage().contains(
                String.format(Label.ERR_CARDKNOX_PMT_PROCESSOR_RQUIRED_FIELD, new List<String> {
                    Payment_Processor__c.Merchant_GL_Account__c.getDescribe().getLabel()
                })
            ));

            p.Bank_GL_Account__c = testData.paymentProcessors[3].Bank_GL_Account__c;
            p.Merchant_GL_Account__c = testData.paymentProcessors[3].Merchant_GL_Account__c;
            p.Merchant_Fees_GL_Account__c = null;
            try {
                update p;
            } catch(DmlException ex) {
                expectedEx = ex;
            }
            Assert.isTrue(expectedEx.getMessage().contains(
                String.format(Label.ERR_CARDKNOX_PMT_PROCESSOR_RQUIRED_FIELD, new List<String> {
                    Payment_Processor__c.Merchant_Fees_GL_Account__c.getDescribe().getLabel()
                })
            ));

            Test.stopTest();
        }
    }

    @IsTest
    public static void testValidateGLAccountsBankAndMerchantMatch() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            
            Exception expectedEx;

            Payment_Processor__c p = testData.paymentProcessors[2];
            p.Merchant_GL_Account__c =  p.Bank_GL_Account__c;
            try {
                update p;
            } catch(DmlException ex) {
                expectedEx = ex;
            }
            
            Assert.isNotNull(expectedEx);
            Assert.isTrue(expectedEx.getMessage().contains(
                String.format(Label.ERR_CARDKNOX_PMT_PROCESSOR_BANK_MATCHES_MERCHANT, new List<String> {
                    Payment_Processor__c.Bank_GL_Account__c.getDescribe().getLabel(),
                    Payment_Processor__c.Merchant_GL_Account__c.getDescribe().getLabel()
                })
            ));

            Test.stopTest();
        }
    }

    @IsTest
    public static void testValidateFeeSetupRequiredFields() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Payment_Processor__c p = testData.paymentProcessors[2];
            p.Enable_Convenience_Fees__c = true;
            
            Database.SaveResult result = Database.update(p, false);
            
            Assert.isFalse(result.isSuccess());
            Assert.areEqual(3, result.getErrors().size());
            List<String> errFields = new List<String>{ 
                GlobalVariables.PACKAGE_QUALIFIER + 'Convenience_Fees_GL_Account__c', 
                GlobalVariables.PACKAGE_QUALIFIER + 'Convenience_Fee_Mapping__c', 
                GlobalVariables.PACKAGE_QUALIFIER + 'Original_Amount_Mapping__c' 
            };
            String field;
            for (Database.Error err : result.getErrors()) {
                Assert.areEqual(Label.ERR_PAYMENT_PROCESSOR_REQUIRED_FOR_FEES, err.getMessage());
                field = err.getFields()[0];
                Assert.isTrue(errFields.contains(field));
                errFields.remove(errFields.indexOf(field));
            }
            Test.stopTest();
        }
    }

    @IsTest
    public static void testValidateFeeSetupDuplicateMappings() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Payment_Processor__c p = testData.paymentProcessors[2];
            p.Enable_Convenience_Fees__c = true;
            p.Convenience_Fees_GL_Account__c = testData.glAccounts[10].Id;
            p.Convenience_Fee_Mapping__c = 'xCustom10';
            p.Original_Amount_Mapping__c = 'xCustom10';

            Database.SaveResult result = Database.update(p, false);

            Assert.isFalse(result.isSuccess());
            Assert.areEqual(2, result.getErrors().size());
            List<String> errFields = new List<String>{ 
                GlobalVariables.PACKAGE_QUALIFIER + 'Convenience_Fee_Mapping__c', 
                GlobalVariables.PACKAGE_QUALIFIER + 'Original_Amount_Mapping__c'
            };
            String field;
            for (Database.Error err : result.getErrors()) {
                Assert.areEqual(Label.ERR_PAYMENT_PROCESSOR_DUPLICATE_FIELD_MAPPING, err.getMessage());
                field = err.getFields()[0];
                Assert.isTrue(errFields.contains(field));
                errFields.remove(errFields.indexOf(field));
            }
            Test.stopTest();
        }
    }

    @IsTest
    public static void testValidateFeeMapping() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Payment_Processor__c p = testData.paymentProcessors[2];
            p.Enable_Convenience_Fees__c = true;
            p.Convenience_Fees_GL_Account__c = testData.glAccounts[10].Id;
            p.Convenience_Fee_Mapping__c = null;
            p.Original_Amount_Mapping__c = null;

            Database.SaveResult result = Database.update(p, false);

            Assert.isFalse(result.isSuccess());
            Assert.areEqual(2, result.getErrors().size());
            List<String> errFields = new List<String>{ 
                GlobalVariables.PACKAGE_QUALIFIER + 'Convenience_Fee_Mapping__c', 
                GlobalVariables.PACKAGE_QUALIFIER + 'Original_Amount_Mapping__c'
            };
            String field;
            for (Database.Error err : result.getErrors()) {
                Assert.areEqual(Label.ERR_PAYMENT_PROCESSOR_REQUIRED_FOR_FEES, err.getMessage());
                field = err.getFields()[0];
                Assert.isTrue(errFields.contains(field));
                errFields.remove(errFields.indexOf(field));
            }
            Test.stopTest();
        }
    }
}