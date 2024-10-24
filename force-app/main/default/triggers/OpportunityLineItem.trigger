trigger OpportunityLineItem on OpportunityLineItem (before insert, after insert, before update, after update) {

    if (Trigger.isBefore && Trigger.isInsert) {
        OpportunityLineItemActions.associateDefaultProductFields(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        SObjectActions.validateGLVariableType(Trigger.new);
        HeaderLevelTaxHelper.validate(Trigger.new, Trigger.oldMap);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {}

    if (Trigger.isAfter && Trigger.isUpdate) {
        SObjectActions.validateGLVariableType(Trigger.new);
        HeaderLevelTaxHelper.validate(Trigger.new, Trigger.oldMap);
    }

}