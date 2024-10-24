public with sharing class CashReceiptFieldUpdateValidator extends SourceDocumentUpdateFieldValidator {

    public Set<SObjectField> lockedUpdateFieldsPostedCR {
        get {
            lockedUpdateFieldsPostedCR = new Set<SObjectField> {
                Cash_Receipt__c.Check_Number__c,
                Cash_Receipt__c.Status__c,
                Cash_Receipt__c.Account__c,
                Cash_Receipt__c.Accounting_Period__c,
                Cash_Receipt__c.Receipt_Date__c,
                Cash_Receipt__c.Amount__c,
                Cash_Receipt__c.Bank_Account__c,
                Cash_Receipt__c.Credit_GL_Account__c,
                Cash_Receipt__c.Cash_Flow_Category__c,
                Cash_Receipt__c.Ledger__c,
                Cash_Receipt__c.Project__c,
                Cash_Receipt__c.Project_Task__c,
                Cash_Receipt__c.GL_Account_Variable_1__c,
                Cash_Receipt__c.GL_Account_Variable_2__c,
                Cash_Receipt__c.GL_Account_Variable_3__c,
                Cash_Receipt__c.GL_Account_Variable_4__c,
                Cash_Receipt__c.Currency_Conversion_Rate__c,
                Cash_Receipt__c.Product__c
            };
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                lockedUpdateFieldsPostedCR.add(Schema.SObjectType.Cash_Receipt__c.fields.getMap().get('CurrencyIsoCode'));
            }
            return lockedUpdateFieldsPostedCR;
        }
        private set;
    }

    public Set<SObjectField> getLockedUpdateFieldsCR() {
        Set<SObjectField> lockedUpdateFieldsCR = new Set<SObjectField>{
            Cash_Receipt__c.Bank_Reconciliation__c,
            Cash_Receipt__c.Bank_Deposit__c,
            Cash_Receipt__c.Void__c,
            Cash_Receipt__c.Void_Date__c
            
        };
        if (!SourceDocumentUpdateFieldValidator.isForceMatchPermitted()) {
            lockedUpdateFieldsCR.add(Cash_Receipt__c.Bank_Transaction__c);
        }
        return lockedUpdateFieldsCR;
    }

    public SObjectField statusFieldName = Cash_Receipt__c.Status__c;

    public CashReceiptFieldUpdateValidator() {
        statusField = statusFieldName;
        lockedUpdateFieldsPosted = lockedUpdateFieldsPostedCR;
        lockedUpdateFields = getLockedUpdateFieldsCR();
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
        if (field == Cash_Receipt__c.Ledger__c && isLegacyLedgerFieldChanged(field)) {
            result = true;
        }
        // allow CCR field population for legacy items.
        if (field == Cash_Receipt__c.Currency_Conversion_Rate__c && (isFirstFieldChanges(field) || isLegacyLedgerFieldChanged(field))) {
            result = true;
        }
        return result;
    }

}