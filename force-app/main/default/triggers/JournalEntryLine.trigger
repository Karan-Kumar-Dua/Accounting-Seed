trigger JournalEntryLine on Journal_Entry_Line__c(
	before insert,
	after insert,
	before update,
	after update,
	before delete,
	after delete
) {
	if (Trigger.isBefore && Trigger.isInsert) {
		JournalEntryLineActions.populateDateField(Trigger.new);
		JournalEntryLineActions.setFieldValues(Trigger.new);
		SObjectActions.populateGLAVsFromAccountOrProduct(
			Trigger.new,
			JournalEntryLineActions.isSkipAutoGLAVsFromAccount
		);
		SObjectActions.associateWithCashFlowCategory(Trigger.new);
		SObjectActions.handleNonCloneableFields(Trigger.new);
		SObjectActions.setISOCodeFromParent(Trigger.new, 'Journal_Entry__c');
		SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, JournalEntryLineActions.currencyAndNumberFields);
		JournalEntryLineActions.validateBankDisbursementRelatedFields(Trigger.new);
		JournalEntryLineActions.validateIfRecordPostedBeforeAssociating(Trigger.new, Trigger.oldMap);
	}

	if (Trigger.isAfter && Trigger.isInsert) {
		JournalEntryLineActions.requireFields(Trigger.new);
		JournalEntryLineActions.validateDebitOrCreditField(Trigger.new);
		JournalEntryLineActions.validateTimeCardVariables(Trigger.new);
		GLAccountValidator.validateGlAccountLookups(Trigger.new, null);
		JournalEntryLineActions.validatePayeeSetCorrect(Trigger.new);
		SourceDocumentUpdateFieldValidator.validate(null, Trigger.newMap);
		SObjectActions.preventShadowLedgers(Trigger.new);
		SObjectActions.preventInactiveLedgers(Trigger.new);
		JournalEntryLineActions.calculateAmountFields(Trigger.New, Trigger.OldMap);
	}

	if (Trigger.isBefore && Trigger.isUpdate) {
		SObjectActions.setISOCodeFromParent(Trigger.new, 'Journal_Entry__c');
		JournalEntryLineActions.populateDateField(Trigger.new);
		JournalEntryLineActions.associateWithCashFlowCategoryOnUpdate(Trigger.new, Trigger.oldMap);
		JournalEntryLineActions.preventBankDisbUpdateIfBankRecCleared(Trigger.new, Trigger.oldMap);
		SObjectActions.amountUpdateSourceRecordUpdateBTStatus(
			Trigger.new,
			Trigger.oldMap,
			Journal_Entry_Line__c.Bank_Transaction__c
		);
		SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, JournalEntryLineActions.currencyAndNumberFields);
		JournalEntryLineActions.validateBankDisbursementRelatedFields(Trigger.new);
		JournalEntryLineActions.validateIfRecordPostedBeforeAssociating(Trigger.new, Trigger.oldMap);
		JournalEntryLineActions.validateBankDisbursementNdBankDepositAssociation(Trigger.new, Trigger.oldMap);
		JournalEntryLineActions.preventBDBAssociationIfDifferentGLV(Trigger.new);
	}

	if (Trigger.isAfter && Trigger.isUpdate) {
		JournalEntryLineActions.requireFields(Trigger.new);
		SObjectActions.preventSameTimeApplyOnDepositAndReconciliation(Trigger.oldMap, Trigger.new);
		SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, Trigger.newMap);
		GLAccountValidator.validateGlAccountLookups(Trigger.new, Trigger.oldMap);
		JournalEntryLineActions.validateDebitOrCreditField(Trigger.new);
		JournalEntryLineActions.validateTimeCardVariables(Trigger.new);
		JournalEntryLineActions.validatePayeeSetCorrect(Trigger.new);
		SObjectActions.handleBtForceMatch(Trigger.new, Trigger.oldMap);
		SObjectActions.preventShadowLedgers(Trigger.new);
		SObjectActions.preventInactiveLedgers(Trigger.new);
		JournalEntryLineActions.calculateAmountFields(Trigger.New, Trigger.OldMap);
	}

	if (Trigger.isBefore && Trigger.isDelete) {
		SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, null);
		SObjectActions.deleteSourceRecordUpdateBTStatus(Trigger.old);
	}

	if (Trigger.isDelete && Trigger.isAfter) {
		JournalEntryLineActions.calculateAmountFields(Trigger.New, Trigger.OldMap);
	}

}
