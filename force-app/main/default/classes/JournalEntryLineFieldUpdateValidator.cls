public with sharing class JournalEntryLineFieldUpdateValidator extends SourceDocumentUpdateFieldValidator {
	public Set<SObjectField> lockedUpdateFieldsPostedJELine = new Set<SObjectField>{
		Journal_Entry_Line__c.Account__c,
		Journal_Entry_Line__c.Date__c,
		Journal_Entry_Line__c.Credit__c,
		Journal_Entry_Line__c.Debit__c,
		Journal_Entry_Line__c.Units__c,
		Journal_Entry_Line__c.Employee__c,
		Journal_Entry_Line__c.GL_Account__c,
		Journal_Entry_Line__c.Project__c,
		Journal_Entry_Line__c.Project_Task__c,
		Journal_Entry_Line__c.Product__c,
		Journal_Entry_Line__c.Cash_Flow_Category__c,
		Journal_Entry_Line__c.Time_Card_Variable_1__c,
		Journal_Entry_Line__c.Time_Card_Variable_2__c,
		Journal_Entry_Line__c.GL_Account_Variable_1__c,
		Journal_Entry_Line__c.GL_Account_Variable_2__c,
		Journal_Entry_Line__c.GL_Account_Variable_3__c,
		Journal_Entry_Line__c.GL_Account_Variable_4__c
	};

	public Set<SObjectField> getLockedUpdateFieldsJELine() {
		Set<SObjectField> lockedUpdateFieldsJELine = new Set<SObjectField>{
			Journal_Entry_Line__c.Bank_Reconciliation__c,
			Journal_Entry_Line__c.Bank_Deposit__c
		};
		if (!SourceDocumentUpdateFieldValidator.isForceMatchPermitted()) {
			lockedUpdateFieldsJELine.add(Journal_Entry_Line__c.Bank_Transaction__c);
		}
		return lockedUpdateFieldsJELine;
	}

	public SObjectField statusFieldName = Journal_Entry_Line__c.Parent_Status__c;

	public JournalEntryLineFieldUpdateValidator() {
		statusField = statusFieldName;
		lockedUpdateFieldsPosted = lockedUpdateFieldsPostedJELine;
		lockedUpdateFields = getLockedUpdateFieldsJELine();
		skipDeleteValidationFlags = new List<Boolean>{ AccountingPeriodActions.isDelarcInProgress };
	}

	public override void setValidationRules() {
		preventUpdateAction();
		preventUpdateActionPosted();
		preventInsertActionPosted();
		preventDeleteActionPosted();
	}
}
