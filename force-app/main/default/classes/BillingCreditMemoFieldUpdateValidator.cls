public with sharing class BillingCreditMemoFieldUpdateValidator extends SourceDocumentUpdateFieldValidator {

    public Set<SObjectFieldWrapper> lockedUpdateFieldsBCM {
        get {
            lockedUpdateFieldsBCM = new Set<SObjectFieldWrapper> {
                new SObjectFieldWrapper(Billing_Credit_Memo__c.Accounting_Period__c, false),
                new SObjectFieldWrapper(Billing_Credit_Memo__c.Amount__c, false),
                new SObjectFieldWrapper(Billing_Credit_Memo__c.Billing_Invoice__c, false),
                new SObjectFieldWrapper(Billing_Credit_Memo__c.Billing_Credit_Memo__c, false),
                new SObjectFieldWrapper(Billing_Credit_Memo__c.Applied_Date__c, true)
            };
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                lockedUpdateFieldsBCM.add(new SObjectFieldWrapper(Schema.SObjectType.Billing_Credit_Memo__c.fields.getMap().get('CurrencyIsoCode'), false));
            }
            return lockedUpdateFieldsBCM;
        }
        private set;
    }

    public BillingCreditMemoFieldUpdateValidator() {
        lockedUpdateWrappedFields = lockedUpdateFieldsBCM;
        skipDeleteValidationFlags = new List<Boolean> {AccountingPeriodActions.isDelarcInProgress};
    }

    public override void setValidationRules() {
        preventUpdateAction();
    }
}