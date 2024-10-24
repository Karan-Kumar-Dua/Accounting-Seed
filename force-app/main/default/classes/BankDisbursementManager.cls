public with sharing class BankDisbursementManager {
	private static final String JOURNAL_ENTRY_LINE_TYPE_LABEL = Label.COMMON_JOURNAL_ENTRY_LINE;
	private static final String CASH_DISBURSEMENT_LABEL = Label.COMMON_CASH_DISBURSEMENT;
	private static final String ANY_TYPE_LABEL = Label.COMMON_ALL;

	@AuraEnabled
	public static List<ResultRecordsWrapper> getCDandJELRecords(
		String bankDisbursementId,
		String filtersJSON,
		String currentTabVal
	) {
		List<ResultRecordsWrapper> results = new List<ResultRecordsWrapper>();
		try {
			if (String.isNotBlank(bankDisbursementId)) {
				FiltersWrapper filters = (FiltersWrapper) JSON.deserialize(filtersJSON, FiltersWrapper.class);
				String selectedTypeValue = filters.objectType;
				List<Bank_Disbursement__c> listOfbankDisbursementRecs = ((List<Bank_Disbursement__c>) queryBankDisbursementRecord(
					bankDisbursementId
				));
				if (!listOfbankDisbursementRecs.isEmpty()) {
					List<SObject> listOfRecords = new List<SObject>();
					if (
						listOfbankDisbursementRecs[0].Bank_Reconciliation__c == null ||
						(currentTabVal == Label.COMMON_ASSOCIATE &&
						listOfbankDisbursementRecs[0].Bank_Reconciliation__c != null)
					) {
						if (
							String.isBlank(selectedTypeValue) ||
							selectedTypeValue == ANY_TYPE_LABEL ||
							selectedTypeValue == CASH_DISBURSEMENT_LABEL
						) {
							listOfRecords.addAll(
								queryCashDisbursements(
									'Cash_Disbursement__c',
									filters,
									listOfbankDisbursementRecs[0],
									currentTabVal
								)
							);
						}
						if (
							String.isBlank(selectedTypeValue) ||
							selectedTypeValue == ANY_TYPE_LABEL ||
							selectedTypeValue == JOURNAL_ENTRY_LINE_TYPE_LABEL
						) {
							listOfRecords.addAll(
								queryJournalEntryLines(
									'Journal_Entry_Line__c',
									filters,
									listOfbankDisbursementRecs[0],
									currentTabVal
								)
							);
						}
					}

					for (SObject rec : listOfRecords) {
						results.add(new ResultRecordsWrapper(rec, listOfbankDisbursementRecs[0].Ledger__c));
					}

					results.sort();
				}
			}
			System.debug('result---->' + results);
		} catch (Exception ex) {
			throw ex;
		}
		return results;
	}

	@AuraEnabled(cacheable=true)
	public static List<Bank_Disbursement__c> queryBankDisbursementRecord(String recordId) {
		List<String> fieldsToQuery = new List<String>{
			'Id',
			'Bank_GL_Account__c',
			'GL_Account_Variable_1__c',
			'GL_Account_Variable_2__c',
			'GL_Account_Variable_3__c',
			'GL_Account_Variable_4__c',
			'Ledger__c',
			'Amount__c',
			'Disbursement_Date__c',
			'Bank_Reconciliation__c',
			'Bank_Reconciliation__r.Name'
		};

		String queryCondition = 'Id =: recordId ';

		if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
			fieldsToQuery.add('CurrencyIsoCode');
		}

		SOQLBuilder theQuery = new SOQLBuilder(Bank_Disbursement__c.SObjectType);
		theQuery.setEnforceFLS(false).selectFields(fieldsToQuery).setCondition(queryCondition);
		return Database.query(theQuery.toSOQL());
	}

	private static List<SObject> queryCashDisbursements(
		String objectApiName,
		FiltersWrapper filters,
		Bank_Disbursement__c bankDisbursementRecord,
		String currentTabVal
	) {
		String queryCondition = getQueryCondition(objectApiName, filters, bankDisbursementRecord, currentTabVal);
		System.debug('queryCondition --> ' + queryCondition);
		List<String> queryFields = new List<String>{
			'Id',
			'Name',
			'Amount__c',
			'Disbursement_Date__c',
			'Vendor__c',
			'Vendor__r.Name',
			'Ledger_Amount__c',
			'Reference__c',
			'Status__c',
			'Bank_Disbursement__r.Bank_Reconciliation__c'
		};

		if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
			queryFields.add('CurrencyISOCode');
		}

		SOQLBuilder theQuery = new SOQLBuilder(Cash_Disbursement__c.SObjectType);
		theQuery
			.assertIsAccessible()
			.setEnforceFLS(true)
			.selectFields(queryFields)
			.setCondition(queryCondition)
			.setLimit(filters.queryLimitForCD);
		System.debug('theQuery.toSOQL() -> ' + theQuery.toSOQL());
		return Database.query(theQuery.toSOQL());
	}

	private static List<SObject> queryJournalEntryLines(
		String objectApiName,
		FiltersWrapper filters,
		Bank_Disbursement__c bankDisbursementRecord,
		String currentTabVal
	) {
		String queryCondition = getQueryCondition(objectApiName, filters, bankDisbursementRecord, currentTabVal);
		List<String> queryFields = new List<String>{
			'Id',
			'Name',
			'Date__c',
			'Amount__c',
			'Ledger_Amount__c',
			'Reference__c',
			'Account__c',
			'Account__r.Name',
			'Journal_Entry__r.Status__c',
			'Debit__c',
			'Credit__c',
			'Bank_Disbursement__r.Bank_Reconciliation__c'
		};

		if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
			queryFields.add('CurrencyISOCode');
		}

		SOQLBuilder theQuery = new SOQLBuilder(Journal_Entry_Line__c.SObjectType);
		theQuery
			.assertIsAccessible()
			.setEnforceFLS(true)
			.selectFields(queryFields)
			.setCondition(queryCondition)
			.setLimit(filters.queryLimitForJEL);

		return Database.query(theQuery.toSOQL());
	}

	private static String getQueryCondition(
		String objectApiName,
		FiltersWrapper filters,
		Bank_Disbursement__c bankDisbursementRecord,
		String currentTabVal
	) {
		String parsedStartDate = getValidDateFormat(Date.valueOf(filters.startDate));
		String parsedEndDate = getValidDateFormat(Date.valueOf(filters.endDate));
		String queryCondition;
		Decimal amountValue = (String.isNotBlank(filters.amount)) ? Decimal.valueOf(filters.amount) : null;
		// System.debug('amount value ->' + amountValue);
		String ledgerId = String.ValueOf(bankDisbursementRecord.get('Ledger__c'));
		String lastId = filters.lastFetchedRecordId;
		String glAccountId = String.ValueOf(bankDisbursementRecord.get('Bank_GL_Account__c'));

		switch on objectApiName {
			when 'Cash_Disbursement__c' {
				queryCondition =
					'Disbursement_Date__c >=' +
					parsedStartDate +
					' AND Disbursement_Date__c <= ' +
					parsedEndDate +
					' AND Disbursement_Date__c <= ' +
					getValidDateFormat(bankDisbursementRecord.Disbursement_Date__c) +
					' ';
				if (currentTabVal == Label.COMMON_UNASSOCIATE) {
					if (String.isNotBlank(ledgerId)) {
						queryCondition += ' AND Ledger__c =  \'' + ledgerId + '\' ';
					}
					queryCondition += ' AND Bank_Account__c =  \'' + glAccountId + '\' ';
					queryCondition += ' AND Payment_Status__c != \'Void\' ';
					queryCondition += ' AND Status__c = \'Posted\' ';
				}
				queryCondition += amountValue != null ? ('AND Amount__c = '+ amountValue +' ') : '';
			}
			when 'Journal_Entry_Line__c' {
				queryCondition =
					'Date__c >=' +
					parsedStartDate +
					'AND Date__c <=' +
					parsedEndDate +
					'AND Date__c <= ' +
					getValidDateFormat(bankDisbursementRecord.Disbursement_Date__c) +
					' ';
				if (currentTabVal == Label.COMMON_UNASSOCIATE) {
					if (String.isNotBlank(ledgerId)) {
						queryCondition += ' AND Journal_Entry__r.Ledger__c =  \'' + ledgerId + '\' ';
					}
					queryCondition += ' AND GL_Account__c =  \'' + glAccountId + '\' ';
					queryCondition += ' AND Bank_Deposit__c = NULL';
					queryCondition += ' AND Journal_Entry__r.Status__c = \'Posted\' ';
				}
				queryCondition += amountValue != null ?  (amountValue < 0 ? ( ' AND Amount__c = ' + Math.abs(amountValue) + ' AND Debit__c != NULL ' ) 
												: ' AND Amount__c = '+ amountValue + ' AND Credit__c != NULL') :  '';
				
			}
		}
		
		if (currentTabVal == Label.COMMON_UNASSOCIATE) {
			queryCondition += ' AND Bank_Disbursement__c = NULL ';
			queryCondition += ' AND Bank_Reconciliation__c = NULL ';
			queryCondition += getGlavVariablePredicate(
				String.ValueOf(bankDisbursementRecord.get('GL_Account_Variable_1__c')),
				String.ValueOf(bankDisbursementRecord.get('GL_Account_Variable_2__c')),
				String.ValueOf(bankDisbursementRecord.get('GL_Account_Variable_3__c')),
				String.ValueOf(bankDisbursementRecord.get('GL_Account_Variable_4__c'))
			);
			if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
				queryCondition +=
					' AND CurrencyISOCode = \'' +
					String.valueOf(bankDisbursementRecord.get('CurrencyIsoCode')) +
					'\' ';
			}
		} else if (currentTabVal == Label.COMMON_ASSOCIATE) {
			queryCondition += ' AND Bank_Disbursement__c =\'' + bankDisbursementRecord.Id + '\' ';
		}

		if (String.isNotBlank(lastId)) {
			queryCondition += ' AND Id >  \'' + lastId + '\' ';
		}
		return queryCondition;
	}

	private static String getValidDateFormat(Date dateVal) {
		return DateTime.newInstance(dateVal, Time.newInstance(0, 0, 0, 0)).format('yyyy-MM-dd');
	}

	public static String getGlavVariablePredicate(String glavVar1, String glavVar2, String glavVar3, String glavVar4) {
		String queryString = '';
		if (!String.isBlank(glavVar1)) {
			queryString += ' AND GL_Account_Variable_1__c = \'' + glavVar1 + '\' ';
		}

		if (!String.isBlank(glavVar2)) {
			queryString += ' AND GL_Account_Variable_2__c = \'' + glavVar2 + '\' ';
		}

		if (!String.isBlank(glavVar3)) {
			queryString += ' AND GL_Account_Variable_3__c = \'' + glavVar3 + '\' ';
		}

		if (!String.isBlank(glavVar4)) {
			queryString += ' AND GL_Account_Variable_4__c = \'' + glavVar4 + '\' ';
		}

		return queryString;
	}

	@AuraEnabled
	public static Integer getTotalCDRecords(String bankDisbursementId, String filtersJSON, String currentTabVal) {
		Integer totalCDrecords = 0;
		try {
			FiltersWrapper filters = (FiltersWrapper) JSON.deserialize(filtersJSON, FiltersWrapper.class);
			List<Bank_Disbursement__c> listOfBankDisbursementRecords = (List<Bank_Disbursement__c>) queryBankDisbursementRecord(
				bankDisbursementId
			);
			String selectedTypeValue = filters.objectType;
			if (!listOfBankDisbursementRecords.isEmpty()) {
				List<SObject> unAssociatedRecords = new List<SObject>();
				if (
					String.isBlank(selectedTypeValue) ||
					selectedTypeValue == ANY_TYPE_LABEL ||
					selectedTypeValue == CASH_DISBURSEMENT_LABEL
				) {
					totalCDrecords = getTotalRecordsCountHelper(
						'Cash_Disbursement__c',
						listOfBankDisbursementRecords[0],
						filters,
						currentTabVal
					);
				}
			}
			return totalCDrecords;
		} catch (Exception ex) {
			throw ex;
		}
	}

	@AuraEnabled
	public static Integer getTotalJELRecords(String bankDisbursementId, String filtersJSON, String currentTabVal) {
		Integer totalJELrecords = 0;
		try {
			FiltersWrapper filters = (FiltersWrapper) JSON.deserialize(filtersJSON, FiltersWrapper.class);
			List<Bank_Disbursement__c> listOfBankDisbursementRecords = (List<Bank_Disbursement__c>) queryBankDisbursementRecord(
				bankDisbursementId
			);
			String selectedTypeValue = filters.objectType;
			if (!listOfBankDisbursementRecords.isEmpty()) {
				List<SObject> unAssociatedRecords = new List<SObject>();
				if (
					String.isBlank(selectedTypeValue) ||
					selectedTypeValue == ANY_TYPE_LABEL ||
					selectedTypeValue == JOURNAL_ENTRY_LINE_TYPE_LABEL
				) {
					totalJELrecords = getTotalRecordsCountHelper(
						'Journal_Entry_Line__c',
						listOfBankDisbursementRecords[0],
						filters,
						currentTabVal
					);
				}
			}
			return totalJELrecords;
		} catch (Exception ex) {
			throw ex;
		}
	}

	@AuraEnabled
	public static Integer getTotalRecordsCountHelper(
		String objectApiName,
		Bank_Disbursement__c bankDisbursementRecord,
		FiltersWrapper filters,
		String currentTabVal
	) {
		Integer numberOfrecords = 0;

		String queryCondition = getQueryCondition(objectApiName, filters, bankDisbursementRecord, currentTabVal);
		String query = 'SELECT COUNT(ID) FROM ' + objectApiName + ' WHERE ';

		query += queryCondition;

		List<AggregateResult> results = Database.query(query);
		if (!results.isEmpty()) {
			AggregateResult result = results[0];
			numberOfRecords = Integer.valueOf(result.get('expr0'));
		}
		return numberOfrecords;
	}

	@AuraEnabled(cacheable=true)
	public static List<String> getFieldSetFields(String objectName, String fieldSetName) {
		List<String> fieldList = new List<String>();
		Schema.FieldSet fieldSetObj = Schema.getGlobalDescribe()
			.get(objectName)
			.getDescribe()
			.fieldSets.getMap()
			.get(fieldSetName);
		for (Schema.FieldSetMember f : fieldSetObj.getFields()) {
			fieldList.add(f.getFieldPath());
		}
		return fieldList;
	}

	@AuraEnabled
	public static List<SObject> updateCDorJELrecords(
		List<Id> listOfRecordIdsToUpdate,
		String bankDisbRecordId,
		String currentTabVal
	) {
		try {
			
			List<Cash_Disbursement__c> cashDisbursementsToUpdate = new List<Cash_Disbursement__c>();
			List<Journal_Entry_Line__c> journalEntryLinesToUpdate = new List<Journal_Entry_Line__c>();

			for (Id recordId : listOfRecordIdsToUpdate) {
				SObjectType sObjType = recordId.getSObjectType();
				if (sObjType == Cash_Disbursement__c.sObjectType) {
					Cash_Disbursement__c cdRecord = new Cash_Disbursement__c();
					cdRecord.Id = recordId;
					if (currentTabVal == Label.COMMON_UNASSOCIATE) {
						cdRecord.Bank_Disbursement__c = bankDisbRecordId;
					} else if (currentTabVal == Label.COMMON_ASSOCIATE) {
						cdRecord.Bank_Disbursement__c = null;
					}
					cashDisbursementsToUpdate.add(cdRecord);
				} else if (sObjType == Journal_Entry_Line__c.sObjectType) {
					Journal_Entry_Line__c jelRecord = new Journal_Entry_Line__c();
					jelRecord.Id = recordId;
					if (currentTabVal == Label.COMMON_UNASSOCIATE) {
						jelRecord.Bank_Disbursement__c = bankDisbRecordId;
					} else if (currentTabVal == Label.COMMON_ASSOCIATE) {
						jelRecord.Bank_Disbursement__c = null;
					}
					journalEntryLinesToUpdate.add(jelRecord);
				}
			}

			if (!cashDisbursementsToUpdate.isEmpty()) {
				SFDCSecurityUtils.updateCheckCRUDAndFLS(
					cashDisbursementsToUpdate,
					new List<String>{ 'Bank_Disbursement__c' }
				);
			}

			if (!journalEntryLinesToUpdate.isEmpty()) {
				SFDCSecurityUtils.updateCheckCRUDAndFLS(
					journalEntryLinesToUpdate,
					new List<String>{ 'Bank_Disbursement__c' }
				);
			}


			listOfSobjects.addAll(cashDisbursementsToUpdate);
			listOfSobjects.addAll(journalEntryLinesToUpdate);

			return listOfSobjects;
		} catch (Exception ex) {
			throw ex;
		}
	}

	public with sharing class ResultRecordsWrapper implements Comparable {
		@AuraEnabled
		public String name;

		@AuraEnabled
		public BankManagerHelper.VendorInfo customerInfo;

		@AuraEnabled
		public String objDate;

		@AuraEnabled
		public BankManagerHelper.Money money;

		@AuraEnabled
		public String reference;

		@AuraEnabled
		public BankManagerHelper.SourceObject sourceObj;

		@AuraEnabled
		public SObject obj;

		@AuraEnabled
		public String objId;

		@AuraEnabled
		public Id ledgerId;

		public ResultRecordsWrapper(SObject obj, Id ledgerId) {
			this.obj = Obj;
			this.ledgerId = ledgerId;
			this.name = (String) obj.get('Name');
			this.objId = (String) obj.get('Id');

			this.sourceObj = new BankManagerHelper.SourceObject(this.obj.Id, this.name, getSourceType());
			if (getSourceType() == CASH_DISBURSEMENT_LABEL) {
				this.customerInfo = ((obj.getSObject('Vendor__r') != null))
					? new BankManagerHelper.VendorInfo(
							(String) obj.getSObject('Vendor__r').get('Name'),
							(String) obj.getSObject('Vendor__r').get('Id')
					  )
					: new BankManagerHelper.VendorInfo('', '');
			} else if (getSourceType() == JOURNAL_ENTRY_LINE_TYPE_LABEL) {
				this.customerInfo = ((obj.getSObject('Account__r') != null))
					? new BankManagerHelper.VendorInfo(
							(String) obj.getSObject('Account__r').get('Name'),
							(String) obj.getSObject('Account__r').get('Id')
					  )
					: new BankManagerHelper.VendorInfo('', '');
			}

			Date objDateSource = getAssociableRecordDate(this.obj);
			this.objDate = (objDateSource != null) ? objDateSource.format() : '';
			this.money = getMoney();
			this.reference = (String) obj.get('Reference__c');
		}

		private Date getAssociableRecordDate(SObject wrappedSObject) {
			Date resultDate;

			switch on wrappedSObject {
				when Cash_Disbursement__c objRecord {
					resultDate = (Date) objRecord.get('Disbursement_Date__c');
				}
				when Journal_Entry_Line__c objRecord {
					resultDate = (objRecord.get('Date__c') != null)
						? (Date) objRecord.get('Date__c')
						: (Date) objRecord.getSObject('Journal_Entry__r').get('Journal_Date__c');
				}
			}
			return resultDate;
		}

		private BankManagerHelper.Money getMoney() {
			Decimal recordAmount = (Decimal) obj.get('Amount__c');
			Decimal ledgerAmount = (Decimal) obj.get('Ledger_Amount__c');
			String recordCurrency = (MultiCurrencyHandler.isMultiCurrencyEnabled)
				? (String) this.obj.get('CurrencyIsoCode')
				: MultiCurrencyHandler.CORPORATE_CURRENCY;
			String ledgerCurrency = LedgerHandler.getLedgerCurrency(this.ledgerId);
			switch on obj {
				when Journal_Entry_Line__c objRecord {
					if (objRecord.get('Debit__c') != null) {
						recordAmount = recordAmount * -1;
						ledgerAmount = ledgerAmount * -1;
					}
				}
			}
			return new BankManagerHelper.Money(recordAmount, recordCurrency, ledgerAmount, ledgerCurrency);
		}

		private String getSourceType() {
			String source = '';
			switch on obj {
				when Cash_Disbursement__c objRecord {
					source = CASH_DISBURSEMENT_LABEL;
				}
				when Journal_Entry_Line__c objRecord {
					source = JOURNAL_ENTRY_LINE_TYPE_LABEL;
				}
			}
			return source;
		}

		public Integer compareTo(Object compareTo) {
			ResultRecordsWrapper comparedRecord = (ResultRecordsWrapper) compareTo;
			if (getAssociableRecordDate(this.obj) == getAssociableRecordDate(comparedRecord.obj))
				return 0;
			if (getAssociableRecordDate(this.obj) > getAssociableRecordDate(comparedRecord.obj))
				return 1;
			return -1;
		}
	}

	public class FiltersWrapper {
		@AuraEnabled
		public String startDate;
		@AuraEnabled
		public String endDate;
		@AuraEnabled
		public String objectType;
		@AuraEnabled
		public String amount;
		@AuraEnabled
		public String lastFetchedRecordId;
		@AuraEnabled
		public Integer queryLimitForJEL;
		@AuraEnabled
		public Integer queryLimitForCD;

		public FiltersWrapper(
			String startDate,
			String endDate,
			String objectType,
			String amount,
			String lastFetchedRecordId,
			Integer queryLimitForJEL,
			Integer queryLimitForCD
		) {
			this.startDate = startDate;
			this.endDate = endDate;
			this.objectType = objectType;
			this.amount = amount;
			this.lastFetchedRecordId = lastFetchedRecordId;
			this.queryLimitForCD = queryLimitForCD;
			this.queryLimitForJEL = queryLimitForJEL;
		}
	}
}
