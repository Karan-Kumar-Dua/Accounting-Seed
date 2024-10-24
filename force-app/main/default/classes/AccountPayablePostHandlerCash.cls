public with sharing class AccountPayablePostHandlerCash extends AbstractPostHandler {
    // =========== LDV Support ===========================

    public override List<PostResult> post(List<LDVPostInput> sourceItems) {
        Set<Id> processedRecordsIds = new Set<Id>();
        List<Account_Payable_Line__c> processedLines = new List<Account_Payable_Line__c>();
        Map<Id, LDVPostInput> sourceItemsByHeaderIds = new Map<Id, LDVPostInput>();

        for (LDVPostInput item : sourceItems) {
            processedRecordsIds.add(item.id);
            processedLines.addAll((List<Account_Payable_Line__c>)item.lines);
            sourceItemsByHeaderIds.put(item.id, item);
        }

        Map<Id, PostResult> postResultsByIds = new Map<Id, PostResult>();

        this.processedRecordIds = new List<Id>(processedRecordsIds);
        if (!this.processedRecordIds.isEmpty()) {
            try {
                dispatcher.clearResultsMap();
                dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.POST);
                //Initial query for payables
                this.sourceRecords = AccountPayablePostHandler.queryPayables(this.processedRecordIds);
                this.sourceRecords = filterRecordsByAcctMethods(
                        this.sourceRecords,
                        new Set<String>{LedgerActions.ACCOUNTING_METHOD_CASH}
                );
                this.glAccountDefaults = this.getGLAccountDefaults(this.sourceRecords);
                if (AccountPayablePostHandler.validateAPControlGLAccount(sourceRecords, glAccountDefaults, dispatcher)) {
                    //weed out unsuitable payables
                    filteredRecordsByStatus(DEFAULT_POSTING_STATUS_POSTED);
                    validateNotPosted(true);
                    validateAccountingPeriodIsOpen(true);
                    validateLedgerType(true, true);
                    validateLedgerTaxSetting(true);
                    this.sourceRecords = AccountPayablePostHandler.validatePayableLinesExist(this.sourceRecords, this.dispatcher, true);

                    this.sourceRecords = filterValidRecords(this.sourceRecords);
                    validateNoQualifyingPostedRecords();

                    if (!sourceRecords.isEmpty()) {
                        processPostAccountPayables(sourceItems);
                        processPostResult();
                    }
                }
                else {
                    processPostResult();
                }
                dispatcher.isPreCheck = false;
            }
            catch (DmlException dmlEx) {
                processDmlExceptions(dmlEx);
            }
            catch (Exception ex) {
                processSystemExceptions(ex);
            }
        }

        return ldvInputsToPostResults(sourceItems, postResultsByIds);
    }
    public override List<PostResult> unpost(List<LDVPostInput> sourceItems) {
        Set<Id> processedRecordsIds = new Set<Id>();
        List<Account_Payable_Line__c> processedLines = new List<Account_Payable_Line__c>();
        Map<Id, LDVPostInput> sourceItemsByHeaderIds = new Map<Id, LDVPostInput>();

        for (LDVPostInput item : sourceItems) {
            processedRecordsIds.add(item.id);
            processedLines.addAll((List<Account_Payable_Line__c>)item.lines);
            sourceItemsByHeaderIds.put(item.id, item);
        }

        Map<Id, PostResult> postResultsByIds = new Map<Id, PostResult>();

        this.processedRecordIds = new List<Id>(processedRecordsIds);
        if (!this.processedRecordIds.isEmpty()) {
            try {
                dispatcher.clearResultsMap();
                dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.UNPOST);
                //Initial query for payables
                this.sourceRecords = AccountPayablePostHandler.queryPayables(this.processedRecordIds);
                this.sourceRecords = filterRecordsByAcctMethods(
                        this.sourceRecords,
                        new Set<String>{LedgerActions.ACCOUNTING_METHOD_CASH}
                );
                //weed out unsuitable payables
                filteredRecordsByStatus(DEFAULT_POSTING_STATUS_NOT_POSTED);
                validateAccountingPeriodIsOpen(true);
                validateLedgerTaxSetting(true);

                this.sourceRecords = filterValidRecords(this.sourceRecords);
                validateNoQualifyingUnpostedRecords(AccountPayablePostHandler.NO_SELECTION_UNPOST_ERROR);

                if (!sourceRecords.isEmpty()) {
                    processUnpostAccountPayables(sourceItems);
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

        return ldvInputsToPostResults(sourceItems, postResultsByIds);
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
                this.sourceRecords = AccountPayablePostHandler.queryPayables(this.processedRecordIds);
                this.sourceRecords = filterRecordsByAcctMethods(
                        this.sourceRecords,
                        new Set<String>{LedgerActions.ACCOUNTING_METHOD_CASH}
                );
                this.glAccountDefaults = this.getGLAccountDefaults(this.sourceRecords);
                if (AccountPayablePostHandler.validateAPControlGLAccount(sourceRecords, glAccountDefaults, dispatcher)) {
                    //weed out unsuitable payables
                    validateNotPosted(false);
                    validateStatusApproved(false);
                    validateAccountingPeriodIsOpen(false);
                    validateLedgerType(false, false);
                    validateLedgerTaxSetting(false);
                    this.sourceRecords = AccountPayablePostHandler.validatePayableLinesExist(this.sourceRecords, this.dispatcher, false);
                    validateNoQualifyingPostedRecords();

                    if (!sourceRecords.isEmpty()) {
                        processPostAccountPayables();
                        processPostResult();
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
                this.sourceRecords = AccountPayablePostHandler.queryPayables(this.processedRecordIds);
                this.sourceRecords = filterRecordsByAcctMethods(
                        this.sourceRecords,
                        new Set<String>{LedgerActions.ACCOUNTING_METHOD_CASH}
                );
                validateIsPosted(false);
                validateAccountingPeriodIsOpen(false);
                validateNoQualifyingUnpostedRecords(AccountPayablePostHandler.NO_SELECTION_UNPOST_ERROR);

                if (!sourceRecords.isEmpty()) {
                    processUnpostAccountPayables();
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

    private void processPostAccountPayables() {
        processPostAccountPayables(null);
    }
    private void processPostAccountPayables(List<LDVPostInput> sourceItems) {
        Savepoint sp = Database.setSavepoint();
        try {
            List<SObject> sourceRecords4Update = filterSourceRecords4Update(sourceItems);

            for (Account_Payable__c invoice : (List<Account_Payable__c>) sourceRecords4Update) {
                invoice.Status__c = DEFAULT_POSTING_STATUS_POSTED;
            }
            TriggerObserver.getInstance().unlockField(Account_Payable__c.Status__c);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(new List<Account_Payable__c>((List<Account_Payable__c>) sourceRecords4Update), new List<String>{'Status__c'});
            TriggerObserver.purgeUnlockedFields(Account_Payable__c.Status__c);

            sourceRecords4Update = DomainUtils.getAccountPayablesByIdForUpdate(
                    new Map<Id, SObject>(sourceRecords4Update).keySet()
            );
            validatePostStatusSet(sourceRecords4Update);
        }
        catch (Exception ex) {
            Database.rollback(sp);
            throw ex;
        }
    }

    private void processUnpostAccountPayables() {
        processUnpostAccountPayables(null);
    }
    private void processUnpostAccountPayables(List<LDVPostInput> sourceItems) {
        Savepoint sp = Database.setSavepoint();
        try {
            List<SObject> sourceRecords4Update = filterSourceRecords4Update(sourceItems);
            String defaultPostingStatus = FinancialSuiteUtils.getDefaultPostingStatus(Account_Payable__c.Status__c);

            List<Account_Payable__c> updateAccountPayables = new List<Account_Payable__c>();
            for (Account_Payable__c ap :  (List<Account_Payable__c>) sourceRecords4Update) {
                ap.Status__c = defaultPostingStatus;
                // Issue date field required as of release 3.0.2
                // This ensures for any records to be unposted the issue date is populated if NULL
                ap.Date__c = ap.Date__c == NULL ? System.today() : ap.Date__c;
                updateAccountPayables.add(ap);
            }
            TriggerObserver.getInstance().unlockField(Account_Payable__c.Status__c);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(updateAccountPayables, new List<String>{'Status__c', 'Date__c'});
            TriggerObserver.purgeUnlockedFields(Account_Payable__c.Status__c);
        }
        catch (Exception ex) {
            Database.rollback(sp);
            throw ex;
        }
    }
}