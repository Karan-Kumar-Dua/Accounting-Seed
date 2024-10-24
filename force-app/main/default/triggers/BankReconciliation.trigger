trigger BankReconciliation on Bank_Reconciliation2__c (before insert, after insert, before update, after update, before delete) {

    if (Trigger.isInsert && Trigger.isBefore) {
        BankReconciliationActions.setDefaultFields(Trigger.new);
        BankReconciliationActions.validateTypeFieldRequiredForModernBR(Trigger.new);  
        SObjectActions.populateLedgerField(Trigger.new);
        BankReconciliationActions.setOpeningBalanceAndType(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        SObjectActions.validateLedgerType(Trigger.new);
        BankReconciliationActions.validateUniqueReconciliation(Trigger.newMap);
        BankReconciliationActions.validateNoSubsequentReconciledReconciliations(Trigger.newMap);
        BankReconciliationActions.validateNoRelatedWorkingReconciliations(Trigger.newMap);
        BankReconciliationActions.clearRelatedSourceDocuments(Trigger.newMap);
        SObjectActions.preventShadowLedgers(Trigger.new);
        SObjectActions.preventInactiveLedgers(Trigger.new);
    }

    if (Trigger.isUpdate && Trigger.isBefore) {
        BankReconciliationActions.checkForMultipleStatusChanges(Trigger.oldMap, Trigger.newMap);
        BankReconciliationActions.handleStatusChange(Trigger.oldMap, Trigger.newMap);
        BankReconciliationActions.validateTypeFieldRequiredForModernBR(Trigger.new);
        SObjectActions.updateLedgerField(Trigger.oldMap, Trigger.newMap);
        TriggerObserver.getInstance().validateObservedContent(Trigger.new);
    }
    
    if (Trigger.isUpdate && Trigger.isAfter) {
        SObjectActions.preventUpdateFieldWithAssociatedRecords(Trigger.oldMap,Trigger.newMap, 'CurrencyIsoCode');
        GLAccountValidator.validateGlAccountLookups(Trigger.new, Trigger.oldMap);
        SObjectActions.validateLedgerType(Trigger.new);
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, Trigger.newMap);
        BankReconciliationActions.validateStatusChange(Trigger.oldMap, Trigger.newMap);
        BankReconciliationActions.invokeEvent(Trigger.oldMap, Trigger.newMap);
        TriggerObserver.getInstance().validateObservedContent(Trigger.new);
        SObjectActions.preventShadowLedgers(Trigger.new);
            SObjectActions.preventInactiveLedgers(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, NULL);
    }

}