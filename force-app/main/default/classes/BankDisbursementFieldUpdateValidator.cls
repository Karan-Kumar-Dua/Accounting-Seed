public with sharing class BankDisbursementFieldUpdateValidator extends SourceDocumentUpdateFieldValidator {
    public Set<SObjectField> getLockedUpdateFieldsBD() {
        Set<SObjectField> lockedUpdateFieldsBD = new Set<SObjectField> {
            Bank_Disbursement__c.Ledger_Amount__c,
            Bank_Disbursement__c.Amount__c
        };
        if (!SourceDocumentUpdateFieldValidator.isForceMatchPermitted()) {
            //lockedUpdateFieldsBD.add(Bank_Disbursement__c.Bank_Transaction__c);
        }
        return lockedUpdateFieldsBD;
    }

    public BankDisbursementFieldUpdateValidator() {
        lockedUpdateFields = getLockedUpdateFieldsBD();
    }

    public override void setValidationRules() {
        preventUpdateAction();
    }
}