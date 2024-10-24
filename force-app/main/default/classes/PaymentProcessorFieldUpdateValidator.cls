public with sharing class PaymentProcessorFieldUpdateValidator extends SourceDocumentUpdateFieldValidator {
    public Set<SObjectField> lockedUpdateFieldsPP = new Set<SObjectField> {
        Payment_Processor__c.External_Key__c
    };
    public PaymentProcessorFieldUpdateValidator() {
        lockedUpdateFields = lockedUpdateFieldsPP;
    }

    public override void setValidationRules() {
        preventUpdateAction();
    }
}