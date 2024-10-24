@IsTest
public with sharing class GLAccountTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testRetrieveBalanceFiresEvent() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            GLAccountBalanceOption opts = new GLAccountBalanceOption();
            opts.inquiryDate = Date.today();
            opts.requestId = 'my_test';
            opts.ledgerId = testData.ledgers[0].Id;        
            opts.glAccountId = testData.glAccounts[0].Id;     
            opts.glVariable1Id = null;
            opts.glVariable2Id = null;
            opts.glVariable3Id = null;
            opts.glVariable4Id = null;

            Test.startTest();
            ServiceResult result = GLAccount.retrieveBalance(opts);
            Test.stopTest();

            System.assertEquals(true, result.isSuccess);
        }
    }

    @IsTest
    private static void testRetrieveBalanceInputHasBadIds() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            GLAccountBalanceOption opts = new GLAccountBalanceOption();
            opts.inquiryDate = Date.today();
            opts.requestId = 'my_test';
            opts.ledgerId = testData.contacts[0].Id;        // invalid ID
            opts.glAccountId = testData.contacts[0].Id;     // ""
            opts.glVariable1Id = testData.contacts[0].Id;   // ""
            opts.glVariable2Id = testData.contacts[0].Id;   // ""
            opts.glVariable3Id = testData.contacts[0].Id;   // ""
            opts.glVariable4Id = testData.contacts[0].Id;   // ""

            Test.startTest();
            ServiceResult result = GLAccount.retrieveBalance(opts);
            Test.stopTest();

            System.assertEquals(false, result.isSuccess);
            System.assertNotEquals(null, result.errors);
            System.assertEquals(6, result.errors.size());
        }
    }

    @IsTest
    private static void testRetrieveBalanceInputHasNullValues() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            GLAccountBalanceOption opts = new GLAccountBalanceOption();
            opts.inquiryDate = null;     // invalid
            opts.requestId = null;       // ""
            opts.ledgerId = null;        // ""
            opts.glAccountId = null;     // ""
            opts.glVariable1Id = null;
            opts.glVariable2Id = null;
            opts.glVariable3Id = null;
            opts.glVariable4Id = null;

            Test.startTest();
            ServiceResult result = GLAccount.retrieveBalance(opts);
            Test.stopTest();

            System.assertEquals(false, result.isSuccess);
            System.assertNotEquals(null, result.errors);
            System.assertEquals(4, result.errors.size());
        }
    }

    @IsTest
    private static void testRetrieveDefaults() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            List<GLAccountDefault> result = GLAccount.retrieveDefaults(testData.ledgers[0].Id);

            if (result != null) {
                System.assertEquals(16, result.size());
            }

        }
    }

    @IsTest
    private static void testSaveDefaults() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            List<GLAccountDefault> glAccountDefaults = new List<GLAccountDefault>();
            GLAccountDefault def = new GLAccountDefault();
            def.glAccount = testData.glAccounts[0];
            def.glAccountDefault = new GL_Account_Default__c(
                GL_Account__c = testData.glAccounts[0].Id,
                GL_Account_Specification__c = 'test spec',
                Ledger__c = testData.ledgers[0].Id,
                Unique_Key__c = 'test key'
            );
            def.ledger = testData.ledgers[0];

            glAccountDefaults.add(def);
            List<ServiceResult> result = GLAccount.saveDefaults(glAccountDefaults);

            if (result[0].isSuccess) {
                System.assertEquals(
                    'test spec',
                    [SELECT Id, GL_Account_Specification__c FROM GL_Account_Default__c WHERE GL_Account_Specification__c = 'test spec'][0].GL_Account_Specification__c
                );
            }

            def.glAccount = testData.glAccounts[1];

            List<ServiceResult> result2 = GLAccount.saveDefaults(glAccountDefaults);

            if (result2[0].isSuccess) {
                System.assertEquals(
                    testData.glAccounts[1].Id,
                    [SELECT Id, GL_Account__c FROM GL_Account_Default__c WHERE GL_Account_Specification__c = 'test spec'][0].GL_Account__c
                );
            }

            def.glAccount = null;

            List<ServiceResult> result3 = GLAccount.saveDefaults(glAccountDefaults);

            if (result3[0].isSuccess) {
                List<GL_Account_Default__c> defList = [SELECT Id, GL_Account__c FROM GL_Account_Default__c WHERE GL_Account_Specification__c = 'test spec'];
                System.assert(defList.isEmpty());
            }

        }
    }

    @IsTest
    private static void testCreateGLAccountDefaultsByLedger() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            delete [SELECT Id FROM GL_Account_Default__c];

            List<GLAccountDefault> emptyResult = GLAccount.retrieveDefaults(testData.ledgers[0].Id);
            System.assert(emptyResult.isEmpty());

            GLAccount.createGLAccountDefaultsByLedger(new Set<Id> {testData.ledgers[0].Id});
            List<GLAccountDefault> result = GLAccount.retrieveDefaults(testData.ledgers[0].Id);

            System.assertEquals(16, result.size());

            for (GLAccountDefault def : result) {
                System.assert(GLAccountDefaultsHandler.instance.glAccountNameByDefaultsSpecifications.keySet().contains(def.glAccountSpecification.DeveloperName));
            }

            GLAccount.createGLAccountDefaultsByLedger(new Set<Id> {testData.ledgers[1].Id});
            List<GLAccountDefault> budgetLedgerResult = GLAccount.retrieveDefaults(testData.ledgers[1].Id);

            System.assertEquals(16, budgetLedgerResult.size());

            for (GLAccountDefault def : budgetLedgerResult) {
                System.assert(GLAccountDefaultsHandler.instance.glAccountNameByDefaultsSpecifications.keySet().contains(def.glAccountSpecification.DeveloperName));
            }

        }
    }

    @IsTest
    private static void testCreateGLAccountDefaultsByLedgerWithCashFlow() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashFlowCategories(true);

        System.runAs(testData.users.get(1)) {
            delete [SELECT Id FROM GL_Account_Default__c];

            List<GLAccountDefault> emptyResult = GLAccount.retrieveDefaults(testData.ledgers[0].Id);
            System.assert(emptyResult.isEmpty());

            GLAccount.createGLAccountDefaultsByLedger(new Set<Id> {testData.ledgers[0].Id});

            List<GLAccountDefault> result = GLAccount.retrieveDefaults(testData.ledgers[0].Id);

            System.assertEquals(19, result.size());

            for (GLAccountDefault def : result) {
                System.assert(GLAccountDefaultsHandler.instance.glAccountNameByDefaultsSpecifications.keySet().contains(def.glAccountSpecification.DeveloperName));
            }
        }
    }

    @IsTest
    private static void testCreateGLAccountDefaultsByLedgerOnlyForCashFlow() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashFlowCategories(true);

        System.runAs(testData.users.get(1)) {
            delete [SELECT Id FROM GL_Account_Default__c];

            List<GLAccountDefault> emptyResult = GLAccount.retrieveDefaults(testData.ledgers[0].Id);
            System.assert(emptyResult.isEmpty());

            GLAccount.createGLAccountDefaultsByLedger(new Set<Id> {testData.ledgers[0].Id}, true);

            List<GLAccountDefault> result = GLAccount.retrieveDefaults(testData.ledgers[0].Id);

            System.assertEquals(3, result.size());

            for (GLAccountDefault def : result) {
                System.assert(GLAccountDefaultsHandler.instance.glAccountNameByDefaultsSpecifications.keySet().contains(def.glAccountSpecification.DeveloperName));
            }
        }
    }

}