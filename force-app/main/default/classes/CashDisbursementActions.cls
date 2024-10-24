public with sharing class CashDisbursementActions {
	public static final String STATUS_PAID = 'Paid';
	public static final String STATUS_VOID = 'Void';
	public static final String SOURCE_MANUAL = 'Manual';
	public static final String SOURCE_PAYABLE = 'Payable';
	public static final String AS_PAY_TYPE = 'AS Pay';
	public static final String CHECK_TYPE = 'Check';
	public static final String ACH_TYPE = 'ACH';
	public static final String VCARD_TYPE = 'Virtual Card';

	private static final String STATUS_IN_PROCESS = 'In Process';
	private static final String STATUS_POSTED = 'Posted';
	private static final String PAYMENT_STATUS_PENDING = 'Pending';
	private static final Set<String> PAYMENT_SERVICE_STATUS_RECONCILE_COMPLETE = new Set<String>{
		'Reconcile Complete',
		'RECONCILE_COMPLETE'
	};

	@TestVisible
	private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
	private static final Boolean isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;

	public static Boolean isBypassGLAccountValidations = false;
	public static Boolean isBatchPay = false;

	public static final List<SObjectField> NON_UPDATE_FIELDS_IF_ASSOCIATED_WITH_AP = new List<SObjectField>{
		Cash_Disbursement__c.Amount__c,
		Cash_Disbursement__c.Accounting_Period__c,
		Cash_Disbursement__c.Debit_GL_Account__c,
		Cash_Disbursement__c.Employee__c,
		Cash_Disbursement__c.Vendor__c,
		Cash_Disbursement__c.Contact__c,
		Cash_Disbursement__c.Ledger__c,
		Cash_Disbursement__c.Source__c
	};
	public static final Map<SObjectField, Integer> currencyAndNumberFields = new Map<SObjectField, Integer>{
		Cash_Disbursement__c.Amount__c => 2,
		Cash_Disbursement__c.Currency_Conversion_Rate__c => 6
	};
	public static final String REQUIRED_PAYEE_ERROR = Label.ERR_REQUIRED_PAYEE;
	public static final String MULTIPLE_PAYEE_ERROR = Label.ERR_MULTIPLE_PAYEEE;
	public static final String NON_UPDATE_FIELDS_AP_UPDATE_ERROR = Label.ERR_NON_UPDATE_FIELDS_AP_UPDATE;
	public static final String NOT_EQUAL_CURRENCY_ERROR = Label.ERR_CASH_DISBURSEMENT_CURRENCY_MISMATCH_CD_BATCH;
	public static final String ATTEMPT_TO_DELETE_APPLIED_ERROR = Label.ERR_ATTEMPT_TO_DELETE_APPLIED;
	public static final String SOURCE_CHANGE_ERROR = Label.ERR_SOURCE_CHANGE_CASH_DISBURSEMENT;
	public static final String PAYMENT_SERVICES_ALREADY_SUBMITTED = Label.ERR_CD_PAYMENT_SERVICES_ALREADY_SUBMITTED;
	@TestVisible
	public static final String INVALID_1099_INFO = Label.ERR_1099_FORM_TYPE_INVALID;
	public static final String CASH_DISBURSEMENT_CANT_BE_ASSOCIATED_TO_BDB_IF_DIFFERENT_GLV = Label.ERR_CASH_DISBURSEMENT_CANT_BE_ASSOCIATED_TO_BDB_IF_DIFFERENT_GLV;
	public static Boolean isSourcedFromPayables = false;

	public static void populatePayeeDataFromVendor(Cash_Disbursement__c[] newCashDisbursements) {
		Map<Id, Account> vendors = new Map<Id, Account>();
		Map<Id, Contact> contacts = new Map<Id, Contact>();
		Map<Id, User> employees = new Map<Id, User>();
		Set<Id> vendorIds = new Set<Id>();
		Set<Id> contactIds = new Set<Id>();
		Set<Id> employeeIds = new Set<Id>();

		for (Cash_Disbursement__c cd : newCashDisbursements) {
			if (cd.Vendor__c != null) {
				vendorIds.add(cd.Vendor__c);
			}
			if (cd.Contact__c != null) {
				contactIds.add(cd.Contact__c);
			}
			if (cd.Employee__c != null) {
				employeeIds.add(cd.Employee__c);
			}
		}
		//query Payee data from related Vendor
		if (!vendorIds.isEmpty()) {
			vendors = new Map<Id, Account>(DomainUtils.getAccountsById(vendorIds));
		}
		//query Payee data from related Contact
		if (!contactIds.isEmpty()) {
			contacts = new Map<Id, Contact>(DomainUtils.getContactById(contactIds));
		}
		//query Payee data from related User
		if (!employeeIds.isEmpty()) {
			employees = new Map<Id, User>(DomainUtils.getUserById(employeeIds));
		}
		//populate Payee data from related Vendors to Cash Disbursements
		for (Cash_Disbursement__c cd : newCashDisbursements) {
			if (cd.Vendor__c != null) {
				if (cd.Alternate_Payee_Name__c == null) {
					cd.Alternate_Payee_Name__c = vendors.get(cd.Vendor__c).Alternate_Payee_Name__c;
				}
				if (cd.Payee_Street2__c == null) {
					cd.Payee_Street2__c = vendors.get(cd.Vendor__c).BillingStreet;
				}
				if (cd.Payee_City__c == null) {
					cd.Payee_City__c = vendors.get(cd.Vendor__c).BillingCity;
				}
				if (cd.Payee_State__c == null) {
					cd.Payee_State__c = vendors.get(cd.Vendor__c).BillingState;
				}
				if (cd.Payee_Postal_Code__c == null) {
					cd.Payee_Postal_Code__c = vendors.get(cd.Vendor__c).BillingPostalCode;
				}
				if (cd.Payee_Country2__c == null) {
					cd.Payee_Country2__c = vendors.get(cd.Vendor__c).BillingCountry;
				}
			}
			//populate Payee data from related Contacts to Cash Disbursements
			if (cd.Contact__c != null) {
				if (cd.Payee_Street2__c == null) {
					cd.Payee_Street2__c = contacts.get(cd.Contact__c).MailingStreet;
				}
				if (cd.Payee_City__c == null) {
					cd.Payee_City__c = contacts.get(cd.Contact__c).MailingCity;
				}
				if (cd.Payee_State__c == null) {
					cd.Payee_State__c = contacts.get(cd.Contact__c).MailingState;
				}
				if (cd.Payee_Postal_Code__c == null) {
					cd.Payee_Postal_Code__c = contacts.get(cd.Contact__c).MailingPostalCode;
				}
				if (cd.Payee_Country2__c == null) {
					cd.Payee_Country2__c = contacts.get(cd.Contact__c).MailingCountry;
				}
			}
			//populate Payee data from related Users to Cash Disbursements
			if (cd.Employee__c != null) {
				if (cd.Payee_Street2__c == null) {
					cd.Payee_Street2__c = employees.get(cd.Employee__c).Street;
				}
				if (cd.Payee_City__c == null) {
					cd.Payee_City__c = employees.get(cd.Employee__c).City;
				}
				if (cd.Payee_State__c == null) {
					cd.Payee_State__c = employees.get(cd.Employee__c).State;
				}
				if (cd.Payee_Postal_Code__c == null) {
					cd.Payee_Postal_Code__c = employees.get(cd.Employee__c).PostalCode;
				}
				if (cd.Payee_Country2__c == null) {
					cd.Payee_Country2__c = employees.get(cd.Employee__c).Country;
				}
			}
		}
	}

	public static void requireFields(List<Cash_Disbursement__c> cashDisbursements) {
		for (Cash_Disbursement__c cd : cashDisbursements) {
			if (cd.Accounting_Period__c == null) {
				cd.Accounting_Period__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
			}
			if (cd.Ledger__c == null) {
				cd.Ledger__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
			}
			if (cd.Bank_Account__c == null) {
				cd.Bank_Account__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
			}
		}
	}

	public static Boolean isSourcePayable(Cash_Disbursement__c record) {
		return new CashDisbursementActionWrapper(record).isSourcePayable();
	}

	// Some fields should not be updated if there any associated AP Disbursement records
	public static void preventUpdateFieldsIfSourcedAP(
		Map<Id, Cash_Disbursement__c> oldCashDisbursementMap,
		Map<Id, Cash_Disbursement__c> newCashDisbursementMap
	) {
		for (Cash_Disbursement__c cd : newCashDisbursementMap.values()) {
			Cash_Disbursement__c oldCd = oldCashDisbursementMap.get(cd.Id);
			if (cd.AP_Voucher_Count__c > 0) {
				for (SObjectField fieldToken : NON_UPDATE_FIELDS_IF_ASSOCIATED_WITH_AP) {
					if (TriggerObserver.getInstance().isUnlockedField(fieldToken)) {
						continue;
					}
					if (
						fieldToken == Cash_Disbursement__c.Ledger__c &&
						oldCd.get(fieldToken) == null &&
						cd.get(fieldToken) == LedgerHandler.getLegacyDefaultLedgerId()
					) {
						continue;
					}
					if (FinancialSuiteUtils.isFieldValueChanged(fieldToken, oldCd, cd)) {
						cd.addError(
							String.format(
								NON_UPDATE_FIELDS_AP_UPDATE_ERROR,
								new List<String>{
									FinancialSuiteUtils.formatFieldStrings(NON_UPDATE_FIELDS_IF_ASSOCIATED_WITH_AP)
								}
							)
						);
					}
				}
			}
		}
	}

	public static void amountToWords(Cash_Disbursement__c[] cashDisbursements) {
		for (Cash_Disbursement__c cd : cashDisbursements) {
			cd.Amount_In_Words__c = CheckUtils.toWords(cd.Amount__c);
		}
	}

	public static void updatePaymentStatus(Cash_Disbursement__c[] cashDisbursements) {
		for (Cash_Disbursement__c cd : cashDisbursements) {
			if (cd.Type__c == AS_PAY_TYPE) {
				TriggerObserver.getInstance().unlockField(Cash_Disbursement__c.Payment_Status__c);
				if (cd.Status__c == STATUS_POSTED) {
					cd.Payment_Status__c = PAYMENT_STATUS_PENDING;
				}
				if (PAYMENT_SERVICE_STATUS_RECONCILE_COMPLETE.contains(cd.Payment_Service_Status__c)) {
					cd.Payment_Status__c = STATUS_PAID;
				}
			}
		}
	}

	public static void preventDeleteIfApdExists(Cash_Disbursement__c[] cashDisbursements) {
		Set<Id> cdIds = new Map<Id, Cash_Disbursement__c>(cashDisbursements).keySet();
		Set<Id> notValidForDeleteIds = new Set<Id>();

		List<Cash_Disbursement__c> cdWithAPD = DomainUtils.getCashDisbursementByIdWithAPDs(cdIds);
		Map<Id, Id> cdByLedgers = SObjectActions.ledgerIdBySourceId(cdWithAPD);
		Map<Id, Map<String, GL_Account_Default__c>> defaults = GLAccount.glAccountDefaultsMapByLedgerId(
			new Set<Id>(cdByLedgers.values())
		);
		for (Cash_Disbursement__c cd : cdWithAPD) {
			if (
				!cd.Account_Payable_Cash_Disbursements__r.isEmpty() &&
				cd.Debit_GL_Account__c != null &&
				defaults.containsKey(cd.Ledger__c) &&
				defaults.get(cd.Ledger__c).containsKey(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT) &&
				cd.Debit_GL_Account__c !=
				defaults.get(cd.Ledger__c).get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT).GL_Account__c
			) {
				notValidForDeleteIds.add(cd.Id);
			}
		}

		for (Cash_Disbursement__c cd : cashDisbursements) {
			if (notValidForDeleteIds.contains(cd.Id)) {
				cd.addError(ATTEMPT_TO_DELETE_APPLIED_ERROR, false);
			}
		}
	}

	// Sets the account payable payment status to 'Unpaid'
	public static void deleteCashDisbursementUpdateAPStatus(SObject[] objects) {
		Map<Id, Account_Payable__c> updateMap = new Map<Id, Account_Payable__c>();
		List<Cash_Disbursement__c> cashDisburse = new List<Cash_Disbursement__c>();
		List<Cash_Disbursement_Batch__c> cashDisburseBatch = new List<Cash_Disbursement_Batch__c>();
		try {
			List<AP_Disbursement__c> apDisbursements;
			if (objects[0].getsObjectType() == Cash_Disbursement__c.sObjectType) {
				cashDisburse.addAll((Cash_Disbursement__c[]) objects);
				apDisbursements = DomainUtils.getApDisbursementsByDisbursement(
					new Map<Id, Cash_Disbursement__c>(cashDisburse).keySet()
				);
			} else if (objects[0].getsObjectType() == Cash_Disbursement_Batch__c.sObjectType) {
				cashDisburseBatch.addAll((Cash_Disbursement_Batch__c[]) objects);
				apDisbursements = DomainUtils.getApDisbursementsByDisbursementBatch(
					new Map<Id, Cash_Disbursement_Batch__c>(cashDisburseBatch).keySet()
				);
			}

			for (AP_Disbursement__c ap : apDisbursements) {
				updateMap.put(ap.Account_Payable__c, ap.Account_Payable__r);
			}

			if (!updateMap.isEmpty()) {
				SFDCSecurityUtils.updateProxy(updateMap.values());
			}
		} catch (Exception ex) {
			for (SObject obj : objects) {
				obj.addError(ex);
			}
		}
	}

	public static void validateVendorContactEmployee(Cash_Disbursement__c[] cashDisbursements) {
		for (Cash_Disbursement__c cd : cashDisbursements) {
			CashDisbursementActionWrapper cdw = new CashDisbursementActionWrapper(cd);
			if (cdw.isPayeeNull()) {
				cd.addError(REQUIRED_PAYEE_ERROR);
			} else if (cdw.isMultiplePayees()) {
				cd.addError(MULTIPLE_PAYEE_ERROR);
			}
		}
	}

	public static void setSourceAndAmountAndDebitGLAccountFields(
		Map<Id, Cash_Disbursement__c> oldCashDisbursementsMap,
		Cash_Disbursement__c[] cashDisbursements
	) {
		for (Cash_Disbursement__c cd : cashDisbursements) {
			Cash_Disbursement__c oldCd = oldCashDisbursementsMap.get(cd.Id);
			CashDisbursementActionWrapper cdw = new CashDisbursementActionWrapper(oldCd, cd);
			cdw.setSource();
			cdw.setDebitGLAccount();

			if (cdw.isSourcePayable() && cdw.isNotPosted() && cdw.isSourceOrAmountOrAppliedAmountChanged()) {
				cdw.setAmount();
				TriggerObserver.getInstance().unlockField(Cash_Disbursement__c.Amount__c);
			} else if (cdw.isSourcePayable() && cdw.isPosted() && cdw.isNotVoid() && cdw.isAppliedAmountChanged()) {
				cdw.setAmount();
				TriggerObserver.getInstance().unlockField(Cash_Disbursement__c.Amount__c);
			}
		}
	}

	public static void setDefaultFields(Cash_Disbursement__c[] cashDisbursements) {
		try {
			Map<Id, Cash_Disbursement_Batch__c> cdbMap = new Map<Id, Cash_Disbursement_Batch__c>();
			String defaultValue = FinancialSuiteUtils.getDefaultPostingStatus(Cash_Disbursement__c.Status__c);

			Id defaultLedgerId = LedgerHandler.getLedgerIdWithSharing();

			if (isMultiCurrencyEnabled) {
				cdbMap = getCashDisbursementBatches(cashDisbursements);
			}

			setLedger(defaultLedgerId, cashDisbursements);

			for (Cash_Disbursement__c cd : cashDisbursements) {
				CashDisbursementActionWrapper cdw = new CashDisbursementActionWrapper(cd);
				cdw.setBankReconciliationNull();
				cdw.setBankDisbursementNull();
				cdw.setVoidDateNull();
				cdw.setCloneFieldValues();
				cdw.setStatus(defaultValue);
				cdw.setPaymentStatus();
				cdw.setSource();
				cdw.setDebitGLAccount();
				cdw.setAmount();

				if (isMultiCurrencyEnabled) {
					String isoCode = cd.Cash_Disbursement_Batch__c != null &&
						cdbMap.containsKey(cd.Cash_Disbursement_Batch__c)
						? (String) cdbMap.get(cd.Cash_Disbursement_Batch__c).get('CurrencyIsoCode')
						: null;
					cdw.setIsoCode(isoCode);
				}
			}

			updatePaymentStatus(cashDisbursements);
		} catch (Exception ex) {
			for (Cash_Disbursement__c cd : cashDisbursements) {
				cd.addError(ex.getMessage(), false);
			}
		}
	}

	public static void validateCashDisbursementBatchHasTheSameCurrency(Cash_Disbursement__c[] cashDisbursements) {
		if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
			//get all linked Cash Disbursement Batch records with their CurrencyIsoCode queried
			Set<Id> cdBatchIds = new Set<Id>();
			for (Cash_Disbursement__c cd : cashDisbursements) {
				cdBatchIds.add(cd.Cash_Disbursement_Batch__c);
			}

			Map<Id, Cash_Disbursement_Batch__c> cdBatchMap = new Map<Id, Cash_Disbursement_Batch__c>(
				DomainUtils.getCashDisbursementBatchById(cdBatchIds, true)
			);

			//go through list of new records and validate that Currencies for each Master-Detail pair are the same
			for (Cash_Disbursement__c cd : cashDisbursements) {
				if (cd.get('CurrencyIsoCode') != cdBatchMap.get(cd.Cash_Disbursement_Batch__c).get('CurrencyIsoCode')) {
					cd.Cash_Disbursement_Batch__c.addError(NOT_EQUAL_CURRENCY_ERROR);
				}
			}
		}
	}

	public static void associateWithCashFlowCategory(List<Cash_Disbursement__c> newCashDisbursements) {
		for (Cash_Disbursement__c cd : newCashDisbursements) {
			Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(
				cd.Ledger__c
			);
			cd.Cash_Flow_Category__c = defaultsBySpecDevNames.get(
					GLAccountDefaultsHandler.DEFAULT_CASH_DISBURSEMENT_CATEGORY
				)
				?.GL_Account__c;
		}
	}

	public static String getDefaultTypePicklistValue() {
		String result = 'Check';
		for (Schema.PicklistEntry pickListEntry : Cash_Disbursement__c.Type__c.getDescribe().getPicklistValues()) {
			if (pickListEntry.isDefaultValue()) {
				result = pickListEntry.getValue();
				break;
			}
		}
		return result;
	}

	public static void updateLegacyVoidedDateField(
		Map<Id, Cash_Disbursement__c> oldCashDisbursementMap,
		Map<Id, Cash_Disbursement__c> newCashDisbursementMap
	) {
		for (Cash_Disbursement__c cd : newCashDisbursementMap.values()) {
			Cash_Disbursement__c oldCd = oldCashDisbursementMap.get(cd.Id);
			if (
				isUpdateVoidedDate(cd, oldCd) &&
				AccountingPeriodHandler.getInstance().getAccountingPeriodById(cd.Accounting_Period__c).Start_Date__c <
				cd.Void_Date__c
			) {
				TriggerObserver.getInstance().unlockField(Cash_Disbursement__c.Void_Date__c);
			}
		}
	}

	public static void set1099Fields(Cash_Disbursement__c[] cashDisbursements) {
		Set<Id> accountIds = new Set<Id>();
		Set<Id> contactIds = new Set<Id>();
		Set<String> formTypes = new Set<String>();
		Set<Integer> disbursementYears = new Set<Integer>();
		Map<String, Integer> effectiveYearByCDYearAndType = new Map<String, Integer>();

		Map<Id, Form_Category__mdt> formCategoriesMap = X1099InfoHelper.getFormCategoriesMap();

		for (Form_Category__mdt category : formCategoriesMap.values()) {
			formTypes.add(category.Form_Type__r.Type__c);
		}

		for (Cash_Disbursement__c cd : cashDisbursements) {
			if (cd.Vendor__c != null) {
				accountIds.add(cd.Vendor__c);
				disbursementYears.add(cd.Disbursement_Date__c.Year());
			}
			if (cd.Contact__c != null) {
				contactIds.add(cd.Contact__c);
				disbursementYears.add(cd.Disbursement_Date__c.Year());
			}
		}

		//yes, this is a bad pattern, but you cannot do aggregate queries against custom metadata types
		for (String type : formTypes) {
			for (Integer year : disbursementYears) {
				Integer effectiveYear = X1099InfoHelper.getMaxEffectiveYearForTypeAndYear(type, year);
				effectiveYearByCDYearAndType.put(year + '-' + type, effectiveYear);
			}
		}

		Map<Id, X1099Data> default1099ValuesByVendor = new Map<Id, X1099Data>();
		for (Account a : getAccount1099Info(accountIds)) {
			if (!String.isEmpty(a.Default_Form_Category_Id__c)) {
				X1099Data data = new X1099Data();
				data.Default1099CategoryId = a.Default_Form_Category_Id__c;
				data.Default1099Box = a.Default_Form_1099_Box__c;
				default1099ValuesByVendor.put(a.Id, data);
			}
		}

		for (Contact c : getContact1099Info(contactIds)) {
			if (!String.isEmpty(c.Default_Form_Category_Id__c)) {
				X1099Data data = new X1099Data();
				data.Default1099CategoryId = c.Default_Form_Category_Id__c;
				data.Default1099Box = c.Default_Form_1099_Box__c;
				default1099ValuesByVendor.put(c.Id, data);
			}
		}

		for (Cash_Disbursement__c cd : cashDisbursements) {
			if (cd.Vendor__c != null && default1099ValuesByVendor.containsKey(cd.Vendor__c)) {
				Form_Category__mdt formCategory = formCategoriesMap.get(
					default1099ValuesByVendor.get(cd.Vendor__c).Default1099CategoryId
				);
				if (
					effectiveYearByCDYearAndType.get(
						cd.Disbursement_Date__c.Year() + '-' + formCategory.Form_Type__r.Type__c
					) == (Integer) formCategory.Form_TYpe__r.Effective_Year__c
				) {
					cd.Form_Category_Id__c = default1099ValuesByVendor.get(cd.Vendor__c).Default1099CategoryId;
					cd.Form_1099_Box__c = default1099ValuesByVendor.get(cd.Vendor__c).Default1099Box;
				}
			} else if (cd.Contact__c != null && default1099ValuesByVendor.containsKey(cd.Contact__c)) {
				Form_Category__mdt formCategory = formCategoriesMap.get(
					default1099ValuesByVendor.get(cd.Contact__c).Default1099CategoryId
				);
				if (
					effectiveYearByCDYearAndType.get(
						cd.Disbursement_Date__c.Year() + '-' + formCategory.Form_Type__r.Type__c
					) == (Integer) formCategory.Form_TYpe__r.Effective_Year__c
				) {
					cd.Form_Category_Id__c = default1099ValuesByVendor.get(cd.Contact__c).Default1099CategoryId;
					cd.Form_1099_Box__c = default1099ValuesByVendor.get(cd.Contact__c).Default1099Box;
				}
			}
		}
	}

	public static void validate1099Info(List<Cash_Disbursement__c> newCDs, Map<Id, Cash_Disbursement__c> oldCDs) {
		// gather changes
		List<Cash_Disbursement__c> changes = new List<Cash_Disbursement__c>();
		List<Id> categoryIds = new List<Id>();
		for (Cash_Disbursement__c cd : newCDs) {
			if (
				cd.Disbursement_Date__c != null &&
				cd.Form_Category_Id__c != null &&
				(cd.Form_Category_Id__c != oldCDs.get(cd.Id).Form_Category_Id__c ||
				cd.Disbursement_Date__c != oldCDs.get(cd.Id).Disbursement_Date__c)
			) {
				categoryIds.add(cd.Form_Category_Id__c);
				changes.add(cd);
			}
		}

		List<Form_Category__mdt> mdts = DomainUtils.getFormCategoriesByIds(categoryIds);
		Map<Id, Form_Category__mdt> categories = new Map<Id, Form_Category__mdt>(mdts);

		List<Form_Type__mdt> formMdts = DomainUtils.getFormTypesOrderByTypeYearASC(null);

		// create buckets by form type
		Map<String, List<Form_Type__mdt>> formsByType = new Map<String, List<Form_Type__mdt>>();
		for (Form_Type__mdt formMdt : formMdts) {
			if (formsByType.get(formMdt.Type__c) == null) {
				formsByType.put(formMdt.Type__c, new List<Form_Type__mdt>());
			}
			formsByType.get(formMdt.Type__c).add(formMdt);
		}
		// build end date lookup
		Map<Id, Integer> nextEffYearByFormId = new Map<Id, Integer>();
		for (List<Form_Type__mdt> formTypes : formsByType.values()) {
			for (Integer i = 0; i < formTypes.size(); i++) {
				if (i == formTypes.size() - 1) {
					nextEffYearByFormId.put(formTypes[i].Id, 999999);
				} else {
					nextEffYearByFormId.put(formTypes[i].Id, Integer.valueOf(formTypes[i + 1].Effective_Year__c));
				}
			}
		}

		// check CDs are in correct effective year range
		for (Cash_Disbursement__c change : changes) {
			// check lower bound
			if (
				change.Disbursement_Date__c.year() <
				categories.get(change.Form_Category_Id__c).Form_Type__r.Effective_Year__c
			) {
				change.addError(
					String.format(INVALID_1099_INFO, new List<String>{ change.Disbursement_Date__c.format() })
				);
			}
			// check upper bound
			else if (
				change.Disbursement_Date__c.year() >=
				nextEffYearByFormId.get(categories.get(change.Form_Category_Id__c).Form_Type__r.Id)
			) {
				change.addError(
					String.format(INVALID_1099_INFO, new List<String>{ change.Disbursement_Date__c.format() })
				);
			}
		}
	}

	private static List<Account> getAccount1099Info(Set<Id> accountIds) {
		List<String> queryFields = new List<String>{ 'Id', 'Default_Form_Category_Id__c', 'Default_Form_1099_Box__c' };

		String queryCondition = 'Id IN :accountIds AND X1099_Vendor__c = true';

		SOQLBuilder theQuery = new SOQLBuilder(Account.getSObjectType());
		theQuery.assertIsAccessible().selectFields(queryFields).setCondition(queryCondition);

		List<Account> resultList = Database.query(theQuery.toSOQL());
		return resultList;
	}

	private static List<Contact> getContact1099Info(Set<Id> contactIds) {
		List<String> queryFields = new List<String>{ 'Id', 'Default_Form_Category_Id__c', 'Default_Form_1099_Box__c' };

		String queryCondition = 'Id IN :contactIds AND X1099_Vendor__c = true';

		SOQLBuilder theQuery = new SOQLBuilder(Contact.getSObjectType());
		theQuery.assertIsAccessible().selectFields(queryFields).setCondition(queryCondition);

		List<Contact> resultList = Database.query(theQuery.toSOQL());
		return resultList;
	}

	private static void setLedger(Id defaultLedgerId, List<Cash_Disbursement__c> cashDisbursements) {
		for (Cash_Disbursement__c cd : cashDisbursements) {
			SObjectActions.populateLedgerField(cd, defaultLedgerId);
			SObjectActions.validateLedgerType(cashDisbursements);
		}
	}

	private class X1099Data {
		String Default1099CategoryId { get; set; }
		String Default1099Box { get; set; }
	}

	private static Boolean isUpdateVoidedDate(Cash_Disbursement__c newCd, Cash_Disbursement__c oldCd) {
		return newCd.Payment_Status__c == 'Void' &&
			oldCd.Void_Date__c != newCd.Void_Date__c &&
			oldCd.Void_Date__c == null;
	}

	private static Map<Id, Cash_Disbursement_Batch__c> getCashDisbursementBatches(
		List<Cash_Disbursement__c> cashDisbursements
	) {
		Set<Id> cdBatchIds = new Set<Id>();
		for (Cash_Disbursement__c cd : cashDisbursements) {
			if (cd.Cash_Disbursement_Batch__c != null) {
				cdBatchIds.add(cd.Cash_Disbursement_Batch__c);
			}
		}

		return DomainUtils.getCashDisbursementBatchMapById(cdBatchIds, isMultiCurrencyEnabled);
	}

	public class CashDisbursementActionWrapper {
		public Cash_Disbursement__c cd;
		public Cash_Disbursement__c oldCd;

		public CashDisbursementActionWrapper(Cash_Disbursement__c cd) {
			this.cd = cd;
		}

		public CashDisbursementActionWrapper(Cash_Disbursement__c oldCd, Cash_Disbursement__c cd) {
			this.oldCd = oldCd;
			this.cd = cd;
		}

		public Boolean isSourcePayable() {
			Boolean retVal = false;
			if (isSourcedFromPayables || (cd.Source__c == 'Payable' || cd.Source__c == 'Account Payable')) {
				retVal = true;
			}
			return retVal;
		}

		public Boolean isPayeeNull() {
			return cd.Vendor__c == null && cd.Contact__c == null && cd.Employee__c == null;
		}

		public Boolean isMultiplePayees() {
			return ((cd.Vendor__c != null && (cd.Contact__c != null || cd.Employee__c != null)) ||
			(cd.Contact__c != null && (cd.Vendor__c != null || cd.Employee__c != null)) ||
			(cd.Employee__c != null && (cd.Vendor__c != null || cd.Contact__c != null)));
		}

		public Boolean isSourceManual() {
			return cd.Source__c == 'Manual';
		}

		public Boolean isPosted() {
			return cd.Status__c == 'Posted';
		}

		public Boolean isNotVoid() {
			return cd.Payment_Status__c != 'Void';
		}

		public Boolean isSourceChanged() {
			return isInsert() || (isUpdate() && oldCd.Source__c != cd.Source__c);
		}

		public Boolean isAmountChanged() {
			return isInsert() || (isUpdate() && oldCd.Amount__c != cd.Amount__c);
		}

		public Boolean isSourceOrAmountOrAppliedAmountChanged() {
			return isSourceChanged() || isAmountChanged() || isAppliedAmountChanged();
		}

		public Boolean isDebitGLAccountChanged() {
			return isInsert() || (isUpdate() && oldCd.Debit_GL_Account__c != cd.Debit_GL_Account__c);
		}

		public Boolean isSourceOrDebitGLAccountChanged() {
			return isSourceChanged() || isDebitGLAccountChanged();
		}

		public Boolean isNotPosted() {
			return cd.Status__c != 'Posted';
		}

		public Boolean isAPDCountZero() {
			return cd.AP_Voucher_Count__c == 0;
		}

		public Boolean isDebitGLAccountNull() {
			return cd.Debit_GL_Account__c == null;
		}

		public Boolean isDebitGLAccountEqualAPControlAccount() {
			Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(
				cd.Ledger__c
			);
			return isDebitGLAccountNull() ||
				cd.Debit_GL_Account__c ==
				defaultsBySpecDevNames?.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;
		}

		public void setPaymentStatus() {
			if (cd.Type__c == AS_PAY_TYPE) {
				cd.Payment_Status__c = STATUS_IN_PROCESS;
			} else {
				cd.Payment_Status__c = STATUS_PAID;
			}
		}

		public void setAmount() {
			cd.Amount__c = isSourcePayable() ? cd.Applied_Amount__c : cd.Amount__c;
		}

		public Boolean isAppliedAmountChanged() {
			return isInsert() || (isUpdate() && oldCd.Applied_Amount__c != cd.Applied_Amount__c);
		}

		public void setStatus(String defaultValue) {
			cd.Status__c = (((cd.Status__c == null || SObjectActions.isPostedStatus(cd)) &&
				String.isNotBlank(defaultValue))
				? defaultValue
				: cd.Status__c);
		}

		public void setSource() {
			cd.Source__c = (isNotValidSourceFieldValue() && isNotPosted() && isAPDCountZero()) ||
				(cd.isClone() && !isSourcedFromPayables)
				? 'Manual'
				: cd.Source__c;
		}

		public void setDebitGLAccount() {
			Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(
				cd.Ledger__c
			);

			if (
				isSourceManual() &&
				isSourceChanged() &&
				isNotPosted() &&
				isAPDCountZero() &&
				(isDebitGLAccountEqualAPControlAccount() || cd.Debit_GL_Account__c == null) &&
				!LedgerHandler.getInstanceWithoutSharing().isCashLedger(cd.Ledger__c)
			) {
				if (
					defaultsBySpecDevNames.get(GLAccountDefaultsHandler.PREPAID_EXPENSE_GL_ACCOUNT)?.GL_Account__c !=
					null
				) {
					cd.Debit_GL_Account__c = defaultsBySpecDevNames.get(
							GLAccountDefaultsHandler.PREPAID_EXPENSE_GL_ACCOUNT
						)
						?.GL_Account__c;
				} else {
					cd.Debit_GL_Account__c.addError(
						String.format(
							Label.ERR_DEFAULT_PREPAID_EXPENSE_GL_ACCOUNT_REQUIRED,
							new List<String>{ Label.COMMON_CASH_DISBURSEMENT }
						)
					);
				}
			} else if (
				isSourcePayable() &&
				isSourceOrDebitGLAccountChanged() &&
				isNotPosted() &&
				isAPDCountZero() &&
				!LedgerHandler.getInstanceWithoutSharing().isCashLedger(cd.Ledger__c)
			) {
				if (defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c != null) {
					cd.Debit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)
						?.GL_Account__c;
				} else {
					cd.Debit_GL_Account__c.addError(
						String.format(
							Label.ERR_DEFAULT_GL_ACCOUNT_REQUIRED,
							new List<String>{ Label.COMMON_CASH_DISBURSEMENT }
						)
					);
				}
			} else if (
				LedgerHandler.getInstanceWithoutSharing().isCashLedger(cd.Ledger__c) &&
				isAPDCountZero() &&
				isNotPosted() &&
				isSourceOrDebitGLAccountChanged() &&
				cd.Debit_GL_Account__c == null
			) {
				if (
					defaultsBySpecDevNames.get(GLAccountDefaultsHandler.UNAPPLIED_EXPENSE_GL_ACCOUNT)?.GL_Account__c !=
					null
				) {
					cd.Debit_GL_Account__c = defaultsBySpecDevNames.get(
							GLAccountDefaultsHandler.UNAPPLIED_EXPENSE_GL_ACCOUNT
						)
						?.GL_Account__c;
				} else {
					cd.Debit_GL_Account__c.addError(Label.ERR_UNAPPLIED_EXPENSE_DEFAULT_GL_ACCOUNT_REQUIRED);
				}
			} else if (
				LedgerHandler.getInstanceWithoutSharing().isAccrualAndCashLedger(cd.Ledger__c) &&
				isAPDCountZero() &&
				isNotPosted() &&
				isSourceOrDebitGLAccountChanged() &&
				cd.Debit_GL_Account__c == null
			) {
				Map<String, GL_Account_Default__c> shadowDefaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(
					LedgerHandler.getInstanceWithoutSharing().getShadowLedgerByParent(cd.Ledger__c).Id
				);
				if (
					shadowDefaultsBySpecDevNames.get(GLAccountDefaultsHandler.UNAPPLIED_EXPENSE_GL_ACCOUNT)
						?.GL_Account__c != null
				) {
					cd.Debit_GL_Account__c = shadowDefaultsBySpecDevNames.get(
							GLAccountDefaultsHandler.UNAPPLIED_EXPENSE_GL_ACCOUNT
						)
						?.GL_Account__c;
				} else {
					cd.Debit_GL_Account__c.addError(Label.ERR_UNAPPLIED_EXPENSE_DEFAULT_GL_ACCOUNT_REQUIRED);
				}
			}
		}

		public void setBankReconciliationNull() {
			cd.Bank_Reconciliation__c = null;
		}

		public void setBankDisbursementNull() {
			cd.Bank_Disbursement__c = null;
		}

		public void setVoidDateNull() {
			cd.Void_Date__c = null;
		}

		public Boolean isUpdateVoidedDate() {
			return isUpdate() &&
				cd.Payment_Status__c == 'Void' &&
				oldCd.Void_Date__c != cd.Void_Date__c &&
				oldCd.Void_Date__c == null;
		}

		private Boolean isVoidDateLessThanPeriodStartDate() {
			return AccountingPeriodHandler.getInstance()
					.getAccountingPeriodById(cd.Accounting_Period__c)
					.Start_Date__c < cd.Void_Date__c;
		}

		public void setCloneFieldValues() {
			if (cd.isClone()) {
				cd.Cleared_Date__c = null;
			}
		}

		public void setIsoCode(String isoCode) {
			if (isMultiCurrencyEnabled) {
				cd.put('CurrencyIsoCode', isoCode);
			}
		}

		public Boolean isNotValidSourceFieldValue() {
			Boolean retVal = true;
			if (cd.Source__c != null && (isSourcePayable() || isSourceManual())) {
				retVal = false;
			}
			return retVal;
		}

		public Boolean isInsert() {
			return oldCd == null;
		}

		public Boolean isUpdate() {
			return oldCd != null;
		}
	}

	public static void checkFeatureParameterFieldLevelAccessInsert() {
		AccessControlService controlService = new AccessControlService(
			new APAutomationControl(),
			Cash_Disbursement__c.SObjectType
		);
		controlService.checkInsertFieldGrants();
	}

	public static void checkFeatureParameterFieldLevelAccessUpdate() {
		AccessControlService controlService = new AccessControlService(
			new APAutomationControl(),
			Cash_Disbursement__c.SObjectType
		);
		controlService.checkUpdateFieldGrants();
	}

	public static void PaymentServicesValidation(
		List<Cash_Disbursement__c> updatedCDs,
		Map<Id, Cash_Disbursement__c> oldCDMap
	) {
		for (Cash_Disbursement__c cd : updatedCDs) {
			Cash_Disbursement__c oldCd = oldCDMap.get(cd.Id);

			if (
				cd.Payment_Service_Status__c != null &&
				!String.isEmpty(cd.Payment_Service_Status__c) &&
				(cd.Type__c != oldCd.Type__c ||
				(cd.Payment_Method__c != oldCd.Payment_Method__c &&
				cd.AS_Pay_Type__c == 'ACH') ||
				cd.AS_Pay_Type__c != oldCd.AS_Pay_Type__c ||
				cd.Amount__c != oldCd.Amount__c ||
				cd.Disbursement_Date__c != oldCd.Disbursement_Date__c ||
				cd.Vendor__c != oldCd.Vendor__c ||
				cd.Payee_City__c != oldCd.Payee_City__c ||
				cd.Payee_Street__c != oldCd.Payee_Street__c ||
				cd.Payee_Postal_Code__c != oldCd.Payee_Postal_Code__c ||
				cd.Payee_Country__c != oldCd.Payee_Country__c)
			) {
				cd.addError(PAYMENT_SERVICES_ALREADY_SUBMITTED, false);
			}
		}
	}

	public static void validateVoid(List<Cash_Disbursement__c> cashDisbursements) {
		//https://api.docs.globalvcard.com/reference/payment-lifecycle
		Set<Id> voidCDs = new Set<Id>();
		for (Cash_Disbursement__c cd : cashDisbursements) {
			if (cd.Payment_Status__c == STATUS_VOID && cd.Type__c == AS_PAY_TYPE) {
				voidCDs.add(cd.Id);
			}
		}
		if (voidCDs.size() == 0) {
			return;
		}
		List<String> queryFields = new List<String>{ 'Id', 'Current_Balance__c', 'Available_Balance__c', 'Status__c' };
		String queryCondition = 'Id IN (SELECT Payment_Method__c FROM Cash_Disbursement__c WHERE Id IN :voidCDs)';
		SOQLBuilder theQuery = new SOQLBuilder(Payment_Method__c.getSObjectType());
		theQuery.assertIsAccessible().selectFields(queryFields).setCondition(queryCondition).setLimit(50000);
		Map<Id, Payment_Method__c> mPMs = new Map<Id, Payment_Method__c>(
			(List<Payment_Method__c>) Database.query(theQuery.toSOQL())
		);

		List<String> ASPayStatuses = new List<String>{
			'canceled',
			'cancelled',
			'publish_cancelled',
			'reconcile_declined',
			'reconcile_cancelled'
		};
		for (Cash_Disbursement__c cd : cashDisbursements) {
			Payment_Method__c iPM = mPMs.get(cd.Payment_Method__c);
			if (cd.Payment_Status__c == STATUS_VOID && cd.Type__c == AS_PAY_TYPE) {
				//add error for virtual card if the CD is in one of the following statuses where the PM would not have been created yet
				if (
					(ASPayStatuses.contains(cd.Payment_Service_Status__c?.toLowerCase()) ||
					cd.Payment_Service_Status__c?.toLowerCase() == 'pending') && cd.AS_Pay_Type__c == VCARD_TYPE
				) {
					cd.Payment_Status__c.addError(Label.ERR_CD_VCARD_VOID);
				}

				//add error for virtual card that is zero balance, they can not be voided in edenred
				if (cd.AS_Pay_Type__c == VCARD_TYPE && iPM.Current_Balance__c > 0 && iPM.Available_Balance__c == 0) {
					cd.Payment_Status__c.addError(Label.ERR_CD_CARD_VOID);
				}

				//add error for ACH when status is not one of the defined ones meaning the payment has already been sent
				if (
					cd.AS_Pay_Type__c == ACH_TYPE &&
					!ASPayStatuses.contains(cd.Payment_Service_Status__c?.toLowerCase())
				) {
					cd.Payment_Status__c.addError(Label.ERR_CD_ACH_VOID);
				}
			}
		}
	}

	public static void validateBankDisbursementRelatedFields(List<Cash_Disbursement__c> listOfNewCDs) {
		Set<Id> setOfBankDisbIds = new Set<Id>();
		List<Cash_Disbursement__c> listOfCDsToValidate = new List<Cash_Disbursement__c>();

		for (Cash_Disbursement__c cd : listOfNewCDs) {
			if (cd.Bank_Disbursement__c != null) {
				setOfBankDisbIds.add(cd.Bank_Disbursement__c);
				listOfCDsToValidate.add(cd);
			}
		}

		if (!setOfBankDisbIds.isEmpty()) {
			Map<Id, Bank_Disbursement__c> mapOfIdAndBankDisbursements = DomainUtils.getBankDisbursements(
				setOfBankDisbIds
			);
			if (!mapOfIdAndBankDisbursements.isEmpty()) {
				for (Cash_Disbursement__c cashDisbRec : listOfCDsToValidate) {
					validateBankAccount(cashDisbRec, mapOfIdAndBankDisbursements);
					validateDisbursementDate(cashDisbRec, mapOfIdAndBankDisbursements);
					if (isMultiCurrencyEnabled) {
						validateBankDisbursementHasTheSameCurrency(cashDisbRec, mapOfIdAndBankDisbursements);
					}
				}
			}
		}
	}

	public static void validateIfRecordPostedBeforeAssociating(
		List<Cash_Disbursement__c> listOfNewCDs,
		Map<Id, Cash_Disbursement__c> oldCashDisbMap
	) {
		for (Cash_Disbursement__c cd : listOfNewCDs) {
			if (
				((oldCashDisbMap == null && cd.Bank_Disbursement__c != null) ||
				(oldCashDisbMap != null &&
				(cd.Bank_Disbursement__c != oldCashDisbMap.get(cd.Id).Bank_Disbursement__c))) &&
				cd.Status__c != 'Posted'
			) {
				cd.Bank_Disbursement__c.addError(
					String.format(
						Label.ERR_ASSOCIATING_BD_IF_RECORD_IS_NOT_POSTED,
						new List<String>{ Label.COMMON_CASH_DISBURSEMENT }
					)
				);
			}
		}
	}

	public static void validateBankAccount(
		Cash_Disbursement__c cashDisbRec,
		Map<Id, Bank_Disbursement__c> mapOfIdAndBankDisbursements
	) {
		if (
			cashDisbRec.Bank_Account__c != null &&
			mapOfIdAndBankDisbursements.containsKey(cashDisbRec.Bank_Disbursement__c) &&
			mapOfIdAndBankDisbursements.get(cashDisbRec.Bank_Disbursement__c).Bank_GL_Account__c != null &&
			cashDisbRec.Bank_Account__c !=
			mapOfIdAndBankDisbursements.get(cashDisbRec.Bank_Disbursement__c).Bank_GL_Account__c
		) {
			cashDisbRec.Bank_Disbursement__c.addError(
				Label.ERR_PREVENT_ASSOCIATING_RECORD_IF_BANK_ACCOUNT_DOESNT_MATCH_ON_BD
			);
		}
	}

	public static void validateDisbursementDate(
		Cash_Disbursement__c cashDisbRec,
		Map<Id, Bank_Disbursement__c> mapOfIdAndBankDisbursements
	) {
		if (
			mapOfIdAndBankDisbursements.containsKey(cashDisbRec.Bank_Disbursement__c) &&
			mapOfIdAndBankDisbursements.get(cashDisbRec.Bank_Disbursement__c).Disbursement_Date__c != null &&
			cashDisbRec.Disbursement_Date__c >
			mapOfIdAndBankDisbursements.get(cashDisbRec.Bank_Disbursement__c).Disbursement_Date__c
		) {
			cashDisbRec.Bank_Disbursement__c.addError(
				Label.ERR_PREVENT_ASSOCIATING_RECORD_IF_DATE_EXCEEDS_DISBURSEMENT_DATE_ON_BD
			);
		}
	}

	public static void validateBankDisbursementHasTheSameCurrency(
		Cash_Disbursement__c cashDisbRec,
		Map<Id, Bank_Disbursement__c> mapOfIdAndBankDisbursements
	) {
		if (
			mapOfIdAndBankDisbursements.containsKey(cashDisbRec.Bank_Disbursement__c) &&
			cashDisbRec.get('CurrencyIsoCode') !=
			mapOfIdAndBankDisbursements.get(cashDisbRec.Bank_Disbursement__c).get('CurrencyIsoCode')
		) {
			cashDisbRec.Bank_Disbursement__c.addError(Label.ERR_CASH_DISBURSEMENT_CURRENCY_MISMATCH_BANK_DISB);
		}
	}

	public static void preventBankDisbUpdateIfBankRecCleared(
		List<Cash_Disbursement__c> listOfNewCDs,
		Map<Id, Cash_Disbursement__c> oldCDMap
	) {
		Set<Id> setOfBankRecIds = new Set<Id>();
		Set<Id> setOfBankDisbIds = new Set<Id>();
		Map<Id, Bank_Reconciliation2__c> mapOfIdAndBankRec = new Map<Id, Bank_Reconciliation2__c>();
		Map<Id, Bank_Disbursement__c> mapOfIdAndBankDisbursements = new Map<Id, Bank_Disbursement__c>();
		List<Cash_Disbursement__c> listOfCDsToProcess = new List<Cash_Disbursement__c>();

		for (Cash_Disbursement__c cashDisbRec : listOfNewCDs) {
			if (cashDisbRec.Bank_Disbursement__c != oldCDMap.get(cashDisbRec.Id).Bank_Disbursement__c) {
				if (cashDisbRec.Bank_Reconciliation__c != null) {
					setOfBankRecIds.add(cashDisbRec.Bank_Reconciliation__c);
				}
				if (oldCDMap.get(cashDisbRec.Id).Bank_Disbursement__c != null) {
					setOfBankDisbIds.add(oldCDMap.get(cashDisbRec.Id).Bank_Disbursement__c);
				}
				if (cashDisbRec.Bank_Disbursement__c != null) {
					setOfBankDisbIds.add(cashDisbRec.Bank_Disbursement__c);
				}
				listOfCDsToProcess.add(cashDisbRec);
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

		for (Cash_Disbursement__c cashDisbRec : listOfCDsToProcess) {
			if (cashDisbRec.Bank_Reconciliation__c != null) {
				cashDisbRec.Bank_Disbursement__c.addError(
					String.format(
						Label.ERR_PREVENT_ASSOCIATING_RECORD_IF_BANK_RECONCILIATION_CLEARED,
						new List<String>{
							Label.COMMON_CASH_DISBURSEMENT,
							mapOfIdAndBankRec.get(cashDisbRec.Bank_Reconciliation__c).Name,
							Label.COMMON_CASH_DISBURSEMENT
						}
					)
				);
			} else if (
				(oldCDMap.get(cashDisbRec.Id).Bank_Disbursement__c != null &&
				mapOfIdAndBankDisbursements.containsKey(oldCDMap.get(cashDisbRec.Id).Bank_Disbursement__c) &&
				mapOfIdAndBankDisbursements.get(oldCDMap.get(cashDisbRec.Id).Bank_Disbursement__c)
					.Bank_Reconciliation__c != null)
			) {
				Bank_Reconciliation2__c bankReconciliationRec = mapOfIdAndBankRec.get(
					mapOfIdAndBankDisbursements.get(oldCDMap.get(cashDisbRec.Id).Bank_Disbursement__c)
						.Bank_Reconciliation__c
				);
				cashDisbRec.Bank_Disbursement__c.addError(
					String.format(
						Label.ERR_PREVENT_ASSOCIATING_RECORD_IF_BANK_RECONCILIATION_CLEARED,
						new List<String>{
							Label.COMMON_BANK_DISBURSEMENT,
							bankReconciliationRec.Name,
							Label.COMMON_BANK_DISBURSEMENT
						}
					)
				);
			} else if (
				(cashDisbRec.Bank_Disbursement__c != null &&
				mapOfIdAndBankDisbursements.containsKey(cashDisbRec.Bank_Disbursement__c) &&
				mapOfIdAndBankDisbursements.get(cashDisbRec.Bank_Disbursement__c).Bank_Reconciliation__c != null)
			) {
				Bank_Reconciliation2__c bankReconciliationRec = mapOfIdAndBankRec.get(
					mapOfIdAndBankDisbursements.get(cashDisbRec.Bank_Disbursement__c).Bank_Reconciliation__c
				);
				cashDisbRec.Bank_Disbursement__c.addError(
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
		List<Cash_Disbursement__c> listOfNewCDs,
		Map<Id, Cash_Disbursement__c> oldCDMap
	) {
		Set<Id> listOfBankDisbIds = new Set<Id>();

		if (listOfNewCDs != null) {
			for (Cash_Disbursement__c cashDisbRec : listOfNewCDs) {
				if (cashDisbRec.Bank_Disbursement__c != null) {
					if (
						oldCDMap != null &&
						oldCDMap.containsKey(cashDisbRec.Id) &&
						(cashDisbRec.Amount__c != oldCDMap.get(cashDisbRec.Id).Amount__c ||
						cashDisbRec.Ledger_Amount__c != oldCDMap.get(cashDisbRec.Id).Ledger_Amount__c ||
						cashDisbRec.Bank_Disbursement__c != oldCDMap.get(cashDisbRec.Id).Bank_Disbursement__c)
					) {
						listOfBankDisbIds.add(cashDisbRec.Bank_Disbursement__c);
					} else {
						listOfBankDisbIds.add(cashDisbRec.Bank_Disbursement__c);
					}
				}
			}
		}

		if (oldCDMap != null) {
			for (Cash_Disbursement__c cashDisbRec : oldCDMap.values()) {
				if (cashDisbRec.Bank_Disbursement__c != null) {
					listOfBankDisbIds.add(cashDisbRec.Bank_Disbursement__c);
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

	public static void preventBDBAssociationIfDifferentGLV(List<Cash_Disbursement__c> newCashDisbursementRecords) {
		Set<Id> bankDisbursementIds = new Set<Id>();
		for (Cash_Disbursement__c cashDisbRecord : newCashDisbursementRecords) {
			if (cashDisbRecord.Bank_Disbursement__c != Null) {
				bankDisbursementIds.add(cashDisbRecord.Bank_Disbursement__c);
			}
		}
	
		if (!bankDisbursementIds.isEmpty()) {
			Map<Id, Bank_Disbursement__c> bankDisbursementMap = DomainUtils.getBankDisbursements(bankDisbursementIds);
			for (Cash_Disbursement__c cashDisbRecord : newCashDisbursementRecords) {
				if (
					cashDisbRecord.Bank_Disbursement__c != Null &&
					bankDisbursementMap.containsKey(cashDisbRecord.Bank_Disbursement__c)
				) {
					Boolean isGlVDifferent = false;
					Bank_Disbursement__c bankDisbursement = bankDisbursementMap.get(
						cashDisbRecord.Bank_Disbursement__c
					);
					if (
						isGlVariableDifferent(
							bankDisbursement.GL_Account_Variable_1__c,
							cashDisbRecord.GL_Account_Variable_1__c
						)
					) {
						isGlVDifferent = true;
					} else if (
						isGlVariableDifferent(
							bankDisbursement.GL_Account_Variable_2__c,
							cashDisbRecord.GL_Account_Variable_2__c
						)
					) {
						isGlVDifferent = true;
					} else if (
						isGlVariableDifferent(
							bankDisbursement.GL_Account_Variable_3__c,
							cashDisbRecord.GL_Account_Variable_3__c
						)
					) {
						isGlVDifferent = true;
					} else if (
						isGlVariableDifferent(
							bankDisbursement.GL_Account_Variable_4__c,
							cashDisbRecord.GL_Account_Variable_4__c
						)
					) {}
						isGlVDifferent = true;
					}

					// Add error if any of Gl variable is different
					if (isGlVDifferent) {
						cashDisbRecord.addError(
							String.format(
								CASH_DISBURSEMENT_CANT_BE_ASSOCIATED_TO_BDB_IF_DIFFERENT_GLV,
								new List<String>{ bankDisbursement.Name }
							)
						);
					}
				}
			}
		}
	}

	public static Boolean isGlVariableDifferent(String bankDisbGLVariable, String cashDisbGLVariable) {
		return (String.isNotBlank(bankDisbGLVariable) &&
		String.isNotBlank(cashDisbGLVariable) &&
		bankDisbGLVariable != cashDisbGLVariable);
	}
}
