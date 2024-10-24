public with sharing class BankRuleActions {
    
    @TestVisible
    private static final String REQUIRED_FIELD_MISSING = Label.COMMON_REQUIRED_FIELD_MISSING_BLOCK;
    @TestVisible
    private static final String PRIORITY_CONFLICT = Label.ERR_BANK_RULE_PRIORITY_CONFLICT;
    @TestVisible
    private static final String ACTION_TARGET_FIELD_CONFLICT = Label.ERR_ACTION_TARGET_FIELD_CONFLICT;
    @TestVisible
    private static final String TOO_MANY_BANK_RULES = Label.ERR_TOO_MANY_BANK_RULES;
    @TestVisible
    private static final String TOO_MANY_ACTIONS = Label.ERR_BANK_RULE_TOO_MANY_ACTIONS;
    @TestVisible
    private static final String TOO_MANY_CONDITIONS = Label.ERR_BANK_RULE_TOO_MANY_CONDITIONS;
    @TestVisible
    private static final String ACTION_VALUE_DESERIALIZE_EXCEPTION = Label.COMMON_ACTION_VALUE_DESERIALIZE_EXCEPTION;
    @TestVisible
    private static final String ACTION_VALUE_REQUIRED = Label.COMMON_ACTION_MISSING_VALUE;
    @TestVisible
    private static final String CONDITION_VALUE_REQUIRED = Label.COMMON_CONDITION_MISSING_VALUE;
    @TestVisible
    private static final Integer MAX_BANK_RULES = 100;
    @TestVisible
    private static final Integer MAX_ACTIONS_PER_RULE = 10;
    @TestVisible
    private static final Integer MAX_CONDITIONS_PER_RULE = 3;

    /**
     * get a map of Bank_Rule_Condition__c.Target_Field__c 
     * picklist options as: Map of { apiName => label }
     */
    private static Map<String,String> getConditionTargetFieldOptions() {
        Map<String,String> picklistOpts = new Map<String,String>();
		List<Schema.PicklistEntry> entries = Bank_Rule_Condition__c.Target_Field__c.getDescribe().getPicklistValues();
		for(Schema.PicklistEntry entry : entries) {
			picklistOpts.put(entry.getValue(), entry.getLabel());
		}     
		return picklistOpts;
    }

    public static void validateFields(List<Bank_Rule__c> rules) {
        for (Bank_Rule__c rule : rules) {
            // if blank SF will set `Name` to record ID (which is not desired behavior)
            if (String.isBlank(rule.Name)) {
                rule.Name.addError(String.format(REQUIRED_FIELD_MISSING, new String[] {Label.COMMON_NAME}));
            }
        }
    }

    public static void validateRulePriority(List<Bank_Rule__c> rules) {
        // (Bank_Rule__c.Type__c + Bank_Rule__c.Priority__c) => Bank_Rule__c
        Map<String,Bank_Rule__c> ruleMap = new Map<String,Bank_Rule__c>();
        Set<Decimal> priorities = new Set<Decimal>();
        
        for (Bank_Rule__c rule : rules) {
            String key = rule.Type__c + rule.Priority__c;
            if (ruleMap.containsKey(key)) {
                rule.Priority__c.addError(PRIORITY_CONFLICT);
            } else {
                ruleMap.put(key, rule);
                priorities.add(rule.Priority__c);
            }
        }

        List<Bank_Rule__c> possibleConflicts = DomainUtils.getBankRulesByPriority(priorities);

        for (Bank_Rule__c rule : possibleConflicts) {
            String key = rule.Type__c + rule.Priority__c;
            if (ruleMap.containsKey(key) && ruleMap.get(key).Id != rule.Id) {
                ruleMap.get(key).Priority__c.addError(PRIORITY_CONFLICT);
            }
        }
    }

    public static void validateUniqueTargetFields(List<Bank_Rule_Action__c> actions) {
        // (Bank_Rule_Action__c.Bank_Rule__c + Bank_Rule_Action__c.Target_Field__c) => Bank_Rule_Action__c
        Map<String,Bank_Rule_Action__c> actionMap = new Map<String,Bank_Rule_Action__c>();
        Set<Id> ruleIds = new Set<Id>();

        for (Bank_Rule_Action__c action : actions) {
            String key = action.Bank_Rule__c + action.Target_Field__c;
            if (actionMap.containsKey(key)) {
                action.Target_Field__c.addError(ACTION_TARGET_FIELD_CONFLICT);
            } else {
                actionMap.put(key, action);
                ruleIds.add(action.Bank_Rule__c);
            }
        }

        List<Bank_Rule_Action__c> possibleConflicts = DomainUtils.getBankRuleActionsByBankRule(ruleIds);

        for (Bank_Rule_Action__c action : possibleConflicts) {
            String key = action.Bank_Rule__c + action.Target_Field__c;
            if (actionMap.containsKey(key) && actionMap.get(key).Id != action.Id) {
                actionMap.get(key).Target_Field__c.addError(ACTION_TARGET_FIELD_CONFLICT);
            }
        }
    }

    public static void validateMaxRules(List<Bank_Rule__c> rules) {
        if (DomainUtils.countActiveBankRules() > MAX_BANK_RULES) {
            String msg = String.format(TOO_MANY_BANK_RULES, new Integer[] { MAX_BANK_RULES });
            for (Bank_Rule__c rule : rules) {
                rule.addError(msg);
            }
        }
    }

    public static void validateMaxActionsPerRule(List<Bank_Rule_Action__c> actions) {
        Set<Id> ruleIds = new Set<Id>();
        for (Bank_Rule_Action__c action : actions) {
            ruleIds.add(action.Bank_Rule__c);
        }

        List<AggregateResult> queryResults = DomainUtils.getBankRulesWithGreaterThanNumActions(ruleIds, MAX_ACTIONS_PER_RULE);
        
        Set<Id> invalid = new Set<Id>(); 
        for(AggregateResult queryResult : queryResults) {
            invalid.add((Id)queryResult.get(GlobalVariables.PACKAGE_QUALIFIER + 'Bank_Rule__c'));
        }

        String msg = String.format(TOO_MANY_ACTIONS, new Integer[] { MAX_ACTIONS_PER_RULE });
        for (Bank_Rule_Action__c action : actions) {
            if (invalid.contains(action.Bank_Rule__c)) {
                action.addError(msg);
            }
        }
    }

    public static void validateMaxConditionsPerRule(List<Bank_Rule_Condition__c> conditions) {
        Set<Id> ruleIds = new Set<Id>();
        for (Bank_Rule_Condition__c condition : conditions) {
            ruleIds.add(condition.Bank_Rule__c);
        }

        List<AggregateResult> queryResults = DomainUtils.getBankRulesWithGreaterThanNumConditions(ruleIds, MAX_CONDITIONS_PER_RULE);
        
        Set<Id> invalid = new Set<Id>(); 
        for(AggregateResult queryResult : queryResults) {
            invalid.add((Id)queryResult.get(GlobalVariables.PACKAGE_QUALIFIER + 'Bank_Rule__c'));
        }

        String msg = String.format(TOO_MANY_CONDITIONS, new Integer[] { MAX_CONDITIONS_PER_RULE });
        for (Bank_Rule_Condition__c condition : conditions) {
            if (invalid.contains(condition.Bank_Rule__c)) {
                condition.addError(msg);
            }
        }
    }

    public static void validateActionValue(List<Bank_Rule_Action__c> actions) {
        Set<Id> ruleIds = new Set<Id>();
        for (Bank_Rule_Action__c action : actions) {
            ruleIds.add(action.Bank_Rule__c);
        }

        Map<Id, Bank_Rule__c> rules = new Map<Id,Bank_Rule__c>(DomainUtils.getBankRulesById(ruleIds));

        for (Bank_Rule_Action__c action : actions) {
            String srcApiName = (String) rules.get(action.Bank_Rule__c).get('Source_Record_Type__c');
            Type srcType = Type.forName(srcApiName);
            try {
                SObject obj = (SObject) JSON.deserialize(action.Value__c, srcType);
                if (obj.get(action.Target_Field__c) == null) {
                    String selectedFieldLabel = FinancialSuiteUtils.formatFieldStrings(obj.getSObjectType(), new String[] { action.Target_Field__c });
                    String msg = String.format(ACTION_VALUE_REQUIRED, new String[] { selectedFieldLabel });
                    action.addError(msg);
                }
            } catch (Exception ex) {
                String msg = String.format(
                    ACTION_VALUE_DESERIALIZE_EXCEPTION, 
                    new String[] { action.Target_Field__c });
                action.addError(msg);
            }
        }
    }

    public static void validateConditionValue(List<Bank_Rule_Condition__c> conditions) {
        Map<String,String> targetFieldOpts;
        for (Bank_Rule_Condition__c condition : conditions) {
            if (!condition.Operator__c.equalsIgnoreCase('IS_BLANK')) {
                Object targetValue = condition.get(condition.Target_Field__c);
                if (targetValue == null || (targetValue instanceof String && String.isBlank((String) targetValue))) {
                    if (targetFieldOpts == null) {
                        targetFieldOpts = getConditionTargetFieldOptions();
                    } 
                    String targetFieldLabel = targetFieldOpts.get(condition.Target_Field__c);
                    String msg = String.format(CONDITION_VALUE_REQUIRED, new String[] { targetFieldLabel });
                    condition.addError(msg);
                }
            }
        }
    }

}