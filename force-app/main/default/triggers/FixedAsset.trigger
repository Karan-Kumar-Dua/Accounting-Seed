trigger FixedAsset on Fixed_Asset__c (before insert, after insert, before update, after update) {

    if (Trigger.isBefore && Trigger.isInsert) {
        SObjectActions.populateLedgerField(Trigger.new);
        MultiCurrencyHandler.setCurrencyIsoCodeByLedger(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        FixedAssetActions.requireFields(Trigger.new);
        SObjectActions.validateLedgerType(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        SObjectActions.updateLedgerField(Trigger.oldMap, Trigger.newMap);
        MulticurrencyHandler.setCurrencyIsoCodeByLedger(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        SObjectActions.preventUpdateLedgerIfAmortizationEntry(Trigger.oldMap, Trigger.newMap, 'Fixed_Asset__c');
        FixedAssetActions.requireFields(Trigger.new);
        SObjectActions.validateLedgerType(Trigger.new);
    }

}