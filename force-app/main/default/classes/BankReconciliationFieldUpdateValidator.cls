public with sharing class BankReconciliationFieldUpdateValidator extends SourceDocumentUpdateFieldValidator {
    public static final String ACTUAL_TYPE = 'Actual';
    public Set<SObjectField> lockedUpdateFieldsCompletedBR = new Set<SObjectField> {
        Bank_Reconciliation2__c.Beginning_Balance__c,
        Bank_Reconciliation2__c.Ending_Balance__c,
        Bank_Reconciliation2__c.Cleared_Deposits__c,
        Bank_Reconciliation2__c.Cleared_Disbursements__c,
        Bank_Reconciliation2__c.GL_Ending_Balance__c,
        Bank_Reconciliation2__c.UnCleared_Deposits__c,
        Bank_Reconciliation2__c.UnCleared_Payments__c
    };

    public Set<SObjectField> lockedUpdateFieldsBR {
        get {
            lockedUpdateFieldsBR = new Set<SObjectField> {
                Bank_Reconciliation2__c.Bank_Account__c,
                Bank_Reconciliation2__c.GL_Account_Variable_1__c,
                Bank_Reconciliation2__c.GL_Account_Variable_2__c,
                Bank_Reconciliation2__c.GL_Account_Variable_3__c,
                Bank_Reconciliation2__c.GL_Account_Variable_4__c,
                Bank_Reconciliation2__c.Error__c,
                Bank_Reconciliation2__c.Ledger__c,
                Bank_Reconciliation2__c.Type__c,
                Bank_Reconciliation2__c.End_Date__c,
                Bank_Reconciliation2__c.Modern_BR__c,
                Bank_Reconciliation2__c.Status__c
            };

            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                lockedUpdateFieldsBR.add(Schema.SObjectType.Bank_Reconciliation2__c.fields.getMap().get('CurrencyIsoCode'));
            }
            return lockedUpdateFieldsBR;
        }
        private set;
    }

    public SObjectField statusFieldName = Bank_Reconciliation2__c.Status__c;

    public BankReconciliationFieldUpdateValidator() {
        statusField = statusFieldName;
        allowStatusChange = true;
        postedStatusValues = new List<String>{BankReconciliation.COMPLETED, BankReconciliation.WORKING};
        lockedUpdateFieldsPosted = lockedUpdateFieldsCompletedBR;
        lockedUpdateFields = lockedUpdateFieldsBR;
        skipDeleteValidationFlags = new List<Boolean> {AccountingPeriodActions.isDelarcInProgress};
    }

    public override void setValidationRules() {
        preventUpdateAction();
        preventUpdateActionAlternatePosted();        
        preventDeleteActionAlternatePosted();
    }
}