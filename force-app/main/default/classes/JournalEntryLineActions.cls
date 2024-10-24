public with sharing class JournalEntryLineActions {
	public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
	public static final Map<SObjectField, Integer> currencyAndNumberFields = new Map<SObjectField, Integer>{
		Journal_Entry_Line__c.Units__c => 6,
		Journal_Entry_Line__c.Debit__c => 2,
		Journal_Entry_Line__c.Credit__c => 2
	};

	public static Boolean isPreventUpdateOverride = false;
	public static Boolean isSkipAutoGLAVsFromAccount = false;
	public static final String BOTH_CREDIT_AND_DEBIT_ERROR = Label.ERR_BOTH_CREDIT_AND_DEBIT;
	public static final String NEITHER_CREDIT_AND_DEBIT_ERROR = Label.ERR_NEITHER_CREDIT_AND_DEBIT;
	public static final String WRONG_TIME_CARD_VARIABLES_ERROR = Label.ERR_WRONG_TIME_CARD_VARIABLES;
	public static final String ACCOUNT_NOT_EXCLUSIVELY_SET_ERROR = Label.ERR_ACCOUNT_NOT_EXCLUSIVELY_SET;
	public static final String PAYEE_NOT_EXCLUSIVELY_SET_ERROR = Label.ERR_PAYEE_NOT_EXCLUSIVELY_SET;
	public static final String JEL_CANT_BE_ASSOCIATED_TO_BD_AND_BDB = Label.ERR_JEL_CANT_BE_ASSOCIATED_TO_BD_AND_BDB;
	public static final String JEL_CANT_BE_ASSOCIATED_TO_BD_AND_BDB_BOTH = Label.ERR_JEL_CANT_BE_ASSOCIATED_TO_BD_AND_BDB_BOTH;
	public static final String COMMON_BANK_DEPOSIT = Label.COMMON_BANK_DEPOSIT;
	public static final String COMMON_BANK_DISBURSEMENT = Label.COMMON_BANK_DISBURSEMENT;
	public static final String JEL_CANT_BE_ASSOCIATED_TO_BDB_IF_DIFFERENT_GLV = Label.ERR_JEL_CANT_BE_ASSOCIATED_TO_BDB_IF_DIFFERENT_GLV;

	public static void requireFields(List<Journal_Entry_Line__c> jeLines) {
		for (Journal_Entry_Line__c jeLine : jeLines) {
			if (jeLine.GL_Account__c == null) {
				jeLine.GL_Account__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
			}
		}
	}

	public static void validatePayeeSetCorrect(List<SObject> jEntryLines) {
		List<SObject> jelList;
		switch on jEntryLines[0] {
			when Journal_Entry_Line__c objRecord {
				jelList = DomainUtils.getJournalEntryLineById(
					(new Map<Id, Journal_Entry_Line__c>((List<Journal_Entry_Line__c>) jEntryLines)).keySet()
				);
			}
			when Recurring_Journal_Entry_Line__c objRecord {
				jelList = DomainUtils.getRecurringJournalEntryLineById(
					(new Map<Id, Recurring_Journal_Entry_Line__c>((List<Recurring_Journal_Entry_Line__c>) jEntryLines))
						.keySet()
				);
			}
		}
		Map<Id, Id> jelByLedgers = SObjectActions.ledgerIdBySourceId(jelList);
		Map<Id, Map<String, GL_Account_Default__c>> defaults = GLAccount.glAccountDefaultsMapByLedgerId(
			new Set<Id>(jelByLedgers.values())
		);

		for (SObject jeLine : jEntryLines) {
			//get all populated Payees in one set
			Set<Id> allPopulatedPayees = new Set<Id>();
			if (jeLine.get('Account__c') != null) {
				allPopulatedPayees.add((Id) jeLine.get('Account__c'));
			}
			if (jeLine.get('Contact__c') != null) {
				allPopulatedPayees.add((Id) jeLine.get('Contact__c'));
			}
			if (jeLine.get('Employee__c') != null) {
				allPopulatedPayees.add((Id) jeLine.get('Employee__c'));
			}

			//Validate populated Payees by different Rules depending on GL Account field

			//AR Control GL Account set
			if (
				defaults.containsKey(jelByLedgers.get(jeLine.Id)) &&
				defaults.get(jelByLedgers.get(jeLine.Id)).containsKey(GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT) &&
				(Id) jeLine.get('GL_Account__c') ==
				defaults.get(jelByLedgers.get(jeLine.Id))
					.get(GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT)
					.GL_Account__c
			) {
				if (
					jeLine.get('Account__c') == null ||
					(jeLine.get('Account__c') != null &&
					allPopulatedPayees.size() > 1)
				) {
					jeLine.addError(ACCOUNT_NOT_EXCLUSIVELY_SET_ERROR);
				}
			}
			//AP Control GL Account set
			else if (
				defaults.containsKey(jelByLedgers.get(jeLine.Id)) &&
				defaults.get(jelByLedgers.get(jeLine.Id)).containsKey(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT) &&
				(Id) jeLine.get('GL_Account__c') ==
				defaults.get(jelByLedgers.get(jeLine.Id))
					.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)
					.GL_Account__c
			) {
				if (allPopulatedPayees.size() != 1) {
					jeLine.addError(PAYEE_NOT_EXCLUSIVELY_SET_ERROR);
				}
			}
			//If any of non AP/AR GL Account was set - there are no rules to enforce
		}
	}

	public static void populateDateField(List<Journal_Entry_Line__c> jEntryLines) {
		Map<Id, Journal_Entry__c> journalEntryMap = new Map<Id, Journal_Entry__c>();
		for (Journal_Entry_Line__c jel : jEntryLines) {
			journalEntryMap.put(jel.Journal_Entry__c, null);
		}

		journalEntryMap = new Map<Id, Journal_Entry__c>(DomainUtils.getJournalEntryById(journalEntryMap.keySet()));

		for (Journal_Entry_Line__c jel : jEntryLines) {
			Journal_Entry__c jEntry = journalEntryMap.get(jel.Journal_Entry__c);
			if (jEntry != null && jel.Date__c == null && jEntry.Status__c != 'Posted') {
				jel.Date__c = jEntry.Journal_Date__c;
			}
		}
	}

	public static void setFieldValues(List<Journal_Entry_Line__c> jEntryLines) {
		for (Journal_Entry_Line__c jel : jEntryLines) {
			jel.Bank_Deposit__c = null;
			jel.Bank_Reconciliation__c = null;
			jel.Bank_Disbursement__c = null;
			if (jel.isClone()) {
				jel.Cleared_Date__c = null;
			}
		}
	}

	public static void validateDebitOrCreditField(List<SObject> jEntryLines) {
		String template = jEntryLines[0].getSObjectType() == Journal_Entry_Line__c.SObjectType
			? ''
			: Label.COMMON_SMALL_RECURRING + ' ';
		for (SObject jel : jEntryLines) {
			if (jel.get('Debit__c') == null && jel.get('Credit__c') == null) {
				jel.addError(String.format(NEITHER_CREDIT_AND_DEBIT_ERROR, new List<String>{ template }));
			} else if (jel.get('Debit__c') != null && jel.get('Credit__c') != null) {
				jel.addError(String.format(BOTH_CREDIT_AND_DEBIT_ERROR, new List<String>{ template }));
			}
		}
	}

	public static void validateTimeCardVariables(List<SObject> jEntryLines) {
		Set<Id> variablesIds = new Set<Id>();
		for (SObject jel : jEntryLines) {
			if (jel.get('Time_Card_Variable_1__c') != null) {
				variablesIds.add((Id) jel.get('Time_Card_Variable_1__c'));
			}
			if (jel.get('Time_Card_Variable_2__c') != null) {
				variablesIds.add((Id) jel.get('Time_Card_Variable_2__c'));
			}
		}

		if (!variablesIds.isEmpty()) {
			Map<Id, Accounting_Variable__c> accVariables = new Map<Id, Accounting_Variable__c>(
				DomainUtils.getGLAVsById(variablesIds)
			);

			for (SObject jel : jEntryLines) {
				if (
					jel.get('Time_Card_Variable_1__c') != null &&
					accVariables.get((Id) jel.get('Time_Card_Variable_1__c')).Type__c != 'Time Card Variable 1'
				) {
					Journal_Entry_Line__c proxyLine = (Journal_Entry_Line__c) jel;
					proxyLine.Time_Card_Variable_1__c.addError(
						String.format(WRONG_TIME_CARD_VARIABLES_ERROR, new List<String>{ '1' })
					);
				}
				if (
					jel.get('Time_Card_Variable_2__c') != null &&
					accVariables.get((Id) jel.get('Time_Card_Variable_2__c')).Type__c != 'Time Card Variable 2'
				) {
					Journal_Entry_Line__c proxyLine = (Journal_Entry_Line__c) jel;
					proxyLine.Time_Card_Variable_2__c.addError(
						String.format(WRONG_TIME_CARD_VARIABLES_ERROR, new List<String>{ '2' })
					);
				}
			}
		}
	}

	public static void associateWithCashFlowCategory(List<SObject> jEntryLines) {
		Map<Id, Id> jeByLedger;
		Set<Id> parentJEIds = new Set<Id>();

		for (SObject jel : jEntryLines) {
			switch on jEntryLines[0] {
				when Journal_Entry_Line__c objRecord {
					parentJEIds.add(((Journal_Entry_Line__c) jel).Journal_Entry__c);
				}
				when Recurring_Journal_Entry_Line__c objRecord {
					parentJEIds.add(((Recurring_Journal_Entry_Line__c) jel).Recurring_Journal_Entry__c);
				}
			}
		}

		switch on jEntryLines[0] {
			when Journal_Entry_Line__c objRecord {
				jeByLedger = SObjectActions.ledgerIdBySourceId(DomainUtils.getJournalEntryById(parentJEIds));
			}
			when Recurring_Journal_Entry_Line__c objRecord {
				jeByLedger = SObjectActions.ledgerIdBySourceId(DomainUtils.getRecurringJournalEntryById(parentJEIds));
			}
		}

		Map<Id, Map<String, GL_Account_Default__c>> defaults = GLAccount.glAccountDefaultsMapByLedgerId(
			new Set<Id>(jeByLedger.values())
		);

		Set<Id> glAccountIds = new Set<Id>();
		for (SObject jel : jEntryLines) {
			if (jel.get('GL_Account__c') != null) {
				glAccountIds.add((Id) jel.get('GL_Account__c'));
			}
		}

		Map<Id, GL_Account__c> glAccounts = new Map<Id, GL_Account__c>(DomainUtils.getGlAccountsById(glAccountIds));

		for (SObject jel : jEntryLines) {
			Id parentId;
			switch on jel {
				when Journal_Entry_Line__c objRecord {
					parentId = ((Journal_Entry_Line__c) jel).Journal_Entry__c;
				}
				when Recurring_Journal_Entry_Line__c objRecord {
					parentId = ((Recurring_Journal_Entry_Line__c) jel).Recurring_Journal_Entry__c;
				}
			}

			if (
				glAccounts.containsKey((Id) jel.get('GL_Account__c')) &&
				glAccounts.get((Id) jel.get('GL_Account__c')).Bank__c &&
				defaults.containsKey(jeByLedger.get(parentId)) &&
				defaults.get(jeByLedger.get(parentId))
					.containsKey(GLAccountDefaultsHandler.DEFAULT_JOURNAL_ENTRY_LINE_CATEGORY)
			) {
				jel.put(
					'Cash_Flow_Category__c',
					defaults.get(jeByLedger.get(parentId))
						.get(GLAccountDefaultsHandler.DEFAULT_JOURNAL_ENTRY_LINE_CATEGORY)
						.GL_Account__c
				);
			}
		}
	}

	public static void associateWithCashFlowCategoryOnUpdate(
		List<SObject> newJEntryLines,
		Map<Id, SObject> oldJournalEntryLines
	) {
		List<SObject> linesToAssociate = new List<SObject>();

		for (SObject newJEL : newJEntryLines) {
			SObject oldJEL = oldJournalEntryLines.get((Id) newJEL.get('Id'));
			if (newJEL.get('GL_Account__c') != oldJEL.get('GL_Account__c')) {
				linesToAssociate.add(newJEL);
			}
		}

		if (!linesToAssociate.isEmpty()) {
			associateWithCashFlowCategory(linesToAssociate);
		}
	}

	public static void validateBankDisbursementRelatedFields(List<Journal_Entry_Line__c> listOfNewJELs) {
		Set<Id> setOfBankDisbIds = new Set<Id>();
		List<Journal_Entry_Line__c> listOfJELsToValidate = new List<Journal_Entry_Line__c>();
		Set<Id> setOfJournalEntryIds = new Set<Id>();

		for (Journal_Entry_Line__c journalEntryLineRec : listOfNewJELs) {
			if (journalEntryLineRec.Bank_Disbursement__c != null) {
				setOfBankDisbIds.add(journalEntryLineRec.Bank_Disbursement__c);
				listOfJELsToValidate.add(journalEntryLineRec);
				setOfJournalEntryIds.add(journalEntryLineRec.Journal_Entry__c);
			}
		}

		if (!setOfBankDisbIds.isEmpty()) {
			Map<Id, Bank_Disbursement__c> mapOfIdAndBankDisbursements = DomainUtils.getBankDisbursements(
				setOfBankDisbIds
			);
			Map<Id, Journal_Entry__c> journalEntryMap = new Map<Id, Journal_Entry__c>(
				DomainUtils.getJournalEntryById(setOfJournalEntryIds)
			);
			if (!mapOfIdAndBankDisbursements.isEmpty()) {
				for (Journal_Entry_Line__c jelDisbRec : listOfJELsToValidate) {
					validatGLAccount(jelDisbRec, mapOfIdAndBankDisbursements);
					validateDisbursementDate(jelDisbRec, mapOfIdAndBankDisbursements);
					if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
						validateBankDisbursementHasTheSameCurrency(jelDisbRec, mapOfIdAndBankDisbursements);
					}
					validateIfRecordPostedBeforeAssociating(jelDisbRec, journalEntryMap);
				}
			}
		}
	}

	public static void validateIfRecordPostedBeforeAssociating(
		Journal_Entry_Line__c jelDisbRec,
		Map<Id, Journal_Entry__c> journalEntryMap
	) {
		if (
			journalEntryMap.containsKey(jelDisbRec.Journal_Entry__c) &&
			journalEntryMap.get(jelDisbRec.Journal_Entry__c).Status__c != 'Posted'
		) {
			jelDisbRec.Bank_Disbursement__c.addError(
				String.format(
					Label.ERR_ASSOCIATING_BD_IF_RECORD_IS_NOT_POSTED,
					new List<String>{ Label.COMMON_JOURNAL_ENTRY }
				)
			);
		}
	}

	public static void validatGLAccount(
		Journal_Entry_Line__c jelDisbRec,
		Map<Id, Bank_Disbursement__c> mapOfIdAndBankDisbursements
	) {
		if (
			mapOfIdAndBankDisbursements.containsKey(jelDisbRec.Bank_Disbursement__c) &&
			jelDisbRec.GL_Account__c != null &&
			mapOfIdAndBankDisbursements.get(jelDisbRec.Bank_Disbursement__c).Bank_GL_Account__c != null &&
			jelDisbRec.GL_Account__c !=
			mapOfIdAndBankDisbursements.get(jelDisbRec.Bank_Disbursement__c).Bank_GL_Account__c
		) {
			jelDisbRec.Bank_Disbursement__c.addError(
				Label.ERR_PREVENT_ASSOCIATING_RECORD_IF_BANK_ACCOUNT_DOESNT_MATCH_ON_BD
			);
		}
	}

	public static void validateDisbursementDate(
		Journal_Entry_Line__c jelDisbRec,
		Map<Id, Bank_Disbursement__c> mapOfIdAndBankDisbursements
	) {
		if (
			mapOfIdAndBankDisbursements.containsKey(jelDisbRec.Bank_Disbursement__c) &&
			mapOfIdAndBankDisbursements.get(jelDisbRec.Bank_Disbursement__c).Disbursement_Date__c != null &&
			jelDisbRec.Date__c > mapOfIdAndBankDisbursements.get(jelDisbRec.Bank_Disbursement__c).Disbursement_Date__c
		) {
			jelDisbRec.Bank_Disbursement__c.addError(
				Label.ERR_PREVENT_ASSOCIATING_RECORD_IF_DATE_EXCEEDS_DISBURSEMENT_DATE_ON_BD
			);
		}
	}

	public static void validateBankDisbursementHasTheSameCurrency(
		Journal_Entry_Line__c jelDisbRec,
		Map<Id, Bank_Disbursement__c> mapOfIdAndBankDisbursements
	) {
		if (
			mapOfIdAndBankDisbursements.containsKey(jelDisbRec.Bank_Disbursement__c) &&
			jelDisbRec.get('CurrencyIsoCode') !=
			mapOfIdAndBankDisbursements.get(jelDisbRec.Bank_Disbursement__c).get('CurrencyIsoCode')
		) {
			jelDisbRec.Bank_Disbursement__c.addError(Label.ERR_JEL_CURRENCY_MISMATCH_BANK_DISB);
		}
	}

	public static void validateIfRecordPostedBeforeAssociating(
		List<Journal_Entry_Line__c> listOfNewJELs,
		Map<Id, Journal_Entry_Line__c> oldJELMap
	) {
		Map<Id, Journal_Entry__c> journalEntryMap = new Map<Id, Journal_Entry__c>();
		for (Journal_Entry_Line__c jel : listOfNewJELs) {
			journalEntryMap.put(jel.Journal_Entry__c, null);
		}

		journalEntryMap = new Map<Id, Journal_Entry__c>(DomainUtils.getJournalEntryById(journalEntryMap.keySet()));

		for (Journal_Entry_Line__c jelDisbRec : listOfNewJELs) {
			Journal_Entry__c jEntry = journalEntryMap.get(jelDisbRec.Journal_Entry__c);
			if (
				((oldJELMap == null && jelDisbRec.Bank_Disbursement__c != null) ||
				(oldJELMap != null &&
				(jelDisbRec.Bank_Disbursement__c != null &&
				jelDisbRec.Bank_Disbursement__c != oldJELMap.get(jelDisbRec.Id).Bank_Disbursement__c))) &&
				jEntry.Status__c != 'Posted'
			) {
				jelDisbRec.Bank_Disbursement__c.addError(
					String.format(
						Label.ERR_ASSOCIATING_BD_IF_RECORD_IS_NOT_POSTED,
						new List<String>{ Label.COMMON_JOURNAL_ENTRY }
					)
				);
			}
		}
	}

	public static void preventBankDisbUpdateIfBankRecCleared(
		List<Journal_Entry_Line__c> listOfNewJELs,
		Map<Id, Journal_Entry_Line__c> oldJELMap
	) {
		Set<Id> setOfBankRecIds = new Set<Id>();
		Set<Id> setOfBankDisbIds = new Set<Id>();
		Map<Id, Bank_Reconciliation2__c> mapOfIdAndBankRec = new Map<Id, Bank_Reconciliation2__c>();
		Map<Id, Bank_Disbursement__c> mapOfIdAndBankDisbursements = new Map<Id, Bank_Disbursement__c>();
		List<Journal_Entry_Line__c> listOfJELsToProcess = new List<Journal_Entry_Line__c>();

		for (Journal_Entry_Line__c jelDisbRec : listOfNewJELs) {
			if (jelDisbRec.Bank_Disbursement__c != oldJELMap.get(jelDisbRec.Id).Bank_Disbursement__c) {
				if (jelDisbRec.Bank_Reconciliation__c != null) {
					setOfBankRecIds.add(jelDisbRec.Bank_Reconciliation__c);
				}
				setOfBankDisbIds.add(jelDisbRec.Bank_Disbursement__c);
				listOfJELsToProcess.add(jelDisbRec);
			}
		}

		if (!setOfBankDisbIds.isEmpty()) {
			mapOfIdAndBankDisbursements = DomainUtils.getBankDisbursements(setOfBankDisbIds);
			for (Bank_Disbursement__c bankDisbRec : mapOfIdAndBankDisbursements.values()) {
				if (bankDisbRec.Bank_Reconciliation__c != null) {
					setOfBankRecIds.add(bankDisbRec.Bank_Reconciliation__c);
				}
			}
		}

		if (!setOfBankRecIds.isEmpty()) {
			for (Bank_Reconciliation2__c bankRec : DomainUtils.getBankRecsById(setOfBankRecIds)) {
				mapOfIdAndBankRec.put(bankRec.Id, bankRec);
			}
		}

		for (Journal_Entry_Line__c jelDisbRec : listOfJELsToProcess) {
			if (jelDisbRec.Bank_Reconciliation__c != null) {
				jelDisbRec.Bank_Disbursement__c.addError(
					String.format(
						Label.ERR_PREVENT_ASSOCIATING_RECORD_IF_BANK_RECONCILIATION_CLEARED,
						new List<String>{
							Label.COMMON_JOURNAL_ENTRY_LINE,
							mapOfIdAndBankRec.get(jelDisbRec.Bank_Reconciliation__c).Name,
							Label.COMMON_JOURNAL_ENTRY_LINE
						}
					)
				);
			} else if (
				mapOfIdAndBankDisbursements.containsKey(jelDisbRec.Bank_Disbursement__c) &&
				mapOfIdAndBankDisbursements.get(jelDisbRec.Bank_Disbursement__c).Bank_Reconciliation__c != null
			) {
				Bank_Reconciliation2__c bankReconciliationRec = mapOfIdAndBankRec.get(
					mapOfIdAndBankDisbursements.get(jelDisbRec.Bank_Disbursement__c).Bank_Reconciliation__c
				);
				jelDisbRec.Bank_Disbursement__c.addError(
					String.format(
						Label.ERR_PREVENT_ASSOCIATING_RECORD_IF_BANK_RECONCILIATION_CLEARED,
						new List<String>{
							Label.COMMON_BANK_DISBURSEMENT,
							bankReconciliationRec.Name,
							Label.COMMON_BANK_DISBURSEMENT
						}
					)
				);
			}
		}
	}

	public static void calculateAmountFields(
		List<Journal_Entry_Line__c> listOfNewJELs,
		Map<Id, Journal_Entry_Line__c> oldJELMap
	) {
		Set<Id> listOfBankDisbIds = new Set<Id>();
		if (listOfNewJELs != null) {
			for (Journal_Entry_Line__c jelDisbRec : listOfNewJELs) {
				if (jelDisbRec.Bank_Disbursement__c != null) {
					listOfBankDisbIds.add(jelDisbRec.Bank_Disbursement__c);
				}
			}
		}

		if (oldJELMap != null) {
			for (Journal_Entry_Line__c jelDisbRec : oldJELMap.values()) {
				if (jelDisbRec.Bank_Disbursement__c != null) {
					listOfBankDisbIds.add(jelDisbRec.Bank_Disbursement__c);
				}
			}
		}

		if (!listOfBankDisbIds.isEmpty()) {
			List<Bank_Disbursement__c> listOfbankDisbursementsToUpdate = new List<Bank_Disbursement__c>();
			Map<Id, AggregateResult> cdAggregateResult = DomainUtils.getCashDisbAmountSumByBankDis(listOfBankDisbIds);
			Map<Id, AggregateResult> debitJELAggregateResult = DomainUtils.getDebitJEAmountSumByBankDis(
				listOfBankDisbIds
			);
			Map<Id, AggregateResult> creditJELAggregateResult = DomainUtils.getCreditJEAmountSumByBankDis(
				listOfBankDisbIds
			);

			for (Id bankDisbRecId : listOfBankDisbIds) {
				Decimal totalAmount = 0;
				Decimal totalLedgerAmount = 0;

				// Aggregate Cash Disbursements Amounts
				totalAmount += aggregateAmount(cdAggregateResult, bankDisbRecId, 'amountSum');
				totalLedgerAmount += aggregateAmount(cdAggregateResult, bankDisbRecId, 'ledgerAmountSum');

				// Aggregate Debit Journal Entry Lines Amounts
				totalAmount -= aggregateAmount(debitJELAggregateResult, bankDisbRecId, 'amountSum');
				totalLedgerAmount -= aggregateAmount(debitJELAggregateResult, bankDisbRecId, 'ledgerAmountSum');

				// Aggregate Credit Journal Entry Lines Amounts
				totalAmount += aggregateAmount(creditJELAggregateResult, bankDisbRecId, 'amountSum');
				totalLedgerAmount += aggregateAmount(creditJELAggregateResult, bankDisbRecId, 'ledgerAmountSum');

				Bank_Disbursement__c bankDisb = new Bank_Disbursement__c(Id = bankDisbRecId);
				bankDisb.Amount__c = totalAmount.setScale(2, System.RoundingMode.HALF_UP);
				bankDisb.Ledger_Amount__c = totalLedgerAmount.setScale(2, System.RoundingMode.HALF_UP);
				listOfbankDisbursementsToUpdate.add(bankDisb);
			}
			// Update Bank Disbursement records
			TriggerObserver.getInstance()
				.unlockFields(
					new Set<SObjectField>{ Bank_Disbursement__c.Amount__c, Bank_Disbursement__c.Ledger_Amount__c }
				);
			SFDCSecurityUtils.updateCheckCRUDAndFLS(
				listOfbankDisbursementsToUpdate,
				new List<String>{ 'Amount__c', 'Ledger_Amount__c' }
			);
			TriggerObserver.purgeUnlockedFields(
				new Set<SObjectField>{ Bank_Disbursement__c.Amount__c, Bank_Disbursement__c.Ledger_Amount__c }
			);
		}
	}

	private static Decimal aggregateAmount(Map<Id, AggregateResult> aggregateResult, Id recordId, String fieldName) {
		if (
			aggregateResult.containsKey(recordId) &&
			aggregateResult.get(recordId) != null &&
			aggregateResult.get(recordId).get(fieldName) != null
		) {
			return (Decimal) aggregateResult.get(recordId).get(fieldName);
		}
		return 0;
	}

	public static void validateBankDisbursementNdBankDepositAssociation(
		List<Journal_Entry_Line__c> newJelRecords,
		Map<Id, Journal_Entry_Line__c> oldJelRecordsMap
	) {
		Map<String, String> bankDepositAndBDBWithName = new Map<String, String>();
		Set<Id> jELIds = new Set<Id>();
		for (Journal_Entry_Line__c jelRecord : newJelRecords) {
			if (jelRecord.Bank_Disbursement__c != null && jelRecord.Bank_Deposit__c != null) {
				jELIds.add(jelRecord.Id);
			}
		}

		if (!jELIds.isEmpty()) {
			for (Journal_Entry_Line__c journalEntryLine : DomainUtils.getJournalEntryLineById(jELIds)) {
				if (journalEntryLine.Bank_Deposit__c != null) {
					bankDepositAndBDBWithName.put(
						journalEntryLine.Bank_Deposit__c,
						journalEntryLine.Bank_Deposit__r.Name
					);
				} else if (journalEntryLine.Bank_Disbursement__c != null) {
					bankDepositAndBDBWithName.put(
						journalEntryLine.Bank_Disbursement__c,
						journalEntryLine.Bank_Disbursement__r.Name
					);
				}
			}
		}

		for (Journal_Entry_Line__c jelRecord : newJelRecords) {
			if (jelRecord.Bank_Disbursement__c != null && jelRecord.Bank_Deposit__c != null) {
				if (oldJelRecordsMap.containsKey(jelRecord.Id)) {
					List<String> currentlyAssociated = new List<String>();
					String previouslyAssociated = '';

					if (oldJelRecordsMap.get(jelRecord.Id).Bank_Deposit__c == null) {
						currentlyAssociated.add(COMMON_BANK_DEPOSIT);
					}
					if (oldJelRecordsMap.get(jelRecord.Id).Bank_Disbursement__c == null) {
						currentlyAssociated.add(COMMON_BANK_DISBURSEMENT);
					}

					if (currentlyAssociated.size() > 1) {
						jelRecord.addError(JEL_CANT_BE_ASSOCIATED_TO_BD_AND_BDB_BOTH);
					} else {
						if (currentlyAssociated[0] == COMMON_BANK_DEPOSIT) {
							previouslyAssociated = COMMON_BANK_DISBURSEMENT;

							if (bankDepositAndBDBWithName.containsKey(jelRecord.Bank_Disbursement__c)) {
								previouslyAssociated +=
									'{' +
									bankDepositAndBDBWithName.get(jelRecord.Bank_Disbursement__c) +
									'}';
							}
						} else {
							previouslyAssociated = COMMON_BANK_DEPOSIT;
							if (bankDepositAndBDBWithName.containsKey(jelRecord.Bank_Deposit__c)) {
								previouslyAssociated +=
									'{' +
									bankDepositAndBDBWithName.get(jelRecord.Bank_Deposit__c) +
									'}';
							}
						}
						jelRecord.addError(
							String.format(
								JEL_CANT_BE_ASSOCIATED_TO_BD_AND_BDB,
								new List<String>{ currentlyAssociated[0], previouslyAssociated }
							)
						);
					}
				}
			}
		}
	}

	public static void preventBDBAssociationIfDifferentGLV(List<Journal_Entry_Line__c> newJelRecords) {
		Set<Id> bankDisbursementIds = new Set<Id>();
		for (Journal_Entry_Line__c jelRecord : newJelRecords) {
			if (jelRecord.Bank_Disbursement__c != null) {
				bankDisbursementIds.add(jelRecord.Bank_Disbursement__c);
			}
		}
		if (!bankDisbursementIds.isEmpty()) {
			Map<Id, Bank_Disbursement__c> bankDisbursementMap = DomainUtils.getBankDisbursements(bankDisbursementIds);
			for (Journal_Entry_Line__c jelRecord : newJelRecords) {
				if (
					jelRecord.Bank_Disbursement__c != null &&
					bankDisbursementMap.containsKey(jelRecord.Bank_Disbursement__c)
				) {
					Boolean isGlVDifferent = false;
					Bank_Disbursement__c bankDisbursement = bankDisbursementMap.get(jelRecord.Bank_Disbursement__c);
					if (
						isGlVariableDifferent(
							bankDisbursement.GL_Account_Variable_1__c,
							jelRecord.GL_Account_Variable_1__c
						)
					) {
						isGlVDifferent = true;
					} else if (
						isGlVariableDifferent(
							bankDisbursement.GL_Account_Variable_2__c,
							jelRecord.GL_Account_Variable_2__c
						)
					) {
						isGlVDifferent = true;
					} else if (
						isGlVariableDifferent(
							bankDisbursement.GL_Account_Variable_3__c,
							jelRecord.GL_Account_Variable_3__c
						)
					) {
						isGlVDifferent = true;
					} else if (
						isGlVariableDifferent(
							bankDisbursement.GL_Account_Variable_4__c,
							jelRecord.GL_Account_Variable_4__c
						)
					) {
						isGlVDifferent = true;
					}

					// Add error if any of Gl variable is different
					if (isGlVDifferent) {
						jelRecord.addError(
							String.format(
								JEL_CANT_BE_ASSOCIATED_TO_BDB_IF_DIFFERENT_GLV,
								new List<String>{ bankDisbursement.Name }
							)
						);
					}
				}
			}
		}
	}

	public static Boolean isGlVariableDifferent(String bankDisbursementGLV, String journalEntryLineGLV) {
		return (String.isNotBlank(bankDisbursementGLV) &&
		String.isNotBlank(journalEntryLineGLV) &&
		bankDisbursementGLV != journalEntryLineGLV);
	}
}
