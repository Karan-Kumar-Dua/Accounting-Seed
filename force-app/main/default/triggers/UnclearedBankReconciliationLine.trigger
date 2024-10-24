trigger UnclearedBankReconciliationLine on Uncleared_Bank_Reconciliation_Line__c (before insert, after update, before delete) {

    if (Trigger.isBefore && Trigger.isInsert) {
        UnclearedBankReconciliationLineActions.preventInsert(Trigger.new);
        UnclearedBankReconciliationLineActions.thereCanBeOnlyOne(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, Trigger.newMap);
        UnclearedBankReconciliationLineActions.thereCanBeOnlyOne(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        UnclearedBankReconciliationLineActions.preventDelete(Trigger.old);
    }

}