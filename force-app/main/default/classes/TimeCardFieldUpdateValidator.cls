public with sharing class TimeCardFieldUpdateValidator extends SourceDocumentUpdateFieldValidator {
    public static final String ACTUAL_TYPE = 'Actual';
    public Set<SObjectField> lockedUpdateFieldsPostedTC = new Set<SObjectField> {
        Time_Card__c.Status__c,
        Time_Card__c.Employee__c,
        Time_Card__c.Time_Card_Period__c,
        Time_Card__c.Total_Hours__c,
        Time_Card__c.Ledger__c,
        Time_Card__c.Type__c
    };

    public SObjectField statusFieldName = Time_Card__c.Status__c;

    public TimeCardFieldUpdateValidator() {
        statusField = statusFieldName;
        lockedUpdateFieldsPosted = lockedUpdateFieldsPostedTC;
    }

    public override void setValidationRules() {
        preventUpdateActionPosted();
        preventUpdateStatusFieldPosted();
        preventDeleteActionPosted();
    }

    public override Boolean skipLegacyRecordValidation(SObjectField field) {
        Boolean result = false;
        // allow Ledger field population for legacy items.
        if (field == Time_Card__c.Ledger__c && isLegacyLedgerFieldChanged(field)) {
            result = true;
        }

        // allow Type field population for legacy items.
        if (field == Time_Card__c.Type__c && isFirstFieldChanges(field) && ((String) getNewFieldValue(field)) == ACTUAL_TYPE) {
            result = true;
        }
        return result;
    }
}