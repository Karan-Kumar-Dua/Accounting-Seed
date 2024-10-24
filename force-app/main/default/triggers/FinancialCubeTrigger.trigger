trigger FinancialCubeTrigger on Financial_Cube__c (before insert, after insert, before update, after update, before delete, after delete) {

    if (Trigger.isBefore && Trigger.isInsert) {
        FinancialCubeActions.setRequiredCubeFields(Trigger.new);
        FinancialCubeActions.clearArchivedAmountOnInsert(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        FinancialCubeActions.requireFields(Trigger.new);
        FinancialCubeActions.preventInsertAction(Trigger.new);
        FinancialCubeActions.validateRequiredFields(Trigger.new);
        FinancialCubeActions.validateCubeType(Trigger.newMap);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        FinancialCubeActions.setRequiredCubeFields(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        FinancialCubeActions.validateRequiredFields(Trigger.new);
        FinancialCubeActions.preventUpdateAction(Trigger.oldMap, Trigger.newMap);
        FinancialCubeActions.validateCubeType(Trigger.newMap);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        FinancialCubeActions.preventDeleteAction(Trigger.oldMap);
        FinancialCubeActions.prepareTranslationCubesForDeletion(Trigger.oldMap);
    }

    if (Trigger.isAfter && Trigger.isDelete) {
        FinancialCubeActions.deleteTranslationCubes();
    }

}