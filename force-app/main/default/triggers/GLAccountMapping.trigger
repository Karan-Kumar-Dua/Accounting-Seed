trigger GLAccountMapping on GL_Account_Mapping__c (before insert, before update, after update) {

    if (Trigger.isAfter && Trigger.isUpdate) {
        GLAccountMappingActions.preventUpdate(Trigger.new, Trigger.oldMap);
    }
    
    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        GLAccountMappingActions.GLAccountMappingActions(Trigger.new,Trigger.oldMap, Trigger.isUpdate);
    }

}