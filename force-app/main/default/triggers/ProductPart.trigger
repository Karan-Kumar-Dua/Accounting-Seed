trigger ProductPart on Product_Part__c (after insert, after update) {

    if (Trigger.isAfter && Trigger.isInsert) {
        ProductPartActions.validateProductPartRowsQuantity(Trigger.new);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        ProductPartActions.validateMasterProductChanges(Trigger.newMap, Trigger.oldMap);
    }
}