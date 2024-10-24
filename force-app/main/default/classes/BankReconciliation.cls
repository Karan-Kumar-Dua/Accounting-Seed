global with sharing class BankReconciliation {

    @TestVisible
    private static Integer MAX_CLEARABLE_RECORDS_PER_BANK_REC = 8000;
    @TestVisible
    private static Integer QUERY_LIMIT_PER_SRC_DOC = 8001;
    private static final String NON_SELECTIVE_BANK_RECONCILIATION = Label.ERR_NON_SELECTIVE_BANK_REC;
    @TestVisible
    private static final String RECORD_COUNT_OVER_LIMIT_UPDATE = Label.ERR_RECORD_COUNT_OVER_LIMIT_UPDATE;
    
    public static final Integer BANK_RECONCILIATION_ITEM_LIMIT = 200;
    public static final String COMPLETED = 'Completed';
    public static final String IN_PROGRESS = 'In Progress';
    public static final String WORKING = 'Working';
    public static final String AUTO_CLEAR_RUNNING = 'Auto Clear Running';

    public static final String BANK_TYPE = 'Bank';
    public static final String CREDIT_CARD_TYPE = 'Credit Card';
    public static final String PAYMENT_TYPE = 'Payment';
    public static final String CHARGE_TYPE = 'Charge';
    public static final String DEPOSIT_TYPE = 'Deposit';
    public static final String TRANSFER_TYPE = 'Transfer';

    public static Boolean bypassItemLimit = false;

    public enum StatusCode {
        NO_INPUT_DATA,
        INVALID_RECORD_OR_ID,
        NO_RECONCILIATION_ITEMS,
        OVER_RECONCILIATION_ITEM_LIMIT,
        INVALID_CLEAR_RECORD,
        INVALID_UNCLEAR_RECORD,
        LEGACY_BR,
        UBRLS_EXIST,
        CLEARABLE_ITEM_LIMIT,
        INVALID_STATUS_CHANGE,
        INVALID_CLEAR_UNCLEAR_LEGACY
    }

    public enum BankReconciliationAction {
        CLEAR, UNCLEAR, RETRIEVE1, RETRIEVE_ALL, RETRIEVE_UNCLEARED
    }

    public enum Status {
        IN_PROGRESS,
        WORKING,
        COMPLETED,
        AUTO_CLEAR_RUNNING
    }

    @TestVisible
    private static final String NO_INPUT_DATA = Label.ERR_NO_INPUT_DATA;
    @TestVisible
    private static final String INVALID_RECORD_OR_ID = Label.ERR_INVALID_RECORD_OR_ID;

    private static final String NO_RECONCILIATION_ITEMS = Label.ERR_NO_RECONCILIATION_ITEMS;

    private static final String OVER_RECONCILIATION_ITEM_LIMIT = Label.ERR_OVER_RECONCILIATION_ITEM_LIMIT;

    @TestVisible
    private static final String INVALID_CLEAR_RECORD = Label.ERR_INVALID_CLEAR_RECORD;

    @TestVisible
    private static final String INVALID_UNCLEAR_RECORD = Label.ERR_INVALID_UNCLEAR_RECORD;

    @TestVisible
    private static final String LEGACY_BR = Label.ERR_LEGACY_BR;

    @TestVisible
    private static final String UBRLS_EXIST = Label.ERR_UBRLS_EXIST;

    @TestVisible
    private static final String NO_STATUS_CHANGE = Label.ERR_NO_STATUS_CHANGE;

    @TestVisible
    private static final String WORKING_STATUS_CHANGE = Label.ERR_WORKING_STATUS_CHANGE;

    @TestVisible
    private static final String INVALID_CLEAR_UNCLEAR_LEGACY = Label.ERR_INVALID_CLEAR_UNCLEAR_LEGACY;

    @TestVisible
    private ServiceResult serviceResult;

    @TestVisible
    public BankReconciliationModel model;
    public BankReconciliationAction action;
    private List<SObject> bankReconciliationItemRecordsToUpdate;
    private List<Id> itemIds;
    private Map<Id, Date> itemToClearedDate;
    private Boolean isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;

    @TestVisible
    private APIServiceContext.APIServiceEntry serviceEntry;
    public class BankReconciliationException extends Exception {}

    public BankReconciliation(Id bankReconciliationId) {
        BankReconciliationModel model = new BankReconciliationModel();
        if (FinancialSuiteUtils.isValidId(bankReconciliationId, Bank_Reconciliation2__c.SObjectType)) {
            model.record = (Bank_Reconciliation2__c) Bank_Reconciliation2__c.SObjectType.newSObject(bankReconciliationId);
            serviceResult = new ServiceResult();
            this.model = model;
            bankReconciliationItemRecordsToUpdate = new List<SObject>();

            serviceEntry = new APIServiceContext.APIServiceEntry();
            serviceEntry.isRestContextAccessible = true;
            serviceEntry.isTriggerContextAccessible = true;
        }
        else {
            throw new BankReconciliationException(INVALID_RECORD_OR_ID);
        }
    }

    public BankReconciliation(Id bankReconciliationId, List<Id> itemIds) {
        this(bankReconciliationId);
        this.itemIds = itemIds;
    }

    public BankReconciliation(Id bankReconciliationId, List<Id> itemIds, Map<Id, Date> itemToClearedDate) {
        this(bankReconciliationId);
        this.itemIds = itemIds;
        this.itemToClearedDate = itemToClearedDate;
    }

    global static ServiceResult clear(Id bankReconciliationId, List<Id> itemIds) {
        return clear(bankReconciliationId, itemIds, NULL);
    }

    global static ServiceResult clear(Id bankReconciliationId, List<Id> itemIds, Map<Id, Date> itemToClearedDate) {
        ServiceResult serviceResult;

        try {
            BankReconciliation service = new BankReconciliation(bankReconciliationId, itemIds, itemToClearedDate);
            serviceResult = APIServiceContext.validateServiceContext(service.serviceEntry);

            if (serviceResult.isSuccess) {
                serviceResult = service.clear();
            }
        }
        catch (Exception ex) {
            serviceResult = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }

        return serviceResult;
    }

    global static ServiceResult unclear(Id bankReconciliationId, List<Id> itemIds) {
        ServiceResult serviceResult;

        try {
            BankReconciliation service = new BankReconciliation(bankReconciliationId, itemIds);
            serviceResult = APIServiceContext.validateServiceContext(service.serviceEntry);

            if (serviceResult.isSuccess) {
                serviceResult = service.unclear();
            }
        }
        catch (Exception ex) {
            serviceResult = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }

        return serviceResult;
    }

    global static BankReconciliationModel retrieve(Id bankReconciliationId) {
        return retrieve(bankReconciliationId, true, false);
    }

    global static BankReconciliationModel retrieve(Id bankReconciliationId, Boolean includeReconciled, Boolean includeUnreconciled) {
        BankReconciliationModel retrieveResult;
        BankReconciliation service = new BankReconciliation(bankReconciliationId);
        // potential non-selective query in trigger ctx
        service.serviceEntry.isTriggerContextAccessible = false;
        ServiceResult sr = APIServiceContext.validateServiceContext(service.serviceEntry);

        if (sr.isSuccess) {
            retrieveResult = service.retrieve(includeReconciled, includeUnreconciled);
        }

        return retrieveResult;
    }

    global static BankReconciliationModel retrieveItemCount(Id bankReconciliationId) {
        BankReconciliationModel retrieveCountResult;
        BankReconciliation service = new BankReconciliation(bankReconciliationId);
        // potential non-selective query in trigger ctx
        service.serviceEntry.isTriggerContextAccessible = false;
        ServiceResult sr = APIServiceContext.validateServiceContext(service.serviceEntry);
        if (sr.isSuccess) {
            retrieveCountResult = service.retrieveCount();
        }
        return retrieveCountResult;
    }

    global static ServiceResult complete(Id bankReconciliationId) {
        ServiceResult result;

        try {
            BankReconciliation svc = new BankReconciliation(bankReconciliationId);
            // potential non-selective query in trigger ctx
            svc.serviceEntry.isTriggerContextAccessible = false;
            ServiceResult validationResult = APIServiceContext.validateServiceContext(svc.serviceEntry);

            if (validationResult.isSuccess) {
                result = svc.complete();
            }
        } catch (Exception ex) {
            result = new ServiceResult(bankReconciliationId, ex.getTypeName(), ex.getMessage());
        }

        return result;
    }

    global static ServiceResult undoComplete(Id bankReconciliationId) {
        ServiceResult result;

        try {
            BankReconciliation svc = new BankReconciliation(bankReconciliationId);
            ServiceResult validationResult = APIServiceContext.validateServiceContext(svc.serviceEntry);

            if (validationResult.isSuccess) {
                result = svc.undoComplete();
            }
        } catch (Exception ex) {
            result = new ServiceResult(bankReconciliationId, ex.getTypeName(), ex.getMessage());
        }

        return result;
    }

    public static ServiceResult calculateUnclearedDepositsAndPayments(Id bankReconciliationId) {
        ServiceResult serviceResult;        
        BankReconciliation service = new BankReconciliation(bankReconciliationId);
        service.serviceEntry.isTriggerContextAccessible = false;
        ServiceResult sr = APIServiceContext.validateServiceContext(service.serviceEntry);
        if (sr.isSuccess) {
            serviceResult = service.setUnclearedValues();
        }
        return serviceResult;
    }

    public static ServiceResult createUnclearedBankReconciliationLines(Id bankReconciliationId) {
        ServiceResult serviceResult;

        try {
            BankReconciliation service = new BankReconciliation(bankReconciliationId);
            service.serviceEntry.isTriggerContextAccessible = false;
            serviceResult = APIServiceContext.validateServiceContext(service.serviceEntry);

            if (serviceResult.isSuccess) {
                serviceResult = service.createUBRLs();
            }
        }
        catch (Exception ex) {
            serviceResult = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }

        return serviceResult;
    }

    public static ServiceResult deleteUnclearedBankReconciliationLines(Id bankReconciliationId) {
        ServiceResult serviceResult;

        try {
            BankReconciliation service = new BankReconciliation(bankReconciliationId);
            serviceResult = APIServiceContext.validateServiceContext(service.serviceEntry);

            if (serviceResult.isSuccess) {
                serviceResult = service.deleteUBRLs();
            }
        }
        catch (Exception ex) {
            serviceResult = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }

        return serviceResult;
    }

    public static ServiceResult setStatus(Id bankReconciliationId, Status s) {
        ServiceResult result;

        try {
            BankReconciliation service = new BankReconciliation(bankReconciliationId);
            ServiceResult validationResult = APIServiceContext.validateServiceContext(service.serviceEntry);

            if (validationResult.isSuccess) {
                result = service.setStatus(s);
            }
        }
        catch (Exception ex) {
            result = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }

        return result;
    }

    private ServiceResult clear() {
        action = BankReconciliationAction.CLEAR;
        if (validateInput()) {
            model.record = queryBankReconciliationById();
            if (validateModernBR() && validateRelatedItemCount()) {
                validateItemIds();
                processSourceRecords(queryCashDisbursements());
                processSourceRecords(queryCashReceipts());
                processSourceRecords(queryBankDeposits());
                processSourceRecords(queryJournalEntryLines());
                processSourceRecords(queryBankDisbursements());
                clearItems(bankReconciliationItemRecordsToUpdate);
            }
        }

        return serviceResult;
    }

    private ServiceResult unclear() {
        action = BankReconciliationAction.UNCLEAR;
        if (validateInput()) {
            model.record = queryBankReconciliationById();
            if (validateModernBR()) {
                validateItemIds();
                processSourceRecords(queryCashDisbursements());
                processSourceRecords(queryCashReceipts());
                processSourceRecords(queryBankDeposits());
                processSourceRecords(queryJournalEntryLines());
                processSourceRecords(queryBankDisbursements());
                unclearItems(bankReconciliationItemRecordsToUpdate);
            }
        }

        return serviceResult;
    }

    private BankReconciliationModel retrieve(Boolean includeReconciled, Boolean includeUnreconciled) {
        if (includeReconciled && !includeUnreconciled) {
            action = BankReconciliationAction.RETRIEVE1;
            queryRecords();
        }
        else if (includeReconciled && includeUnreconciled) {
            action = BankReconciliationAction.RETRIEVE_ALL;
            queryRecords();
        }
        else if (!includeReconciled && includeUnreconciled) {
            action = BankReconciliationAction.RETRIEVE_UNCLEARED;
            queryRecords();
        }
        model.recordCount = model.items.size();
        return model;
    }

    private ServiceResult deleteUBRLs() {
        ServiceResult serviceResult;
        try {
            UnclearedBankReconciliationLineActions.isPreventDeleteOverride = true;
            SFDCSecurityUtils.deleteProxy(DomainUtils.getUnclearedBankRecLinesByBankRecId(new Set<Id>{model.record.Id}));
            serviceResult = new ServiceResult(model.record.Id, true);
        } catch (Exception ex) {
            serviceResult = new ServiceResult(model.record.id, ex.getTypeName(), ex.getMessage());
        }
        return serviceResult;
    }

    private ServiceResult createUBRLs() {
        ServiceResult serviceResult;
        try {
            if (DomainUtils.getUnclearedBankRecLinesByBankRecId(new Set<Id>{model.record.Id}).isEmpty()) {
                BankReconciliationModel model = retrieve(false, true);
                List<Uncleared_Bank_Reconciliation_Line__c> ubrls = new List<Uncleared_Bank_Reconciliation_Line__c>();
                for (SObject item :model.items) {
                    Uncleared_Bank_Reconciliation_Line__c ubrl = new Uncleared_Bank_Reconciliation_Line__c();
                    ubrl.Bank_Reconciliation__c = model.record.Id;
                    String debitType = model.record.Type__c == BANK_TYPE ? DEPOSIT_TYPE : PAYMENT_TYPE;
                    String creditType = model.record.Type__c == BANK_TYPE ? PAYMENT_TYPE : CHARGE_TYPE;

                    switch on item {
                        when cash_Receipt__c crItem {
                            debitType = crItem.Amount__c < 0 ? creditType : debitType;
                            ubrl.Cash_Receipt__c = crItem.Id;
                            ubrl.Related_Source_Document__c = crItem.Name;
                            ubrl.Amount__c = crItem.Amount__c;
                            ubrl.Ledger_Amount__c = crItem.Ledger_Amount__c;
                            ubrl.Cleared_Date__c = crItem.Cleared_Date__c;
                            ubrl.Date__c = crItem.Receipt_Date__c;
                            ubrl.Description__c = crItem.Description__c;
                            ubrl.Payee_Name__c = crItem.Account__r.Name;
                            ubrl.Payee_Id__c = crItem.Account__c;
                            ubrl.Reference__c = crItem.Payment_Reference__c;
                            ubrl.Type__c = crItem.Credit_GL_Account__r.Bank__c == true ? TRANSFER_TYPE : debitType;
                            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                                ubrl.put('CurrencyIsoCode', (String) crItem.get('CurrencyIsoCode'));
                            }
                            ubrls.add(ubrl);
                        }
                        when Cash_Disbursement__c cdItem {
                            ubrl.Cash_Disbursement__c = cdItem.Id;
                            ubrl.Related_Source_Document__c = cdItem.Name;
                            ubrl.Amount__c = cdItem.Amount__c;
                            ubrl.Ledger_Amount__c = cdItem.Ledger_Amount__c;
                            ubrl.Cleared_Date__c = cdItem.Cleared_Date__c;
                            ubrl.Date__c = cdItem.Disbursement_Date__c;
                            ubrl.Description__c = cdItem.Description__c;
                            ubrl.Payee_Name__c = cdItem.Payee__c;
                            ubrl.Payee_Id__c = cdItem.Payee_Id__c;
                            ubrl.Reference__c = cdItem.Reference__c;
                            ubrl.Type__c = cdItem.Debit_GL_Account__r.Bank__c == true ? TRANSFER_TYPE : cdItem.Amount__c < 0 ? debitType : creditType;
                            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                                ubrl.put('CurrencyIsoCode', (String) cdItem.get('CurrencyIsoCode'));
                            }
                            ubrls.add(ubrl);
                        }
                        when Bank_Deposit__c bdItem {
                            ubrl.Bank_Deposit__c = bdItem.Id;
                            ubrl.Related_Source_Document__c = bdItem.Name;
                            ubrl.Amount__c = bdItem.Amount__c;
                            ubrl.Ledger_Amount__c = bdItem.Ledger_Amount__c;
                            ubrl.Cleared_Date__c = bdItem.Cleared_Date__c;
                            ubrl.Date__c = bdItem.Deposit_Date__c;
                            ubrl.Reference__c = bdItem.Deposit_Reference__c;
                            ubrl.Type__c = bdItem.Amount__c < 0 ? creditType : debitType;
                            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                                ubrl.put('CurrencyIsoCode', (String) bdItem.get('CurrencyIsoCode'));
                            }
                            ubrls.add(ubrl);
                        }
                        when Journal_Entry_Line__c jelItem {
                            ubrl.Journal_Entry_Line__c = jelItem.Id;
                            ubrl.Related_Source_Document__c = jelItem.Name;
                            ubrl.Amount__c = jelItem.Amount__c;
                            ubrl.Ledger_Amount__c = jelItem.Ledger_Amount__c;
                            ubrl.Cleared_Date__c = jelItem.Cleared_Date__c;
                            ubrl.Date__c = jelItem.Journal_Entry__r.Journal_Date__c;
                            ubrl.Description__c = jelItem.Description__c;
                            if (jelItem.Account__c != NULL) {
                                ubrl.Payee_Name__c = jelItem.Account__r.Name;
                                ubrl.Payee_Id__c = jelItem.Account__c;
                            } else if (jelItem.Contact__c != NULL) {
                                ubrl.Payee_Name__c = jelItem.Contact__r.Name;
                                ubrl.Payee_Id__c = jelItem.Contact__c;
                            } else if (jelItem.Employee__c != NULL) {
                                ubrl.Payee_Name__c = jelItem.Employee__r.Name;
                                ubrl.Payee_Id__c = jelItem.Employee__c;
                            }
                            ubrl.Reference__c = jelItem.Reference__c;
                            ubrl.Type__c = jelItem.Debit__c != NULL ? debitType : creditType;
                            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                                ubrl.put('CurrencyIsoCode', (String) jelItem.get('CurrencyIsoCode'));
                            }
                            ubrls.add(ubrl);
                        }
                        when Bank_Disbursement__c bankDisbItem {
                            ubrl.Bank_Disbursement__c = bankDisbItem.Id;
                            ubrl.Related_Source_Document__c = bankDisbItem.Name;
                            ubrl.Amount__c = bankDisbItem.Amount__c;
                            ubrl.Ledger_Amount__c = bankDisbItem.Ledger_Amount__c;
                            ubrl.Cleared_Date__c = bankDisbItem.Cleared_Date__c;
                            ubrl.Date__c = bankDisbItem.Disbursement_Date__c;
                            ubrl.Reference__c = bankDisbItem.Disbursement_Reference__c;
                            ubrl.Type__c = bankDisbItem.Amount__c < 0 ? debitType : creditType;
                            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                                ubrl.put('CurrencyIsoCode', (String) bankDisbItem.get('CurrencyIsoCode'));
                            }
                            ubrls.add(ubrl);
                        }
                    }
                }
                UnclearedBankReconciliationLineActions.isPreventInsertOverride = true;
                SFDCSecurityUtils.insertProxy(ubrls);
                serviceResult = new ServiceResult(model.record.Id, true);
            } else {
                ServiceResult.Error error = new ServiceResult.Error();
                error.detail = UBRLS_EXIST;
                error.code = StatusCode.UBRLS_EXIST.Name();
                serviceResult = new ServiceResult(model.record.Id, false, new ServiceResult.Error[]{error});
            }
        } catch (Exception ex) {
            serviceResult = new ServiceResult(model.record.Id, ex.getTypeName(), ex.getMessage());
        }
        return serviceResult;
    }

    private BankReconciliationModel retrieveCount(){
        action = BankReconciliationAction.RETRIEVE_ALL;
        getRecordCounts();
        return model;
    }

    private ServiceResult setUnclearedValues() {
        ServiceResult serviceResult;
        try {
            Decimal unclearedDeposits = 0;
            Decimal unclearedPayments = 0;
            BankReconciliationModel brm = retrieve(false, true);
            
            String amountField;
            String currencyIsoCode;

            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                currencyIsoCode = (String) model.record.get('CurrencyIsoCode');
            }

            if (BankManagerHelper.needShowLedgerAmount((String) model.record.get('Ledger__c'), currencyIsoCode)) {
                amountField = 'Ledger_Amount__c';
            }
            else {
                amountField = 'Amount__c';
            }

            for (SObject item : brm.items) {
                switch on item {
                    when Cash_Disbursement__c cd {
                        Decimal amount = (Decimal)cd.get(amountField);
                        if(amount < 0){
                            unclearedDeposits += Math.abs(amount);
                        }else {
                            unclearedPayments += amount;
                        }
                    }
                    when Cash_Receipt__c cr {
                        Decimal amount = (Decimal)cr.get(amountField);
                        if(amount < 0){
                            unclearedPayments += Math.abs(amount);
                        }else {
                            unclearedDeposits += amount;
                        }
                    }
                    when Bank_Deposit__c bd {
                        Decimal amount = (Decimal)bd.get(amountField);
                        if(amount < 0){
                            unclearedPayments += Math.abs(amount);
                        }else {
                            unclearedDeposits += amount;
                        }
                    }
                    // negative JEL will still show as negative in the calculator, negative from other source docs will use abs value
                    when Journal_Entry_Line__c jel {
                        Decimal amount = (Decimal) jel.get(amountField);
                        if (jel.Credit__c != NULL) {
                            unclearedPayments += amount;
                        } else {
                            unclearedDeposits += amount;
                        }
                    }
                    when Bank_Disbursement__c bd {
                        Decimal amount = (Decimal)bd.get(amountField);
                        if(amount < 0){
                            unclearedDeposits += Math.abs(amount);
                        }else {
                            unclearedPayments += amount;
                        }
                    }
                }
            }

            model.record.Uncleared_Deposits__c = unclearedDeposits;
            model.record.Uncleared_Payments__c = unclearedPayments;

            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Bank_Reconciliation2__c.UnCleared_Deposits__c,
                    Bank_Reconciliation2__c.UnCleared_Payments__c
                }
            );
            SFDCSecurityUtils.updateProxy(model.record);
            TriggerObserver.reset();

            serviceResult = new ServiceResult(model.record.Id, true);
        }
        catch (Exception ex) {
            serviceResult = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }
        return serviceResult;
    }

    private void queryRecords() {
        if (validateInput()) {
            model.record = queryBankReconciliationById();
            model.items = new List<SObject>();
            retrieveSourceRecord(queryCashDisbursements());
            retrieveSourceRecord(queryCashReceipts());
            retrieveSourceRecord(queryJournalEntryLines());
            retrieveSourceRecord(queryBankDeposits());
            retrieveSourceRecord(queryBankDisbursements());
            if (isRetrieveAllOrUncleared() && isCompletedStatus()) {
                retrieveSourceRecord(queryUnclearedBankReconciliationLine());
            }
        }
    }

    private void getRecordCounts() {
        if (validateInput()) {
            model.record = queryBankReconciliationById();
            model.items = new List<SObject>();
            model.recordCount = 0;
            handleRecordCount(queryRecordCount('Cash_Receipt__c')); 
            handleRecordCount(queryRecordCount('Cash_Disbursement__c'));     
            handleRecordCount(queryRecordCount('Bank_Deposit__c')); 
            handleRecordCount(queryRecordCount('Journal_Entry_Line__c')); 
            handleRecordCount(queryRecordCount('Bank_Disbursement__c')); 
        }
    }

    private void handleRecordCount(List<AggregateResult> records) {
        for (AggregateResult ar : records) {
            model.recordCount += (Integer)ar.get('expr0');
        }
    }

    private void retrieveSourceRecord(List<SObject> records) {
        if (action == BankReconciliationAction.RETRIEVE1
            || action == BankReconciliationAction.RETRIEVE_ALL
            || action == BankReconciliationAction.RETRIEVE_UNCLEARED) {
            for (SObject obj : records) {
                model.items.add(obj);
            }
        }
    }

    private void processSourceRecords(List<SObject> records) {
        if (records != NULL && !records.isEmpty()) {
            Set<Id> ledgerIds = getValidLedgerIds();
            for (SObject obj : records) {
                BankReconciliationItemWrapper bankRecItemWrapped = new BankReconciliationItemWrapper(obj, model.record);
                if (action == BankReconciliationAction.CLEAR) {
                    if (itemToClearedDate != NULL && itemToClearedDate.containsKey(obj.Id)) {
                        bankRecItemWrapped.setClearedDate(itemToClearedDate.get(obj.Id));
                    }
                    clearSourceRecord(bankRecItemWrapped, ledgerIds);
                }
                else if (action == BankReconciliationAction.UNCLEAR) {
                    unclearSourceRecord(bankRecItemWrapped);
                }
            }
        }
    }

    private void clearSourceRecord(BankReconciliationItemWrapper bankRecItemWrapped, Set<Id> ledgerIds) {
        if (bankRecItemWrapped.validateForClear(ledgerIds)) {
            bankReconciliationItemRecordsToUpdate.add(bankRecItemWrapped.item);
        }
        else {
            serviceResult.results.add(
                new ServiceResult(
                    bankRecItemWrapped.item.Id,
                    StatusCode.INVALID_CLEAR_RECORD.name(), INVALID_CLEAR_RECORD
                )
            );
        }
    }

    private void unclearSourceRecord(BankReconciliationItemWrapper bankRecItemWrapped) {
        if (bankRecItemWrapped.validateForUnclear()) {
            bankReconciliationItemRecordsToUpdate.add(bankRecItemWrapped.item);
        }
        else {
            serviceResult.results.add(
                new ServiceResult(
                    bankRecItemWrapped.item.Id,
                    StatusCode.INVALID_UNCLEAR_RECORD.name(), INVALID_UNCLEAR_RECORD
                )
            );
        }
    }

    private Boolean validateInput() {
        ServiceResult.Error error = new ServiceResult.Error();

        if (model == NULL) {
            error.detail = NO_INPUT_DATA;
            error.code = StatusCode.NO_INPUT_DATA.name();
        }
        else if (!FinancialSuiteUtils.isValidId(model.record.Id, Bank_Reconciliation2__c.SObjectType)) {
            error.detail = INVALID_RECORD_OR_ID;
            error.code = StatusCode.INVALID_RECORD_OR_ID.name();
        }
        else if ((action == BankReconciliationAction.CLEAR || action == BankReconciliationAction.UNCLEAR)
                    && (itemIds == NULL || itemIds.isEmpty())) {

            error.detail = NO_RECONCILIATION_ITEMS;
            error.code = StatusCode.NO_RECONCILIATION_ITEMS.name();
        }
        else if (itemIds != NULL && itemIds.size() > BANK_RECONCILIATION_ITEM_LIMIT && !bypassItemLimit) {
            error.detail = String.format(OVER_RECONCILIATION_ITEM_LIMIT, new String[]{String.valueOf(BANK_RECONCILIATION_ITEM_LIMIT)});
            error.code = StatusCode.OVER_RECONCILIATION_ITEM_LIMIT.name();
        }

        if (error.detail != NULL) {
            serviceResult = new ServiceResult(NULL, false, new ServiceResult.Error[]{error});
        }
        else {
            serviceResult = new ServiceResult(model.record.Id, true);
        }

        return serviceResult.isSuccess;
    }

    private void validateItemIds() {
        List<Id> tempItemIds = new List<Id>();

        for (Id itemId : itemIds) {
            if (FinancialSuiteUtils.isValidId(itemId, Cash_Disbursement__c.SObjectType)
                    || FinancialSuiteUtils.isValidId(itemId, Cash_Receipt__c.SObjectType)
                    || FinancialSuiteUtils.isValidId(itemId, Journal_Entry_Line__c.SObjectType)
                    || FinancialSuiteUtils.isValidId(itemId, Bank_Deposit__c.SObjectType)
                    || FinancialSuiteUtils.isValidId(itemId, Bank_Disbursement__c.SObjectType)) {

                tempItemIds.add(itemId);
            }
            else {
                serviceResult.results.add(new ServiceResult(itemId, StatusCode.INVALID_RECORD_OR_ID.name(), INVALID_RECORD_OR_ID));
            }
        }

        itemIds = tempItemIds;
    }

    
    private Boolean validateModernBR() {
        ServiceResult.Error error = new ServiceResult.Error();

        if (!model.record.Modern_BR__c && isSubsequentBankRecCompleted()) {
            String errorMsg = String.format(
                INVALID_CLEAR_UNCLEAR_LEGACY,
                new List<String>{action == BankReconciliationAction.CLEAR ? Label.COMMON_SMALL_CLEAR : Label.COMMON_SMALL_UNCLEAR}
            );
            error.detail = errorMsg;
            error.code = StatusCode.INVALID_CLEAR_UNCLEAR_LEGACY.Name();
        }

        if (error.detail != NULL) {
            serviceResult = new ServiceResult(NULL, false, new ServiceResult.Error[]{error});
        }
        else {
            serviceResult = new ServiceResult(model.record.Id, true);
        }

        return serviceResult.isSuccess;
    }

    private Boolean isSubsequentBankRecCompleted() {
        BankReconciliationActions.BankReconciliationStatusProcessor brecProcessor
            = new BankReconciliationActions.BankReconciliationStatusProcessor();
        brecProcessor.newRecord = model.record;
        brecProcessor.relatedBankRecs = DomainUtils.getRelatedBankRecs(brecProcessor.newRecord);

        return brecProcessor.isSubsequentBankRecCompleted();
    }

    private Boolean validateRelatedItemCount() {
        BankReconciliationModel countResult = BankReconciliation.retrieveItemCount(model.record.Id);
        if (countResult.recordCount > MAX_CLEARABLE_RECORDS_PER_BANK_REC) {
            ServiceResult.Error error = new ServiceResult.Error();
            error.detail = String.format(
                NON_SELECTIVE_BANK_RECONCILIATION, 
                new String[]{String.valueOf(MAX_CLEARABLE_RECORDS_PER_BANK_REC), String.valueOf(countResult.recordCount)}
            );
            error.code = StatusCode.CLEARABLE_ITEM_LIMIT.name();
            error.id = model.record.id;
            serviceResult = new ServiceResult(model.record.id, false, new ServiceResult.Error[]{error});
        }
        return serviceResult.isSuccess;
    }

    private Boolean isCompletedStatus() {
        return model.record.Status__c == COMPLETED;
    }

    private Boolean isWorkingStatus() {
        return model.record.Status__c == WORKING;
    }

    private Boolean isRetrieveAllOrUncleared() {
        return (action == BankReconciliationAction.RETRIEVE_ALL
            || action == BankReconciliationAction.RETRIEVE_UNCLEARED);
    }

    private Bank_Reconciliation2__c queryBankReconciliationById() {
        Id bankRecId = model.record.Id;
        Bank_Reconciliation2__c result;
        try {
            List<String> queryFields = new List<String>{
                'Id',
                'Name',
                'Bank_Account__c',
                'GL_Account_Variable_1__c',
                'GL_Account_Variable_2__c',
                'GL_Account_Variable_3__c',
                'GL_Account_Variable_4__c',
                'Ledger__c',
                'Status__c',
                'End_Date__c',
                'Cleared_Deposits__c',
                'Cleared_Disbursements__c',
                'Beginning_Balance__c',
                'Ending_Balance__c',
                'Modern_BR__c',
                'Type__c'
            };

            if (isMultiCurrencyEnabled) {
                queryFields.add('CurrencyIsoCode');
                queryFields.add('Ledger__r.CurrencyIsoCode');
            }

            String queryCondition = 'Id = :bankRecId';

            SOQLBuilder theQuery = new SOQLBuilder(Bank_Reconciliation2__c.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition);

            result = (Bank_Reconciliation2__c) Database.query(theQuery.toSOQL());
        }
        catch (Exception ex) {
            throw ex;
        }
        return result;
    }

    private Integer getQueryLimit() {
        if (System.isBatch()) {
            // batch context: limit is based on available query rows
            return Limits.getLimitQueryRows() - Limits.getQueryRows();
        } else if (model != null && model.items != null) {
            // non-batch: limit is based on current size of
            // model.items to avoid heap size limit
            Integer lim = QUERY_LIMIT_PER_SRC_DOC - model.items.size();
            return lim < 0 ? 0 : lim;
        }
        // in all other cases default to max allowable records
        return QUERY_LIMIT_PER_SRC_DOC;
    }

    private List<AggregateResult> queryRecordCount(String objAPIName) {
        Id bankReconciliationId = model.record.Id;
        Date endDate = model.record.End_Date__c;
        String bankAccount = model.record.Bank_Account__c;
        Id ledgerId = model.record.Ledger__c;
        String glavVar1 = model.record.GL_Account_Variable_1__c;
        String glavVar2 = model.record.GL_Account_Variable_2__c;
        String glavVar3 = model.record.GL_Account_Variable_3__c;
        String glavVar4 = model.record.GL_Account_Variable_4__c;
        String currencyIsoCode = getModelRecordCurrency();

        String queryString = 'SELECT COUNT(Id) FROM ';
        queryString += objAPIName + ' WHERE ';
        String queryCondition;
        switch on objAPIName {
            when 'Cash_Receipt__c' {
                queryCondition = getCRQueryCondition();
            }
            when 'Cash_Disbursement__c' {
                queryCondition = getCDQueryCondition();
            }
            when 'Bank_Deposit__c' {
                queryCondition = getBDQueryCondition();
            }
            when 'Journal_Entry_Line__c' {
                queryCondition = getJELQueryCondition();
            }
            when 'Bank_Disbursement__c' {
                queryCondition = getBankDisbQueryCondition();
            }
        }        
        return new List<AggregateResult>((AggregateResult[])Database.query(queryString + queryCondition));        
    }

    private List<Cash_Disbursement__c> queryCashDisbursements() {
        List<Cash_Disbursement__c> result;
        try {
            List<String> queryFields = new List<String>{
                'Id',
                'Name',
                'Amount__c',
                'Cleared_Date__c',
                'Bank_Reconciliation__c',
                'Bank_Account__c',
                'Bank_Disbursement__c',
                'Bank_Disbursement__r.Disbursement_Date__c',
                'Status__c',
                'Payment_Status__c',
                'Ledger__c',
                'Ledger_Amount__c',
                'GL_Account_Variable_1__c',
                'GL_Account_Variable_2__c',
                'GL_Account_Variable_3__c',
                'GL_Account_Variable_4__c',
                'Check_Number__c',
                'Reference__c',
                'Debit_GL_Account__c',
                'Debit_GL_Account__r.Name',
                'Debit_GL_Account__r.Bank__c',
                'Disbursement_Date__c',
                'Description__c',
                'Vendor__c',
                'Vendor__r.Name',
                'Contact__c',
                'Contact__r.Name',
                'Employee__c',
                'Employee__r.Name',
                'Payee__c',
                'Payee_Id__c',
                'Bank_Transaction__c',
                'Bank_Transaction__r.Name',
                'Bank_Reconciliation__r.Name',
                'Bank_Account__r.Name',
                'Bank_Reconciliation_Date__c'
            };

            if (isMultiCurrencyEnabled) {
                queryFields.addAll(new List<String>{'CurrencyIsoCode'});
            }

            Id bankReconciliationId = model.record.Id;
            Date endDate = model.record.End_Date__c;
            String bankAccount = model.record.Bank_Account__c;
            Id ledgerId = model.record.Ledger__c;
            String glavVar1 = model.record.GL_Account_Variable_1__c;
            String glavVar2 = model.record.GL_Account_Variable_2__c;
            String glavVar3 = model.record.GL_Account_Variable_3__c;
            String glavVar4 = model.record.GL_Account_Variable_4__c;
            String currencyIsoCode = getModelRecordCurrency();

            String queryCondition = getCDQueryCondition();
            SOQLBuilder.Ordering ordering = new SOQLBuilder.Ordering('Cash_Disbursement__c', 'Name', SOQLBuilder.SortOrder.ASCENDING);

            SOQLBuilder theQuery = new SOQLBuilder(Cash_Disbursement__c.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition)
                .addOrdering(ordering)
                .setLimit(getQueryLimit());

            result = (List<Cash_Disbursement__c>) Database.query(theQuery.toSOQL());
        }
        catch (Exception ex) {
            throw ex;
        }
        return result;
    }

    private String getCDQueryCondition() {
        String queryCondition = '';
        if (isRetrieveAllOrUncleared() && !isCompletedStatus()) {
            String voidCondition = '(Payment_Status__c != \'Void\' OR (Payment_Status__c = \'Void\' AND Void_Date__c > :endDate))';
            String dateCondition = 'Bank_Reconciliation__c = NULL AND Disbursement_Date__c <= :endDate';
            String matchingCriteria = '(Bank_Account__c = :bankAccount OR Debit_GL_Account__c = :bankAccount) '
                + getLedgerCondition() + getGlavsCondition() + getCurrencyCodeCondition();

            String queryOneCondition = '(Bank_Reconciliation__c = :bankReconciliationId AND ' + getPostedCondition() + ')';
            String queryTwoCondition = '(Bank_Reconciliation__c != NULL AND Bank_Reconciliation__c != :bankReconciliationId' +
                ' AND Bank_Reconciliation_Date__c > :endDate AND Disbursement_Date__c <= :endDate AND ' + getPostedCondition() + ' AND ' + matchingCriteria + ')';
            String queryThreeCondition = '(' + getPostedCondition() + ' AND ' + matchingCriteria + ' AND ' + dateCondition + ')';

            queryCondition = '(';
            if (action == BankReconciliationAction.RETRIEVE_ALL) {
                queryCondition += queryOneCondition + ' OR ';
            }

            queryCondition += queryTwoCondition + ' OR ' + queryThreeCondition + ')' +  getBankDisbursementCondition('Disbursement_Date__c', 'AND');
            queryCondition += ' AND ' + voidCondition;
        }
        else if (action == BankReconciliationAction.RETRIEVE1 || isCompletedStatus()) {
            queryCondition = 'Bank_Reconciliation__c = :bankReconciliationId';
        }
        else {
            queryCondition = 'Id IN :itemIds';
        }

        return queryCondition;
    }

    private List<Cash_Receipt__c> queryCashReceipts() {
        List<Cash_Receipt__c> result;
        try {
            List<String> queryFields = new List<String>{
                'Id',
                'Name',
                'Amount__c',
                'Cleared_Date__c',
                'Bank_Reconciliation__c',
                'Bank_Deposit__c',
                'Bank_Deposit__r.Deposit_Date__c',
                'Bank_Account__c',
                'Status__c',
                'Ledger__c',
                'Ledger_Amount__c',
                'GL_Account_Variable_1__c',
                'GL_Account_Variable_2__c',
                'GL_Account_Variable_3__c',
                'GL_Account_Variable_4__c',
                'Credit_GL_Account__c',
                'Credit_GL_Account__r.Name',
                'Credit_GL_Account__r.Bank__c',
                'Receipt_Date__c',
                'Payment_Reference__c',
                'Description__c',
                'Account__c',
                'Account__r.Name',
                'Bank_Transaction__c',
                'Bank_Transaction__r.Name',
                'Bank_Reconciliation__r.Name',
                'Bank_Account__r.Name',
                'Bank_Reconciliation_Date__c',
                'Check_Number__c',
                'Purpose__c',
                'Void__c'
            };

            if (isMultiCurrencyEnabled) {
                queryFields.add('CurrencyIsoCode');
            }

            Id bankReconciliationId = model.record.Id;
            Date endDate = model.record.End_Date__c;
            String bankAccount = model.record.Bank_Account__c;
            Id ledgerId = model.record.Ledger__c;
            String glavVar1 = model.record.GL_Account_Variable_1__c;
            String glavVar2 = model.record.GL_Account_Variable_2__c;
            String glavVar3 = model.record.GL_Account_Variable_3__c;
            String glavVar4 = model.record.GL_Account_Variable_4__c;
            String currencyIsoCode = getModelRecordCurrency();

            String queryCondition = getCRQueryCondition();
            SOQLBuilder.Ordering ordering = new SOQLBuilder.Ordering('Cash_Receipt__c', 'Name', SOQLBuilder.SortOrder.ASCENDING);
            SOQLBuilder theQuery = new SOQLBuilder(Cash_Receipt__c.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition)
                .addOrdering(ordering)
                .setLimit(getQueryLimit());

            result = (List<Cash_Receipt__c>) Database.query(theQuery.toSOQL());
        }
        catch (Exception ex) {
            throw ex;
        }
        return result;
    }

    private String getCRQueryCondition() {
        String queryCondition = '';
        if (isRetrieveAllOrUncleared() && !isCompletedStatus()) {
            String voidCondition = '(Void__c = false OR (Void__c = true AND Void_Date__c > :endDate))';
            String dateCondition = 'Bank_Reconciliation__c = NULL AND Receipt_Date__c <= :endDate';
            String matchingCriteria = '(Bank_Account__c = :bankAccount OR Credit_GL_Account__c = :bankAccount) '
                + getLedgerCondition() + getGlavsCondition() + getCurrencyCodeCondition();

            String queryOneCondition = '(Bank_Reconciliation__c = :bankReconciliationId AND ' + getPostedCondition() + ')';
            String queryTwoCondition = '(Bank_Reconciliation__c != NULL AND Bank_Reconciliation__c != :bankReconciliationId' +
                ' AND Bank_Reconciliation_Date__c > :endDate AND Receipt_Date__c <= :endDate AND ' + getPostedCondition() + ' AND ' + matchingCriteria + ')';
            String queryThreeCondition = '(' + getPostedCondition() + ' AND ' + matchingCriteria + ' AND ' + dateCondition + ')';

            queryCondition = '(';
            if (action == BankReconciliationAction.RETRIEVE_ALL) {
                queryCondition += queryOneCondition + ' OR ';
            }

            queryCondition += queryTwoCondition + ' OR ' + queryThreeCondition + ')' + getBankDepositCondition('Receipt_Date__c');
            queryCondition += ' AND ' + voidCondition;
        }
        else if (action == BankReconciliationAction.RETRIEVE1 || isCompletedStatus()) {
            queryCondition = 'Bank_Reconciliation__c = :bankReconciliationId';
        }
        else {
            queryCondition = 'Id IN :itemIds';
        }

        return queryCondition;
    }

    private List<Bank_Deposit__c> queryBankDeposits() {
        List<Bank_Deposit__c> result;
        try {
            List<String> queryFields = new List<String>{
                'Id',
                'Name',
                'Amount__c',
                'Cleared_Date__c',
                'Bank_Reconciliation__c',
                'Bank_Reconciliation__r.Name',
                'Ledger__c',
                'Ledger_Amount__c',
                'GL_Account_Variable_1__c',
                'GL_Account_Variable_2__c',
                'GL_Account_Variable_3__c',
                'GL_Account_Variable_4__c',
                'Bank_Account__c',
                'Bank_Account__r.Name',
                'Bank_Account__r.Bank__c',
                'Deposit_Date__c',
                'Deposit_Reference__c',
                'Bank_Transaction__c',
                'Bank_Transaction__r.Name',
                'Bank_Reconciliation_Date__c'
            };

            if (isMultiCurrencyEnabled) {
                queryFields.add('CurrencyIsoCode');
            }

            Id bankReconciliationId = model.record.Id;
            Date endDate = model.record.End_Date__c;
            String bankAccount = model.record.Bank_Account__c;
            Id ledgerId = model.record.Ledger__c;
            String glavVar1 = model.record.GL_Account_Variable_1__c;
            String glavVar2 = model.record.GL_Account_Variable_2__c;
            String glavVar3 = model.record.GL_Account_Variable_3__c;
            String glavVar4 = model.record.GL_Account_Variable_4__c;
            String currencyIsoCode = getModelRecordCurrency();

            String queryCondition = getBDQueryCondition();
            SOQLBuilder.Ordering ordering = new SOQLBuilder.Ordering('Bank_Deposit__c', 'Name', SOQLBuilder.SortOrder.ASCENDING);

            SOQLBuilder theQuery = new SOQLBuilder(Bank_Deposit__c.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition)
                .addOrdering(ordering)
                .setLimit(getQueryLimit());

            result = (List<Bank_Deposit__c>) Database.query(theQuery.toSOQL());
        }
        catch (Exception ex) {
            throw ex;
        }
        return result;
    }

    private String getBDQueryCondition() {
        String queryCondition = '';
        if (isRetrieveAllOrUncleared() && !isCompletedStatus()) {
            String dateCondition = 'Bank_Reconciliation__c = NULL AND Deposit_Date__c <= :endDate';
            String matchingCriteria = 'Bank_Account__c = :bankAccount '
                + getLedgerCondition() + getGlavsCondition() + getCurrencyCodeCondition();

            String queryOneCondition = 'Bank_Reconciliation__c = :bankReconciliationId';
            String queryTwoCondition = '(Bank_Reconciliation__c != NULL AND Bank_Reconciliation__c != :bankReconciliationId' +
                ' AND Bank_Reconciliation_Date__c > :endDate AND Deposit_Date__c <= :endDate AND ' + matchingCriteria + ')';
            String queryThreeCondition = '(' + matchingCriteria + ' AND ' + dateCondition + ')';

            if (action == BankReconciliationAction.RETRIEVE_ALL) {
                queryCondition = queryOneCondition + ' OR ';
            }
            queryCondition += queryTwoCondition + ' OR ' + queryThreeCondition;
        }
        else if (action == BankReconciliationAction.RETRIEVE1 || isCompletedStatus()) {
            queryCondition = 'Bank_Reconciliation__c = :bankReconciliationId';
        }
        else {
            queryCondition = 'Id IN :itemIds';
        }

        return queryCondition;
    }

    private List<Journal_Entry_Line__c> queryJournalEntryLines() {
        List<Journal_Entry_Line__c> result;
        try {
            List<String> queryFields = new List<String>{
                'Id',
                'Name',
                'Amount__c',
                'Credit__c',
                'Debit__c',
                'Ledger_Amount__c',
                'Cleared_Date__c',
                'Bank_Reconciliation__c',
                'Bank_Deposit__c',
                'Bank_Deposit__r.Deposit_Date__c',
                'Bank_Disbursement__c',
                'Bank_Disbursement__r.Disbursement_Date__c',
                'Journal_Entry__r.Status__c',
                'Journal_Entry__r.Ledger__c',
                'Journal_Entry__r.Journal_Date__c',
                'GL_Account_Variable_1__c',
                'GL_Account_Variable_2__c',
                'GL_Account_Variable_3__c',
                'GL_Account_Variable_4__c',
                'GL_Account__c',
                'GL_Account__r.Name',
                'Description__c',
                'Reference__c',
                'Account__c',
                'Account__r.Name',
                'Contact__c',
                'Contact__r.Name',
                'Employee__c',
                'Employee__r.Name',
                'Bank_Transaction__c',
                'Bank_Transaction__r.Name',
                'Bank_Reconciliation__r.Name',
                'Bank_Reconciliation_Date__c'
            };

            if (isMultiCurrencyEnabled) {
                queryFields.add('CurrencyIsoCode');
            }

            Id bankReconciliationId = model.record.Id;
            Date endDate = model.record.End_Date__c;
            String bankAccount = model.record.Bank_Account__c;
            Id ledgerId = model.record.Ledger__c;
            String glavVar1 = model.record.GL_Account_Variable_1__c;
            String glavVar2 = model.record.GL_Account_Variable_2__c;
            String glavVar3 = model.record.GL_Account_Variable_3__c;
            String glavVar4 = model.record.GL_Account_Variable_4__c;
            String currencyIsoCode = getModelRecordCurrency();

            String queryCondition = getJELQueryCondition();
            SOQLBuilder.Ordering ordering = new SOQLBuilder.Ordering('Journal_Entry_Line__c', 'Name', SOQLBuilder.SortOrder.ASCENDING);

            SOQLBuilder theQuery = new SOQLBuilder(Journal_Entry_Line__c.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition)
                .addOrdering(ordering)
                .setLimit(getQueryLimit());

            result = (List<Journal_Entry_Line__c>) Database.query(theQuery.toSOQL());
        }
        catch (Exception ex) {
            throw ex;
        }
        return result;
    }

    private String getJELQueryCondition() {
        String queryCondition = '';
        if (isRetrieveAllOrUncleared() && !isCompletedStatus()) {
            String headerPostedStatus = 'Journal_Entry__r.Status__c = \'Posted\'';
            String ledgerCondition = BankManagerHelper.getLedgerCondition(model.record.Ledger__c, 'Journal_Entry__r.Ledger__c');
            String dateCondition = 'Bank_Reconciliation__c = NULL AND Journal_Entry__r.Journal_Date__c <= :endDate';
            String matchingCriteria = 'GL_Account__c = :bankAccount '
                + ledgerCondition + getGlavsCondition() + getCurrencyCodeCondition();

            String queryOneCondition = '(Bank_Reconciliation__c = :bankReconciliationId AND ' + headerPostedStatus + ')';
            String queryTwoCondition = '(Bank_Reconciliation__c != NULL AND Bank_Reconciliation__c != :bankReconciliationId' +
                ' AND Bank_Reconciliation_Date__c > :endDate AND Journal_Entry__r.Journal_Date__c <= :endDate AND '
                + headerPostedStatus + ' AND ' + matchingCriteria + ')';
            String queryThreeCondition = '(' + headerPostedStatus + ' AND ' + matchingCriteria + ' AND ' + dateCondition + ')';

            queryCondition = '(';
            if (action == BankReconciliationAction.RETRIEVE_ALL) {
                queryCondition += queryOneCondition + ' OR ';
            }
            queryCondition += queryTwoCondition + ' OR ' + queryThreeCondition + ')'
                + getBankDepositCondition('Journal_Entry__r.Journal_Date__c') + getBankDisbursementCondition('Journal_Entry__r.Journal_Date__c', 'AND');
        }
        else if (action == BankReconciliationAction.RETRIEVE1 || isCompletedStatus()) {
            queryCondition = 'Bank_Reconciliation__c = :bankReconciliationId';
        }
        else {
            queryCondition = 'Id IN :itemIds';
        }

        return queryCondition;
    }

    private List<Bank_Disbursement__c> queryBankDisbursements() {
        List<Bank_Disbursement__c> result;
        try {
            List<String> queryFields = new List<String>{
                'Id',
                'Name',
                'Amount__c',
                'Cleared_Date__c',
                'Bank_Reconciliation__c',
                'Bank_Reconciliation__r.Name',
                'Ledger__c',
                'Ledger_Amount__c',
                'GL_Account_Variable_1__c',
                'GL_Account_Variable_2__c',
                'GL_Account_Variable_3__c',
                'GL_Account_Variable_4__c',
                'Bank_Account__c',
                'Bank_Account__r.Name',
                'Bank_GL_Account__c',
                'Bank_GL_Account__c.Bank__c',
                'Disbursement_Date__c',
                'Disbursement_Reference__c',
                'Bank_Transaction__c',
                'Bank_Transaction__r.Name',
                'Bank_Reconciliation_Date__c'
            };

            if (isMultiCurrencyEnabled) {
                queryFields.add('CurrencyIsoCode');
            }

            Id bankReconciliationId = model.record.Id;
            Date endDate = model.record.End_Date__c;
            String bankAccount = model.record.Bank_Account__c;
            Id ledgerId = model.record.Ledger__c;
            String glavVar1 = model.record.GL_Account_Variable_1__c;
            String glavVar2 = model.record.GL_Account_Variable_2__c;
            String glavVar3 = model.record.GL_Account_Variable_3__c;
            String glavVar4 = model.record.GL_Account_Variable_4__c;
            String currencyIsoCode = getModelRecordCurrency();

            String queryCondition = getBankDisbQueryCondition();
            SOQLBuilder.Ordering ordering = new SOQLBuilder.Ordering('Bank_Disbursement__c', 'Name', SOQLBuilder.SortOrder.ASCENDING);

            SOQLBuilder theQuery = new SOQLBuilder(Bank_Disbursement__c.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition)
                .addOrdering(ordering)
                .setLimit(getQueryLimit());

            result = (List<Bank_Disbursement__c>) Database.query(theQuery.toSOQL());
        }
        catch (Exception ex) {
            throw ex;
        }
        return result;
    }

    private String getBankDisbQueryCondition() {
        String queryCondition = '';
        if (isRetrieveAllOrUncleared() && !isCompletedStatus()) {
            String dateCondition = 'Bank_Reconciliation__c = NULL AND Disbursement_Date__c <= :endDate';
            String matchingCriteria = 'Bank_GL_Account__c = :bankAccount '
                + getLedgerCondition() + getGlavsCondition() + getCurrencyCodeCondition();

            String queryOneCondition = 'Bank_Reconciliation__c = :bankReconciliationId';
            String queryTwoCondition = '(Bank_Reconciliation__c != NULL AND Bank_Reconciliation__c != :bankReconciliationId' +
                ' AND Bank_Reconciliation_Date__c > :endDate AND Disbursement_Date__c <= :endDate AND ' + matchingCriteria + ')';
            String queryThreeCondition = '(' + matchingCriteria + ' AND ' + dateCondition + ')';

            if (action == BankReconciliationAction.RETRIEVE_ALL) {
                queryCondition = queryOneCondition + ' OR ';
            }
            queryCondition += queryTwoCondition + ' OR ' + queryThreeCondition;
        }
        else if (action == BankReconciliationAction.RETRIEVE1 || isCompletedStatus()) {
            queryCondition = 'Bank_Reconciliation__c = :bankReconciliationId';
        }
        else {
            queryCondition = 'Id IN :itemIds';
        }

        return queryCondition;
    }

    private List<Uncleared_Bank_Reconciliation_Line__c> queryUnclearedBankReconciliationLine() {
        List<Uncleared_Bank_Reconciliation_Line__c> result;
        try {
            List<String> queryFields = new List<String>{
                'Id',
                'Name',
                'Amount__c',
                'Ledger_Amount__c',
                'Bank_Deposit__c',
                'Bank_Deposit__r.Name',
                'Bank_Reconciliation__c',
                'Bank_Disbursement__c',
                'Bank_Disbursement__r.Name',
                'Cash_Disbursement__c',
                'Cash_Disbursement__r.Name',
                'Cash_Disbursement__r.Debit_GL_Account__c',
                'Cash_Disbursement__r.Check_Number__c',
                'Cash_Receipt__c',
                'Cash_Receipt__r.Name',
                'Cash_Receipt__r.Credit_GL_Account__c',
                'Cash_Receipt__r.Check_Number__c',
                'Cleared_Date__c',
                'Date__c',
                'Description__c',
                'Journal_Entry_Line__c',
                'Journal_Entry_Line__r.Name',
                'Journal_Entry_Line__r.Credit__c',
                'Journal_Entry_Line__r.Debit__c',
                'Payee_Id__c',
                'Payee_Name__c',
                'Reference__c',
                'Related_Source_Document__c',
                'Type__c'
            };

            if (isMultiCurrencyEnabled) {
                queryFields.add('CurrencyIsoCode');
            }

            Id bankReconciliationId = model.record.Id;

            String queryCondition = 'Bank_Reconciliation__c = :bankReconciliationId';
            SOQLBuilder.Ordering ordering = new SOQLBuilder.Ordering('Uncleared_Bank_Reconciliation_Line__c', 'Name', SOQLBuilder.SortOrder.ASCENDING);

            SOQLBuilder theQuery = new SOQLBuilder(Uncleared_Bank_Reconciliation_Line__c.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition)
                .addOrdering(ordering)
                .setLimit(50000);
            result = (List<Uncleared_Bank_Reconciliation_Line__c>) Database.query(theQuery.toSOQL());
        }
        catch (Exception ex) {
            throw ex;
        }
        return result;
    }

    private String getGlavsCondition() {
        return BankManagerHelper.getGlavVariablePredicate(
            model.record.GL_Account_Variable_1__c,
            model.record.GL_Account_Variable_2__c,
            model.record.GL_Account_Variable_3__c,
            model.record.GL_Account_Variable_4__c);
    }

    private String getCurrencyCodeCondition() {
        return BankManagerHelper.getCurrencyCondition(model.record.Ledger__c, getModelRecordCurrency());
    }

    private String getLedgerCondition() {
        return BankManagerHelper.getLedgerCondition(model.record.Ledger__c, 'Ledger__c');
    }

    private String getPostedCondition() {
        return 'Status__c = \'Posted\'';
    }

    private String getBankDepositCondition(String dateField) {
        if (action == BankReconciliationAction.UNCLEAR || isWorkingStatus()) {
            return ' AND (Bank_Deposit__c = NULL'
                + ' OR (Bank_Deposit__c != NULL AND Bank_Deposit__r.Deposit_Date__c > :endDate AND ' +
                dateField + ' <= :endDate))';
        }
        else {
            return ' AND Bank_Deposit__c = NULL';
        }
    }

    private String getBankDisbursementCondition(String dateField, string condition) {
        if (action == BankReconciliationAction.UNCLEAR || isWorkingStatus()) {
            return ' ' + condition + ' (Bank_Disbursement__c = NULL'
                + ' OR (Bank_Disbursement__c != NULL AND Bank_Disbursement__r.Disbursement_Date__c > :endDate AND ' +
                dateField + ' <= :endDate))';
        }
        else {
            return ' ' + condition + ' Bank_Disbursement__c = NULL';
        }
    }

    private String getModelRecordCurrency() {
        String result = '';
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            result = (String) model.record.get('CurrencyIsoCode');
        }
        return result;
    }

    private Set<Id> getValidLedgerIds() {
        Set<Id> validLedgerIds;

        if (model.record.Ledger__c == NULL) {
            //if bank rec is legacy record
            validLedgerIds = new Set<Id>{LedgerHandler.getLegacyDefaultLedgerId(), NULL};
        }
        else if (LedgerHandler.isLedgerEqualLegacyLedger(model.record.Ledger__c)) {
            //if bank rec is not legacy but there may be legacy transactions
            validLedgerIds = new Set<Id>{model.record.Ledger__c, NULL};
        }
        else {
            validLedgerIds = new Set<Id>{model.record.Ledger__c};
        }

        return validLedgerIds;
    }

    public with sharing class BankReconciliationItemWrapper {
        private SObject item;
        private Bank_Reconciliation2__c bankReconciliation;

        public BankReconciliationItemWrapper(SObject obj, Bank_Reconciliation2__c bankReconciliation) {
            item = obj;
            this.bankReconciliation = bankReconciliation;
        }

        public void setClearedDate(Date clearedDate) {
            if (this.item != NULL) {
                this.item.put('Cleared_Date__c', clearedDate);
            }
        }

        private Boolean validateForClear(Set<Id> validLedgerIds) {
            return isValidByLedger(validLedgerIds)
                && isValidByBankReconciliation()
                && isValidByBankDeposit()
                && isValidByBankDisbursement()
                && isValidByPostingStatus()
                && isValidByGlavs()
                && isValidByCurrency()
                && isValidByCDVoid()
                && isValidByCRVoid()
                ;
        }

        private Boolean validateForUnclear() {
            return getBankReconciliationId() == bankReconciliation.Id;
        }

        private Boolean isValidByLedger(Set<Id> validLedgerIds) {
            return validLedgerIds.contains(getLedgerId());
        }

        private Boolean isValidByBankReconciliation() {
            return getBankReconciliationId() == NULL;
        }

        private Boolean isValidByBankDeposit() {
            return getBankDepositId() == NULL;
        }

        private Boolean isValidByBankDisbursement() {
            return getBankDisbursementId() == NULL;
        }

        private Boolean isValidByPostingStatus() {
            return getPostingStatus() == AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED;
        }

        private Boolean isValidByCurrency() {
            Boolean result = true;
            if (MultiCurrencyHandler.isMultiCurrencyEnabled && !isSameBRCurrencyAsLedger() && !isSameCurrencyAsBankRecCurrency()) {
                result = false;
            }
            return result;
        }

        private Boolean isValidByCDVoid() {
            Boolean result = true;
            switch on item {
                when Cash_Disbursement__c cashDisbursement {
                    if (cashDisbursement.Payment_Status__c == 'Void' || cashDisbursement.Status__c == 'Void') {
                        result = false;
                    }
                }
            }
            return result;
        }

        private Boolean isValidByCRVoid() {
            Boolean result = true;
            switch on item {            
                when Cash_Receipt__c cashReceipt {
                    if (cashReceipt.Void__c) {
                        result = false;
                    }
                }
            }

            return result;
        }


        private Boolean isSameCurrencyAsBankRecCurrency() {
            return (String) bankReconciliation.get('CurrencyIsoCode') == (String) item.get('CurrencyIsoCode');
        }

        private Boolean isSameBRCurrencyAsLedger() {
            String ledgerIsoCode = bankReconciliation.Ledger__c != NULL
                ? (String) bankReconciliation.getSObject('Ledger__r').get('CurrencyIsoCode') :
                LedgerHandler.getLedgerCurrency(LedgerHandler.getLegacyDefaultLedgerId());
            return (String) bankReconciliation.get('CurrencyIsoCode') == ledgerIsoCode;
        }
      
        private Boolean isValidByGlavs() {
            Boolean retVal = TRUE;

            if (bankReconciliation.GL_Account_Variable_1__c != NULL
                    && (Id) item.get('GL_Account_Variable_1__c') != bankReconciliation.GL_Account_Variable_1__c) {
                retVal = FALSE;
            }

            if (bankReconciliation.GL_Account_Variable_2__c != NULL
                    && (Id) item.get('GL_Account_Variable_2__c') != bankReconciliation.GL_Account_Variable_2__c) {
                retVal = FALSE;
            }

            if (bankReconciliation.GL_Account_Variable_3__c != NULL
                    && (Id) item.get('GL_Account_Variable_3__c') != bankReconciliation.GL_Account_Variable_3__c) {
                retVal = FALSE;
            }

            if (bankReconciliation.GL_Account_Variable_4__c != NULL
                    && (Id) item.get('GL_Account_Variable_4__c') != bankReconciliation.GL_Account_Variable_4__c) {
                retVal = FALSE;
            }

            return retVal;
        }

        private String getPostingStatus() {
            String postStatus;

            switch on item {
                when Cash_Disbursement__c cashDisbursement {
                    postStatus = cashDisbursement.Status__c;
                }
                when Cash_Receipt__c cashReceipt {
                    postStatus = cashReceipt.Status__c;
                }
                when Journal_Entry_Line__c journalEntryLine {
                    postStatus = journalEntryLine.Journal_Entry__r.Status__c;
                }
                when else {
                    postStatus = AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED;
                }
            }

            return postStatus;
        }

        private Id getLedgerId() {
            Id ledgerId;

            switch on item {
                when Cash_Disbursement__c cashDisbursement {
                    ledgerId = cashDisbursement.Ledger__c;
                }
                when Cash_Receipt__c cashReceipt {
                    ledgerId = cashReceipt.Ledger__c;
                }
                when Journal_Entry_Line__c journalEntryLine {
                    ledgerId = journalEntryLine.Journal_Entry__r.Ledger__c;
                }
                when Bank_Deposit__c bankDeposit {
                    ledgerId = bankDeposit.Ledger__c;
                }
                when Bank_Disbursement__c bankDisbursement {
                    ledgerId = bankDisbursement.Ledger__c;
                }
            }

            return ledgerId;
        }

        private Id getBankAccountId() {
            Id bankAccountId;

            switch on item {
                when Cash_Disbursement__c cashDisbursement {
                    bankAccountId = cashDisbursement.Bank_Account__c;
                }
                when Cash_Receipt__c cashReceipt {
                    bankAccountId = cashReceipt.Bank_Account__c;
                }
                when Journal_Entry_Line__c journalEntryLine {
                    bankAccountId = journalEntryLine.GL_Account__c;
                }
                when Bank_Deposit__c bankDeposit {
                    bankAccountId = bankDeposit.Bank_Account__c;
                }
                when Bank_Disbursement__c bankDisbursement {
                    bankAccountId = bankDisbursement.Bank_GL_Account__c;
                }
            }

            return bankAccountId;
        }

        private Id getBankDepositId() {
            Id bankDepositId;

            switch on item {
                when Cash_Receipt__c cashReceipt {
                    bankDepositId = cashReceipt.Bank_Deposit__c;
                }
                when Journal_Entry_Line__c journalEntryLine {
                    bankDepositId = journalEntryLine.Bank_Deposit__c;
                }
            }

            return bankDepositId;
        }

        private Id getBankDisbursementId() {
            Id bankDisbId;

            switch on item {
                when Cash_Disbursement__c cashDisb {
                    bankDisbId = cashDisb.Bank_Disbursement__c;
                }
                when Journal_Entry_Line__c journalEntryLine {
                    bankDisbId = journalEntryLine.Bank_Disbursement__c;
                }
            }

            return bankDisbId;
        }

        private Id getBankReconciliationId() {
            Id bankRecId;

            switch on item {
                when Cash_Disbursement__c cashDisbursement {
                    bankRecId = cashDisbursement.Bank_Reconciliation__c;
                }
                when Cash_Receipt__c cashReceipt {
                    bankRecId = cashReceipt.Bank_Reconciliation__c;
                }
                when Journal_Entry_Line__c journalEntryLine {
                    bankRecId = journalEntryLine.Bank_Reconciliation__c;
                }
                when Bank_Deposit__c bankDeposit {
                    bankRecId = bankDeposit.Bank_Reconciliation__c;
                }
                when Bank_Disbursement__c bankDisbursement {
                    bankRecId = bankDisbursement.Bank_Reconciliation__c;
                }
            }

            return bankRecId;
        }
    }

    // ================ Reconciliation Handler =================================

    private void clearItems(List<SObject> sObjectList) {
        Savepoint sp = Database.setSavepoint();
        try {
            List<Cash_Receipt__c> cashReceiptList = new List<Cash_Receipt__c>();
            List<Bank_Deposit__c> bankDepositList = new List<Bank_Deposit__c>();
            List<Cash_Disbursement__c> cashDisbursementList = new List<Cash_Disbursement__c>();
            List<Journal_Entry_Line__c> journalEntryLineList = new List<Journal_Entry_Line__c>();
            List<Bank_Disbursement__c> bankDisbursementList = new List<Bank_Disbursement__c>();

            for (SObject obj : sObjectList) {
                if (obj.get('Bank_Reconciliation__c') == NULL) {
                    obj.put('Bank_Reconciliation__c', model.record.Id);
                }

                switch on obj {
                    when Journal_Entry_Line__c objRecord {
                        journalEntryLineList.add((Journal_Entry_Line__c) objRecord);
                    }
                    when Cash_Disbursement__c objRecord {
                        cashDisbursementList.add((Cash_Disbursement__c) objRecord);
                    }
                    when Cash_Receipt__c objRecord {
                        cashReceiptList.add((Cash_Receipt__c) objRecord);
                    }
                    when Bank_Deposit__c objRecord {
                        bankDepositList.add((Bank_Deposit__c) objRecord);
                    }
                    when Bank_Disbursement__c objRecord {
                        bankDisbursementList.add((Bank_Disbursement__c) objRecord);
                    }
                }
            }

            if (!journalEntryLineList.isEmpty()) {
                TriggerObserver.getInstance().unlockField(Journal_Entry_Line__c.Bank_Reconciliation__c);
                SFDCSecurityUtils.updateCheckCRUDAndFLS(journalEntryLineList, new List<String>{
                    'Bank_Reconciliation__c'
                });
                TriggerObserver.purgeUnlockedFields(Journal_Entry_Line__c.Bank_Reconciliation__c);
            }

            if (!cashDisbursementList.isEmpty()) {
                TriggerObserver.getInstance().unlockField(Cash_Disbursement__c.Bank_Reconciliation__c);
                SFDCSecurityUtils.updateCheckCRUDAndFLS(cashDisbursementList, new List<String>{
                    'Bank_Reconciliation__c'
                });
                TriggerObserver.purgeUnlockedFields(Cash_Disbursement__c.Bank_Reconciliation__c);
            }

            if (!cashReceiptList.isEmpty()) {
                TriggerObserver.getInstance().unlockField(Cash_Receipt__c.Bank_Reconciliation__c);
                SFDCSecurityUtils.updateCheckCRUDAndFLS(cashReceiptList, new List<String>{
                    'Bank_Reconciliation__c'
                });
                TriggerObserver.purgeUnlockedFields(Cash_Receipt__c.Bank_Reconciliation__c);
            }

            if (!bankDepositList.isEmpty()) {
                TriggerObserver.getInstance().unlockField(Bank_Deposit__c.Bank_Reconciliation__c);
                SFDCSecurityUtils.updateCheckCRUDAndFLS(bankDepositList, new List<String>{
                    'Bank_Reconciliation__c'
                });
                TriggerObserver.purgeUnlockedFields(Bank_Deposit__c.Bank_Reconciliation__c);
            }

            if (!bankDisbursementList.isEmpty()) {
                TriggerObserver.getInstance().unlockField(Bank_Disbursement__c.Bank_Reconciliation__c);
                SFDCSecurityUtils.updateCheckCRUDAndFLS(bankDisbursementList, new List<String>{
                    'Bank_Reconciliation__c'
                });
                TriggerObserver.purgeUnlockedFields(Bank_Disbursement__c.Bank_Reconciliation__c);
            }

            calculateClearedDepositAndClearedDisbursement();
        }
        catch (Exception ex) {
            Database.rollback(sp);
            throw ex;
        }

    }

    private void unclearItems(List<SObject> sObjectList) {

        Savepoint sp = Database.setSavepoint();
        try {
            List<Cash_Receipt__c> cashReceiptList = new List<Cash_Receipt__c>();
            List<Bank_Deposit__c> bankDepositList = new List<Bank_Deposit__c>();
            List<Cash_Disbursement__c> cashDisbursementList = new List<Cash_Disbursement__c>();
            List<Journal_Entry_Line__c> journalEntryLineList = new List<Journal_Entry_Line__c>();
            List<Bank_Disbursement__c> bankDisbursementList = new List<Bank_Disbursement__c>();

            for (SObject obj : sObjectList) {
                obj.put('Bank_Reconciliation__c', NULL);

                switch on obj {
                    when Journal_Entry_Line__c objRecord {
                        journalEntryLineList.add((Journal_Entry_Line__c) objRecord);
                    }
                    when Cash_Disbursement__c objRecord {
                        cashDisbursementList.add((Cash_Disbursement__c) objRecord);
                    }
                    when Cash_Receipt__c objRecord {
                        cashReceiptList.add((Cash_Receipt__c) objRecord);
                    }
                    when Bank_Deposit__c objRecord {
                        bankDepositList.add((Bank_Deposit__c) objRecord);
                    }
                    when Bank_Disbursement__c objRecord {
                        bankDisbursementList.add((Bank_Disbursement__c) objRecord);
                    }
                }
            }

            if (!journalEntryLineList.isEmpty()) {
                TriggerObserver.getInstance().unlockField(Journal_Entry_Line__c.Bank_Reconciliation__c);
                SFDCSecurityUtils.updateCheckCRUDAndFLS(journalEntryLineList, new List<String>{
                    'Bank_Reconciliation__c'
                });
                TriggerObserver.purgeUnlockedFields(Journal_Entry_Line__c.Bank_Reconciliation__c);
            }

            if (!cashDisbursementList.isEmpty()) {
                TriggerObserver.getInstance().unlockField(Cash_Disbursement__c.Bank_Reconciliation__c);
                SFDCSecurityUtils.updateCheckCRUDAndFLS(cashDisbursementList, new List<String>{
                    'Bank_Reconciliation__c'
                });
                TriggerObserver.purgeUnlockedFields(Cash_Disbursement__c.Bank_Reconciliation__c);
            }

            if (!cashReceiptList.isEmpty()) {
                TriggerObserver.getInstance().unlockField(Cash_Receipt__c.Bank_Reconciliation__c);
                SFDCSecurityUtils.updateCheckCRUDAndFLS(cashReceiptList, new List<String>{
                    'Bank_Reconciliation__c'
                });
                TriggerObserver.purgeUnlockedFields(Cash_Receipt__c.Bank_Reconciliation__c);
            }

            if (!bankDepositList.isEmpty()) {
                TriggerObserver.getInstance().unlockField(Bank_Deposit__c.Bank_Reconciliation__c);
                SFDCSecurityUtils.updateCheckCRUDAndFLS(bankDepositList, new List<String>{
                    'Bank_Reconciliation__c'
                });
                TriggerObserver.purgeUnlockedFields(Bank_Deposit__c.Bank_Reconciliation__c);
            }

            if (!bankDisbursementList.isEmpty()) {
                TriggerObserver.getInstance().unlockField(Bank_Disbursement__c.Bank_Reconciliation__c);
                SFDCSecurityUtils.updateCheckCRUDAndFLS(bankDisbursementList, new List<String>{
                    'Bank_Reconciliation__c'
                });
                TriggerObserver.purgeUnlockedFields(Bank_Disbursement__c.Bank_Reconciliation__c);
            }

            calculateClearedDepositAndClearedDisbursement();
        }
        catch (Exception ex) {
            Database.rollback(sp);
            throw ex;
        }
    }

    private void calculateClearedDepositAndClearedDisbursement() {
        try {
            Decimal result;
            String currencyIsoCode;
            SObjectField amountField;
            model.record.Cleared_Deposits__c = 0;
            model.record.Cleared_Disbursements__c = 0;

            if (isMultiCurrencyEnabled) {
                currencyIsoCode = (String) model.record.get('CurrencyIsoCode');
            }

            //==================================================================================================
            // CRUD and FLS are handled and checked in the BankReconciliationManager class
            // Performing CRUD and FLS would be a redundant check for aggregate query
            //==================================================================================================

            //For BDs, CRs, JEs and CDs we can aggregate Amount using either Amount__c or Ledger_Amount__c fields
            if (BankManagerHelper.needShowLedgerAmount((String) model.record.get('Ledger__c'), currencyIsoCode)) {
                amountField = Cash_Receipt__c.Ledger_Amount__c;
            }
            else {
                amountField = Cash_Receipt__c.Amount_Number__c;
            }
            //Aggregate all Bank Deposits Amounts using either Amount__c or Ledger_Amount__c fields (in org currency)
            result = DomainUtils.getBankDepositAmount(model.record.Id, amountField, Bank_Deposit__c.Bank_Reconciliation__c);
            if (result != NULL) {
                model.record.Cleared_Deposits__c += result;
            }
            result = DomainUtils.getNegativeBankDepositAmount(model.record.Id, amountField, Bank_Deposit__c.Bank_Reconciliation__c);
            if (result != NULL) {
                model.record.Cleared_Disbursements__c += result > 0 ? result : Math.abs(result);
            }
            //Aggregate all Cash Receipt Amounts using either Amount__c or Ledger_Amount__c fields (in org currency)
            result = DomainUtils.getCashReceiptAmount(model.record.Id, amountField, Cash_Receipt__c.Bank_Reconciliation__c);
            if (result != NULL) {
                model.record.Cleared_Deposits__c += result;
            }
            //Aggregate all Refund Cash Receipt Amounts using either Amount__c or Ledger_Amount__c fields (in org currency)
            result = DomainUtils.getCashReceiptRefundAmount(model.record.Id, amountField, Cash_Receipt__c.Bank_Reconciliation__c);
            if (result != NULL) {
                model.record.Cleared_Disbursements__c += result > 0 ? result : result * -1;
            }
            //Aggregate all Debit JE Line Amounts using either Amount__c or Ledger_Amount__c fields (in org currency)
            result = DomainUtils.getJEDebitAmount(model.record.Id, amountField, Journal_Entry_Line__c.Bank_Reconciliation__c);
            if (result != NULL) {
                model.record.Cleared_Deposits__c += result;
            }
            //Aggregate all Cash Disbursement Amounts using either Amount__c or Ledger_Amount__c fields (in org currency)
            result = DomainUtils.getCashDisbursementAmount(model.record.Id, amountField, Cash_Disbursement__c.Bank_Reconciliation__c);
            if (result != NULL) {
                model.record.Cleared_Disbursements__c += result;
            }

            ////Aggregate all negative Cash Disbursement Amounts using either Amount__c or Ledger_Amount__c fields (in org currency)
            result = DomainUtils.getNegativeCashDisbursementAmount(model.record.Id, amountField, Cash_Disbursement__c.Bank_Reconciliation__c);
            if (result != NULL) {
               model.record.Cleared_Deposits__c += result > 0 ? result : result * -1;
            }
            
            //Aggregate all Credit JE Line Amounts using either Amount__c or Ledger_Amount__c fields (in org currency)
            result = DomainUtils.getJECreditAmount(model.record.Id, amountField, Journal_Entry_Line__c.Bank_Reconciliation__c);
            if (result != NULL) {
                model.record.Cleared_Disbursements__c += result;
            }

            //Aggregate all Bank Disbursement Amounts using either Amount__c or Ledger_Amount__c fields (in org currency)
            result = DomainUtils.getBankDisbursementAmount(model.record.Id, amountField, Bank_Disbursement__c.Bank_Reconciliation__c);
            if (result != NULL) {
                model.record.Cleared_Disbursements__c += result;
            }

            //Normalize final results
            model.record.Cleared_Deposits__c = model.record.Cleared_Deposits__c.setScale(2, System.RoundingMode.HALF_UP);
            model.record.Cleared_Disbursements__c = model.record.Cleared_Disbursements__c.setScale(2, System.RoundingMode.HALF_UP);
            //Save results in DB
            TriggerObserver.getInstance().unlockFields(new Set<sObjectField>{Bank_Reconciliation2__c.Cleared_Deposits__c, Bank_Reconciliation2__c.Cleared_Disbursements__c});
            SFDCSecurityUtils.updateCheckCRUDAndFLS(model.record, new List<String>{
                'Cleared_Deposits__c',
                'Cleared_Disbursements__c'
            });
            TriggerObserver.reset();
        }
        catch (Exception ex) {
            throw ex;
        }

    }

    private ServiceResult complete() {
        // validate clearable item count
        retrieveCount();
        if (model?.recordCount == null || model.recordCount > MAX_CLEARABLE_RECORDS_PER_BANK_REC) {
            Integer count = model?.recordCount != null ? model.recordCount : -1;
            String msg = String.format(RECORD_COUNT_OVER_LIMIT_UPDATE, new String[] { String.valueOf(MAX_CLEARABLE_RECORDS_PER_BANK_REC), String.valueOf(count) });
            return new ServiceResult(model?.record?.Id, StatusCode.CLEARABLE_ITEM_LIMIT.name(), msg);
        }
        // validate status change is valid
        if (model.record.Status__c == COMPLETED) {
            return new ServiceResult(
                model.record.Id,
                StatusCode.INVALID_STATUS_CHANGE.name(),
                String.format(NO_STATUS_CHANGE, new String[] { COMPLETED }));
        }
        if (model.record.Status__c == WORKING) {
            return new ServiceResult(
                model.record.Id,
                StatusCode.INVALID_STATUS_CHANGE.name(),
                WORKING_STATUS_CHANGE);
        }

        return setStatus(Status.COMPLETED);
    }

    private ServiceResult undoComplete() {
        // validate status change is valid
        model.record = queryBankReconciliationById();
        if (model.record.Status__c == IN_PROGRESS) {
            return new ServiceResult(
                model.record.Id,
                StatusCode.INVALID_STATUS_CHANGE.name(),
                String.format(NO_STATUS_CHANGE, new String[] { IN_PROGRESS }));
        }

        return setStatus(Status.IN_PROGRESS);
    }

    private ServiceResult setStatus(Status s) {
        switch on s {
            when IN_PROGRESS {
                model.record.Status__c = IN_PROGRESS;
            }
            when WORKING {
                model.record.Status__c = WORKING;
            }
            when COMPLETED {
                model.record.Status__c = COMPLETED;
            }
            when AUTO_CLEAR_RUNNING {
                model.record.Status__c = AUTO_CLEAR_RUNNING;
            }
            when else {
                return new ServiceResult(model.record.Id, StatusCode.NO_INPUT_DATA.name(), NO_INPUT_DATA);
            }
        }

        ServiceResult result;
        try {
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Bank_Reconciliation2__c.Status__c});
            SFDCSecurityUtils.updateProxy(model.record);
            TriggerObserver.reset();
            result = new ServiceResult(model.record.Id, true);
        } catch (DmlException ex) {
            result = new ServiceResult(model.record.Id, ex.getDmlType(0).name(), ex.getDmlMessage(0));
        }
        return result;
    }

}