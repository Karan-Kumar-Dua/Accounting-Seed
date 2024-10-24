public with sharing class JournalEntryFieldUpdateValidator extends SourceDocumentUpdateFieldValidator {

    public Set<SObjectField> lockedUpdateFieldsPostedJE = new Set<SObjectField> {
        Journal_Entry__c.Journal_Date__c,
        Journal_Entry__c.Accounting_Period__c,
        Journal_Entry__c.Status__c,
        Journal_Entry__c.Ledger__c,
        Journal_Entry__c.Currency_Conversion_Rate__c,
        Journal_Entry__c.Accrual_and_or_Cash__c
    };

    public Set<SObjectField> lockedUpdateFieldsJE {
        get {
            lockedUpdateFieldsJE = new Set<SObjectField>();
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                lockedUpdateFieldsJE.add(Schema.SObjectType.Journal_Entry__c.fields.getMap().get('CurrencyIsoCode'));
            }
            return lockedUpdateFieldsJE;
        }
        private set;
    }

    public SObjectField statusFieldName = Journal_Entry__c.Status__c;

    public JournalEntryFieldUpdateValidator() {
        statusField = statusFieldName;
        lockedUpdateFieldsPosted = lockedUpdateFieldsPostedJE;
        lockedUpdateFields = lockedUpdateFieldsJE;
        skipDeleteValidationFlags = new List<Boolean> {AccountingPeriodActions.isDelarcInProgress};
        errorMessagesByLockedUpdateFieldsPosted = new Map<SObjectField, String>{
            Journal_Entry__c.Accrual_and_or_Cash__c => String.format(
                Label.ERR_ACCRUAL_CASH_CHANGE_ON_POSTED_JE_AE,
                new List<String>{Journal_Entry__c.getSObjectType().getDescribe().getLabel()}
            )
        };
    }

    public override void setValidationRules() {
        preventUpdateAction();
        preventUpdateActionPosted();
        preventUpdateStatusFieldPosted();
        preventDeleteActionPosted();
    }

    public override Boolean skipLegacyRecordValidation(SObjectField field) {
        Boolean result = false;
        // allow Ledger field population for legacy items.
        if (field == Journal_Entry__c.Ledger__c && isLegacyLedgerFieldChanged(field)) {
            result = true;
        }
        // allow CCR field population for legacy items.
        if (field == Journal_Entry__c.Currency_Conversion_Rate__c && (isFirstFieldChanges(field) || isLegacyLedgerFieldChanged(field))) {
            result = true;
        }
        if (field == Journal_Entry__c.Accrual_and_or_Cash__c && isFirstFieldChanges(field)) {
            result = true;
        }
        return result;
    }
}