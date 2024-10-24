public with sharing class JournalEntryPostHandler extends AbstractPostHandler {

    private static final String NO_JOURNAL_LINES_ERROR_MESSAGE = Label.ERR_NO_JOURNAL_LINES;
    @TestVisible
    private static final Integer JOURNAL_ENTRY_LINE_COUNT_LIMIT = 1000;
    @TestVisible
    private static final String JOURNAL_ENTRY_LINE_COUNT_LIMIT_EXCEEDED_ERROR_MESSAGE =
        Label.ERR_PAYABLE_LINE_COUNT_LIMIT_EXCEEDED;
    @TestVisible
    private static final String CREDITS_DEBITS_NOT_EQUAL_ERROR_MESSAGE =
        Label.ERR_CREDITS_DEBITS_NOT_EQUAL;
    private static final String UNPOSTED_CLEARED_BANK_RECONCILIATION_ERROR_MESSAGE =
        Label.ERR_UNPOSTED_CLEARED_BANK_RECONCILIATION;
    private static final String UNPOSTED_CLEARED_BANK_DEPOSIT_ERROR_MESSAGE =
        Label.ERR_UNPOSTED_CLEARED_BANK_DEPOSIT;
    public static final String NO_SELECTION_UNPOST_ERROR =
        Label.ERR_NO_SELECTION_UNPOST;
    //============================================================================================
    // =========== LDV Support ===========================
    public override List<PostResult> post(List<LDVPostInput> sourceItems) {
        List<Journal_Entry_Line__c> processedLines = new List<Journal_Entry_Line__c>();
        Map<Id, LDVPostInput> sourceMap = new Map<Id, LDVPostInput>();

        for (LDVPostInput item : sourceItems) {
            processedLines.addAll((List<Journal_Entry_Line__c>)item.lines);
            sourceMap.put(item.id, item);
        }

        Map<Id, PostResult> postResults = new Map<Id, PostResult>();

        this.processedRecordIds = new List<Id>(sourceMap.keySet());
        dispatcher.clearResultsMap();
        dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.POST);
        queryJournalEntries();
        getGLAccountDefaults();
        filteredRecordsByStatus(DEFAULT_POSTING_STATUS_POSTED);
        validateAccountingPeriodIsOpen(true);
        validateLedgerType(true, true);
        validateNotPosted(true);
        validateDebitsEqualCredits(true);
        //validate all Journal Entries have Journal Entry lines
        validateJournalEntryLinesExist(true);
        //no need to proceed further if there is no valid Journal Entries after all validations above
        validateNoQualifyingPostedRecords(
            AbstractPostHandler.NO_SELECTION_POSTED_ERROR_MESSAGE
                + '  '
                + JournalEntryPostHandler.CREDITS_DEBITS_NOT_EQUAL_ERROR_MESSAGE
        );

        if (!sourceRecords.isEmpty()) {
            sourceRecordLines = processedLines;
            validateJeLineCashFlowStatementConformity(true);
            Map<Id, Journal_Entry_Line__c> processedLinesMap = new Map<Id, Journal_Entry_Line__c>((List<Journal_Entry_Line__c>) sourceRecordLines);
            for (Transaction__c tr : createTransactions()) {
                if (!postResults.containsKey(processedLinesMap.get(tr.Journal_Entry_Line__c).Journal_Entry__c)) {
                    PostResult res = new PostResult(
                        true,
                        processedLinesMap.get(tr.Journal_Entry_Line__c).Journal_Entry__c,
                        '',
                        sourceMap.get(processedLinesMap.get(tr.Journal_Entry_Line__c).Journal_Entry__c).transactionGroup);
                    res.transactions.add(tr);
                    postResults.put(processedLinesMap.get(tr.Journal_Entry_Line__c).Journal_Entry__c, res);
                }
                else {
                    postResults.get(processedLinesMap.get(tr.Journal_Entry_Line__c).Journal_Entry__c).transactions.add(tr);
                }

            }
        }
        processPostResult();
        ldvValidatePostResultMap(postResults);

        return postResults.values();
    }

    public override List<PostResult> unpost(List<LDVPostInput> sourceItems) {
        List<Journal_Entry_Line__c> processedLines = new List<Journal_Entry_Line__c>();
        Map<Id, LDVPostInput> sourceMap = new Map<Id, LDVPostInput>();

        for (LDVPostInput item : sourceItems) {
            sourceMap.put(item.id, item);
            processedLines.addAll((List<Journal_Entry_Line__c>)item.lines);
        }

        Map<Id, PostResult> postResults = new Map<Id, PostResult>();
        this.processedRecordIds = new List<Id>(sourceMap.keySet());
        if (!this.processedRecordIds.isEmpty()) {
            try {
                dispatcher.clearResultsMap();
                dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.UNPOST);
                queryJournalEntries();
                validateAccountingPeriodIsOpen(true);
                //no need to proceed further if there is no valid Journal Entries after all validations above
                validateNoQualifyingUnpostedRecords(NO_SELECTION_UNPOST_ERROR);
                if (!sourceRecords.isEmpty()) {
                    //weed out the unsuitable Journal Entry Lines
                    validateNotAssociatedWithBankRecOrBankDeposit(true);
                    validateNoQualifyingUnpostedRecords(NO_SELECTION_UNPOST_ERROR);
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

    public void processLDVPostJETransaction(List<PostResult> processedResults) {
        Savepoint sp;
        if(!Test.isRunningTest()) {
            sp = Database.setSavepoint();
        }

        try {
            List<Transaction__c> transList = new List<Transaction__c>();
            Map<Id, Journal_Entry__c> needUpdateStatus = new Map<Id, Journal_Entry__c>();

            for (PostResult item : processedResults) {
                for (Transaction__c tr : item.transactions) {
                    transList.add(tr);
                }
                if (item.transactionGroup.Line_Count__c == item.transactionGroup.Lines_Processed__c) {
                    needUpdateStatus.put(item.id, null);
                }
            }

            for (Journal_Entry__c je : (List<Journal_Entry__c>) sourceRecords) {
                if (needUpdateStatus.containsKey(je.Id)) {
                    je.Status__c = DEFAULT_POSTING_STATUS_POSTED;
                    needUpdateStatus.put(je.Id, je);
                }
            }

            TriggerObserver.getInstance().unlockField(Journal_Entry__c.Status__c);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(needUpdateStatus.values(), new List<String>{'Status__c'});
            TriggerObserver.purgeUnlockedFields(Journal_Entry__c.Status__c);

            sourceRecords = DomainUtils.getJournalEntryByIdForUpdate(needUpdateStatus.keySet());
            validatePostStatusSet();

            TransactionActions.createTransactions(transList);
        }
        catch (Exception ex) {
            Database.rollback(sp);
            throw ex;
        }
    }

    public void processLDVUnpostJETransactions(List<PostResult> processedResults) {
        Map<Id, Journal_Entry__c> needUpdateStatus = new Map<Id, Journal_Entry__c>();
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
            TransactionActions.deleteTransactions(TransactionActions.queryTransactions(sourceRecordLines));
            String defaultPostingStatus = FinancialSuiteUtils.getDefaultPostingStatus(Journal_Entry__c.Status__c);

            for (Journal_Entry__c je : (List<Journal_Entry__c>) this.sourceRecords) {
                if (needUpdateStatus.containsKey(je.Id)) {
                    je.Status__c = defaultPostingStatus;
                    needUpdateStatus.put(je.Id, je);
                }
            }

            TriggerObserver.getInstance().unlockFields(new Set<SObjectField> {Journal_Entry__c.Status__c});
            SFDCSecurityUtils.updateCheckCRUDAndFLS(needUpdateStatus.values(), new List<String>{'Status__c'});
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField> {Journal_Entry__c.Status__c});
        }
        catch (Exception ex) {
            Database.rollback(sp);
            throw ex;
        }
    }
    //====================================================

    //Post method implementation ====================================================
    public override List<PostResult> post(List<SObject> processedRecords) {
        Map<Id, Journal_Entry__c> jEntryMap = new Map<Id, Journal_Entry__c>((List<Journal_Entry__c>) processedRecords);
        return post(new List<Id>(jEntryMap.keySet()));
    }

    public override List<PostResult> post(List<String> processedRecordsIds) {
        this.processedRecordIds = processedRecordsIds;

        if (!this.processedRecordIds.isEmpty()) {
            try {
                dispatcher.clearResultsMap();
                dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.POST);
                //Initial query for Journal Entries
                queryJournalEntries();
                //weed out the unsuitable Journal Entries
                validateAccountingPeriodIsOpen(false);
                validateLedgerType(false, true);
                validateNotPosted(false);
                validateStatusApproved(false);
                validateDebitsEqualCredits(false);
                //validate all Journal Entries have Journal Entry lines
                validateJournalEntryLinesExist(false);
                //no need to proceed further if there is no valid Journal Entries after all validations above
                validateNoQualifyingPostedRecords(
                    AbstractPostHandler.NO_SELECTION_POSTED_ERROR_MESSAGE
                        + '  '
                        + JournalEntryPostHandler.CREDITS_DEBITS_NOT_EQUAL_ERROR_MESSAGE
                );

                if (!sourceRecords.isEmpty()) {
                    //it's time to query Journal Entry Lines
                    queryJournalEntryLines();
                    validateJeLineCashFlowStatementConformity(false);
                    //validate line count and if everything is OK => execute Posting business logic
                    if (validateJournalEntryLinesLimit()) {
                        processPostJournalEntries();
                        for (SObject jEntry : sourceRecords) {
                            dispatcher.addPostResult(jEntry.Id, new PostResult(true, jEntry.Id, NULL));
                        }
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

        return dispatcher.getPostResults();
    }

    //==============================================================================================
    //Unpost method implementation ====================================================
    public override List<PostResult> unpost(List<SObject> processedRecords) {
        Map<Id, Journal_Entry__c> jEntriesMap = new Map<Id, Journal_Entry__c>((List<Journal_Entry__c>) processedRecords);
        return unpost(new List<Id>(jEntriesMap.keySet()));
    }

    public override List<PostResult> unpost(List<String> processedRecordsIds) {
        this.processedRecordIds = processedRecordsIds;

        if (!this.processedRecordIds.isEmpty()) {
            try {
                dispatcher.clearResultsMap();
                dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.UNPOST);
                //Initial query for Journal Entries
                queryJournalEntries();
                //weed out the unsuitable Journal Entries
                validateIsPosted(false);
                validateAccountingPeriodIsOpen(false);
                //no need to proceed further if there is no valid Journal Entries after all validations above
                validateNoQualifyingUnpostedRecords(NO_SELECTION_UNPOST_ERROR);

                if (!sourceRecords.isEmpty()) {
                    //it's time to query Payable Lines
                    queryJournalEntryLines();
                    //weed out the unsuitable Journal Entry Lines
                    validateNotAssociatedWithBankRecOrBankDeposit(false);
                    withdrawNonValidJournalEntries();
                    validateNoQualifyingUnpostedRecords(NO_SELECTION_UNPOST_ERROR);
                    if (!sourceRecordLines.isEmpty() && validateJournalEntryLinesLimit()) {
                        processUnpostJournalEntry();
                        for (SObject jEntry : sourceRecords) {
                            dispatcher.addPostResult(jEntry.Id, new PostResult(true, jEntry.Id, NULL));
                        }
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

        return dispatcher.getPostResults();
    }

    //===================================================================================
    //====== Payable Post/Unpost specific utility and validation methods ================

    private void queryJournalEntries() {
        //=================================================
        //build dynamic SOQL query using SOQLBuilder class
        //=================================================
        //Select fields
        List<String> fieldsToQuery = new List<String> {
            'Id',
            'Name',
            'Ledger__c',
            'Ledger__r.Name',
            'Ledger__r.Type__c',
            'Ledger__r.Accounting_Method__c',
            'Accounting_Period__c',
            'Accounting_Period__r.Status__c',
            'Accounting_Period__r.Name',
            'Journal_Date__c',
            'Status__c',
            'Total_Credits__c',
            'Total_Debits__c'
        };
        //Add Multicurrency related fields
        if (IS_MULTI_CURRENCY_ENABLED) {
            fieldsToQuery.addAll(new String[]{'CurrencyIsoCode', 'Currency_Conversion_Rate__c'});
        }
        //Add query condition
        String queryCondition = 'Id IN :processedRecordIds FOR UPDATE';
        //Final assembly of SOQL string
        String dynamicSOQL = SOQLBuilder.buildDynamicSoqlQuery(
            fieldsToQuery,
            NULL,
            Journal_Entry__c.SObjectType,
            queryCondition,
            true,
            false
        );
        //Call DML operation
        sourceRecords = Database.query(dynamicSOQL);
    }

    private void queryJournalEntryLines() {
        //=================================================
        //build dynamic SOQL query using SOQLBuilder class
        //=================================================
        //Select fields
        List<String> fieldsToQuery = new List<String> {
            'Id',
            'Name',
            'Date__c',
            'Reference__c',
            'Journal_Entry__c',
            'Journal_Entry__r.Name',
            'Journal_Entry__r.Total_Credits__c',
            'Journal_Entry__r.Total_Debits__c',
            'Journal_Entry__r.Ledger__c',
            'Journal_Entry__r.Accrual_and_or_Cash__c',
            'Ledger__c',
            'Credit__c',
            'Debit__c',
            'Project_Task__c',
            'Units__c',
            'Project__c',
            'Time_Card_Variable_1__c',
            'Time_Card_Variable_2__c',
            'GL_Account__c',
            'GL_Account__r.Bank__c',
            'Account__c',
            'Employee__c',
            'Contact__c',
            'Cash_Flow_Category__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c',
            'Journal_Entry__r.Accounting_Period__c',
            'Journal_Entry__r.Journal_Date__c',
            'Product__c',
            'Bank_Reconciliation__c',
            'Bank_Reconciliation__r.Name',
            'Bank_Deposit__c',
            'Bank_Deposit__r.Name'
        };

        //Add query condition
        String queryCondition = 'Journal_Entry__c IN :sourceRecords LIMIT 1001 FOR UPDATE';
        //Final assembly of SOQL string
        String dynamicSOQL = SOQLBuilder.buildDynamicSoqlQuery(
            fieldsToQuery,
            NULL,
            Journal_Entry_Line__c.SObjectType,
            queryCondition,
            true,
            false
        );
        //Call DML operation and return the results
        sourceRecordLines = Database.query(dynamicSOQL);
    }

    private void validateJournalEntryLinesExist(Boolean fullStatistics) {
        Map<Id, Journal_Entry__c> preSelectedJournalEntries =
            new Map<Id, Journal_Entry__c>((List<Journal_Entry__c>) sourceRecords);

        // CRUD and FLS already has been checked at this point. No need to check again.
        Set<Id> parentIdsWithLines = DomainUtils.parentIdsWithLines(
                String.valueOf(Journal_Entry_Line__c.getSObjectType()),
                String.valueOf(Journal_Entry_Line__c.Journal_Entry__c),
                preSelectedJournalEntries.keySet()
        );

        for (Journal_Entry__c jEntry : new List<Journal_Entry__c>(preSelectedJournalEntries.values())) {
            if (!parentIdsWithLines.contains(jEntry.Id)) {
                preSelectedJournalEntries.remove(jEntry.Id);
                dispatcher.addPostErrorResult(
                    jEntry,
                    new PostResult.PostErrorResult(
                        jEntry,
                        PostResult.StatusCode.NO_LINES,
                        NO_JOURNAL_LINES_ERROR_MESSAGE
                    )
                );
            }
        }
        //the rest of Journal Entries will have all fields selected in the initial SOQL query
        if (!fullStatistics) {
            sourceRecords = preSelectedJournalEntries.values();
        }
    }

    public void validateBeforePost(List<SObject> processedRecords, Boolean fullStatistics) {
        dispatcher.clearResultsMap();
        dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.POST);
        Map<Id, Journal_Entry__c> jEntryMap = new Map<Id, Journal_Entry__c>((List<Journal_Entry__c>) processedRecords);
        this.processedRecordIds = new List<Id>(jEntryMap.keySet());
        //Initial query for Journal Entries
        queryJournalEntries();
        //weed out the unsuitable Journal Entries
        validateAccountingPeriodIsOpen(fullStatistics);
        validateLedgerType(fullStatistics, true);
        validateNotPosted(fullStatistics);
        validateStatusApproved(fullStatistics);
        validateDebitsEqualCredits(fullStatistics);
        //validate all Journal Entries have Journal Entry lines
        validateJournalEntryLinesExist(fullStatistics);
        if (!this.isLDVBatchContext && !sourceRecords.isEmpty()) {
            //it's time to query Journal Entry Lines
            queryJournalEntryLines();
            validateJeLineCashFlowStatementConformity(fullStatistics);
            //validate line count
            validateJournalEntryLinesLimit();
        }
        //add positive results
        processPostResult();
    }

    public void validateBeforeUnpost(List<SObject> processedRecords, Boolean fullStatistics) {
        dispatcher.clearResultsMap();
        dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.UNPOST);
        Map<Id, Journal_Entry__c> jEntryMap = new Map<Id, Journal_Entry__c>((List<Journal_Entry__c>) processedRecords);
        this.processedRecordIds = new List<Id>(jEntryMap.keySet());
        //Initial query for Journal Entries
        queryJournalEntries();
        validateIsPosted(fullStatistics);
        //weed out the unsuitable Journal Entries
        validateAccountingPeriodIsOpen(fullStatistics);
        if (!this.isLDVBatchContext && !sourceRecords.isEmpty()) {
            //it's time to query Payable Lines
            queryJournalEntryLines();
            //weed out the unsuitable Journal Entry Lines
            validateNotAssociatedWithBankRecOrBankDeposit(fullStatistics);
            validateJournalEntryLinesLimit();
        }
        //add positive results
        processPostResult();
    }

    private void validateJeLineCashFlowStatementConformity(Boolean fullStatistics) {
        List<Journal_Entry__c> validJournalEntries = new List<Journal_Entry__c>();
        Set<Id> notValidJournalEntryIds = new Set<Id>();
        getAccountingSettings();

        for (Journal_Entry_Line__c jEntryLine : (List<Journal_Entry_Line__c>) sourceRecordLines) {
            //Check line validity if CFS is enabled
            if (main.Enable_Cash_Flow_Statement__c && jEntryLine.GL_Account__r.Bank__c && jEntryLine.Cash_Flow_Category__c == NULL) {

                dispatcher.addPostErrorResult(
                    jEntryLine.Journal_Entry__r,
                    new PostResult.PostErrorResult(
                        jEntryLine,
                        PostResult.StatusCode.NO_CASH_FLOW_CATEGORY,
                        NO_CASH_FLOW_CATEGORY_HELP_TEXT
                    )
                );

                notValidJournalEntryIds.add(jEntryLine.Journal_Entry__c);
            }//Check line validity if CFS is NOT enabled
            else if (!main.Enable_Cash_Flow_Statement__c && jEntryLine.Cash_Flow_Category__c != NULL) {

                dispatcher.addPostErrorResult(
                    jEntryLine.Journal_Entry__r,
                    new PostResult.PostErrorResult(
                        jEntryLine,
                        PostResult.StatusCode.CASH_FLOW_NON_CONFORMITY,
                        CASH_FLOW_NON_CONFORMITY_HELP_TEXT
                    )
                );

                notValidJournalEntryIds.add(jEntryLine.Journal_Entry__c);
            }
        }

        //weed out all not valid records if they exist and if it is not statistics collection's context
        if (!notValidJournalEntryIds.isEmpty() && !fullStatistics) {
            //get rid of Journal entries which contain non-valid Lines
            for (Journal_Entry__c jEntry : (List<Journal_Entry__c>) sourceRecords) {
                if (!notValidJournalEntryIds.contains(jEntry.Id)) {
                    validJournalEntries.add(jEntry);
                }
            }

            //reassign JE records collection to have only valid header records further
            sourceRecords = validJournalEntries;
            //refresh JE Lines collection from DB to have Lines related to the valid JE records only
            queryJournalEntryLines();
        }
    }

    private Boolean validateJournalEntryLinesLimit() {
        Integer lineCount = sourceRecordLines.size();

        if (lineCount > JOURNAL_ENTRY_LINE_COUNT_LIMIT) {
            for (SObject jEntry : sourceRecords) {
                dispatcher.addPostErrorResult(
                    jEntry,
                    new PostResult.PostErrorResult(
                        jEntry,
                        PostResult.StatusCode.LINE_COUNT_LIMIT_EXCEEDED,
                        String.format(
                            JOURNAL_ENTRY_LINE_COUNT_LIMIT_EXCEEDED_ERROR_MESSAGE,
                            new List<String>{String.valueOf(JOURNAL_ENTRY_LINE_COUNT_LIMIT)}
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

    private void validateDebitsEqualCredits(Boolean fullStatistics) {
        List<Journal_Entry__c> validJournalEntries = new List<Journal_Entry__c>();

        for (Journal_Entry__c jEntry : (List<Journal_Entry__c>) sourceRecords) {

            if (jEntry.Total_Credits__c.setScale(2, System.RoundingMode.HALF_UP) !=
                    jEntry.Total_Debits__c.setScale(2, System.RoundingMode.HALF_UP)) {

                dispatcher.addPostErrorResult(
                    jEntry,
                    new PostResult.PostErrorResult(
                        jEntry,
                        PostResult.StatusCode.CREDITS_DEBITS_NOT_EQUAL,
                        JournalEntryPostHandler.CREDITS_DEBITS_NOT_EQUAL_ERROR_MESSAGE
                    )
                );
            }
            else {
                validJournalEntries.add(jEntry);
            }

        }

        if (!fullStatistics) {
            sourceRecords = validJournalEntries;
        }
    }

    private void validateNotAssociatedWithBankRecOrBankDeposit(Boolean fullStatistics) {
        List<Journal_Entry_Line__c> validJEntryLines = new List<Journal_Entry_Line__c>();

        validateNotAssociatedWithBankReconciliation();
        validateNotAssociatedWithBankDeposit();

        for (Journal_Entry_Line__c jEntryLine : (List<Journal_Entry_Line__c>) sourceRecordLines) {
            if (!dispatcher.getPostResultsMap().containsKey(jEntryLine.Journal_Entry__c)) {
                validJEntryLines.add(jEntryLine);
            }
        }

        if (!fullStatistics) {
            sourceRecordLines = validJEntryLines;
        }
    }

    private void validateNotAssociatedWithBankReconciliation() {
        for (Journal_Entry_Line__c jEntryLine : (List<Journal_Entry_Line__c>) sourceRecordLines) {
            if (jEntryLine.Bank_Reconciliation__c != NULL) {
                dispatcher.addPostErrorResult(
                    jEntryLine.Journal_Entry__r,
                    new PostResult.PostErrorResult(
                        jEntryLine.Bank_Reconciliation__r,
                        PostResult.StatusCode.CLEARED_BANK_RECONCILIATION,
                        UNPOSTED_CLEARED_BANK_RECONCILIATION_ERROR_MESSAGE
                    )
                );
            }
        }
    }

    private void validateNotAssociatedWithBankDeposit() {
        for (Journal_Entry_Line__c jEntryLine : (List<Journal_Entry_Line__c>) sourceRecordLines) {
            if (jEntryLine.Bank_Deposit__c != NULL) {
                dispatcher.addPostErrorResult(
                    jEntryLine.Journal_Entry__r,
                    new PostResult.PostErrorResult(
                        jEntryLine.Bank_Deposit__r,
                        PostResult.StatusCode.CLEARED_BANK_DEPOSIT,
                        UNPOSTED_CLEARED_BANK_DEPOSIT_ERROR_MESSAGE
                    )
                );
            }
        }
    }

    //for the final step of Unpost validation
    private void withdrawNonValidJournalEntries() {
        Set<Id> validJEIds = new Set<Id>();
        List<Journal_Entry__c> validJournalEntries = new List<Journal_Entry__c>();
        for (Journal_Entry_Line__c jEntryLine : (List<Journal_Entry_Line__c>) sourceRecordLines) {
            validJEIds.add(jEntryLine.Journal_Entry__c);
        }
        for (Journal_Entry__c je : (List<Journal_Entry__c>) sourceRecords) {
            if (validJEIds.contains(je.Id)) {
                validJournalEntries.add(je);
            }
        }

        sourceRecords = validJournalEntries;
    }

    private void processPostJournalEntries() {
        getAccountingSettings();
        SavePoint sp = Database.setSavepoint();

        try {
            // delete any and all transactions associated with the source document
            // before another set of transactions are created and the status is changed
            TransactionActions.deleteTransactions(TransactionActions.queryTransactions(sourceRecordLines));
            //=========================================================================================

            List<Transaction__c> transList = createTransactions();
            for (Journal_Entry__c journalEntry : (List<Journal_Entry__c>) sourceRecords) {
                journalEntry.Status__c = DEFAULT_POSTING_STATUS_POSTED;
            }

            //convert generic collection to the collection with specific SObjectType
            List<Journal_Entry__c> sourceRecordsToUpdate = new List<Journal_Entry__c>(
                (List<Journal_Entry__c>) sourceRecords
            );

            TriggerObserver.getInstance().unlockField(Journal_Entry__c.Status__c);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(sourceRecordsToUpdate, new List<String>{'Status__c'});
            TriggerObserver.purgeUnlockedFields(Journal_Entry__c.Status__c);

            sourceRecords = DomainUtils.getJournalEntryByIdForUpdate(
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

    private void processUnpostJournalEntry() {
        Savepoint sp = Database.setSavepoint();
        try {
            TransactionActions.deleteTransactions(TransactionActions.queryTransactions(sourceRecordLines));

            List<Journal_Entry__c> updateJournalEntryList = new List<Journal_Entry__c>();
            String defaultPostingStatus = FinancialSuiteUtils.getDefaultPostingStatus(Journal_Entry__c.Status__c);

            for (Journal_Entry__c je : (List<Journal_Entry__c>) sourceRecords) {
                if (je.Status__c == DEFAULT_POSTING_STATUS_POSTED) {
                    je.Status__c = defaultPostingStatus;
                    updateJournalEntryList.add(je);
                }
            }

            TriggerObserver.getInstance().unlockField(Journal_Entry__c.Status__c);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(updateJournalEntryList, new List<String>{'Status__c'});
            TriggerObserver.purgeUnlockedFields(Journal_Entry__c.Status__c);
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
        for (Journal_Entry_Line__c jel : (List<Journal_Entry_Line__c>) sourceRecordLines) {
            Transaction__c trans = createTransaction(jel);
            Decimal transactionAmount;
            if (jel.Debit__c <> NULL) {
                transactionAmount = jel.Debit__c;
            }
            else {
                transactionAmount = jel.Credit__c * (-1);
            }

            trans.Ledger__c = getLedgerId(jel);
            //MC part ================================================================================================
            if (isMultiCurrencyAndDifferentCurrency(jel.Journal_Entry__c, trans.Ledger__c)) {
                trans.Foreign_Amount__c = transactionAmount;
                trans.Foreign_Currency__c = sourceIdToCurrencyCode.get(jel.Journal_Entry__c);
                trans.Currency_Conversion_Rate__c = sourceIdToCurrencyConversionRate.get(jel.Journal_Entry__c);
                trans.Amount__c =
                    (transactionAmount / sourceIdToCurrencyConversionRate.get(jel.Journal_Entry__c))
                        .setScale(2, System.RoundingMode.HALF_UP);
            }
            else {
                trans.Amount__c = transactionAmount;
            }
            //========================================================================================================
            transList.add(trans);

            if (LedgerHandler.getInstanceWithoutSharing().isAccrualAndCashLedger(jel.Ledger__c)
                && jel.Journal_Entry__r.Accrual_and_or_Cash__c == LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH) {
                transList.addAll(getShadowLedgerTransaction(jel));
            }
        }
        return transList;
    }

    private Id getLedgerId(Journal_Entry_Line__c line) {
        Id glLedgerId;
        if (LedgerHandler.getInstanceWithoutSharing().isAccrualAndCashLedger(line.Ledger__c)
            && line.Journal_Entry__r.Accrual_and_or_Cash__c == LedgerActions.ACCOUNTING_METHOD_CASH) {
            glLedgerId = LedgerHandler.getInstanceWithoutSharing().getShadowLedgerByParent(line.Ledger__c).Id;
        } else {
            glLedgerId = line.Journal_Entry__r.Ledger__c != null ? line.Journal_Entry__r.Ledger__c : LedgerHandler.getLegacyDefaultLedgerId();
        }
        return glLedgerId;
    }

    private List<Transaction__c> getShadowLedgerTransaction(Journal_Entry_Line__c jel) {
        List<Transaction__c> shadowTrans = new List<Transaction__c>();
        Transaction__c trans = createTransaction(jel);
        Decimal transactionAmount;
        if (jel.Debit__c <> NULL) {
            transactionAmount = jel.Debit__c;
        }
        else {
            transactionAmount = jel.Credit__c * (-1);
        }
        trans.Ledger__c = LedgerHandler.getInstanceWithoutSharing().getShadowLedgerByParent(jel.Ledger__c).Id;
        if (isMultiCurrencyAndDifferentCurrency(jel.Journal_Entry__c, trans.Ledger__c)) {
            trans.Foreign_Amount__c = transactionAmount;
            trans.Foreign_Currency__c = sourceIdToCurrencyCode.get(jel.Journal_Entry__c);
            trans.Currency_Conversion_Rate__c = sourceIdToCurrencyConversionRate.get(jel.Journal_Entry__c);
            trans.Amount__c =
                (transactionAmount / sourceIdToCurrencyConversionRate.get(jel.Journal_Entry__c))
                    .setScale(2, System.RoundingMode.HALF_UP);
        }
        else {
            trans.Amount__c = transactionAmount;
        }
        shadowTrans.add(trans);
        return shadowTrans;
    }

    private Transaction__c createTransaction(Journal_Entry_Line__c jel) {
        Transaction__c trans = new Transaction__c();
        trans.GL_Account_Variable_1__c = jel.GL_Account_Variable_1__c;
        trans.GL_Account_Variable_2__c = jel.GL_Account_Variable_2__c;
        trans.GL_Account_Variable_3__c = jel.GL_Account_Variable_3__c;
        trans.GL_Account_Variable_4__c = jel.GL_Account_Variable_4__c;
        trans.Date__c = jel.Date__c == null ? jel.Journal_Entry__r.Journal_Date__c : jel.Date__c;
        trans.GL_Account__c = jel.GL_Account__c;
        trans.Journal_Entry_Line__c =  jel.Id ;
        trans.Project__c = jel.Project__c;
        trans.Project_Task__c = jel.Project_Task__c;
        trans.Time_Card_Variable_1__c = jel.Time_Card_Variable_1__c;
        trans.Time_Card_Variable_2__c = jel.Time_Card_Variable_2__c;
        trans.Units__c = jel.Units__c;
        trans.Accounting_Period__c = jel.Journal_Entry__r.Accounting_Period__c;
        trans.Account__c = jel.Account__c;
        trans.Employee__c = jel.Employee__c;
        trans.Contact__c = jel.Contact__c;
        trans.Product__c = jel.Product__c;
        trans.Note__c = jel.Reference__c;
        trans.Cash_Flow_Category__c = jel.Cash_Flow_Category__c;
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

            String queryCondition = 'Journal_Entry_Line__c IN :sourceRecordLines';

            SOQLBuilder theQuery = new SOQLBuilder(Transaction__c.SObjectType);
            theQuery
                .setEnforceFLS(false)
                .selectFields(queryFields)
                .setCondition(queryCondition);

            return (List<Transaction__c>) Database.query(theQuery.toSOQL());
        }

    }

}