public with sharing class BDCSourceDocumentsFactory {

    @TestVisible
    private List<Bank_Transaction__c> bankTransactions;
    @TestVisible
    private BankRuleApplicator brApplicator;
    @TestVisible
    private FinancialTxAccountMatchRule accountMatchRule;
    @TestVisible
    private List<BDCSourceDocumentUnit> units;

    //Use this class constructor if SObjectType of source documents must be defined automatically
    public BDCSourceDocumentsFactory(Set<Id> bankTransactionIds) {
        this.bankTransactions = DomainUtils.getBankTransactionsById(bankTransactionIds);
        this.brApplicator = BankRuleApplicator.getInstance();
        if (FinancialTxAccountMatchRule.isEnabled()) {
            this.accountMatchRule = FinancialTxAccountMatchRule.getInstance();
        }
        initUnits();
    }

    public BDCSourceDocumentsFactory(List<Bank_Transaction__c> bts) {
        this(new Map<Id, Bank_Transaction__c>(bts).keySet());
    }

    private void initUnits() {
        this.units = new List<BDCSourceDocumentUnit>();
        for (Bank_Transaction__c bt : bankTransactions) {
            //Create unit based on Bank Rule applied
            BDCSourceDocumentUnit unit = brApplicator.apply(bt);
            if (unit != NULL) {
                units.add(unit);
            }
            else {//If no applicable Bank Rule found - use Cash-In/Cash-Out Default Source Record Type from settings
                //=== CASH IN ===
                if (bt.Base_Type__c == 'Credit') {
                    if (AccountingSettingsHandler.getCashInDefaultSourceRecordType() == 'Cash Receipt') {
                        units.add(new BDCSourceDocumentUnit(bt, Cash_Receipt__c.SObjectType));
                    }
                    else {
                        units.add(new BDCSourceDocumentUnit(bt, Journal_Entry__c.SObjectType));
                    }
                }//=== CASH OUT ===
                else if (bt.Base_Type__c == 'Debit') {
                    if (AccountingSettingsHandler.getCashOutDefaultSourceRecordType() == 'Cash Disbursement') {
                        units.add(new BDCSourceDocumentUnit(bt, Cash_Disbursement__c.SObjectType));
                    }
                    else {
                        units.add(new BDCSourceDocumentUnit(bt, Journal_Entry__c.SObjectType));
                    }
                }
            }
            applyAccountMatchRule(units.get(units.size() - 1));
        }
    }

    private void applyAccountMatchRule(BDCSourceDocumentUnit unit) {
        if (accountMatchRule == null) {
            return;
        }
        
        if (unit.isCashReceiptType()) {
            accountMatchRule.transferAccountData(unit.cashReceipt.bt, unit.cashReceipt.cr);
        } 
        else if (unit.isCashDisbursementType()) {
            accountMatchRule.transferAccountData(unit.cashDisbursement.bt, unit.cashDisbursement.cd);
        } 
        else if (unit.isJournalEntryType()) {
            accountMatchRule.transferAccountData(unit.journalEntry.bt, unit.journalEntry.creditJELine, unit.journalEntry.debitJELine);
        }
    }

    public List<ServiceResult> insertSourceDocuments() {
        List<ServiceResult> results = new List<ServiceResult>();
        try {
            List<BDCSourceDocumentUnit> cashReceiptUnits = new List<BDCSourceDocumentUnit>();
            List<BDCSourceDocumentUnit> cashDisbursementUnits = new List<BDCSourceDocumentUnit>();
            List<BDCSourceDocumentUnit> journalEntryUnits = new List<BDCSourceDocumentUnit>();

            for (BDCSourceDocumentUnit unit : units) {
                if (unit.isCashReceiptType()) {
                    cashReceiptUnits.add(unit);
                }
                else if (unit.isCashDisbursementType()) {
                    cashDisbursementUnits.add(unit);
                }
                else if (unit.isJournalEntryType()) {
                    journalEntryUnits.add(unit);
                }
            }

            if (!cashReceiptUnits.isEmpty()) {
                results.addAll(createCashReceipts(cashReceiptUnits));
            }
            if (!cashDisbursementUnits.isEmpty()) {
                results.addAll(createCashDisbursements(cashDisbursementUnits));
            }
            if (!journalEntryUnits.isEmpty()) {
                results.addAll(createJournalEntries(journalEntryUnits));
            }
        }
        catch (Exception ex) {
            throw ex;
        }
        return results;
    }

    private List<ServiceResult> createCashReceipts(List<BDCSourceDocumentUnit> cashReceiptUnits) {
        List<ServiceResult> results = new List<ServiceResult>();
        try {
            //Get all Cash Receipts which are valid for save in DB
            List<Cash_Receipt__c> crs = new List<Cash_Receipt__c>();
            for (BDCSourceDocumentUnit unit : cashReceiptUnits) {
                if (unit.cashReceipt.isReadyForSave()) {
                    crs.add(unit.cashReceipt.getRecord());
                }
                else {
                    results.add(new ServiceResult(unit.bt.Id, NULL, Label.ERR_REQUIRED_FIELDS_MISSING));
                }
            }
            //Save all Cash Receipts and handle save results
            if (!crs.isEmpty()) {
                SObjectActions.isPreventNonCloneableFieldsCleaning = true;
                List<Database.SaveResult> insertResults = SFDCSecurityUtils.insertProxy(crs, false);
                SObjectActions.isPreventNonCloneableFieldsCleaning = false;
                for (Integer i = 0; i < crs.size(); i++) {
                    Database.SaveResult insertResult = insertResults.get(i);
                    Id bankTransactionId = (String) crs.get(i).get('Bank_Transaction__c');
                    if (insertResult.isSuccess()) {
                        results.add(new ServiceResult(bankTransactionId, true));
                    }
                    else {
                        Database.Error err = insertResult.getErrors()[0];
                        results.add(new ServiceResult(bankTransactionId, err.statusCode.name(), err.message));
                    }
                }
            }
        }
        catch (Exception ex) {
            throw ex;
        }
        return results;
    }

    private List<ServiceResult> createCashDisbursements(List<BDCSourceDocumentUnit> cashDisbursementUnits) {
        List<ServiceResult> results = new List<ServiceResult>();
        try {
            //Save all Cash Disbursement Batch records
            saveCashDisbursementBatches(cashDisbursementUnits);
            //Get all Cash Disbursements which are valid for save in DB
            List<Cash_Disbursement__c> cds = new List<Cash_Disbursement__c>();
            for (BDCSourceDocumentUnit unit : cashDisbursementUnits) {
                //Populate master-detail relationship field on any of cash disbursements
                unit.cashDisbursement.setMasterRecord();
                //Filter not valid for save cash disbursements out
                if (unit.cashDisbursement.isReadyForSave()) {
                    cds.add(unit.cashDisbursement.getRecord());
                }
                else {
                    results.add(new ServiceResult(unit.bt.Id, NULL, Label.ERR_REQUIRED_FIELDS_MISSING));
                }
            }
            //Save all Cash Disbursements and handle save results
            if (!cds.isEmpty()) {
                SObjectActions.isPreventNonCloneableFieldsCleaning = true;
                List<Database.SaveResult> insertResults = SFDCSecurityUtils.insertProxy(cds, false);
                SObjectActions.isPreventNonCloneableFieldsCleaning = false;
                for (Integer i = 0; i < cds.size(); i++) {
                    Database.SaveResult insertResult = insertResults.get(i);
                    Id bankTransactionId = (String) cds.get(i).get('Bank_Transaction__c');
                    if (insertResult.isSuccess()) {
                        results.add(new ServiceResult(bankTransactionId, true));
                    }
                    else {
                        Database.Error err = insertResult.getErrors()[0];
                        results.add(new ServiceResult(bankTransactionId, err.statusCode.name(), err.message));
                    }
                }
            }
            //Delete all Cash Disbursement Batches if related Cash Disbursement record has not been successfully saved in DB
            List<Cash_Disbursement_Batch__c> cashDisbursementBatchesToRollback = new List<Cash_Disbursement_Batch__c>();
            for (BDCSourceDocumentUnit unit : cashDisbursementUnits) {
                if (unit.cashDisbursement.isMasterRecordSaved() && !unit.cashDisbursement.isRecordSaved()) {
                    cashDisbursementBatchesToRollback.add(unit.cashDisbursement.cdb);
                }
            }
            if (!cashDisbursementBatchesToRollback.isEmpty()) {
                SFDCSecurityUtils.deleteProxy(cashDisbursementBatchesToRollback);
            }
        }
        catch (Exception ex) {
            throw ex;
        }
        return results;
    }

    private void saveCashDisbursementBatches(List<BDCSourceDocumentUnit> cashDisbursementUnits) {
        try {
            Database.insert(getCashDisbursementBatches(cashDisbursementUnits), false);
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    private List<Cash_Disbursement_Batch__c> getCashDisbursementBatches(List<BDCSourceDocumentUnit> cashDisbursementUnits) {
        List<Cash_Disbursement_Batch__c> cdBatches = new List<Cash_Disbursement_Batch__c>();
        for (BDCSourceDocumentUnit unit : cashDisbursementUnits) {
            cdBatches.add(unit.cashDisbursement.getMasterRecord());
        }
        return cdBatches;
    }

    private List<ServiceResult> createJournalEntries(List<BDCSourceDocumentUnit> journalEntryUnits) {
        List<ServiceResult> results = new List<ServiceResult>();
        try {
            //Save all Journal Entries
            saveJournalEntries(journalEntryUnits);
            //Get all Journal Entry Line pairs which are valid for save in DB
            List<Journal_Entry_Line__c> journalEntryLines = new List<Journal_Entry_Line__c>();
            for (BDCSourceDocumentUnit unit : journalEntryUnits) {
                //Populate master-detail relationship field on any of Journal Entry Line pairs
                unit.journalEntry.setMasterRecord();
                //Filter not valid for save Journal Entry Line pairs out
                if (unit.journalEntry.isReadyForSave()) {
                    journalEntryLines.add(unit.journalEntry.getMainLine());
                    journalEntryLines.add(unit.journalEntry.getOppositeLine());
                }
                else {
                    results.add(new ServiceResult(unit.bt.Id, NULL, Label.ERR_REQUIRED_FIELDS_MISSING));
                }
            }

            Map<String, List<Database.Error>> btToInsertErrors = new Map<String, List<Database.Error>>();
            //Save all Journal Entry Lines and handle save results
            if (!journalEntryLines.isEmpty()) {
                Id bankTransactionId;//Not NULL only for the Main JE Line in each pair

                SObjectActions.isPreventNonCloneableFieldsCleaning = true;
                List<Database.SaveResult> insertResults = SFDCSecurityUtils.insertProxy(journalEntryLines, false);
                SObjectActions.isPreventNonCloneableFieldsCleaning = false;

                for (Integer i = 0; i < journalEntryLines.size(); i++) {
                    Database.SaveResult insertResult = insertResults.get(i);
                    if (journalEntryLines.get(i).get('Bank_Transaction__c') != NULL) {
                        bankTransactionId = (String) journalEntryLines.get(i).get('Bank_Transaction__c');
                    }
                    if (!insertResult.isSuccess()) {
                        if (btToInsertErrors.containsKey(bankTransactionId)) {
                            btToInsertErrors.get(bankTransactionId).addAll(insertResult.getErrors());
                        }
                        else {
                            btToInsertErrors.put(bankTransactionId, insertResult.getErrors());
                        }
                    }
                }
            }
            //Check if all records have not been successfully saved in DB and delete any redundant records in case of partial success
            List<Journal_Entry__c> journalEntriesToRollback = new List<Journal_Entry__c>();
            List<Journal_Entry_Line__c> journalEntryLinesToRollback = new List<Journal_Entry_Line__c>();
            for (BDCSourceDocumentUnit unit : journalEntryUnits) {
                //Full Success
                if (unit.journalEntry.isMasterRecordSaved() && unit.journalEntry.linesSaved()) {
                    results.add(new ServiceResult(unit.journalEntry.bt.Id, true));
                }//Journal Entry - success, Journal Entry Lines - failed
                else if (unit.journalEntry.isMasterRecordSaved()) {
                    List<Database.Error> dmlErrors = btToInsertErrors.get(unit.journalEntry.bt.Id);
                    if (dmlErrors != NULL) {//If there was attempt to do dml operation
                        //add failed result into common results collection
                        results.add(new ServiceResult(unit.journalEntry.bt.Id, false, convertDMLErrors(dmlErrors)));
                    }
                    journalEntriesToRollback.add(unit.journalEntry.getMasterRecord());
                    if (unit.journalEntry.getMainLine().Id != NULL) {
                        journalEntryLinesToRollback.add(unit.journalEntry.getMainLine());
                    }
                    if (unit.journalEntry.getOppositeLine().Id != NULL) {
                        journalEntryLinesToRollback.add(unit.journalEntry.getOppositeLine());
                    }
                }
            }

            //Process rollback action
            if (!journalEntryLinesToRollback.isEmpty()) {
                SFDCSecurityUtils.deleteProxy(journalEntryLinesToRollback);
            }
            if (!journalEntriesToRollback.isEmpty()) {
                SFDCSecurityUtils.deleteProxy(journalEntriesToRollback);
            }
        }
        catch (Exception ex) {
            throw ex;
        }

        return results;
    }

    private void saveJournalEntries(List<BDCSourceDocumentUnit> journalEntryUnits) {
        try {
            Database.insert(getJournalEntries(journalEntryUnits), false);
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    private List<Journal_Entry__c> getJournalEntries(List<BDCSourceDocumentUnit> journalEntryUnits) {
        List<Journal_Entry__c> journalEntries = new List<Journal_Entry__c>();
        for (BDCSourceDocumentUnit unit : journalEntryUnits) {
            journalEntries.add(unit.journalEntry.getMasterRecord());
        }
        return journalEntries;
    }

    private List<ServiceResult.Error> convertDMLErrors(List<Database.Error> dmlErrors) {
        List<ServiceResult.Error> convertedErrors = new List<ServiceResult.Error>();
        for (Database.Error dmlError : dmlErrors) {
            ServiceResult.Error convertedError = new ServiceResult.Error(
                dmlError.getStatusCode().name(), dmlError.getMessage()
            );
            convertedErrors.add(convertedError);
        }
        return convertedErrors;
    }


    public with sharing class BDCSourceDocumentUnit {
        private Bank_Transaction__c bt;
        private SObjectType sourceDocType;

        public BDCSourceDocumentsFactory.CashReceiptWrapper cashReceipt;
        public BDCSourceDocumentsFactory.CashDisbursementWrapper cashDisbursement;
        public BDCSourceDocumentsFactory.JournalEntryWrapper journalEntry;

        public BDCSourceDocumentUnit(Bank_Transaction__c bt, SObjectType sourceDocType) {
            this.bt = bt;
            this.sourceDocType = sourceDocType;
            initWrapper();
        }

        public Boolean isCashReceiptType() {
            return sourceDocType == Cash_Receipt__c.SObjectType;
        }
        public Boolean isCashDisbursementType() {
            return sourceDocType == Cash_Disbursement__c.SObjectType;
        }
        public Boolean isJournalEntryType() {
            return sourceDocType == Journal_Entry__c.SObjectType;
        }

        private void initWrapper() {
            if (isCashReceiptType()) {
                this.cashReceipt = new CashReceiptWrapper(bt);
            }
            else if (isCashDisbursementType()) {
                this.cashDisbursement = new CashDisbursementWrapper(bt);
            }
            else if (isJournalEntryType()) {
                this.journalEntry = new JournalEntryWrapper(bt);
            }
        }

    }

    public with sharing class CashReceiptWrapper {
        private Bank_Transaction__c bt;
        private Cash_Receipt__c cr;
        private List<SObjectField> requiredFields = new List<SObjectField>{
            Cash_Receipt__c.Account__c,
            Cash_Receipt__c.Credit_GL_Account__c
        };

        public CashReceiptWrapper(Bank_Transaction__c bt) {
            this.bt = bt;
            initRecord();
        }

        private void initRecord() {
            cr = new Cash_Receipt__c();
            cr.Payment_Reference__c = bt.Bank_Transaction_Id__c;
            cr.Description__c = bt.Description__c;
            cr.Receipt_Date__c = bt.Date__c;
            cr.Amount__c = bt.Amount__c;
            cr.Bank_Account__c = bt.GL_Account_Mapping__r.GL_Account__c;
            cr.Ledger__c = bt.GL_Account_Mapping__r.Ledger__c;
            cr.Bank_Transaction__c = bt.Id;
            cr.Cleared_Date__c = bt.Date__c;
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                cr.put('CurrencyIsoCode', bt.get('CurrencyIsoCode'));
            }
        }

        public Cash_Receipt__c getRecord() {
            return cr;
        }

        public Boolean isReadyForSave() {
            Boolean result = true;
            for (SObjectField requiredField : requiredFields) {
                if (cr.get(requiredField) == NULL) {
                    result = false;
                }
            }
            return result;
        }
    }

    public with sharing class CashDisbursementWrapper {
        private Bank_Transaction__c bt;
        private Cash_Disbursement__c cd;
        private Cash_Disbursement_Batch__c cdb;
        private List<SObjectField> requiredFields = new List<SObjectField>{
            Cash_Disbursement__c.Cash_Disbursement_Batch__c,
            Cash_Disbursement__c.Vendor__c,
            Cash_Disbursement__c.Debit_GL_Account__c
        };

        public CashDisbursementWrapper(Bank_Transaction__c bt) {
            this.bt = bt;
            initMasterRecord();
            initRecord();
        }

        private void initMasterRecord() {
            this.cdb = new Cash_Disbursement_Batch__c(
                Name = String.valueOf(System.now().format())
            );
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                cdb.put('CurrencyIsoCode', bt.get('CurrencyIsoCode'));
            }
        }

        private void initRecord() {
            this.cd = new Cash_Disbursement__c();
            cd.Bank_Transaction__c = bt.Id;
            cd.Ledger__c = bt.GL_Account_Mapping__r.Ledger__c;
            cd.Bank_Account__c = bt.GL_Account_Mapping__r.GL_Account__c;
            cd.Reference__c = bt.Bank_Transaction_Id__c;
            cd.Amount__c = bt.Amount__c;
            cd.Description__c = bt.Description__c;
            cd.Disbursement_Date__c = bt.Date__c;
            cd.Cleared_Date__c = bt.Date__c;
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                cd.put('CurrencyIsoCode', bt.get('CurrencyIsoCode'));
            }
        }

        public Cash_Disbursement__c getRecord() {
            return cd;
        }

        public Cash_Disbursement_Batch__c getMasterRecord() {
            return cdb;
        }

        public void setMasterRecord() {
            this.cd.Cash_Disbursement_Batch__c = cdb.Id;
        }

        public Boolean isRecordSaved() {
            return this.cd.Id != NULL;
        }

        public Boolean isMasterRecordSaved() {
            return this.cdb.Id != NULL;
        }

        public Boolean isReadyForSave() {
            Boolean result = true;
            for (SObjectField requiredField : requiredFields) {
                if (cd.get(requiredField) == NULL) {
                    result = false;
                }
            }
            return result;
        }
    }

    public with sharing class JournalEntryWrapper {
        public Journal_Entry__c journalEntry;
        public Journal_Entry_Line__c debitJELine;
        public Journal_Entry_Line__c creditJELine;
        public Bank_Transaction__c bt;
        private List<SObjectField> requiredFields = new List<SObjectField>{
            Journal_Entry_Line__c.Journal_Entry__c,
            Journal_Entry_Line__c.GL_Account__c
        };

        public JournalEntryWrapper(Bank_Transaction__c bt) {
            this.bt = bt;
            initMasterRecord();
            initLines();
        }

        private void initLines() {
            debitJELine = new Journal_Entry_Line__c();
            debitJELine.Debit__c = bt.Amount__c;
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                debitJELine.put('CurrencyIsoCode', bt.get('CurrencyIsoCode'));
            }

            creditJELine = new Journal_Entry_Line__c();
            creditJELine.Credit__c = bt.Amount__c;
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                creditJELine.put('CurrencyIsoCode', bt.get('CurrencyIsoCode'));
            }
            //Populate main line's fields
            Journal_Entry_Line__c mainLine = getMainLine();
            mainLine.Bank_Transaction__c = bt.Id;
            mainLine.GL_Account__c = bt.GL_Account_Mapping__r.GL_Account__c;
            mainLine.Reference__c = bt.Bank_Transaction_Id__c;
            mainLine.Description__c = bt.Description__c;
            mainLine.Cleared_Date__c = bt.Date__c;
        }

        private void initMasterRecord() {
            journalEntry = new Journal_Entry__c();
            journalEntry.Journal_Date__c = bt.Date__c;
            journalEntry.Name = JournalEntryActions.BDC + '-' + bt.Source__c?.replaceAll(' ','') +'-' + bt.Name + '-' + System.today().format();
            journalEntry.Ledger__c = bt.GL_Account_Mapping__r.Ledger__c;
            journalEntry.Source__c = JournalEntryActions.SOURCE_BDC;
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                journalEntry.put('CurrencyIsoCode', bt.get('CurrencyIsoCode'));
            }
        }

        public Journal_Entry_Line__c getMainLine() {
            Journal_Entry_Line__c line;
            if (bt.Base_Type__c == 'Credit') {
                line = debitJELine;
            }
            else if (bt.Base_Type__c == 'Debit') {
                line = creditJELine;
            }
            return line;
        }

        public Journal_Entry_Line__c getOppositeLine() {
            Journal_Entry_Line__c line;
            if (bt.Base_Type__c == 'Credit') {
                line = creditJELine;
            }
            else if (bt.Base_Type__c == 'Debit') {
                line = debitJELine;
            }
            return line;
        }

        public Journal_Entry__c getMasterRecord() {
            return journalEntry;
        }

        public Boolean isMasterRecordSaved() {
            return journalEntry.Id != NULL;
        }

        public void setMasterRecord() {
            debitJELine.Journal_Entry__c = journalEntry.Id;
            creditJELine.Journal_Entry__c = journalEntry.Id;
        }

        public Boolean linesSaved() {
            return debitJELine.Id != NULL && creditJELine.Id != NULL;
        }

        public Boolean isReadyForSave() {
            Boolean result = true;
            //Check common required fields on both lines
            for (SObjectField requiredField : requiredFields) {
                if (getMainLine().get(requiredField) == NULL || getOppositeLine().get(requiredField) == NULL) {
                    result = false;
                }
            }
            //Additionally check Bank Transaction Id on the Main Line
            if (getMainLine().get(Journal_Entry_Line__c.Bank_Transaction__c) == NULL) {
                result = false;
            }
            return result;
        }
    }

}