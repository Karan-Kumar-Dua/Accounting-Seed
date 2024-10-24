trigger TaxGroup on Tax_Group__c (before insert, after update, before delete) {

    if (Trigger.isBefore && Trigger.isInsert) {
        TaxGroupActions.validateExternalIDAllowed(Trigger.new);
    }
    
    if (Trigger.isAfter && Trigger.isUpdate) {
        TaxGroupActions.validateTaxRates(Trigger.newMap);
        TaxGroupActions.validateTaxType(Trigger.new, Trigger.oldMap);
        TaxGroupActions.preventUpdateLineCountAndCombinedTaxRateIfHasAssociated(Trigger.new, Trigger.oldMap);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        TaxGroupActions.preventTaxGroupDelete(Trigger.oldMap);
    }

}