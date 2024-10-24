public with sharing class BankRuleComposite {
    
    public Bank_Rule__c rule;
    private List<Bank_Rule_Condition__c> conditions;
    private List<Bank_Rule_Action__c> actions;
    private List<Bank_Rule_GLAM__c> financialInstitutions;
    private Set<Id> glamIds;
    private SObject actionPrototype;
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    public BankRuleComposite(   Bank_Rule__c rule,
                                List<Bank_Rule_Condition__c> conditions,
                                List<Bank_Rule_Action__c> actions,
                                List<Bank_Rule_GLAM__c> financialInstitutions) {

        this.rule = rule;
        this.conditions = conditions;
        this.actions = actions;
        this.financialInstitutions = financialInstitutions;
        if (this.rule != NULL && String.isNotBlank(this.rule.Source_Record_Type__c)) {
            deserializeActionsToPrototype();
        }
        this.glamIds = extractGlamIds();
    }

    public BankRuleComposite(Bank_Rule__c bankRuleWithRelatedLists) {
        this(
            bankRuleWithRelatedLists,
            bankRuleWithRelatedLists.Bank_Rule_Conditions__r,
            bankRuleWithRelatedLists.Bank_Rule_Actions__r,
            bankRuleWithRelatedLists.Bank_Rule_GLAMs__r
        );
    }

    public SObjectType getSObjectTypeForFutureSourceDocument() {
        SObjectType result;
        switch on this.actionPrototype {
            when Journal_Entry_Line__c jel {
                result = Journal_Entry__c.SObjectType;
            }
            when else {
                result = this.actionPrototype.getSObjectType();
            }
        }
        return result;
    }

    public void takeActions(SObject sourceDocument, Boolean lockGLAccount) {
        if (actionPrototype == null) {
            deserializeActionsToPrototype();
        }
        for (Bank_Rule_Action__c action : actions) {
            if (!skipAction(lockGLAccount, action.Target_Field__c)) {
                sourceDocument.put(action.Target_Field__c, actionPrototype.get(action.Target_Field__c));
            }
        }
    }

    private Boolean skipAction(Boolean lockGLAccount, String fieldApiName) {
        return lockGLAccount && fieldApiName == PACKAGE_QUALIFIER + 'GL_Account__c';
    }

    public Boolean isApplicableFor(Bank_Transaction__c bankTransaction) {
        return isApplicableFor(bankTransaction, NULL);
    }

    public Boolean isApplicableFor(Bank_Transaction__c bankTransaction, SObjectType sObjectTypeCondition) {
        Boolean result = false;
        List<Bank_Rule_Condition__c> matchedConditions = new List<Bank_Rule_Condition__c>();
        if (rule != NULL
                && isApplicableBySObjectType(sObjectTypeCondition)
                && FinancialSuiteUtils.isNotNullAndNotEmpty(conditions)
                && FinancialSuiteUtils.isNotNullAndNotEmpty(actions)
                && isApplicableByFIA(bankTransaction)) {

            for (Bank_Rule_Condition__c condition : conditions) {
                if (isApplicableByCondition(bankTransaction, condition)) {
                    matchedConditions.add(condition);
                }
            }

            if ((rule.Evaluation_Type__c == 'Or' && !matchedConditions.isEmpty())
                    || (rule.Evaluation_Type__c == 'And' && matchedConditions.size() == conditions.size())) {

                result = true;
            }
        }
        return result;
    }

    private Set<Id> extractGlamIds() {
        Set<Id> glamIds = new Set<Id>();
        if (financialInstitutions != NULL) {
            for (Bank_Rule_GLAM__c brGLAM : financialInstitutions) {
                glamIds.add(brGLAM.GL_Account_Mapping__c);
            }
        }
        return glamIds;
    }

    private Boolean isApplicableBySObjectType(SObjectType sObjectTypeCondition) {
        return !(sObjectTypeCondition != NULL && sObjectTypeCondition != this.actionPrototype.getSObjectType());
    }

    private Boolean isApplicableByFIA(Bank_Transaction__c bt) {
        return rule.Apply_To_All_Financial_Accounts__c 
            || (glamIds != NULL && glamIds.contains(bt.GL_Account_Mapping__c));
    }

    private Boolean isApplicableByCondition(Bank_Transaction__c bt, Bank_Rule_Condition__c condition) {
        Boolean result = false;
        SObjectField conditionSourceField = Bank_Rule_Condition__c.SObjectType.getDescribe().fields.getMap().get(condition.Target_Field__c);
        DisplayType dType = conditionSourceField.getDescribe().getType();
        SObjectField btSourceField = Bank_Transaction__c.SObjectType.getDescribe().fields.getMap().get(condition.Target_Field__c);
        String operator = condition.Operator__c;
        result = compareFieldValues(condition.get(conditionSourceField), operator, bt.get(btSourceField), dType);
        return result;
    }

    @TestVisible
    private Boolean compareFieldValues(Object targetFieldValue, String operator, Object sourceFieldValue, DisplayType dType) {
        Boolean result = false;
        switch on operator {
            when 'Contains' {
                String sourceValue = (sourceFieldValue != NULL) ? (String) sourceFieldValue : '';
                String targetValue = (targetFieldValue != NULL) ? (String) targetFieldValue : '';
                result = sourceValue.containsIgnoreCase(targetValue);
            }
            when 'Does_Not_Contain' {
                String sourceValue = (sourceFieldValue != NULL) ? (String) sourceFieldValue : '';
                String targetValue = (targetFieldValue != NULL) ? (String) targetFieldValue : '';
                result = !sourceValue.containsIgnoreCase(targetValue);
            }
            when 'Does_Not_Equal' {
                if (dType == DisplayType.STRING) {
                    String sourceValue = (sourceFieldValue != NULL) ? (String) sourceFieldValue : '';
                    String targetValue = (targetFieldValue != NULL) ? (String) targetFieldValue : '';
                    result = !sourceValue.equalsIgnoreCase(targetValue);
                }
                else if (dType == DisplayType.CURRENCY) {
                    Decimal sourceValue = (sourceFieldValue != NULL) ? (Decimal) sourceFieldValue : 0;
                    Decimal targetValue = (targetFieldValue != NULL) ? (Decimal) targetFieldValue : 0;
                    result = (sourceValue != targetValue);
                }
            }
            when 'Equals' {
                if (dType == DisplayType.STRING || dType == DisplayType.PICKLIST) {
                    String sourceValue = (sourceFieldValue != NULL) ? (String) sourceFieldValue : '';
                    String targetValue = (targetFieldValue != NULL) ? (String) targetFieldValue : '';
                    result = sourceValue.equalsIgnoreCase(targetValue);
                }
                else if (dType == DisplayType.CURRENCY) {
                    Decimal sourceValue = (sourceFieldValue != NULL) ? (Decimal) sourceFieldValue : 0;
                    Decimal targetValue = (targetFieldValue != NULL) ? (Decimal) targetFieldValue : 0;
                    result = (sourceValue == targetValue);
                }
            }
            when 'Greater_Than' {
                Decimal sourceValue = (sourceFieldValue != NULL) ? (Decimal) sourceFieldValue : 0;
                Decimal targetValue = (targetFieldValue != NULL) ? (Decimal) targetFieldValue : 0;
                result = (sourceValue > targetValue);
            }
            when 'Is_Blank' {
                String sourceValue = (String) sourceFieldValue;
                result = String.isBlank(sourceValue);
            }
            when 'Less_Than' {
                Decimal sourceValue = (sourceFieldValue != NULL) ? (Decimal) sourceFieldValue : 0;
                Decimal targetValue = (targetFieldValue != NULL) ? (Decimal) targetFieldValue : 0;
                result = (sourceValue < targetValue);
            }
            when 'Starts_With' {
                String sourceValue = (sourceFieldValue != NULL) ? (String) sourceFieldValue : '';
                String targetValue = (targetFieldValue != NULL) ? (String) targetFieldValue : '';
                result = sourceValue.startsWithIgnoreCase(targetValue);
            }
        }
        return result;
    }

    private void deserializeActionsToPrototype () {
        Type srcType = Type.forName(rule.Source_Record_Type__c);
        actionPrototype = (SObject) srcType.newInstance();
        for (Bank_Rule_Action__c action : actions) {
            SObject obj = (SObject) JSON.deserialize(action.Value__c, srcType);
            actionPrototype.put(action.Target_Field__c, obj.get(action.Target_Field__c));
        }
    }

}