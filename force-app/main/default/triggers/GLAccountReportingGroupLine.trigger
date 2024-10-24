trigger GLAccountReportingGroupLine on GL_Account_Reporting_Group_Line__c (after insert, after update) {

    if (Trigger.isAfter && Trigger.isInsert) {
        GLAccountReportingGroupLineActions.validateUniquenessOfGLAccountInGLAccountReportingGroup(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        GLAccountReportingGroupLineActions.validateUniquenessOfGLAccountInGLAccountReportingGroup(Trigger.new);
    }

}