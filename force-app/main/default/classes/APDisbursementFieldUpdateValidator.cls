public with sharing class APDisbursementFieldUpdateValidator extends SourceDocumentUpdateFieldValidator {

    public Set<SObjectFieldWrapper> lockedUpdateFieldsPostedAPD = new Set<SObjectFieldWrapper> {
        new SObjectFieldWrapper(AP_Disbursement__c.Accounting_Period__c, false),
        new SObjectFieldWrapper(AP_Disbursement__c.Paid_Amount__c, false),
        new SObjectFieldWrapper(AP_Disbursement__c.Status__c, false),
        new SObjectFieldWrapper(AP_Disbursement__c.Applied_Date__c, true)
    };

    public Set<SObjectField> lockedUpdateFieldsAPD {
        get {
            lockedUpdateFieldsAPD = new Set<SObjectField> {
                AP_Disbursement__c.Paid_Amount__c,
                AP_Disbursement__c.Accounting_Period__c,
                AP_Disbursement__c.Status__c
            };
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                lockedUpdateFieldsAPD.add(Schema.SObjectType.AP_Disbursement__c.fields.getMap().get('CurrencyIsoCode'));
            }
            return lockedUpdateFieldsAPD;
        }
        private set;
    }

    public SObjectField statusFieldName = AP_Disbursement__c.Status__c;

    public APDisbursementFieldUpdateValidator() {
        statusField = statusFieldName;
        lockedUpdateFields = lockedUpdateFieldsAPD;
        lockedUpdateWrappedFieldsPosted = lockedUpdateFieldsPostedAPD;
    }

    public override void setValidationRules() {
        preventUpdateAction();
        preventUpdateActionPosted();
    }

}