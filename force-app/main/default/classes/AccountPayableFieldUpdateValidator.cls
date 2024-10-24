public with sharing class AccountPayableFieldUpdateValidator extends SourceDocumentUpdateFieldValidator {

    public Set<SObjectField> lockedUpdateFieldsPostedAP = new Set<SObjectField> {
        Account_Payable__c.Status__c,
        Account_Payable__c.Vendor__c,
        Account_Payable__c.Contact__c,
        Account_Payable__c.Employee__c,
        Account_Payable__c.Accounting_Period__c,
        Account_Payable__c.Credit_Memo_Applied_Amount__c,
        Account_Payable__c.Ledger__c,
        Account_Payable__c.Currency_Conversion_Rate__c,
        Account_Payable__c.Closed_Accounting_Period__c
    };

    public Set<SObjectField> lockedUpdateFieldsAppliedAP {
        get {
            lockedUpdateFieldsAppliedAP = new Set<SObjectField> {
                Account_Payable__c.Accounting_Period__c,
                Account_Payable__c.Ledger__c,
                Account_Payable__c.Total__c,
                Account_Payable__c.Discount_Amount__c,
                Account_Payable__c.Credit_Memo_Applied_Amount__c,
                Account_Payable__c.Contact__c,
                Account_Payable__c.Employee__c,
                Account_Payable__c.Vendor__c,
                Account_Payable__c.Closed_Accounting_Period__c
            };
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                lockedUpdateFieldsAppliedAP.add(Account_Payable__c.Currency_Conversion_Rate__c);
            }
            return lockedUpdateFieldsAppliedAP;
        }
        private set;
    }

    public Set<SObjectField> lockedUpdateFieldsAP {
        get {
            lockedUpdateFieldsAP = new Set<SObjectField>();
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                lockedUpdateFieldsAP.add(Schema.SObjectType.Account_Payable__c.fields.getMap().get('CurrencyIsoCode'));
            }
            return lockedUpdateFieldsAP;
        }
        private set;
    }

    public SObjectField statusFieldName = Account_Payable__c.Status__c;

    public AccountPayableFieldUpdateValidator() {
        statusField = statusFieldName;
        lockedUpdateFieldsPosted = lockedUpdateFieldsPostedAP;
        lockedUpdateFields = lockedUpdateFieldsAP;
        lockedUpdateFieldsApplied = lockedUpdateFieldsAppliedAP;
        skipDeleteValidationFlags = new List<Boolean> {AccountingPeriodActions.isDelarcInProgress};
        skipUpdateValidationFlags = new List<Boolean> {AccountingPeriodActions.isDelarcInProgress};
    }

    public override void setValidationRules() {
        preventUpdateAction();
        preventUpdateActionPosted();
        preventUpdateActionApplied();
        preventUpdateStatusFieldPosted();
        preventDeleteActionPosted();
        preventDeleteActionApplied();
    }

    public override Boolean skipLegacyRecordValidation(SObjectField field) {
        Boolean result = false;
        // allow Ledger field population for legacy items.
        if (field == Account_Payable__c.Ledger__c && isLegacyLedgerFieldChanged(field)) {
            result = true;
        }
        // allow CCR field population for legacy items.
        if (field == Account_Payable__c.Currency_Conversion_Rate__c && (isFirstFieldChanges(field) || isLegacyLedgerFieldChanged(field))) {
            result = true;
        }
        // allow Discount Amount population for legacy items.
        if (field == Account_Payable__c.Discount_Amount__c && isFirstFieldChanges(field)) {
            result = true;
        }
        return result;
    }

}