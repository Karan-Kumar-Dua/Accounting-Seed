public with sharing class ExchangeRateTableFieldUpdateValidator extends SourceDocumentUpdateFieldValidator {

    public Set<SObjectField> lockedUpdateFieldsER = new Set<SObjectField> {
        Exchange_Rate__c.Next_Exchange_Rate__c,
        Exchange_Rate__c.Effective_From__c,
        Exchange_Rate__c.From_Currency_Code__c,
        Exchange_Rate__c.To_Currency_Code__c,
        Exchange_Rate__c.Rate_Type__c
    };

    public ExchangeRateTableFieldUpdateValidator() {
        lockedUpdateFields = lockedUpdateFieldsER;
    }

    public override void setValidationRules() {
        preventUpdateAction();
    }

}