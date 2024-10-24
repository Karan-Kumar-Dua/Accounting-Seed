trigger BankDeposit on Bank_Deposit__c (before insert, after insert, before update, after update, before delete) {

    if (Trigger.isInsert && Trigger.isBefore) {
        BankDepositActions.setDefaultFields(Trigger.new);
        SObjectActions.handleNonCloneableFields(Trigger.new);
        SObjectActions.populateLedgerField(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        SObjectActions.validateLedgerType(Trigger.new);
        SObjectActions.preventShadowLedgers(Trigger.new);
            SObjectActions.preventInactiveLedgers(Trigger.new);
    }

    if (Trigger.isUpdate && Trigger.isBefore) {
        SObjectActions.updateLedgerField(Trigger.oldMap, Trigger.newMap);
        BankDepositActions.setLedgerAmount(Trigger.new, Trigger.oldMap);
    }

    if (Trigger.isUpdate && Trigger.isAfter) {
        BankDepositActions.preventUpdateActionChildRecords(Trigger.oldMap, Trigger.newMap);
        SObjectActions.preventUpdateFieldWithAssociatedRecords(Trigger.oldMap, Trigger.newMap, 'CurrencyIsoCode');
        SObjectActions.preventUpdateFieldWithAssociatedRecords(Trigger.oldMap, Trigger.newMap, 'Ledger__c');
        BankDepositActions.preventUpdateLedgerOnClearedBD(Trigger.oldMap, Trigger.newMap);
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, Trigger.newMap);
        GLAccountValidator.validateGlAccountLookups(Trigger.new, Trigger.oldMap);
        SObjectActions.validateLedgerType(Trigger.new);
        SObjectActions.handleBtForceMatch(Trigger.new, Trigger.oldMap);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
    }

    if (Trigger.isDelete && Trigger.isBefore) {
        BankDepositActions.preventDeleteAction(Trigger.old);
        SObjectActions.deleteSourceRecordUpdateBTStatus(Trigger.old);
    }

}