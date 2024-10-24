public with sharing class BillingFieldUpdateValidator extends SourceDocumentUpdateFieldValidator {

    public Set<SObjectField> lockedUpdateFieldsLockedAvataxBilling = new Set<SObjectField> {
        Billing__c.Accounting_Period__c,
        Billing__c.Ledger__c,
        Billing__c.Total__c,
        Billing__c.Customer__c,
        Billing__c.Closed_Accounting_Period__c,
        Billing__c.Currency_Conversion_Rate__c,
        Billing__c.Billing_City__c,
        Billing__c.Billing_Country__c,
        Billing__c.Billing_PostalCode__c,
        Billing__c.Billing_State__c,
        Billing__c.Billing_Street__c,
        Billing__c.Shipping_City__c,
        Billing__c.Shipping_Country__c,
        Billing__c.Shipping_PostalCode__c,
        Billing__c.Shipping_State__c,
        Billing__c.Shipping_Street__c,
        Billing__c.Origin_Address_Override__c,
        Billing__c.Destination_Address_Override__c
    };

    public Set<SObjectField> lockedUpdateFieldsPostedBilling = new Set<SObjectField> {
        Billing__c.Status__c,
        Billing__c.Customer__c,
        Billing__c.Accounting_Period__c,
        Billing__c.Credit_Memo_Applied_Amount__c,
        Billing__c.Ledger__c,
        Billing__c.Currency_Conversion_Rate__c,
        Billing__c.Closed_Accounting_Period__c
    };

    public Set<SObjectField> lockedUpdateFieldsAppliedBilling {
        get {
            lockedUpdateFieldsAppliedBilling = new Set<SObjectField> {
                Billing__c.Accounting_Period__c,
                Billing__c.Ledger__c,
                Billing__c.Total__c,
                Billing__c.Customer__c,
                Billing__c.Closed_Accounting_Period__c
            };
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                lockedUpdateFieldsAppliedBilling.add(Billing__c.Currency_Conversion_Rate__c);
            }
            return lockedUpdateFieldsAppliedBilling;
        }
        private set;
    }

    public Set<SObjectField> lockedUpdateFieldsBilling {
        get {
            lockedUpdateFieldsBilling = new Set<SObjectField> {
                Billing__c.Locked_In_AvaTax__c
            };
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                lockedUpdateFieldsBilling.add(Schema.SObjectType.Billing__c.fields.getMap().get('CurrencyIsoCode'));
            }
            return lockedUpdateFieldsBilling;
        }
        private set;
    }

    public SObjectField statusFieldName = Billing__c.Status__c;

    public BillingFieldUpdateValidator() {
        statusField = statusFieldName;
        lockedUpdateFieldsPosted = lockedUpdateFieldsPostedBilling;
        lockedUpdateFields = lockedUpdateFieldsBilling;
        lockedUpdateFieldsApplied = lockedUpdateFieldsAppliedBilling;
        lockedUpdateFieldsCustomSet = lockedUpdateFieldsLockedAvataxBilling;
        customValidationErrorMsg = Label.ERR_UPDATE_AVATAX_LOCKED;
        skipDeleteValidationFlags = new List<Boolean> {AccountingPeriodActions.isDelarcInProgress};
        skipUpdateValidationFlags = new List<Boolean> {AccountingPeriodActions.isDelarcInProgress};
    }

    public override void setValidationRules() {
        preventUpdateAction();
        preventUpdateActionPosted();
        preventUpdateActionApplied();
        preventUpdateCustomAction();
        preventUpdateStatusFieldPosted();
        preventDeleteActionPosted();
        preventDeleteActionApplied();
    }

    public override Boolean skipLegacyRecordValidation(SObjectField field) {
        Boolean result = false;
        // allow Ledger field population for legacy items.
        if (field == Billing__c.Ledger__c && isLegacyLedgerFieldChanged(field)) {
            result = true;
        }
        // allow CCR field population for legacy items.
        if (field == Billing__c.Currency_Conversion_Rate__c && (isFirstFieldChanges(field) || isLegacyLedgerFieldChanged(field))) {
            result = true;
        }
        return result;
    }

    public override Boolean customValidationRules() {
        return (Boolean) oldObj.get(Billing__c.Locked_In_AvaTax__c);
    }
}