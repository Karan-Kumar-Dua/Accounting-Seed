trigger Product2 on Product2 (after insert, after update) {

    if (Trigger.isAfter && Trigger.isInsert) {
        SObjectActions.validateGLVariableType(Trigger.new);
        GLAccountValidator.validateGlAccountLookups(Trigger.new, NULL);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        SObjectActions.validateGLVariableType(Trigger.new);
        Product2Actions.preventUpdateTaxRateProduct(Trigger.new, Trigger.oldMap);
        GLAccountValidator.validateGlAccountLookups(Trigger.new, Trigger.oldMap);
        Product2Actions.preventUpdateTypeProductWithRelatedParts(Trigger.newMap, Trigger.oldMap);
    }

}