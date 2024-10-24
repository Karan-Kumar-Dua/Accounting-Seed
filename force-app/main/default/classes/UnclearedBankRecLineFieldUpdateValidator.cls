public with sharing class UnclearedBankRecLineFieldUpdateValidator extends SourceDocumentUpdateFieldValidator {

    public Set<SObjectField> lockedUpdateFieldsUnclearedBRECLine {
        get {
            lockedUpdateFieldsUnclearedBRECLine = new Set<SObjectField> {
                Uncleared_Bank_Reconciliation_Line__c.Cash_Disbursement__c,
                Uncleared_Bank_Reconciliation_Line__c.Cash_Receipt__c,
                Uncleared_Bank_Reconciliation_Line__c.Journal_Entry_Line__c,
                Uncleared_Bank_Reconciliation_Line__c.Bank_Deposit__c,
                Uncleared_Bank_Reconciliation_Line__c.Bank_Disbursement__c,
                Uncleared_Bank_Reconciliation_Line__c.Amount__c,
                Uncleared_Bank_Reconciliation_Line__c.Cleared_Date__c,
                Uncleared_Bank_Reconciliation_Line__c.Date__c,
                Uncleared_Bank_Reconciliation_Line__c.Description__c,
                Uncleared_Bank_Reconciliation_Line__c.Payee_Id__c,
                Uncleared_Bank_Reconciliation_Line__c.Payee_Name__c,
                Uncleared_Bank_Reconciliation_Line__c.Reference__c,
                Uncleared_Bank_Reconciliation_Line__c.Type__c,
                Uncleared_Bank_Reconciliation_Line__c.Related_Source_Document__c
            };

            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                lockedUpdateFieldsUnclearedBRECLine.add(Schema.SObjectType.Uncleared_Bank_Reconciliation_Line__c.fields.getMap().get('CurrencyIsoCode'));
            }
            return lockedUpdateFieldsUnclearedBRECLine;
        }
        private set;
    }

    public UnclearedBankRecLineFieldUpdateValidator() {
        lockedUpdateFields = lockedUpdateFieldsUnclearedBRECLine;
    }

    public override void setValidationRules() {
        preventUpdateAction();
    }
}