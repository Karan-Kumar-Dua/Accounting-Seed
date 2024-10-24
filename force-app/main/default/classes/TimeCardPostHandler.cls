public with sharing class TimeCardPostHandler extends AbstractPostHandler {

    private static final Integer DAY_COUNT_LIMIT = 1000;

    public static final String NO_APPROVED_SELECTION_MESSAGE =
        Label.ERR_NO_APPROVED_SELECTION;
    public static final String CLOSED_ACCOUNTING_PERIOD_ERROR_MESSAGE = Label.ERR_CLOSED_ACCOUNTING_PERIOD_TIME_CARD;
    public static final String NO_POSTED_SELECTION_MESSAGE =
        Label.ERR_NO_POSTED_SELECTION;
    public static final String NO_LABOR_CONTROL_ACCOUNT_DEFINED_ERROR_MESSAGE =
        Label.ERR_NO_LABOR_CONTROL_ACCOUNT_DEFINED;
    public static final String NO_TASK_EXPENSE_ACCOUNT_DEFINED_ERROR_MESSAGE =
        Label.ERR_NO_TASK_EXPENSE_ACCOUNT_DEFINED;
    public static final String DAY_COUNT_ERROR_MESSAGE =
        Label.ERR_CANNOT_POST_MORE_THAN + DAY_COUNT_LIMIT + Label.ERR_TIME_CARD_POST_REQUEST_SMALLER_NUMBER;
    public static final String ONLY_ACTUAL_TIME_CARD_ALLOW_ERROR_MESSAGE = Label.ERR_ONLY_ACTUAL_TIME_CARD_ALLOW;

    //================================================================+============================
    //=================== POST method implementation for Time Cards ===============================
    public override List<PostResult> post(List<SObject> processedRecords) {
        Map<Id, Time_Card__c> timeCardMap = new Map<Id, Time_Card__c>((List<Time_Card__c>) processedRecords);
        return post(new List<Id>(timeCardMap.keySet()));
    }

    public override List<PostResult> post(List<String> processedRecordsIds) {
        this.processedRecordIds = processedRecordsIds;

        if (!this.processedRecordIds.isEmpty()) {
            try {
                dispatcher.clearResultsMap();
                dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.POST);
                //Initial query for Time Cards
                queryTimeCards();//Time Cards will be stored in the 'sourceRecords' property
                //weed out unsuitable Time Cards
                getGLAccountDefaults();
                validateLaborGLAccount();
                validateType(false);
                validateNotPosted(false);
                validateStatusApproved(false);
                validateLedgerType(false, false);
                validateOnlyOpenAccountingPeriodsInTimeCardPeriodScope(false);
                //no need to proceed further if there is no valid Time Cards after all validations above
                validateNoQualifyingPostedRecords(NO_APPROVED_SELECTION_MESSAGE);

                if (!sourceRecords.isEmpty()) {
                    queryTimeCardDays();//Time Cards Days will be stored in the 'sourceRecordLines' property
                    validateTaskExpenseGLAccount(false);
                    if (validateDaysCount()) {
                        processPostTimeCards();
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

        return dispatcher.getPostResults();
    }

    //===============================================================================================
    //=================== UNPOST method implementation for Time Cards ===============================
    public override List<PostResult> unpost(List<SObject> processedRecords) {
        Map<Id, Time_Card__c> timeCardMap = new Map<Id, Time_Card__c>((List<Time_Card__c>) processedRecords);
        return unpost(new List<Id>(timeCardMap.keySet()));
    }

    public override List<PostResult> unpost(List<String> processedRecordsIds) {
        this.processedRecordIds = processedRecordsIds;

        if (!this.processedRecordIds.isEmpty()) {
            try {
                dispatcher.clearResultsMap();
                dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.UNPOST);
                //Initial query for Time Cards
                queryTimeCards();//Time Cards will be stored in the 'sourceRecords' property
                //weed out unsuitable Time Cards
                validateIsPosted(false);
                validateOnlyOpenAccountingPeriodsInTimeCardPeriodScope(false);
                //no need to proceed further if there is no valid Scheduled Revenue Expenses after all validations above
                validateNoQualifyingUnpostedRecords(NO_POSTED_SELECTION_MESSAGE);

                if (!sourceRecords.isEmpty()) {
                    queryTimeCardDays();//Time Cards Days will be stored in the 'sourceRecordLines' property
                    processUnpostTimeCards();
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

    //=============================================================================================
    //========================== Retrieve data from DB ============================================
    private void queryTimeCards() {
        //Select fields
        List<String> fieldsToQuery = new List<String> {
            'Id',
            'Name',
            'Status__c',
            'Time_Card_Period__c',
            'Time_Card_Period__r.Name',
            'Day_Count__c',
            'Employee__r.Name',
            'Employee__c',
            'Total_Hours__c',
            'Ledger__c',
            'Ledger__r.Name',
            'Ledger__r.Type__c',
            'Type__c'
        };
        //Add query condition
        String queryCondition = 'Id IN :processedRecordIds FOR UPDATE';
        //Final assembly of SOQL string
        String dynamicSOQL = SOQLBuilder.buildDynamicSoqlQuery(
            fieldsToQuery,
            NULL,
            Time_Card__c.SObjectType,
            queryCondition,
            true,
            false
        );
        //Call DML operation
        sourceRecords = Database.query(dynamicSOQL);
    }

    private void queryTimeCardDays() {
        //Select fields
        List<String> fieldsToQuery = new List<String> {
            'Id',
            'Hours__c',
            'Date__c',
            'Time_Card_Line__r.Project__c',
            'Time_Card_Line__r.Project_Task__c',
            'Time_Card_Line__r.Time_Card__r.Time_Card_Period__r.Start_Date__c',
            'Time_Card_Line__r.Project_Task__r.GL_Account_Variable_1__c',
            'Time_Card_Line__r.Project_Task__r.GL_Account_Variable_2__c',
            'Time_Card_Line__r.Project_Task__r.GL_Account_Variable_3__c',
            'Time_Card_Line__r.Project_Task__r.GL_Account_Variable_4__c',
            'Time_Card_Line__r.Billable__c',
            'Time_Card_Line__r.Overtime__c',
            'Time_Card_Line__r.Time_Card__c',
            'Time_Card_Line__r.Time_Card__r.Name',
            'Time_Card_Line__r.Time_Card__r.Employee__c',
            'Time_Card_Line__r.Time_Card__r.Ledger__c',
            'Time_Card_Line__r.Project_Task__r.Labor_GL_Account__c',
            'Time_Card_Line__r.Project_Task__r.Name',
            'Time_Card_Line__r.Time_Card_Variable_1__c',
            'Time_Card_Line__r.Time_Card_Variable_2__c',
            'Time_Card_Line__r.Total_Hours__c',
            'Time_Card_Line__r.Time_Card__r.Total_Hours__c',
            'Time_Card_Line__r.Time_Card__r.Time_Card_Period__c'
        };
        //Add query condition
        String queryCondition = 'Time_Card_Line__r.Time_Card__c IN :sourceRecords LIMIT 1001 FOR UPDATE';
        //Final assembly of SOQL string
        String dynamicSOQL = SOQLBuilder.buildDynamicSoqlQuery(
            fieldsToQuery,
            NULL,
            Time_Card_Day__c.SObjectType,
            queryCondition,
            false,
            false
        );
        //Call DML operation
        sourceRecordLines = Database.query(dynamicSOQL);
    }

    private List<Time_Card_Accounting_Period__c> queryTimeCardAccountingPeriod(Set<Id> timeCardPeriodIds) {
        //Select fields
        List<String> fieldsToQuery = new List<String> {
            'Id',
            'Time_Card_Period__c',
            'Time_Card_Period__r.Name',
            'Accounting_Period__c',
            'Accounting_Period__r.Name',
            'Accounting_Period__r.Start_Date__c',
            'Accounting_Period__r.End_Date__c',
            'Accounting_Period__r.Status__c'
        };
        //Add query condition
        String queryCondition = 'Time_Card_Period__c IN :timeCardPeriodIds FOR UPDATE';
        //Final assembly of SOQL string
        String dynamicSOQL = SOQLBuilder.buildDynamicSoqlQuery(
            fieldsToQuery,
            NULL,
            Time_Card_Accounting_Period__c.SObjectType,
            queryCondition,
            false,
            false
        );
        //Call DML operation
        return (List<Time_Card_Accounting_Period__c>) Database.query(dynamicSOQL);
    }

    private List<Cost_Rates__c> queryCostRates(Set<Id> employeeIdSet) {
        //Select fields
        List<String> fieldsToQuery = new List<String> {
            'Id',
            'Name',
            'Employee__c',
            'Hourly_Cost__c',
            'Overtime_Hourly_Cost__c',
            'Weekly_Salary_Cost__c',
            'Project__c',
            'Project_Task__c'
        };
        //Add query condition
        String queryCondition = 'Employee__c IN :employeeIdSet FOR UPDATE';
        //Final assembly of SOQL string
        String dynamicSOQL = SOQLBuilder.buildDynamicSoqlQuery(
            fieldsToQuery,
            NULL,
            Cost_Rates__c.SObjectType,
            queryCondition,
            false,
            false
        );
        //Call DML operation
        return (List<Cost_Rates__c>) Database.query(dynamicSOQL);
    }

    //=============================================================================================
    //========================== Validation methods ===============================================
    public void validateBeforePost(List<SObject> processedRecords, Boolean fullStatistics) {
        dispatcher.clearResultsMap();
        dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.POST);
        Map<Id, Time_Card__c> timeCardMap = new Map<Id, Time_Card__c>((List<Time_Card__c>) processedRecords);
        this.processedRecordIds = new List<Id>(timeCardMap.keySet());

        //Initial query for Time Cards
        queryTimeCards();//Time Cards will be stored in the 'sourceRecords' property
        //weed out unsuitable Time Cards
        getGLAccountDefaults();
        validateLaborGLAccount();
        validateType(fullStatistics);
        validateNotPosted(fullStatistics);
        validateStatusApproved(fullStatistics);
        validateLedgerType(fullStatistics, false);
        validateOnlyOpenAccountingPeriodsInTimeCardPeriodScope(fullStatistics);
        if (!sourceRecords.isEmpty()) {
            queryTimeCardDays();//Time Cards Days will be stored in the 'sourceRecordLines' property
            validateTaskExpenseGLAccount(fullStatistics);
            validateDaysCount();
        }
        //add positive results
        processPostResult();
    }

    public void validateBeforeUnpost(List<SObject> processedRecords, Boolean fullStatistics) {
        dispatcher.clearResultsMap();
        dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.UNPOST);
        Map<Id, Time_Card__c> timeCardMap = new Map<Id, Time_Card__c>((List<Time_Card__c>) processedRecords);
        this.processedRecordIds = new List<Id>(timeCardMap.keySet());
        //Initial query for Time Cards
        queryTimeCards();//Time Cards will be stored in the 'sourceRecords' property
        //weed out unsuitable Time Cards
        validateIsPosted(fullStatistics);
        validateOnlyOpenAccountingPeriodsInTimeCardPeriodScope(fullStatistics);
        //add positive results
        processPostResult();
    }

    private void validateType(Boolean fullStatistics) {
        List<Time_Card__c> validTimeCards = new List<Time_Card__c>();
        for (Time_Card__c timeCard : (List<Time_Card__c>) sourceRecords) {
            if (timeCard.Type__c != NULL && timeCard.Type__c != TimeCardActions.TYPE_VALUE_ACTUAL) {
                dispatcher.addPostErrorResult(
                    timeCard,
                    new PostResult.PostErrorResult(
                        timeCard,
                        PostResult.StatusCode.ONLY_ACTUAL_TIME_CARD_ALLOW,
                        ONLY_ACTUAL_TIME_CARD_ALLOW_ERROR_MESSAGE
                    )
                );
            }
            else {
                validTimeCards.add(timeCard);
            }
        }

        if (!fullStatistics) {
            sourceRecords = validTimeCards;
        }
    }

    private Boolean validateLaborGLAccount() {
        Boolean isValid = true;
        for (Time_Card__c timeCard : (List<Time_Card__c>) sourceRecords) {
            if (!glAccountDefaults.containsKey(timeCard.Ledger__c) ||
                (glAccountDefaults.containsKey(timeCard.Ledger__c)
                    && !glAccountDefaults.get(timeCard.Ledger__c).containsKey(GLAccountDefaultsHandler.LABOR_GL_ACCOUNT))) {
                dispatcher.addPostErrorResult(
                    timeCard,
                    new PostResult.PostErrorResult(
                        timeCard,
                        PostResult.StatusCode.NO_LABOR_CONTROL_ACCOUNT_DEFINED,
                        NO_LABOR_CONTROL_ACCOUNT_DEFINED_ERROR_MESSAGE
                    )
                );
                isValid = false;
            }
        }
        return isValid;
    }

    private void validateTaskExpenseGLAccount(Boolean fullStatistics) {
        List<Time_Card__c> validTimeCards = new List<Time_Card__c>();
        Map<Id, Time_Card__c> nonValidTimeCards = new Map<Id, Time_Card__c>();
        Map<Id, Project_Task__c> timeCardIdToProjectTask = new Map<Id, Project_Task__c>();
        for (Time_Card_Day__c timeCardDay : (List<Time_Card_Day__c>) sourceRecordLines) {
            if (timeCardDay.Time_Card_Line__r.Project_Task__r.Labor_GL_Account__c == NULL) {
                nonValidTimeCards.put(timeCardDay.Time_Card_Line__r.Time_Card__c, timeCardDay.Time_Card_Line__r.Time_Card__r);
                timeCardIdToProjectTask.put(timeCardDay.Time_Card_Line__r.Time_Card__c, timeCardDay.Time_Card_Line__r.Project_Task__r);
            }
        }

        for (Time_Card__c timeCard : (List<Time_Card__c>) sourceRecords) {
            if (nonValidTimeCards.containsKey(timeCard.Id)) {
                dispatcher.addPostErrorResult(
                    timeCard,
                    new PostResult.PostErrorResult(
                        timeCardIdToProjectTask.get(timeCard.Id),
                        PostResult.StatusCode.NO_TASK_EXPENSE_GL_ACCOUNT_DEFINED,
                        NO_TASK_EXPENSE_ACCOUNT_DEFINED_ERROR_MESSAGE
                    )
                );
            }
            else {
                validTimeCards.add(timeCard);
            }
        }

        if (!fullStatistics) {
            sourceRecords = validTimeCards;
        }
    }

    private void validateOnlyOpenAccountingPeriodsInTimeCardPeriodScope(Boolean fullStatistics) {
        List<Time_Card__c> validTimeCards = new List<Time_Card__c>();
        Set<Id> timeCardPeriodIds = new Set<Id>();
        Map<Id, List<Accounting_Period__c>> timeCardPeriodIdToClosedAccountingPeriods = new Map<Id, List<Accounting_Period__c>>();

        for (Time_Card__c timeCard : (List<Time_Card__c>) sourceRecords) {
            timeCardPeriodIds.add(timeCard.Time_Card_Period__c);
        }

        //Open Accounting Period check
        for (Time_Card_Accounting_Period__c tcAcctPeriod : queryTimeCardAccountingPeriod(timeCardPeriodIds)) {
            if (tcAcctPeriod.Accounting_Period__r.Status__c != AccountingPeriodActions.OPEN_STATUS) {
                if (timeCardPeriodIdToClosedAccountingPeriods.containsKey(tcAcctPeriod.Time_Card_Period__c)) {
                    timeCardPeriodIdToClosedAccountingPeriods
                        .get(tcAcctPeriod.Time_Card_Period__c)
                        .add(tcAcctPeriod.Accounting_Period__r);
                }
                else {
                    timeCardPeriodIdToClosedAccountingPeriods
                        .put(tcAcctPeriod.Time_Card_Period__c, new List<Accounting_Period__c>{tcAcctPeriod.Accounting_Period__r});
                }
            }
        }

        for (Time_Card__c timeCard : (List<Time_Card__c>) sourceRecords) {
            if (timeCardPeriodIdToClosedAccountingPeriods.containsKey(timeCard.Time_Card_Period__c)) {
                dispatcher.addPostErrorResult(
                    timeCard,
                    new PostResult.PostErrorResult(
                        timeCardPeriodIdToClosedAccountingPeriods.get(timeCard.Time_Card_Period__c)[0],
                        PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD,
                        CLOSED_ACCOUNTING_PERIOD_ERROR_MESSAGE
                    )
                );
            }
            else {
                validTimeCards.add(timeCard);
            }
        }

        if (!fullStatistics) {
            sourceRecords = validTimeCards;
        }
    }

    private Boolean validateDaysCount() {
        Integer lineCount = sourceRecordLines.size();

        if (lineCount > DAY_COUNT_LIMIT) {
            for (Time_Card__c timeCard : (List<Time_Card__c>) sourceRecords) {
                dispatcher.addPostErrorResult(
                    timeCard,
                    new PostResult.PostErrorResult(
                        timeCard,
                        PostResult.StatusCode.LINE_COUNT_LIMIT_EXCEEDED,
                        DAY_COUNT_ERROR_MESSAGE
                    )
                );
            }
            return false;
        }
        else {
            return true;
        }
    }
    //=============================================================================================
    //========================== POST processing ==================================================
    public void processPostTimeCards() {
        Savepoint sp = Database.setSavepoint();
        Boolean isLegacyTimeCards = false;
        try {
            // delete any and all transactions associated with the source document
            // before another set of transactions are created and the status is changed
            TransactionActions.deleteTransactions(TransactionActions.queryTransactions(sourceRecordLines));
            //=========================================================================================

            Map<Id, Time_Card__c> processTimeCardMap = new Map<Id, Time_Card__c>();
            List<Transaction__c> transList = new List<Transaction__c>();
            Map<Id, Time_Card_Day__c> timeDayMap = new Map<Id, Time_Card_Day__c>();
            Map<String, Cost_Rates__c> timeResourceCostMap = new Map<String, Cost_Rates__c>();
            Set<Id> employeeIdSet = new Set<Id>();
            Set<Id> timeCardPeriodSet = new Set<Id>();
            Map<Id, List<Time_Card_Accounting_Period__c>> timeCardProjectPeriods = new Map<Id, List<Time_Card_Accounting_Period__c>>();

            for (Time_Card__c timeCard : (List<Time_Card__c>) sourceRecords) {
                timeCard.Status__c = DEFAULT_POSTING_STATUS_POSTED;
                processTimeCardMap.put(timeCard.Id, timeCard);
                employeeIdSet.add(timeCard.Employee__c);
                timeCardPeriodSet.add(timeCard.Time_Card_Period__c);
                if (!isLegacyTimeCards && timeCard.Type__c == NULL) {
                    isLegacyTimeCards = true;
                }
            }

            List<Time_Card_Accounting_Period__c> timeCardAccountingPeriods = queryTimeCardAccountingPeriod(timeCardPeriodSet);

            for (Time_Card_Accounting_Period__c timeCardAccountingPeriod : timeCardAccountingPeriods) {
                if (timeCardProjectPeriods.containsKey(timeCardAccountingPeriod.Time_Card_Period__c)) {
                    timeCardProjectPeriods.get(timeCardAccountingPeriod.Time_Card_Period__c).add(timeCardAccountingPeriod);
                }
                else {
                    timeCardProjectPeriods.put(timeCardAccountingPeriod.Time_Card_Period__c, new List<Time_Card_Accounting_Period__c>{timeCardAccountingPeriod});
                }
            }

            timeResourceCostMap = getAllCostRates(employeeIdSet);

            for (Time_Card_Day__c timeCardDay : (List<Time_Card_Day__c>) sourceRecordLines) {

                if (timeCardDay.Hours__c == NULL) {
                    continue;
                }

                Id acctPeriodId = findAccountingPeriod(timeCardDay, timeCardProjectPeriods.get(timeCardDay.Time_Card_Line__r.Time_Card__r.Time_Card_Period__c));

                Cost_Rates__c rc = getCostRateByTimeCardLine(timeResourceCostMap, timeCardDay.Time_Card_Line__r);
                Decimal amount = 0;

                if (rc != NULL && timeCardDay.Time_Card_Line__r.Overtime__c && rc.Overtime_Hourly_Cost__c != NULL && rc.Hourly_Cost__c != NULL) {
                    amount = rc.Overtime_Hourly_Cost__c * timeCardDay.Hours__c;
                }
                else if (rc != NULL && rc.Hourly_Cost__c != NULL) {
                    amount = rc.Hourly_Cost__c * timeCardDay.Hours__c;
                }
                else if (rc != NULL && rc.Weekly_Salary_Cost__c != NULL && timeCardDay.Hours__c != NULL) {
                    Decimal hourlyRate = rc.Weekly_Salary_Cost__c / timeCardDay.Time_Card_Line__r.Time_Card__r.Total_Hours__c;
                    amount = hourlyRate * timeCardDay.Hours__c;
                }

                Transaction__c pt = createTransaction(
                    timeCardDay,
                    timeCardDay.Time_Card_Line__r.Project_Task__r.Labor_GL_Account__c,
                    acctPeriodId,
                    amount
                );

                transList.add(pt);
                timeDayMap.put(timeCardDay.Id, timeCardDay);

                Transaction__c balancingPt = createTransaction(
                    timeCardDay,
                    glAccountDefaults.get(timeCardDay.Time_Card_Line__r.Time_Card__r.Ledger__c).get(GLAccountDefaultsHandler.LABOR_GL_ACCOUNT).GL_Account__c,
                    acctPeriodId,
                    (amount * -1)
                );

                transList.add(balancingPt);
            }

            //Update Time Card Days
            //Why we need that?
            SFDCSecurityUtils.updateCheckCRUDAndFLS(
                timeDayMap.values(),
                new List<String>()
            );

            //Update Time Cards to change their Status field
            TriggerObserver.getInstance().unlockField(Time_Card__c.Status__c);
            if (isLegacyTimeCards) {
                TriggerObserver.getInstance().unlockField(Time_Card__c.Type__c);
            }
            SFDCSecurityUtils.updateCheckCRUDAndFLS(
                processTimeCardMap.values(),
                new List<String>{
                    'Status__c'
                }
            );
            TriggerObserver.purgeUnlockedFields(Time_Card__c.Status__c);

            sourceRecords = DomainUtils.getTimeCardsByIdForUpdate(
                new Map<Id, SObject>(sourceRecords).keySet()
            ); 
            validatePostStatusSet();

            //Create Transactions in DB
            TransactionActions.createTransactions(transList);
        }
        catch (Exception ex) {
            Database.rollback(sp);
            throw ex;
        }
    }

    private Transaction__c createTransaction(Time_Card_Day__c timeCardDay, Id glAccountId, Id acctPeriodId, Decimal amount) {
        Transaction__c trans = new Transaction__c();
        trans.Time_Card_Day__c = timeCardDay.Id;
        trans.Date__c = timeCardDay.Date__c;
        trans.Ledger__c = timeCardDay.Time_Card_Line__r.Time_Card__r.Ledger__c != NULL ?
                timeCardDay.Time_Card_Line__r.Time_Card__r.Ledger__c : LedgerHandler.getLegacyDefaultLedgerId();
        trans.Project_Task__c = timeCardDay.Time_Card_Line__r.Project_Task__c;
        trans.Project__c = timeCardDay.Time_Card_Line__r.Project__c;
        trans.GL_Account__c = glAccountId;
        trans.GL_Account_Variable_1__c = timeCardDay.Time_Card_Line__r.Project_Task__r.GL_Account_Variable_1__c;
        trans.GL_Account_Variable_2__c = timeCardDay.Time_Card_Line__r.Project_Task__r.GL_Account_Variable_2__c;
        trans.GL_Account_Variable_3__c = timeCardDay.Time_Card_Line__r.Project_Task__r.GL_Account_Variable_3__c;
        trans.GL_Account_Variable_4__c = timeCardDay.Time_Card_Line__r.Project_Task__r.GL_Account_Variable_4__c;
        trans.Employee__c = timeCardDay.Time_Card_Line__r.Time_Card__r.Employee__c;
        trans.Time_Card_Variable_1__c = timeCardDay.Time_Card_Line__r.Time_Card_Variable_1__c;
        trans.Time_Card_Variable_2__c = timeCardDay.Time_Card_Line__r.Time_Card_Variable_2__c;
        trans.Amount__c = amount;
        trans.Units__c = timeCardDay.Hours__c;
        trans.Accounting_Period__c = acctPeriodId;
        return trans;
    }

    @TestVisible
    private Id findAccountingPeriod(Time_Card_Day__c timeCardDay, List<Time_Card_Accounting_Period__c> timeCardAccountingPeriods) {
        Id result;
        for (Time_Card_Accounting_Period__c period : timeCardAccountingPeriods) {
            if (timeCardDay.Date__c <= period.Accounting_Period__r.End_Date__c
                && timeCardDay.Date__c >= period.Accounting_Period__r.Start_Date__c) {

                result = period.Accounting_Period__c;
                break;
            }
        }
        return result;
    }

    @TestVisible
    private Cost_Rates__c getCostRateByTimeCardLine(Map<String, Cost_Rates__c> timeResourceCostMap, Time_Card_Line__c timeCardLine) {
        Cost_Rates__c theCostRate;

        String keyEmpProjectAndTask = String.valueOf(timeCardLine.Time_Card__r.Employee__c) + String.valueOf(timeCardLine.Project__c) + String.valueOf(timeCardLine.Project_Task__c);
        String keyEmpProject = String.valueOf(timeCardLine.Time_Card__r.Employee__c) + String.valueOf(timeCardLine.Project__c) + 'null';
        String keyEmp = String.valueOf(timeCardLine.Time_Card__r.Employee__c) + 'nullnull';

        if (timeResourceCostMap.containsKey(keyEmpProjectAndTask)) {
            theCostRate = timeResourceCostMap.get(keyEmpProjectAndTask);
        }
        else if (timeResourceCostMap.containsKey(keyEmpProject)) {
            theCostRate = timeResourceCostMap.get(keyEmpProject);
        }
        else if (timeResourceCostMap.containsKey(keyEmp)) {
            theCostRate = timeResourceCostMap.get(keyEmp);
        }

        return theCostRate;
    }

    @TestVisible
    private Map<String, Cost_Rates__c> getAllCostRates(Set<Id> employeeIdSet) {
        Map<String, Cost_Rates__c> costRateMap = new Map<String, Cost_Rates__c>();

        for (Cost_Rates__c costRate : queryCostRates(employeeIdSet)) {
            String key = String.valueOf(costRate.Employee__c) + String.valueOf(costRate.Project__c) + String.valueOf(costRate.Project_Task__c);
            costRateMap.put(key, costRate);
        }
        return costRateMap;
    }
    //=============================================================================================
    //========================== UNPOST processing ================================================
    public void processUnpostTimeCards() {
        Savepoint sp = Database.setSavepoint();
        try {
            TransactionActions.deleteTransactions(TransactionActions.queryTransactions(sourceRecordLines));

            List<Time_Card__c> timeCardsForUpdate = new List<Time_Card__c>();
            Boolean isLegacyTimeCards = false;

            String defaultPostingStatus = FinancialSuiteUtils.getDefaultPostingStatus(Time_Card__c.Status__c);

            for (Time_Card__c tc : (List<Time_Card__c>) sourceRecords) {
                if (tc.Status__c == DEFAULT_POSTING_STATUS_POSTED) {
                    tc.Status__c = defaultPostingStatus;
                    timeCardsForUpdate.add(tc);
                }
                if (!isLegacyTimeCards && tc.Type__c == NULL) {
                    isLegacyTimeCards = true;
                }
            }

            TriggerObserver.getInstance().unlockField(Time_Card__c.Status__c);
            if (isLegacyTimeCards) {
                TriggerObserver.getInstance().unlockField(Time_Card__c.Type__c);
            }
            SFDCSecurityUtils.updateCheckCRUDAndFLS(timeCardsForUpdate, new List<String> {'Status__c'});
            TriggerObserver.purgeUnlockedFields(Time_Card__c.Status__c);
        }
        catch (Exception ex) {
            Database.rollback(sp);
            throw ex;
        }
    }

}