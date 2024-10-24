public with sharing class AccountPayableLineFieldUpdateValidator extends SourceDocumentUpdateFieldValidator {

    public Set<SObjectField> lockedUpdateFieldsAppliedAPLine {
        get {
            lockedUpdateFieldsAppliedAPLine = new Set<SObjectField> {
                Account_Payable_Line__c.Product__c,
                Account_Payable_Line__c.Amount__c,
                Account_Payable_Line__c.Quantity__c,
                Account_Payable_Line__c.Unit_Cost__c,
                Account_Payable_Line__c.Tax_Amount__c
            };
            return lockedUpdateFieldsAppliedAPLine;
        }
        private set;
    }

    public Set<SObjectField> lockedUpdateFieldsPostedAPLine = new Set<SObjectField> {
        Account_Payable_Line__c.Date__c,
        Account_Payable_Line__c.Quantity__c,
        Account_Payable_Line__c.Amount__c,
        Account_Payable_Line__c.Unit_Cost__c,
        Account_Payable_Line__c.Expense_GL_Account__c,
        Account_Payable_Line__c.Product__c,
        Account_Payable_Line__c.Project__c,
        Account_Payable_Line__c.Project_Task__c,
        Account_Payable_Line__c.GL_Account_Variable_1__c,
        Account_Payable_Line__c.GL_Account_Variable_2__c,
        Account_Payable_Line__c.GL_Account_Variable_3__c,
        Account_Payable_Line__c.GL_Account_Variable_4__c,
        Account_Payable_Line__c.Tax_Amount__c,
        Account_Payable_Line__c.Tax_Group__c
    };

    public SObjectField statusFieldName = Account_Payable_Line__c.Parent_Status__c;

    public AccountPayableLineFieldUpdateValidator() {
        statusField = statusFieldName;
        lockedUpdateFieldsPosted = lockedUpdateFieldsPostedAPLine;
        lockedUpdateFieldsApplied = lockedUpdateFieldsAppliedAPLine;
        skipDeleteValidationFlags = new List<Boolean> {AccountingPeriodActions.isDelarcInProgress};
    }

    public override void setValidationRules() {
        preventUpdateActionPosted();
        preventUpdateActionApplied();
        preventInsertActionPosted();
        preventDeleteActionPosted();
        preventInsertActionApplied();
        preventDeleteActionApplied();
    }

    public override void setJunctionSObjectIds(Map<Id, SObject> oldObjectMap, Map<Id, SObject> newObjectMap) {
        Map<Id, SObject> tempMap = newObjectMap != NULL && !newObjectMap.isEmpty() ? newObjectMap : oldObjectMap;
        for (Account_Payable_Line__c payableLine : (List<Account_Payable_Line__c>) tempMap.values()) {
            junctionSObjectIds.add(payableLine.Account_Payable__c);
        }
    }

    public override Id getJunctionObjectId(SObject obj) {
        return ((Account_Payable_Line__c) obj).Account_Payable__c;
    }

}