trigger BillingAgingHistory on Billing_Aging_History__c (before insert, before update, after insert, after update) {

    if (Trigger.isBefore && Trigger.isInsert) {
        SObjectActions.setISOCodeFromParentLedger(Trigger.new, 'Billing__c');
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        SObjectActions.setISOCodeFromParentLedger(Trigger.new, 'Billing__c');
    }

}