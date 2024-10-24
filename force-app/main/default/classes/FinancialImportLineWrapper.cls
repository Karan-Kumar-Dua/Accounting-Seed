public with sharing class FinancialImportLineWrapper {

    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    public static final Schema.SObjectType receiptType = Schema.getGlobalDescribe().get(PACKAGE_QUALIFIER + 'Cash_Receipt__c');
    public static final Schema.SObjectType disbursementType = Schema.getGlobalDescribe().get(PACKAGE_QUALIFIER + 'Cash_Disbursement__c');
    public static final Schema.SObjectType jeLineType = Schema.getGlobalDescribe().get(PACKAGE_QUALIFIER + 'Journal_Entry_Line__c');
    public static final Schema.SObjectType depositType = Schema.getGlobalDescribe().get(PACKAGE_QUALIFIER + 'Bank_Deposit__c');
    public static final String DEBIT_JOURNAL_LABEL = 'Debit Journal';
    public static final String CREDIT_JOURNAL_LABEL = 'Credit Journal';
    public static final String JOURNAL_ENTRY_LABEL = 'Journal Entry';
    public static final String DEPOSIT_LABEL = 'Deposit';
    public static final String RECEIPT_LABEL = 'Receipt';
    public static final String DISBURSEMENT_LABEL = 'Disbursement';
    public static final String DEBIT_JOURNAL_VALUE = Label.COMMON_DEBIT_JOURNAL;
    public static final String CREDIT_JOURNAL_VALUE = Label.COMMON_CREDIT_JOURNAL;
    public static final String JOURNAL_ENTRY_VALUE = Label.COMMON_JOURNAL_ENTRY;
    public static final String DEPOSIT_VALUE = Label.COMMON_DEPOSIT;
    public static final String RECEIPT_VALUE = Label.COMMON_RECEIPT;
    public static final String DISBURSEMENT_VALUE = Label.COMMON_DISBURSEMENT;

    public SObject obj {get; set;}
    public String currencyCode {get; set;}
    public TransactionType tranType;
    public String name {get; set;}
    public enum TransactionType {DEBIT, CREDIT}
    public InsertResult insertResult {get; set;}
    public Boolean isRecordExists {get; set;}
    public String selectedTransactionType {get; set;}
    public String extId {get; set;}
    public Boolean linkedWithMatchingRecord {get; set;}
    public List<FinancialTransactionMatchingProvider.MatchingRecordWrapper> matchingRecords {get; set;}
    public Date transDate;

    public FinancialImportLineWrapper(  String transId,
                                        String name,
                                        String transType,
                                        Date transDate,
                                        Decimal amount,
                                        String currencyCode,
                                        String glAccountId) {

        this.tranType = (transType.toUpperCase() == 'CREDIT' ? TransactionType.CREDIT : TransactionType.DEBIT);
        this.obj = (this.tranType == TransactionType.CREDIT ? receiptType.newSObject() : disbursementType.newSObject());
        this.selectedTransactionType = (this.tranType == TransactionType.CREDIT) ? RECEIPT_VALUE : DISBURSEMENT_VALUE;
        this.extId = transId;
        setExternalId(transId);
        this.name = name;
        this.transDate = transDate;
        setDate(transDate);
        obj.put('Amount__c', Math.abs(amount));
        setGLAccount(glAccountId);
        isRecordExists = false;
        linkedWithMatchingRecord = false;
        populateDefaultCashFlowCategory();
        this.currencyCode = currencyCode;
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            this.obj.put('CurrencyIsoCode', currencyCode);
        }
    }

    public void populateDefaultCashFlowCategory() {
        Accounting_Settings__c main = AccountingSettingsHandler.getAccountingSettings();
        if (main.Enable_Cash_Flow_Statement__c) {
            Id ledgerId = LedgerHandler.getInstanceWithoutSharing().getTransactionalLedgers()[0].Id;
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(ledgerId);
            if (this.obj.getSObjectType() == receiptType) {
                this.obj.put('Cash_Flow_Category__c', defaultsBySpecDevNames.get(GLAccountDefaultsHandler.DEFAULT_CASH_RECEIPT_CATEGORY)?.GL_Account__c);
            }
            else if (this.obj.getSObjectType() == disbursementType) {
                this.obj.put('Cash_Flow_Category__c', defaultsBySpecDevNames.get(GLAccountDefaultsHandler.DEFAULT_CASH_DISBURSEMENT_CATEGORY)?.GL_Account__c);
            }
        }
    }

    public void setClearedDate() {
        if (this.obj.get('Cleared_Date__c') == NULL) {
            this.obj.put('Cleared_Date__c', this.transDate);
        }
    }

    public void clearObjectId() {
        if (this.obj != NULL) {
            this.obj.Id = NULL;
        }
    }

    public void mergeWithMatchingRecord() {
        if (this.obj == NULL || this.obj.Id == NULL || linkedWithMatchingRecord == false || matchingRecords == NULL || matchingRecords.isEmpty()) {
            return;
        }

        SObject tempSObject;

        for (FinancialTransactionMatchingProvider.MatchingRecordWrapper matchingRecordWrapper : matchingRecords) {
            if (matchingRecordWrapper.obj != NULL && matchingRecordWrapper.obj.Id == this.obj.Id) {
                tempSObject = matchingRecordWrapper.obj;
                tempSObject.put('Bank_Id__c', this.extId);
                this.selectedTransactionType = matchingRecordWrapper.tranTypeName;
            }
        }

        this.obj = tempSObject;
    }

    public FinancialTransactionMatchingProvider.MatchingRecordWrapper getLinkedMatchingRecord() {
        if (this.obj == NULL || this.obj.Id == NULL || linkedWithMatchingRecord == false || matchingRecords == NULL || matchingRecords.isEmpty()) {
            return NULL;
        }

        FinancialTransactionMatchingProvider.MatchingRecordWrapper result;
        for (FinancialTransactionMatchingProvider.MatchingRecordWrapper matchingRecordWrapper : matchingRecords) {
            if (matchingRecordWrapper.obj != NULL && matchingRecordWrapper.obj.Id == this.obj.Id) {
                result = matchingRecordWrapper;
            }
        }
        return result;
    }

    public Boolean getHasMatchingRecords() {
        return matchingRecords != NULL && !matchingRecords.isEmpty();
    }

    public Boolean getIsCreateable() {
        return !isRecordExists || (insertResult != NULL
                                        && insertResult.result != NULL
                                        && insertResult.result.theStatusCode != StatusCode.CREATED
                                        && insertResult.result.theStatusCode != StatusCode.RECORD_EXISTS);
    }
    
    public String getAccountId() {
        String accountId;
        
        if (tranType == TransactionType.CREDIT) {
            accountId = String.valueOf(obj.get('Account__c'));               
        }
        else {
            accountId = String.valueOf(obj.get('Vendor__c'));
        }
        
        return accountId;
    }

    public void setAccountId(String accountId) {
        
        if (tranType == TransactionType.CREDIT) {
            obj.put('Account__c', accountId);
        }
        else {
            obj.put('Vendor__c', accountId);
        }
    }

    public TransactionType getTranType() {
        return tranType;
    }
            
    public String getTranTypeName() {
        String result;
        if (obj.getSObjectType() == receiptType) {
            result = RECEIPT_VALUE;
        }
        else if (obj.getSObjectType() == disbursementType) {
            result = DISBURSEMENT_VALUE;
        }
        else if (obj.getSObjectType() == jeLineType) {
            result = JOURNAL_ENTRY_VALUE;
        }
        else if (obj.getSObjectType() == depositType) {
            result = DEPOSIT_VALUE;
        }
        return result;
    }

    public List<SelectOption> getAvailableTypes() {
        List<SelectOption> result = new List<SelectOption>();
        if (tranType == TransactionType.CREDIT) {
            result.add(
                new SelectOption(RECEIPT_VALUE, RECEIPT_LABEL)
            );
            result.add(
                new SelectOption(DEBIT_JOURNAL_VALUE, DEBIT_JOURNAL_LABEL)
            );
        }
        else {
            result.add(
                new SelectOption(DISBURSEMENT_VALUE, DISBURSEMENT_LABEL)
            );
            result.add(
                new SelectOption(DEBIT_JOURNAL_VALUE, CREDIT_JOURNAL_LABEL)
            );
        }

        return result;
    }
    
    private void setDate(Date theDate) {
        if (tranType == TransactionType.CREDIT) {
            obj.put('Receipt_Date__c', theDate);
        }
        else {
            obj.put('Disbursement_Date__c', theDate);
        }
    }

    public Date getDate() {
        Date result;
        if (obj.getSObjectType() == receiptType) {
            result = (Date) obj.get('Receipt_Date__c');
        }
        else if (obj.getSObjectType() == disbursementType) {
            result = (Date) obj.get('Disbursement_Date__c');
        }
        else if (obj.getSObjectType() == jeLineType) {
            result = (Date) obj.getSObject('Journal_Entry__r').get('Journal_Date__c');
        }
        else if (obj.getSObjectType() == depositType) {
            result = (Date) obj.get('Deposit_Date__c');
        }

        return result;
    }

    private void setExternalId(String theId) {
        obj.put('Bank_Id__c', theId);
        //need that because Payment_Reference__c field on Cash Receipt is required on the DB level
        if (obj.getSObjectType() == Cash_Receipt__c.SObjectType) {
            obj.put('Payment_Reference__c', String.valueOf(Datetime.now().getTime()));
        }
    }
    
    public String getExternalId() {
        return String.valueOf(obj.get('Bank_Id__c'));
    }   
    
    public void setGLAccount(Id glAccountId) {
        if (tranType == TransactionType.CREDIT) {
            obj.put('Credit_GL_Account__c', glAccountId);
        }
        else {
            obj.put('Debit_GL_Account__c', glAccountId);
        }                   
    }

    public String getAmountFieldApiName() {
        String amountFieldApiName = 'Amount__c';
        switch on obj {
            when Journal_Entry_Line__c je {
                if (je.Debit__c != NULL) {
                    amountFieldApiName = 'Debit__c';
                }
                else {
                    amountFieldApiName = 'Credit__c';
                }
            }
            when else {
                amountFieldApiName = 'Amount__c';
            }
        }
        return amountFieldApiName;
    }
    
    public Id getGLAccount() {
       return tranType == TransactionType.CREDIT ? String.valueOf(obj.get('Credit_GL_Account__c')) : String.valueOf(obj.get('Debit_GL_Account__c'));        
    }
    
    public enum StatusCode {CASH_FLOW_ERROR, RECORD_EXISTS, CREATED, REQUIRED_FIELD_ERROR, SYSTEM_EXCEPTION}

    public with sharing class InsertResult {
        public Boolean isSuccess {get; private set;}
        public String id {get; private set;}
        public InsertCompleteResult result {get; private set;}

        public InsertResult(Boolean isSuccess, String id, InsertCompleteResult result) {
            this.isSuccess = isSuccess;
            this.id = id;
            this.result = result;
        }

    }


    public with sharing class InsertCompleteResult {
        public StatusCode theStatusCode {get; private set;}
        public String customMessage {get; set;}
        public String id {get; set;}
               
        public InsertCompleteResult(StatusCode theStatusCode) {
            this.theStatusCode = theStatusCode;
            this.customMessage = customMessage;
        }

        public String getMessage() {
            String message = '';

            if (theStatusCode == StatusCode.CREATED) {
                message = '<span style="font-weight:bold;color:#390">' + Label.COMMON_CREATED + '<br/><a href="/' + id + '" target="_blank">' + Label.COMMON_VIEW_RECORD + '</span>';
            }
            else if (theStatusCode == StatusCode.REQUIRED_FIELD_ERROR) {
                message = 'Not Created<br/>Missing Required Fields';
            }
            else if (theStatusCode == StatusCode.RECORD_EXISTS) {
                message = '<span style="font-weight:bold;color:#4585F4">' + Label.COMMON_RECORD_EXISTS + '<br/><a href="/' + id + '" target="_blank">' + Label.COMMON_VIEW_RECORD + '</span>';
            }
            else if (theStatusCode == StatusCode.CASH_FLOW_ERROR) {
                message = Label.COMMON_NOT_CREATED + '<br/>' + Label.COMMON_INCORRECT + ' ' + Label.COMMON_CASH_FLOW_CATEGORY;
            }
            else {
                message = Label.COMMON_NOT_CREATED + ' - ' + Label.COMMON_EXCEPTION +'<br/>' + customMessage + '';
            }
            return message;
        }

        public String getTheStatusCodeName() {
            return theStatusCode.name();
        }
    }

}