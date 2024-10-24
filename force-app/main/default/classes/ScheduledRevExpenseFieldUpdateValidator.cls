public with sharing class ScheduledRevExpenseFieldUpdateValidator extends SourceDocumentUpdateFieldValidator {

    public Set<SObjectField> lockedUpdateFieldsPostedSRE = new Set<SObjectField> {
        Scheduled_Revenue_Expense__c.Account2__c,
        Scheduled_Revenue_Expense__c.Accounting_Period__c,
        Scheduled_Revenue_Expense__c.Amount__c,
        Scheduled_Revenue_Expense__c.Status__c,
        Scheduled_Revenue_Expense__c.Credit_GL_Account__c,
        Scheduled_Revenue_Expense__c.Debit_GL_Account__c,
        Scheduled_Revenue_Expense__c.Project__c,
        Scheduled_Revenue_Expense__c.Project_Task__c,
        Scheduled_Revenue_Expense__c.Product__c,
        Scheduled_Revenue_Expense__c.GL_Account_Variable_1__c,
        Scheduled_Revenue_Expense__c.GL_Account_Variable_2__c,
        Scheduled_Revenue_Expense__c.GL_Account_Variable_3__c,
        Scheduled_Revenue_Expense__c.GL_Account_Variable_4__c,
        Scheduled_Revenue_Expense__c.Billing__c,
        Scheduled_Revenue_Expense__c.Account_Payable__c,
        Scheduled_Revenue_Expense__c.Fixed_Asset__c,
        Scheduled_Revenue_Expense__c.Ledger__c,
        Scheduled_Revenue_Expense__c.Accrual_and_or_Cash__c
    };

    public SObjectField statusFieldName = Scheduled_Revenue_Expense__c.Status__c;

    public ScheduledRevExpenseFieldUpdateValidator() {
        statusField = statusFieldName;
        lockedUpdateFieldsPosted = lockedUpdateFieldsPostedSRE;
        skipDeleteValidationFlags = new List<Boolean> {AccountingPeriodActions.isDelarcInProgress};
        errorMessagesByLockedUpdateFieldsPosted = new Map<SObjectField, String>{
            Scheduled_Revenue_Expense__c.Accrual_and_or_Cash__c => String.format(
                Label.ERR_ACCRUAL_CASH_CHANGE_ON_POSTED_JE_AE,
                new List<String>{Scheduled_Revenue_Expense__c.getSObjectType().getDescribe().getLabel()}
            )
        };
    }

    public override void setValidationRules() {
        preventUpdateActionPosted();
        preventUpdateStatusFieldPosted();
        preventDeleteActionPosted();
    }

    public override Boolean skipLegacyRecordValidation(SObjectField field) {
        Boolean result = false;
        // allow Ledger field population for legacy items.
        if (field == Scheduled_Revenue_Expense__c.Ledger__c && isLegacyLedgerFieldChanged(field)) {
            result = true;
        }
        if (field == Scheduled_Revenue_Expense__c.Accrual_and_or_Cash__c && isFirstFieldChanges(field)) {
            result = true;
        }
        return result;
    }
}