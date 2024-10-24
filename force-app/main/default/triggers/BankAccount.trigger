trigger BankAccount on Bank_Account__c (before insert, after insert, before update,
                                        after update, before delete, after delete) {

    if (Trigger.isBefore && Trigger.isInsert) {
        AccessControlService controlService =  new AccessControlService(new APAutomationControl(), AcctSeed__Bank_Account__c.SObjectType);
        BankAccountActions.checkInsertFieldGrantsForPaymentServices(controlService);
        BankAccountActions.checkRequiredField(Trigger.new);
        BankAccountActions.populatePaymentServicesEnrollmentStatus(Trigger.new,controlService);
    }
    
    if (Trigger.isAfter && Trigger.isInsert) {
        BankAccountActions.apAutomationPostMessage(Trigger.new,null);
    }
    if (Trigger.isBefore && Trigger.isUpdate) {
        BankAccountActions.checkUpdateFieldGrantsForPaymentServices();
        BankAccountActions.checkRequiredField(Trigger.new);
        BankAccountActions.setAndPreventEnablePaymentService(Trigger.new, Trigger.oldMap);
        BankAccountActions.updatePaymentServiceEnrollmentStatus(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        BankAccountActions.apAutomationPostMessage(Trigger.new,Trigger.oldMap);
    }
}