trigger BankRuleCondition on Bank_Rule_Condition__c (after insert, after update) {

    if (Trigger.isAfter && Trigger.isInsert) {
        BankRuleActions.validateMaxConditionsPerRule(Trigger.new);
        BankRuleActions.validateConditionValue(Trigger.new);
    }
    else if (Trigger.isAfter && Trigger.isUpdate) {
        BankRuleActions.validateMaxConditionsPerRule(Trigger.new);
        BankRuleActions.validateConditionValue(Trigger.new);
    }

}