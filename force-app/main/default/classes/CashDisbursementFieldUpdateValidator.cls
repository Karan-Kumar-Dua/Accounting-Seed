public with sharing class CashDisbursementFieldUpdateValidator extends SourceDocumentUpdateFieldValidator {

    public Set<SObjectField> lockedUpdateFieldsPostedCD {
        get {
            lockedUpdateFieldsPostedCD = new Set<SObjectField> {
                Cash_Disbursement__c.Status__c,
                Cash_Disbursement__c.Payment_Status__c,
                Cash_Disbursement__c.Vendor__c,
                Cash_Disbursement__c.Contact__c,
                Cash_Disbursement__c.Employee__c,
                Cash_Disbursement__c.Accounting_Period__c,
                Cash_Disbursement__c.Disbursement_Date__c,
                Cash_Disbursement__c.Amount__c,
                Cash_Disbursement__c.Source__c,
                Cash_Disbursement__c.Bank_Account__c,
                Cash_Disbursement__c.Debit_GL_Account__c,
                Cash_Disbursement__c.Cash_Flow_Category__c,
                Cash_Disbursement__c.Project__c,
                Cash_Disbursement__c.Project_Task__c,
                Cash_Disbursement__c.GL_Account_Variable_1__c,
                Cash_Disbursement__c.GL_Account_Variable_2__c,
                Cash_Disbursement__c.GL_Account_Variable_3__c,
                Cash_Disbursement__c.GL_Account_Variable_4__c,
                Cash_Disbursement__c.Ledger__c,
                Cash_Disbursement__c.Currency_Conversion_Rate__c,
                Cash_Disbursement__c.Product__c,
                Cash_Disbursement__c.Check_Number__c
            };
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                lockedUpdateFieldsPostedCD.add(Schema.SObjectType.Cash_Disbursement__c.fields.getMap().get('CurrencyIsoCode'));
            }
            return lockedUpdateFieldsPostedCD;
        }
        private set;
    }

    public Set<SObjectField> getLockedUpdateFieldsCD() {
        Set<SObjectField> lockedUpdateFieldsCD = new Set<SObjectField> {
            Cash_Disbursement__c.Payment_Status__c,
            Cash_Disbursement__c.Void_Date__c
        };
        if (!SourceDocumentUpdateFieldValidator.isForceMatchPermitted()) {
            lockedUpdateFieldsCD.add(Cash_Disbursement__c.Bank_Transaction__c);
        }
        return lockedUpdateFieldsCD;
    }

    public SObjectField statusFieldName = Cash_Disbursement__c.Status__c;

    public CashDisbursementFieldUpdateValidator() {
        statusField = statusFieldName;
        lockedUpdateFieldsPosted = lockedUpdateFieldsPostedCD;
        lockedUpdateFields = getLockedUpdateFieldsCD();
        skipDeleteValidationFlags = new List<Boolean> {AccountingPeriodActions.isDelarcInProgress};
        skipUpdateValidationFlags = new List<Boolean> {AccountingPeriodActions.isDelarcInProgress};
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
        if (field == Cash_Disbursement__c.Ledger__c && isLegacyLedgerFieldChanged(field)) {
            result = true;
        }
        // allow CCR field population for legacy items.
        if (field == Cash_Disbursement__c.Currency_Conversion_Rate__c && (isFirstFieldChanges(field) || isLegacyLedgerFieldChanged(field))) {
            result = true;
        }
        return result;
    }
}