trigger PeriodTask on Period_Task__c (after insert, after update) {
    switch on Trigger.operationType {
        when AFTER_INSERT {
            SObjectActions.preventShadowLedgers(Trigger.new);
            SObjectActions.preventInactiveLedgers(Trigger.new);
        }
        when AFTER_UPDATE {
            SObjectActions.preventShadowLedgers(Trigger.new);
            SObjectActions.preventInactiveLedgers(Trigger.new);
        }
    }
}