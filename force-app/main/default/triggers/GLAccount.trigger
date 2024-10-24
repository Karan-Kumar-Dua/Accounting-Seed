trigger GLAccount on GL_Account__c (before insert, after insert, before update, after update, before delete) {

    if (Trigger.isBefore && Trigger.isInsert) {
        GLAccountActions.validateInputOutputGLAccounts(Trigger.new, NULL);
    }
    
    if (Trigger.isAfter && Trigger.isInsert) {
        GLAccountActions.requireFields(Trigger.new);
        GLAccountActions.validatePicklistValues(Trigger.new, NULL);
        GLAccountActions.validateTotalLimit(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        GLAccountActions.validateInputOutputGLAccounts(Trigger.new, Trigger.oldMap);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        GLAccountActions.requireFields(Trigger.new);
        GLAccountActions.preventChangeTypeField(Trigger.oldMap, Trigger.newMap);
        GLAccountActions.preventChangeGLCategoryIfCubesExist(Trigger.new, Trigger.oldMap);
        GLAccountActions.preventChangeTypeToCashFlowIfReportRowsExist(Trigger.oldMap, Trigger.newMap);
        GLAccountActions.preventChangeBankCheckboxIfCubesExist(Trigger.new, Trigger.oldMap);
        GLAccountActions.validatePicklistValues(Trigger.new, Trigger.oldMap);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        GLAccountActions.preventDeleteIfRelatedRecordsExist(Trigger.oldMap);
    }

}