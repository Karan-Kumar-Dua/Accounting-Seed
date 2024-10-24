public with sharing class BankDepositFieldUpdateValidator extends SourceDocumentUpdateFieldValidator {

    public Set<SObjectField> getLockedUpdateFieldsBD() {
        Set<SObjectField> lockedUpdateFieldsBD = new Set<SObjectField> {
            Bank_Deposit__c.Bank_Reconciliation__c,
            Bank_Deposit__c.Ledger_Amount__c,
            Bank_Deposit__c.Amount__c
        };
        if (!SourceDocumentUpdateFieldValidator.isForceMatchPermitted()) {
            lockedUpdateFieldsBD.add(Bank_Deposit__c.Bank_Transaction__c);
        }
        return lockedUpdateFieldsBD;
    }

    public BankDepositFieldUpdateValidator() {
        lockedUpdateFields = getLockedUpdateFieldsBD();
    }

    public override void setValidationRules() {
        preventUpdateAction();
    }

}