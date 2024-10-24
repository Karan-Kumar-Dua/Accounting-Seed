public with sharing class BankDirectConnectHelper extends AbstractLWCHelper {

    public static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final Integer BT_LOAD_LIMIT = 2001;
    public static final String JOURNAL_DEBIT_VALUE = 'Journal Entry Debit';
    public static final String JOURNAL_CREDIT_VALUE = 'Journal Entry Credit';
    public static final String DEPOSIT_VALUE = 'Cash Disbursement';
    public static final String RECEIPT_VALUE = 'Cash Receipt';
    public static final String REFUND_RECEIPT_VALUE = 'Refund Cash Receipt';
    public static final String BANK_DEPOSIT_VALUE = 'Bank Deposit';
    public static final String DEBIT_VALUE = 'DEBIT';
    public static final String CREDIT_VALUE = 'CREDIT';
    public static final String JOURNAL_DEBIT_LABEL = Label.COMMON_JOURNAL_ENTRY_DEBIT;
    public static final String JOURNAL_CREDIT_LABEL = Label.COMMON_JOURNAL_ENTRY_CREDIT;
    public static final String DEPOSIT_LABEL = Label.COMMON_CASH_DISBURSEMENT;
    public static final String RECEIPT_LABEL = Label.COMMON_CASH_RECEIPT;
    public static final String REFUND_RECEIPT_LABEL = Label.COMMON_REFUND_CASH_RECEIPT;
    public static final String BANK_DEPOSIT_LABEL = Label.COMMON_BANK_DEPOSIT;
    public static final String DEBIT_LABEL = Label.COMMON_CAPS_DEBIT;
    public static final String CREDIT_LABEL = Label.COMMON_CAPS_CREDIT;
    public static final String ADD_ACTION = Label.COMMON_CAPS_ADD;
    public static final String VIEW_ACTION = Label.COMMON_CAPS_VIEW;
    public static final String REMOVE_ACTION = Label.COMMON_CAPS_REMOVE;
    public static final String RESTORE_ACTION = Label.COMMON_CAPS_RESTORE;
    public static final String MATCH_ACTION = Label.COMMON_CAPS_MATCH;
    public static final String UNMATCH_ACTION = Label.COMMON_CAPS_UNMATCH;

    public static final String REQUIRED_FIELD_ERROR = Label.REQUIRED_FIELDS_ARE_MISSING + ': {0}';
    public static final String REQUIRED_FIELD_MISSED_ERROR = Label.COMMON_REQUIRED_FIELD_MISSED_ERROR;
    public static final String PERIOD_NOT_EXIST_ERROR = Label.COMMON_PERIOD_NOT_EXIST_ERROR;

    public static final String DOWNLOAD_CLASS_NAME = 'BankTransactionsDownloadQueueable';
    public static final Set<String> JOB_STATUSES = GlobalVariables.APEX_JOB_STATUSES;
    public static final String JOB_NAME = 'DownloadBDCTransaction';
    public static final String BDC_CUSTOM_PERMISSION_NAME = 'Import_BDC_Transactions';

    public static final Map<String, SObjectField> accountField = new Map<String, SObjectField> {
        PACKAGE_QUALIFIER + 'Cash_Disbursement__c' => Cash_Disbursement__c.Vendor__c,
        PACKAGE_QUALIFIER + 'Cash_Receipt__c' => Cash_Receipt__c.Account__c,
        PACKAGE_QUALIFIER + 'Journal_Entry_Line__c' => Journal_Entry_Line__c.Account__c
    };

    public static final Map<String, SObjectField> glAccountField = new Map<String, SObjectField> {
        PACKAGE_QUALIFIER + 'Cash_Disbursement__c' => Cash_Disbursement__c.Debit_GL_Account__c,
        PACKAGE_QUALIFIER + 'Cash_Receipt__c' => Cash_Receipt__c.Credit_GL_Account__c,
        PACKAGE_QUALIFIER + 'Journal_Entry_Line__c' => Journal_Entry_Line__c.GL_Account__c,
        PACKAGE_QUALIFIER + 'Bank_Deposit__c' => Bank_Deposit__c.Bank_Account__c
    };

    public static final Map<String, SObjectField> descriptionField = new Map<String, SObjectField> {
        PACKAGE_QUALIFIER + 'Cash_Disbursement__c' => Cash_Disbursement__c.Description__c,
        PACKAGE_QUALIFIER + 'Cash_Receipt__c' => Cash_Receipt__c.Description__c,
        PACKAGE_QUALIFIER + 'Journal_Entry_Line__c' => Journal_Entry_Line__c.Description__c,
        PACKAGE_QUALIFIER + 'Bank_Deposit__c' => Bank_Deposit__c.Deposit_Reference__c
    };

    @AuraEnabled
    public static Boolean isAllowBDCAccess(){
        return FeatureManagement.checkPermission(BDC_CUSTOM_PERMISSION_NAME);
    }

    @AuraEnabled
    public static void runDownloadTransactionJob() {
        BDCService service = new BDCService();
        service.getAllTransactionsBulk();
    }

    @AuraEnabled
    public static Boolean isDownloadTransactionJobDone() {
        return DomainUtils.getAsyncApexJobByApexClassNameAndStatus(new Set<String> {DOWNLOAD_CLASS_NAME}, JOB_STATUSES).isEmpty();
    }

    @AuraEnabled
    public static List<BankAccountWrapper> getBankAccounts() {
        List<BankAccountWrapper> wrapper = new List<BankAccountWrapper>();
        try {
            for (GL_Account_Mapping__c mapping : DomainUtils.getGLAccountMappings(true)) {
                wrapper.add(new BankAccountWrapper(mapping));
            }
        }
        catch (AuraHandledException ex) {
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        return wrapper;
    }

    @AuraEnabled
    public static List<BankTransactionWrapper> getBankTransactions(String bankAccountId, String filterBy) {
        List<BankTransactionWrapper> results = new List<BankTransactionWrapper>();
        try {
            if (!String.isBlank(bankAccountId)) {
                TransactionFilter filter = (TransactionFilter) deserialize(filterBy, TransactionFilter.class);
                List<Bank_Transaction__c> bankTransactions = getBTs(bankAccountId, filter);
                if (isFilterStatusUnmatched(filter)) {
                    for (Bank_Transaction__c bt : bankTransactions) {
                        BankTransactionWrapper wbt = new BankTransactionWrapper(bt, NULL);
                        wbt.setDefaultAppliedObject();
                        results.add(wbt);
                    }
                }
                else {
                    results.addAll(getBTWrapperWithRelated(bankTransactions, filter));
                }

            }

        }
        catch (AuraHandledException ex) {
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        return results;
    }

    @AuraEnabled
    public static List<BankTransactionWrapper> getUnmatchedBankTransactions(String bankAccountId) {
        List<BankTransactionWrapper> results = new List<BankTransactionWrapper>();
        try {
            if (!String.isBlank(bankAccountId)) {
                TransactionFilter filter = new TransactionFilter();
                filter.status = new List<String> {BankTransactionsHelper.BT_UNMATCHED_STATUS};
                for (Bank_Transaction__c bt : getBTs(bankAccountId, filter)) {
                    BankTransactionWrapper wbt = new BankTransactionWrapper(bt, NULL);
                    wbt.setDefaultAppliedObject();
                    results.add(wbt);
                }
            }

        }
        catch (AuraHandledException ex) {
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        return results;
    }

    @AuraEnabled
    public static List<BankTransactionWrapper> applyAccountRules(String transactions) {
        List<BankTransactionWrapper> results = new List<BankTransactionWrapper>();
        try {
            if (!String.isBlank(transactions)) {
                results = (List<BankTransactionWrapper>) JSON.deserialize(transactions, List<BankTransactionWrapper>.class);
                if (!results.isEmpty()) {
                    setPossibleAccountRules(results);
                }
            }

        }
        catch (AuraHandledException ex) {
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }

        return results;
    }

    private static void setPossibleAccountRules(List<BankTransactionWrapper> transactions) {
        if (FinancialTxAccountMatchRule.isEnabled()) {
            FinancialTxAccountMatchRule accountMatchRule = FinancialTxAccountMatchRule.getInstance();
            for (BankTransactionWrapper wbt : transactions) {
                accountMatchRule.transferAccountData(wbt.bt.obj, wbt.proxyObj.obj);
            }
        }
    }

    @AuraEnabled
    public static List<BankTransactionWrapper> applyBankRules(String transactions) {
        List<BankTransactionWrapper> results = new List<BankTransactionWrapper>();
        try {
            if (!String.isBlank(transactions)) {
                results = (List<BankTransactionWrapper>) JSON.deserialize(transactions, List<BankTransactionWrapper>.class);
                if (!results.isEmpty()) {
                    setPossibleMatchAndApplyRules(results);
                }
            }

        }
        catch (AuraHandledException ex) {
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }

        return results;
    }

    private static void setPossibleMatchAndApplyRules(List<BankTransactionWrapper> transactions) {
        Set<Id> bankTransactionsIds = new Set<Id>();
        for (BankTransactionWrapper wbt : transactions) {
            bankTransactionsIds.add(wbt.bt.obj.Id);
        }
        BankRuleApplicator.getInstance();

        BankTransactionsMatcher matcher = new BankTransactionsMatcher(
            bankTransactionsIds, BankTransactionsMatcher.ExecutionContext.UI
        );
        matcher.searchMatchingRecords();

        for (BankTransactionWrapper wbt : transactions) {

            BankRuleComposite bankRuleAppliedToProxyObject =
                BankRuleApplicator.getInstance().apply(wbt.bt.obj, wbt.proxyObj.obj);

            BankRuleComposite bankRuleAppliedToShadowProxyObject =
                BankRuleApplicator.getInstance().apply(wbt.bt.obj, wbt.shadowProxyObj.obj);

            if (isProxyObjectSwapNeeded(bankRuleAppliedToProxyObject, bankRuleAppliedToShadowProxyObject)) {
                wbt.swapProxyObject();
            }

            wbt.setDefaultAppliedObject();

            if (matcher.hasMatchingRecords(wbt.bt.obj.Id)) {
                wbt.setPossibleMatch(matcher.getMatchingRecords(wbt.bt.obj.Id), true);
            }
            else {
                wbt.validateRequiredFields();
            }
        }
    }

    private static Boolean isProxyObjectSwapNeeded(BankRuleComposite bRuleFirst, BankRuleComposite bRuleSecond) {
        Boolean result = false;

        if ((bRuleFirst == NULL && bRuleSecond != NULL)
                || (bRuleFirst != NULL && bRuleSecond != NULL
                        && bRuleSecond.rule.Priority__c < bRuleFirst.rule.Priority__c)) {

            result = true;
        }

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isMultiCurrencyEnabled(){
        return AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED;
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isCashFlowStatementEnabled(){
        return AccountingSettingsHandler.getAccountingSettings().Enable_Cash_Flow_Statement__c;
    }

    @AuraEnabled
    public static List<BankTransactionWrapper> removeRecords(String transactionList) {
        Boolean isError = false;
        List<BankTransactionWrapper> results;
        System.Savepoint sp = Database.setSavepoint();
        try {
            results = (List<BankTransactionWrapper>) JSON.deserialize(transactionList, List<BankTransactionWrapper>.class);

            List<Bank_Transaction__c> updateList = new List<Bank_Transaction__c>();
            for (BankTransactionWrapper btw : results) {
                btw.setActionName(BankTransactionsHelper.BT_REMOVED_STATUS);
                updateList.add(btw.bt.obj);
            }

            if (!updateList.isEmpty()) {
                BankTransactionsHelper.updateBankTransactionsStatus(updateList, BankTransactionsHelper.BT_REMOVED_STATUS);
            }
        }
        catch (AuraHandledException ex) {
            isError = true;
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            isError = true;
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }
        catch (Exception ex) {
            isError = true;
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        finally {
            if (isError) {
                Database.rollback(sp);
            }
        }
        return results;
    }

    @AuraEnabled
    public static List<BankTransactionWrapper> restoreRecords(String transactionList) {
        Boolean isError = false;
        List<BankTransactionWrapper> results;
        System.Savepoint sp = Database.setSavepoint();
        try {
            results = (List<BankTransactionWrapper>) JSON.deserialize(transactionList, List<BankTransactionWrapper>.class);

            List<Bank_Transaction__c> updateList = new List<Bank_Transaction__c>();
            for (BankTransactionWrapper btw : results) {
                btw.setActionName(BankTransactionsHelper.BT_UNMATCHED_STATUS);
                updateList.add(btw.bt.obj);
            }

            if (!updateList.isEmpty()) {
                BankTransactionsHelper.updateBankTransactionsStatus(updateList, BankTransactionsHelper.BT_UNMATCHED_STATUS);
            }
            setPossibleMatchAndApplyRules(results);
        }
        catch (AuraHandledException ex) {
            isError = true;
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            isError = true;
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }
        catch (Exception ex) {
            isError = true;
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        finally {
            if (isError) {
                Database.rollback(sp);
            }
        }
        return results;
    }

    @AuraEnabled
    public static List<BankTransactionWrapper> unmatchRecords(String transactionList) {
        Boolean isError = false;
        List<BankTransactionWrapper> results;
        System.Savepoint sp = Database.setSavepoint();
        try {
            results = (List<BankTransactionWrapper>) JSON.deserialize(transactionList, List<BankTransactionWrapper>.class);

            List<Cash_Disbursement__c> cdUpdateList = new List<Cash_Disbursement__c>();
            List<Cash_Receipt__c> crUpdateList = new List<Cash_Receipt__c>();
            List<Journal_Entry_Line__c> jeUpdateList = new List<Journal_Entry_Line__c>();
            List<Bank_Deposit__c> bdUpdateList = new List<Bank_Deposit__c>();

            Map<Integer, BankTransactionWrapper> indexCRMap = new Map<Integer, BankDirectConnectHelper.BankTransactionWrapper>();
            Map<Integer, BankTransactionWrapper> indexCDMap = new Map<Integer, BankDirectConnectHelper.BankTransactionWrapper>();
            Map<Integer, BankTransactionWrapper> indexJEMap = new Map<Integer, BankDirectConnectHelper.BankTransactionWrapper>();
            Map<Integer, BankTransactionWrapper> indexBDMap = new Map<Integer, BankDirectConnectHelper.BankTransactionWrapper>();
            Integer innerCRIndex = 0;
            Integer innerCDIndex = 0;
            Integer innerJEIndex = 0;
            Integer innerBDIndex = 0;

            for (BankTransactionWrapper res : results) {
                res.errors = new List<String>();
                    if (res.proxyObj.obj.Id != NULL
                            && (res.bt.obj.Status__c == BankTransactionsHelper.BT_ADDED_STATUS
                                    || res.bt.obj.Status__c == BankTransactionsHelper.BT_MATCHED_STATUS)) {

                        res.proxyObj.obj.put('Bank_Transaction__c', NULL);
                        res.proxyObj.obj.put('Cleared_Date__c', NULL);

                        switch on res.proxyObj.obj {
                            when Cash_Disbursement__c objRecord {
                                cdUpdateList.add(objRecord);
                                indexCDMap.put(innerCRIndex, res);
                                innerCDIndex ++;
                            }
                            when Cash_Receipt__c objRecord {
                                crUpdateList.add(objRecord);
                                indexCRMap.put(innerCDIndex, res);
                                innerCRIndex ++;
                            }
                            when Journal_Entry_Line__c objRecord {
                                jeUpdateList.add(objRecord);
                                indexJEMap.put(innerJEIndex, res);
                                innerJEIndex ++;
                            }
                            when Bank_Deposit__c objRecord {
                                bdUpdateList.add(objRecord);
                                indexBDMap.put(innerBDIndex, res);
                                innerBDIndex ++;
                            }
                        }
                    }
            }

            if (!crUpdateList.isEmpty()) {
                updateCRs(crUpdateList, indexCRMap);
            }

            if (!cdUpdateList.isEmpty()) {
                updateCDs(cdUpdateList, indexCDMap);
            }

            if (!jeUpdateList.isEmpty()) {
                updateJELs(jeUpdateList, indexJEMap);
            }

            if (!bdUpdateList.isEmpty()) {
                updateBDs(bdUpdateList, indexBDMap);
            }

            updateUnmatchedBankTransactionStatus(results);
        }
        catch (AuraHandledException ex) {
            isError = true;
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            isError = true;
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }
        catch (Exception ex) {
            isError = true;
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        finally {
            if (isError) {
                Database.rollback(sp);
            }
        }
        return results;
    }

    private static void updateUnmatchedBankTransactionStatus(List<BankTransactionWrapper> btwList) {
        List<Bank_Transaction__c> updateList = new List<Bank_Transaction__c>();
        for (BankTransactionWrapper btw : btwList) {
            if (btw.errors.isEmpty()) {
                Boolean isMatchExist = false;
                for (PossibleMatchWrapper matchWrapper : btw.possibleMatches) {
                    if (matchWrapper.possibleMatch.obj.Id == btw.proxyObj.obj.Id) {
                        isMatchExist = true;
                    }
                }
                SObject tempProxyObject = btw.proxyObj.obj;
                btw.setProxyObject(NULL);
                if (!isMatchExist && tempProxyObject.Id != NULL) {
                    btw.setPossibleMatch(new List<SObject> {tempProxyObject}, false);
                }
                if (isMatchExist) {
                    btw.updateExistedPossibleMatch();
                }

                btw.setActionName(BankTransactionsHelper.BT_UNMATCHED_STATUS);
                updateList.add(btw.bt.obj);
            }
        }

        if (!updateList.isEmpty()) {
            BankTransactionsHelper.updateBankTransactionsStatus(updateList, BankTransactionsHelper.BT_UNMATCHED_STATUS);
        }
    }

    @AuraEnabled
    public static List<BankTransactionWrapper> matchRecords(String transactionList) {
        Boolean isError = false;
        List<BankTransactionWrapper> results;
        System.Savepoint sp = Database.setSavepoint();
        try {
            results = (List<BankTransactionWrapper>) JSON.deserialize(transactionList, List<BankTransactionWrapper>.class);

            Set<Id> alreadyMatchedIds = checkForAlreadyMatched(results);

            List<Cash_Disbursement__c> cdUpdateList = new List<Cash_Disbursement__c>();
            List<Cash_Receipt__c> crUpdateList = new List<Cash_Receipt__c>();
            List<Journal_Entry_Line__c> jeUpdateList = new List<Journal_Entry_Line__c>();
            List<Bank_Deposit__c> bdUpdateList = new List<Bank_Deposit__c>();

            Map<Integer, BankTransactionWrapper> indexCRMap = new Map<Integer, BankDirectConnectHelper.BankTransactionWrapper>();
            Map<Integer, BankTransactionWrapper> indexCDMap = new Map<Integer, BankDirectConnectHelper.BankTransactionWrapper>();
            Map<Integer, BankTransactionWrapper> indexJEMap = new Map<Integer, BankDirectConnectHelper.BankTransactionWrapper>();
            Map<Integer, BankTransactionWrapper> indexBDMap = new Map<Integer, BankDirectConnectHelper.BankTransactionWrapper>();
            Integer innerCRIndex = 0;
            Integer innerCDIndex = 0;
            Integer innerJEIndex = 0;
            Integer innerBDIndex = 0;

            for (BankTransactionWrapper res : results) {
                res.errors = new List<String>();
                for (PossibleMatchWrapper matchWrapper : res.possibleMatches) {
                    if (matchWrapper.checked && !alreadyMatchedIds.contains(matchWrapper.possibleMatch.obj.Id)) {
                        matchWrapper.possibleMatch.obj.put('Bank_Transaction__c', res.bt.obj.Id);
                        matchWrapper.possibleMatch.obj.put('Cleared_Date__c', res.bt.obj.Date__c);
                        if (String.isBlank((String) matchWrapper.possibleMatch.obj.get(descriptionField.get(matchWrapper.possibleMatch.sobjType)))) {
                            matchWrapper.possibleMatch.obj.put(descriptionField.get(matchWrapper.possibleMatch.sobjType), res.bt.obj.Description__c);
                        }

                        switch on matchWrapper.possibleMatch.obj {
                            when Cash_Disbursement__c objRecord {
                                cdUpdateList.add(objRecord);
                                indexCDMap.put(innerCRIndex, res);
                                innerCDIndex ++;
                            }
                            when Cash_Receipt__c objRecord {
                                crUpdateList.add(objRecord);
                                indexCRMap.put(innerCDIndex, res);
                                innerCRIndex ++;
                            }
                            when Journal_Entry_Line__c objRecord {
                                jeUpdateList.add(objRecord);
                                indexJEMap.put(innerJEIndex, res);
                                innerJEIndex ++;
                            }
                            when Bank_Deposit__c objRecord {
                                bdUpdateList.add(objRecord);
                                indexBDMap.put(innerBDIndex, res);
                                innerBDIndex ++;
                            }
                        }
                    }
                    else if (matchWrapper.checked && alreadyMatchedIds.contains(matchWrapper.possibleMatch.obj.Id)) {
                        res.errors.add(String.format(Label.ERR_RECORD_MATCHED_WITH_OTHER_BT, new List<Object>{matchWrapper.possibleMatch.obj.get('Name')}));
                    }
                }
            }

            if (!crUpdateList.isEmpty()) {
                updateCRs(crUpdateList, indexCRMap);
            }

            if (!cdUpdateList.isEmpty()) {
                updateCDs(cdUpdateList, indexCDMap);
            }

            if (!jeUpdateList.isEmpty()) {
                updateJELs(jeUpdateList, indexJEMap);
            }

            if (!bdUpdateList.isEmpty()) {
                updateBDs(bdUpdateList, indexBDMap);
            }

            updateMatchedBankTransactionStatus(results);
        }
        catch (AuraHandledException ex) {
            isError = true;
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            isError = true;
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }
        catch (Exception ex) {
            isError = true;
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        finally {
            if (isError) {
                Database.rollback(sp);
            }
        }
        return results;
    }

    private static Set<Id> checkForAlreadyMatched(List<BankTransactionWrapper> btwList) {
        Set<Id> alreadyMatchedSourceRecordIds = new Set<Id>();
        Set<Id> cdIds = new Set<Id>();
        Set<Id> crIds = new Set<Id>();
        Set<Id> jelIds = new Set<Id>();
        Set<Id> bdIds = new Set<Id>();
        for (BankTransactionWrapper res : btwList) {
            for (PossibleMatchWrapper matchWrapper : res.possibleMatches) {
                if (matchWrapper.checked) {
                    switch on matchWrapper.possibleMatch.obj {
                        when Cash_Disbursement__c objRecord {
                            cdIds.add(objRecord.Id);
                        }
                        when Cash_Receipt__c objRecord {
                            crIds.add(objRecord.Id);
                        }
                        when Journal_Entry_Line__c objRecord {
                            jelIds.add(objRecord.Id);
                        }
                        when Bank_Deposit__c objRecord {
                            bdIds.add(objRecord.Id);
                        }
                    }
                }
            }
        }

        if (!cdIds.isEmpty()) {
            for (SObject rec : DomainUtils.getSourceDocumentsHavingBankTransactionById(cdIds, Cash_Disbursement__c.SObjectType)) {
                alreadyMatchedSourceRecordIds.add(rec.Id);
            }
        }

        if (!crIds.isEmpty()) {
            for (SObject rec : DomainUtils.getSourceDocumentsHavingBankTransactionById(crIds, Cash_Receipt__c.SObjectType)) {
                alreadyMatchedSourceRecordIds.add(rec.Id);
            }
        }

        if (!jelIds.isEmpty()) {
            for (SObject rec : DomainUtils.getSourceDocumentsHavingBankTransactionById(jelIds, Journal_Entry_Line__c.SObjectType)) {
                alreadyMatchedSourceRecordIds.add(rec.Id);
            }
        }

        if (!bdIds.isEmpty()) {
            for (SObject rec : DomainUtils.getSourceDocumentsHavingBankTransactionById(bdIds, Bank_Deposit__c.SObjectType)) {
                alreadyMatchedSourceRecordIds.add(rec.Id);
            }
        }

        return alreadyMatchedSourceRecordIds;
    }

    private static void updateMatchedBankTransactionStatus(List<BankTransactionWrapper> btwList) {
        List<Bank_Transaction__c> updateList = new List<Bank_Transaction__c>();
        for (BankTransactionWrapper btw : btwList) {
            if (btw.errors.isEmpty()) {
                for (PossibleMatchWrapper matchWrapper : btw.possibleMatches) {
                    if (matchWrapper.checked) {
                        btw.setProxyObject(matchWrapper.possibleMatch.obj);
                        btw.setActionName(BankTransactionsHelper.BT_MATCHED_STATUS);
                        updateList.add(btw.bt.obj);
                    }
                }
            }
        }

        if (!updateList.isEmpty()) {
            BankTransactionsHelper.updateBankTransactionsStatus(updateList, BankTransactionsHelper.BT_MATCHED_STATUS);
        }
    }

    private static void updateCRs(List<SObject> updateList, Map<Integer, BankTransactionWrapper> indexMap) {
        TriggerObserver.getInstance().unlockField(Cash_Receipt__c.Bank_Transaction__c);
        updateMatchedRecords(updateList, indexMap);
        TriggerObserver.purgeUnlockedFields(Cash_Receipt__c.Bank_Transaction__c);
    }

    private static void updateCDs(List<SObject> updateList, Map<Integer, BankTransactionWrapper> indexMap) {
        TriggerObserver.getInstance().unlockField(Cash_Disbursement__c.Bank_Transaction__c);
        updateMatchedRecords(updateList, indexMap);
        TriggerObserver.purgeUnlockedFields(Cash_Disbursement__c.Bank_Transaction__c);
    }

    private static void updateJELs(List<SObject> updateList, Map<Integer, BankTransactionWrapper> indexMap) {
        TriggerObserver.getInstance().unlockField(Journal_Entry_Line__c.Bank_Transaction__c);
        updateMatchedRecords(updateList, indexMap);
        TriggerObserver.purgeUnlockedFields(Journal_Entry_Line__c.Bank_Transaction__c);
    }

    private static void updateBDs(List<SObject> updateList, Map<Integer, BankTransactionWrapper> indexMap) {
        TriggerObserver.getInstance().unlockField(Bank_Deposit__c.Bank_Transaction__c);
        updateMatchedRecords(updateList, indexMap);
        TriggerObserver.purgeUnlockedFields(Bank_Deposit__c.Bank_Transaction__c);
    }

    private static void updateMatchedRecords(List<SObject> updateList, Map<Integer, BankTransactionWrapper> indexMap) {
        Integer index = 0;

        List<String> fieldsNeedToBeCheckedForEditAccess = new List<String>{
            'Bank_Transaction__c',
            'Cleared_Date__c',
            updateList[0].getSObjectType() != Bank_Deposit__c.getSObjectType() ? 'Description__c' : 'Deposit_Reference__c'
        };

        for (Database.SaveResult saveResult : SFDCSecurityUtils.updateCheckCRUDAndFLS(updateList, fieldsNeedToBeCheckedForEditAccess, false)) {
            if (!saveResult.isSuccess()) {
                indexMap.get(index).errors.add(saveResult.getErrors()[0].getMessage());
            }
            index ++;
        }
    }

    @AuraEnabled
    public static List<BankTransactionWrapper> addRecords(String transactionList, String bankInfo) {
        Boolean isError = false;
        List<BankTransactionWrapper> results;
        BankAccountWrapper bankInfoData;
        System.Savepoint sp = Database.setSavepoint();
        try {
            results = (List<BankTransactionWrapper>) JSON.deserialize(transactionList, List<BankTransactionWrapper>.class);
            bankInfoData = (BankAccountWrapper) JSON.deserialize(bankInfo, BankAccountWrapper.class);

            List<InsertWrapper> cdInsertList = new List<InsertWrapper>();
            List<InsertWrapper> crInsertList = new List<InsertWrapper>();
            List<InsertWrapper> jeInsertList = new List<InsertWrapper>();

            Map<Integer, BankTransactionWrapper> indexCRMap = new Map<Integer, BankDirectConnectHelper.BankTransactionWrapper>();
            Map<Integer, BankTransactionWrapper> indexCDMap = new Map<Integer, BankDirectConnectHelper.BankTransactionWrapper>();
            Map<Integer, BankTransactionWrapper> indexJEMap = new Map<Integer, BankDirectConnectHelper.BankTransactionWrapper>();
            Integer innerCRIndex = 0;
            Integer innerCDIndex = 0;
            Integer innerJEIndex = 0;

            for (BankTransactionWrapper res : results) {
                res.errors = new List<String>();
                if (res.isEdit && res.proxyObj.obj.Id == NULL) {
                    switch on res.selectedType {
                        when 'Cash Receipt' {
                            SObject cr = createRecordFromWrapper(res, bankInfoData);
                            if (!isRequiredFieldEmpty(cr, res)) {
                                crInsertList.add(new InsertWrapper(cr));
                                indexCRMap.put(innerCRIndex, res);
                                innerCRIndex ++;
                            }
                        }
                        when 'Cash Disbursement' {
                            SObject cd = createRecordFromWrapper(res, bankInfoData);
                            if (!isRequiredFieldEmpty(cd, res)) {
                                cdInsertList.add(new InsertWrapper(cd));
                                indexCDMap.put(innerCDIndex, res);
                                innerCDIndex ++;
                            }
                        }
                        when 'Journal Entry Credit', 'Journal Entry Debit' {
                            List<Journal_Entry_Line__c> lines = createJELRecordFromWrapper(res, bankInfoData);
                            if (!isJELRequiredFieldEmpty(lines, res)) {
                                jeInsertList.add(new InsertWrapper(lines, bankInfoData,res));
                                indexJEMap.put(innerJEIndex, res);
                                innerJEIndex ++;
                            }
                        }
                    }
                }
            }

            if (!crInsertList.isEmpty()) {
                List<Cash_Receipt__c> insertList = new List<Cash_Receipt__c>();
                insertList.addAll((List<Cash_Receipt__c>) getSObjects(crInsertList));

                CashReceiptActions.isSkipAutoGLAVsFromAccount = true;
                insertNewRecords(insertList, indexCRMap);
                CashReceiptActions.isSkipAutoGLAVsFromAccount = false;
            }

            if (!cdInsertList.isEmpty()) {
                SFDCSecurityUtils.insertProxy(getCDBatches(cdInsertList));
                setCDBatches(cdInsertList);

                List<Cash_Disbursement__c> insertList = new List<Cash_Disbursement__c>();
                insertList.addAll((List<Cash_Disbursement__c>) getSObjects(cdInsertList));

                insertNewRecords(insertList, indexCDMap);
            }

            if (!jeInsertList.isEmpty()) {
                SFDCSecurityUtils.insertProxy(getJournalEntries(jeInsertList));
                setJournalEntries(jeInsertList);
                List<Journal_Entry_Line__c> insertList = new List<Journal_Entry_Line__c>();
                insertList.addAll((List<Journal_Entry_Line__c>) getSObjects(jeInsertList));

                JournalEntryLineActions.isSkipAutoGLAVsFromAccount = true;
                insertNewRecords(insertList, indexJEMap);
                JournalEntryLineActions.isSkipAutoGLAVsFromAccount = false;
            }

            Map<Id, Cash_Receipt__c> insertedCRList = retrieveInsertedCRRecords(crInsertList);
            Map<Id, Cash_Disbursement__c> insertedCDList = retrieveInsertedCDRecords(cdInsertList);
            Map<Id, Journal_Entry_Line__c> insertedJELList = retrieveInsertedJELRecords(jeInsertList);

            List<Bank_Transaction__c> updateList = new List<Bank_Transaction__c>();

            Boolean isSaveError = false;
            for (BankTransactionWrapper btw : results) {
                if (btw.proxyObj.obj.Id != NULL) {
                    btw.setActionName(BankTransactionsHelper.BT_ADDED_STATUS);
                    updateList.add(btw.bt.obj);
                    if (insertedCRList != NULL && insertedCRList.containsKey(btw.proxyObj.obj.Id)) {
                        btw.setProxyObject(insertedCRList.get(btw.proxyObj.obj.Id));
                    }
                    if (insertedCDList != NULL && insertedCDList.containsKey(btw.proxyObj.obj.Id)) {
                        btw.setProxyObject(insertedCDList.get(btw.proxyObj.obj.Id));
                    }
                }
                if (insertedJELList != NULL && insertedJELList.containsKey(btw.bt.obj.Id) && btw.errors.isEmpty()) {
                    btw.setActionName(BankTransactionsHelper.BT_ADDED_STATUS);
                    updateList.add(btw.bt.obj);
                    btw.setProxyObject(insertedJELList.get(btw.bt.obj.Id));
                }
                if (!btw.errors.isEmpty()) {
                    isSaveError = true;
                }
            }

            if (!updateList.isEmpty()) {
                BankTransactionsHelper.updateBankTransactionsStatus(updateList, BankTransactionsHelper.BT_ADDED_STATUS);
            }

            if (isSaveError) {
                SFDCSecurityUtils.deleteProxy(getRollbackDeleteIds(cdInsertList, jeInsertList));
            }
        }
        catch (AuraHandledException ex) {
            isError = true;
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            isError = true;
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }
        catch (Exception ex) {
            isError = true;
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        finally {
            if (isError) {
                Database.rollback(sp);
            }
        }
        return results;
    }

    private static Boolean isJELRequiredFieldEmpty(List<Journal_Entry_Line__c> lines, BankTransactionWrapper btw) {
        Boolean result = false;
        List<String> resultFields = new List<String>();
        if (String.isBlank((String) lines[1].GL_Account__c)) {
            resultFields.add('GL Account');
            result = true;
        }

        if (isCashFlowStatementEnabled() && String.isBlank((String) lines[0].Cash_Flow_Category__c)) {
            resultFields.add('Cash Flow Category');
            result = true;
        }

        if (String.isBlank((btw.accountingPeriodId))) {
            resultFields.add('Accounting Period');
            result = true;
        }

        if (result) {
            addRequiredError(btw, resultFields);
        }
        return result;
    }

    private static Boolean isRequiredFieldEmpty(SObject obj, BankTransactionWrapper btw) {
        Boolean result = false;
        List<String> resultFields = new List<String>();
        switch on obj {
            when Cash_Receipt__c objRecord {
                if (String.isBlank((String) obj.get(Cash_Receipt__c.Account__c))) {
                    resultFields.add('Customer');
                    result = true;
                }
                if (String.isBlank((String) obj.get(Cash_Receipt__c.Credit_GL_Account__c))) {
                    resultFields.add('Credit GL Account');
                    result = true;
                }
            }
            when Cash_Disbursement__c objRecord {
                if (String.isBlank((String) obj.get(Cash_Disbursement__c.Vendor__c))) {
                    resultFields.add('Vendor');
                    result = true;
                }
                if (String.isBlank((String) obj.get(Cash_Disbursement__c.Debit_GL_Account__c))) {
                    resultFields.add('Debit GL Account');
                    result = true;
                }
            }
        }

        if (isCashFlowStatementEnabled() && String.isBlank((String) obj.get('Cash_Flow_Category__c'))) {
            resultFields.add('Cash Flow Category');
            result = true;
        }

        if (String.isBlank((String) obj.get('Accounting_Period__c'))) {
            resultFields.add('Accounting Period');
            result = true;
        }

        if (result) {
            addRequiredError(btw, resultFields);
        }
        return result;
    }

    private static void addRequiredError(BankTransactionWrapper btw, List<String> resultFields) {
        String fields = '';
        for (String fieldName : resultFields){
            fields += fieldName + ', ';
        }
        fields = fields.removeEnd(', ');
        btw.errors.add(String.format(REQUIRED_FIELD_ERROR, new List<String> {fields}));
    }

    private static List<Id> getRollbackDeleteIds(List<InsertWrapper> cdInsertList, List<InsertWrapper> jeInsertList) {
        List<Id> result = new List<Id>();

        List<InsertWrapper> commonList = new List<InsertWrapper>(cdInsertList);
        commonList.addAll(jeInsertList);

        for (InsertWrapper iw : commonList) {
            if (iw.obj.Id == NULL || (iw.obj.Id != NULL && iw.journalEntryLine != NULL && iw.journalEntryLine.Id == NULL)) {
                if (iw.cdBatch != NULL && iw.cdBatch.Id != NULL) {
                    result.add(iw.cdBatch.Id);
                }
                if (iw.journalEntry != NULL && iw.journalEntry.Id != NULL) {
                    result.add(iw.journalEntry.Id);
                }
                if (iw.journalEntryLine != NULL && iw.journalEntryLine.Id != NULL) {
                    result.add(iw.journalEntryLine.Id);
                }
            }
        }
        return result;
    }

    private static void insertNewRecords(List<SObject> insertList, Map<Integer, BankTransactionWrapper> indexMap) {
        Integer index = 0;
        Integer innerIndex;
        List<Database.SaveResult> saveResults = new List<Database.SaveResult>();
        SObjectActions.isPreventNonCloneableFieldsCleaning = true;
        switch on insertList[0] {
            when Cash_Disbursement__c objRecord {
                List<Cash_Disbursement__c> cdInsertList = (List<Cash_Disbursement__c>) insertList;
                saveResults = SFDCSecurityUtils.insertCheckCRUDAndFLS(cdInsertList, new List<String> (), false);
            }
            when Cash_Receipt__c objRecord {
                List<Cash_Receipt__c> crInsertList = (List<Cash_Receipt__c>) insertList;
                saveResults = SFDCSecurityUtils.insertCheckCRUDAndFLS(crInsertList, new List<String> (), false);
            }
            when Journal_Entry_Line__c objRecord {
                innerIndex = 0;
                List<Journal_Entry_Line__c> jelInsertList = (List<Journal_Entry_Line__c>) insertList;
                saveResults = SFDCSecurityUtils.insertCheckCRUDAndFLS(jelInsertList, new List<String> (), false);
            }
        }
        SObjectActions.isPreventNonCloneableFieldsCleaning = false;

        for (Database.SaveResult saveResult : saveResults) {
            if (!saveResult.isSuccess()) {
                indexMap.get(index).errors.add(saveResult.getErrors()[0].getMessage());
            }
            if (innerIndex == NULL) {
                index ++;
            }
            else {
                innerIndex ++;
                if (innerIndex == 2) {
                    index ++;
                    innerIndex = 0;
                }
            }
        }
    }

    private static Map<Id, Cash_Receipt__c> retrieveInsertedCRRecords(List<InsertWrapper> insertList) {
        return new Map<Id, Cash_Receipt__c>(DomainUtils.getCashReceiptById(getSObjectsId(insertList)));
    }

    private static Map<Id, Cash_Disbursement__c> retrieveInsertedCDRecords(List<InsertWrapper> insertList) {
        return new Map<Id, Cash_Disbursement__c>(DomainUtils.getCashDisbursementById(getSObjectsId(insertList)));
    }

    private static Map<Id, Journal_Entry_Line__c> retrieveInsertedJELRecords(List<InsertWrapper> insertList) {
        Map<Id, Journal_Entry_Line__c> result = new Map<Id, Journal_Entry_Line__c>();
        for (Journal_Entry_Line__c jel : DomainUtils.getJournalEntryLineById(getSObjectsId(insertList))) {
            if (jel.Bank_Transaction__c != NULL) {
                result.put(jel.Bank_Transaction__c, jel);
            }
        }
        return result;
    }

    private static Set<Id> getSObjectsId(List<InsertWrapper> insertList) {
        Set<Id> result = new Set<Id>();
        for (InsertWrapper iw : insertList) {
            result.add(iw.obj.Id);
        }
        return result;
    }

    private static List<SObject> getSObjects(List<InsertWrapper> insertList) {
        List<SObject> result = new List<SObject>();
        for (InsertWrapper iw : insertList) {
            result.add(iw.obj);
            if (iw.journalEntryLine != NULL) {
                result.add(iw.journalEntryLine);
            }
        }
        return result;
    }

    private static List<Journal_Entry__c> getJournalEntries(List<InsertWrapper> insertList) {
        List<Journal_Entry__c> result = new List<Journal_Entry__c>();
        for (InsertWrapper iw : insertList) {
            result.add(iw.journalEntry);
        }
        return result;
    }

    private static void setJournalEntries(List<InsertWrapper> insertList) {
        for (InsertWrapper iw : insertList) {
            iw.setJournalEntryId();
        }
    }

    private static List<Cash_Disbursement_Batch__c> getCDBatches(List<InsertWrapper> insertList) {
        List<Cash_Disbursement_Batch__c> result = new List<Cash_Disbursement_Batch__c>();
        for (InsertWrapper iw : insertList) {
            result.add(iw.cdBatch);
        }
        return result;
    }

    private static void setCDBatches(List<InsertWrapper> insertList) {
        for (InsertWrapper iw : insertList) {
            iw.setCDBatchId();
        }
    }

    public with sharing class InsertWrapper {
        public SObject obj;
        public Cash_Disbursement_Batch__c cdBatch;
        public Journal_Entry__c journalEntry;
        public Journal_Entry_Line__c journalEntryLine;
        private BankAccountWrapper bankInfoData;

        public InsertWrapper(SObject obj) {
            this.obj = obj;
            if (obj.getSObjectType() == Cash_Disbursement__c.getSObjectType()) {
                createCDBatch();
            }
        }

        public InsertWrapper(List<Journal_Entry_Line__c> objList, BankAccountWrapper bankInfoData,
                            BankTransactionWrapper res) {
            this.obj = objList[0];
            journalEntryLine = objList[1];
            this.bankInfoData = bankInfoData;
            if (obj.getSObjectType() == Journal_Entry_Line__c.getSObjectType()) {
                createJournalEntry(res);
            }
        }

        public void setCDBatchId() {
            if (cdBatch.Id != NULL) {
                obj.put(PACKAGE_QUALIFIER + 'Cash_Disbursement_Batch__c', cdBatch.Id);
            }
        }

        public void setJournalEntryId() {
            if (journalEntry.Id != NULL) {
                obj.put(PACKAGE_QUALIFIER + 'Journal_Entry__c', journalEntry.Id);
                journalEntryLine.Journal_Entry__c = journalEntry.Id;
            }
        }

        private void createCDBatch() {
            cdBatch = new Cash_Disbursement_Batch__c();
            cdBatch.Name = String.valueOf(System.now().format());

            if (AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED) {
                cdBatch.put('CurrencyIsoCode', (String) obj.get('CurrencyIsoCode'));
            }
        }

        private void createJournalEntry(BankTransactionWrapper res) {
            journalEntry = new Journal_Entry__c();
            journalEntry.Journal_Date__c = (Date) obj.get('Date__c');
            journalEntry.Name = JournalEntryActions.BDC + '-' + res.bt.obj.Source__c.replaceAll(' ','') +'-' + res.bt.obj.Name + '-' + System.today().format();
            journalEntry.Accounting_Period__c = (Id) AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(journalEntry.Journal_Date__c).Id;
            journalEntry.Ledger__c = bankInfoData.ledgerId;
            journalEntry.Source__c = JournalEntryActions.SOURCE_BDC;
            if (AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED) {
                journalEntry.put('CurrencyIsoCode', (String) obj.get('CurrencyIsoCode'));
            }
        }

    }

    private static List<BankTransactionWrapper> getBTWrapperWithRelated(List<Bank_Transaction__c> bts, TransactionFilter filter) {
        List<BankTransactionWrapper> result = new List<BankDirectConnectHelper.BankTransactionWrapper>();
        Boolean relatedFilter = String.isNotEmpty(filter.glAccount) || String.isNotEmpty(filter.customerId);

        BankTransactionWrapper wbt;
        for (Bank_Transaction__c bt : bts) {
            wbt = NULL;
            if (bt.Cash_Disbursements__r != NULL && !bt.Cash_Disbursements__r.isEmpty()) {
                wbt = new BankTransactionWrapper(bt, bt.Cash_Disbursements__r[0]);
            }
            else if (bt.Cash_Receipts__r != NULL && !bt.Cash_Receipts__r.isEmpty()) {
                wbt = new BankTransactionWrapper(bt, bt.Cash_Receipts__r[0]);
            }
            else if (bt.Journal_Entry_Lines__r != NULL && !bt.Journal_Entry_Lines__r.isEmpty()) {
                wbt = new BankTransactionWrapper(bt, bt.Journal_Entry_Lines__r[0]);
            }
            else if (bt.Bank_Deposits__r != NULL && !bt.Bank_Deposits__r.isEmpty()) {
                wbt =new BankTransactionWrapper(bt, bt.Bank_Deposits__r[0]);
            }
            else if (!relatedFilter) {
                wbt = new BankTransactionWrapper(bt, NULL);
            }
            if (wbt != NULL) {
                wbt.setDefaultAppliedObject();
                result.add(wbt);
            }
        }

        return result;
    }

    private static Boolean isFilterStatusUnmatched(TransactionFilter filter) {
        return filter.status != NULL && !filter.status.isEmpty() && filter.status.size() == 1 && filter.status[0] == 'Unmatched';
    }

    private static SObject createRecordFromWrapper(BankTransactionWrapper btw, BankAccountWrapper bankInfoData) {
        setCommonFields(btw, bankInfoData);
        switch on btw.selectedType {
            when 'Cash Receipt' {
                setCashReceipt(btw);
            }
            when 'Cash Disbursement' {
                setCashDisbursement(btw);
            }
        }

        return btw.proxyObj.obj;
    }

    private static List<Journal_Entry_Line__c> createJELRecordFromWrapper(BankTransactionWrapper btw, BankAccountWrapper bankInfoData) {
        List<Journal_Entry_Line__c> createdObject;
        switch on btw.bt.obj.Base_Type__c.toUpperCase(){
            when 'CREDIT' {
                createdObject = setJELDebit(btw, bankInfoData);
            }
            when 'DEBIT' {
                createdObject = setJELCredit(btw, bankInfoData);
            }
        }

        return createdObject;
    }

    private static List<Journal_Entry_Line__c> setJELDebit(BankTransactionWrapper btw, BankAccountWrapper bankInfoData) {
        Journal_Entry_Line__c mainLine = getCommonJEL(btw);
        Journal_Entry_Line__c oppositeLine = getCommonJEL(btw);

        setCommonMainJELFields(mainLine, btw, bankInfoData);
        mainLine.Debit__c = (Decimal)  btw.bt.obj.Amount__c;

        setCommonOppositeJELFields(oppositeLine, btw);
        oppositeLine.Credit__c = (Decimal)  btw.bt.obj.Amount__c;
        return new List<Journal_Entry_Line__c> {mainLine, oppositeLine};
    }

    private static List<Journal_Entry_Line__c> setJELCredit(BankTransactionWrapper btw, BankAccountWrapper bankInfoData) {
        Journal_Entry_Line__c mainLine = getCommonJEL(btw);
        Journal_Entry_Line__c oppositeLine = getCommonJEL(btw);

        setCommonMainJELFields(mainLine, btw, bankInfoData);
        mainLine.Credit__c = (Decimal) btw.bt.obj.Amount__c;

        setCommonOppositeJELFields(oppositeLine, btw);
        oppositeLine.Debit__c = (Decimal)  btw.bt.obj.Amount__c;
        return new List<Journal_Entry_Line__c> {mainLine, oppositeLine};
    }

    private static void setCommonMainJELFields(Journal_Entry_Line__c line, BankTransactionWrapper btw, BankAccountWrapper bankInfoData) {
        line.Bank_Transaction__c = btw.bt.obj.Id;
        line.Cleared_Date__c = btw.bt.obj.Date__c;
        line.GL_Account__c = bankInfoData.glAccountId;
        line.Date__c = btw.bt.obj.Date__c;
    }

    private static void setCommonOppositeJELFields(Journal_Entry_Line__c line, BankTransactionWrapper btw) {
        line.Date__c = btw.bt.obj.Date__c;
        line.Bank_Transaction__c = NULL;
    }

    private static Journal_Entry_Line__c getCommonJEL(BankTransactionWrapper btw) {
        Journal_Entry_Line__c journalEntryLine = ((Journal_Entry_Line__c) btw.proxyObj.obj).clone(false, true);
        if (AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED) {
            journalEntryLine.put('CurrencyIsoCode', (String) btw.bt.obj.get('CurrencyIsoCode'));
        }
        return journalEntryLine;
    }

    private static void setCashReceipt(BankTransactionWrapper btw) {
        ((Cash_Receipt__c) btw.proxyObj.obj).Payment_Reference__c = btw.bt.obj.Bank_Transaction_Id__c;
        ((Cash_Receipt__c) btw.proxyObj.obj).Receipt_Date__c = btw.bt.obj.Date__c;
    }

    private static void setCashDisbursement(BankTransactionWrapper btw) {
        ((Cash_Disbursement__c) btw.proxyObj.obj).Disbursement_Date__c = btw.bt.obj.Date__c;
        ((Cash_Disbursement__c) btw.proxyObj.obj).Source__c = 'Manual';
    }

    private static void setCommonFields(BankTransactionWrapper btw, BankAccountWrapper bankInfoData) {
        btw.proxyObj.obj.put('Amount__c', btw.bt.obj.Amount__c);
        btw.proxyObj.obj.put('Bank_Transaction__c', btw.bt.obj.Id);
        btw.proxyObj.obj.put('Cleared_Date__c', btw.bt.obj.Date__c);
        btw.proxyObj.obj.put('Bank_Account__c', bankInfoData.glAccountId);
        btw.proxyObj.obj.put('Ledger__c', bankInfoData.ledgerId);
        if (String.isNotBlank(btw.accountingPeriodId)) {
            btw.proxyObj.obj.put('Accounting_Period__c', btw.accountingPeriodId);
        }
        if (AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED) {
            btw.proxyObj.obj.put('CurrencyIsoCode', (String) btw.bt.obj.get('CurrencyIsoCode'));
        }
    }

    private static List<Bank_Transaction__c> getBTs(String bankAccountId, TransactionFilter filter) {
        //define fields to query
        List<String> queryFields = new List<String> {
            'Id',
            'Base_Type__c',
            'Type__c',
            'Bank_Transaction_Id__c',
            'Name',
            'Date__c',
            'Amount__c',
            'High_Level_Category_Id__c',
            'High_Level_Category__c',
            'Detail_Category_Id__c',
            'Detail_Category__c',
            'Category__c',
            'Account_Id__c',
            'Source__c',
            'Status__c',
            'Description__c',
            'GL_Account_Mapping__c'
        };

        if (AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED) {
            queryFields.add('CurrencyIsoCode');
        }

        //All BTs with the special Status value will be filtered out
        String statusReservedForInternalUsageOnly = BankTransactionsHelper.BT_IN_PROCESS_STATUS;

        String queryCondition =
            PACKAGE_QUALIFIER + 'Account_Id__c = :bankAccountId ' +
            'AND ' + PACKAGE_QUALIFIER + 'Status__c != :statusReservedForInternalUsageOnly';

        if (filter.status != NULL && !filter.status.isEmpty() && !filter.status.contains('All')) {
            List<String> status = filter.status;
            queryCondition += ' AND Status__c IN :status';
        }
        if (String.isNotEmpty(filter.transactionType) && filter.transactionType != 'All') {
            String transactionType = filter.transactionType;
            queryCondition += ' AND ' + PACKAGE_QUALIFIER + 'Base_Type__c = :transactionType';
        }
        if (String.isNotEmpty(filter.reference)) {
            String reference = '%' + filter.reference + '%';
            queryCondition += ' AND ' + PACKAGE_QUALIFIER + 'Description__c like :reference';
        }
        if (filter.dateStart != null) {
            Date dateStart = filter.dateStart;
            queryCondition += ' AND ' + PACKAGE_QUALIFIER + 'Date__c >= :dateStart';
        }
        if (filter.dateEnd != null) {
            Date dateEnd = filter.dateEnd;
            queryCondition += ' AND ' + PACKAGE_QUALIFIER + 'Date__c <= :dateEnd';
        }
        if (filter.amountStart != null) {
            Decimal amountStart = filter.amountStart;
            queryCondition += ' AND ' + PACKAGE_QUALIFIER + 'Amount__c >= :amountStart';
        }
        if (filter.amountEnd != null) {
            Decimal amountEnd = filter.amountEnd;
            queryCondition += ' AND ' + PACKAGE_QUALIFIER + 'Amount__c <= :amountEnd';
        }

        String subQueryCR = PACKAGE_QUALIFIER + 'Cash_Receipts__r';
        List<String> subQueryCRFields = new List<String> {
            'Name',
            PACKAGE_QUALIFIER + 'Receipt_Date__c',
            PACKAGE_QUALIFIER + 'Description__c',
            PACKAGE_QUALIFIER + 'Account__c',
            PACKAGE_QUALIFIER + 'Amount__c'
        };
        String subQueryCRCondition = getSubQueryCondition(filter, 'Credit_GL_Account__c', 'Account__c');
        subQueryCRCondition = String.isBlank(subQueryCRCondition) ? subQueryCRCondition : subQueryCRCondition + ' AND ';
        subQueryCRCondition += PACKAGE_QUALIFIER + 'Void__c = false';

        String subQueryCD = PACKAGE_QUALIFIER + 'Cash_Disbursements__r';
        List<String> subQueryCDFields = new List<String> {
            'Name',
            PACKAGE_QUALIFIER + 'Disbursement_Date__c',
            PACKAGE_QUALIFIER + 'Description__c',
            PACKAGE_QUALIFIER + 'Vendor__c'
        };
        String subQueryCDCondition = getSubQueryCondition(filter, 'Debit_GL_Account__c', 'Vendor__c');

        String subQueryJEL = PACKAGE_QUALIFIER + 'Journal_Entry_Lines__r';
        List<String> subQueryJELFields = new List<String> {
            'Name',
            PACKAGE_QUALIFIER + 'Date__c',
            PACKAGE_QUALIFIER + 'Description__c',
            PACKAGE_QUALIFIER + 'Account__c',
            PACKAGE_QUALIFIER + 'Journal_Entry__r.Journal_Date__c'
        };
        String subQueryJELCondition = getSubQueryCondition(filter, 'GL_Account__c', 'Account__c');

        String subQueryBD = PACKAGE_QUALIFIER + 'Bank_Deposits__r';
        List<String> subQueryBDFields = new List<String> {
            'Name',
            PACKAGE_QUALIFIER + 'Deposit_Date__c',
            PACKAGE_QUALIFIER + 'Deposit_Reference__c'
        };
        String subQueryBDCondition = getSubQueryCondition(filter, 'Bank_Account__c', NULL);

        String glAccount;
        if (String.isNotEmpty(filter.glAccount)) {
            glAccount = filter.glAccount;
        }
        String customerId;
        if (String.isNotEmpty(filter.customerId)) {
            customerId = filter.customerId;
        }

        SOQLBuilder.Ordering ordering = new SOQLBuilder.Ordering('Bank_Transaction__c', 'Date__c', SOQLBuilder.SortOrder.DESCENDING);

        SOQLBuilder theQuery = new SOQLBuilder(Bank_Transaction__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .addOrdering(ordering)
            .setLimit(BT_LOAD_LIMIT);
        if (!isFilterStatusUnmatched(filter)) {
            if (String.isNotBlank(subQueryCRCondition)) {
                theQuery
                    .subselectQuery(subQueryCR, false)
                    .setEnforceFLS(true)
                    .selectFields(subQueryCRFields)
                    .setCondition(subQueryCRCondition);
            }
            else {
                theQuery
                    .subselectQuery(subQueryCR, false)
                    .setEnforceFLS(true)
                    .selectFields(subQueryCRFields);
            }
            if (String.isNotBlank(subQueryCDCondition)) {
                theQuery
                    .subselectQuery(subQueryCD, false)
                    .setEnforceFLS(true)
                    .selectFields(subQueryCDFields)
                    .setCondition(subQueryCDCondition);
            }
            else {
                theQuery
                    .subselectQuery(subQueryCD, false)
                    .setEnforceFLS(true)
                    .selectFields(subQueryCDFields);
            }
            if (String.isNotBlank(subQueryJELCondition)) {
                theQuery
                    .subselectQuery(subQueryJEL, false)
                    .setEnforceFLS(true)
                    .selectFields(subQueryJELFields)
                    .setCondition(subQueryJELCondition);
            }
            else {
                theQuery
                    .subselectQuery(subQueryJEL, false)
                    .setEnforceFLS(true)
                    .selectFields(subQueryJELFields);
            }
            if (String.isNotBlank(subQueryBDCondition)) {
                theQuery
                    .subselectQuery(subQueryBD, false)
                    .setEnforceFLS(true)
                    .selectFields(subQueryBDFields)
                    .setCondition(subQueryBDCondition);
            }
            else if (String.isEmpty(filter.customerId)) {
                theQuery
                    .subselectQuery(subQueryBD, false)
                    .setEnforceFLS(true)
                    .selectFields(subQueryBDFields);
            }
        }
        return Database.query(theQuery.toSOQL());
    }

    private static String getSubQueryCondition(TransactionFilter filter, String glAccountName, String customerName) {
        String result = '';
        if (String.isNotEmpty(filter.glAccount)) {
            String glAccount = filter.glAccount;
            result += PACKAGE_QUALIFIER + glAccountName + ' = :glAccount';
        }
        if (String.isNotEmpty(filter.customerId) && customerName != NULL) {
            result = String.isBlank(result) ? result : result + ' AND ';
            String customerId = filter.customerId;
            result += PACKAGE_QUALIFIER + customerName + ' = :customerId';
        }

        return result;
    }

    private static String getCurrencyIsoCode(SObject obj) {
        String result;
        if (AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED) {
            result = (String) obj.get('CurrencyIsoCode');
        }
        else {
            result = MultiCurrencyHandler.CORPORATE_CURRENCY;
        }
        return result;
    }

    public with sharing class BankAccountWrapper {
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String bankAccountName;
        @AuraEnabled
        public String bankAccountId;
        @AuraEnabled
        public String glAccountId;
        @AuraEnabled
        public String currencyIsoCode;
        @AuraEnabled
        public String ledgerId;
        @AuraEnabled
        public Boolean isMultiCurrencyEnabled = AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED;
        @AuraEnabled
        public Datetime lastRefreshedDate;
        @AuraEnabled
        public Decimal availableBalance;
        @AuraEnabled
        public Decimal currentBalance;
        @AuraEnabled
        public String fiaStatus;
        @AuraEnabled
        public Boolean isFIAStatusError;
        @AuraEnabled
        public Boolean isMFAAccount;
        @AuraEnabled
        public Date initialStartDate;
        @AuraEnabled
        public String createdDate;
        @AuraEnabled
        public String source;

        public BankAccountWrapper(GL_Account_Mapping__c mappingObject) {
            this.id = mappingObject.Id;
            this.bankAccountName = mappingObject.Account_Name__c;
            this.bankAccountId = mappingObject.External_Id__c;
            this.lastRefreshedDate = mappingObject.Last_Refreshed__c;
            this.availableBalance = mappingObject.Available_Balance__c;
            this.currentBalance = mappingObject.Current_Balance__c;
            this.ledgerId = mappingObject.Ledger__c;
            this.glAccountId = mappingObject.GL_Account__c;
            this.fiaStatus = mappingObject.FIA_Status__c;
            this.isFIAStatusError = !String.isEmpty(this.fiaStatus) && this.fiaStatus != BankTransactionsHelper.NO_ACTION_REQUIRED_MSG && this.fiaStatus != BankTransactionsHelper.USER_INPUT_REQUIRED_ERROR_MSG ? true : false;
            this.isMFAAccount = this.fiaStatus == BankTransactionsHelper.USER_INPUT_REQUIRED_ERROR_MSG;
            this.currencyIsoCode = getCurrencyIsoCode(mappingObject);
            this.initialStartDate = mappingObject.Initial_Start_Date__c;
            this.createdDate = mappingObject.createdDate.format();
            this.source = mappingObject.Source__c;
        }
    }

    public with sharing class TransactionFilter {
        public String customerId;
        public List<String> status;
        public String transactionType;
        public String glAccount;
        public String reference;
        public Date dateStart;
        public Date dateEnd;
        public Decimal amountStart;
        public Decimal amountEnd;
    }

    public with sharing class BankTransactionWrapper {
        @AuraEnabled
        public String Id;
        @AuraEnabled
        public SObjectDataBT bt;
        @AuraEnabled
        public SObjectData proxyObj;
        @AuraEnabled
        public SObjectData shadowProxyObj;
        @AuraEnabled
        public SObject defaultAppliedProxyObj;
        @AuraEnabled
        public String accountingPeriodId;
        @AuraEnabled
        public List<String> errors = new List<String>();
        @AuraEnabled
        public Boolean isEdit = false;
        @AuraEnabled
        public List<CustomSelectOption> availableTypes = new List<CustomSelectOption>();
        @AuraEnabled
        public String selectedType;
        @AuraEnabled
        public String unmatchedActionName;
        @AuraEnabled
        public String actionName;
        @AuraEnabled
        public Boolean actionDisabled = true;
        @AuraEnabled
        public DetailsWrapper details = new DetailsWrapper();
        @AuraEnabled
        public AmountStyleWrapper amountStyle = new AmountStyleWrapper();
        @AuraEnabled
        public List<PossibleMatchWrapper> possibleMatches = new List<PossibleMatchWrapper>();

        public BankTransactionWrapper(Bank_Transaction__c bt, SObject proxyObject) {
            this.bt = new SObjectDataBT(bt);
            this.Id = bt.Id;
            this.unmatchedActionName = ADD_ACTION;
            details.setErrorMessage(REQUIRED_FIELD_MISSED_ERROR);
            setAccountingPeriod();
            setProxyObject(proxyObject);
            setActionName(this.bt.obj.Status__c);
        }

        public void setProxyObject(SObject proxyObject) {
            if (proxyObject != NULL) {
                setProxyObjectBySobjectType(proxyObject);
            }
            else if (bt.obj.Base_Type__c.toUpperCase() == CREDIT_VALUE) {
                availableTypes = new List<CustomSelectOption>();
                availableTypes.add(new CustomSelectOption(RECEIPT_VALUE, RECEIPT_LABEL));
                availableTypes.add(new CustomSelectOption(JOURNAL_DEBIT_VALUE, JOURNAL_DEBIT_LABEL));

                if (AccountingSettingsHandler.getCashInDefaultSourceRecordType() == RECEIPT_VALUE
                    || AccountingSettingsHandler.getCashInDefaultSourceRecordType() == NULL) {
                    selectedType = RECEIPT_VALUE;
                    proxyObj = new SObjectDataCR(getCRProxyObject());
                    shadowProxyObj = new SObjectDataJEL(getJELProxyObject());
                }
                else {
                    selectedType = JOURNAL_DEBIT_VALUE;
                    proxyObj = new SObjectDataJEL(getJELProxyObject());
                    shadowProxyObj = new SObjectDataCR(getCRProxyObject());
                }
            }
            else if (bt.obj.Base_Type__c.toUpperCase() == DEBIT_VALUE) {
                availableTypes = new List<CustomSelectOption>();
                availableTypes.add(new CustomSelectOption(DEPOSIT_VALUE, DEPOSIT_LABEL));
                availableTypes.add(new CustomSelectOption(JOURNAL_CREDIT_VALUE, JOURNAL_CREDIT_LABEL));

                if (AccountingSettingsHandler.getCashOutDefaultSourceRecordType() == DEPOSIT_VALUE
                    || AccountingSettingsHandler.getCashOutDefaultSourceRecordType() == NULL) {
                    selectedType = DEPOSIT_VALUE;
                    proxyObj = new SObjectDataCD(getCDProxyObject());
                    shadowProxyObj = new SObjectDataJEL(getJELProxyObject());
                }
                else {
                    selectedType = JOURNAL_CREDIT_VALUE;
                    proxyObj = new SObjectDataJEL(getJELProxyObject());
                    shadowProxyObj = new SObjectDataCD(getCDProxyObject());
                }
            }

            amountStyle.setValue(bt.obj.Base_Type__c);
        }

        private void setProxyObjectBySobjectType(SObject proxyObject) {
            switch on proxyObject {
                when Cash_Disbursement__c objRecord {
                    proxyObj = new SObjectDataCD(objRecord);
                    shadowProxyObj = new SObjectDataJEL(getJELProxyObject());
                    selectedType = DEPOSIT_VALUE;
                }
                when Cash_Receipt__c objRecord {
                    proxyObj = new SObjectDataCR(objRecord);
                    shadowProxyObj = new SObjectDataJEL(getJELProxyObject());
                    selectedType = objRecord.Amount__c == null || objRecord.Amount__c >= 0 ? RECEIPT_VALUE : REFUND_RECEIPT_VALUE;
                }
                when Journal_Entry_Line__c objRecord {
                    proxyObj = new SObjectDataJEL(objRecord);
                    if (bt.obj.Base_Type__c.toUpperCase() == CREDIT_VALUE) {
                        shadowProxyObj = new SObjectDataCR(getCRProxyObject());
                        selectedType = JOURNAL_DEBIT_VALUE;
                    }
                    else if (bt.obj.Base_Type__c.toUpperCase() == DEBIT_VALUE) {
                        shadowProxyObj = new SObjectDataCD(getCDProxyObject());
                        selectedType = JOURNAL_CREDIT_VALUE;
                    }
                }
                when Bank_Deposit__c objRecord {
                    proxyObj = new SObjectDataBD(objRecord);
                    shadowProxyObj = new SObjectDataJEL(getJELProxyObject());
                    selectedType = BANK_DEPOSIT_VALUE;
                }
            }

        }

        public void setPossibleMatch(List<SObject> objs, Boolean resetAll) {
            if (resetAll) {
                possibleMatches = new List<PossibleMatchWrapper>();
            }

            for (SObject obj : objs) {
                switch on obj {
                    when Cash_Disbursement__c objRecord {
                        PossibleMatchWrapper pw = new PossibleMatchWrapper(new SObjectDataCD(objRecord));
                        possibleMatches.add(pw);
                    }
                    when Cash_Receipt__c objRecord {
                        PossibleMatchWrapper pw = new PossibleMatchWrapper(new SObjectDataCR(objRecord));
                        possibleMatches.add(pw);
                    }
                    when Journal_Entry_Line__c objRecord {
                        PossibleMatchWrapper pw = new PossibleMatchWrapper(new SObjectDataJEL(objRecord));
                        possibleMatches.add(pw);
                    }
                    when Bank_Deposit__c objRecord {
                        PossibleMatchWrapper pw = new PossibleMatchWrapper(new SObjectDataBD(objRecord));
                        possibleMatches.add(pw);
                    }
                }
            }

            if (!possibleMatches.isEmpty()) {
                if (possibleMatches.size() == 1) {
                    details.setInfoMessage('1 ' + Label.COMMON_RECORD_FOUND);
                    details.setRecord(possibleMatches[0]);
                    unmatchedActionName = MATCH_ACTION;
                    actionDisabled = false;
                }
                else {
                    details.setInfoMessage(String.valueOf(possibleMatches.size()) + ' ' + Label.COMMON_RECORDS_FOUND);
                    details.setRecord(NULL);
                    unmatchedActionName = VIEW_ACTION;
                    actionDisabled = true;
                }
                possibleMatches[0].checked = true;
                setDefaultPossibleMatchFields(possibleMatches[0]);
            }
        }

        public void updateExistedPossibleMatch() {
            setDefaultPossibleMatchFields(possibleMatches[0]);
        }

        public void setDefaultAppliedObject() {
            defaultAppliedProxyObj = proxyObj.obj.clone();
        }

        public void swapProxyObject() {
            AbstractLWCHelper.SObjectData tempCopy = new AbstractLWCHelper.SObjectData(proxyObj);
            proxyObj = new AbstractLWCHelper.SObjectData(shadowProxyObj);
            shadowProxyObj = tempCopy;
            setSelectedTypeBasedOnSObjectType(proxyObj.obj);
        }

        private void setSelectedTypeBasedOnSObjectType(SObject obj) {
            switch on obj {
                when Cash_Disbursement__c cd {
                    selectedType = DEPOSIT_VALUE;
                }
                when Cash_Receipt__c cr {
                    selectedType = cr.Amount__c == null || cr.Amount__c >= 0 ? RECEIPT_VALUE : REFUND_RECEIPT_VALUE;
                }
                when Journal_Entry_Line__c jel {
                    if (bt.obj.Base_Type__c.toUpperCase() == CREDIT_VALUE) {
                        selectedType = JOURNAL_DEBIT_VALUE;
                    }
                    else if (bt.obj.Base_Type__c.toUpperCase() == DEBIT_VALUE) {
                        selectedType = JOURNAL_CREDIT_VALUE;
                    }
                }
                when Bank_Deposit__c objRecord {
                    selectedType = BANK_DEPOSIT_VALUE;
                }
            }
        }

        public void setActionName(String btStatus) {
            switch on btStatus {
                when 'Matched', 'Added' {
                    actionName = UNMATCH_ACTION;
                }
                when 'Removed'{
                    actionName = RESTORE_ACTION;
                }
                when 'Unmatched' {
                    actionName = REMOVE_ACTION;
                }
            }
        }

        private void validateRequiredFields() {
            Boolean commonFields = String.isNotBlank(accountingPeriodId)
                && (!isCashFlowStatementEnabled() || isCashFlowStatementEnabled() && proxyObj.obj.get('Cash_Flow_Category__c') != NULL);

            switch on proxyObj.obj {
                when Cash_Disbursement__c rec {
                    if (rec.Vendor__c != NULL && rec.Debit_GL_Account__c != NULL && commonFields) {
                        actionDisabled = false;
                    }
                }
                when Cash_Receipt__c rec {
                    if (rec.Account__c != NULL && rec.Credit_GL_Account__c != NULL && commonFields) {
                        actionDisabled = false;
                    }
                }
                when Journal_Entry_Line__c rec {
                    if (rec.GL_Account__c != NULL && commonFields) {
                        actionDisabled = false;
                    }
                }
            }

            if (!actionDisabled) {
                details.resetMessage();
            }
        }

        private void setAccountingPeriod() {
            if (AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(this.bt.obj.Date__c) != NULL) {
                accountingPeriodId = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(this.bt.obj.Date__c).Id;
            }
            else {
                details.setErrorMessage(PERIOD_NOT_EXIST_ERROR);
            }
        }

        private void setDefaultPossibleMatchFields(PossibleMatchWrapper pw) {
            switch on pw.possibleMatch.obj {
                when Cash_Disbursement__c objRecord {
                    selectedType = DEPOSIT_VALUE;
                }
                when Cash_Receipt__c objRecord {
                    selectedType = objRecord.Amount__c == null || objRecord.Amount__c >= 0 ? RECEIPT_VALUE : REFUND_RECEIPT_VALUE;
                }
                when Bank_Deposit__c objRecord {
                    selectedType = BANK_DEPOSIT_VALUE;
                }
                when Journal_Entry_Line__c objRecord {
                    if (bt.obj.Base_Type__c.toUpperCase() == CREDIT_VALUE) {
                        selectedType = JOURNAL_DEBIT_VALUE;
                    }
                    else if (bt.obj.Base_Type__c.toUpperCase() == DEBIT_VALUE) {
                        selectedType = JOURNAL_CREDIT_VALUE;
                    }
                }
            }

            if (pw.possibleMatch.obj.getSObjectType() != Bank_Deposit__c.getSObjectType()) {
                proxyObj.obj.put(accountField.get(proxyObj.sobjType), pw.possibleMatch.obj.get(accountField.get(pw.possibleMatch.sobjType)));
            }
            proxyObj.obj.put(glAccountField.get(proxyObj.sobjType), pw.possibleMatch.obj.get(glAccountField.get(pw.possibleMatch.sobjType)));
            proxyObj.obj.put(descriptionField.get(proxyObj.sobjType), pw.possibleMatch.obj.get(descriptionField.get(pw.possibleMatch.sobjType)));
        }

        private Cash_Disbursement__c getCDProxyObject() {
            Cash_Disbursement__c result = new Cash_Disbursement__c();
            result.Accounting_Period__c = accountingPeriodId;
            result.Description__c = bt.obj.Description__c;
            if (isCashFlowStatementEnabled()) {
                Id ledgerId = LedgerHandler.getInstanceWithoutSharing().getTransactionalLedgers()[0].Id;
                Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(ledgerId);
                result.Cash_Flow_Category__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.DEFAULT_CASH_DISBURSEMENT_CATEGORY)?.GL_Account__c;
            }
            return result;
        }

        private Cash_Receipt__c getCRProxyObject() {
            Cash_Receipt__c result = new Cash_Receipt__c();
            result.Accounting_Period__c = accountingPeriodId;
            result.Description__c = bt.obj.Description__c;
            if (isCashFlowStatementEnabled()) {
                Id ledgerId = LedgerHandler.getInstanceWithoutSharing().getTransactionalLedgers()[0].Id;
                Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(ledgerId);
                result.Cash_Flow_Category__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.DEFAULT_CASH_RECEIPT_CATEGORY)?.GL_Account__c;
            }
            return result;
        }

        private Journal_Entry_Line__c getJELProxyObject() {
            Journal_Entry_Line__c result = new Journal_Entry_Line__c();
            result.Description__c = bt.obj.Description__c;
            if (isCashFlowStatementEnabled()) {
                Id ledgerId = LedgerHandler.getInstanceWithoutSharing().getTransactionalLedgers()[0].Id;
                Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(ledgerId);
                result.Cash_Flow_Category__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.DEFAULT_JOURNAL_ENTRY_LINE_CATEGORY)?.GL_Account__c;
            }
            return result;
        }

    }

    public with sharing class SObjectDataBT {
        @AuraEnabled
        public Bank_Transaction__c obj;
        @AuraEnabled
        public String sobjType;
        @AuraEnabled
        public String recordURL;
        @AuraEnabled
        public String currencyIsoCode;
        @AuraEnabled
        public Boolean isMultiCurrencyEnabled = AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED;

        public SObjectDataBT(Bank_Transaction__c obj) {
            this.obj = obj;
            this.sobjType = PACKAGE_QUALIFIER + 'Bank_Transaction__c';
            if (obj.Id != NULL) {
                this.recordURL = AbstractLWCHelper.getUrl(this.obj.Id);
            }
            this.currencyIsoCode = getCurrencyIsoCode(obj);
        }

    }

    public with sharing class SObjectDataCD extends SObjectData {

        public SObjectDataCD(Cash_Disbursement__c obj) {
            this.obj = obj;
            this.sobjType = PACKAGE_QUALIFIER + 'Cash_Disbursement__c';
            if (obj.Id != NULL) {
                this.recordURL = AbstractLWCHelper.getUrl(this.obj.Id);
            }
        }
    }

    public with sharing class SObjectDataCR extends SObjectData {

        public SObjectDataCR(Cash_Receipt__c obj) {
            this.obj = obj;
            this.sobjType = PACKAGE_QUALIFIER + 'Cash_Receipt__c';
            if (obj.Id != NULL) {
                this.recordURL = AbstractLWCHelper.getUrl(this.obj.Id);
            }
        }
    }

    public with sharing class SObjectDataJEL extends SObjectData {

        public SObjectDataJEL(Journal_Entry_Line__c obj) {
            this.obj = obj;
            this.sobjType = PACKAGE_QUALIFIER + 'Journal_Entry_Line__c';
            if (obj.Id != NULL) {
                this.recordURL = AbstractLWCHelper.getUrl(this.obj.Id);
            }
        }
    }

    public with sharing class SObjectDataBD extends SObjectData {

        public SObjectDataBD(Bank_Deposit__c obj) {
            this.obj = obj;
            this.sobjType = PACKAGE_QUALIFIER + 'Bank_Deposit__c';
            if (obj.Id != NULL) {
                this.recordURL = AbstractLWCHelper.getUrl(this.obj.Id);
            }
        }
    }

    public with sharing class PossibleMatchWrapper {
        @AuraEnabled
        public SObjectData possibleMatch;
        @AuraEnabled
        public Boolean checked = false;
        @AuraEnabled
        public Boolean isJEObject = false;
        @AuraEnabled
        public Boolean isCDObject = false;
        @AuraEnabled
        public Boolean isRefundCRObject = false;
        @AuraEnabled
        public Boolean isBDObject = false;
        @AuraEnabled
        public String journalEntryId;
        @AuraEnabled
        public String journalEntrySobjectType = PACKAGE_QUALIFIER + 'Journal_Entry__c';
        @AuraEnabled
        public String dateFieldName;
        @AuraEnabled
        public String accountFieldName;
        @AuraEnabled
        public String glAccountFieldName;
        @AuraEnabled
        public String descriptionFieldName;
        @AuraEnabled
        public String checkNumberFieldName;
        @AuraEnabled
        public String payeeFieldName;

        public PossibleMatchWrapper(SObjectData possibleMatch) {
            this.possibleMatch = possibleMatch;
            setFieldsBySObjectType();
        }

        private void setFieldsBySObjectType() {
            switch on possibleMatch.obj {
                when Cash_Disbursement__c objRecord {
                    isCDObject = true;
                    dateFieldName = PACKAGE_QUALIFIER + 'Disbursement_Date__c';
                    accountFieldName = PACKAGE_QUALIFIER + 'Vendor__c';
                    glAccountFieldName = PACKAGE_QUALIFIER + 'Debit_GL_Account__c';
                    descriptionFieldName = PACKAGE_QUALIFIER + 'Description__c';
                    checkNumberFieldName = PACKAGE_QUALIFIER + 'Check_Number__c';
                    if (objRecord.get(Cash_Disbursement__c.Vendor__c) != NULL) {
                        payeeFieldName = PACKAGE_QUALIFIER + 'Vendor__c';
                    }
                    else if (objRecord.get(Cash_Disbursement__c.Contact__c) != NULL) {
                        payeeFieldName = PACKAGE_QUALIFIER + 'Contact__c';
                    }
                    else if (objRecord.get(Cash_Disbursement__c.Employee__c) != NULL) {
                        payeeFieldName = PACKAGE_QUALIFIER + 'Employee__c';
                    }
                }
                when Cash_Receipt__c objRecord {
                    isRefundCRObject = objRecord.Amount__c < 0;
                    dateFieldName = PACKAGE_QUALIFIER + 'Receipt_Date__c';
                    accountFieldName = PACKAGE_QUALIFIER + 'Account__c';
                    glAccountFieldName = PACKAGE_QUALIFIER + 'Credit_GL_Account__c';
                    descriptionFieldName = PACKAGE_QUALIFIER + 'Description__c';
                    checkNumberFieldName = PACKAGE_QUALIFIER + 'Check_Number__c';
                    payeeFieldName = accountFieldName;
                }
                when Journal_Entry_Line__c objRecord {
                    isJEObject = true;
                    journalEntryId = objRecord.Journal_Entry__c;
                    dateFieldName = PACKAGE_QUALIFIER + 'Journal_Date__c';
                    accountFieldName = PACKAGE_QUALIFIER + 'Account__c';
                    glAccountFieldName = PACKAGE_QUALIFIER + 'GL_Account__c';
                    descriptionFieldName = PACKAGE_QUALIFIER + 'Description__c';
                    if (objRecord.get(Journal_Entry_Line__c.Account__c) != NULL) {
                        payeeFieldName = PACKAGE_QUALIFIER + 'Account__c';
                    }
                    else if (objRecord.get(Journal_Entry_Line__c.Contact__c) != NULL) {
                        payeeFieldName = PACKAGE_QUALIFIER + 'Contact__c';
                    }
                    else if (objRecord.get(Journal_Entry_Line__c.Employee__c) != NULL) {
                        payeeFieldName = PACKAGE_QUALIFIER + 'Employee__c';
                    }
                }
                when Bank_Deposit__c objRecord {
                    isBDObject = true;
                    dateFieldName = PACKAGE_QUALIFIER + 'Deposit_Date__c';
                    accountFieldName = '';
                    glAccountFieldName = PACKAGE_QUALIFIER + 'Bank_Account__c';
                    descriptionFieldName = PACKAGE_QUALIFIER + 'Deposit_Reference__c';
                }
            }
        }
    }

    public with sharing class DetailsWrapper {
        @AuraEnabled
        public String details;
        @AuraEnabled
        public String recordName;
        @AuraEnabled
        public String recordURL;
        @AuraEnabled
        public Date recordDate;
        @AuraEnabled
        public String detailsStyle = '';

        public void setRecord(PossibleMatchWrapper record) {
            if (record != NULL) {
                if (record.possibleMatch.obj.Id != NULL) {
                    recordURL = AbstractLWCHelper.getUrl(record.possibleMatch.obj.Id);
                }

                recordName = (String) record.possibleMatch.obj.get('Name');
                switch on record.possibleMatch.obj {
                    when Cash_Disbursement__c objRecord {
                        recordDate = (Date) objRecord.get(record.dateFieldName);
                    }
                    when Cash_Receipt__c objRecord {
                        recordDate = (Date) objRecord.get(record.dateFieldName);
                    }
                    when Bank_Deposit__c objRecord {
                        recordDate = (Date) objRecord.get(record.dateFieldName);
                    }
                    when Journal_Entry_Line__c objRecord {
                        recordDate = (Date) objRecord.Journal_Entry__r.Journal_Date__c;
                    }
                }
            }
            else {
                recordURL = NULL;
                recordName = NULL;
                recordDate = NULL;
            }
        }

        public void setInfoMessage(String message) {
            details = message;
            detailsStyle = 'color: #5e9a3f';
        }

        public void setErrorMessage(String message) {
            details = message;
            detailsStyle = 'color: #b80707';
        }

        public void resetMessage() {
            details = NULL;
            detailsStyle = '';
        }
    }

    public with sharing class AmountStyleWrapper {
        @AuraEnabled
        public String valueStyle = '';
        @AuraEnabled
        public Boolean valueParentheses = false;

        public void setValue(String btType) {
            if (btType.toUpperCase() == DEBIT_VALUE) {
                valueStyle = 'color: #b80707';
                valueParentheses = true;
            }
        }
    }

    @AuraEnabled
    public static BDCServiceResult fetchTransactions(String extId){
        try {
            
            BDCServiceResult serviceResult = new BDCServiceResult(); 
            PlaidBDCTransactionBulk transactionBulk = new PlaidBDCTransactionBulk();
            
            for(GL_Account_Mapping__c mapping : DomainUtils.getGLAccountMappings(true)){
               
                if(mapping.External_Id__c == extId) {
                    transactionBulk.byPassEarliestRefrshDateLogic = true;
                    serviceResult = transactionBulk.startTransactionProcess(new List<GL_Account_Mapping__c>{mapping});
                    break;
                }
            }
            return serviceResult;
        } catch (Exception e) {
            throw new BDCService.BDCException(Label.TRANSACTION_DOWNLOAD_EXECPTION_ERROR + ' ' +e.getMessage() + ' ' + Label.COMMON_AT + e.getLineNumber());
        }
    }

}