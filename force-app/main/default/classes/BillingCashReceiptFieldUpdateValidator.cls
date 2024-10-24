public with sharing class BillingCashReceiptFieldUpdateValidator extends SourceDocumentUpdateFieldValidator {

    public Set<SObjectFieldWrapper> lockedUpdateFieldsPostedBCR = new Set<SObjectFieldWrapper> {
        new SObjectFieldWrapper(Billing_Cash_Receipt__c.Adjustment_Amount__c, false),
        new SObjectFieldWrapper(Billing_Cash_Receipt__c.Adjustment_GL_Account__c, false),
        new SObjectFieldWrapper(Billing_Cash_Receipt__c.Accounting_Period__c, false),
        new SObjectFieldWrapper(Billing_Cash_Receipt__c.Applied_Amount__c, false),
        new SObjectFieldWrapper(Billing_Cash_Receipt__c.Status__c, false),
        new SObjectFieldWrapper(Billing_Cash_Receipt__c.Applied_Date__c, true)
    };

    public Set<SObjectField> lockedUpdateFieldsBCR {
        get {
            lockedUpdateFieldsBCR = new Set<SObjectField> {
                Billing_Cash_Receipt__c.Accounting_Period__c,
                Billing_Cash_Receipt__c.Applied_Amount__c,
                Billing_Cash_Receipt__c.Adjustment_Amount__c,
                Billing_Cash_Receipt__c.Adjustment_GL_Account__c,
                Billing_Cash_Receipt__c.Status__c
            };
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                lockedUpdateFieldsBCR.add(Schema.SObjectType.Billing_Cash_Receipt__c.fields.getMap().get('CurrencyIsoCode'));
            }
            return lockedUpdateFieldsBCR;
        }
        private set;
    }

    public SObjectField statusFieldName = Billing_Cash_Receipt__c.Status__c;

    public BillingCashReceiptFieldUpdateValidator() {
        statusField = statusFieldName;
        lockedUpdateFields = lockedUpdateFieldsBCR;
        lockedUpdateWrappedFieldsPosted = lockedUpdateFieldsPostedBCR;
    }

    public override void setValidationRules() {
        preventUpdateAction();
        preventUpdateActionPosted();
    }

}