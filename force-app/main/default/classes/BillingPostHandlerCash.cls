public with sharing class BillingPostHandlerCash extends AbstractPostHandler {
    // =========== LDV Support ===========================

    public override List<PostResult> post(List<LDVPostInput> sourceItems) {
        Set<Id> processedRecordsIds = new Set<Id>();
        List<Billing_Line__c> processedLines = new List<Billing_Line__c>();
        Map<Id, LDVPostInput> sourceItemsByHeaderIds = new Map<Id, LDVPostInput>();

        for (LDVPostInput item : sourceItems) {
            processedRecordsIds.add(item.id);
            processedLines.addAll((List<Billing_Line__c>)item.lines);
            sourceItemsByHeaderIds.put(item.id, item);
        }

        Map<Id, PostResult> postResultsByIds = new Map<Id, PostResult>();

        this.processedRecordIds = new List<Id>(processedRecordsIds);
        if (!this.processedRecordIds.isEmpty()) {
            try {
                dispatcher.clearResultsMap();
                dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.POST);
                //Initial query for billings
                this.sourceRecords = BillingPostHandler.queryBillings(this.processedRecordIds);
                this.sourceRecords = filterRecordsByAcctMethods(
                        this.sourceRecords,
                        new Set<String>{LedgerActions.ACCOUNTING_METHOD_CASH}
                );
                this.glAccountDefaults = this.getGLAccountDefaults(this.sourceRecords);
                if (BillingPostHandler.validateARControlGLAccount(sourceRecords, glAccountDefaults, dispatcher)) {
                    //weed out the unsuitable billings
                    filteredRecordsByStatus(DEFAULT_POSTING_STATUS_POSTED);
                    validateNotPosted(true);
                    validateAccountingPeriodIsOpen(true);
                    validateLedgerType(true, true);
                    validateLedgerTaxSetting(true);
                    //validate all billings have billing lines
                    this.sourceRecords = BillingPostHandler.validateBillingLinesExist(this.sourceRecords, this.dispatcher, true);

                    this.sourceRecords = filterValidRecords(this.sourceRecords);
                    //no need to proceed further if there is no valid Billings after all validations above
                    validateNoQualifyingPostedRecords();

                    if (!sourceRecords.isEmpty()) {
                        processPostBillings(sourceItems);
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
        List<Billing_Line__c> processedLines = new List<Billing_Line__c>();
        Map<Id, LDVPostInput> sourceItemsByHeaderIds = new Map<Id, LDVPostInput>();

        for (LDVPostInput item : sourceItems) {
            processedRecordsIds.add(item.id);
            processedLines.addAll((List<Billing_Line__c>)item.lines);
            sourceItemsByHeaderIds.put(item.id, item);
        }

        Map<Id, PostResult> postResultsByIds = new Map<Id, PostResult>();

        this.processedRecordIds = new List<Id>(processedRecordsIds);
        if (!this.processedRecordIds.isEmpty()) {
            try {
                dispatcher.clearResultsMap();
                dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.UNPOST);
                //Initial query for billings
                this.sourceRecords = BillingPostHandler.queryBillings(this.processedRecordIds);
                this.sourceRecords = filterRecordsByAcctMethods(
                        this.sourceRecords,
                        new Set<String>{LedgerActions.ACCOUNTING_METHOD_CASH}
                );
                //weed out the unsuitable billings
                filteredRecordsByStatus(DEFAULT_POSTING_STATUS_NOT_POSTED);
                validateAccountingPeriodIsOpen(true);
                validateLedgerTaxSetting(true);

                this.sourceRecords = filterValidRecords(this.sourceRecords);
                //no need to proceed further if there is no valid Billings after all validations above
                validateNoQualifyingUnpostedRecords(BillingPostHandler.NO_SELECTION_UNPOSTED_ERROR_MESSAGE);

                if (!sourceRecords.isEmpty()) {
                    processUnpostBillings(sourceItems);
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

    //Post method implementation for Billings ====================================================
    public override List<PostResult> post(List<SObject> processedRecords) {
        Map<Id, Billing__c> billingsMap = new Map<Id, Billing__c>((List<Billing__c>) processedRecords);
        return post(new List<Id>(billingsMap.keySet()));
    }
    public override List<PostResult> post(List<String> processedRecordsIds) {
        this.processedRecordIds = processedRecordsIds;

        if (!this.processedRecordIds.isEmpty()) {
            try {
                dispatcher.clearResultsMap();
                dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.POST);
                //Initial query for billings
                this.sourceRecords = BillingPostHandler.queryBillings(this.processedRecordIds);
                this.sourceRecords = filterRecordsByAcctMethods(
                        this.sourceRecords,
                        new Set<String>{LedgerActions.ACCOUNTING_METHOD_CASH}
                );
                this.glAccountDefaults = this.getGLAccountDefaults(this.sourceRecords);
                if (BillingPostHandler.validateARControlGLAccount(sourceRecords, glAccountDefaults, dispatcher)) {
                    //weed out the unsuitable billings
                    validateNotPosted(false);
                    validateStatusApproved(false);
                    validateAccountingPeriodIsOpen(false);
                    validateLedgerType(false, false);
                    validateLedgerTaxSetting(false);
                    //validate all billings have billing lines
                    this.sourceRecords = BillingPostHandler.validateBillingLinesExist(this.sourceRecords, this.dispatcher, false);

                    //no need to proceed further if there is no valid Billings after all validations above
                    validateNoQualifyingPostedRecords();

                    if (!sourceRecords.isEmpty()) {
                        processPostBillings();
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

        return dispatcher.getPostResults();
    }
    //===========================================================================================
    //UnPost method implementation for Billings =================================================
    public override List<PostResult> unpost(List<SObject> processedRecords) {
        Map<Id, Billing__c> billingsMap = new Map<Id, Billing__c>((List<Billing__c>) processedRecords);
        return unpost(new List<Id>(billingsMap.keySet()));
    }
    public override List<PostResult> unpost(List<String> processedRecordsIds) {
        this.processedRecordIds = processedRecordsIds;

        if (!this.processedRecordIds.isEmpty()) {
            try {
                dispatcher.clearResultsMap();
                dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.UNPOST);
                //Initial query for billings
                this.sourceRecords = BillingPostHandler.queryBillings(this.processedRecordIds);
                this.sourceRecords = filterRecordsByAcctMethods(
                        this.sourceRecords,
                        new Set<String>{LedgerActions.ACCOUNTING_METHOD_CASH}
                );
                //weed out the unsuitable billings
                validateIsPosted(false);
                validateAccountingPeriodIsOpen(false);
                validateLedgerTaxSetting(false);
                //no need to proceed further if there is no valid Billings after all validations above
                validateNoQualifyingUnpostedRecords(BillingPostHandler.NO_SELECTION_UNPOSTED_ERROR_MESSAGE);

                if (!sourceRecords.isEmpty()) {
                    processUnpostBillings();
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
    private void processPostBillings() {
        processPostBillings(null);
    }
    private void processPostBillings(List<LDVPostInput> sourceItems) {

        Savepoint sp;
        if(!Test.isRunningTest()) {
            sp = Database.setSavepoint();
        }

        try {
            List<SObject> sourceRecords4Update = filterSourceRecords4Update(sourceItems);

            for (Billing__c billing : (List<Billing__c>) sourceRecords4Update) {
                billing.Status__c = DEFAULT_POSTING_STATUS_POSTED;
            }

            TriggerObserver.getInstance().unlockField(Billing__c.Status__c);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(new List<Billing__c>((List<Billing__c>) sourceRecords4Update), new List<String>{'Status__c'});
            TriggerObserver.purgeUnlockedFields(Billing__c.Status__c);

            sourceRecords4Update = DomainUtils.getBillingsByIdForUpdate(new Map<Id, SObject>(sourceRecords4Update).keySet());
            validatePostStatusSet(sourceRecords4Update);
        }
        catch (Exception ex) {
            Database.rollback(sp);
            throw ex;
        }
    }

    private void processUnpostBillings() {
        processUnpostBillings(null);
    }
    private void processUnpostBillings(List<LDVPostInput> sourceItems) {
        Savepoint sp;
        if(!Test.isRunningTest()) {
            sp = Database.setSavepoint();
        }
        try {
            List<SObject> sourceRecords4Update = filterSourceRecords4Update(sourceItems);
            String defaultPostingStatus = FinancialSuiteUtils.getDefaultPostingStatus(Billing__c.Status__c);

            List<Billing__c> updateBillings = new List<Billing__c>();
            for (Billing__c bill : (List<Billing__c>) sourceRecords4Update) {
                bill.Status__c = defaultPostingStatus;
                updateBillings.add(bill);

                // Legacy update to the due date field to allow for unposting the record
                if (bill.Due_Date2__c == NULL && bill.Date__c != NULL) {
                    bill.Due_Date2__c = bill.Date__c;
                }
            }

            TriggerObserver.getInstance().unlockFields(new Set<SObjectField> {Billing__c.Status__c});
            SFDCSecurityUtils.updateCheckCRUDAndFLS(updateBillings, new List<String>{'Status__c'});
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField> {Billing__c.Status__c});
        }
        catch (Exception ex) {
            Database.rollback(sp);
            throw ex;
        }
    }
}