public with sharing class ScheduledRevenueExpensePostHandler extends AbstractPostHandler {

    public static final String NO_SELECTION_POSTED_ERROR_MESSAGE =
        'No qualifying records have been selected. Please ensure records are associated with an accounting period which has a status of "Open" and the record status is "Approved".';
    public static final String NO_SELECTION_UNPOSTED_ERROR_MESSAGE =
        'No qualifying records have been selected. Please ensure records are associated with an accounting period which has a status of "Open" and the record has a status of "Posted".';

    //============================================================================================
    //Post method implementation for Scheduled Revenue Expenses ==================================
    public override List<PostResult> post(List<SObject> processedRecords) {
        Map<Id, Scheduled_Revenue_Expense__c> sreMap = new Map<Id, Scheduled_Revenue_Expense__c>((List<Scheduled_Revenue_Expense__c>) processedRecords);
        return post(new List<Id>(sreMap.keySet()));
    }

    public override List<PostResult> post(List<String> processedRecordsIds) {
        this.processedRecordIds = processedRecordsIds;

        if (!this.processedRecordIds.isEmpty()) {
            try {
                dispatcher.clearResultsMap();
                dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.POST);
                //Initial query for Scheduled Revenue Expenses
                queryScheduledRevenueExpenses();
                //weed out unsuitable Scheduled Revenue Expenses
                validateNotPosted(false);
                validateAccountingPeriodIsOpen(false);
                validateLedgerType(false, false);
                //no need to proceed further if there is no valid Cash Receipts after all validations above
                validateNoQualifyingPostedRecords(ScheduledRevenueExpensePostHandler.NO_SELECTION_POSTED_ERROR_MESSAGE);

                if (!sourceRecords.isEmpty()) {
                    processPostScheduledRevenueExpenses();
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
    //Unpost method implementation for Scheduled Revenue Expenses ==================================
    public override List<PostResult> unpost(List<SObject> processedRecords) {
        Map<Id, Scheduled_Revenue_Expense__c> sreMap = new Map<Id, Scheduled_Revenue_Expense__c>((List<Scheduled_Revenue_Expense__c>) processedRecords);
        return unpost(new List<Id>(sreMap.keySet()));
    }

    public override List<PostResult> unpost(List<String> processedRecordsIds) {
        this.processedRecordIds = processedRecordsIds;

        if (!this.processedRecordIds.isEmpty()) {
            try {
                dispatcher.clearResultsMap();
                dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.UNPOST);
                //Initial query for Scheduled Revenue Expenses
                queryScheduledRevenueExpenses();
                //weed out unsuitable Scheduled Revenue Expenses
                validateIsPosted(false);
                validateAccountingPeriodIsOpen(false);
                //no need to proceed further if there is no valid Scheduled Revenue Expenses after all validations above
                validateNoQualifyingUnpostedRecords(NO_SELECTION_UNPOSTED_ERROR_MESSAGE);
                if (!sourceRecords.isEmpty()) {
                    processUnpostScheduledRevenueExpenses();
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

    private void queryScheduledRevenueExpenses() {
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
            'Accounting_Period__c',
            'Accounting_Period__r.Name',
            'Accounting_Period__r.Status__c',
            'Transaction_Date__c',
            'Status__c',
            'Account2__c',
            'Description__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c',
            'Project__c',
            'Project_Task__c',
            'Debit_GL_Account__c',
            'Credit_GL_Account__c',
            'Product__c',
            'Quantity__c',
            'Amount__c',
            'Accrual_and_or_Cash__c'
        };

        //Add query condition
        String queryCondition = 'Id IN :processedRecordIds FOR UPDATE';
        //Final assembly of SOQL string
        String dynamicSOQL = SOQLBuilder.buildDynamicSoqlQuery(
            fieldsToQuery,
            NULL,
            Scheduled_Revenue_Expense__c.SObjectType,
            queryCondition,
            true,
            false
        );
        //Call DML operation
        sourceRecords = Database.query(dynamicSOQL);
    }

    public void validateBeforePost(List<SObject> processedRecords, Boolean fullStatistics) {
        dispatcher.clearResultsMap();
        dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.POST);
        Map<Id, Scheduled_Revenue_Expense__c> sreMap =
            new Map<Id, Scheduled_Revenue_Expense__c>((List<Scheduled_Revenue_Expense__c>) processedRecords);
        this.processedRecordIds = new List<Id>(sreMap.keySet());
        //Initial query for Scheduled Revenue Expenses
        queryScheduledRevenueExpenses();
        //weed out unsuitable Scheduled Revenue Expenses
        validateAccountingPeriodIsOpen(fullStatistics);
        validateLedgerType(fullStatistics, false);
        validateNotPosted(fullStatistics);
        //add positive results
        processPostResult();
    }

    public void validateBeforeUnpost(List<SObject> processedRecords, Boolean fullStatistics) {
        dispatcher.clearResultsMap();
        dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.UNPOST);
        Map<Id, Scheduled_Revenue_Expense__c> sreMap =
            new Map<Id, Scheduled_Revenue_Expense__c>((List<Scheduled_Revenue_Expense__c>) processedRecords);
        this.processedRecordIds = new List<Id>(sreMap.keySet());
        //Initial query for Scheduled Revenue Expenses
        queryScheduledRevenueExpenses();
        //weed out unsuitable Scheduled Revenue Expenses
        validateIsPosted(fullStatistics);
        validateAccountingPeriodIsOpen(fullStatistics);
        //add positive results
        processPostResult();
    }

    private void processPostScheduledRevenueExpenses() {
        Savepoint sp = Database.setSavepoint();
        try {
            // delete any and all transactions associated with the source document
            // before another set of transactions are created and the status is changed
            TransactionActions.deleteTransactions(TransactionActions.queryTransactions(sourceRecords));
            //=========================================================================================

            Transaction__c[] transList = new List<Transaction__c>();
            Map<Id, Scheduled_Revenue_Expense__c> scheduledRevMap = new Map<Id, Scheduled_Revenue_Expense__c>();

            for (Scheduled_Revenue_Expense__c scheduledRev : (List<Scheduled_Revenue_Expense__c>) sourceRecords) {
                Transaction__c pt = createTransaction(scheduledRev);
                pt.GL_Account__c = scheduledRev.Debit_GL_Account__c;
                pt.Amount__c = scheduledRev.Amount__c;
                pt.Units__c = scheduledRev.Quantity__c;
                pt.Ledger__c = getLedgerId(scheduledRev);
                transList.add(pt);

                // balancing line
                pt = createTransaction(scheduledRev);
                pt.GL_Account__c = scheduledRev.Credit_GL_Account__c;
                pt.Amount__c = scheduledRev.Amount__c * -1;
                pt.Units__c = scheduledRev.Quantity__c != NULL ? (scheduledRev.Quantity__c * -1) : scheduledRev.Quantity__c;
                pt.Ledger__c = getLedgerId(scheduledRev);
                transList.add(pt);

                if (LedgerHandler.getInstanceWithoutSharing().isAccrualAndCashLedger(scheduledRev.Ledger__c)
                    && scheduledRev.Accrual_and_or_Cash__c == LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH) {
                    transList.addAll(getShadowLedgerTransaction(scheduledRev));
                }

                scheduledRev.Status__c = DEFAULT_POSTING_STATUS_POSTED;
                scheduledRevMap.put(scheduledRev.Id, scheduledRev);
            }

            TriggerObserver.getInstance().unlockField(Scheduled_Revenue_Expense__c.Status__c);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(scheduledRevMap.values(), new List<String>{'Status__c'});
            TriggerObserver.purgeUnlockedFields(Scheduled_Revenue_Expense__c.Status__c);

            sourceRecords = DomainUtils.getScheduledRevenueExpensesByIdForUpdate(
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

    private Id getLedgerId(Scheduled_Revenue_Expense__c scheduledRev) {
        Id glLedgerId;
        if (LedgerHandler.getInstanceWithoutSharing().isAccrualAndCashLedger(scheduledRev.Ledger__c)
            && scheduledRev.Accrual_and_or_Cash__c == LedgerActions.ACCOUNTING_METHOD_CASH) {
            glLedgerId = LedgerHandler.getInstanceWithoutSharing().getShadowLedgerByParent(scheduledRev.Ledger__c).Id;
        } else {
            glLedgerId = scheduledRev.Ledger__c != NULL ? scheduledRev.Ledger__c : LedgerHandler.getLegacyDefaultLedgerId();
        }
        return glLedgerId;
    }

    private List<Transaction__c> getShadowLedgerTransaction(Scheduled_Revenue_Expense__c scheduledRev) {
        List<Transaction__c> shadowTrans = new List<Transaction__c>();
        Transaction__c pt = createTransaction(scheduledRev);
        pt.GL_Account__c = scheduledRev.Debit_GL_Account__c;
        pt.Amount__c = scheduledRev.Amount__c;
        pt.Units__c = scheduledRev.Quantity__c;
        pt.Ledger__c = LedgerHandler.getInstanceWithoutSharing().getShadowLedgerByParent(scheduledRev.Ledger__c).Id;
        shadowTrans.add(pt);

        // balancing line
        pt = createTransaction(scheduledRev);
        pt.GL_Account__c = scheduledRev.Credit_GL_Account__c;
        pt.Amount__c = scheduledRev.Amount__c * -1;
        pt.Units__c = scheduledRev.Quantity__c != NULL ? (scheduledRev.Quantity__c * -1) : scheduledRev.Quantity__c;
        pt.Ledger__c = LedgerHandler.getInstanceWithoutSharing().getShadowLedgerByParent(scheduledRev.Ledger__c).Id;
        shadowTrans.add(pt);
        return shadowTrans;
    }

    private Transaction__c createTransaction(Scheduled_Revenue_Expense__c scheduledRev) {
        Transaction__c pt = new Transaction__c();
        pt.Scheduled_Revenue_Expense__c = scheduledRev.Id;
        pt.Account__c = scheduledRev.Account2__c;
        pt.Ledger__c = scheduledRev.Ledger__c != NULL ? scheduledRev.Ledger__c : LedgerHandler.getLegacyDefaultLedgerId();
        pt.Date__c = scheduledRev.Transaction_Date__c != NULL
            ? scheduledRev.Transaction_Date__c
            : AccountingPeriodHandler.getInstance().getAccountingPeriodById(scheduledRev.Accounting_Period__c).Start_Date__c;
        pt.Project_Task__c = scheduledRev.Project_Task__c;
        pt.Project__c = scheduledRev.Project__c;
        pt.Product__c = scheduledRev.Product__c;
        pt.Accounting_Period__c = scheduledRev.Accounting_Period__c;
        pt.GL_Account_Variable_1__c = scheduledRev.GL_Account_Variable_1__c;
        pt.GL_Account_Variable_2__c = scheduledRev.GL_Account_Variable_2__c;
        pt.GL_Account_Variable_3__c = scheduledRev.GL_Account_Variable_3__c;
        pt.GL_Account_Variable_4__c = scheduledRev.GL_Account_Variable_4__c;
        return pt;
    }

    private void processUnpostScheduledRevenueExpenses() {
        Savepoint sp = Database.setSavepoint();
        List<Scheduled_Revenue_Expense__c> updateScheduledRevList = new List<Scheduled_Revenue_Expense__c>();

        try {
            TransactionActions.deleteTransactions(TransactionActions.queryTransactions(sourceRecords));

            String defaultPostingStatus = FinancialSuiteUtils.getDefaultPostingStatus(Scheduled_Revenue_Expense__c.Status__c);

            for (Scheduled_Revenue_Expense__c scheduledRev : (List<Scheduled_Revenue_Expense__c>) sourceRecords) {
                if (scheduledRev.Status__c == DEFAULT_POSTING_STATUS_POSTED) {
                    scheduledRev.Status__c = defaultPostingStatus;
                    updateScheduledRevList.add(scheduledRev);
                }
            }

            TriggerObserver.getInstance().unlockField(Scheduled_Revenue_Expense__c.Status__c);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(updateScheduledRevList, new List<String>{'Status__c'});
            TriggerObserver.purgeUnlockedFields(Scheduled_Revenue_Expense__c.Status__c);
        }
        catch (DMLException ex) {
            Database.rollback(sp);
            throw ex;
        }
    }

    //Accessible and FLS checks are performed in Visualforce page for the records retrieved from this method.
    public List<Transaction__c> getForecastedTransactions() {

        if (dispatcher.getExecutionContext() == PostResultDispatcher.ExecutionContext.POST) {

            List<Transaction__c> transList = new List<Transaction__c>();
            for (Scheduled_Revenue_Expense__c scheduledRev : (List<Scheduled_Revenue_Expense__c>) sourceRecords) {
                Transaction__c pt = createTransaction(scheduledRev);
                pt.GL_Account__c = scheduledRev.Debit_GL_Account__c;
                pt.Amount__c = scheduledRev.Amount__c;
                pt.Ledger__c = getLedgerId(scheduledRev);
                transList.add(pt);

                // balancing line
                pt = createTransaction(scheduledRev);
                pt.GL_Account__c = scheduledRev.Credit_GL_Account__c;
                pt.Amount__c = scheduledRev.Amount__c * -1;
                pt.Ledger__c = getLedgerId(scheduledRev);
                transList.add(pt);

                if (LedgerHandler.getInstanceWithoutSharing().isAccrualAndCashLedger(scheduledRev.Ledger__c)
                        && scheduledRev.Accrual_and_or_Cash__c == LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH) {
                    transList.addAll(getShadowLedgerTransaction(scheduledRev));
                }
            }

            if (IS_MULTI_CURRENCY_ENABLED) {
                transList = setLedgerIsoCodeToTransactions(transList);
            }
            return transList;

        }
        else {

            List<String> queryFields = new List<String>{
                'Id',
                'Name',
                'Ledger__c',
                'GL_Account__c',
                'Amount__c',
                'Project__c',
                'Project_Task__c',
                'GL_Account_Variable_1__c',
                'GL_Account_Variable_2__c',
                'GL_Account_Variable_3__c',
                'GL_Account_Variable_4__c'
            };

            String queryCondition = 'Scheduled_Revenue_Expense__c IN :sourceRecords';

            SOQLBuilder theQuery = new SOQLBuilder(Transaction__c.SObjectType);
            theQuery
                .setEnforceFLS(false)
                .selectFields(queryFields)
                .setCondition(queryCondition);

            return (List<Transaction__c>) Database.query(theQuery.toSOQL());
        }

    }

}