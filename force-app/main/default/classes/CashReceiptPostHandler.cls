public with sharing class CashReceiptPostHandler extends AbstractPostHandler {
   
    @TestVisible
    private static final String POSTED_VOID_ERROR_MESSAGE = Label.ERR_CR_POSTED_VOID;
    @TestVisible
    private static final String UNPOST_CLEARED_ERROR_MESSAGE = Label.ERR_UNPOSTED_CLEARED_BANK_RECONCILIATION;
    @TestVisible
    private static final String UNPOSTED_BILLING_CASH_RECEIPTS_ERROR_MESSAGE = Label.ERR_UNPOSTED_BILLING_CASH_RECEIPTS;
    @TestVisible
    private static final String UNPOST_DEPOSIT_ERROR_MESSAGE = Label.ERR_UNPOSTED_CLEARED_BANK_DEPOSIT;

    public static final String NO_SELECTION_UNPOSTED_ERROR_MESSAGE = Label.ERR_AP_STATUS_OPEN_POSTED_NO_BILLING_CR_NO_BANK_RECONCILIATION_DEPOSIT;
    public static final String NO_UNAPPLIED_CASH_GL_ACCOUNT_MESSAGE = Label.ERR_CR_NO_UNAPPLIED_CASH_GL_ACCOUNT;
    public static final String NO_UNAPPLIED_REVENUE_GL_ACCOUNT_MESSAGE = Label.ERR_CR_NO_UNAPPLIED_REVENUE_GL_ACCOUNT;

    //============================================================================================
    // =========== LDV Support ===========================
    public override List<PostResult> post(List<LDVPostInput> sourceItems) {
        isLDVBatchContext = true;
        Map<Id, LDVPostInput> sourceMap = new Map<Id, LDVPostInput>();
        for (LDVPostInput item : sourceItems) {
            sourceMap.put(item.id, item);
        }
        return post(new List<Id>(sourceMap.keySet()));
    }


    //Post method implementation for Cash Receipts ====================================================
    public override List<PostResult> post(List<SObject> processedRecords) {
        Map<Id, Cash_Receipt__c> cashReceiptsMap = new Map<Id, Cash_Receipt__c>((List<Cash_Receipt__c>) processedRecords);
        return post(new List<Id>(cashReceiptsMap.keySet()));
    }

    public override List<PostResult> post(List<String> processedRecordsIds) {
        this.processedRecordIds = processedRecordsIds;

        if (!this.processedRecordIds.isEmpty()) {
            try {
                dispatcher.clearResultsMap();
                dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.POST);
                //Initial query for Cash Receipts
                queryCashReceipts();
                getGLAccountDefaults();
                validateUnappliedCashGLAccount(false);
                //weed out unsuitable Cash Receipts
                validateNotPosted(false);
                validateNotVoid(false);
                if (!isLDVBatchContext) {
                    validateStatusApproved(false);
                }
                validateAccountingPeriodIsOpen(false);
                validateLedgerType(false, false);
                validateCashFlowCategoryIsDefined(false);
                validateCashFlowStatementConformity(false);
                //no need to proceed further if there is no valid Cash Receipts after all validations above
                validateNoQualifyingPostedRecords();
                if (!sourceRecords.isEmpty()) {
                    processPostCashReceipts();
                    processPostResult();
                }
                dispatcher.isPreCheck = false;
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

    //==============================================================================================
    //Unpost method implementation ====================================================
    public override List<PostResult> unpost(List<LDVPostInput> sourceItems) {
        isLDVBatchContext = true;
        Map<Id, PostResult> postResults = new Map<Id, PostResult>();
        Map<Id, LDVPostInput> sourceMap = new Map<Id, LDVPostInput>();
        for (LDVPostInput item : sourceItems) {
            sourceMap.put(item.id, item);
        }
        for (PostResult res : unpost(new List<Id>(sourceMap.keySet()))) {
            postResults.put(res.id, res);
        }
        ldvGetPostResultMap(postResults, sourceMap);
        return postResults.values();
    }

    public override List<PostResult> unpost(List<SObject> processedRecords) {
        Map<Id, Cash_Receipt__c> cashReceiptsMap = new Map<Id, Cash_Receipt__c>((List<Cash_Receipt__c>) processedRecords);
        return unpost(new List<Id>(cashReceiptsMap.keySet()));
    }

    public override List<PostResult> unpost(List<String> processedRecordsIds) {
        this.processedRecordIds = processedRecordsIds;

        if (!this.processedRecordIds.isEmpty()) {
            try {
                dispatcher.clearResultsMap();
                dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.UNPOST);
                //Initial query for Cash Receipts
                queryCashReceipts();
                //weed out the unsuitable Cash Receipts
                if (isLDVBatchContext) {
                    validateIsPostedByApproval(true);
                }
                else {
                    validateIsPosted(false);
                }
                validateAccountingPeriodIsOpen(false);
                validateBillingCashReceiptsNotExist(false);
                validateNotAssociatedWithBankReconciliation(false);
                validateNotAssociatedWithBankDeposit(false);
                //no need to proceed further if there is no valid Cash Receipts after all validations above
                validateNoQualifyingUnpostedRecords(NO_SELECTION_UNPOSTED_ERROR_MESSAGE);

                if (!sourceRecords.isEmpty()) {
                    processUnpostCashReceipt();
                    processPostResult();
                }
                dispatcher.isPreCheck = false;
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

    private void queryCashReceipts() {
        //=================================================
        //build dynamic SOQL query using SOQLBuilder class
        //=================================================
        //Select fields
        List<String> fieldsToQuery = new List<String> {
            'Id',
            'Name',
            'Status__c',
            'Accounting_Period__c',
            'Accounting_Period__r.Name',
            'Accounting_Period__r.Status__c',
            'Number_of_Billing_Cash_Receipts__c',
            'Bank_Reconciliation__c',
            'Bank_Reconciliation__r.Name',
            'Bank_Deposit__c',
            'Bank_Deposit__r.Name',
            'Check_Number__c',
            'Amount__c',
            'Receipt_Date__c',
            'Bank_Account__c',
            'Account__c',
            'Ledger__c',
            'Ledger__r.Name',
            'Ledger__r.Type__c',
            'Ledger__r.Tax_Settings__c',
            'Ledger__r.Accounting_Method__c',
            'Cash_Flow_Category__c',
            'Payment_Reference__c',
            'Project__c',
            'Project_Task__c',
            'Credit_GL_Account__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c',
            'Product__c',
            'Void__c'
        };

        String subQueryCondition = 'Status__c = \'' + PaymentActivityHelper.ERROR_STATUS 
        + '\' OR Status__c = \''  + PaymentActivityHelper.DECLINED_STATUS + 
        + '\' OR Status__c = \'' + PaymentActivityHelper.VOID_STATUS + '\'';

        if (IS_MULTI_CURRENCY_ENABLED) {
            fieldsToQuery.add('CurrencyIsoCode');
            fieldsToQuery.add('Currency_Conversion_Rate__c');
        }
        

        //Add query condition
        String queryCondition = 'Id IN :processedRecordIds FOR UPDATE';

        String subQueryRelationshipName = PACKAGE_QUALIFIER + 'Payment_Activities__r';
        List<String> subQueryFields = new List<String>{
            'Id',
            'Status__c'
        };


        SOQLBuilder theQuery = new SOQLBuilder(Cash_Receipt__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(fieldsToQuery)
            .setCondition(queryCondition)
            .subselectQuery(subQueryRelationshipName, true)
            .setEnforceFLS(true)
            .selectFields(new List<String>(subQueryFields))
            .setCondition(subQueryCondition)
            .setLimit(1);/*nested query limit*/   
        //Call DML operation
        sourceRecords = Database.query(theQuery.toSOQL());
    }

    public void validateBeforePost(List<SObject> processedRecords, Boolean fullStatistics) {
        dispatcher.clearResultsMap();
        dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.POST);
        Map<Id, Cash_Receipt__c> cashReceiptsMap =
            new Map<Id, Cash_Receipt__c>((List<Cash_Receipt__c>) processedRecords);
        this.processedRecordIds = new List<Id>(cashReceiptsMap.keySet());
        //Initial query for Cash Receipts
        queryCashReceipts();
        getGLAccountDefaults();
        validateUnappliedCashGLAccount(fullStatistics);
        //weed out unsuitable Cash Receipts
        validateNotPosted(fullStatistics);
        validateNotVoid(fullStatistics);
        validateStatusApproved(fullStatistics);
        validateRelatedPaymentAcitivityStatus(fullStatistics);
        validateAccountingPeriodIsOpen(fullStatistics);
        validateLedgerType(fullStatistics, false);
        validateCashFlowCategoryIsDefined(fullStatistics);
        validateCashFlowStatementConformity(fullStatistics);
        //add positive results
        processPostResult();
    }

    public void validateBeforeUnpost(List<SObject> processedRecords, Boolean fullStatistics) {
        dispatcher.clearResultsMap();
        dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.UNPOST);
        Map<Id, Cash_Receipt__c> cashReceiptsMap =
            new Map<Id, Cash_Receipt__c>((List<Cash_Receipt__c>) processedRecords);
        this.processedRecordIds = new List<Id>(cashReceiptsMap.keySet());
        //Initial query for Cash Receipts
        queryCashReceipts();
        //weed out the unsuitable Cash Receipts
        validateIsPosted(fullStatistics);
        validateAccountingPeriodIsOpen(fullStatistics);
        validateBillingCashReceiptsNotExist(fullStatistics);
        validateNotAssociatedWithBankReconciliation(fullStatistics);
        validateNotAssociatedWithBankDeposit(fullStatistics);
        //add positive results
        processPostResult();
    }

    private void validateRelatedPaymentAcitivityStatus(Boolean fullStatistics) {
        List<Cash_Receipt__c> validCashReceipts = new List<Cash_Receipt__c>();
        for (Cash_Receipt__c cr : (List<Cash_Receipt__c>) sourceRecords) {
            if(cr.Payment_Activities__r.size() > 0){
                dispatcher.addPostErrorResult(
                    cr,
                    new PostResult.PostErrorResult(
                        cr,
                        PostResult.StatusCode.ERR_CASHRECEIPT_STATUS_VOID_ERROR_DECLINED,
                        ERR_CASHRECEIPT_STATUS_VOID_ERROR_DECLINED
                    )
                );
            }else {
                validCashReceipts.add(cr);
            }
        }

        if (!fullStatistics) {
            sourceRecords = validCashReceipts;
        }
    }

    private void validateUnappliedCashGLAccount(Boolean fullStatistics) {
        List<SObject> validRecords = new List<SObject>();
        for (Cash_Receipt__c cr : (List<Cash_Receipt__c>) sourceRecords) {
            Boolean isValid = true;
            if ((LedgerHandler.getInstanceWithoutSharing().isAccrualAndCashLedger(cr.Ledger__c)
                || LedgerHandler.getInstanceWithoutSharing().isAccrualLedger(cr.Ledger__c))
                && (!glAccountDefaults.containsKey(cr.Ledger__c) ||
                (glAccountDefaults.containsKey(cr.Ledger__c)
                    && !glAccountDefaults.get(cr.Ledger__c).containsKey(GLAccountDefaultsHandler.UNAPPLIED_CASH_GL_ACCOUNT)))) {
                dispatcher.addPostErrorResult(
                    cr,
                    new PostResult.PostErrorResult(
                        cr,
                        PostResult.StatusCode.NO_UNAPPLIED_CASH_CONTROL_ACCOUNT_DEFINED,
                        NO_UNAPPLIED_CASH_GL_ACCOUNT_MESSAGE
                    )
                );
                isValid = false;
            }
            if ((LedgerHandler.getInstanceWithoutSharing().isAccrualAndCashLedger(cr.Ledger__c)
                && noUnappliedGLAccountForLedger(LedgerHandler.getInstanceWithoutSharing().getShadowLedgerByParent(cr.Ledger__c).Id))
                || (LedgerHandler.getInstanceWithoutSharing().isCashLedger(cr.Ledger__c) && cr.Credit_GL_Account__c == null
                && noUnappliedGLAccountForLedger(cr.Ledger__c))) {
                dispatcher.addPostErrorResult(
                    cr,
                    new PostResult.PostErrorResult(
                        cr,
                        PostResult.StatusCode.NO_UNAPPLIED_REVENUE_GL_ACCOUNT_DEFINED,
                        NO_UNAPPLIED_REVENUE_GL_ACCOUNT_MESSAGE
                    )
                );
                isValid = false;
            }
            if (isValid) {
                validRecords.add(cr);
            }
        }
        if (!fullStatistics) {
            sourceRecords = validRecords;
        }
    }

    private Boolean noUnappliedGLAccountForLedger(Id ledgerId) {
        return (!glAccountDefaults.containsKey(ledgerId) ||
            (glAccountDefaults.containsKey(ledgerId)
                && !glAccountDefaults.get(ledgerId).containsKey(GLAccountDefaultsHandler.UNAPPLIED_REVENUE_GL_ACCOUNT)));
    }

    private void validateNotAssociatedWithBankReconciliation(Boolean fullStatistics) {
        List<Cash_Receipt__c> validCashReceipts = new List<Cash_Receipt__c>();
        for (Cash_Receipt__c cr : (List<Cash_Receipt__c>) sourceRecords) {
            if (cr.Bank_Reconciliation__c != NULL) {
                dispatcher.addPostErrorResult(
                    cr,
                    new PostResult.PostErrorResult(
                        cr.Bank_Reconciliation__r,
                        PostResult.StatusCode.CLEARED_BANK_RECONCILIATION,
                        UNPOST_CLEARED_ERROR_MESSAGE
                    )
                );
            }
            else {
                validCashReceipts.add(cr);
            }
        }
        if (!fullStatistics) {
            sourceRecords = validCashReceipts;
        }
    }

    private void validateNotVoid(Boolean fullStatistics) {
        List<Cash_Receipt__c> validCashReceipts = new List<Cash_Receipt__c>();
        for (Cash_Receipt__c cr : (List<Cash_Receipt__c>) sourceRecords) {
            if (cr.Void__c) {
                dispatcher.addPostErrorResult(
                    cr,
                    new PostResult.PostErrorResult(
                        cr,
                        PostResult.StatusCode.ERR_CR_POSTED_VOID,
                        ERR_CR_POSTED_VOID
                    )
                );
            }
            else {
                validCashReceipts.add(cr);
            }
        }
        if (!fullStatistics) {
            sourceRecords = validCashReceipts;
        }
    }

    private void validateBillingCashReceiptsNotExist(Boolean fullStatistics) {
        List<Cash_Receipt__c> validCashReceipts = new List<Cash_Receipt__c>();
        for (Cash_Receipt__c cr : (List<Cash_Receipt__c>) sourceRecords) {
            if (cr.Number_of_Billing_Cash_Receipts__c > 0) {
                dispatcher.addPostErrorResult(
                    cr,
                    new PostResult.PostErrorResult(
                        cr,
                        PostResult.StatusCode.BILLING_CASH_RECEIPTS_EXIST,
                        UNPOSTED_BILLING_CASH_RECEIPTS_ERROR_MESSAGE
                    )
                );
            }
            else {
                validCashReceipts.add(cr);
            }
        }
        if (!fullStatistics) {
            sourceRecords = validCashReceipts;
        }
    }

    private void validateNotAssociatedWithBankDeposit(Boolean fullStatistics) {
        List<Cash_Receipt__c> validCashReceipts = new List<Cash_Receipt__c>();
        for (Cash_Receipt__c cr : (List<Cash_Receipt__c>) sourceRecords) {
            if (cr.Bank_Deposit__c != NULL) {
                dispatcher.addPostErrorResult(
                    cr,
                    new PostResult.PostErrorResult(
                        cr.Bank_Deposit__r,
                        PostResult.StatusCode.CLEARED_BANK_DEPOSIT,
                        UNPOST_DEPOSIT_ERROR_MESSAGE
                    )
                );
            }
            else {
                validCashReceipts.add(cr);
            }
        }
        if (!fullStatistics) {
            sourceRecords = validCashReceipts;
        }
    }

    private void processPostCashReceipts() {
        main = getAccountingSettings();
        Savepoint sp = Database.setSavepoint();
        try {
            // delete any and all transactions associated with the source document
            // before another set of transactions are created and the status is changed
            TransactionActions.deleteTransactions(TransactionActions.queryTransactions(sourceRecords));
            //=========================================================================================

            List<Transaction__c> transList = createTransactions();
            for (Cash_Receipt__c cashReceipt : (List<Cash_Receipt__c>) sourceRecords) {
                cashReceipt.Status__c = DEFAULT_POSTING_STATUS_POSTED;
            }

            //convert generic collection to the collection with specific SObjectType
            List<Cash_Receipt__c> sourceRecordsToUpdate = new List<Cash_Receipt__c>(
                (List<Cash_Receipt__c>) sourceRecords
            );

            TriggerObserver.getInstance().unlockField(Cash_Receipt__c.Status__c);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(sourceRecordsToUpdate, new List<String>{'Status__c'});
            TriggerObserver.purgeUnlockedFields(Cash_Receipt__c.Status__c);

            sourceRecords = DomainUtils.getCashReceiptByIdForUpdate(
                new Map<Id, SObject>(sourceRecords).keySet()
            ); 
            validatePostStatusSet();

            CubeBuilder.isEnabledCashFlowStatement = main.Enable_Cash_Flow_Statement__c;
            TransactionActions.createTransactions(transList);
            CubeBuilder.isEnabledCashFlowStatement = false;
        }
        catch (Exception ex) {
            Database.rollback(sp);
            throw ex;
        }
    }

    private void processUnpostCashReceipt() {

        Savepoint sp = Database.setSavepoint();
        try {
            TransactionActions.deleteTransactions(TransactionActions.queryTransactions(sourceRecords));

            List<Cash_Receipt__c> updateCashReceiptList = new List<Cash_Receipt__c>();
            String defaultPostingStatus = FinancialSuiteUtils.getDefaultPostingStatus(Cash_Receipt__c.Status__c);

            for (Cash_Receipt__c cashReceipt : (List<Cash_Receipt__c>) sourceRecords) {
                if ((isLDVBatchContext && (cashReceipt.Status__c == DEFAULT_POSTING_STATUS_UNPOSTING_IN_PROGRESS
                    || cashReceipt.Status__c == DEFAULT_POSTING_STATUS_POSTED))
                    || (!isLDVBatchContext && cashReceipt.Status__c == DEFAULT_POSTING_STATUS_POSTED)) {
                    cashReceipt.Status__c = defaultPostingStatus;
                    updateCashReceiptList.add(cashReceipt);
                    if (cashReceipt.Credit_GL_Account__c == NULL) {
                        TriggerObserver.getInstance().unlockField(Cash_Receipt__c.Credit_GL_Account__c);
                    }
                }
            }

            TriggerObserver.getInstance().unlockField(Cash_Receipt__c.Status__c);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(updateCashReceiptList, new List<String>{'Status__c'});
            TriggerObserver.purgeUnlockedFields(new Set<Schema.SObjectField>{Cash_Receipt__c.Status__c, Cash_Receipt__c.Credit_GL_Account__c});
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
        for (Cash_Receipt__c cashReceipt : (List<Cash_Receipt__c>) sourceRecords) {
            //===========================================================
            //==================== DEBIT LINE ===========================
            //===========================================================
            Transaction__c trans = createTransaction(cashReceipt);
            //MC part ==============================================================================================
            if (isMultiCurrencyAndDifferentCurrency(cashReceipt.Id, trans.Ledger__c)) {
                trans.Foreign_Amount__c = cashReceipt.Amount__c;
                trans.Foreign_Currency__c = (String) cashReceipt.get('CurrencyIsoCode');
                trans.Currency_Conversion_Rate__c = cashReceipt.Currency_Conversion_Rate__c;
                trans.Amount__c =
                    (cashReceipt.Amount__c / cashReceipt.Currency_Conversion_Rate__c)
                        .setScale(2, System.RoundingMode.HALF_UP);
            }
            else {
                trans.Amount__c = cashReceipt.Amount__c;
            }
            //======================================================================================================
            trans.GL_Account__c = cashReceipt.Bank_Account__c;
            transList.add(trans);

            //===========================================================
            //==================== CREDIT LINE ===========================
            //===========================================================

            trans = createTransaction(cashReceipt);
            //MC part ==============================================================================================
            if (isMultiCurrencyAndDifferentCurrency(cashReceipt.Id, trans.Ledger__c)) {
                trans.Foreign_Amount__c = cashReceipt.Amount__c * -1;
                trans.Foreign_Currency__c = (String) cashReceipt.get('CurrencyIsoCode');
                trans.Currency_Conversion_Rate__c = cashReceipt.Currency_Conversion_Rate__c;
                trans.Amount__c =
                    (cashReceipt.Amount__c / cashReceipt.Currency_Conversion_Rate__c)
                        .setScale(2, System.RoundingMode.HALF_UP) * -1;
            }
            else {
                trans.Amount__c = cashReceipt.Amount__c * -1;
            }
            //======================================================================================================
            trans.GL_Account__c = getCreditGLAccount(cashReceipt);

            transList.add(trans);

            if (cashReceipt.Ledger__r.Accounting_Method__c != null && LedgerHandler.getInstanceWithoutSharing().isAccrualAndCashLedger(cashReceipt.Ledger__c)) {
                transList.addAll(getShadowLedgerTransaction(cashReceipt));
            }
        }

        return transList;
    }

    private Id getCreditGLAccount(Cash_Receipt__c cashReceipt) {
        Id glAccountId;
        if (cashReceipt.Ledger__r.Accounting_Method__c == null
            || LedgerHandler.getInstanceWithoutSharing().isAccrualLedger(cashReceipt.Ledger__c)
            || LedgerHandler.getInstanceWithoutSharing().isAccrualAndCashLedger(cashReceipt.Ledger__c)) {
            glAccountId = (cashReceipt.Credit_GL_Account__c != null)
                ? cashReceipt.Credit_GL_Account__c
                : glAccountDefaults.get(cashReceipt.Ledger__c).get(GLAccountDefaultsHandler.UNAPPLIED_CASH_GL_ACCOUNT).GL_Account__c;
        } else if (LedgerHandler.getInstanceWithoutSharing().isCashLedger(cashReceipt.Ledger__c)) {
            if (String.isBlank(cashReceipt.Credit_GL_Account__c)
                    && String.isBlank(glAccountDefaults.get(cashReceipt.Ledger__c)?.get(GLAccountDefaultsHandler.UNAPPLIED_REVENUE_GL_ACCOUNT)?.GL_Account__c)) {
                throw new PostHandlerException(Label.ERR_CR_NO_UNAPPLIED_REVENUE_GL_ACCOUNT);
            }
            glAccountId = cashReceipt.Credit_GL_Account__c != null
                ? cashReceipt.Credit_GL_Account__c
                : glAccountDefaults.get(cashReceipt.Ledger__c)?.get(GLAccountDefaultsHandler.UNAPPLIED_REVENUE_GL_ACCOUNT)?.GL_Account__c;
        }

        return glAccountId;
    }

    private List<Transaction__c> getShadowLedgerTransaction(Cash_Receipt__c cashReceipt) {
        List<Transaction__c> shadowTrans = new List<Transaction__c>();
        Transaction__c trans = createTransaction(cashReceipt);
        trans.Ledger__c = LedgerHandler.getInstanceWithoutSharing().getShadowLedgerByParent(cashReceipt.Ledger__c).Id;
        if (isMultiCurrencyAndDifferentCurrency(cashReceipt.Id, trans.Ledger__c)) {
            trans.Foreign_Amount__c = cashReceipt.Amount__c;
            trans.Foreign_Currency__c = (String) cashReceipt.get('CurrencyIsoCode');
            trans.Currency_Conversion_Rate__c = cashReceipt.Currency_Conversion_Rate__c;
            trans.Amount__c =
                (cashReceipt.Amount__c / cashReceipt.Currency_Conversion_Rate__c)
                    .setScale(2, System.RoundingMode.HALF_UP);
        }
        else {
            trans.Amount__c = cashReceipt.Amount__c;
        }

        trans.GL_Account__c = cashReceipt.Bank_Account__c;
        shadowTrans.add(trans);

        trans = createTransaction(cashReceipt);
        trans.Ledger__c = LedgerHandler.getInstanceWithoutSharing().getShadowLedgerByParent(cashReceipt.Ledger__c).Id;
        if (isMultiCurrencyAndDifferentCurrency(cashReceipt.Id, trans.Ledger__c)) {
            trans.Foreign_Amount__c = cashReceipt.Amount__c * -1;
            trans.Foreign_Currency__c = (String) cashReceipt.get('CurrencyIsoCode');
            trans.Currency_Conversion_Rate__c = cashReceipt.Currency_Conversion_Rate__c;
            trans.Amount__c =
                (cashReceipt.Amount__c / cashReceipt.Currency_Conversion_Rate__c)
                    .setScale(2, System.RoundingMode.HALF_UP) * -1;
        }
        else {
            trans.Amount__c = cashReceipt.Amount__c * -1;
        }
        if (String.isBlank(glAccountDefaults.get(trans.Ledger__c)?.get(GLAccountDefaultsHandler.UNAPPLIED_REVENUE_GL_ACCOUNT)?.GL_Account__c)) {
            throw new PostHandlerException(Label.ERR_CR_NO_UNAPPLIED_REVENUE_GL_ACCOUNT);
        }
        trans.GL_Account__c = glAccountDefaults.get(trans.Ledger__c)?.get(GLAccountDefaultsHandler.UNAPPLIED_REVENUE_GL_ACCOUNT)?.GL_Account__c;
        shadowTrans.add(trans);
        return shadowTrans;
    }

    private Transaction__c createTransaction(Sobject obj) {
        Cash_Receipt__c cashReceipt = (Cash_Receipt__c) obj;
        Transaction__c trans = new Transaction__c();
        trans.Ledger__c = cashReceipt.Ledger__c != NULL ? cashReceipt.Ledger__c : LedgerHandler.getLegacyDefaultLedgerId();
        trans.Cash_Receipt__c = cashReceipt.Id;
        trans.Accounting_Period__c = cashReceipt.Accounting_Period__c;
        trans.Date__c = cashReceipt.Receipt_Date__c;
        trans.Account__c = cashReceipt.Account__c;
        trans.Cash_Flow_Category__c = cashReceipt.Cash_Flow_Category__c;
        trans.Project__c = cashReceipt.Project__c;
        trans.Project_Task__c = cashReceipt.Project_Task__c;
        trans.Note__c = (cashReceipt.Check_Number__c == NULL ? cashReceipt.Payment_Reference__c : String.valueOf(cashReceipt.Check_Number__c));
        trans.GL_Account_Variable_1__c = cashReceipt.GL_Account_Variable_1__c;
        trans.GL_Account_Variable_2__c = cashReceipt.GL_Account_Variable_2__c;
        trans.GL_Account_Variable_3__c = cashReceipt.GL_Account_Variable_3__c;
        trans.GL_Account_Variable_4__c = cashReceipt.GL_Account_Variable_4__c;
        trans.Product__c = cashReceipt.Product__c;

        return trans; 
    }

    //Accessible and FLS checks are performed in Visualforce page for the records retrieved from this method.
    public List<Transaction__c> getForecastedTransactions() {

        if (dispatcher.getExecutionContext() == PostResultDispatcher.ExecutionContext.POST) {
            List<Transaction__c> transactionsList = createTransactions();
            if (IS_MULTI_CURRENCY_ENABLED) {
                transactionsList = setLedgerIsoCodeToTransactions(transactionsList);
            }
            return transactionsList;
        }
        else {
            List<String> queryFields = new List<String>{
                'Id',
                'Name',
                'Ledger__c',
                'GL_Account__c',
                'Amount__c',
                'Product__c',
                'Project__c',
                'Project_Task__c',
                'GL_Account_Variable_1__c',
                'GL_Account_Variable_2__c',
                'GL_Account_Variable_3__c',
                'GL_Account_Variable_4__c'
            };

            if (IS_MULTI_CURRENCY_ENABLED) {
                queryFields.add('Foreign_Amount__c');
                queryFields.add('Foreign_Currency__c');
                queryFields.add('Currency_Conversion_Rate__c');
            }

            String queryCondition = 'Cash_Receipt__c IN :sourceRecords';

            SOQLBuilder theQuery = new SOQLBuilder(Transaction__c.SObjectType);
            theQuery
                .setEnforceFLS(false)
                .selectFields(queryFields)
                .setCondition(queryCondition);

            return (List<Transaction__c>) Database.query(theQuery.toSOQL());
        }

    }

}