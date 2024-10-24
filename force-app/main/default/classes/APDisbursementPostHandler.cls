public with sharing class APDisbursementPostHandler extends AbstractPostHandler {

    public final static String NO_CONTROL_ACCOUNT_MESSAGE = Label.ERR_NO_CONTROL_ACCOUNT_AP_DISBURSEMENTS;
    public final static String DEBIT_GL_ACCOUNT_VALIDATION_ON_INSERT_ERROR_MESSAGE = Label.ERR_DEBIT_GL_ACCOUNT_VALIDATION_ON_INSERT;
    public final static String DEBIT_GL_ACCOUNT_VALIDATION_ON_POST_ERROR_MESSAGE = Label.ERR_DEBIT_GL_ACCOUNT_VALIDATION_ON_POST;
    public static final String LINE_COUNT_LIMIT_EXCEEDED_ERROR_MESSAGE = Label.ERR_PAYABLE_LINE_COUNT_LIMIT_EXCEEDED;
    public static final Integer LINE_COUNT_LIMIT = 500;
    public ProportionalDistributionHelper pdHelper;
    private static AbstractTaxService service = AccountingSettingsHandler.isHeaderLevelPost()
        ? (AbstractTaxService) new NativeTaxHeaderLevel() : (AbstractTaxService) new NativeTaxLineLevel();
    private Map<Id, List<Transaction__c>> resultTransList = new Map<Id, List<Transaction__c>>();
    private Set<Id> ldvFirstRun = new Set<Id>();
    private Decimal roundingBalance = 0;
    private Decimal foreignRoundingBalance = 0;
    private Map<String, Transaction__c> roundingAdjustment = new Map<String, Transaction__c>();

    //========================================================================================
    //=================== POST method implementation for AP Disbursements ====================

    public override List<PostResult> post(List<LDVPostInput> sourceItems) {
        isLDVBatchContext = true;
        Map<Id, LDVPostInput> sourceMap = new Map<Id, LDVPostInput>();
        Map<Id, PostResult> postResults = new Map<Id, PostResult>();
        List<String> processedRecordsIds = new List<String>();
        List<SObject> sobjectsLines = new List<SObject>();
        for (LDVPostInput item : sourceItems) {
            processedRecordsIds.addAll(new List<Id> (new Map<Id, SObject> (item.relatedObjects).keySet()));
            sobjectsLines.addAll(item.lines);
            sourceMap.put(item.id, item);
            if (item.transactionGroup.Lines_Processed__c <= PostProcessor.BATCH_CHUNK_SIZE) {
                ldvFirstRun.addAll(new List<Id> (new Map<Id, SObject> (item.relatedObjects).keySet()));
            }
        }
        this.processedRecordIds = processedRecordsIds;
        if (!this.processedRecordIds.isEmpty()) {
            main = getAccountingSettings();
            //Initial query for AP Disbursements
            queryAPDisbursements();//AP Disbursements will be stored in the 'sourceRecords' property
            List<SObject> sourceWithCash = filterRecordsByAcctMethod(
                this.sourceRecords,
                new Set<String>{LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH, LedgerActions.ACCOUNTING_METHOD_CASH}
            );
            if (!sourceWithCash.isEmpty()) {
                pdHelper = new ProportionalDistributionHelper(sourceWithCash, sobjectsLines);
            }
            getGLAccountDefaults();
            if (validateControlGLAccount()) {
                try {
                    validateNotPosted(false);
                    //to proceed further - Debit GL Account on Cash Disbursement must be not NULL or not set to the AP Control Account
                    validateDebitGLAccount(true);
                    validateAccountingPeriodIsOpen(false);
                    validateInactiveLedger();

                    if (!sourceRecords.isEmpty()) {
                        for (AP_Disbursement__c apd : (List<AP_Disbursement__c>) sourceRecords) {
                            PostResult res = new PostResult(true, apd.Id, '', sourceMap.get(apd.Account_Payable__c).transactionGroup);
                            postResults.put(apd.Id, res);
                        }
                        processAPDisbursementTransactions();
                        processPostResult();
                        for (AP_Disbursement__c apd : (List<AP_Disbursement__c>) sourceRecords) {
                            PostResult res = postResults.get(apd.Id);
                            res.transactions.addAll(resultTransList.get(apd.Id));
                        }
                    }
                }
                catch (System.DmlException dmlEx) {
                    processDmlExceptions(dmlEx);
                }
                catch (Exception ex) {
                    processSystemExceptions(ex);
                }
            }
        }
        ldvValidatePostResultMap(postResults);
        ldvValidateExceptionPostResultMap(postResults);
        return postResults.values();
    }

    public void processLDVPostTransactionConsolidation(List<PostResult> processedResults) {

        Savepoint sp;
        if(!Test.isRunningTest()) {
            sp = Database.setSavepoint();
        }

        try {
            List<Transaction__c> transList = new List<Transaction__c>();
            Map<Id, AP_Disbursement__c> needUpdateStatus = new Map<Id, AP_Disbursement__c>();
            Set<String> transactionKeys = new Set<String>();

            for (PostResult item : processedResults) {
                if (item.transactionGroup.Line_Count__c == item.transactionGroup.Lines_Processed__c) {
                    needUpdateStatus.put(item.id, null);
                }
                for (Transaction__c tr : item.transactions) {
                    TransactionKey tk = new TransactionKey(tr);
                    transactionKeys.add(tk.hashCode());
                    transList.add(tr);
                }
            }

            if (IS_HEADER_LEVEL_POST) {
                List<Transaction__c> existedTransactions = getExistedTransactionByKeys(transactionKeys);

                Map<String, Transaction__c> existedTransactionMap = new Map<String, Transaction__c>();
                for (Transaction__c tr : existedTransactions) {
                    existedTransactionMap.put(getTransactionKey(tr, false), tr);
                }

                for (Transaction__c tr : transList) {
                    if (existedTransactionMap.containsKey(getTransactionKey(tr, false))) {
                        consolidateTransaction(existedTransactionMap.get(getTransactionKey(tr, false)), tr);
                    }
                }

                TransactionActions.deleteTransactions(existedTransactions);
            }

            List<AP_Disbursement__c> sourceRecordsInProgress = new List<AP_Disbursement__c>();

            for (AP_Disbursement__c apd : (List<AP_Disbursement__c>) sourceRecords) {
                if (needUpdateStatus.containsKey(apd.Id)) {
                    apd.Status__c = DEFAULT_POSTING_STATUS_POSTED;
                    needUpdateStatus.put(apd.Id, apd);
                }
                else if (apd.Status__c == AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED) {
                    apd.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTING_IN_PROGRESS;
                    sourceRecordsInProgress.add(apd);
                }
            }
            sourceRecordsInProgress.addAll(needUpdateStatus.values());

            TriggerObserver.getInstance().unlockField(AP_Disbursement__c.Status__c);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(sourceRecordsInProgress, new List<String>{'Status__c'});
            TriggerObserver.purgeUnlockedFields(AP_Disbursement__c.Status__c);

            sourceRecords = DomainUtils.getApDisbursementsByIdForUpdate(needUpdateStatus.keySet());
            validatePostStatusSet();

            TransactionActions.createTransactions(transList);
        }
        catch (Exception ex) {
            Database.rollback(sp);
            throw ex;
        }
    }

    public override List<PostResult> post(List<SObject> processedRecords) {
        Map<Id, AP_Disbursement__c> apDisbursementsMap = new Map<Id, AP_Disbursement__c>((List<AP_Disbursement__c>) processedRecords);
        return post(new List<Id>(apDisbursementsMap.keySet()));
    }

    public override List<PostResult> post(List<String> processedRecordsIds) {
        this.processedRecordIds = processedRecordsIds;
        if (!this.processedRecordIds.isEmpty()) {
            main = getAccountingSettings();
            //Initial query for AP Disbursements
            queryAPDisbursements();//AP Disbursements will be stored in the 'sourceRecords' property
            List<SObject> sourceWithCash = filterRecordsByAcctMethod(
                this.sourceRecords,
                new Set<String>{LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH, LedgerActions.ACCOUNTING_METHOD_CASH}
            );
            if (!sourceWithCash.isEmpty()) {
                pdHelper = new ProportionalDistributionHelper(sourceWithCash);
            }
            getGLAccountDefaults();
            if (validateControlGLAccount() && isValidCashBasisLimit(pdHelper)) {
                try {
                    validateNotPosted(false);
                    //to proceed further - Debit GL Account on Cash Disbursement must be not NULL or not set to the AP Control Account
                    validateDebitGLAccount(false);
                    validateAccountingPeriodIsOpen(false);
                    validateInactiveLedger();

                    if (!sourceRecords.isEmpty()) {
                        processAPDisbursementTransactions();
                        processPostResult();
                    }
                }
                catch (System.DmlException dmlEx) {
                    processDmlExceptions(dmlEx);
                }
                catch (Exception ex) {
                    processSystemExceptions(ex);
                }
            }
        }

        return dispatcher.getPostResults();
    }

    //===============================================================================================
    //=================== UNPOST method implementation for AP Disbursements =========================

    public override List<PostResult> unpost(List<LDVPostInput> sourceItems) {
        isLDVBatchContext = true;
        Map<Id, PostResult> postResults = new Map<Id, PostResult>();
        Map<Id, LDVPostInput> sourceMap = new Map<Id, LDVPostInput>();
        List<String> processedRecordsIds = new List<String>();
        for (LDVPostInput item : sourceItems) {
            for (SObject obj : item.relatedObjects) {
                sourceMap.put(obj.Id, item);
            }
            processedRecordsIds.addAll(new List<Id> (new Map<Id, SObject> (item.relatedObjects).keySet()));
        }
        for (PostResult res : unpost(processedRecordsIds)) {
            res.transactionGroup(sourceMap.get(res.id).transactionGroup);
            postResults.put(res.id, res);
        }
        ldvValidatePostResultMap(postResults);
        return postResults.values();
    }

    public override List<PostResult> unpost(List<SObject> processedRecords) {
        Map<Id, AP_Disbursement__c> apDisbursementsMap = new Map<Id, AP_Disbursement__c>((List<AP_Disbursement__c>) processedRecords);
        return unpost(new List<Id>(apDisbursementsMap.keySet()));
    }

    public override List<PostResult> unpost(List<String> processedRecordsIds) {
        this.processedRecordIds = processedRecordsIds;

        if (!this.processedRecordIds.isEmpty()) {
            try {
                validateIsPostedByApproval(false);
                //Initial query for AP Disbursements
                queryAPDisbursements();//AP Disbursements will be stored in the 'sourceRecords' property
                validateAccountingPeriodIsOpen(false);

                if (!sourceRecords.isEmpty()) {
                    processUnpost();
                    processPostResult();
                }
            }
            catch (System.DmlException dmlEx) {
                processDmlExceptions(dmlEx);
            }
            catch (Exception ex) {
                processSystemExceptions(ex);
            }
        }

        return dispatcher.getPostResults();
    }

    //=============================================================================================
    //========================== Validation methods ===============================================
    private Boolean isValidCashBasisLimit(ProportionalDistributionHelper calculation) {
        Boolean isValid = true;
        if (calculation != null && calculation.totalLinesCount() > LINE_COUNT_LIMIT) {
            for (AP_Disbursement__c apd : (List<AP_Disbursement__c>) sourceRecords) {
                dispatcher.addPostErrorResult(
                    apd.Id,
                    new PostResult.PostErrorResult(
                        PostResult.StatusCode.LINE_COUNT_LIMIT_EXCEEDED,
                        String.format(
                            LINE_COUNT_LIMIT_EXCEEDED_ERROR_MESSAGE,
                            new List<String>{String.valueOf(LINE_COUNT_LIMIT)}
                        )
                    )
                );
                isValid = false;
            }
        }
        return isValid;
    }

    private Boolean validateControlGLAccount() {
        Boolean isValid = true;
        for (SObject apd : sourceRecords) {
            if (!glAccountDefaults.containsKey(((AP_Disbursement__c) apd).Cash_Disbursement__r.Ledger__c) ||
                (glAccountDefaults.containsKey(((AP_Disbursement__c) apd).Cash_Disbursement__r.Ledger__c)
                    && !glAccountDefaults.get(((AP_Disbursement__c) apd).Cash_Disbursement__r.Ledger__c).containsKey(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT))) {
                dispatcher.addPostErrorResult(
                    apd.Id,
                    new PostResult.PostErrorResult(
                        PostResult.StatusCode.NO_CONTROL_AP_ACCOUNT_DEFINED,
                        NO_CONTROL_ACCOUNT_MESSAGE
                    )
                );
                isValid = false;
            }
        }
        return isValid;
    }

    private List<SObject> filterRecordsByAcctMethod(List<SObject> sourceRecords, Set<String> acctMethods) {
        List<SObject> validRecords = new List<SObject>();
        for (AP_Disbursement__c sourceRecord : (List<AP_Disbursement__c>) sourceRecords) {
            if (sourceRecord.Account_Payable__r.Ledger__c != null
                && acctMethods.contains(sourceRecord.Account_Payable__r.Ledger__r.Accounting_Method__c)) {
                validRecords.add(sourceRecord);
            } else if (!dispatcher.getPostResultsMap().containsKey(sourceRecord.Id)) {
                dispatcher.addPostResult(sourceRecord.Id, new PostResult(true, sourceRecord.Id, null));
            }
        }
        return validRecords;
    }

    @TestVisible
    private void validateDebitGLAccount(Boolean fullStatistics) {
        List<AP_Disbursement__c> validApDisbursements = new List<AP_Disbursement__c>();
        for (AP_Disbursement__c apDisbursement : (List<AP_Disbursement__c>) sourceRecords) {
            if (apDisbursement.Cash_Disbursement__r.Debit_GL_Account__c == null
                    || apDisbursement.Cash_Disbursement__r.Debit_GL_Account__c ==
                glAccountDefaults.get(apDisbursement.Cash_Disbursement__r.Ledger__c).get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT).GL_Account__c) {

                dispatcher.addPostErrorResult(
                    apDisbursement.Id,
                    new PostResult.PostErrorResult(
                        PostResult.StatusCode.DEBIT_GL_ACCOUNT_IS_NULL_OR_SET_TO_AP_CONTROL_ACCOUNT,
                        DEBIT_GL_ACCOUNT_VALIDATION_ON_POST_ERROR_MESSAGE
                    )
                );
            }
            else {
                validApDisbursements.add(apDisbursement);
            }
        }

        if (!fullStatistics) {
            sourceRecords = validApDisbursements;
        }
    }

    //=============================================================================================
    //========================== Retrieve data from DB ============================================
    private void queryAPDisbursements() {
        //Select fields
        List<String> fieldsToQuery = new List<String> {
            'Id',
            'Name',
            'Status__c',
            'Paid_Amount__c',
            'Accounting_Period__c',
            'Applied_Date__c',
            'Discount_Amount__c',
            'Accounting_Period__r.Start_Date__c',
            'Accounting_Period__r.Status__c',
            'Cash_Disbursement__r.Vendor__c',
            'Cash_Disbursement__r.Contact__c',
            'Cash_Disbursement__r.Employee__c',
            'Cash_Disbursement__r.Ledger__c',
            'Cash_Disbursement__r.Project__c',
            'Cash_Disbursement__r.Project_Task__c',
            'Cash_Disbursement__r.GL_Account_Variable_1__c',
            'Cash_Disbursement__r.GL_Account_Variable_2__c',
            'Cash_Disbursement__r.GL_Account_Variable_3__c',
            'Cash_Disbursement__r.GL_Account_Variable_4__c',
            'Cash_Disbursement__r.Debit_GL_Account__c',
            'Cash_Disbursement__r.Currency_Conversion_Rate__c',
            'Account_Payable__r.Accounting_Period__c',
            'Account_Payable__r.Accounting_Period__r.Start_Date__c',
            'Account_Payable__r.Ledger__r.Accounting_Method__c',
            'Account_Payable__r.Credit_Memo_Applied_Amount__c',
            'Account_Payable__r.Currency_Conversion_Rate__c',
            'Account_Payable__r.Total__c',
            'Account_Payable__r.Ledger__c',
            'Account_Payable__c'
        };
        //Add Multi currency fields
        if (IS_MULTI_CURRENCY_ENABLED) {
            fieldsToQuery.add('CurrencyIsoCode');
            fieldsToQuery.add('Account_Payable__r.CurrencyIsoCode');
            fieldsToQuery.add('Cash_Disbursement__r.CurrencyIsoCode');
        }

        //Add query condition
        String queryCondition = 'Id IN :processedRecordIds FOR UPDATE';
        //Final assembly of SOQL string
        String dynamicSOQL = SOQLBuilder.buildDynamicSoqlQuery(
            fieldsToQuery,
            null,
            AP_Disbursement__c.SObjectType,
            queryCondition,
            true,
            false
        );
        //Call DML operation
        sourceRecords = Database.query(dynamicSOQL);
    }

    //=============================================================================================
    //========================== POST processing ==================================================
    private void processAPDisbursementTransactions() {
        Savepoint sp = Database.setSavepoint();

        try {
            // delete any and all transactions associated with the source document
            // before another set of transactions are created and the status is changed
            if (!isLDVBatchContext) {
                TransactionActions.deleteTransactions(TransactionActions.queryTransactions(sourceRecords));
            }
            //=========================================================================================

            List<Transaction__c> transList = createTransactions();
            if (!isLDVBatchContext) {
                for (AP_Disbursement__c apDisbursement : (List<AP_Disbursement__c>) sourceRecords) {
                    apDisbursement.Status__c = DEFAULT_POSTING_STATUS_POSTED;
                }

                //convert generic collection to the collection with specific SObjectType
                List<AP_Disbursement__c> sourceRecordsToUpdate = new List<AP_Disbursement__c>((List<AP_Disbursement__c>) sourceRecords);

                TriggerObserver.getInstance().unlockField(AP_Disbursement__c.Status__c);
                SFDCSecurityUtils.updateCheckCRUDAndFLS(sourceRecordsToUpdate, new List<String>{'Status__c'});
                TriggerObserver.purgeUnlockedFields(AP_Disbursement__c.Status__c);

                sourceRecords = DomainUtils.getApDisbursementsByIdForUpdate(new Map<Id, SObject>(sourceRecords).keySet());
                validatePostStatusSet();

                TransactionActions.createTransactions(transList);
            }
        }
        catch (Exception ex) {
            Database.rollback(sp);
            throw ex;
        }
    }

    private List<Transaction__c> createTransactions() {
        //If MC is enabled ==================
        getCurrencyInformation();
        //===================================
        List<Transaction__c> transList = new List<Transaction__c>();
        for (AP_Disbursement__c apDisbursement : (List<AP_Disbursement__c>) sourceRecords) {
            List<Transaction__c> tempTransList = new List<Transaction__c>();
            if (isAllowToCreate(apDisbursement) && apDisbursement.Account_Payable__r.Ledger__r.Accounting_Method__c != null
                && (LedgerHandler.getInstanceWithoutSharing().isAccrualAndCashLedger(apDisbursement.Account_Payable__r.Ledger__c)
                || LedgerHandler.getInstanceWithoutSharing().isAccrualLedger(apDisbursement.Account_Payable__r.Ledger__c))) {
                //======================================================================================
                //Create Debit and Credit Transaction Lines ============================================
                //======================================================================================

                //========================= DEBIT LINE =================================================
                Transaction__c debitTransaction = createTransaction(apDisbursement);
                processTransactionAmount(
                    apDisbursement,
                    debitTransaction,
                    apDisbursement.Paid_Amount__c + apDisbursement.Discount_Amount__c,
                    apDisbursement.Account_Payable__r.Currency_Conversion_Rate__c
                );

                debitTransaction.GL_Account__c =
                    glAccountDefaults.get(apDisbursement.Cash_Disbursement__r.Ledger__c).get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT).GL_Account__c;
                tempTransList.add(debitTransaction);

                //======================== CREDIT LINE =================================================
                Transaction__c creditTransaction = createTransaction(apDisbursement);
                Decimal amountResult = (apDisbursement.Paid_Amount__c + apDisbursement.Discount_Amount__c) * -1;
                processTransactionAmount(apDisbursement, creditTransaction, amountResult, apDisbursement.Cash_Disbursement__r.Currency_Conversion_Rate__c);

                creditTransaction.GL_Account__c = apDisbursement.Cash_Disbursement__r.Debit_GL_Account__c;
                tempTransList.add(creditTransaction);

                //=========================== FOREIGN EXCHANGE GAIN/LOSS TRANSACTION LINE ===============
                if (isMultiCurrencyAndDifferentCurrency(apDisbursement.Id, creditTransaction.Ledger__c)) {
                    Transaction__c foreignExchangeTransaction = createTransaction(apDisbursement);

                    Decimal creditLineAmount = amountResult / apDisbursement.Cash_Disbursement__r.Currency_Conversion_Rate__c;/*negative line*/
                    Decimal debitLineAmount = (apDisbursement.Paid_Amount__c + apDisbursement.Discount_Amount__c) / apDisbursement.Account_Payable__r.Currency_Conversion_Rate__c;/*positive line*/

                    foreignExchangeTransaction.Amount__c = (creditLineAmount.setScale(2, System.RoundingMode.HALF_UP) + debitLineAmount.setScale(2, System.RoundingMode.HALF_UP)) * -1;

                    foreignExchangeTransaction.GL_Account__c =
                        glAccountDefaults.get(apDisbursement.Cash_Disbursement__r.Ledger__c).get(GLAccountDefaultsHandler.CURRENCY_GAIN_LOSS_GL_ACCOUNT).GL_Account__c;
                    tempTransList.add(foreignExchangeTransaction);
                }
            }

            if (apDisbursement.Account_Payable__r.Ledger__r.Accounting_Method__c != null
                && (LedgerHandler.getInstanceWithoutSharing().isAccrualAndCashLedger(apDisbursement.Account_Payable__r.Ledger__c)
                || LedgerHandler.getInstanceWithoutSharing().isCashLedger(apDisbursement.Account_Payable__r.Ledger__c))) {

                tempTransList.addAll(getCashLedgerTransaction(apDisbursement));
            }

            if (isLDVBatchContext) {
                resultTransList.put(apDisbursement.Id, new List<Transaction__c> (tempTransList));
            }
            transList.addAll(tempTransList);
        }

        return transList;
    }

    private void processTransactionAmount(AP_Disbursement__c apDisbursement, Transaction__c trans, Decimal amount, Decimal ccr) {
        if (isMultiCurrencyAndDifferentCurrency(apDisbursement.Id, trans.Ledger__c)) {
            trans.Foreign_Amount__c = amount;
            trans.Foreign_Currency__c = (String) apDisbursement.getSObject(PACKAGE_QUALIFIER + 'Cash_Disbursement__r').get('CurrencyIsoCode');
            trans.Currency_Conversion_Rate__c = ccr;
            trans.Amount__c = (amount / ccr).setScale(2, System.RoundingMode.HALF_UP);
        }
        else {
            trans.Amount__c = amount;
        }
    }

    private void processCashTransactionAmount(AP_Disbursement__c apDisbursement, Transaction__c trans) {
        Decimal amount = trans.Amount__c;
        if (isMultiCurrencyAndDifferentCurrency(apDisbursement.Id, trans.Ledger__c)) {
            trans.Foreign_Amount__c = amount;
            trans.Foreign_Currency__c = (String) apDisbursement.getSObject(PACKAGE_QUALIFIER + 'Cash_Disbursement__r').get('CurrencyIsoCode');
            trans.Currency_Conversion_Rate__c = apDisbursement.Cash_Disbursement__r.Currency_Conversion_Rate__c;
            trans.Amount__c = (amount / apDisbursement.Cash_Disbursement__r.Currency_Conversion_Rate__c).setScale(2, System.RoundingMode.HALF_UP);
        }
    }

    private List<Transaction__c> getCashLedgerTransaction(AP_Disbursement__c apDisbursement) {
        List<Transaction__c> shadowTrans = new List<Transaction__c>();
        resetRoundingAdjustment();
        if (pdHelper.getTransactionAmountCalculationById(apDisbursement.Account_Payable__c) != null) {
            ProportionalDistributionHelper.TransactionAmountCalculation calculation =
                pdHelper.getTransactionAmountCalculationById(apDisbursement.Account_Payable__c);
            if (IS_HEADER_LEVEL_POST) {
                shadowTrans.addAll(getHLPTransactions(apDisbursement, calculation));
            } else {
                shadowTrans.addAll(getLLPTransactions(apDisbursement, calculation));
            }

        }
        return shadowTrans;
    }

    private void resetRoundingAdjustment() {
        roundingAdjustment = new Map<String, Transaction__c>();
        roundingBalance = 0;
        foreignRoundingBalance = 0;
    }

    private void adjustRounding() {
        if (Math.abs(roundingAdjustment.get('credit').Amount__c) != Math.abs(roundingBalance)) {
            roundingAdjustment.get('debit').Amount__c += roundingAdjustment.get('debit').Amount__c < 0 ?
                ((Math.abs(roundingAdjustment.get('credit').Amount__c) - Math.abs(roundingBalance)) * -1) :
                (Math.abs(roundingAdjustment.get('credit').Amount__c) - Math.abs(roundingBalance));
        }
        if (roundingAdjustment.get('credit').Foreign_Amount__c != null
            && Math.abs(roundingAdjustment.get('credit').Foreign_Amount__c) != Math.abs(foreignRoundingBalance)) {
            roundingAdjustment.get('debit').Foreign_Amount__c += roundingAdjustment.get('debit').Foreign_Amount__c < 0 ?
                ((Math.abs(roundingAdjustment.get('credit').Foreign_Amount__c) - Math.abs(foreignRoundingBalance)) * -1) :
                (Math.abs(roundingAdjustment.get('credit').Foreign_Amount__c) - Math.abs(foreignRoundingBalance));
        }
    }

    private void addRoundingBalance(Transaction__c trans) {
        roundingBalance += trans.Amount__c;
        if (trans.Foreign_Amount__c != null) {
            foreignRoundingBalance += trans.Foreign_Amount__c;
        }
    }

    private void validateTransForRounding(List<Transaction__c> trans) {
        for (Transaction__c tr : trans) {
            if ((roundingAdjustment.containsKey('debit')
                && Math.abs(roundingAdjustment.get('debit').Amount__c) < Math.abs(tr.Amount__c))
                || !roundingAdjustment.containsKey('debit')) {
                roundingAdjustment.put('debit', tr);
            }
            addRoundingBalance(tr);
        }
    }

    private List<Transaction__c> getHLPTransactions(AP_Disbursement__c apDisbursement, ProportionalDistributionHelper.TransactionAmountCalculation calculation) {
        List<Transaction__c> result = new List<Transaction__c>();
        if (isAllowToCreate(apDisbursement)) {
            Transaction__c trans = createTransaction(apDisbursement);
            trans.Account_Payable__c = apDisbursement.Account_Payable__c;
            trans.Ledger__c = getCashLedgerId(apDisbursement);
            trans.Amount__c = ((apDisbursement.Paid_Amount__c + apDisbursement.Discount_Amount__c) * -1).setScale(2, System.RoundingMode.HALF_UP);
            trans.GL_Account__c = getCashDebitGLAccount(apDisbursement);
            result.add(trans);
            roundingAdjustment.put('credit', trans);
        }
        Map<String, Transaction__c> glAccountIdToCreditTransaction = new Map<String, Transaction__c>();
        for (ProportionalDistributionHelper.TransactionAmountCalculationLine line : calculation.lines) {
            if (!line.isFuturePeriod && !(line.isCreditMemo && !isAllowToCreate(apDisbursement))) {
                Transaction__c cashTrans = createCashTransaction(line);
                cashTrans.AP_Disbursement__c = apDisbursement.Id;
                cashTrans.Account_Payable__c = apDisbursement.Account_Payable__c;
                cashTrans.Accounting_Period__c = apDisbursement.Accounting_Period__c;
                Date transDate = apDisbursement.Applied_Date__c != null ? apDisbursement.Applied_Date__c : apDisbursement.Accounting_Period__r.Start_Date__c;
                cashTrans.Date__c = transDate;
                cashTrans.Account__c = apDisbursement.Cash_Disbursement__r.Vendor__c;
                cashTrans.Contact__c = apDisbursement.Cash_Disbursement__r.Contact__c;
                cashTrans.Employee__c = apDisbursement.Cash_Disbursement__r.Employee__c;
                cashTrans.Ledger__c = getCashLedgerId(apDisbursement);
                cashTrans.Amount__c = line.subTotal.setScale(2, System.RoundingMode.HALF_UP);

                if (glAccountIdToCreditTransaction.containsKey(getTransactionKey(cashTrans, false))) {
                    Transaction__c exTrans = glAccountIdToCreditTransaction.get(getTransactionKey(cashTrans, false));
                    exTrans.Amount__c += cashTrans.Amount__c;
                } else {
                    glAccountIdToCreditTransaction.put(getTransactionKey(cashTrans, false), cashTrans);
                }

                if (line.taxAmount != null && line.taxAmount != 0 && String.isNotBlank(line.taxGroupId)) {
                    processTaxTransaction(line, glAccountIdToCreditTransaction, apDisbursement);
                }
            }
        }

        if (!calculation.existedPay.isEmpty()) {
            List<String> existedKeys = new List<String>();
            for (AP_Disbursement__c apd : (List<AP_Disbursement__c>) calculation.existedPay) {
                for (Transaction__c tr : apd.Transactions__r) {
                    if (tr.AP_Disbursement__c == apDisbursement.Id) {
                        existedKeys.add(getTransactionKey(tr, false));
                        existedKeys.add(getTransactionKey(tr, true));
                    }
                }
            }
            for (AP_Disbursement__c apd : (List<AP_Disbursement__c>) calculation.existedPay) {
                for (Transaction__c tr : apd.Transactions__r) {
                    String key = getTransactionKey(tr, false).replace(String.valueOf(tr.AP_Disbursement__c), String.valueOf(apDisbursement.Id));
                    String taxKey = getTransactionKey(tr, true).replace(String.valueOf(tr.AP_Disbursement__c), String.valueOf(apDisbursement.Id));
                    if (isLDVBatchContext && tr.AP_Disbursement__c != apDisbursement.Id) {
                        if (!existedKeys.contains(key) && glAccountIdToCreditTransaction.keySet().contains(key)) {
                            reduceTransactionAmount(glAccountIdToCreditTransaction.get(key), tr, apDisbursement);
                        } else if (!existedKeys.contains(taxKey) && glAccountIdToCreditTransaction.keySet().contains(taxKey)) {
                            reduceTransactionAmount(glAccountIdToCreditTransaction.get(taxKey), tr, apDisbursement);
                        }
                    } else if (!isLDVBatchContext && tr.AP_Disbursement__c != apDisbursement.Id) {
                        if (glAccountIdToCreditTransaction.keySet().contains(key)) {
                            reduceTransactionAmount(glAccountIdToCreditTransaction.get(key), tr, apDisbursement);
                        } else if (glAccountIdToCreditTransaction.keySet().contains(taxKey)) {
                            reduceTransactionAmount(glAccountIdToCreditTransaction.get(taxKey), tr, apDisbursement);
                        }
                    }
                }
            }
        }

        for (Transaction__c tr : result) {
            processCashTransactionAmount(apDisbursement, tr);
        }

        for (Transaction__c tr : glAccountIdToCreditTransaction.values()) {
            processCashTransactionAmount(apDisbursement, tr);
        }

        if (!isLDVBatchContext) {
            validateTransForRounding(glAccountIdToCreditTransaction.values());
            adjustRounding();
        }

        result.addAll(glAccountIdToCreditTransaction.values());
        return result;
    }

    private List<Transaction__c> getLLPTransactions(AP_Disbursement__c apDisbursement, ProportionalDistributionHelper.TransactionAmountCalculation calculation) {
        Map<String, String> transPair = new Map<String, String>();
        Map<String, Transaction__c> glAccountIdToCreditTransaction = new Map<String, Transaction__c>();
        List<String> debitBalanceTransactions = new List<String>();
        for (ProportionalDistributionHelper.TransactionAmountCalculationLine line : calculation.lines) {
            if (!line.isFuturePeriod && !(line.isCreditMemo && !isAllowToCreate(apDisbursement))) {
                Transaction__c cashTransDebit = createCashTransaction(line);
                cashTransDebit.AP_Disbursement__c = apDisbursement.Id;
                cashTransDebit.Account_Payable_Line__c = line.recordId;
                cashTransDebit.Accounting_Period__c = apDisbursement.Accounting_Period__c;
                Date transDate = apDisbursement.Applied_Date__c != null ? apDisbursement.Applied_Date__c : apDisbursement.Accounting_Period__r.Start_Date__c;
                cashTransDebit.Date__c = transDate;
                cashTransDebit.Account__c = apDisbursement.Cash_Disbursement__r.Vendor__c;
                cashTransDebit.Contact__c = apDisbursement.Cash_Disbursement__r.Contact__c;
                cashTransDebit.Employee__c = apDisbursement.Cash_Disbursement__r.Employee__c;
                cashTransDebit.Ledger__c = getCashLedgerId(apDisbursement);
                cashTransDebit.GL_Account__c = getCashDebitGLAccount(apDisbursement);
                cashTransDebit.Amount__c = (line.subTotal * -1).setScale(2, System.RoundingMode.HALF_UP);
                glAccountIdToCreditTransaction.put(getTransactionKey(cashTransDebit, false) + line.recordId + llpNegativeKey(cashTransDebit), cashTransDebit);
                debitBalanceTransactions.add(getTransactionKey(cashTransDebit, false) + line.recordId + llpNegativeKey(cashTransDebit));

                Transaction__c cashTrans = createCashTransaction(line);
                cashTrans.AP_Disbursement__c = apDisbursement.Id;
                cashTrans.Account_Payable_Line__c = line.recordId;
                cashTrans.Accounting_Period__c = apDisbursement.Accounting_Period__c;
                cashTrans.Date__c = transDate;
                cashTrans.Account__c = apDisbursement.Cash_Disbursement__r.Vendor__c;
                cashTrans.Contact__c = apDisbursement.Cash_Disbursement__r.Contact__c;
                cashTrans.Employee__c = apDisbursement.Cash_Disbursement__r.Employee__c;
                cashTrans.Ledger__c = getCashLedgerId(apDisbursement);
                cashTrans.Amount__c = line.subTotal.setScale(2, System.RoundingMode.HALF_UP);
                glAccountIdToCreditTransaction.put(getTransactionKey(cashTrans, false) + line.recordId + llpNegativeKey(cashTrans), cashTrans);
                transPair.put(
                    getTransactionKey(cashTrans, false) + line.recordId + llpNegativeKey(cashTrans),
                    getTransactionKey(cashTransDebit, false) + line.recordId + llpNegativeKey(cashTransDebit)
                );
                transPair.put(
                    getTransactionKey(cashTransDebit, false) + line.recordId + llpNegativeKey(cashTransDebit),
                    getTransactionKey(cashTrans, false) + line.recordId + llpNegativeKey(cashTrans)
                );
            }
        }

        if (!calculation.existedPay.isEmpty()) {
            for (AP_Disbursement__c apd : (List<AP_Disbursement__c>) calculation.existedPay) {
                for (Transaction__c tr : apd.Transactions__r) {
                    String key = getTransactionKey(tr, false).replace(String.valueOf(tr.AP_Disbursement__c), String.valueOf(apDisbursement.Id));
                    if (tr.AP_Disbursement__c != apDisbursement.Id
                        && glAccountIdToCreditTransaction.keySet().contains(key + String.valueOf(tr.Account_Payable_Line__c) + llpNegativeKey(tr))) {
                        reduceTransactionAmount(
                            glAccountIdToCreditTransaction.get(key + String.valueOf(tr.Account_Payable_Line__c) + llpNegativeKey(tr)), tr, apDisbursement
                        );
                    }
                }
            }
        }
        Decimal debitBalance = 0;
        Decimal debitForeignBalance = 0;
        for (Transaction__c tr : glAccountIdToCreditTransaction.values()) {
            processCashTransactionAmount(apDisbursement, tr);
            if (debitBalanceTransactions.contains(getTransactionKey(tr, false) + tr.Account_Payable_Line__c + llpNegativeKey(tr))) {
                debitBalance += tr.Amount__c;
                if (isMultiCurrencyAndDifferentCurrency(apDisbursement.Id, tr.Ledger__c) && tr.Foreign_Amount__c != null) {
                    debitForeignBalance += tr.Foreign_Amount__c;
                }
            }
        }

        if (!isLDVBatchContext) {
            validateTransForRounding(glAccountIdToCreditTransaction.values());
            if (debitForeignBalance != 0
                && (getAbsAPDBalance(apDisbursement) != Math.abs(debitForeignBalance)
                || Math.abs(getAppliedAmountInLedgerCurrency(apDisbursement)) != Math.abs(debitBalance))) {
                Transaction__c oppositeForeign = getOppositeTransaction(glAccountIdToCreditTransaction, transPair);

                Decimal absForeignValue = getAbsAPDBalance(apDisbursement) - Math.abs(debitForeignBalance);
                roundingAdjustment.get('debit').Foreign_Amount__c += roundingAdjustment.get('debit').Foreign_Amount__c > 0 ?
                absForeignValue : absForeignValue * -1;
                oppositeForeign.Foreign_Amount__c += oppositeForeign.Foreign_Amount__c > 0 ? absForeignValue : absForeignValue * -1;

                Decimal absValue = Math.abs(getAppliedAmountInLedgerCurrency(apDisbursement)) - Math.abs(debitBalance);
                roundingAdjustment.get('debit').Amount__c += roundingAdjustment.get('debit').Amount__c > 0 ?
                    absValue : absValue * -1;
                oppositeForeign.Amount__c += oppositeForeign.Amount__c > 0 ? absValue : absValue * -1;
            } else if (debitForeignBalance == 0 && getAbsAPDBalance(apDisbursement) != Math.abs(debitBalance)) {
                Transaction__c opposite = getOppositeTransaction(glAccountIdToCreditTransaction, transPair);

                Decimal absValue = getAbsAPDBalance(apDisbursement) - Math.abs(debitBalance);
                roundingAdjustment.get('debit').Amount__c += roundingAdjustment.get('debit').Amount__c > 0 ?
                    absValue : absValue * -1;
                opposite.Amount__c += opposite.Amount__c > 0 ? absValue : absValue * -1;
            }
        }

        return glAccountIdToCreditTransaction.values();
    }

    private String llpNegativeKey(Transaction__c tr) {
        return tr.Amount__c < 0 ? '-' : '';
    }

    private Decimal getAbsAPDBalance(AP_Disbursement__c apDisbursement) {
        return Math.abs(apDisbursement.Paid_Amount__c + apDisbursement.Discount_Amount__c);
    }

    private Transaction__c getOppositeTransaction(Map<String, Transaction__c> glAccountIdToCreditTransaction, Map<String, String> transPair) {
        return glAccountIdToCreditTransaction.get(transPair.get(
            getTransactionKey(roundingAdjustment.get('debit'), false)
                + roundingAdjustment.get('debit').Account_Payable_Line__c
                + llpNegativeKey(roundingAdjustment.get('debit'))
            )
        );
    }

    public Decimal getAppliedAmountInLedgerCurrency(AP_Disbursement__c apDisbursement) {
        return ((apDisbursement.Paid_Amount__c + apDisbursement.Discount_Amount__c)
            / apDisbursement.Cash_Disbursement__r.Currency_Conversion_Rate__c).setScale(2, System.RoundingMode.HALF_UP);
    }

    private Id getCashLedgerId(AP_Disbursement__c apDisbursement) {
        return LedgerHandler.getInstanceWithoutSharing().isCashLedger(apDisbursement.Account_Payable__r.Ledger__c)
            ? apDisbursement.Account_Payable__r.Ledger__c
            : LedgerHandler.getInstanceWithoutSharing().getShadowLedgerByParent(apDisbursement.Account_Payable__r.Ledger__c).Id;
    }

    public Id getCashDebitGLAccount(AP_Disbursement__c apDisbursement) {
        Id debitGLAccount = apDisbursement.Cash_Disbursement__r.Debit_GL_Account__c;
        if (!LedgerHandler.getInstanceWithoutSharing().isCashLedger(apDisbursement.Account_Payable__r.Ledger__c) || debitGLAccount == null) {
            GL_Account_Default__c glAccDefRecord = glAccountDefaults.get(getCashLedgerId(apDisbursement)).get(GLAccountDefaultsHandler.UNAPPLIED_EXPENSE_GL_ACCOUNT);
            if (glAccDefRecord != null) {
                debitGLAccount = glAccDefRecord.GL_Account__c;
            }
            else {
                throw new PostHandlerException(Label.ERR_CD_NO_UNAPPLIED_EXPENSE_GL_ACCOUNT);
            }
        }
        return debitGLAccount;
    }

    private Boolean isAllowToCreate(AP_Disbursement__c apd) {
        return !isLDVBatchContext || (isLDVBatchContext && ldvFirstRun.contains(apd.Id));
    }

    private void reduceTransactionAmount(Transaction__c newTr, Transaction__c existedTr, AP_Disbursement__c apDisbursement) {
        newTr.Amount__c -= isMultiCurrencyAndDifferentCurrency(apDisbursement.Id, existedTr.Ledger__c) ? existedTr.Foreign_Amount__c : existedTr.Amount__c;
    }

    private void processTaxTransaction(ProportionalDistributionHelper.TransactionAmountCalculationLine line,
        Map<String, Transaction__c> taxTransMap,
        AP_Disbursement__c apDisbursement) {

        Map<Id, Decimal> rateAdjustment = AbstractTaxService.getTaxRateAdjustmentByAmount(
            (line.total).setScale(2, RoundingMode.HALF_UP), line.rates
        );

        for (Tax_Rate__c rate : line.rates) {
            Transaction__c creditTaxTR = createCashTransaction(line);
            creditTaxTR.AP_Disbursement__c = apDisbursement.Id;
            creditTaxTR.Account_Payable__c = apDisbursement.Account_Payable__c;
            creditTaxTR.Accounting_Period__c = apDisbursement.Accounting_Period__c;
            Date transDate = apDisbursement.Applied_Date__c != null ? apDisbursement.Applied_Date__c : apDisbursement.Accounting_Period__r.Start_Date__c;
            creditTaxTR.Date__c = transDate;
            creditTaxTR.Account__c = apDisbursement.Cash_Disbursement__r.Vendor__c;
            creditTaxTR.Contact__c = apDisbursement.Cash_Disbursement__r.Contact__c;
            creditTaxTR.Employee__c = apDisbursement.Cash_Disbursement__r.Employee__c;
            creditTaxTR.Ledger__c = getCashLedgerId(apDisbursement);
            creditTaxTR.GL_Account__c = rate.Purchase_Tax_Expense_GL_Account__c;
            creditTaxTR.Time_Card_Variable_1__c = null;
            creditTaxTR.Time_Card_Variable_2__c = null;
            creditTaxTR.GL_Account_Variable_1__c = line.glav1Id;
            creditTaxTR.GL_Account_Variable_2__c = line.glav2Id;
            creditTaxTR.GL_Account_Variable_3__c = line.glav3Id;
            creditTaxTR.GL_Account_Variable_4__c = line.glav4Id;
            creditTaxTR.Product__c = null;
            creditTaxTR.Project__c = null;
            creditTaxTR.Project_Task__c = null;
            creditTaxTR.Amount__c = (rate.Tax_Rate__c / line.taxRate * line.taxAmount).setScale(2, System.RoundingMode.HALF_UP);

           if (rateAdjustment.containsKey(rate.Id)
               && service.getTaxRoundingThreshold(apDisbursement.Account_Payable__r) >= rateAdjustment.get(rate.Id).abs()) {

                creditTaxTR.Amount__c += rateAdjustment.get(rate.Id) * -1;
            }

            populateTransactionMap(creditTaxTR, taxTransMap, true);
        }
    }

    private Transaction__c createTransaction(AP_Disbursement__c apDisbursement) {
        Transaction__c trans = new Transaction__c();
        trans.AP_Disbursement__c = apDisbursement.Id;
        trans.Account__c = apDisbursement.Cash_Disbursement__r.Vendor__c;
        trans.Contact__c = apDisbursement.Cash_Disbursement__r.Contact__c;
        trans.Employee__c = apDisbursement.Cash_Disbursement__r.Employee__c;
        trans.Ledger__c = apDisbursement.Cash_Disbursement__r.Ledger__c != null ? apDisbursement.Cash_Disbursement__r.Ledger__c : LedgerHandler.getLegacyDefaultLedgerId();
        trans.Accounting_Period__c = apDisbursement.Accounting_Period__c;
        Date transDate = apDisbursement.Applied_Date__c != null ? apDisbursement.Applied_Date__c : apDisbursement.Accounting_Period__r.Start_Date__c;
        trans.Date__c = transDate;
        trans.Project__c = apDisbursement.Cash_Disbursement__r.Project__c;
        trans.Project_Task__c = apDisbursement.Cash_Disbursement__r.Project_Task__c;
        trans.GL_Account_Variable_1__c = apDisbursement.Cash_Disbursement__r.GL_Account_Variable_1__c;
        trans.GL_Account_Variable_2__c = apDisbursement.Cash_Disbursement__r.GL_Account_Variable_2__c;
        trans.GL_Account_Variable_3__c = apDisbursement.Cash_Disbursement__r.GL_Account_Variable_3__c;
        trans.GL_Account_Variable_4__c = apDisbursement.Cash_Disbursement__r.GL_Account_Variable_4__c;
        return trans;
    }

    private Transaction__c createCashTransaction(ProportionalDistributionHelper.TransactionAmountCalculationLine line) {
        Transaction__c trans = new Transaction__c();
        trans.GL_Account__c = line.glAccountId;
        trans.Product__c = line.productId;
        trans.Project__c = line.projectId;
        trans.Project_Task__c = line.projectTaskId;
        trans.GL_Account_Variable_1__c = line.glav1Id;
        trans.GL_Account_Variable_2__c = line.glav2Id;
        trans.GL_Account_Variable_3__c = line.glav3Id;
        trans.GL_Account_Variable_4__c = line.glav4Id;
        return trans;
    }

    public override String getTransactionKey(Transaction__c pt, Boolean isTaxTransaction) {
        String result = '';
        result += String.valueOf(pt.AP_Disbursement__c);
        result += String.valueOf(pt.GL_Account_Variable_1__c);
        result += String.valueOf(pt.GL_Account_Variable_2__c);
        result += String.valueOf(pt.GL_Account_Variable_3__c);
        result += String.valueOf(pt.GL_Account_Variable_4__c);
        result += String.valueOf(pt.GL_Account__c);
        if (!isTaxTransaction) {
            result += String.valueOf(pt.Project__c);
            result += String.valueOf(pt.Project_Task__c);
            result += String.valueOf(pt.Product__c);
        }
        return result;
    }

    //=============================================================================================
    //========================== UNPOST processing ================================================
    private void processUnpost() {
        Savepoint sp = Database.setSavepoint();

        try {
            if (isLDVBatchContext) {
                TransactionActions.deleteTransactions(
                    TransactionActions.queryTransactions(sourceRecords, AccountingSettingsHandler.isHeaderLevelPost(), 1000)
                );
            } else {
                TransactionActions.deleteTransactions(TransactionActions.queryTransactions(sourceRecords));
            }
        }
        catch (Exception ex) {
            Database.rollback(sp);
            throw ex;
        }
    }

}