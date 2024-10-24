trigger ProjectTask on Project_Task__c (before insert, after insert, after update, before delete) {

    if (Trigger.isBefore && Trigger.isInsert) {
        ProjectTaskActions.associateDefaultLaborGLAccount(Trigger.new);
        SObjectActions.populateGLAVsFromAccountOrProduct(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        GLAccountValidator.validateGlAccountLookups(Trigger.new, NULL);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        GLAccountValidator.validateGlAccountLookups(Trigger.new, Trigger.oldMap);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        ProjectTaskActions.preventDeleteIfRelatedRecordsExist(Trigger.oldMap);
    }

}