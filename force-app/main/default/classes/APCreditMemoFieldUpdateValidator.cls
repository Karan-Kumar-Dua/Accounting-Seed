public with sharing class APCreditMemoFieldUpdateValidator extends SourceDocumentUpdateFieldValidator {

    public Set<SObjectFieldWrapper> lockedUpdateFieldsAPCM {
        get {
            lockedUpdateFieldsAPCM = new Set<SObjectFieldWrapper> {
                new SObjectFieldWrapper(AP_Credit_Memo__c.Account_Payable_Credit_Memo__c, false),
                new SObjectFieldWrapper(AP_Credit_Memo__c.Account_Payable_Invoice__c, false),
                new SObjectFieldWrapper(AP_Credit_Memo__c.Amount__c, false),
                new SObjectFieldWrapper(AP_Credit_Memo__c.Accounting_Period__c, false),
                new SObjectFieldWrapper(AP_Credit_Memo__c.Applied_Date__c, true)
            };
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                lockedUpdateFieldsAPCM.add(new SObjectFieldWrapper(Schema.SObjectType.AP_Credit_Memo__c.fields.getMap().get('CurrencyIsoCode'), false));
            }
            return lockedUpdateFieldsAPCM;
        }
        private set;
    }

    public APCreditMemoFieldUpdateValidator() {
        lockedUpdateWrappedFields = lockedUpdateFieldsAPCM;
    }

    public override void setValidationRules() {
        preventUpdateAction();
    }

}