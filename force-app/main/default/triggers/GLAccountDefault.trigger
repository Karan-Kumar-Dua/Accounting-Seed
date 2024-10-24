trigger GLAccountDefault on GL_Account_Default__c (before insert, after insert, before update, after update) {
    switch on Trigger.operationType {
        when BEFORE_INSERT {
            GLAccountDefaultActions.setUniqueKeys(Trigger.new);
        }
        when AFTER_INSERT {
            GLAccountDefaultActions.validate(Trigger.new);
        }
        when BEFORE_UPDATE {
            GLAccountDefaultActions.setUniqueKeys(Trigger.new);
        }
        when AFTER_UPDATE {
            GLAccountDefaultActions.validate(Trigger.new, Trigger.oldMap);
        }
    }
}