@IsTest
public with sharing class BankRuleActionsTest {
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testValidateRulePriority() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankRules();
        
        System.runAs(testData.users[1]) {
            DMLException expectedEx;

            Test.startTest();
            try {
                Bank_Rule__c rule = testData.bankRules[0].clone(false, false, false, false);
                insert rule;
            } catch(DMLException ex) {
                expectedEx = ex;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            System.assertEquals(BankRuleActions.PRIORITY_CONFLICT, expectedEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testValidateUniqueTargetFields() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankRules();
        
        System.runAs(testData.users[1]) {
            DMLException expectedEx;

            Test.startTest();
            try {
                Bank_Rule_Action__c action = testData.bankRuleActions[0].clone(false, false, false, false);
                action.Bank_Rule__c = testData.bankRules[0].Id;
                insert action;
            } catch(DMLException ex) {
                expectedEx = ex;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            System.assertEquals(BankRuleActions.ACTION_TARGET_FIELD_CONFLICT, expectedEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testValidateFields() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankRules();
        
        System.runAs(testData.users[1]) {
            DMLException expectedEx;

            Test.startTest();
            try {
                Bank_Rule__c rule = testData.bankRules[0].clone(false, false, false, false);
                rule.Name = null;
                insert rule;
            } catch(DMLException ex) {
                expectedEx = ex;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            System.assertEquals(String.format(BankRuleActions.PRIORITY_CONFLICT, new String[] {Label.COMMON_NAME}), expectedEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testValidateMaxRules() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankRules();

        System.runAs(testData.users[1]) {
            DMLException expectedEx;

            Test.startTest();
            try {
                List<Bank_Rule__c> rules = new List<Bank_Rule__c>();
                for (Integer i=0; i<=BankRuleActions.MAX_BANK_RULES; i++) {
                    Bank_Rule__c rule = testData.bankRules[0].clone(false, false, false, false);
                    rule.Priority__c = 1000 + i;
                    rules.add(rule);
                }
                insert rules;
            } catch(DMLException ex) {
                expectedEx = ex;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            System.assertEquals(
                String.format(BankRuleActions.TOO_MANY_BANK_RULES, new Integer[] { BankRuleActions.MAX_BANK_RULES }),
                expectedEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    private static void testValidateMaxActionsPerRule() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankRules()
            .createProjects()
            .createProjectTasks();
        
        System.runAs(testData.users[1]) {
            DMLException expectedEx;

            Test.startTest();
            try {
                Map<String,String> propToValue = new Map<String,String>{
                    'Accounting_Period__c' 
                        => JSON.serialize(new Cash_Receipt__c(Accounting_Period__c = testData.acctPeriods[0].Id), true),
                    'Amount__c' 
                        => JSON.serialize(new Cash_Receipt__c(Amount__c = 1000.00), true),
                    'Bank_Account__c' 
                        => JSON.serialize(new Cash_Receipt__c(Bank_Account__c = testData.glAccounts[0].Id), true),
                    'Bank_Id__c' 
                        => JSON.serialize(new Cash_Receipt__c(Bank_Id__c = '123oviun09q384hgqibunob7'), true),
                    'Cleared_Date__c' 
                        => JSON.serialize(new Cash_Receipt__c(Cleared_Date__c = Date.today()), true),
                    'Ledger__c' 
                        => JSON.serialize(new Cash_Receipt__c(Ledger__c = testData.ledgers[0].Id), true),
                    'Payment_Reference__c' 
                        => JSON.serialize(new Cash_Receipt__c(Payment_Reference__c = 'no83q7bbv38o3b22445n24q5sdfb708q3b3'), true),
                    'Project__c' 
                        => JSON.serialize(new Cash_Receipt__c(Project__c = testData.projects[0].Id), true),
                    'Project_Task__c' 
                        => JSON.serialize(new Cash_Receipt__c(Project_Task__c = testData.projectTasks[0].Id), true),
                    'Receipt_Date__c'
                        => JSON.serialize(new Cash_Receipt__c(Receipt_Date__c = Date.today()), true)
                };
                List<Bank_Rule_Action__c> actions = new List<Bank_Rule_Action__c>();
                for (String prop : propToValue.keySet()) {
                    Bank_Rule_Action__c action = testData.bankRuleActions[0].clone(false, false, false, false);
                    action.Target_Field__c = GlobalVariables.PACKAGE_QUALIFIER + prop;
                    action.Value__c = propToValue.get(prop);
                    actions.add(action);
                }
                insert actions;
            } catch(DMLException ex) {
                expectedEx = ex;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            System.assertEquals(
                String.format(BankRuleActions.TOO_MANY_ACTIONS, new Integer[] { BankRuleActions.MAX_ACTIONS_PER_RULE }),
                expectedEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    private static void testValidateMaxConditionsPerRule() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankRules();

        System.runAs(testData.users[1]) {
            DMLException expectedEx;

            Test.startTest();
            try {
                List<Bank_Rule_Condition__c> conditions = new List<Bank_Rule_Condition__c>();
                for (Integer i=0; i<=BankRuleActions.MAX_CONDITIONS_PER_RULE; i++) {
                    Bank_Rule_Condition__c condition = testData.bankRuleConditions[0].clone(false, false, false, false);
                    conditions.add(condition);
                }
                insert conditions;
            } catch(DMLException ex) {
                expectedEx = ex;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            System.assertEquals(
                String.format(BankRuleActions.TOO_MANY_CONDITIONS, new Integer[] { BankRuleActions.MAX_CONDITIONS_PER_RULE }),
                expectedEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    private static void testValidateActionValueWithBlankValue() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankRules();
        
        System.runAs(testData.users[1]) {
            String targetField = GlobalVariables.PACKAGE_QUALIFIER + 'Description__c';
            DMLException expectedEx;

            Test.startTest();
            try {
                testData.bankRuleActions[0].Target_Field__c = targetField;
                testData.bankRuleActions[0].Value__c = '{}';
                update testData.bankRuleActions[0];
            } catch(DMLException ex) {
                expectedEx = ex;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            System.assertEquals(
                String.format(BankRuleActions.ACTION_VALUE_REQUIRED, new String[] { Label.COMMON_DESCRIPTION }), 
                expectedEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    private static void testValidateActionValueWithMalformedValue() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankRules();
        
        System.runAs(testData.users[1]) {
            String targetField = PACKAGE_QUALIFIER + 'Description__c';
            DMLException expectedEx;

            Test.startTest();
            try {
                testData.bankRuleActions[0].Target_Field__c = targetField;
                testData.bankRuleActions[0].Value__c = '{\"' + targetField + '\" : {\"bad\" : true} }';
                update testData.bankRuleActions[0];
            } catch(DMLException ex) {
                expectedEx = ex;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            System.assertEquals(
                String.format(BankRuleActions.ACTION_VALUE_DESERIALIZE_EXCEPTION, new String[] { targetField }), 
                expectedEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    private static void testValidateConditionValueWithIsBlankOp() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankRules();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Bank_Rule_Condition__c condition = testData.bankRuleConditions[1];
            condition.Target_Field__c = PACKAGE_QUALIFIER + 'Description__c';
            condition.Operator__c = 'Is_Blank';
            condition.Description__c = null;
            update condition;
            Test.stopTest();

            Bank_Rule_Condition__c result = [
                SELECT 
                    Target_Field__c,
                    Operator__c,
                    Description__c
                FROM Bank_Rule_Condition__c
                WHERE Id = :condition.Id
            ];

            System.assertEquals(result.Target_Field__c, condition.Target_Field__c);
            System.assertEquals(result.Operator__c, condition.Operator__c);
            System.assertEquals(result.Description__c, condition.Description__c);
        }
    }

    @IsTest
    private static void testValidateConditionValueWithNullValue() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankRules();
        
        System.runAs(testData.users[1]) {
            Exception expectedEx;

            Test.startTest();
            Bank_Rule_Condition__c condition = testData.bankRuleConditions[0];
            condition.Target_Field__c = PACKAGE_QUALIFIER + 'Amount__c';
            condition.Operator__c = 'Equals';
            condition.Amount__c = null;
            try {
                update condition;
            } catch (DMLException ex) {
                expectedEx = ex;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            System.assertEquals(
                String.format(BankRuleActions.CONDITION_VALUE_REQUIRED, new String[] { 'Amount' }), 
                expectedEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    private static void testValidateConditionValueWithBlankValue() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankRules();
        
        System.runAs(testData.users[1]) {
            Exception expectedEx;

            Test.startTest();
            Bank_Rule_Condition__c condition = testData.bankRuleConditions[1];
            condition.Target_Field__c = PACKAGE_QUALIFIER + 'Description__c';
            condition.Operator__c = 'Contains';
            condition.Description__c = '   ';
            try {
                update condition;
            } catch (DMLException ex) {
                expectedEx = ex;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            System.assertEquals(
                String.format(BankRuleActions.CONDITION_VALUE_REQUIRED, new String[] { 'Description' }), 
                expectedEx.getDmlMessage(0)
            );
        }
    }

}