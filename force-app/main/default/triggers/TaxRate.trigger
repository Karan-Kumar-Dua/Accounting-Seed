trigger TaxRate on Tax_Rate__c (after insert, after update) {

    if (Trigger.isAfter && Trigger.isInsert) {
        GLAccountValidator.validateGlAccountLookups(Trigger.new, NULL, TaxRateActions.isPreventUpdateOverride);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        GLAccountValidator.validateGlAccountLookups(Trigger.new, Trigger.oldMap, TaxRateActions.isPreventUpdateOverride);
        TaxRateActions.validateGLAccountChanges(Trigger.new, Trigger.oldMap);
    }

}