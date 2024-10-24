public with sharing class AccountPayablePostHandler extends AbstractPostHandler {

    @TestVisible
    private static final String PAYABLE_LINE_COUNT_LIMIT_EXCEEDED_ERROR_MESSAGE = Label.ERR_PAYABLE_LINE_COUNT_LIMIT_EXCEEDED;
    @TestVisible
    private static final String NO_CONTROL_ACCOUNT = Label.ERR_NO_CONTROL_ACCOUNT_FOR_PAYABLE;
    @TestVisible
    private static final String NO_INVOICE_LINES_ERROR = Label.ERR_NO_INVOICE_LINES;

    public static final String NO_SELECTION_UNPOST_ERROR = Label.ERR_NO_SELECTION_UNPOST_FOR_PAYABLE;
    public static final String HEADER_LEVEL_POSTING_PREFIX = 'HP-';
    public static final Integer PAYABLE_LINE_COUNT_NO_PRODUCT_COSTING_LIMIT = 500;
    public static final Integer PAYABLE_LINE_COUNT_PRODUCT_COSTING_LIMIT = 250;
    public static final Integer UNPOST_PAYABLE_LINE_COUNT_LIMIT = 1000;
    private static AbstractTaxService service = AccountingSettingsHandler.isHeaderLevelPost()
        ? (AbstractTaxService) new NativeTaxHeaderLevel() : (AbstractTaxService) new NativeTaxLineLevel();

    // =========== LDV Support ===========================
    public override List<PostResult> post(List<LDVPostInput> sourceItems) {
        List<Account_Payable_Line__c> processedLines = new List<Account_Payable_Line__c>();
        Map<Id, LDVPostInput> sourceMap = new Map<Id, LDVPostInput>();

        for (LDVPostInput item : sourceItems) {
            processedLines.addAll((List<Account_Payable_Line__c>)item.lines);
            sourceMap.put(item.id, item);
        }

        Map<Id, PostResult> postResults = new Map<Id, PostResult>();

        this.processedRecordIds = new List<Id>(sourceMap.keySet());
        dispatcher.clearResultsMap();
        dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.POST);
        queryPayables();
        this.sourceRecords = filterRecordsByAcctMethods(
                this.sourceRecords,
                new Set<String>{LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH, LedgerActions.ACCOUNTING_METHOD_ACCRUAL}
        );
        getGLAccountDefaults();

        if (validateAPControlGLAccount()) {
            validateNotPosted(true);
            validateAccountingPeriodIsOpen(true);
            validateLedgerType(true, true);
            validateLedgerTaxSetting(true);
            validateNoQualifyingPostedRecords();
            if (!sourceRecords.isEmpty()) {
                sourceRecordLines = processedLines;
                Map<Id, Account_Payable_Line__c> processedLinesMap;
                if (!IS_HEADER_LEVEL_POST) {
                    processedLinesMap = new Map<Id, Account_Payable_Line__c>((List<Account_Payable_Line__c>) sourceRecordLines);
                }
                for (Transaction__c tr : buildTransactions()) {
                    Id payId = IS_HEADER_LEVEL_POST ? tr.Account_Payable__c : processedLinesMap.get(tr.Account_Payable_Line__c).Account_Payable__c;
                    if (!postResults.containsKey(payId)) {
                        PostResult res = new PostResult(true, payId, '', sourceMap.get(payId).transactionGroup);
                        res.transactions.add(tr);
                        postResults.put(payId, res);
                    }
                    else {
                        postResults.get(payId).transactions.add(tr);
                    }

                }
            }
            processPostResult();
            ldvValidatePostResultMap(postResults);
        }

        return postResults.values();
    }

    public override List<PostResult> unpost(List<LDVPostInput> sourceItems) {
        List<Account_Payable_Line__c> processedLines = new List<Account_Payable_Line__c>();
        Map<Id, LDVPostInput> sourceMap = new Map<Id, LDVPostInput>();

        for (LDVPostInput item : sourceItems) {
            sourceMap.put(item.id, item);
            processedLines.addAll((List<Account_Payable_Line__c>)item.lines);
        }

        Map<Id, PostResult> postResults = new Map<Id, PostResult>();
        this.processedRecordIds = new List<Id>(sourceMap.keySet());
        if (!this.processedRecordIds.isEmpty()) {
            try {
                dispatcher.clearResultsMap();
                dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.UNPOST);

                queryPayables();
                this.sourceRecords = filterRecordsByAcctMethods(
                        this.sourceRecords,
                        new Set<String>{LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH, LedgerActions.ACCOUNTING_METHOD_ACCRUAL}
                );
                validateIsPostedByApproval(true);
                validateAccountingPeriodIsOpen(true);
                validateLedgerTaxSetting(true);
                validateNoQualifyingUnpostedRecords(NO_SELECTION_UNPOST_ERROR);

                if (!sourceRecords.isEmpty()) {
                    sourceRecordLines = processedLines;
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

            ldvGetPostResultMap(postResults, sourceMap);
        }
        return postResults.values();
    }

    public void processLDVPostPayableTransaction(List<PostResult> processedResults) {

        Savepoint sp;
        if(!Test.isRunningTest()) {
            sp = Database.setSavepoint();
        }

        try {
            List<Transaction__c> transList = new List<Transaction__c>();
            Map<Id, Account_Payable__c> needUpdateStatus = new Map<Id, Account_Payable__c>();
            Set<String> transactionKeys = new Set<String>();

            for (PostResult item : processedResults) {
                for (Transaction__c tr : item.transactions) {
                    TransactionKey tk = new TransactionKey(tr);
                    transactionKeys.add(tk.hashCode());
                    transList.add(tr);
                }
                if (item.transactionGroup.Line_Count__c == item.transactionGroup.Lines_Processed__c) {
                    needUpdateStatus.put(item.id, null);
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

            for (Account_Payable__c payable : (List<Account_Payable__c>) sourceRecords) {
                if (needUpdateStatus.containsKey(payable.Id)) {
                    payable.Status__c = DEFAULT_POSTING_STATUS_POSTED;
                    needUpdateStatus.put(payable.Id, payable);
                }
            }

            TriggerObserver.getInstance().unlockField(Account_Payable__c.Status__c);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(needUpdateStatus.values(), new List<String>{'Status__c'});
            TriggerObserver.purgeUnlockedFields(Account_Payable__c.Status__c);

            sourceRecords = DomainUtils.getBillingsByIdForUpdate(needUpdateStatus.keySet());
            validatePostStatusSet();

            TransactionActions.createTransactions(transList);
        }
        catch (Exception ex) {
            Database.rollback(sp);
            throw ex;
        }
    }

    public void processLDVUnpostPayableTransactions(List<PostResult> processedResults) {
        Map<Id, Account_Payable__c> needUpdateStatus = new Map<Id, Account_Payable__c>();
        for (PostResult item : processedResults) {
            if (item.transactionGroup.Line_Count__c == item.transactionGroup.Lines_Processed__c) {
                needUpdateStatus.put(item.id, null);
            }
        }

        Savepoint sp;
        if(!Test.isRunningTest()) {
            sp = Database.setSavepoint();
        }
        try {
            if (IS_HEADER_LEVEL_POST) {
                List<Account_Payable_Line__c> linesForDeleteTaxTransaction = new List<Account_Payable_Line__c>();
                Map<Id, Account_Payable__c> processedPayableMap = new Map<Id, Account_Payable__c>((List<Account_Payable__c>) sourceRecords);

                Set<String> transactionKeys = new Set<String>();
                for (Account_Payable_Line__c line : (List<Account_Payable_Line__c>) sourceRecordLines) {
                    TransactionKey tk = new TransactionKey(processedPayableMap.get(line.Account_Payable__c), line);
                    transactionKeys.add(tk.hashCode());
                    if (needUpdateStatus.containsKey(line.Account_Payable__c)) {
                        linesForDeleteTaxTransaction.add(line);
                    }
                }

                TransactionActions.deleteTransactions(getExistedTransactionByKeys(transactionKeys));
                if (!linesForDeleteTaxTransaction.isEmpty()) {
                    TransactionActions.deleteTransactions(TransactionActions.queryTransactions(
                        linesForDeleteTaxTransaction, true
                    ));
                }
            } else {
                TransactionActions.deleteTransactions(TransactionActions.queryTransactions(
                    sourceRecordLines, false
                ));
            }

            String defaultPostingStatus = FinancialSuiteUtils.getDefaultPostingStatus(Account_Payable__c.Status__c);

            for (Account_Payable__c pay : (List<Account_Payable__c>) this.sourceRecords) {
                if (needUpdateStatus.containsKey(pay.Id)) {
                    pay.Status__c = defaultPostingStatus;
                    pay.Date__c = pay.Date__c == null ? System.today() : pay.Date__c;
                    needUpdateStatus.put(pay.Id, pay);
                }
            }

            TriggerObserver.getInstance().unlockFields(new Set<SObjectField> {Account_Payable__c.Status__c});
            SFDCSecurityUtils.updateCheckCRUDAndFLS(needUpdateStatus.values(), new List<String>{'Status__c'});
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField> {Account_Payable__c.Status__c});
        }
        catch (Exception ex) {
            Database.rollback(sp);
            throw ex;
        }
    }
    //====================================================

    //Post method implementation for Payables ====================================================
    public override List<PostResult> post(List<SObject> processedRecords) {
        Map<Id, Account_Payable__c> payablesMap =
            new Map<Id, Account_Payable__c>((List<Account_Payable__c>) processedRecords);
        return post(new List<Id>(payablesMap.keySet()));
    }

    public override List<PostResult> post(List<String> processedRecordIds) {
        this.processedRecordIds = processedRecordIds;
        main = getAccountingSettings();
        if (!processedRecordIds.isEmpty()) {
            try {
                dispatcher.clearResultsMap();
                dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.POST);
                //Initial query for payables
                queryPayables();
                getGLAccountDefaults();
                if (validateAPControlGLAccount()) {
                    //weed out unsuitable payables
                    validateNotPosted(false);
                    validateStatusApproved(false);
                    validateAccountingPeriodIsOpen(false);
                    validateLedgerType(false, false);
                    validateLedgerTaxSetting(false);
                    validatePayableLinesExist(false);
                    validateNoQualifyingPostedRecords();

                    if (!sourceRecords.isEmpty()) {
                        //it's time to query Payable Lines
                        queryPayableLines();
                        //validate line count and if everything is OK => execute Posting business logic
                        if (validatePostPayableLinesLimit()) {
                            processPostAccountPayables();
                            processPostResult();
                        }
                    }
                }
                else {
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

        submitSuccessfulResultsToAvaVAT();
        return dispatcher.getPostResults();
    }

    //==============================================================================================
    //Unpost method implementation for Payables ====================================================
    public override List<PostResult> unpost(List<SObject> processedRecords) {
        Map<Id, Account_Payable__c> payablesMap =
            new Map<Id, Account_Payable__c>((List<Account_Payable__c>) processedRecords);
        return unpost(new List<Id>(payablesMap.keySet()));
    }

    public override List<PostResult> unpost(List<String> processedRecordIds) {
        this.processedRecordIds = processedRecordIds;

        if (!processedRecordIds.isEmpty()) {
            try {
                dispatcher.clearResultsMap();
                dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.UNPOST);
                queryPayables();
                validateIsPosted(false);
                validateAccountingPeriodIsOpen(false);
                validateNoQualifyingUnpostedRecords(NO_SELECTION_UNPOST_ERROR);

                if (!sourceRecords.isEmpty()) {
                    //it's time to query Payable Lines
                    queryPayableLines();
                    //validate line count and if everything is OK => execute UnPosting business logic
                    if (validateUnpostPayableLinesLimit()) {
                        processUnpostAccountPayables();
                        processPostResult();
                    }
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
        
        submitSuccessfulResultsToAvaVAT();
        return dispatcher.getPostResults();
    }

    //===================================================================================
    //====== Payable Post/Unpost specific utility and validation methods ================

    private void queryPayables() {
        sourceRecords = queryPayables(this.processedRecordIds);
    }
    public static List<SObject> queryPayables(List<Id> processedRecordIds) {
        //=================================================
        //build dynamic SOQL query using SOQLBuilder class
        //=================================================
        //Select fields
        List<String> fieldsToQuery = new List<String> {
            'Id',
            'Name',
            'Accounting_Period__c',
            'Accounting_Period__r.Name',
            'Accounting_Period__r.Status__c',
            'Ledger__c',
            'Ledger__r.Name',
            'Ledger__r.Type__c',
            'Ledger__r.Tax_Settings__c',
            'Ledger__r.Accounting_Method__c',
            'Status__c',
            'Payment_Status__c',
            'AP_Disbursement_Count__c',
            'Date__c',
            'Employee__c',
            'Type__c',
            'Vendor__c',
            'Payee_Reference__c'
        };
        //Add Multicurrency related fields
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            fieldsToQuery.addAll(new List<String>{'CurrencyIsoCode', 'Currency_Conversion_Rate__c'});
        }
        //Add subqueries
        List<String> subQueryRelationshipNames = new List<String>{
            GlobalVariables.PACKAGE_QUALIFIER + 'AP_Credit_Memos__r',
            GlobalVariables.PACKAGE_QUALIFIER + 'AP_Credit_Memos1__r'
        };
        //Add query condition
        String queryCondition = 'Id IN :processedRecordIds FOR UPDATE';
        //Final assembly of SOQL string
        String dynamicSOQL = SOQLBuilder.buildDynamicSoqlQuery(
            fieldsToQuery,
            subQueryRelationshipNames,
            Account_Payable__c.SObjectType,
            queryCondition,
            true,
            false
        );
        return Database.query(dynamicSOQL);
    }

    private void queryPayableLines() {
        //=================================================
        //build dynamic SOQL query using SOQLBuilder class
        //=================================================
        //Select fields
        List<String> fieldsToQuery = new List<String> {
            'Id',
            'Name',
            'Account_Payable__c',
            'Expense_GL_Account__c',
            'Account_Payable__c',
            'Combined_Tax_Rate__c',
            'GL_Account_Variable_4__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_1__c',
            'Invoice_Comment__c',
            'Internal_Comment__c',
            'Amount__c',
            'Sub_Total__c',
            'Ledger__c',
            'Account_Payable__r.Type__c',
            'Account_Payable__r.Status__c',
            'Account_Payable__r.Vendor__c',
            'Account_Payable__r.Employee__c',
            'Account_Payable__r.Contact__c',
            'Account_Payable__r.Payee_Reference__c',
            'Account_Payable__r.Accounting_Period__c',
            'Account_Payable__r.Date__c',
            'Account_Payable__r.Ledger__c',
            'Account_Payable__r.Reverse_Charge__c',
            'Date__c',
            'Quantity__c',
            'Tax_Group__c',
            'Tax_Group__r.External_Id2__c',
            'Project_Task__c',
            'Project__c',
            'Product__c',
            'Product__r.Inventory_Type__c',
            'Product__r.Inventory_Product__c',
            'Product__r.Unit_Cost__c',
            'Product__r.GL_Account_Variable_1__c',
            'Product__r.GL_Account_Variable_2__c',
            'Product__r.GL_Account_Variable_3__c',
            'Product__r.GL_Account_Variable_4__c',
            'Product__r.Inventory_GL_Account__c',
            'Tax_Inclusive__c',
            'Tax_Amount__c'
        };
        //Add query condition
        String queryCondition = 'Account_Payable__c IN :sourceRecords LIMIT 1001 FOR UPDATE';
        //Final assembly of SOQL string
        String dynamicSOQL = SOQLBuilder.buildDynamicSoqlQuery(
            fieldsToQuery,
            NULL,
            Account_Payable_Line__c.SObjectType,
            queryCondition,
            true,
            false
        );
        //Call DML operation
        sourceRecordLines = Database.query(dynamicSOQL);
    }

    public void validateBeforePost(List<SObject> processedRecords, Boolean fullStatistics) {
        dispatcher.clearResultsMap();
        dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.POST);
        Map<Id, Account_Payable__c> payablesMap =
            new Map<Id, Account_Payable__c>((List<Account_Payable__c>) processedRecords);
        this.processedRecordIds = new List<Id>(payablesMap.keySet());

        main = getAccountingSettings();
        //Initial query for payables
        queryPayables();
        getGLAccountDefaults();
        validateAPControlGLAccount();
        //weed out unsuitable payables
        validateNotPosted(fullStatistics);
        validateStatusApproved(fullStatistics);
        validateAccountingPeriodIsOpen(fullStatistics);
        validateLedgerType(fullStatistics, false);
        validateLedgerTaxSetting(fullStatistics);
        validatePayableLinesExist(fullStatistics);
        if (!this.isLDVBatchContext && !sourceRecords.isEmpty()) {
            //it's time to query Payable Lines
            queryPayableLines();
            //validate line count
            validatePostPayableLinesLimit();
        }
        //add positive results
        processPostResult();
    }

    public void validateBeforeUnpost(List<SObject> processedRecords, Boolean fullStatistics) {
        dispatcher.clearResultsMap();
        dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.UNPOST);
        Map<Id, Account_Payable__c> payablesMap =
            new Map<Id, Account_Payable__c>((List<Account_Payable__c>) processedRecords);
        this.processedRecordIds = new List<Id>(payablesMap.keySet());
        queryPayables();
        validateIsPosted(fullStatistics);
        validateAccountingPeriodIsOpen(fullStatistics);

        if (!this.isLDVBatchContext && !sourceRecords.isEmpty()) {
            //it's time to query Payable Lines
            queryPayableLines();
            //validate line count
            validateUnpostPayableLinesLimit();
        }
        //add positive results
        processPostResult();
    }

    private Boolean validateAPControlGLAccount() {
        return validateAPControlGLAccount(this.sourceRecords, this.glAccountDefaults, this.dispatcher);
    }

    public static Boolean validateAPControlGLAccount(List<SObject> sourceRecords, Map<Id, Map<String, GL_Account_Default__c>> glAccountDefaults, PostResultDispatcher dispatcher) {
        Boolean isValid = true;
        for (SObject payable : sourceRecords) {
            if (!glAccountDefaults.containsKey(((Account_Payable__c) payable).Ledger__c) ||
                (glAccountDefaults.containsKey(((Account_Payable__c) payable).Ledger__c)
                && glAccountDefaults.get(((Account_Payable__c) payable).Ledger__c)?.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT) == null)) {
                dispatcher.addPostErrorResult(
                    payable,
                    new PostResult.PostErrorResult(
                        payable,
                        PostResult.StatusCode.NO_CONTROL_AP_ACCOUNT_DEFINED,
                        NO_CONTROL_ACCOUNT
                    )
                );
                isValid = false;
            }
        }
        return isValid;
    }

    private void validatePayableLinesExist(Boolean fullStatistics) {
        this.sourceRecords = validatePayableLinesExist(this.sourceRecords, this.dispatcher, fullStatistics);
    }

    public static List<SObject> validatePayableLinesExist(List<SObject> sourceRecords, PostResultDispatcher dispatcher, Boolean fullStatistics) {
        Map<Id, Account_Payable__c> preSelectedPayables =
            new Map<Id, Account_Payable__c>((List<Account_Payable__c>) sourceRecords);

        // CRUD and FLS already has been checked at this point. No need to check again.
        Set<Id> parentIdsWithLines = DomainUtils.parentIdsWithLines(
                String.valueOf(Account_Payable_Line__c.getSObjectType()),
                String.valueOf(Account_Payable_Line__c.Account_Payable__c),
                preSelectedPayables.keySet()
        );
        for (Account_Payable__c payable : new List<Account_Payable__c>(preSelectedPayables.values())) {

            if (!parentIdsWithLines.contains(payable.Id)) {
                preSelectedPayables.remove(payable.Id);
                dispatcher.addPostErrorResult(
                    payable,
                    new PostResult.PostErrorResult(
                        payable,
                        PostResult.StatusCode.NO_LINES,
                        NO_INVOICE_LINES_ERROR
                    )
                );
            }
        }
        //the rest of Payables will have all fields selected in the initial SOQL query
        if (!fullStatistics) {
            sourceRecords = preSelectedPayables.values();
        }

        return sourceRecords;
    }

    private Boolean validatePostPayableLinesLimit() {
        Integer lineWithPC = 0;

        for (Account_Payable_Line__c payableLine : (List<Account_Payable_Line__c>) sourceRecordLines) {
            if (isInventoryCostLine(payableLine)) {
                lineWithPC++;
            }
        }

        Integer currentLineLimit =
            (lineWithPC > 0)
                ? PAYABLE_LINE_COUNT_PRODUCT_COSTING_LIMIT
                : PAYABLE_LINE_COUNT_NO_PRODUCT_COSTING_LIMIT;

        Integer lineCount = sourceRecordLines.size();

        if (lineCount > currentLineLimit) {
            for (Account_Payable__c payable : (List<Account_Payable__c>) sourceRecords) {
                dispatcher.addPostErrorResult(
                    payable,
                    new PostResult.PostErrorResult(
                        payable,
                        PostResult.StatusCode.LINE_COUNT_LIMIT_EXCEEDED,
                        String.format(
                            PAYABLE_LINE_COUNT_LIMIT_EXCEEDED_ERROR_MESSAGE,
                            new List<String>{String.valueOf(currentLineLimit)}
                        )
                    )
                );
            }
            return false;
        }
        else {
            return true;
        }
    }

    private Boolean validateUnpostPayableLinesLimit() {
        if (this.sourceRecordLines.size() > UNPOST_PAYABLE_LINE_COUNT_LIMIT) {
            for (SObject payable : sourceRecords) {
                dispatcher.addPostErrorResult(
                    payable,
                    new PostResult.PostErrorResult(
                        payable,
                        PostResult.StatusCode.LINE_COUNT_LIMIT_EXCEEDED,
                        String.format(
                            PAYABLE_LINE_COUNT_LIMIT_EXCEEDED_ERROR_MESSAGE,
                            new List<String>{String.valueOf(UNPOST_PAYABLE_LINE_COUNT_LIMIT)}
                        )
                    )
                );
            }
            return false;
        }
        else {
            return true;
        }
    }

    private void processPostAccountPayables() {
        Savepoint sp = Database.setSavepoint();
        try {
            // delete any and all transactions associated with the source document
            // before another set of transactions are created and the status is changed
            TransactionActions.deleteTransactions(TransactionActions.queryTransactions(
                sourceRecordLines, IS_HEADER_LEVEL_POST
            ));
            //=========================================================================================

            List<Transaction__c> transList = buildTransactions();
            for (Account_Payable__c invoice : (List<Account_Payable__c>) sourceRecords) {
                invoice.Status__c = DEFAULT_POSTING_STATUS_POSTED;
            }
            TriggerObserver.getInstance().unlockField(Account_Payable__c.Status__c);
            //convert generic collection to the collection with specific SObjectType
            List<Account_Payable__c> sourceRecordsToUpdate = new List<Account_Payable__c>(
                (List<Account_Payable__c>) sourceRecords
            );
            SFDCSecurityUtils.updateCheckCRUDAndFLS(sourceRecordsToUpdate, new List<String>{'Status__c'});
            TriggerObserver.purgeUnlockedFields(Account_Payable__c.Status__c);

            sourceRecords = DomainUtils.getAccountPayablesByIdForUpdate(
                new Map<Id, SObject>(sourceRecords).keySet()
            );
            validatePostStatusSet();

            TransactionActions.createTransactions(transList);
        }
        catch (Exception ex) {
            Database.rollback(sp);
            throw ex;
        }
    }

    private void processUnpostAccountPayables() {
        List<Account_Payable__c> updateAccountPayables = new List<Account_Payable__c>();

        Savepoint sp = Database.setSavepoint();
        try {
            String defaultPostingStatus = FinancialSuiteUtils.getDefaultPostingStatus(Account_Payable__c.Status__c);

            for (Account_Payable__c ap :  (List<Account_Payable__c>) sourceRecords) {
                if (ap.Status__c == DEFAULT_POSTING_STATUS_POSTED) {
                    ap.Status__c = defaultPostingStatus;
                    // Issue date field required as of release 3.0.2
                    // This ensures for any records to be unposted the issue date is populated if NULL
                    ap.Date__c = ap.Date__c == NULL ? System.today() : ap.Date__c;
                    updateAccountPayables.add(ap);
                }
            }

            TransactionActions.deleteTransactions(TransactionActions.queryTransactions(
                sourceRecordLines, true
            ));

            TriggerObserver.getInstance().unlockField(Account_Payable__c.Status__c);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(updateAccountPayables, new List<String>{'Status__c', 'Date__c'});
            TriggerObserver.purgeUnlockedFields(Account_Payable__c.Status__c);
        }
        catch (Exception ex) {
            Database.rollback(sp);
            throw ex;
        }
    }

    private List<Transaction__c> buildTransactions() {
        List<Transaction__c> result = new List<Transaction__c>();
        if (IS_HEADER_LEVEL_POST) {
            result = createTransactionsInHLPMode();
        }
        else {
            result = createTransactionsInLLPMode();
        }
        return result;
    }

    private List<Transaction__c> createTransactionsInHLPMode() {
        //If MC is enabled ==================
        getCurrencyInformation();
        //===================================
        List<Transaction__c> transList = new List<Transaction__c>();
        Map<Id, Transaction__c> payableIdToCreditTransaction = new Map<Id, Transaction__c>();
        Map<String, Transaction__c> debitTransactionsByKey = new Map<String, Transaction__c>();
        Map<String, Transaction__c> taxTransactionsByKey = new Map<String, Transaction__c>();

        Map<Id, Tax_Group__c> taxGroupMap = TaxGroupHandler.getTaxGroupsBySObject(sourceRecordLines);

        for (Account_Payable_Line__c invoiceLine : (List<Account_Payable_Line__c>) sourceRecordLines) {
            if (LedgerHandler.getInstanceWithoutSharing().isCashLedger(invoiceLine.Ledger__c)) {
                continue;
            }
            //===========================================================
            //==================== DEBIT LINE ===========================
            //===========================================================
            Transaction__c pt = createTransaction(invoiceLine);
            pt.GL_Account__c = invoiceLine.Expense_GL_Account__c;
            processDebitTransactionAmount(invoiceLine, pt);

            pt.Units__c = invoiceLine.Quantity__c == NULL ? 1 : invoiceLine.Quantity__c;

            populateTransactionMap(pt, debitTransactionsByKey, false);

            //=======================================================================================================
            //==================== CREDIT LINE (Only one Transaction to the AP Control GL Account) ==================
            //=======================================================================================================

            if (!payableIdToCreditTransaction.containsKey(invoiceLine.Account_Payable__c)) {
                Transaction__c creditTransaction = updateCreditTransaction(createTransaction(invoiceLine), invoiceLine);
                processCreditTransactionAmount(invoiceLine, creditTransaction);
                payableIdToCreditTransaction.put(invoiceLine.Account_Payable__c, creditTransaction);
            }
            else {
                Transaction__c creditTransaction = payableIdToCreditTransaction.get(invoiceLine.Account_Payable__c);
                processCreditTransactionAmount(invoiceLine, creditTransaction);
            }

            if (invoiceLine.Tax_Group__c != NULL && taxGroupMap.containsKey(invoiceLine.Tax_Group__c)) {
                processTaxTransaction(invoiceLine, taxTransactionsByKey, payableIdToCreditTransaction, taxGroupMap.get(invoiceLine.Tax_Group__c));
            }

        }
        transList.addAll(payableIdToCreditTransaction.values());
        transList.addAll(debitTransactionsByKey.values());
        transList.addAll(taxTransactionsByKey.values());

        return transList;
    }

    private List<Transaction__c> createTransactionsInLLPMode() {
        //If MC is enabled ==================
        getCurrencyInformation();
        //===================================

        List<Transaction__c> transList = new List<Transaction__c>();

        for (Account_Payable_Line__c invoiceLine : (List<Account_Payable_Line__c>) sourceRecordLines) {
            if (LedgerHandler.getInstanceWithoutSharing().isCashLedger(invoiceLine.Ledger__c)) {
                continue;
            }

            //===========================================================
            //==================== DEBIT LINE ===========================
            //===========================================================
            Transaction__c pt = createTransaction(invoiceLine);
            pt.GL_Account__c = invoiceLine.Expense_GL_Account__c;

            //MC part ==============================================================================================
            processDebitTransactionAmount(invoiceLine, pt);

            pt.Units__c = invoiceLine.Quantity__c == NULL ? 1 : invoiceLine.Quantity__c;
            if (isInventoryCostLine(invoiceLine)) {
                pt.GL_Account__c =
                    glAccountDefaults.get(invoiceLine.Account_Payable__r.Ledger__c)?.get(GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT)?.GL_Account__c;
            }

            if (isInventoryCostLine(invoiceLine) && AccountingSettingsHandler.isInventoryValuationStandardCost()) {
                pt.Amount__c = pt.Units__c * invoiceLine.Product__r.Unit_Cost__c;
            }

            transList.add(pt);
            Decimal debitAmount = pt.Amount__c;

            //===========================================================
            //==================== CREDIT LINE ===========================
            //===========================================================
            pt = createTransaction(invoiceLine);
            pt.GL_Account__c =
                glAccountDefaults.get(invoiceLine.Account_Payable__r.Ledger__c)?.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;

            //MC part ==============================================================================================
            processCreditTransactionAmount(invoiceLine, pt);

            pt.Units__c = invoiceLine.Quantity__c == NULL ? -1 : (invoiceLine.Quantity__c * -1);
            transList.add(pt);

            Decimal creditAmount = pt.Amount__c;

            // Only post variance transaction if cost difference
            if (isInventoryCostLine(invoiceLine) && (debitAmount + creditAmount) != 0 && AccountingSettingsHandler.isInventoryValuationStandardCost()) {
                transList.add(createInventoryVarianceTransaction(invoiceLine, debitAmount, creditAmount));
            }
        }

        return transList;
    }

    private void processDebitTransactionAmount(Account_Payable_Line__c invoiceLine, Transaction__c pt) {
        processTransactionAmount(invoiceLine, pt, invoiceLine.Sub_Total__c);
    }

    private void processCreditTransactionAmount(Account_Payable_Line__c invoiceLine, Transaction__c pt) {
        processTransactionAmount(invoiceLine, pt, invoiceLine.Sub_Total__c * -1);
    }

    private void processTaxTransactionAmount(Account_Payable_Line__c invoiceLine, Transaction__c pt, Tax_Rate__c rate) {
        Decimal normalRate = rate.Tax_Rate__c/100;
        processTransactionAmount(invoiceLine, pt, invoiceLine.Sub_Total__c * normalRate);
    }

    private void processTaxTransactionAmountCredit(Account_Payable_Line__c invoiceLine, Transaction__c pt, Tax_Rate__c rate) {
        Decimal normalRate = rate.Tax_Rate__c/100;
        processTransactionAmount(invoiceLine, pt, invoiceLine.Sub_Total__c * normalRate * -1);
    }

    private void processTransactionAmount(Account_Payable_Line__c invoiceLine, Transaction__c pt, Decimal amount) {
        if (isMultiCurrencyAndDifferentCurrency(invoiceLine.Account_Payable__c, pt.Ledger__c)) {
            pt.Foreign_Amount__c = sumDecimalResult(pt.Foreign_Amount__c, amount, 2);
            pt.Foreign_Currency__c = sourceIdToCurrencyCode.get(invoiceLine.Account_Payable__c);
            pt.Currency_Conversion_Rate__c = sourceIdToCurrencyConversionRate.get(invoiceLine.Account_Payable__c);
            pt.Amount__c = sumDecimalResult(pt.Amount__c, (amount/sourceIdToCurrencyConversionRate.get(invoiceLine.Account_Payable__c)), 2);
        }
        else {
            pt.Amount__c = sumDecimalResult(pt.Amount__c, amount, 2);
        }
    }

    private void processTaxTransaction(Account_Payable_Line__c invoiceLine,
                                        Map<String, Transaction__c> taxTransMap,
                                        Map<Id, Transaction__c> payableIdToCreditTransaction,
                                        Tax_Group__c taxGroup) {
        Transaction__c creditTransaction = payableIdToCreditTransaction.get(invoiceLine.Account_Payable__c);
        Map<Id, Decimal> rateAdjustment = getTaxRateAdjustment(invoiceLine, taxGroup.Tax_Rates__r);
        Map<Id, Decimal> foreignRateAdjustment;
        if (isMultiCurrencyAndDifferentCurrency(invoiceLine.Account_Payable__c, creditTransaction.Ledger__c)) {
            foreignRateAdjustment = getForeignTaxRateAdjustment(invoiceLine, taxGroup.Tax_Rates__r);
        }

        for (Tax_Rate__c rate : taxGroup.Tax_Rates__r) {
            Transaction__c debitTaxTR = updateTaxTransaction(createTransaction(invoiceLine), rate);
            processTaxTransactionAmount(invoiceLine, debitTaxTR, rate);

            if (invoiceLine.Account_Payable__r.Reverse_Charge__c && invoiceLine.Tax_Group__c != NULL && invoiceLine.Tax_Group__r.External_Id2__c != NULL && AccountingSettingsHandler.isAvaVATReportingEnabled()) {
                Transaction__c creditTaxTR = updateTaxTransactionCredit(createTransaction(invoiceLine), rate);
                processTaxTransactionAmountCredit(invoiceLine, creditTaxTR, rate);
                populateTransactionMap(creditTaxTR, taxTransMap, true);
            } else {
                creditTransaction.Amount__c = sumDecimalResult(creditTransaction.Amount__c, debitTaxTR.Amount__c * -1, 2);
                if (isMultiCurrencyAndDifferentCurrency(invoiceLine.Account_Payable__c, creditTransaction.Ledger__c)) {
                    creditTransaction.Foreign_Amount__c = sumDecimalResult(creditTransaction.Foreign_Amount__c, debitTaxTR.Foreign_Amount__c * -1, 2);
                }
            }

            if (isMultiCurrencyAndDifferentCurrency(invoiceLine.Account_Payable__c, creditTransaction.Ledger__c)) {
                if (rateAdjustment.containsKey(rate.Id) && service.getTaxRoundingThreshold(invoiceLine.Account_Payable__r) >= rateAdjustment.get(rate.Id).abs())  {
                    creditTransaction.Foreign_Amount__c += rateAdjustment.get(rate.Id) * -1;
                    debitTaxTR.Foreign_Amount__c += rateAdjustment.get(rate.Id);
                }
                if (foreignRateAdjustment.containsKey(rate.Id) && service.getTaxRoundingThreshold(invoiceLine.Account_Payable__r) >= foreignRateAdjustment.get(rate.Id).abs())  {
                    creditTransaction.Amount__c += foreignRateAdjustment.get(rate.Id) * -1;
                    debitTaxTR.Amount__c += foreignRateAdjustment.get(rate.Id);
                }
            }
            else if (rateAdjustment.containsKey(rate.Id) && service.getTaxRoundingThreshold(invoiceLine.Account_Payable__r) >= rateAdjustment.get(rate.Id).abs()) {
                creditTransaction.Amount__c += rateAdjustment.get(rate.Id) * -1;
                debitTaxTR.Amount__c += rateAdjustment.get(rate.Id);
            }
            populateTransactionMap(debitTaxTR, taxTransMap, true);
        }
    }

    private Map<Id, Decimal> getForeignTaxRateAdjustment (Account_Payable_Line__c invoiceLine, List<Tax_Rate__c> rates) {
        if (invoiceLine.Tax_Inclusive__c) {
            return AbstractTaxService.getTaxRateAdjustmentByAmount(
                (invoiceLine.Sub_Total__c / sourceIdToCurrencyConversionRate.get(invoiceLine.Account_Payable__c)).setScale(2, RoundingMode.HALF_UP), 
                rates, 
                (invoiceLine.Tax_Amount__c / sourceIdToCurrencyConversionRate.get(invoiceLine.Account_Payable__c)).setScale(2, RoundingMode.HALF_UP)
            );
        }
        return AbstractTaxService.getTaxRateAdjustmentByAmount(
            (invoiceLine.Sub_Total__c / sourceIdToCurrencyConversionRate.get(invoiceLine.Account_Payable__c)).setScale(2, RoundingMode.HALF_UP), 
            rates
        );
    }

    private Map<Id, Decimal> getTaxRateAdjustment (Account_Payable_Line__c invoiceLine, List<Tax_Rate__c> rates) {
        if (invoiceLine.Tax_Inclusive__c) {
            return AbstractTaxService.getTaxRateAdjustmentByAmount(invoiceLine.Sub_Total__c, rates, invoiceLine.Tax_Amount__c);
        }
        return AbstractTaxService.getTaxRateAdjustmentByAmount(invoiceLine.Sub_Total__c, rates);
    }

    public override String getTransactionKey(Transaction__c pt, Boolean isTaxTransaction) {
        String result = '';
        result += String.valueOf(pt.Account_Payable__c);
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

    private Transaction__c updateTaxTransaction(Transaction__c pt, Tax_Rate__c rate) {
        pt.GL_Account__c = rate.Purchase_Tax_Expense_GL_Account__c;
        pt.Account_Payable_Line__c = NULL;
        pt.Project_Task__c = NULL;
        pt.Project__c = NULL;
        pt.Product__c = NULL;
        pt.Amount__c = NULL;
        pt.Foreign_Amount__c = NULL;

        return pt;
    }

    private Transaction__c updateTaxTransactionCredit(Transaction__c pt, Tax_Rate__c rate) {
        pt.GL_Account__c = rate.Sales_Tax_Liability_GL_Account__c;
        pt.Account_Payable_Line__c = NULL;
        pt.Project_Task__c = NULL;
        pt.Project__c = NULL;
        pt.Product__c = NULL;
        pt.Amount__c = NULL;
        pt.Foreign_Amount__c = NULL;

        return pt;
    }

    private Transaction__c updateCreditTransaction(Transaction__c pt, SObject obj) {
        pt.GL_Account__c = glAccountDefaults.get(((Account_Payable_Line__c) obj).Account_Payable__r.Ledger__c)?.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;
        pt.Account_Payable_Line__c = NULL;
        pt.Project_Task__c = NULL;
        pt.Project__c = NULL;
        pt.GL_Account_Variable_1__c = NULL;
        pt.GL_Account_Variable_2__c = NULL;
        pt.GL_Account_Variable_3__c = NULL;
        pt.GL_Account_Variable_4__c = NULL;
        pt.Product__c = NULL;

        return pt;
    }

    private Boolean isInventoryCostLine(Account_Payable_Line__c invoiceLine) {
        return AccountingSettingsHandler.isProductCostingEnabled()
                && invoiceLine.Product__c != NULL
                && invoiceLine.Product__r.Inventory_Product__c
                && (invoiceLine.Product__r.Inventory_Type__c == 'Purchased'
                    || invoiceLine.Product__r.Inventory_Type__c == 'Raw Material');
    }

    private Transaction__c createTransaction(SObject obj) {
        Account_Payable_Line__c invoiceLine = (Account_Payable_Line__c) obj;

        Transaction__c pt = new Transaction__c();

        pt.Account_Payable_Line__c = !IS_HEADER_LEVEL_POST ? invoiceLine.Id : NULL;
        pt.Account_Payable__c = IS_HEADER_LEVEL_POST ? invoiceLine.Account_Payable__c : NULL;
        pt.Ledger__c = invoiceLine.Account_Payable__r.Ledger__c != NULL ? invoiceLine.Account_Payable__r.Ledger__c : LedgerHandler.getLegacyDefaultLedgerId();
        pt.Accounting_Period__c = invoiceLine.Account_Payable__r.Accounting_Period__c;
        pt.Date__c = invoiceLine.Account_Payable__r.Date__c;
        pt.Project_Task__c = invoiceLine.Project_Task__c;
        pt.Project__c = invoiceLine.Project__c;
        pt.GL_Account_Variable_1__c = invoiceLine.GL_Account_Variable_1__c;
        pt.GL_Account_Variable_2__c = invoiceLine.GL_Account_Variable_2__c;
        pt.GL_Account_Variable_3__c = invoiceLine.GL_Account_Variable_3__c;
        pt.GL_Account_Variable_4__c = invoiceLine.GL_Account_Variable_4__c;
        pt.Account__c = invoiceLine.Account_Payable__r.Vendor__c;
        pt.Employee__c = invoiceLine.Account_Payable__r.Employee__c;
        pt.Contact__c = invoiceLine.Account_Payable__r.Contact__c;
        pt.Note__c = invoiceLine.Account_Payable__r.Payee_Reference__c;
        pt.Product__c = invoiceLine.Product__c;

        return pt;
    }

    private Transaction__c createInventoryVarianceTransaction(SObject obj, Decimal debitAmount, Decimal creditAmount) {
        Account_Payable_Line__c invoiceLine = (Account_Payable_Line__c) obj;
        
        Transaction__c pt = createTransaction(invoiceLine);
        pt.GL_Account__c = glAccountDefaults.get(invoiceLine.Account_Payable__r.Ledger__c)?.get(GLAccountDefaultsHandler.INVENTORY_VARIANCE_GL_ACCOUNT)?.GL_Account__c;
        pt.Units__c = invoiceLine.Quantity__c == NULL ? 1 : invoiceLine.Quantity__c;
        pt.Amount__c = (debitAmount + creditAmount) * -1;
        pt.Units__c = pt.Amount__c < 0 ? pt.Units__c * -1 : pt.Units__c;

        return pt;
    }

    //Accessible and FLS checks are performed in Visualforce page for the records retrieved from this method.
    public List<Transaction__c> getForecastedTransactions() {

        if (dispatcher.getExecutionContext() == PostResultDispatcher.ExecutionContext.POST) {
            List<Transaction__c> transactionsList = buildTransactions();
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

            String queryCondition;

            if (IS_HEADER_LEVEL_POST) {
                Set<String> headerIds = getHeaderLevelIds(Account_Payable_Line__c.Account_Payable__c);
                queryCondition = 'Account_Payable__c IN :headerIds AND ' + AP_Disbursement__c.getSObjectType() + ' = null';
            }
            else {
                queryCondition = 'Account_Payable_Line__c IN :sourceRecordLines AND ' + AP_Disbursement__c.getSObjectType() + ' = null';
            }


            SOQLBuilder theQuery = new SOQLBuilder(Transaction__c.SObjectType);
            theQuery
                .setEnforceFLS(false)
                .selectFields(queryFields)
                .setCondition(queryCondition);

            return (List<Transaction__c>) Database.query(theQuery.toSOQL());
        }
    }

    private void submitSuccessfulResultsToAvaVAT() {
        try {
            FinancialSuiteService.submitPayablesToAvaVAT(dispatcher.getIdsFromSuccessfulResultsAsList(), dispatcher.getExecutionContext());
        } catch (Exception ex) {
            // Ignore Avalara VAT Reporting submission failures
        }
    }

}