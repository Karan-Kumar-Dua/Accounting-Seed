trigger BankDisbursement on Bank_Disbursement__c (before insert, after insert, before update,after update, before delete, after delete) {
   
    if(Trigger.IsBefore && Trigger.isInsert){
        BankDisbursementActions.setDefaultFields(Trigger.new);
    }

    if(Trigger.IsAfter && Trigger.isInsert){
        BankDisbursementActions.requireFields(Trigger.new);
        SObjectActions.validateLedgerType(Trigger.new);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
    }
    
    if (Trigger.isBefore && Trigger.isUpdate) {
        SObjectActions.updateLedgerField(Trigger.oldMap, Trigger.newMap);
        BankDisbursementActions.preventUpdateActionIfChildRecords(Trigger.oldMap, Trigger.newMap);
        SObjectActions.preventUpdateFieldWithAssociatedRecordsOnBankDisb(Trigger.oldMap, Trigger.newMap, 'CurrencyIsoCode');
        SObjectActions.preventUpdateFieldWithAssociatedRecordsOnBankDisb(Trigger.oldMap, Trigger.newMap, 'Ledger__c');
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, Trigger.newMap);
    }

    if (Trigger.isUpdate && Trigger.isAfter) {
        BankDisbursementActions.requireFields(Trigger.new);
        SObjectActions.validateLedgerType(Trigger.new);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        BankDisbursementActions.preventDeleteAction(Trigger.oldMap);
    }
}