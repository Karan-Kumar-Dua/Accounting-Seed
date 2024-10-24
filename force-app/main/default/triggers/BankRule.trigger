trigger BankRule on Bank_Rule__c (before insert, after insert, before update, after update) {

    // insert
    if (Trigger.isInsert && Trigger.isBefore) {
        BankRuleActions.validateRulePriority(Trigger.new);
        BankRuleActions.validateFields(Trigger.new);
    }
    else if (Trigger.isInsert && Trigger.isAfter) {
        BankRuleActions.validateMaxRules(Trigger.new);
    }
    
    // update
    else if (Trigger.isUpdate && Trigger.isBefore) {
        BankRuleActions.validateRulePriority(Trigger.new);
        BankRuleActions.validateFields(Trigger.new);
    }
    else if (Trigger.isUpdate && Trigger.isAfter) {
        BankRuleActions.validateMaxRules(Trigger.new);
    }

}