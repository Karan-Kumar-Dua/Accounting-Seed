@IsTest
public with sharing class BDCBankRulesHelperTest {
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testGetBankRules() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankRules();
        
        System.runAs(testData.users.get(1)) {
            String ruleType = 'Cash_In';
            List<Bank_Rule__c> rules;
            
            Test.startTest();
            rules = BDCBankRulesHelper.getBankRules(ruleType);
            Test.stopTest();

            System.assertEquals(2, rules.size());

            Decimal previousPriority;
            for(Bank_Rule__c rule : rules) {
                System.assertEquals(rule.Type__c, ruleType);
                if (previousPriority != null) {
                    System.assert(rule.Priority__c > previousPriority);
                }
                previousPriority = rule.Priority__c;
            }
        }
    }

    @IsTest
    private static void testGetBankRules_NoneExist() {
        TestDataSuite testData = TestDataSuite.getInstance();
        
        System.runAs(testData.users[1]) {
            String ruleType = 'Cash_In';
            List<Bank_Rule__c> rules;
            
            Test.startTest();
            rules = BDCBankRulesHelper.getBankRules(ruleType);
            Test.stopTest();

            System.assert(rules.isEmpty());
        }
    }

    @IsTest
    private static void testGetBankRule() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankRules();
        
        System.runAs(testData.users[1]) {
            BDCBankRulesHelper.BankRule rule;
            
            Test.startTest();
            rule = BDCBankRulesHelper.getBankRule(testData.bankRules[0].Id);
            Test.stopTest();

            System.assertEquals(testData.bankRules[0].Id, rule.rule.Id);
            System.assertEquals(testData.bankRuleGLAMs[0].GL_Account_Mapping__c, rule.glams[0]);
            System.assertEquals(testData.bankRuleConditions[0].Id, rule.conditions[0].Id);
            System.assertEquals(testData.bankRuleActions[0].Id, rule.actions[0].Id);
        }
    }

    @IsTest
    private static void testGetActionFields() {
        TestDataSuite testData = TestDataSuite.getInstance();
        
        System.runAs(testData.users[1]) {
            String ruleType = 'Cash_In';
            String sourceDocType = PACKAGE_QUALIFIER + 'Cash_Receipt__c';
            List<AbstractLWCHelper.CustomSelectOption> opts;
            
            Test.startTest();
            opts = BDCBankRulesHelper.getActionFields(ruleType, sourceDocType);
            Test.stopTest();

            List<String> values = BDCBankRulesHelper.actionFieldOptions.get(ruleType).get(sourceDocType);
            for (AbstractLWCHelper.CustomSelectOption opt : opts) {
                if (opt.value == PACKAGE_QUALIFIER + 'Cash_Flow_Category__c') {
                    System.assert(false, 'Cash Flow Category should not be included when cash flow is disabled.');
                }
                else {
                    System.assert(values.contains(opt.value));
                }
            }
        }
    }

    @IsTest
    private static void testGetActionFields_CashFlowEnabled() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashFlowCategories(true);
        
        System.runAs(testData.users[1]) {
            String ruleType = 'Cash_In';
            String sourceDocType = PACKAGE_QUALIFIER + 'Cash_Receipt__c';
            List<AbstractLWCHelper.CustomSelectOption> opts;
            
            Test.startTest();
            opts = BDCBankRulesHelper.getActionFields(ruleType, sourceDocType);
            Test.stopTest();

            List<String> values = BDCBankRulesHelper.actionFieldOptions.get(ruleType).get(sourceDocType);
            for (AbstractLWCHelper.CustomSelectOption opt : opts) {
                System.assert(values.contains(opt.value));
            }
        }
    }

    @IsTest
    private static void testGetFinancialInstitutionAccountOptions() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAMs();
        
        System.runAs(testData.users[1]) {
            List<AbstractLWCHelper.CustomSelectOption> fias;
            
            Test.startTest();
            fias = BDCBankRulesHelper.getFinancialInstitutionAccountOptions();
            Test.stopTest();

            System.assertEquals(3, fias.size());
        }
    }

    @IsTest
    private static void testGetFinancialInstitutionAccountOptions_NoneExist() {
        TestDataSuite testData = TestDataSuite.getInstance();
        
        System.runAs(testData.users[1]) {
            List<AbstractLWCHelper.CustomSelectOption> fias;
            
            Test.startTest();
            fias = BDCBankRulesHelper.getFinancialInstitutionAccountOptions();
            Test.stopTest();

            System.assert(fias.isEmpty());
        }
    }

    @IsTest
    private static void testGetFinancialInstitutionAccountOptions_FilterInactive() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAMs();
        
        System.runAs(testData.users[1]) {
            GLAccountMappingActions.isDmlRestrictionBypassEnabled = true;
            testData.glams[0].Inactive__c = true;
            GLAccountMappingActions.isDmlRestrictionBypassEnabled = true;
            update testData.glams[0];
            GLAccountMappingActions.isDmlRestrictionBypassEnabled = false;

            List<AbstractLWCHelper.CustomSelectOption> fias;
            
            Test.startTest();
            fias = BDCBankRulesHelper.getFinancialInstitutionAccountOptions();
            Test.stopTest();

            System.assertEquals(2, fias.size());
        }
    }

    @IsTest
    private static void testSaveBankRule_new() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankRules();

        System.runAs(testData.users[1]) {
            Bank_Rule__c rule = testData.bankRules[0].clone(false, false, false, false);
            rule.Priority__c = 110;

            List<Id> glams = new List<Id> { testData.glams[0].Id };

            List<Bank_Rule_Condition__c> conditions = new List<Bank_Rule_Condition__c> {
                testData.bankRuleConditions[0].clone(false, false, false, false)
            };

            List<Bank_Rule_Action__c> actions = new List<Bank_Rule_Action__c> {
                testData.bankRuleActions[0].clone(false, false, false, false)
            };

            List<Bank_Rule_Condition__c> deleteConditions = new List<Bank_Rule_Condition__c>();

            List<Bank_Rule_Action__c> deleteActions = new List<Bank_Rule_Action__c>();        
            
            Test.startTest();
            BDCBankRulesHelper.saveBankRule(
                rule,
                glams,
                conditions,
                actions,
                deleteConditions,
                deleteActions
            );
            Test.stopTest();

            System.assertNotEquals(null, rule.Id);
            System.assertNotEquals(null, conditions[0].Id);
            System.assertNotEquals(null, actions[0].Id);
            
            List<Bank_Rule_GLAM__c> resultGlams = [
                SELECT GL_Account_Mapping__c 
                FROM Bank_Rule_GLAM__c 
                WHERE Bank_Rule__c = :rule.Id
            ];
            System.assertEquals(1, resultGlams.size());
            System.assertEquals(glams[0], resultGlams[0].GL_Account_Mapping__c);
        }
    }

    @IsTest
    private static void testSaveBankRule_update() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankRules();

        System.runAs(testData.users[1]) {
            Bank_Rule__c rule = testData.bankRules[0];
            rule.Name = 'Updated Rule';

            List<Id> glams = new List<Id> { testData.glams[1].Id };

            testData.bankRuleConditions[0].Operator__c = 'Less_Than';
            List<Bank_Rule_Condition__c> conditions = new List<Bank_Rule_Condition__c> {
                testData.bankRuleConditions[0]
            };

            testData.bankRuleActions[0].Target_Field__c = PACKAGE_QUALIFIER + 'Credit_GL_Account__c';
            testData.bankRuleActions[0].Value__c = '{ \"' + PACKAGE_QUALIFIER + 'Credit_GL_Account__c\" : \"' + testData.glAccounts[1].Id + '\" }';
            List<Bank_Rule_Action__c> actions = new List<Bank_Rule_Action__c> {
                testData.bankRuleActions[0]
            };

            List<Bank_Rule_Condition__c> deleteConditions = new List<Bank_Rule_Condition__c>();

            List<Bank_Rule_Action__c> deleteActions = new List<Bank_Rule_Action__c>();        
            
            Test.startTest();
            BDCBankRulesHelper.saveBankRule(
                rule,
                glams,
                conditions,
                actions,
                deleteConditions,
                deleteActions
            );
            Test.stopTest();

            Bank_Rule__c resultRule = [
                SELECT Name 
                FROM Bank_Rule__c 
                WHERE Id = :rule.Id
                LIMIT 1
            ];
            System.assertEquals(rule.Name, resultRule.Name);

            List<Bank_Rule_Condition__c> resultConditions = [
                SELECT Operator__c
                FROM Bank_Rule_Condition__c 
                WHERE Bank_Rule__c = :rule.Id
            ];
            System.assertEquals(1, resultConditions.size());
            System.assertEquals(conditions[0].Operator__c, resultConditions[0].Operator__c);

            List<Bank_Rule_Action__c> resultActions = [
                SELECT Target_Field__c, Value__c
                FROM Bank_Rule_Action__c 
                WHERE Bank_Rule__c = :rule.Id
            ];
            System.assertEquals(1, resultActions.size());
            System.assertEquals(actions[0].Target_Field__c, resultActions[0].Target_Field__c);
            System.assertEquals(actions[0].Value__c, resultActions[0].Value__c);
            
            List<Bank_Rule_GLAM__c> resultGlams = [
                SELECT GL_Account_Mapping__c 
                FROM Bank_Rule_GLAM__c 
                WHERE Bank_Rule__c = :rule.Id
            ];
            System.assertEquals(1, resultGlams.size());
            System.assertEquals(glams[0], resultGlams[0].GL_Account_Mapping__c);
        }
    }

    @IsTest
    private static void testSaveBankRule_NoCondition() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankRules();

        System.runAs(testData.users[1]) {
            Bank_Rule__c rule = testData.bankRules[0].clone(false, false, false, false);
            rule.Priority__c = 110;

            List<Id> glams = new List<Id> { testData.glams[0].Id };

            List<Bank_Rule_Condition__c> conditions = new List<Bank_Rule_Condition__c>();

            List<Bank_Rule_Action__c> actions = new List<Bank_Rule_Action__c> {
                testData.bankRuleActions[0].clone(false, false, false, false)
            };

            List<Bank_Rule_Condition__c> deleteConditions = new List<Bank_Rule_Condition__c>();

            List<Bank_Rule_Action__c> deleteActions = new List<Bank_Rule_Action__c>();        
            
            Exception expectedException;

            Test.startTest();
            try {
                BDCBankRulesHelper.saveBankRule(
                    rule,
                    glams,
                    conditions,
                    actions,
                    deleteConditions,
                    deleteActions
                );
            } catch(AuraHandledException ex) {
                expectedException = ex;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedException);
            System.assert(expectedException.getMessage().contains(BDCBankRulesHelper.CONDITION_REQUIRED));
        }
    }

    @IsTest
    private static void testSaveBankRule_NoAction() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankRules();

        System.runAs(testData.users[1]) {
            Bank_Rule__c rule = testData.bankRules[0].clone(false, false, false, false);
            rule.Priority__c = 110;

            List<Id> glams = new List<Id> { testData.glams[0].Id };

            List<Bank_Rule_Condition__c> conditions = new List<Bank_Rule_Condition__c> {
                testData.bankRuleConditions[0].clone(false, false, false, false)
            };

            List<Bank_Rule_Action__c> actions = new List<Bank_Rule_Action__c>();

            List<Bank_Rule_Condition__c> deleteConditions = new List<Bank_Rule_Condition__c>();

            List<Bank_Rule_Action__c> deleteActions = new List<Bank_Rule_Action__c>();        
            
            Exception expectedException;

            Test.startTest();
            try {
                BDCBankRulesHelper.saveBankRule(
                    rule,
                    glams,
                    conditions,
                    actions,
                    deleteConditions,
                    deleteActions
                );
            } catch(AuraHandledException ex) {
                expectedException = ex;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedException);
            System.assert(expectedException.getMessage().contains(BDCBankRulesHelper.ACTION_REQUIRED));
        }
    }

    @IsTest
    private static void testSaveBankRule_NoFIA() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankRules();

        System.runAs(testData.users[1]) {
            Bank_Rule__c rule = testData.bankRules[0].clone(false, false, false, false);
            rule.Priority__c = 110;

            List<Id> glams = new List<Id>();

            List<Bank_Rule_Condition__c> conditions = new List<Bank_Rule_Condition__c> {
                testData.bankRuleConditions[0].clone(false, false, false, false)
            };

            List<Bank_Rule_Action__c> actions = new List<Bank_Rule_Action__c> {
                testData.bankRuleActions[0].clone(false, false, false, false)
            };

            List<Bank_Rule_Condition__c> deleteConditions = new List<Bank_Rule_Condition__c>();

            List<Bank_Rule_Action__c> deleteActions = new List<Bank_Rule_Action__c>();        
            
            Exception expectedException;

            Test.startTest();
            try {
                BDCBankRulesHelper.saveBankRule(
                    rule,
                    glams,
                    conditions,
                    actions,
                    deleteConditions,
                    deleteActions
                );
            } catch(AuraHandledException ex) {
                expectedException = ex;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedException);
            System.assert(expectedException.getMessage().contains(BDCBankRulesHelper.FIA_REQUIRED));
        }
    }

    @IsTest
    private static void testSaveBankRule_AllFIAs() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankRules();

        System.runAs(testData.users[1]) {
            Bank_Rule__c rule = testData.bankRules[0].clone(false, false, false, false);
            rule.Priority__c = 110;
            rule.Apply_To_All_Financial_Accounts__c = true;

            List<Id> glams = new List<Id>();

            List<Bank_Rule_Condition__c> conditions = new List<Bank_Rule_Condition__c> {
                testData.bankRuleConditions[0].clone(false, false, false, false)
            };

            List<Bank_Rule_Action__c> actions = new List<Bank_Rule_Action__c> {
                testData.bankRuleActions[0].clone(false, false, false, false)
            };

            List<Bank_Rule_Condition__c> deleteConditions = new List<Bank_Rule_Condition__c>();

            List<Bank_Rule_Action__c> deleteActions = new List<Bank_Rule_Action__c>();        

            Test.startTest();
            BDCBankRulesHelper.saveBankRule(
                rule,
                glams,
                conditions,
                actions,
                deleteConditions,
                deleteActions
            );
            Test.stopTest();

            Bank_Rule__c savedRule = [
                SELECT Apply_To_All_Financial_Accounts__c 
                FROM Bank_Rule__c 
                WHERE Id = :rule.Id
            ];

            System.assertNotEquals(null, savedRule);
            System.assertEquals(true, savedRule.Apply_To_All_Financial_Accounts__c);
        }
    }

    @IsTest
    private static void testSaveBankRule_DeleteCondition() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankRules();

        System.runAs(testData.users[1]) {
            Bank_Rule__c rule = testData.bankRules[0];

            List<Id> glams = new List<Id> { testData.glams[1].Id };

            List<Bank_Rule_Condition__c> conditions = new List<Bank_Rule_Condition__c> {
                testData.bankRuleConditions[0].clone(false, false, false, false)
            };

            List<Bank_Rule_Action__c> actions = new List<Bank_Rule_Action__c> {
                testData.bankRuleActions[0]
            };

            List<Bank_Rule_Condition__c> deleteConditions = new List<Bank_Rule_Condition__c> {
                testData.bankRuleConditions[0]
            };

            List<Bank_Rule_Action__c> deleteActions = new List<Bank_Rule_Action__c>();        
            
            Test.startTest();
            BDCBankRulesHelper.saveBankRule(
                rule,
                glams,
                conditions,
                actions,
                deleteConditions,
                deleteActions
            );
            Test.stopTest();

            List<Bank_Rule_Condition__c> resultConditions = [
                SELECT Id
                FROM Bank_Rule_Condition__c 
                WHERE Bank_Rule__c = :rule.Id
            ];
            System.assertEquals(1, resultConditions.size());
            System.assertEquals(conditions[0].Id, resultConditions[0].Id);
        }
    }

    @IsTest
    private static void testSaveBankRule_DeleteAction() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankRules();

        System.runAs(testData.users[1]) {
            Bank_Rule__c rule = testData.bankRules[0];

            List<Id> glams = new List<Id> { testData.glams[1].Id };

            List<Bank_Rule_Condition__c> conditions = new List<Bank_Rule_Condition__c> {
                testData.bankRuleConditions[0]
            };

            List<Bank_Rule_Action__c> actions = new List<Bank_Rule_Action__c> {
                testData.bankRuleActions[0].clone(false, false, false, false)
            };

            List<Bank_Rule_Condition__c> deleteConditions = new List<Bank_Rule_Condition__c>();

            List<Bank_Rule_Action__c> deleteActions = new List<Bank_Rule_Action__c> {
                testData.bankRuleActions[0]
            };        
            
            Test.startTest();
            BDCBankRulesHelper.saveBankRule(
                rule,
                glams,
                conditions,
                actions,
                deleteConditions,
                deleteActions
            );
            Test.stopTest();

            List<Bank_Rule_Action__c> resultActions = [
                SELECT Id
                FROM Bank_Rule_Action__c 
                WHERE Bank_Rule__c = :rule.Id
            ];
            System.assertEquals(1, resultActions.size());
            System.assertEquals(actions[0].Id, resultActions[0].Id);
        }
    }

}