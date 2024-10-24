global with sharing class BankDeposit {

    public static final Integer BANK_DEPOSIT_ITEM_LIMIT = 200;
    
    public enum StatusCode {NO_INPUT_DATA, INVALID_RECORD_OR_ID, NO_BANK_DEPOSIT_ITEMS, OVER_BANK_DEPOSIT_ITEM_LIMIT, INVALID_ASSOCIATION_RECORD, INVALID_UNASSOCIATION_RECORD}

    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    @TestVisible 
    private static final String NO_INPUT_DATA = Label.ERR_NO_INPUT_DATA;

    @TestVisible 
    private static final String INVALID_RECORD_OR_ID = Label.ERR_INVALID_RECORD_OR_ID;

    @TestVisible 
    private static final String NO_BANK_DEPOSIT_ITEMS = Label.ERR_NO_BANK_DEPOSIT_ITEMS;

    @TestVisible
    private static final String INVALID_ASSOCIATION_RECORD = Label.ERR_INVALID_ASSOCIATION_BANK_DEPOSIT;

    @TestVisible
    private static final String INVALID_UNASSOCIATION_RECORD = Label.ERR_INVALID_UNASSOCIATION_BANK_DEPOSIT;

    @TestVisible 
    private static final String OVER_BANK_DEPOSIT_ITEM_LIMIT = Label.ERR_OVER_RECONCILIATION_ITEM_LIMIT;

    @TestVisible
    private ServiceResult serviceResult;

    @TestVisible
    public BankDepositModel model;
    public BankDepositAction action;
    private List<Id> itemIds;

    private List<SObject> bankDepositItemRecordsToUpdate;

    @TestVisible 
    private APIServiceContext.APIServiceEntry serviceEntry;
    public class BankDepositException extends Exception {}

    public BankDeposit(Id bankDepositId) {
        BankDepositModel model = new BankDepositModel();
        if (FinancialSuiteUtils.isValidId(bankDepositId, Bank_Deposit__c.SObjectType)) {
            model.record = (Bank_Deposit__c) Bank_Deposit__c.SObjectType.newSObject(bankDepositId);
            serviceResult = new ServiceResult();
            this.model = model;
            bankDepositItemRecordsToUpdate = new List<SObject>();

            serviceEntry = new APIServiceContext.APIServiceEntry();
        }
        else {
            throw new BankDepositException(INVALID_RECORD_OR_ID);
        }
    }

    public BankDeposit(Id bankDepositId, List<Id> itemIds) {
        this(bankDepositId);
        this.itemIds = itemIds;
    }

    global static ServiceResult associate(Id bankDepositId, List<Id> itemIds) {
        ServiceResult serviceResult;

        try {
            BankDeposit bds = new BankDeposit(bankDepositId, itemIds);
            serviceResult = APIServiceContext.validateServiceContext(bds.serviceEntry);

            if (serviceResult.isSuccess) {
                serviceResult = bds.associate();
            }
        }
        catch (BankDepositException ex) {
            serviceResult = new ServiceResult(NULL, StatusCode.NO_INPUT_DATA.name(), NO_INPUT_DATA);
        }
        catch (Exception ex) {
            serviceResult = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }

        return serviceResult;
    }
    
    global static ServiceResult unassociate(Id bankDepositId, List<Id> itemIds) {
        ServiceResult serviceResult;

        try {
            BankDeposit bds = new BankDeposit(bankDepositId, itemIds);
            serviceResult = APIServiceContext.validateServiceContext(bds.serviceEntry);

            if (serviceResult.isSuccess) {
                serviceResult = bds.unassociate();
            }
        }
        catch (BankDepositException ex) {
            serviceResult = new ServiceResult(NULL, StatusCode.NO_INPUT_DATA.name(), NO_INPUT_DATA);
        }
        catch (Exception ex) {
            serviceResult = new ServiceResult(NULL,ex.getTypeName(),ex.getMessage());
        }

        return serviceResult;
    }

    global static BankDepositModel retrieve(Id bankDepositId) {
        BankDepositModel retrieveResult;
        BankDeposit bds = new BankDeposit(bankDepositId);
        ServiceResult sr = APIServiceContext.validateServiceContext(bds.serviceEntry);
        if (sr.isSuccess) {
            retrieveResult = bds.retrieve();
        }
        return retrieveResult;
    }
    
    private ServiceResult associate() {
        action = BankDepositAction.ASSOCIATE;
        if (validateInput()) {
            model.record = queryBankDepositById();
            validateItemIds();
            processSourceRecords(queryCashReceipts());
            processSourceRecords(queryJournalEntryLines());
            BankDepositHandler bdHandler = new BankDepositHandler(model.record.Id);
            bdHandler.associateObjectsAndCalculate(bankDepositItemRecordsToUpdate);
        }

        return serviceResult;
    }
    
    private ServiceResult unassociate() {
        action = BankDepositAction.UNASSOCIATE;
        if (validateInput()) {
            model.record = queryBankDepositById();
            validateItemIds();
            processSourceRecords(queryCashReceipts());
            processSourceRecords(queryJournalEntryLines());
            BankDepositHandler bdHandler = new BankDepositHandler(model.record.Id);
            bdHandler.unAssociateObjectsAndCalculate(bankDepositItemRecordsToUpdate);
        }

        return serviceResult;
    }
    
    private BankDepositModel retrieve() {
        action = BankDepositAction.RETRIEVE1;

        if (validateInput()) {
            model.record = queryBankDepositById();
            model.items = new List<SObject>(); 
            retrieveSourceRecord(queryCashReceipts());
            retrieveSourceRecord(queryJournalEntryLines());
        }

        return model;
    }

    private Boolean validateInput() {
        ServiceResult.Error error = new ServiceResult.Error(); 

        if (model == NULL) {
            error.detail = NO_INPUT_DATA;
            error.code = StatusCode.NO_INPUT_DATA.name();
        }
        else if (!FinancialSuiteUtils.isValidId(model.record.Id, Bank_Deposit__c.SObjectType)) {
            error.detail = INVALID_RECORD_OR_ID;
            error.code = StatusCode.INVALID_RECORD_OR_ID.name();
        }
        else if ((action == BankDepositAction.ASSOCIATE || action == BankDepositAction.UNASSOCIATE)
                    && (itemIds == NULL || itemIds.isEmpty())) {

            error.detail = NO_BANK_DEPOSIT_ITEMS;
            error.code = StatusCode.NO_BANK_DEPOSIT_ITEMS.name();
        }
        else if (itemIds != NULL && itemIds.size() > BANK_DEPOSIT_ITEM_LIMIT) {
            error.detail = String.format(OVER_BANK_DEPOSIT_ITEM_LIMIT, new String[]{String.valueOf(BANK_DEPOSIT_ITEM_LIMIT)});
            error.code = StatusCode.OVER_BANK_DEPOSIT_ITEM_LIMIT.name();
        }

        if (error.detail != NULL) {
            serviceResult = new ServiceResult(
                NULL,
                false,
                new ServiceResult.Error[]{error}
            );
        }
        else {
            serviceResult = new ServiceResult(model.record.Id, true);
        }

        return serviceResult.isSuccess;
    }

    private Bank_Deposit__c queryBankDepositById() {
        Bank_Deposit__c result;
        Id bankDepId =  model.record.Id;

        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Bank_Account__c',
            'Amount__c',
            'Deposit_Date__c',
            'Deposit_Reference__c',
            'Cleared_Date__c',
            'Bank_Reconciliation__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c',
            'Ledger__c'
        };

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }

        String queryCondition = 'Id = :bankDepId';

        SOQLBuilder theQuery = new SOQLBuilder(Bank_Deposit__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        result = (Bank_Deposit__c) Database.query(theQuery.toSOQL());

        return result;
    }

    private void validateItemIds() {
        List<Id> tempItemIds = new List<Id>();

        for (Id itemId : itemIds) {
            if (FinancialSuiteUtils.isValidId(itemId, Cash_Receipt__c.SObjectType)
                    || FinancialSuiteUtils.isValidId(itemId, Journal_Entry_Line__c.SObjectType)) {

                tempItemIds.add(itemId);
            }
            else {
                serviceResult.results.add(new ServiceResult(itemId, StatusCode.INVALID_RECORD_OR_ID.name(), INVALID_RECORD_OR_ID));
            }
        }

        itemIds = tempItemIds;
    }

    private void retrieveSourceRecord(List<SObject> records) {
        if (action == BankDepositAction.RETRIEVE1) {
            for (SObject obj : records) {
                model.items.add(obj);
            }
        }
    }

    private void processSourceRecords(List<SObject> records) {
        if (records != NULL && !records.isEmpty()) {
            Set<Id> ledgerIds = getValidLedgerIds();
            for (SObject obj : records) {
                BankDepositItemWrapper bdi = new BankDepositItemWrapper(obj, model.record);
                if (action == BankDepositAction.ASSOCIATE) {
                    associateSourceRecord(bdi, ledgerIds);
                }
                else if (action == BankDepositAction.UNASSOCIATE) {
                    unassociateSourceRecord(bdi);
                }
            }
        }
    }

    private void associateSourceRecord(BankDepositItemWrapper bdi, Set<Id> ledgerIds) {
        if (bdi.validateRecordToAssociate(ledgerIds)) {
            bankDepositItemRecordsToUpdate.add(bdi.item);
        }
        else {
            serviceResult.results.add(new ServiceResult(bdi.item.Id, StatusCode.INVALID_ASSOCIATION_RECORD.name(), INVALID_ASSOCIATION_RECORD));
        }
    }

    private void unassociateSourceRecord(BankDepositItemWrapper bdi) {
        if (bdi.validateRecordToUnassociate()) {
            bankDepositItemRecordsToUpdate.add(bdi.item);
        }
        else {
            serviceResult.results.add(new ServiceResult(bdi.item.Id, StatusCode.INVALID_UNASSOCIATION_RECORD.name(), INVALID_UNASSOCIATION_RECORD));
        }
    }

    private Set<Id> getValidLedgerIds() {
        Set<Id> validLedgerIds;
        if (model.record.Ledger__c == NULL) {
            //if bank deposit is legacy record
            validLedgerIds = new Set<Id>{LedgerHandler.getLegacyDefaultLedgerId(), NULL};
        }
        else if (LedgerHandler.isLedgerEqualLegacyLedger(model.record.Ledger__c)) {
            //if bank deposit is not legacy but there may be legacy transactions
            validLedgerIds = new Set<Id>{model.record.Ledger__c, NULL};
        }
        else {
            validLedgerIds = new Set<Id>{model.record.Ledger__c};
        }

        return validLedgerIds;
    }

    private List<Cash_Receipt__c> queryCashReceipts() {
        List<Cash_Receipt__c> result = new List<Cash_Receipt__c>();

        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Amount__c',
            'Cleared_Date__c',
            'Bank_Reconciliation__c',
            'Bank_Deposit__c',
            'Bank_Account__c',
            'Status__c',
            'Ledger__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c',
            'Void__c'
        };

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }

        String queryCondition;
        Id bankDepositId = model.record.Id;

        if (action == BankDepositAction.RETRIEVE1) {
            queryCondition = 'Bank_Deposit__c = :bankDepositId';
        }
        else {
            queryCondition = 'Id IN :itemIds';
        } 

        SOQLBuilder theQuery = new SOQLBuilder(Cash_Receipt__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        result = (List<Cash_Receipt__c>) Database.query(theQuery.toSOQL());

        return result;
    }

    private List<Journal_Entry_Line__c> queryJournalEntryLines() {
        List<Journal_Entry_Line__c> result  = new List<Journal_Entry_Line__c>();

        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Amount__c',
            'Credit__c',
            'Debit__c',
            'Cleared_Date__c',
            'Bank_Reconciliation__c',
            'Bank_Deposit__c',
            'Journal_Entry__r.Status__c',
            'GL_Account__c',
            'Journal_Entry__r.Ledger__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c'
        };

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }

        String queryCondition;
        Id bankDepositId = model.record.Id;

        if (action == BankDepositAction.RETRIEVE1) {
            queryCondition = 'Bank_Deposit__c = :bankDepositId';
        }
        else {
            queryCondition = 'Id IN :itemIds';
        } 

        SOQLBuilder theQuery = new SOQLBuilder(Journal_Entry_Line__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        result = (List<Journal_Entry_Line__c>) Database.query(theQuery.toSOQL());

        return result;
    }

    public enum BankDepositAction {
        ASSOCIATE, UNASSOCIATE, RETRIEVE1
    }

    public with sharing class BankDepositItemWrapper {
        SObject item;
        private Bank_Deposit__c bankDeposit;

        public BankDepositItemWrapper(SObject obj, Bank_Deposit__c bankDeposit) {
            item = obj;
            this.bankDeposit = bankDeposit;
        }

        public Boolean validateRecordToAssociate(Set<Id> validLedgerIds) {

            return isValidLedgerId(validLedgerIds)
                    && isBankReconciliationNull()
                    && isBankDepositNull()
                    && isValidBankAccount()
                    && isValidPostingStatus() 
                    && isValidByGlavs() 
                    && isValidByCRVoid();
        }
        
        private Boolean isValidLedgerId(Set<Id> validLedgerIds) {
            return validLedgerIds.contains(getLedgerId());
        }

        private Boolean isBankReconciliationNull() {
            return item.get('Bank_Reconciliation__c') == NULL;
        }

        private Boolean isBankDepositBankReconciliationNull() {
            return bankDeposit.Bank_Reconciliation__c == NULL;
        }

        private Boolean isBankDepositNull() {
            return item.get('Bank_Deposit__c') == NULL;
        }

        private Boolean isValidBankDepositId() {
            return item.get('Bank_Deposit__c') == NULL;
        }

        private Boolean isValidBankAccount() {
            return getBankAccountId() == bankDeposit.Bank_Account__c;
        }

        private Boolean isValidPostingStatus() {
            return getPostingStatus() == AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED;
        }

        private Boolean isCorrectBankDeposit() {
            return item.get('Bank_Deposit__c') == bankDeposit.Id;
        }
        private Boolean isValidByCRVoid(){
            if(item.getSObjectType() == Schema.Cash_Receipt__c.sobjectType && Boolean.valueOf(item.get(PACKAGE_QUALIFIER + 'Void__c')) == true ){
                return false;
            }
            return true;
        }
        private Boolean isValidByGlavs() {
            Boolean retVal = TRUE;

            if (bankDeposit.GL_Account_Variable_1__c != NULL
                    && (Id) item.get('GL_Account_Variable_1__c') != bankDeposit.GL_Account_Variable_1__c) {
                retVal = FALSE;
            }

            if (bankDeposit.GL_Account_Variable_2__c != NULL
                    && (Id) item.get('GL_Account_Variable_2__c') != bankDeposit.GL_Account_Variable_2__c) {
                retVal = FALSE;
            }

            if (bankDeposit.GL_Account_Variable_3__c != NULL
                    && (Id) item.get('GL_Account_Variable_3__c') != bankDeposit.GL_Account_Variable_3__c) {
                retVal = FALSE;
            }

            if (bankDeposit.GL_Account_Variable_4__c != NULL
                    && (Id) item.get('GL_Account_Variable_4__c') != bankDeposit.GL_Account_Variable_4__c) {
                retVal = FALSE;
            }

            return retVal;
        }

        public Boolean validateRecordToUnassociate() {
            Boolean isValid = true;
            if (!isCorrectBankDeposit() || !isBankDepositBankReconciliationNull()) {
                isValid = false;
            }
            return isValid;
        }

        private String getPostingStatus() {
            String postStatus;

            switch on item {
                when Cash_Receipt__c cashReceipt {
                    postStatus = cashReceipt.Status__c;
                }
                when Journal_Entry_Line__c journalEntryLine {
                    postStatus = journalEntryLine.Journal_Entry__r.Status__c;
                }
            }

            return postStatus;
        }

        private Id getLedgerId() {
            Id ledgerId;

            switch on item {
                when Cash_Receipt__c cashReceipt {
                    ledgerId = cashReceipt.Ledger__c;
                }
                when Journal_Entry_Line__c journalEntryLine {
                    ledgerId = journalEntryLine.Journal_Entry__r.Ledger__c;
                }
            }

            return ledgerId;
        }

        private Id getBankAccountId() {
            Id ledgerId;

            switch on item {
                when Cash_Receipt__c cashReceipt {
                    ledgerId = cashReceipt.Bank_Account__c;
                }
                when Journal_Entry_Line__c journalEntryLine {
                    ledgerId = journalEntryLine.GL_Account__c;
                }
            }

            return ledgerId;
        }
    }
}