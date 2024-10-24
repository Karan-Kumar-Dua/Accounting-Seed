public with sharing class BankDepositManagerLWC {
    public class CustomException extends Exception{}
    private static final String JOURNAL_ENTRY_LINE_TYPE_LABEL = Label.COMMON_JOURNAL_ENTRY_LINE;
	private static final String CASH_RECEIPT_LABEL =  Label.COMMON_CASH_RECEIPT;
	private static final String ANY_TYPE_LABEL = Label.COMMON_ALL;
    private static final String CASH_RECEIPT_TYPE = 'Cash Receipt';
    private static final String CREDIT_JOURNAL_ENTRY_LINE_TYPE = 'Credit Journal';
    private static final String DEBIT_JOURNAL_ENTRY_LINE_TYPE = 'Debit Journal';
    
    @AuraEnabled
    public static List<ResultRecordsWrapper> getCashReceiptNdJEL(String bankDepositId, String filtersObj, String currentTab){
        try{
            List<ResultRecordsWrapper> results = new List<ResultRecordsWrapper>();
            if(String.isNotBlank(bankDepositId)){
                FiltersWrapper filterWrap = (FiltersWrapper) JSON.deserialize(filtersObj,FiltersWrapper.class);
                List<Bank_Deposit__c> bankDepositRecords = ((List<Bank_Deposit__c>) queryBankDepositRecord(bankDepositId));
                
                if(!bankDepositRecords.isEmpty()){
                    List<SObject> listOfRecords = new List<SObject>();
                    if(bankDepositRecords[0].Bank_Reconciliation__c != NULL){
                        String bankDepositWithBankReconciliationError = String.format(Label.ERR_BANK_DEPOSIT_ASSOCIATED_BR_FIRST_UNCLEAR_BD, 
                                                                        new List<Object>{bankDepositRecords[0].Bank_Reconciliation__c, bankDepositRecords[0].Bank_Reconciliation__r.Name});
    
                        throw new CustomException(bankDepositWithBankReconciliationError);
                        
                    }else{
                        String selectedObjType = filterWrap.objectType;
                       
                        if(selectedObjType == ANY_TYPE_LABEL || selectedObjType == CASH_RECEIPT_LABEL){
                            listOfRecords.addAll(queryCashReceiptRecords(bankDepositRecords[0],filterWrap,currentTab));
                        }
                        if(selectedObjType == ANY_TYPE_LABEL || selectedObjType == JOURNAL_ENTRY_LINE_TYPE_LABEL){
                            listOfRecords.addAll(queryJELRecords(bankDepositRecords[0],filterWrap,currentTab));
                        }    
                    }
                    for(SObject record : listOfRecords){
                        results.add(new ResultRecordsWrapper(record));
                    }
                    return results;
                }   
            }
            return results;
        }catch(Exception exc){
            throw new AuraHandledException(exc.getMessage());
        }
    }

    @AuraEnabled
	public static Integer getTotalCRRecords(String bankDepositId, String filtersJSON, String currentTabVal) {
		Integer totalCRrecords = 0;
		try {
			FiltersWrapper filters = (FiltersWrapper) JSON.deserialize(filtersJSON, FiltersWrapper.class);
            List<Bank_Deposit__c> bankDepositRecords = ((List<Bank_Deposit__c>) queryBankDepositRecord(bankDepositId));
			String selectedTypeValue = filters.objectType;
			if (!bankDepositRecords.isEmpty()) {
				if (
					String.isBlank(selectedTypeValue) ||
					selectedTypeValue == ANY_TYPE_LABEL ||
					selectedTypeValue == CASH_RECEIPT_LABEL
				) {
					totalCRrecords = getTotalRecordsCountHelper(
						'Cash_Receipt__c',
						bankDepositRecords[0],
						filters,
						currentTabVal
					);
				}
			}
			return totalCRrecords;
		} catch (Exception ex) {
			throw ex;
		}
	}

    @AuraEnabled
	public static Integer getTotalJELRecords(String bankDepositId, String filtersJSON, String currentTabVal) {
		Integer totalJELrecords = 0;
		try {
			FiltersWrapper filters = (FiltersWrapper) JSON.deserialize(filtersJSON, FiltersWrapper.class);
            List<Bank_Deposit__c> bankDepositRecords = ((List<Bank_Deposit__c>) queryBankDepositRecord(bankDepositId));
			String selectedTypeValue = filters.objectType;
			if (!bankDepositRecords.isEmpty()) {
				if (
					String.isBlank(selectedTypeValue) ||
					selectedTypeValue == ANY_TYPE_LABEL ||
					selectedTypeValue == JOURNAL_ENTRY_LINE_TYPE_LABEL
				) {
					totalJELrecords = getTotalRecordsCountHelper(
						'Journal_Entry_Line__c',
						bankDepositRecords[0],
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
		Bank_Deposit__c bankDepositRecord,
		FiltersWrapper filters,
		String currentTabVal
	) {
		Integer numberOfrecords = 0;

		String queryCondition = getQueryCondition(objectApiName, bankDepositRecord ,filters, currentTabVal);
		String query = 'SELECT COUNT(ID) FROM ' + objectApiName + ' WHERE ';

		query += queryCondition;

		List<AggregateResult> results = Database.query(query);
		if (!results.isEmpty()) {
			AggregateResult result = results[0];
			numberOfRecords = Integer.valueOf(result.get('expr0'));
		}
		return numberOfrecords;
	}


    public static List<SObject> queryCashReceiptRecords(Bank_Deposit__c bankDepositRecord, FiltersWrapper filterWrap, String currentTab){
        String ledgerId = bankDepositRecord.Ledger__c;
        String ledgerCondition = BankManagerHelper.getLedgerCondition(ledgerId, 'Ledger__c');
        String queryCondition = getQueryCondition('Cash_Receipt__c',bankDepositRecord,filterWrap,currentTab) + ledgerCondition;
        List<String> queryFields = filterWrap.cashReceipt.split(',');
        queryFields.add('Id');
        if(MultiCurrencyHandler.isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
            String currencyIsoCode = bankDepositRecord.CurrencyIsoCode;
            queryCondition += BankManagerHelper.getCurrencyCondition(ledgerId, currencyIsoCode);
        }
        SOQLBuilder theQuery = new SOQLBuilder(Cash_Receipt__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .setLimit(filterWrap.queryLimitForCR);

        return Database.query(theQuery.toSOQL());
    }

    public static List<SObject> queryJELRecords(Bank_Deposit__c bankDepositRecord, FiltersWrapper filterWrap, String currentTab){
        String ledgerId = bankDepositRecord.Ledger__c;
        String ledgerCondition = BankManagerHelper.getLedgerCondition(ledgerId, 'Journal_Entry__r.Ledger__c');
        String queryCondition = getQueryCondition('Journal_Entry_Line__c',bankDepositRecord,filterWrap,currentTab) + ledgerCondition;
       
        List<String> queryFields = filterWrap.journalEntryLine.split(',');
        queryFields.addAll(new List<String>{'Id','AcctSeed__Debit__c','AcctSeed__Credit__c'});

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
            String currencyIsoCode = bankDepositRecord.CurrencyIsoCode;
            queryCondition += BankManagerHelper.getCurrencyCondition(ledgerId,currencyIsoCode);
        }

        SOQLBuilder theQuery = new SOQLBuilder(Journal_Entry_Line__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .setLimit(filterWrap.queryLimitForJEL);

        return Database.query(theQuery.toSOQL());
    }

    public static String getQueryCondition(
        String objectApiName,
        Bank_Deposit__c bankDepositRecord,
        FiltersWrapper filterWrap, 
        String currentTab)
    {
        String parsedStartDate = getValidDateFormat(Date.valueOf(filterWrap.startDate));
		String parsedEndDate   = getValidDateFormat(Date.valueOf(filterWrap.endDate));
        String bankAccount = bankDepositRecord.Bank_Account__c;
       
        String queryCondition = '';
        switch on objectApiName{
            when 'Cash_Receipt__c'{
                queryCondition = 'Receipt_Date__c >= '+ 
                                    parsedStartDate +
                                ' AND Receipt_Date__c <= '+
                                    parsedEndDate +' AND ';
                if(currentTab == Label.COMMON_UNASSOCIATE){ 
                    queryCondition +=   'Bank_Account__c = \''+ bankAccount +'\' '+
                                        'AND Bank_Deposit__c = NULL ' +
                                        'AND Bank_Reconciliation__c = NULL ' +
                                        'AND Status__c = \'Posted\' ' + 
                                        'AND Void__c = false ';
                }else if(currentTab == Label.COMMON_ASSOCIATE){
                    queryCondition += 'Void__c = false AND ';
                } 
            }
            when 'Journal_Entry_Line__c'{
                queryCondition = 'Date__c >= '+ 
                                    parsedStartDate +
                                ' AND Date__c <= '+
                                    parsedEndDate + ' AND ';
                if(currentTab == Label.COMMON_UNASSOCIATE){
                    queryCondition += 'Bank_Deposit__c = NULL ' +
                                      'AND Bank_Reconciliation__c = NULL ' +
                                      'AND GL_Account__c = \'' + bankAccount +'\' '+
                                      'AND Journal_Entry__r.Status__c = \'Posted\' ' +
                                      'AND Bank_Disbursement__c = NULL ';
                }
            }
        }
        if(currentTab == Label.COMMON_ASSOCIATE){
            queryCondition +=  'Bank_Deposit__c = \'' +bankDepositRecord.Id + '\' AND Bank_Reconciliation__c = NULL ';
        }else if(currentTab == Label.COMMON_UNASSOCIATE){
            queryCondition += BankManagerHelper.getGlavVariablePredicate(bankDepositRecord.GL_Account_Variable_1__c,bankDepositRecord.GL_Account_Variable_2__c,
                                                                        bankDepositRecord.GL_Account_Variable_3__c, bankDepositRecord.GL_Account_Variable_4__c);
        } 

        if (String.isNotBlank(filterWrap.lastFetchedRecordId)) {
			queryCondition += ' AND Id >  \'' + filterWrap.lastFetchedRecordId + '\' ';
		}
        return queryCondition;
    }


    private static String getValidDateFormat(Date dateVal) {
		return DateTime.newInstance(dateVal, Time.newInstance(0, 0, 0, 0)).format('yyyy-MM-dd');
       
	}

    @AuraEnabled
    public static List<DatatableColumns__c> getDatatableColumns(){
        List<DatatableColumns__c> dataTableColumns = DatatableColumns__c.getall().values();
        return dataTableColumns;
    } 
    
    @AuraEnabled
    public static list<SObject> updateCashReceiptNdJEL(
        List<Id> recordsIdsToUpdate,
        String bankDepositId,
        Boolean isAssociation
    ) {
        
        List<SObject> listOfSobjects = new List<Sobject>();
        try {
			List<Cash_Receipt__c> cashReceiptsToUpdate = new List<Cash_Receipt__c>();
			List<Journal_Entry_Line__c> journalEntryLinesToUpdate = new List<Journal_Entry_Line__c>();

            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Bank_Deposit__c,
                    Journal_Entry_Line__c.Bank_Deposit__c
                }
            );
			for (Id recordId : recordsIdsToUpdate) {
				SObjectType sObjType = recordId.getSObjectType();
				if (sObjType == Cash_Receipt__c.sObjectType) {
					Cash_Receipt__c crRecord = new Cash_Receipt__c();
					crRecord.Id = recordId;
                    if(isAssociation){
                        crRecord.Bank_Deposit__c = bankDepositId;
                    } else {
                        crRecord.Bank_Deposit__c = null;
                    }
					cashReceiptsToUpdate.add(crRecord);
				} else if (sObjType == Journal_Entry_Line__c.sObjectType) {
					Journal_Entry_Line__c jelRecord = new Journal_Entry_Line__c();
					jelRecord.Id = recordId;
                    if(isAssociation){
                        jelRecord.Bank_Deposit__c = bankDepositId;
                    } else {
                        jelRecord.Bank_Deposit__c = null;
                    }
					journalEntryLinesToUpdate.add(jelRecord);
				}
			}

            
            SFDCSecurityUtils.BYPASS_INTERNAL_FLS_AND_CRUD = true;
			if (!cashReceiptsToUpdate.isEmpty()) {
				SFDCSecurityUtils.updateCheckCRUDAndFLS(
					cashReceiptsToUpdate,
					new List<String>{ 'Bank_Deposit__c' }
				);
			}

			if (!journalEntryLinesToUpdate.isEmpty()) {
				SFDCSecurityUtils.updateCheckCRUDAndFLS(
					journalEntryLinesToUpdate,
					new List<String>{ 'Bank_Deposit__c' }
				);
			}
            SFDCSecurityUtils.BYPASS_INTERNAL_FLS_AND_CRUD = false;
            TriggerObserver.reset();
            

			calculateTotalAmount(bankDepositId);
            setBankTransactionStatus(bankDepositId);

			listOfSobjects.addAll(cashReceiptsToUpdate);
			listOfSobjects.addAll(journalEntryLinesToUpdate);   
        }
        catch (DmlException dmlEx) {
           throw new DmlException(dmlEx.getDmlMessage(0));    
        }
        catch (Exception ex) {
            throw ex;
        }
        
        return listOfSobjects;
    }

    private static void calculateTotalAmount(String bankDepositId) {
        try {
            Bank_Deposit__c thisBankDeposit;
            List<String> queryFields = new List<String>{
                'Id',
                'Amount__c',
                'Ledger_Amount__c',
                'Ledger__c'
            };

            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                queryFields.add('CurrencyIsoCode');
            }

            String queryCondition = 'Id = :bankDepositId LIMIT 1';

            SOQLBuilder theQuery = new SOQLBuilder(Bank_Deposit__c.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition);

            thisBankDeposit = (Bank_Deposit__c) Database.query(theQuery.toSOQL());

            String bankDepositCurrency = MultiCurrencyHandler.CORPORATE_CURRENCY;
            String ledgerCurrency = MultiCurrencyHandler.CORPORATE_CURRENCY;
            Decimal totalAmount = 0;
            Decimal totalLedgerAmount = 0;

            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                bankDepositCurrency = (String) thisBankDeposit.get('CurrencyIsoCode');
                ledgerCurrency = LedgerHandler.getLedgerCurrency(thisBankDeposit.Ledger__c);
            }

            AggregateResult crAggregateResult =
                DomainUtils.getCashReceiptsAmountSumAndLedgerAmountSum(bankDepositId, Cash_Receipt__c.Bank_Deposit__c)[0];
            if (crAggregateResult.get('amountSum') != NULL) {
                totalAmount += (Decimal) crAggregateResult.get('amountSum');
            }
            if (crAggregateResult.get('ledgerAmountSum') != NULL) {
                totalLedgerAmount += (Decimal) crAggregateResult.get('ledgerAmountSum');
            }
            //Debit Journal Entry Lines Amounts aggregation =============
            AggregateResult debitJELAggregateResult =
                DomainUtils.getDebitJEAmountSumAndLedgerAmountSum(bankDepositId, Journal_Entry_Line__c.Bank_Deposit__c)[0];
            if (debitJELAggregateResult.get('amountSum') != NULL) {
                totalAmount -= (Decimal) debitJELAggregateResult.get('amountSum');
            }
            if (debitJELAggregateResult.get('ledgerAmountSum') != NULL) {
                totalLedgerAmount -= (Decimal) debitJELAggregateResult.get('ledgerAmountSum');
            }
            //Create Journal Entry Lines Amounts aggregation =============
            AggregateResult creditJELAggregateResult =
                DomainUtils.getCreditJEAmountSumAndLedgerAmountSum(bankDepositId, Journal_Entry_Line__c.Bank_Deposit__c)[0];
            if (creditJELAggregateResult.get('amountSum') != NULL) {
                totalAmount += (Decimal) creditJELAggregateResult.get('amountSum');
            }
            if (creditJELAggregateResult.get('ledgerAmountSum') != NULL) {
                totalLedgerAmount += (Decimal) creditJELAggregateResult.get('ledgerAmountSum');
            }

            if (bankDepositCurrency.equals(ledgerCurrency)) {
                totalAmount = totalLedgerAmount;
            }
            thisBankDeposit.Amount__c = totalAmount.setScale(2, System.RoundingMode.HALF_UP);
            thisBankDeposit.Ledger_Amount__c = totalLedgerAmount.setScale(2, System.RoundingMode.HALF_UP);

            
            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c}
            );
            SFDCSecurityUtils.updateCheckCRUDAndFLS(thisBankDeposit, new List<String>{'Amount__c', 'Ledger_Amount__c'});
            TriggerObserver.purgeUnlockedFields(
                new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c}
            );
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    private static void setBankTransactionStatus(String bankDepositId) {
        List<Bank_Deposit__c> thisBankDeposit = DomainUtils.getBankDepositsById(new Set<Id> {bankDepositId});

        if (!thisBankDeposit.isEmpty() && thisBankDeposit[0].Bank_Transaction__c != NULL) {
            BankTransactionsHelper.updateBankTransactionsStatus(
                DomainUtils.getBankTransactionsById(new Set<Id> {thisBankDeposit[0].Bank_Transaction__c}),
                BankTransactionsHelper.BT_UNMATCHED_STATUS
            );
            thisBankDeposit[0].Cleared_Date__c = NULL;
            thisBankDeposit[0].Bank_Transaction__c = NULL;

            TriggerObserver.getInstance().unlockField(Bank_Deposit__c.Bank_Transaction__c);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(
                thisBankDeposit, new List<String>{'Cleared_Date__c', 'Bank_Transaction__c'}
            );
            TriggerObserver.purgeUnlockedFields(Bank_Deposit__c.Bank_Transaction__c);
        }
    }

    @AuraEnabled
    public static void saveColumnDetails(String columnData){
        if(String.isNotBlank(columnData)){
            Map<String,Boolean> mapOfIdWithColVisibility = (Map<String,Boolean>) JSON.deserialize(columnData,Map<String,Boolean>.class);
            Map<Id,DatatableColumns__c> mapOfIdWithDatatableCustomSetting = new Map<Id,DatatableColumns__c>(getDatatableColCustomSetting(mapOfIdWithColVisibility.keySet()));
            for(Id id : mapOfIdWithDatatableCustomSetting.keySet()){
                mapOfIdWithDatatableCustomSetting.get(id).Add_Field__c = mapOfIdWithColVisibility.get(String.valueOf(id));
            }
            if(!mapOfIdWithDatatableCustomSetting.isEmpty()){
                update mapOfIdWithDatatableCustomSetting.values();
            }
        }
    }

    public static List<DatatableColumns__c> getDatatableColCustomSetting(Set<String> ids){
        return [SELECT Id,Add_Field__c FROM DatatableColumns__c WHERE Id IN : ids];
    }

   @AuraEnabled(cacheable=true)
	public static List<Bank_Deposit__c> queryBankDepositRecord(String recordId) {
		List<String> fieldsToQuery = new List<String>{
			'Id',
			'Bank_Account__c',
            'Deposit_Date__c',
			'GL_Account_Variable_1__c',
			'GL_Account_Variable_2__c',
			'GL_Account_Variable_3__c',
			'GL_Account_Variable_4__c',
			'Ledger__c',
			'Amount__c',
            'Bank_Transaction__c',
			'Bank_Reconciliation__c',
			'Bank_Reconciliation__r.Name'
		};

		String queryCondition = 'Id =: recordId ';

		if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
			fieldsToQuery.add('CurrencyIsoCode');
		}

		SOQLBuilder theQuery = new SOQLBuilder(Bank_Deposit__c.SObjectType);
		theQuery.setEnforceFLS(false).selectFields(fieldsToQuery).setCondition(queryCondition);
		return Database.query(theQuery.toSOQL());
	}


    public class FiltersWrapper {
        @AuraEnabled
        public String startDate;
        @AuraEnabled
        public String endDate;
        @AuraEnabled
        public String objectType;
        @AuraEnabled 
        public String cashReceipt;
        @AuraEnabled 
        public String journalEntryLine;
        @AuraEnabled
        public Integer queryLimitForCR;
        @AuraEnabled
        public Integer queryLimitForJEL;
        @AuraEnabled
        public String lastFetchedRecordId;


        public FiltersWrapper(
                String startDate,
                String endDate,
                String objectType,
                String cashReceipt,
                String journalEntryLine,
                Integer queryLimitForCR,
                Integer queryLimitForJEL,
                String lastFetchedRecordId
        ) {
            this.startDate = startDate;
            this.endDate = endDate;
            this.objectType = objectType;
            this.cashReceipt = cashReceipt;
            this.journalEntryLine = journalEntryLine;
            this.queryLimitForCR = queryLimitForCR;
            this.queryLimitForJEL = queryLimitForJEL;
            this.lastFetchedRecordId = lastFetchedRecordId;
        }
    }
    

    public with sharing class ResultRecordsWrapper implements Comparable {
        @AuraEnabled
        public SObject obj;

        @AuraEnabled
        public String name {get; set;}

        @AuraEnabled
        public BankManagerHelper.SourceObject sourceObj {get; set;}

        public ResultRecordsWrapper(SObject sObj) {
            this.obj = sObj;
            this.name = (String) obj.get('Name');
            this.sourceObj = new BankManagerHelper.SourceObject(this.obj.Id, this.name, getSourceType());
        }


        public Integer compareTo(Object compareTo) {
            System.debug('inside compare to');
            return 1;
        } 

        private String getSourceType() {
            String source = '';
            switch on obj {
                when Cash_Receipt__c objRecord {
                    source = CASH_RECEIPT_TYPE;
                }
                when Journal_Entry_Line__c objRecord {
                    if (objRecord.get('Debit__c') != NULL) {
                        source = DEBIT_JOURNAL_ENTRY_LINE_TYPE;
                    }
                    else if (objRecord.get('Credit__c') != NULL) {
                        source = CREDIT_JOURNAL_ENTRY_LINE_TYPE;
                    }
                }
            }
            return source;
        }
    }  
}