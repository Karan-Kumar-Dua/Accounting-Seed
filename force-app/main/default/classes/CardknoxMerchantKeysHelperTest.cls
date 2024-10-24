@IsTest
public with sharing class CardknoxMerchantKeysHelperTest {
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    @IsTest
    static void testGetKeysSuccess(){
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            String uuid = FinancialSuiteUtils.getUUIDNoTestCheck();
            Keys__c key = new Keys__c();
            key.Name = uuid;
            key.KeyId__c = uuid;
            key.Value_1__c = 'testxkey';
            key.Value_2__c = 'testifieldskey';
            INSERT key;

            Test.startTest();
            CardknoxMerchantKeysHelper.Keys keys = CardknoxMerchantKeysHelper.getKeys(uuid);
            System.assertEquals(key.Name,keys.externalKey);
            System.assertEquals(keys.xKey,CardknoxMerchantKeysHelper.HIDDEN_VALUE);
            System.assertEquals(keys.iFieldsKey,CardknoxMerchantKeysHelper.HIDDEN_VALUE);
            Test.stopTest();
        }
    }
    @IsTest
    static void testGetKeysEmptyInput(){
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            CardknoxMerchantKeysHelper.Keys keys = CardknoxMerchantKeysHelper.getKeys('');
            System.assertEquals('',keys.externalKey);
            System.assertEquals('',keys.xKey);
            System.assertEquals('',keys.iFieldsKey);
            Test.stopTest();
        }
    }
    @IsTest
    static void testGetKeysInvalidInput(){
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Payment_Processor__c> paymentProcessors = [SELECT External_Key__c FROM Payment_Processor__c WHERE Id = :testData.paymentProcessors[0].Id];

            CardknoxMerchantKeysHelper.Keys keys = CardknoxMerchantKeysHelper.getKeys(paymentProcessors[0].External_Key__c);
            System.assertEquals(paymentProcessors[0].External_Key__c,keys.externalKey);
            System.assertEquals('',keys.xKey);
            System.assertEquals('',keys.iFieldsKey);
            Test.stopTest();
        }
    }
    @IsTest
    static void testUpsertKeysSuccess(){
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();
        System.runAs(testData.users.get(1)) {
            String uuid = FinancialSuiteUtils.getUUIDNoTestCheck();

            Keys__c key = new Keys__c();
            key.Name = uuid;
            key.KeyId__c = uuid;
            key.Value_1__c = 'testxkey';
            key.Value_2__c = 'testifieldskey';
            INSERT key;

            Test.startTest();
            CardknoxMerchantKeysHelper.Keys keys = new CardknoxMerchantKeysHelper.Keys(key);
            keys.xKey = 'testxkeyupdated';
            keys.iFieldsKey = 'testifieldskeyupdated';

            CardknoxMerchantKeysHelper.upsertUserKeys(JSON.serialize(keys), testData.paymentProcessors[0].Id);

            System.assertEquals(keys.externalKey,Keys__c.getValues(uuid).Name);
            System.assertEquals(keys.xKey,Keys__c.getValues(uuid).Value_1__c);
            System.assertEquals(keys.iFieldsKey,Keys__c.getValues(uuid).Value_2__c);
            Test.stopTest();
        }
    }
    @IsTest
    static void testUpsertKeysSuccess2(){
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();
        System.runAs(testData.users.get(1)) {
            String uuid = FinancialSuiteUtils.getUUIDNoTestCheck();

            Keys__c key = new Keys__c();
            key.Name = uuid;
            key.KeyId__c = uuid;
            key.Value_1__c = 'testxkey';
            key.Value_2__c = 'testifieldskey';
            INSERT key;

            Test.startTest();
            CardknoxMerchantKeysHelper.Keys keys = new CardknoxMerchantKeysHelper.Keys(key);
            keys.xKey = 'testxkeyupdated';
            keys.externalKey = 'cardknox1';
            keys.iFieldsKey = 'testifieldskeyupdated';

            CardknoxMerchantKeysHelper.upsertUserKeys(JSON.serialize(keys), testData.paymentProcessors[0].Id);
			Payment_Processor__c pp = [SELECT Id, Active__c FROM Payment_Processor__c WHERE Id = :testData.paymentProcessors[0].Id];
            System.assertNotEquals(keys.externalKey,Keys__c.getValues(uuid).KeyId__c);
            System.assertEquals(keys.externalKey,Keys__c.getValues(keys.externalKey).Name);
            System.assertEquals(keys.xKey,Keys__c.getValues(keys.externalKey).Value_1__c);
            System.assertEquals(keys.iFieldsKey,Keys__c.getValues(keys.externalKey).Value_2__c);
            System.assertEquals(true, pp.Active__c);
            
            Test.stopTest();
        }
    }
}