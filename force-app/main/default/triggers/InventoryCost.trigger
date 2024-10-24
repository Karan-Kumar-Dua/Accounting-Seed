trigger InventoryCost on Inventory_Cost__c (before insert, before update, after insert, after update, before delete) {

    if (Trigger.isBefore && Trigger.isInsert) {
        InventoryCostActions.preventInventoryCostInsert(Trigger.new);
        MultiCurrencyHandler.setCurrencyIsoCodeByLedger(Trigger.new);
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, InventoryCostActions.currencyAndNumberFields);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        InventoryCostActions.requireFields(Trigger.new);
        InventoryCostActions.preventInventoryCostDuplicates(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        MulticurrencyHandler.setCurrencyIsoCodeByLedger(Trigger.new);
        SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, InventoryCostActions.currencyAndNumberFields);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        InventoryCostActions.requireFields(Trigger.new);
        InventoryCostActions.preventInventoryCostDuplicates(Trigger.new);
        InventoryCostActions.preventInventoryCostUpdate(Trigger.oldMap, Trigger.newMap);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        InventoryCostActions.preventInventoryCostDelete(Trigger.old);
    }
}