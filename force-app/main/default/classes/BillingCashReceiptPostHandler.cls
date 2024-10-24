public with sharing class BillingCashReceiptPostHandler extends AbstractPostHandler {

    public static final String LINE_COUNT_LIMIT_EXCEEDED_ERROR_MESSAGE = Label.ERR_PAYABLE_LINE_COUNT_LIMIT_EXCEEDED;
    public final static String NO_CONTROL_ACCOUNT_MESSAGE = Label.ERR_NO_CONTROL_ACCOUNT_MESSAGE;
    public final static String REFUND_STATUS_CANNOT_BE_POSTED = Label.ERR_REFUND_STATUS_CANNOT_BE_POSTED ;
    public static final Integer LINE_COUNT_LIMIT = 500;
    public ProportionalDistributionHelper pdHelper;
    private static AbstractTaxService service = AccountingSettingsHandler.isHeaderLevelPost()
        ? (AbstractTaxService) new NativeTaxHeaderLevel() : (AbstractTaxService) new NativeTaxLineLevel();
    private Map<Id, List<Transaction__c>> resultTransList = new Map<Id, List<Transaction__c>>();
    private Set<Id> ldvFirstRun = new Set<Id>();
    private Decimal roundingBalance = 0;
    private Decimal foreignRoundingBalance = 0;
    private Map<String, Transaction__c> roundingAdjustment = new Map<String, Transaction__c>();

    //=============================================================================================
    //=================== POST method implementation for Billing Cash Receipts ====================

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
            //Initial query for Billing Cash Receipts
            queryBillingCashReceipts();//Billing Cash Receipts will be stored in the 'sourceRecords' property
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
                    validateNoRefundBCRs();
                    validateAccountingPeriodIsOpen(false);
                    validateInactiveLedger();
                    if (!sourceRecords.isEmpty()) {
                        for (Billing_Cash_Receipt__c bcr : (List<Billing_Cash_Receipt__c>) sourceRecords) {
                            PostResult res = new PostResult(true, bcr.Id, '', sourceMap.get(bcr.Billing__c).transactionGroup);
                            postResults.put(bcr.Id, res);
                        }
                        processBillingCashReceiptTransactions();
                        processPostResult();
                        for (Billing_Cash_Receipt__c bcr : (List<Billing_Cash_Receipt__c>) sourceRecords) {
                            PostResult res = postResults.get(bcr.Id);
                            res.transactions.addAll(resultTransList.get(bcr.Id));
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
            Map<Id, Billing_Cash_Receipt__c> needUpdateStatus = new Map<Id, Billing_Cash_Receipt__c>();
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

            List<Billing_Cash_Receipt__c> sourceRecordsInProgress = new List<Billing_Cash_Receipt__c>();

            for (Billing_Cash_Receipt__c billingCashReceipt : (List<Billing_Cash_Receipt__c>) sourceRecords) {
                if (needUpdateStatus.containsKey(billingCashReceipt.Id)) {
                    billingCashReceipt.Status__c = DEFAULT_POSTING_STATUS_POSTED;
                    needUpdateStatus.put(billingCashReceipt.Id, billingCashReceipt);
                }
                else if (billingCashReceipt.Status__c == AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED) {
                    billingCashReceipt.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTING_IN_PROGRESS;
                    sourceRecordsInProgress.add(billingCashReceipt);
                }
            }
            sourceRecordsInProgress.addAll(needUpdateStatus.values());

            TriggerObserver.getInstance().unlockField(Billing_Cash_Receipt__c.Status__c);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(sourceRecordsInProgress, new List<String>{'Status__c'});
            TriggerObserver.purgeUnlockedFields(Billing_Cash_Receipt__c.Status__c);

            sourceRecords = DomainUtils.getBillingCashReceiptsByIdForUpdate(needUpdateStatus.keySet());
            validatePostStatusSet();

            TransactionActions.createTransactions(transList);
        }
        catch (Exception ex) {
            Database.rollback(sp);
            throw ex;
        }
    }

    public override List<PostResult> post(List<SObject> processedRecords) {
        Map<Id, Billing_Cash_Receipt__c> bcrMap =
            new Map<Id, Billing_Cash_Receipt__c>((List<Billing_Cash_Receipt__c>) processedRecords);
        return post(new List<Id>(bcrMap.keySet()));
    }

    public override List<PostResult> post(List<String> processedRecordsIds) {
        this.processedRecordIds = processedRecordsIds;

        if (!this.processedRecordIds.isEmpty()) {
            main = getAccountingSettings();
            //Initial query for Billing Cash Receipts
            queryBillingCashReceipts();//Billing Cash Receipts will be stored in the 'sourceRecords' property
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
                    validateNoRefundBCRs();
                    validateAccountingPeriodIsOpen(false);
                    validateInactiveLedger();
                    if (!sourceRecords.isEmpty()) {
                        processBillingCashReceiptTransactions();
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
    //=================== UNPOST method implementation for Billing Cash Receipts ====================

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
        Map<Id, Billing_Cash_Receipt__c> bcrMap =
            new Map<Id, Billing_Cash_Receipt__c>((List<Billing_Cash_Receipt__c>) processedRecords);
        return unpost(new List<Id>(bcrMap.keySet()));
    }

    public override List<PostResult> unpost(List<String> processedRecordsIds) {
        this.processedRecordIds = processedRecordsIds;

        if (!this.processedRecordIds.isEmpty()) {
            try {
                //Initial query for Billing Cash Receipts
                queryBillingCashReceipts();//Billing Cash Receipts will be stored in the 'sourceRecords' property
                if (!sourceRecords.isEmpty()) {
                    processUnpostBillingCashReceipt();
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

    private List<SObject> filterRecordsByAcctMethod(List<SObject> sourceRecords, Set<String> acctMethods) {
        List<SObject> validRecords = new List<SObject>();
        for (Billing_Cash_Receipt__c sourceRecord : (List<Billing_Cash_Receipt__c>) sourceRecords) {
            if (sourceRecord.Billing__r.Ledger__c != null
                && acctMethods.contains(sourceRecord.Billing__r.Ledger__r.Accounting_Method__c)) {
                validRecords.add(sourceRecord);
            } else if (!dispatcher.getPostResultsMap().containsKey(sourceRecord.Id)) {
                dispatcher.addPostResult(sourceRecord.Id, new PostResult(true, sourceRecord.Id, NULL));
            }
        }
        return validRecords;
    }

    //=============================================================================================
    //========================== Retrieve data from DB ============================================
    private void queryBillingCashReceipts() {
        //Select fields
        List<String> fieldsToQuery = new List<String> {
            'Id',
            'Name',
            'Status__c',
            PACKAGE_QUALIFIER + 'Ledger__c',
            PACKAGE_QUALIFIER + 'Applied_Amount__c',
            PACKAGE_QUALIFIER + 'Cash_Receipt__r.' + PACKAGE_QUALIFIER + 'Credit_GL_Account__c',
            PACKAGE_QUALIFIER + 'Accounting_Period__c',
            PACKAGE_QUALIFIER + 'Applied_Date__c',
            PACKAGE_QUALIFIER + 'Accounting_Period__r.' + PACKAGE_QUALIFIER + 'Start_Date__c',
            PACKAGE_QUALIFIER + 'Accounting_Period__r.' + PACKAGE_QUALIFIER + 'Status__c',
            PACKAGE_QUALIFIER + 'Cash_Receipt__r.' + PACKAGE_QUALIFIER + 'Product__c',
            PACKAGE_QUALIFIER + 'Cash_Receipt__r.' + PACKAGE_QUALIFIER + 'Project__c',
            PACKAGE_QUALIFIER + 'Cash_Receipt__r.' + PACKAGE_QUALIFIER + 'Project_Task__c',
            PACKAGE_QUALIFIER + 'Cash_Receipt__r.' + PACKAGE_QUALIFIER + 'Receipt_Date__c',
            PACKAGE_QUALIFIER + 'Cash_Receipt__r.' + PACKAGE_QUALIFIER + 'Account__c',
            PACKAGE_QUALIFIER + 'Cash_Receipt__r.' + PACKAGE_QUALIFIER + 'Payment_Reference__c',
            PACKAGE_QUALIFIER + 'Cash_Receipt__r.' + PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c',
            PACKAGE_QUALIFIER + 'Cash_Receipt__r.' + PACKAGE_QUALIFIER + 'Ledger__c',
            PACKAGE_QUALIFIER + 'Adjustment_Amount__c',
            PACKAGE_QUALIFIER + 'Adjustment_GL_Account__c',
            PACKAGE_QUALIFIER + 'Cash_Receipt__r.' + PACKAGE_QUALIFIER + 'GL_Account_Variable_2__c',
            PACKAGE_QUALIFIER + 'Cash_Receipt__r.' + PACKAGE_QUALIFIER + 'GL_Account_Variable_3__c',
            PACKAGE_QUALIFIER + 'Cash_Receipt__r.' + PACKAGE_QUALIFIER + 'GL_Account_Variable_4__c',
            PACKAGE_QUALIFIER + 'Cash_Receipt__r.' + PACKAGE_QUALIFIER + 'Amount__c',
            PACKAGE_QUALIFIER + 'Billing__r.' + PACKAGE_QUALIFIER + 'Customer__c',
            PACKAGE_QUALIFIER + 'Billing__r.' + PACKAGE_QUALIFIER + 'Ledger__c',
            PACKAGE_QUALIFIER + 'Billing__r.' + PACKAGE_QUALIFIER + 'Credit_Memo_Applied_Amount__c',
            PACKAGE_QUALIFIER + 'Billing__r.' + PACKAGE_QUALIFIER + 'Ledger__r.' + PACKAGE_QUALIFIER + 'Accounting_Method__c',
            PACKAGE_QUALIFIER + 'Cash_Receipt__r.' + PACKAGE_QUALIFIER + 'Currency_Conversion_Rate__c',
            PACKAGE_QUALIFIER + 'Billing__r.' + PACKAGE_QUALIFIER + 'Currency_Conversion_Rate__c',
            PACKAGE_QUALIFIER + 'Billing__r.' + PACKAGE_QUALIFIER + 'Total__c',
            PACKAGE_QUALIFIER + 'Billing__c'

        };
        //Add Multi currency fields
        if (IS_MULTI_CURRENCY_ENABLED) {
            fieldsToQuery.add('CurrencyIsoCode');
            fieldsToQuery.add(PACKAGE_QUALIFIER + 'Billing__r.CurrencyIsoCode');
            fieldsToQuery.add(PACKAGE_QUALIFIER + 'Cash_Receipt__r.CurrencyIsoCode');
        }

        //Add query condition
        String queryCondition = 'Id IN :processedRecordIds FOR UPDATE';
        //Final assembly of SOQL string
        String dynamicSOQL = SOQLBuilder.buildDynamicSoqlQuery(
            fieldsToQuery,
            NULL,
            Billing_Cash_Receipt__c.SObjectType,
            queryCondition,
            true,
            false
        );
        //Call DML operation
        sourceRecords = Database.query(dynamicSOQL);
    }

    //=============================================================================================
    //========================== Validation methods ===============================================
    private Boolean isValidCashBasisLimit(ProportionalDistributionHelper calculation) {
        Boolean isValid = true;
        if (calculation != null && calculation.totalLinesCount() > LINE_COUNT_LIMIT) {
            for (Billing_Cash_Receipt__c bcr : (List<Billing_Cash_Receipt__c>) sourceRecords) {
                dispatcher.addPostErrorResult(
                    bcr.Id,
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
        for (Billing_Cash_Receipt__c bcr : (List<Billing_Cash_Receipt__c>) sourceRecords) {
            if (!glAccountDefaults.containsKey(bcr.Cash_Receipt__r.Ledger__c) ||
                (glAccountDefaults.containsKey(bcr.Cash_Receipt__r.Ledger__c)
                    && !glAccountDefaults.get(bcr.Cash_Receipt__r.Ledger__c).containsKey(GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT))
                || (glAccountDefaults.containsKey(bcr.Cash_Receipt__r.Ledger__c)
                && !glAccountDefaults.get(bcr.Cash_Receipt__r.Ledger__c).containsKey(GLAccountDefaultsHandler.UNAPPLIED_CASH_GL_ACCOUNT))) {
                dispatcher.addPostErrorResult(
                    bcr.Id,
                    new PostResult.PostErrorResult(
                        PostResult.StatusCode.NO_CONTROL_AR_OR_UNAPPLIED_CASH_ACCOUNT_DEFINED,
                        NO_CONTROL_ACCOUNT_MESSAGE
                    )
                );
                isValid = false;
            }
        }
        return isValid;
    }

    private void validateNoRefundBCRs() {
        List<SObject> validRecords = new List<SObject>();
        for (SObject masterRecord : sourceRecords) {
            if (masterRecord.get('Status__c') == DEFAULT_POSTING_STATUS_BCR_REFUND) {
                dispatcher.addPostErrorResult(
                    masterRecord,
                    new PostResult.PostErrorResult(
                        masterRecord,
                        PostResult.statusCode.INVALID_RECORD_ID,
                        REFUND_STATUS_CANNOT_BE_POSTED
                    )
                );
            }
            else {
                validRecords.add(masterRecord);
            }
        }
           
        sourceRecords = validRecords;
    }


    //=============================================================================================
    //========================== POST processing ==================================================
    private void processBillingCashReceiptTransactions() {
        Savepoint sp = Database.setSavepoint();

        try {
            // delete any and all transactions associated with the source document
            // before another set of transactions are created and the status is changed
            if (!isLDVBatchContext) {
                TransactionActions.deleteTransactions(TransactionActions.queryTransactions(sourceRecords));
            }
            //=========================================================================================

            //If MC is enabled ==================
            getCurrencyInformation();
            //===================================
            List<Transaction__c> transList = new List<Transaction__c>();
            for (Billing_Cash_Receipt__c billReceipt : (List<Billing_Cash_Receipt__c>) sourceRecords) {
                List<Transaction__c> tempTransList = new List<Transaction__c>();
                if (isAllowToCreate(billReceipt) && billReceipt.Billing__r.Ledger__r.Accounting_Method__c != null
                    && (LedgerHandler.getInstanceWithoutSharing().isAccrualAndCashLedger(billReceipt.Billing__r.Ledger__c)
                    || LedgerHandler.getInstanceWithoutSharing().isAccrualLedger(billReceipt.Billing__r.Ledger__c))) {
                    //======================================================================================================
                    //========================== CREATE APPLIED OR UNAPPLIED TRANSACTION ===================================
                    //======================================================================================================
                    Transaction__c trans = createTransaction(billReceipt);
                    trans.Account__c = billReceipt.Cash_Receipt__r.Account__c;
                    //MC part ==============================================================================================
                    processTransactionAmount(billReceipt, trans, billReceipt.Applied_Amount__c, billReceipt.Cash_Receipt__r.Currency_Conversion_Rate__c);
                    //======================================================================================================
                    trans.GL_Account__c = (billReceipt.Cash_Receipt__r.Credit_GL_Account__c != NULL) ? billReceipt.Cash_Receipt__r.Credit_GL_Account__c :
                        glAccountDefaults.get(billReceipt.Cash_Receipt__r.Ledger__c).get(GLAccountDefaultsHandler.UNAPPLIED_CASH_GL_ACCOUNT).GL_Account__c;
                    tempTransList.add(trans);

                    //======================================================================================================
                    //=============================== CREATE AR TRANSACTION LINE ===========================================
                    //======================================================================================================
                    trans = createTransaction(billReceipt);
                    //MC part ==============================================================================================
                    Decimal adjustmentAmount = 0;
                    if (billReceipt.Adjustment_GL_Account__c != null && billReceipt.Adjustment_Amount__c != null && billReceipt.Adjustment_Amount__c != 0) {
                        adjustmentAmount = billReceipt.Adjustment_Amount__c.setScale(2, System.RoundingMode.HALF_UP);
                    }
                    Decimal amountResult = (billReceipt.Applied_Amount__c + adjustmentAmount) * -1;

                    processTransactionAmount(billReceipt, trans, amountResult, billReceipt.Billing__r.Currency_Conversion_Rate__c);
                    //======================================================================================================
                    trans.GL_Account__c = glAccountDefaults.get(billReceipt.Cash_Receipt__r.Ledger__c).get(GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT).GL_Account__c;
                    tempTransList.add(trans);

                    //======================================================================================================
                    //=========================== CREATE CASH RECEIPT ADJUSTMENT TRANSACTION LINE ==========================
                    //======================================================================================================
                    if ((billReceipt.Adjustment_Amount__c != NULL && billReceipt.Adjustment_Amount__c.setScale(2, System.RoundingMode.HALF_UP) != 0) && billReceipt.Adjustment_GL_Account__c != NULL) {
                        trans = createTransaction(billReceipt);
                        //MC part ==========================================================================================
                        processTransactionAmount(billReceipt, trans, billReceipt.Adjustment_Amount__c, billReceipt.Cash_Receipt__r.Currency_Conversion_Rate__c);
                        //==================================================================================================
                        trans.GL_Account__c = billReceipt.Adjustment_GL_Account__c;
                        tempTransList.add(trans);
                    }

                    //======================================================================================================
                    //=========================== CREATE FOREIGN EXCHANGE GAIN/LOSS TRANSACTION LINE =======================
                    //======================================================================================================
                    if (isMultiCurrencyAndDifferentCurrency(billReceipt.Id, trans.Ledger__c)) {
                        trans = createTransaction(billReceipt);

                        Decimal arLineAmount = amountResult / billReceipt.Billing__r.Currency_Conversion_Rate__c;/*negative line*/

                        Decimal unappliedCashLineAmount = billReceipt.Applied_Amount__c / billReceipt.Cash_Receipt__r.Currency_Conversion_Rate__c;/*positive line*/

                        Decimal adjAmount = (billReceipt.Adjustment_Amount__c != NULL)
                            ?
                            billReceipt.Adjustment_Amount__c / billReceipt.Cash_Receipt__r.Currency_Conversion_Rate__c
                            :
                            0;

                        trans.Amount__c = (arLineAmount.setScale(2, System.RoundingMode.HALF_UP) + unappliedCashLineAmount.setScale(2, System.RoundingMode.HALF_UP) + adjAmount.setScale(2, System.RoundingMode.HALF_UP)) * -1;

                        trans.GL_Account__c = glAccountDefaults.get(billReceipt.Cash_Receipt__r.Ledger__c).get(GLAccountDefaultsHandler.CURRENCY_GAIN_LOSS_GL_ACCOUNT).GL_Account__c;
                        tempTransList.add(trans);
                    }
                }

                if (billReceipt.Billing__r.Ledger__r.Accounting_Method__c != null
                    && (LedgerHandler.getInstanceWithoutSharing().isAccrualAndCashLedger(billReceipt.Billing__r.Ledger__c)
                    || LedgerHandler.getInstanceWithoutSharing().isCashLedger(billReceipt.Billing__r.Ledger__c))) {
                    tempTransList.addAll(getCashLedgerTransaction(billReceipt));
                }

                if (isLDVBatchContext) {
                    resultTransList.put(billReceipt.Id, new List<Transaction__c> (tempTransList));
                }
                transList.addAll(tempTransList);
            }

            if (!isLDVBatchContext) {
                for (Billing_Cash_Receipt__c billingCashReceipt : (List<Billing_Cash_Receipt__c>) sourceRecords) {
                    billingCashReceipt.Status__c = DEFAULT_POSTING_STATUS_POSTED;
                }
                //convert generic collection to the collection with specific SObjectType
                List<Billing_Cash_Receipt__c> sourceRecordsToUpdate = new List<Billing_Cash_Receipt__c>((List<Billing_Cash_Receipt__c>) sourceRecords);

                TriggerObserver.getInstance().unlockField(Billing_Cash_Receipt__c.Status__c);
                SFDCSecurityUtils.updateCheckCRUDAndFLS(sourceRecordsToUpdate, new List<String>{'Status__c'});
                TriggerObserver.purgeUnlockedFields(Billing_Cash_Receipt__c.Status__c);

                sourceRecords = DomainUtils.getBillingCashReceiptsByIdForUpdate(new Map<Id, SObject>(sourceRecords).keySet());
                validatePostStatusSet();

                TransactionActions.createTransactions(transList);
            }
        }
        catch (Exception ex) {
            Database.rollback(sp);
            throw ex;
        }
    }

    private void processTransactionAmount(Billing_Cash_Receipt__c billReceipt, Transaction__c trans, Decimal amount, Decimal ccr) {
        if (isMultiCurrencyAndDifferentCurrency(billReceipt.Id, trans.Ledger__c)) {
            trans.Foreign_Amount__c = amount;
            trans.Foreign_Currency__c = (String) billReceipt.getSObject(PACKAGE_QUALIFIER + 'Cash_Receipt__r').get('CurrencyIsoCode');
            trans.Currency_Conversion_Rate__c = ccr;
            trans.Amount__c = (amount / ccr).setScale(2, System.RoundingMode.HALF_UP);
        }
        else {
            trans.Amount__c = amount.setScale(2, System.RoundingMode.HALF_UP);
        }
    }

    private void processCashTransactionAmount(Billing_Cash_Receipt__c billReceipt, Transaction__c trans) {
        Decimal amount = trans.Amount__c;
        if (isMultiCurrencyAndDifferentCurrency(billReceipt.Id, trans.Ledger__c)) {
            trans.Foreign_Amount__c = amount;
            trans.Foreign_Currency__c = (String) billReceipt.getSObject(PACKAGE_QUALIFIER + 'Cash_Receipt__r').get('CurrencyIsoCode');
            trans.Currency_Conversion_Rate__c = billReceipt.Cash_Receipt__r.Currency_Conversion_Rate__c;
            trans.Amount__c = (amount / billReceipt.Cash_Receipt__r.Currency_Conversion_Rate__c).setScale(2, System.RoundingMode.HALF_UP);
        }
    }

    private List<Transaction__c> getCashLedgerTransaction(Billing_Cash_Receipt__c billReceipt) {
        List<Transaction__c> shadowTrans = new List<Transaction__c>();
        resetRoundingAdjustment();
        if (pdHelper.getTransactionAmountCalculationById(billReceipt.Billing__c) != null) {
            ProportionalDistributionHelper.TransactionAmountCalculation calculation =
                pdHelper.getTransactionAmountCalculationById(billReceipt.Billing__c);
            if (IS_HEADER_LEVEL_POST) {
                shadowTrans.addAll(getHLPTransactions(billReceipt, calculation));
            } else {
                shadowTrans.addAll(getLLPTransactions(billReceipt, calculation));
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
        if (Math.abs(getRoundingAmount()) != Math.abs(roundingBalance)) {
            roundingAdjustment.get('credit').Amount__c += roundingAdjustment.get('credit').Amount__c < 0 ?
                ((Math.abs(getRoundingAmount()) - Math.abs(roundingBalance)) * -1) :
                (Math.abs(getRoundingAmount()) - Math.abs(roundingBalance));
        }
        if (roundingAdjustment.get('debit').Foreign_Amount__c != null
            && Math.abs(getRoundingForeignAmount()) != Math.abs(foreignRoundingBalance)) {
            roundingAdjustment.get('credit').Foreign_Amount__c += roundingAdjustment.get('credit').Foreign_Amount__c < 0 ?
            ((Math.abs(getRoundingForeignAmount()) - Math.abs(foreignRoundingBalance)) * -1) :
                (Math.abs(getRoundingForeignAmount()) - Math.abs(foreignRoundingBalance));
        }
    }

    private Decimal getRoundingAmount() {
        return roundingAdjustment.containsKey('adjustment') ?
            roundingAdjustment.get('debit').Amount__c + roundingAdjustment.get('adjustment').Amount__c
            : roundingAdjustment.get('debit').Amount__c;
    }

    private Decimal getRoundingForeignAmount() {
        return roundingAdjustment.containsKey('adjustment') ?
            roundingAdjustment.get('debit').Foreign_Amount__c + roundingAdjustment.get('adjustment').Foreign_Amount__c
            : roundingAdjustment.get('debit').Foreign_Amount__c;
    }

    private void addRoundingBalance(Transaction__c trans) {
        roundingBalance += trans.Amount__c;
        if (trans.Foreign_Amount__c != null) {
            foreignRoundingBalance += trans.Foreign_Amount__c;
        }
    }

    private void validateTransForRounding(List<Transaction__c> trans) {
        for (Transaction__c tr : trans) {
            if ((roundingAdjustment.containsKey('credit')
                && Math.abs(roundingAdjustment.get('credit').Amount__c) < Math.abs(tr.Amount__c))
                || !roundingAdjustment.containsKey('credit')) {
                roundingAdjustment.put('credit', tr);
            }
            addRoundingBalance(tr);
        }
    }

    private List<Transaction__c> getHLPTransactions(Billing_Cash_Receipt__c billReceipt, ProportionalDistributionHelper.TransactionAmountCalculation calculation) {
        List<Transaction__c> result = new List<Transaction__c>();
        if (isAllowToCreate(billReceipt)) {
            Transaction__c trans = createTransaction(billReceipt);
            trans.Billing__c = billReceipt.Billing__c;
            trans.Ledger__c = getCashLedgerId(billReceipt);
            trans.Account__c = billReceipt.Cash_Receipt__r.Account__c;
            trans.Amount__c = billReceipt.Applied_Amount__c.setScale(2, System.RoundingMode.HALF_UP);
            trans.GL_Account__c = getCashCreditGLAccount(billReceipt);
            result.add(trans);
            roundingAdjustment.put('debit', trans);
            if (calculation.adjustmentAmount != null && calculation.adjustmentAmount != 0) {
                Transaction__c adjustmentTrans = createTransaction(billReceipt);
                adjustmentTrans.Billing__c = billReceipt.Billing__c;
                adjustmentTrans.Ledger__c = getCashLedgerId(billReceipt);
                adjustmentTrans.Account__c = billReceipt.Cash_Receipt__r.Account__c;
                adjustmentTrans.Amount__c = calculation.adjustmentAmount.setScale(2, System.RoundingMode.HALF_UP);
                adjustmentTrans.GL_Account__c = billReceipt.Adjustment_GL_Account__c;
                result.add(adjustmentTrans);
                roundingAdjustment.put('adjustment', adjustmentTrans);
            }
        }
        Map<String, Transaction__c> glAccountIdToDebitTransaction = new Map<String, Transaction__c>();
        for (ProportionalDistributionHelper.TransactionAmountCalculationLine line : calculation.lines) {
            if (!line.isFuturePeriod && !(line.isCreditMemo && !isAllowToCreate(billReceipt))) {
                Transaction__c cashTrans = createCashTransaction(line);
                cashTrans.Billing_Cash_Receipt__c = billReceipt.Id;
                cashTrans.Billing__c = billReceipt.Billing__c;
                cashTrans.Accounting_Period__c = billReceipt.Accounting_Period__c;
                Date transDate = billReceipt.Applied_Date__c != NULL ? billReceipt.Applied_Date__c : billReceipt.Accounting_Period__r.Start_Date__c;
                cashTrans.Date__c = transDate;
                cashTrans.Account__c = billReceipt.Billing__r.Customer__c;
                cashTrans.Ledger__c = getCashLedgerId(billReceipt);
                cashTrans.Note__c = billReceipt.Cash_Receipt__r.Payment_Reference__c;
                cashTrans.Amount__c = (line.subTotal * -1).setScale(2, System.RoundingMode.HALF_UP);

                if (glAccountIdToDebitTransaction.containsKey(getTransactionKey(cashTrans, false))) {
                    Transaction__c exTrans = glAccountIdToDebitTransaction.get(getTransactionKey(cashTrans, false));
                    exTrans.Amount__c += cashTrans.Amount__c;
                } else {
                    glAccountIdToDebitTransaction.put(getTransactionKey(cashTrans, false), cashTrans);
                }

                if (line.taxAmount != null && line.taxAmount != 0 && String.isNotBlank(line.taxGroupId)) {
                    processTaxTransaction(line, glAccountIdToDebitTransaction, billReceipt);
                }

                if (String.isBlank(line.taxGroupId) && line.taxAmount != null && line.taxAmount != 0 && line.taxRate != null && line.taxRate != 0) {
                    processAvaTaxTransaction(line, glAccountIdToDebitTransaction, billReceipt);
                }
            }
        }

        if (!calculation.existedPay.isEmpty()) {
            List<String> existedKeys = new List<String>();
            for (Billing_Cash_Receipt__c bcr : (List<Billing_Cash_Receipt__c>) calculation.existedPay) {
                for (Transaction__c tr : bcr.Transactions__r) {
                    if (tr.Billing_Cash_Receipt__c == billReceipt.Id) {
                        existedKeys.add(getTransactionKey(tr, false));
                        existedKeys.add(getTransactionKey(tr, true));
                    }
                }
            }
            for (Billing_Cash_Receipt__c bcr : (List<Billing_Cash_Receipt__c>) calculation.existedPay) {
                for (Transaction__c tr : bcr.Transactions__r) {
                    String key = getTransactionKey(tr, false).replace(String.valueOf(tr.Billing_Cash_Receipt__c), String.valueOf(billReceipt.Id));
                    String taxKey = getTransactionKey(tr, true).replace(String.valueOf(tr.Billing_Cash_Receipt__c), String.valueOf(billReceipt.Id));
                    if (isLDVBatchContext && tr.Billing_Cash_Receipt__c != billReceipt.Id) {
                        if (!existedKeys.contains(key) && glAccountIdToDebitTransaction.keySet().contains(key)) {
                            reduceTransactionAmount(glAccountIdToDebitTransaction.get(key), tr, billReceipt);
                        } else if (!existedKeys.contains(taxKey) && glAccountIdToDebitTransaction.keySet().contains(taxKey)) {
                            reduceTransactionAmount(glAccountIdToDebitTransaction.get(taxKey), tr, billReceipt);
                        }
                    } else if (!isLDVBatchContext && tr.Billing_Cash_Receipt__c != billReceipt.Id) {
                        if (glAccountIdToDebitTransaction.keySet().contains(key)) {
                            reduceTransactionAmount(glAccountIdToDebitTransaction.get(key), tr, billReceipt);
                        } else if (glAccountIdToDebitTransaction.keySet().contains(taxKey)) {
                            reduceTransactionAmount(glAccountIdToDebitTransaction.get(taxKey), tr, billReceipt);
                        }
                    }
                }
            }
        }

        for (Transaction__c tr : result) {
            processCashTransactionAmount(billReceipt, tr);
        }

        for (Transaction__c tr : glAccountIdToDebitTransaction.values()) {
            processCashTransactionAmount(billReceipt, tr);
        }

        if (!isLDVBatchContext) {
            validateTransForRounding(glAccountIdToDebitTransaction.values());
            adjustRounding();
        }

        result.addAll(glAccountIdToDebitTransaction.values());
        return result;
    }

    private List<Transaction__c> getLLPTransactions(Billing_Cash_Receipt__c billReceipt, ProportionalDistributionHelper.TransactionAmountCalculation calculation) {
        Map<String, String> transPair = new Map<String, String>();
        Map<String, Transaction__c> glAccountIdToDebitTransaction = new Map<String, Transaction__c>();
        List<String> creditBalanceTransactions = new List<String>();
        if (isAllowToCreate(billReceipt) && calculation.adjustmentAmount != null && calculation.adjustmentAmount != 0) {
            Transaction__c adjustmentTransDebit = createTransaction(billReceipt);
            adjustmentTransDebit.Billing__c = billReceipt.Billing__c;
            adjustmentTransDebit.Ledger__c = getCashLedgerId(billReceipt);
            adjustmentTransDebit.GL_Account__c = getCashCreditGLAccount(billReceipt);
            adjustmentTransDebit.Amount__c = (calculation.adjustmentAmount * -1).setScale(2, System.RoundingMode.HALF_UP);
            glAccountIdToDebitTransaction.put(getTransactionKey(adjustmentTransDebit, false) + 'null' + llpNegativeKey(adjustmentTransDebit), adjustmentTransDebit);
            creditBalanceTransactions.add(getTransactionKey(adjustmentTransDebit, false) + 'null' + llpNegativeKey(adjustmentTransDebit));

            Transaction__c adjustmentTrans = createTransaction(billReceipt);
            adjustmentTrans.Billing__c = billReceipt.Billing__c;
            adjustmentTrans.Ledger__c = getCashLedgerId(billReceipt);
            adjustmentTrans.Amount__c = calculation.adjustmentAmount.setScale(2, System.RoundingMode.HALF_UP);
            adjustmentTrans.GL_Account__c = billReceipt.Adjustment_GL_Account__c;
            glAccountIdToDebitTransaction.put(getTransactionKey(adjustmentTrans, false) + 'null' + llpNegativeKey(adjustmentTrans), adjustmentTrans);
            transPair.put(
                getTransactionKey(adjustmentTransDebit, false) + 'null' + llpNegativeKey(adjustmentTransDebit),
                getTransactionKey(adjustmentTrans, false) + 'null' + llpNegativeKey(adjustmentTrans)
            );
            transPair.put(
                getTransactionKey(adjustmentTrans, false) + 'null' + llpNegativeKey(adjustmentTrans),
                getTransactionKey(adjustmentTransDebit, false) + 'null' + llpNegativeKey(adjustmentTransDebit)
            );
        }
        for (ProportionalDistributionHelper.TransactionAmountCalculationLine line : calculation.lines) {
            if (!line.isFuturePeriod && !(line.isCreditMemo && !isAllowToCreate(billReceipt))) {
                Transaction__c cashTransDebit = createCashTransaction(line);
                cashTransDebit.Billing_Cash_Receipt__c = billReceipt.Id;
                cashTransDebit.Billing_Line__c = line.recordId;
                cashTransDebit.Accounting_Period__c = billReceipt.Accounting_Period__c;
                Date transDate = billReceipt.Applied_Date__c != NULL ? billReceipt.Applied_Date__c : billReceipt.Accounting_Period__r.Start_Date__c;
                cashTransDebit.Date__c = transDate;
                cashTransDebit.Account__c = billReceipt.Billing__r.Customer__c;
                cashTransDebit.Ledger__c = getCashLedgerId(billReceipt);
                cashTransDebit.Note__c = billReceipt.Cash_Receipt__r.Payment_Reference__c;
                cashTransDebit.GL_Account__c = getCashCreditGLAccount(billReceipt);
                cashTransDebit.Amount__c = line.subTotal.setScale(2, System.RoundingMode.HALF_UP);
                glAccountIdToDebitTransaction.put(getTransactionKey(cashTransDebit, false) + line.recordId + llpNegativeKey(cashTransDebit), cashTransDebit);
                creditBalanceTransactions.add(getTransactionKey(cashTransDebit, false) + line.recordId + llpNegativeKey(cashTransDebit));

                Transaction__c cashTrans = createCashTransaction(line);
                cashTrans.Billing_Cash_Receipt__c = billReceipt.Id;
                cashTrans.Billing_Line__c = line.recordId;
                cashTrans.Accounting_Period__c = billReceipt.Accounting_Period__c;
                cashTrans.Date__c = transDate;
                cashTrans.Account__c = billReceipt.Billing__r.Customer__c;
                cashTrans.Ledger__c = getCashLedgerId(billReceipt);
                cashTrans.Note__c = billReceipt.Cash_Receipt__r.Payment_Reference__c;
                cashTrans.Amount__c = (line.subTotal * -1).setScale(2, System.RoundingMode.HALF_UP);
                glAccountIdToDebitTransaction.put(getTransactionKey(cashTrans, false) + line.recordId + llpNegativeKey(cashTrans), cashTrans);
                transPair.put(
                    getTransactionKey(cashTransDebit, false) + line.recordId + llpNegativeKey(cashTransDebit),
                    getTransactionKey(cashTrans, false) + line.recordId + llpNegativeKey(cashTrans)
                );
                transPair.put(
                    getTransactionKey(cashTrans, false) + line.recordId + llpNegativeKey(cashTrans),
                    getTransactionKey(cashTransDebit, false) + line.recordId + llpNegativeKey(cashTransDebit)
                );
            }
        }

        if (!calculation.existedPay.isEmpty()) {
            for (Billing_Cash_Receipt__c bcr : (List<Billing_Cash_Receipt__c>) calculation.existedPay) {
                for (Transaction__c tr : bcr.Transactions__r) {
                    String key = getTransactionKey(tr, false).replace(String.valueOf(tr.Billing_Cash_Receipt__c), String.valueOf(billReceipt.Id));
                    if (tr.Billing_Cash_Receipt__c != billReceipt.Id
                        && glAccountIdToDebitTransaction.keySet().contains(key + String.valueOf(tr.Billing_Line__c) + llpNegativeKey(tr))) {
                        reduceTransactionAmount(
                            glAccountIdToDebitTransaction.get(key + String.valueOf(tr.Billing_Line__c) + llpNegativeKey(tr)), tr, billReceipt
                        );
                    }
                }
            }
        }
        Decimal debitBalance = 0;
        Decimal debitForeignBalance = 0;
        for (Transaction__c tr : glAccountIdToDebitTransaction.values()) {
            processCashTransactionAmount(billReceipt, tr);
            if (creditBalanceTransactions.contains(getTransactionKey(tr, false) + tr.Billing_Line__c + llpNegativeKey(tr))) {
                debitBalance += tr.Amount__c;
                if (isMultiCurrencyAndDifferentCurrency(billReceipt.Id, tr.Ledger__c) && tr.Foreign_Amount__c != null) {
                    debitForeignBalance += tr.Foreign_Amount__c;
                }
            }
        }

        if (!isLDVBatchContext) {
            validateTransForRounding(glAccountIdToDebitTransaction.values());
            if (debitForeignBalance != 0
                && (getAbsBCRBalance(billReceipt) != Math.abs(debitForeignBalance)
                || Math.abs(getAppliedAmountInLedgerCurrency(billReceipt)) != Math.abs(debitBalance))) {
                Transaction__c oppositeForeign = getOppositeTransaction(glAccountIdToDebitTransaction, transPair);
                Decimal absForeignValue = getAbsBCRBalance(billReceipt) - Math.abs(debitForeignBalance);
                roundingAdjustment.get('credit').Foreign_Amount__c += roundingAdjustment.get('credit').Foreign_Amount__c > 0 ?
                    absForeignValue : absForeignValue * -1;
                oppositeForeign.Foreign_Amount__c += oppositeForeign.Foreign_Amount__c > 0 ? absForeignValue : absForeignValue * -1;

                Decimal absValue = Math.abs(getAppliedAmountInLedgerCurrency(billReceipt)) - Math.abs(debitBalance);
                roundingAdjustment.get('credit').Amount__c += roundingAdjustment.get('credit').Amount__c > 0 ?
                    absValue : absValue * -1;
                oppositeForeign.Amount__c += oppositeForeign.Amount__c > 0 ? absValue : absValue * -1;
            } else if (debitForeignBalance == 0 && getAbsBCRBalance(billReceipt) != Math.abs(debitBalance)) {
                Transaction__c opposite = getOppositeTransaction(glAccountIdToDebitTransaction, transPair);
                Decimal absValue = getAbsBCRBalance(billReceipt) - Math.abs(debitBalance);
                roundingAdjustment.get('credit').Amount__c += roundingAdjustment.get('credit').Amount__c > 0 ?
                    absValue : absValue * -1;
                opposite.Amount__c += opposite.Amount__c > 0 ? absValue : absValue * -1;
            }
        }

        return glAccountIdToDebitTransaction.values();
    }

    private String llpNegativeKey(Transaction__c tr) {
        return tr.Amount__c < 0 ? '-' : '';
    }

    private Decimal getAbsBCRBalance(Billing_Cash_Receipt__c billReceipt) {
        return Math.abs(billReceipt.Applied_Amount__c);
    }

    private Transaction__c getOppositeTransaction(Map<String, Transaction__c> glAccountIdToDebitTransaction, Map<String, String> transPair) {
        return glAccountIdToDebitTransaction.get(transPair.get(
            getTransactionKey(roundingAdjustment.get('credit'), false)
            + roundingAdjustment.get('credit').Billing_Line__c
            + llpNegativeKey(roundingAdjustment.get('credit')))
        );
    }

    public Decimal getAppliedAmountInLedgerCurrency(Billing_Cash_Receipt__c billReceipt) {
        return (billReceipt.Applied_Amount__c
            / billReceipt.Cash_Receipt__r.Currency_Conversion_Rate__c).setScale(2, System.RoundingMode.HALF_UP);
    }

    private Id getCashLedgerId(Billing_Cash_Receipt__c billReceipt) {
        return LedgerHandler.getInstanceWithoutSharing().isCashLedger(billReceipt.Billing__r.Ledger__c)
            ? billReceipt.Billing__r.Ledger__c
            : LedgerHandler.getInstanceWithoutSharing().getShadowLedgerByParent(billReceipt.Billing__r.Ledger__c).Id;
    }

    public Id getCashCreditGLAccount(Billing_Cash_Receipt__c billReceipt) {
        Id creditGLAccount = billReceipt.Cash_Receipt__r.Credit_GL_Account__c;
        if (!LedgerHandler.getInstanceWithoutSharing().isCashLedger(billReceipt.Billing__r.Ledger__c) || creditGLAccount == null) {
            GL_Account_Default__c glDefRecord =
                glAccountDefaults.get(getCashLedgerId(billReceipt)).get(GLAccountDefaultsHandler.UNAPPLIED_REVENUE_GL_ACCOUNT);
            if (glDefRecord != null) {
                creditGLAccount = glDefRecord.GL_Account__c;
            }
            else {
                throw new PostHandlerException(Label.ERR_CR_NO_UNAPPLIED_REVENUE_GL_ACCOUNT);
            }
        }
        return creditGLAccount;
    }

    private Boolean isAllowToCreate(Billing_Cash_Receipt__c billReceipt) {
        return !isLDVBatchContext || (isLDVBatchContext && ldvFirstRun.contains(billReceipt.Id));
    }

    private void reduceTransactionAmount(Transaction__c newTr, Transaction__c existedTr, Billing_Cash_Receipt__c billReceipt) {
        newTr.Amount__c -= isMultiCurrencyAndDifferentCurrency(billReceipt.Id, existedTr.Ledger__c) ? existedTr.Foreign_Amount__c : existedTr.Amount__c;
    }

    private void processTaxTransaction(ProportionalDistributionHelper.TransactionAmountCalculationLine line,
        Map<String, Transaction__c> taxTransMap,
        Billing_Cash_Receipt__c billReceipt) {

        Map<Id, Decimal> rateAdjustment = AbstractTaxService.getTaxRateAdjustmentByAmount(
            (line.total).setScale(2, System.RoundingMode.HALF_UP), line.rates
        );

        for (Tax_Rate__c rate : line.rates) {
            Transaction__c creditTaxTR = createCashTransaction(line);
            creditTaxTR.Billing_Cash_Receipt__c = billReceipt.Id;
            creditTaxTR.Billing__c = billReceipt.Billing__c;
            creditTaxTR.Accounting_Period__c = billReceipt.Accounting_Period__c;
            Date transDate = billReceipt.Applied_Date__c != null ? billReceipt.Applied_Date__c : billReceipt.Accounting_Period__r.Start_Date__c;
            creditTaxTR.Date__c = transDate;
            creditTaxTR.Account__c = billReceipt.Billing__r.Customer__c;
            creditTaxTR.Ledger__c = getCashLedgerId(billReceipt);
            creditTaxTR.GL_Account__c = rate.Sales_Tax_Liability_GL_Account__c;
            creditTaxTR.Time_Card_Variable_1__c = line.timeCardVar1Id;
            creditTaxTR.Time_Card_Variable_2__c = line.timeCardVar2Id;
            creditTaxTR.GL_Account_Variable_1__c = line.glav1Id;
            creditTaxTR.GL_Account_Variable_2__c = line.glav2Id;
            creditTaxTR.GL_Account_Variable_3__c = line.glav3Id;
            creditTaxTR.GL_Account_Variable_4__c = line.glav4Id;
            creditTaxTR.Product__c = null;
            creditTaxTR.Project__c = null;
            creditTaxTR.Project_Task__c = null;
            creditTaxTR.Amount__c = ((rate.Tax_Rate__c / line.taxRate * line.taxAmount) * -1).setScale(2, System.RoundingMode.HALF_UP);

            if (rateAdjustment.containsKey(rate.Id)
                && service.getTaxRoundingThreshold(billReceipt.Billing__r) >= rateAdjustment.get(rate.Id).abs()) {

                creditTaxTR.Amount__c += rateAdjustment.get(rate.Id);
            }

            populateTransactionMap(creditTaxTR, taxTransMap, true);
        }
    }

    private void processAvaTaxTransaction(ProportionalDistributionHelper.TransactionAmountCalculationLine line,
        Map<String, Transaction__c> taxTransMap,
        Billing_Cash_Receipt__c billReceipt) {

            Transaction__c creditTaxTR = createCashTransaction(line);
            creditTaxTR.Billing_Cash_Receipt__c = billReceipt.Id;
            creditTaxTR.Billing__c = billReceipt.Billing__c;
            creditTaxTR.Accounting_Period__c = billReceipt.Accounting_Period__c;
            Date transDate = billReceipt.Applied_Date__c != NULL ? billReceipt.Applied_Date__c : billReceipt.Accounting_Period__r.Start_Date__c;
            creditTaxTR.Date__c = transDate;
            creditTaxTR.Account__c = billReceipt.Billing__r.Customer__c;
            creditTaxTR.Ledger__c = getCashLedgerId(billReceipt);
            creditTaxTR.GL_Account__c = AvaTaxHelper.getAvaTaxGLAccount(billReceipt.Billing__r);
            creditTaxTR.Time_Card_Variable_1__c = line.timeCardVar1Id;
            creditTaxTR.Time_Card_Variable_2__c = line.timeCardVar2Id;
            creditTaxTR.GL_Account_Variable_1__c = line.glav1Id;
            creditTaxTR.GL_Account_Variable_2__c = line.glav2Id;
            creditTaxTR.GL_Account_Variable_3__c = line.glav3Id;
            creditTaxTR.GL_Account_Variable_4__c = line.glav4Id;
            creditTaxTR.Product__c = null;
            creditTaxTR.Project__c = null;
            creditTaxTR.Project_Task__c = null;
            creditTaxTR.Amount__c = (line.taxAmount * -1).setScale(2, System.RoundingMode.HALF_UP);
            populateTransactionMap(creditTaxTR, taxTransMap, true);
    }

    private Transaction__c createTransaction(Billing_Cash_Receipt__c billReceipt) {
        Transaction__c trans = new Transaction__c();
        trans.Billing_Cash_Receipt__c = billReceipt.Id;
        trans.Accounting_Period__c = billReceipt.Accounting_Period__c;
        Date transDate = billReceipt.Applied_Date__c != NULL ? billReceipt.Applied_Date__c : billReceipt.Accounting_Period__r.Start_Date__c;
        trans.Date__c = transDate;
        trans.Account__c = billReceipt.Billing__r.Customer__c;
        trans.Ledger__c = billReceipt.Cash_Receipt__r.Ledger__c != NULL ? billReceipt.Cash_Receipt__r.Ledger__c : LedgerHandler.getLegacyDefaultLedgerId();
        trans.Note__c = billReceipt.Cash_Receipt__r.Payment_Reference__c;
        trans.Product__c = billReceipt.Cash_Receipt__r.Product__c;
        trans.Project__c = billReceipt.Cash_Receipt__r.Project__c;
        trans.Project_Task__c = billReceipt.Cash_Receipt__r.Project_Task__c;
        trans.GL_Account_Variable_1__c = billReceipt.Cash_Receipt__r.GL_Account_Variable_1__c;
        trans.GL_Account_Variable_2__c = billReceipt.Cash_Receipt__r.GL_Account_Variable_2__c;
        trans.GL_Account_Variable_3__c = billReceipt.Cash_Receipt__r.GL_Account_Variable_3__c;
        trans.GL_Account_Variable_4__c = billReceipt.Cash_Receipt__r.GL_Account_Variable_4__c;
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
        trans.Time_Card_Variable_1__c = line.timeCardVar1Id;
        trans.Time_Card_Variable_2__c = line.timeCardVar2Id;
        return trans;
    }

    public override String getTransactionKey(Transaction__c pt, Boolean isTaxTransaction) {
        String result = '';
        result += String.valueOf(pt.Billing_Cash_Receipt__c);
        result += String.valueOf(pt.GL_Account_Variable_1__c);
        result += String.valueOf(pt.GL_Account_Variable_2__c);
        result += String.valueOf(pt.GL_Account_Variable_3__c);
        result += String.valueOf(pt.GL_Account_Variable_4__c);
        result += String.valueOf(pt.GL_Account__c);
        result += String.valueOf(pt.Time_Card_Variable_1__c);
        result += String.valueOf(pt.Time_Card_Variable_2__c);
        if (!isTaxTransaction) {
            result += String.valueOf(pt.Project__c);
            result += String.valueOf(pt.Project_Task__c);
            result += String.valueOf(pt.Product__c);
        }
        return result;
    }

    private void processUnpostBillingCashReceipt() {
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