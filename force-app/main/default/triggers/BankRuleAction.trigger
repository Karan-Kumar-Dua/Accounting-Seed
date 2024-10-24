trigger BankRuleAction on Bank_Rule_Action__c (before insert, after insert, before update, after update) {

    if (Trigger.isBefore && Trigger.isInsert) {
        BankRuleActions.validateUniqueTargetFields(Trigger.new);
        BankRuleActions.validateActionValue(Trigger.new);
    }
    else if (Trigger.isBefore && Trigger.isUpdate) {
        BankRuleActions.validateUniqueTargetFields(Trigger.new);
        BankRuleActions.validateActionValue(Trigger.new);
    }
    else if (Trigger.isAfter && Trigger.isInsert) {
        BankRuleActions.validateMaxActionsPerRule(Trigger.new);
    }
    else if (Trigger.isAfter && Trigger.isUpdate) {
        BankRuleActions.validateMaxActionsPerRule(Trigger.new);
    }

}