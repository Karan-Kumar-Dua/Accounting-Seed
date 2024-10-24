public with sharing class AccountingPeriodActions {

    public static final String OPEN_INTERIM_STATUS = 'Open In Progress';
    public static final String CLOSE_INTERIM_STATUS = 'Close In Progress';
    public static final String OPEN_STATUS = 'Open';
    public static final String CLOSED_STATUS = 'Closed';
    public static final String ARCHIVED_STATUS = 'Archived';
    public static final String ARCHIVE_IN_PROGRESS_STATUS = 'Archive In Progress';
    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static String ERP_PACKAGE_QUALIFIER = GlobalVariables.ERPPACKAGE_QUALIFIER;
    public static final Set<String> JOB_STATUSES = GlobalVariables.APEX_JOB_STATUSES;
    public static final Set<String> CONSIDERED_CLOSED_STATUSES = new Set<String>{
            CLOSED_STATUS,
            OPEN_INTERIM_STATUS,
            ARCHIVED_STATUS,
            ARCHIVE_IN_PROGRESS_STATUS
    };

    public static final String DELETE_ERROR = Label.ERR_ACCOUNTING_PERIOD_CHILD_EXSISTS;
    public static final String BULK_UPDATE_ERROR = Label.ERR_ACCOUNTING_PERIOD_BULK_UPDATE;
    public static final String PAST_OPEN_ACCOUNTING_PERIOD_ERROR = String.format(Label.PAST_OPEN_ACCOUNTING_PERIOD_ERROR, new List<String>{CLOSED_STATUS.toLowerCase()});
    public static final String DATE_RANGE_ERROR = Label.ERR_ACCOUNTING_PERIOD_DATE_RANGE;
    public static final String NAME_FORMAT_ERROR = Label.ERR_ACCOUNTING_PERIOD_NAME_FORMAT;
    public static final String START_DATE_ERROR = Label.START_DATE_ERROR;
    public static final String STATUS_VALUE_ERROR = String.format(Label.STATUS_VALUE_ERROR, new List<String>{CLOSED_STATUS, OPEN_STATUS});
    public static final String STATUS_UNARCHIVE_ERROR = Label.ERR_ACCOUNTING_PERIOD_STATUS_UNARCHIVE;
    public static final String STATUS_ARCHIVE_ERROR = String.format(Label.STATUS_ARCHIVE_ERROR, new List<String>{ARCHIVED_STATUS});
    public static final String STATUS_CHANGED_FROM_ARCHIVE_IN_PROGRESS_ERROR = String.format(Label.ERR_ACCOUNTING_PERIOD_STATUS_CHANGED_FROM_ARCHIVE_IN_PROGRESS, new List<Object>{ ARCHIVE_IN_PROGRESS_STATUS });
    public static final String STATUS_CHANGED_FROM_IN_PROGRESS_ERROR = String.format(Label.ERR_ACCOUNTING_PERIOD_STATUS_CHANGED_FROM_IN_PROGRESS, new List<Object>{ OPEN_INTERIM_STATUS, CLOSE_INTERIM_STATUS}) + ' ' + OPEN_STATUS + '.';
    public static final String NAME_DUPLICATION_ERROR = Label.ERR_ACCOUNTING_PERIOD_NAME_DUPLICATE;
    public static final String NOT_CONTIGUOUS_ERROR = Label.ERR_ACCOUNTING_PERIOD_NOT_CONTIGUOUS;
    public static final String OPEN_AND_CLOSE_IN_ONE_STEP_ERROR = Label.ERR_ACCOUNTING_PERIOD_OPEN_AND_CLOSE_IN_ONE_STEP;
    public static final String BEFORE_CLOSED_OR_ARCHIVED_ERROR = String.format(Label.BEFORE_CLOSED_OR_ARCHIVED_ERROR, new List<String>{CLOSE_INTERIM_STATUS.toLowerCase(), CLOSED_STATUS.toLowerCase(), ARCHIVED_STATUS.toLowerCase()});

    public static final String CONSOLIDATION_IN_PROGRESS_ERROR = Label.ERR_CONSOLIDATION_IN_PROGRESS;
    public static final String CLOSE_AP_AR_INVENTORY_ERROR = Label.ERR_CLOSE_AP_AR_INVENTORY;
    public static final String MIXED_OPEN_CLOSE_WITH_SOFT_OPEN_CLOSE = Label.ERR_MIXED_OPEN_CLOSE_WITH_SOFT_OPEN_CLOSE;
    public static final String ERR_OPEN_CLOSE_OPERATION_IN_PROGRESS = Label.ERR_OPEN_CLOSE_OPERATION_IN_PROGRESS;

    public static final Set<String> validStatusValues = new Set<String>{OPEN_STATUS, CLOSED_STATUS, ARCHIVED_STATUS};

    public static Boolean isUpdateError = false;
    public static Boolean isFirstRun = true;
    public static Boolean isPreventUpdateOverride = false;
    public static Boolean isPreventInsertOverride = false;
    public static Boolean isDelarcInProgress = false;

    public static final List<String> relatedObjectForDeleteValidation {
        get {
            relatedObjectForDeleteValidation = new List<String> {
                PACKAGE_QUALIFIER + 'Account_Payable__c',
                PACKAGE_QUALIFIER + 'AP_Disbursement__c',
                PACKAGE_QUALIFIER + 'Billing__c',
                PACKAGE_QUALIFIER + 'Billing_Cash_Receipt__c',
                PACKAGE_QUALIFIER + 'Cash_Receipt__c',
                PACKAGE_QUALIFIER + 'Cash_Disbursement__c',
                PACKAGE_QUALIFIER + 'Journal_Entry__c',
                PACKAGE_QUALIFIER + 'Scheduled_Revenue_Expense__c',
                PACKAGE_QUALIFIER + 'Financial_Cube__c'
            };
            return relatedObjectForDeleteValidation;
        }
        private set;
    }

    public static final Set<String> consolidationRoutineClasses = new Set<String>{
        'ConsolidationRoutineBatch'
    };

    public static final Set<Schema.SObjectType> arSObjectTypes = new Set<Schema.SObjectType>{
        Billing__c.getSObjectType(),
        Cash_Receipt__c.getSObjectType(),
        Billing_Cash_Receipt__c.getSObjectType()
    };

    public static final Set<Schema.SObjectType> apSObjectTypes = new Set<Schema.SObjectType>{
        Account_Payable__c.getSObjectType(),
        Cash_Disbursement__c.getSObjectType(),
        AP_Disbursement__c.getSObjectType()
    };

    public static void validateDateRanges(List<Accounting_Period__c> periods) {
        Boolean isError = false;
        AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
        for (Accounting_Period__c checkPeriod : acctPeriodHandler.getAllAccountingPeriods()) {
            for (Accounting_Period__c period : periods) {
                //Checks sandwich period-Start date before and end date after existing record
                if (checkPeriod.Start_Date__c <= period.Start_Date__c
                        && checkPeriod.End_Date__c >= period.Start_Date__c && checkPeriod.Id != period.Id) {

                    isError = true;
                }
                //Checks to make sure the start date is not in an existing range
                if (checkPeriod.Start_Date__c <= period.End_Date__c
                        && checkPeriod.End_Date__c >= period.End_Date__c && checkPeriod.Id != period.Id) {

                    isError = true;
                }
                //Checks to make sure the end date is not in an existing range
                if (checkPeriod.Start_Date__c >= period.Start_Date__c
                        && checkPeriod.End_Date__c <= period.End_Date__c && checkPeriod.Id != period.Id) {

                    isError = true;
                }
                if (isError) {
                    period.addError(DATE_RANGE_ERROR);
                    isUpdateError = true;
                }
                isError = false;
            }
        }
    }

    public static void preventBulkUpdateAccountingPeriods(List<Accounting_Period__c> periods) {
        if (isUpdateError) {
            return;
        }
        if (periods.size() > 12) {
            for (Accounting_Period__c period : periods) {
                period.addError(BULK_UPDATE_ERROR);
                isUpdateError = true;
            }
        }
    }

    public static void checkAllPeriodsHaveSameStatus(List<Accounting_Period__c> newPeriods, List<Accounting_Period__c> oldPeriods) {
        if (isUpdateError) {
            return;
        }

        Set<String> statuses = new Set<String>();
        for (Accounting_Period__c period : oldPeriods) {
            statuses.add(period.Status__c);
        }
        if (statuses.size() > 1) {
            for (Accounting_Period__c period : newPeriods) {
                period.addError(OPEN_AND_CLOSE_IN_ONE_STEP_ERROR);
            }
            isUpdateError = true;
        }
    }

    public static void checkAccountingPeriodsAreContiguous(List<Accounting_Period__c> newPeriods) {
        if (isUpdateError) {
            return;
        }
        if (newPeriods.size() > 1) {
            List<Accounting_Period__c> sortableCollection = AccountingPeriodOpenCloseUtils.getSortedCollection(newPeriods);
            Accounting_Period__c previousPeriod;
            for (Accounting_Period__c period : sortableCollection) {
                if (previousPeriod != NULL) {
                    if (period.Start_Date__c != previousPeriod.End_Date__c.addDays(1)) {
                        isUpdateError = true;
                    }
                }
                previousPeriod = period;
            }

            if (isUpdateError) {
                for (Accounting_Period__c period : newPeriods) {
                    period.addError(NOT_CONTIGUOUS_ERROR);
                }
            }
        }
    }

    public static void preventSetStatusClosedIfPreviousIsOpenOrInProgress(  List<Accounting_Period__c> newPeriods,
                                                                            Map<Id, Accounting_Period__c> oldAcctPeriodMap) {

        if (isUpdateError) {
            return;
        }

        List<Accounting_Period__c> sortableCollection = AccountingPeriodOpenCloseUtils.getSortedCollection(newPeriods);

        Accounting_Period__c firstAcctPeriod = sortableCollection[0];
        if (oldAcctPeriodMap.get(firstAcctPeriod.Id).Status__c == OPEN_STATUS && firstAcctPeriod.Status__c == CLOSED_STATUS) {
            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
            if (acctPeriodHandler.isPastOpenOrInProgressPeriodExists(firstAcctPeriod)) {
                for (Accounting_Period__c period : newPeriods) {
                    period.addError(PAST_OPEN_ACCOUNTING_PERIOD_ERROR);
                }
                isUpdateError = true;
            }
        }
    }

    public static void preventStatusChangeArchived( Map<Id, Accounting_Period__c> oldPeriodsMap,
                                                    Map<Id, Accounting_Period__c> newPeriodsMap) {

        if (!isPreventUpdateOverride) {
            for (Accounting_Period__c newPeriod : newPeriodsMap.values()) {
                Accounting_Period__c oldPeriod = oldPeriodsMap.get(newPeriod.Id);

                if (oldPeriod.Status__c == ARCHIVED_STATUS && newPeriod.Status__c != ARCHIVED_STATUS) {
                    newPeriod.Status__c.addError(STATUS_UNARCHIVE_ERROR);
                    isUpdateError = true;
                }
                else if (oldPeriod.Status__c != ARCHIVED_STATUS && newPeriod.Status__c == ARCHIVED_STATUS) {
                    newPeriod.Status__c.addError(STATUS_ARCHIVE_ERROR);
                    isUpdateError = true;
                }
                else if (oldPeriod.Status__c == ARCHIVE_IN_PROGRESS_STATUS) {
                    newPeriod.Status__c.addError(STATUS_CHANGED_FROM_ARCHIVE_IN_PROGRESS_ERROR);
                    isUpdateError = true;
                }
            }
        }
    }

    public static void setDefaultFields(List<Accounting_Period__c> periods) {
        if (isPreventInsertOverride) {
            return;
        }

        for (Accounting_Period__c period : periods) {
            period.Status__c = OPEN_STATUS;
        }
    }

    public static void checkStatusValue(List<Accounting_Period__c> periods) {
        if (!isPreventUpdateOverride) {
            for (Accounting_Period__c period : periods) {
                if (!validStatusValues.contains(period.Status__c)) {
                    period.Status__c.addError(STATUS_VALUE_ERROR);
                }
            }
        }
    }

    public static void checkNameFormatField(List<Accounting_Period__c> periods) {
        Pattern namePattern = Pattern.compile('^(1|2)[0-9]{3}-(0[1-9]|1[012])$');
        for (Accounting_Period__c period : periods) {
            if (!namePattern.matcher(period.Name).matches()) {
                period.Name.addError(NAME_FORMAT_ERROR);
            }
        }
    }

    public static void preventNameDuplication(List<Accounting_Period__c> newPeriods) {
        if (isPreventUpdateOverride) {
            return;
        }

        Map<String, Accounting_Period__c> nameToAcctPeriodMap = new Map<String, Accounting_Period__c>();
        Map<Id, Accounting_Period__c> newAcctPeriodMap = new Map<Id, Accounting_Period__c>();
        //checking the possible duplication across NEW records
        for (Accounting_Period__c eachNewPeriod : newPeriods) {
            if (nameToAcctPeriodMap.containsKey(eachNewPeriod.Name)) {
                eachNewPeriod.Name.addError(NAME_DUPLICATION_ERROR);
            }
            else {
                nameToAcctPeriodMap.put(eachNewPeriod.Name, eachNewPeriod);
                newAcctPeriodMap.put(eachNewPeriod.Id, eachNewPeriod);
            }
        }
        //checking the possible duplication across NEW and existed records
        List<AggregateResult> periodsGroupedByName = DomainUtils.getPeriodsGroupedByName(nameToAcctPeriodMap.keySet());

        for (AggregateResult result : periodsGroupedByName) {
            if ((Integer) result.get('expr0') > 1) {
                Accounting_Period__c newPeriod = nameToAcctPeriodMap.get((String) result.get('Name'));
                newPeriod.Name.addError(NAME_DUPLICATION_ERROR);
            }
        }

    }

    public static void checkStartDateLessThanEndDate(List<Accounting_Period__c> periods) {
        for (Accounting_Period__c period : periods) {
            if (period.Start_Date__c > period.End_Date__c) {
                period.addError(START_DATE_ERROR);
            }
        }
    }

    public static void allowOnlyOpenStatusFromInProgress(List<Accounting_Period__c> newPeriods, Map<Id, Accounting_Period__c> oldPeriodsMap) {
        for (Accounting_Period__c newPeriod : newPeriods) {
            Accounting_Period__c oldPeriod = oldPeriodsMap.get(newPeriod.Id);
            if (newPeriod.Status__c != OPEN_STATUS && (oldPeriod.Status__c == OPEN_INTERIM_STATUS || oldPeriod.Status__c == CLOSE_INTERIM_STATUS)) {
                newPeriod.addError(STATUS_CHANGED_FROM_IN_PROGRESS_ERROR);
            }
        }
    }

    public static void preventOpenPeriodBeforeClosedOrArchivedOrInProgress(List<Accounting_Period__c> periods) {
        Set<String> periodStatus = new Set<String> {
            CLOSED_STATUS, ARCHIVED_STATUS, ARCHIVE_IN_PROGRESS_STATUS, OPEN_INTERIM_STATUS, CLOSE_INTERIM_STATUS
        };

        for (Accounting_Period__c period : periods) {
            List<Accounting_Period__c> existingPeriod = AccountingPeriodHandler.getInstance().getNextAccountingPeriods(period, periodStatus);
            if (!existingPeriod.isEmpty() && period.Status__c == OPEN_STATUS) {
                period.addError(BEFORE_CLOSED_OR_ARCHIVED_ERROR);
            }
        }
    }

    public static void openAccountingPeriods(List<Accounting_Period__c> newPeriods, Map<Id, Accounting_Period__c> oldPeriodMap) {
        if (!isUpdateError && isFirstRun) {
            AccountingPeriodOpenCloseUtils.openAccountingPeriods(newPeriods, oldPeriodMap);
        }
    }

    public static void closeAccountingPeriods(List<Accounting_Period__c> newPeriods, Map<Id, Accounting_Period__c> oldPeriodMap) {
        if (!isUpdateError && isFirstRun) {
            AccountingPeriodOpenCloseUtils.closeAccountingPeriods(newPeriods, oldPeriodMap);
        }
    }

    public static void resetAccountingPeriodHandler() {
        AccountingPeriodHandler.reset();
    }

    public static void preventDeleteIfRelatedRecordsExist(Map<Id, Accounting_Period__c> oldPeriodMap) {
        Set<Id> periodWithPositive = new Set<Id> ();

        for (String objName : relatedObjectForDeleteValidation) {
            Map<Id, AggregateResult> results = new Map<Id, AggregateResult>(
                DomainUtils.getRelatedObjectCountByApiNameAndLookupName(oldPeriodMap.keySet(), objName, 'Accounting_Period__c')
            );
            for (Id resId : results.keySet()) {
                if (results.get(resId).get('itemCount') != 0) {
                    periodWithPositive.add(resId);
                }
            }
        }

        if (!periodWithPositive.isEmpty()) {
            for (Id oldLedgerId : periodWithPositive) {
                oldPeriodMap.get(oldLedgerId).addError(DELETE_ERROR);
            }
        }
    }

    public static void preventOpenClosedOrArchivedPeriodIfConsolidation(List<Accounting_Period__c> periods, Map<Id, Accounting_Period__c> oldPeriodMap) {
        List<AsyncApexJob> asyncApexJobs = DomainUtils.getAsyncApexJobByApexClassNameAndStatus(
            consolidationRoutineClasses, JOB_STATUSES
        );

        for (Accounting_Period__c period : periods) {
            Accounting_Period__c oldPeriod = oldPeriodMap.get(period.Id);
            if (period.Status__c != oldPeriod.Status__c && asyncApexJobs != NULL && !asyncApexJobs.isEmpty()) {
                period.addError(CONSOLIDATION_IN_PROGRESS_ERROR);
            }
        }
    }
     /**
     * Params - periods(i.e., Trigger.new)  and oldPeriodMap(i.e., Trigger.oldMap)
     * Description - This method is called from AccountingPeriod Trigger and used to delete AP_Aging_History__c
     *               records if Close_AP__c checkbox IS changed from checked to un-checked on an Accounting Period that is still in the open status. 
     */
    public static void deleteAPAgingOnSoftOpen(List<Accounting_Period__c> periods, Map<Id, Accounting_Period__c> oldPeriodMap){
        List<Accounting_Period__c> periodsToProcess = new List<Accounting_Period__c>();

        for(Accounting_Period__c period : periods){
            if(!(period.close_AP__c) && oldPeriodMap.get(period.Id).close_AP__c != period.close_AP__c && period.Status__c == OPEN_STATUS)
            {      
                periodsToProcess.add(period);
            }
        }

        if(periodsToProcess != NULL && periodsToProcess.size() > 0){
            AccountingPeriodOpenCloseOptions periodInfoContainer =
                new AccountingPeriodOpenCloseOptions(
                    periodsToProcess,
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.SOFT_OPEN // context is soft open becoz AP_close is unchecked and status is open
                );
            
            Database.executeBatch(new AccountingPeriodOpenAPAging(periodInfoContainer));
        }
    }

    /**
     * Params - periods(i.e., Trigger.new)  and oldPeriodMap(i.e., Trigger.oldMap)
     * Description - This method is called from AccountingPeriod Trigger and used to create  Billing_aging_history__c
     *               records if Close_AR__c checkbox is checked and status is open. 
     */
    public static void createCloseBillingAgingOnSoftClose(List<Accounting_Period__c> periods, Map<Id, Accounting_Period__c> oldPeriodMap){
        List<Accounting_Period__c> periodsToProcess = new List<Accounting_Period__c>();

        for(Accounting_Period__c period : periods){
            if(period.close_AR__c && oldPeriodMap.get(period.Id).close_AR__c != period.close_AR__c && period.Status__c == OPEN_STATUS)
            {      
                periodsToProcess.add(period);
            }
        }

        if(periodsToProcess != NULL && periodsToProcess.size() > 0){
            AccountingPeriodOpenCloseOptions periodInfoContainer =
                new AccountingPeriodOpenCloseOptions(
                    periodsToProcess,
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.SOFT_CLOSE // context is soft close becoz AR_close is checked and status is open
                );
            Database.executeBatch(new AccountingPeriodCloseBillingAging(periodInfoContainer));  
        } 
    }
     /**
     * Params - periods(i.e., Trigger.new)  and oldPeriodMap(i.e., Trigger.oldMap)
     * Description - This method is called from AccountingPeriod Trigger and used to delete Billing_aging_history__c
     *               records if Close_AR__c checkbox is unchecked and status is open. 
     */
    public static void deleteARAgingOnSoftOpen(List<Accounting_Period__c> periods, Map<Id, Accounting_Period__c> oldPeriodMap){
        List<Accounting_Period__c> periodsToProcess = new List<Accounting_Period__c>();
        
        for(Accounting_Period__c period : periods){
           
            if(!(period.close_AR__c) && oldPeriodMap.get(period.Id).close_AR__c != period.close_AR__c && period.Status__c == OPEN_STATUS)
            {      
                periodsToProcess.add(period);
            }
        }

        if(periodsToProcess != NULL && periodsToProcess.size() > 0){
            AccountingPeriodOpenCloseOptions periodInfoContainer =
                new AccountingPeriodOpenCloseOptions(
                    periodsToProcess,
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.SOFT_OPEN // context is soft open becoz AR_close is unchecked and status is open
                );
            
            Database.executeBatch(new AccountingPeriodOpenBillingAging(periodInfoContainer));
        }
    }

    public static void preventSourceDocDeleteCheck(List<Accounting_Period__c> periods, Map<Id, Accounting_Period__c> oldPeriodMap) {
        if (!isDelarcInProgress) {
            for (Accounting_Period__c period : periods) {
                if (period.Source_Docs_Deleted__c != oldPeriodMap.get(period.Id).Source_Docs_Deleted__c) {
                    period.addError(Label.ERR_SOURCE_DOC_DELETED_PREVENT);
                }
            }
        }
    }

    /**
     * Params - periods(i.e., Trigger.new)  and oldPeriodMap(i.e., Trigger.oldMap)
     * Description - This method is called from AccountingPeriod Trigger and used to create  AP_Aging_History__c 
     *               records if Close_AP__c checkbox is checked and status is open. 
     */
    public static void createCloseAPAgingOnSoftClose(List<Accounting_Period__c> periods, Map<Id, Accounting_Period__c> oldPeriodMap){
        List<Accounting_Period__c> periodsToProcess = new List<Accounting_Period__c>();

        for(Accounting_Period__c period : periods){
          if(period.close_AP__c && oldPeriodMap.get(period.Id).close_AP__c != period.close_AP__c && period.Status__c == OPEN_STATUS)
            {      
                periodsToProcess.add(period);
            }
        }

        if(periodsToProcess != NULL && periodsToProcess.size() > 0){
            AccountingPeriodOpenCloseOptions periodInfoContainer =
                new AccountingPeriodOpenCloseOptions(
                    periodsToProcess,
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.SOFT_CLOSE // context is soft close becoz AP_close is checked and status is open
                );

            Database.executeBatch(new AccountingPeriodCloseAPAging(periodInfoContainer));   
        }
    }

    public static void preventCloseAPCloseARCloseInvIfStatusClosed(List<Accounting_Period__c> periods, Map<Id, Accounting_Period__c> oldPeriodMap) {
        for (Accounting_Period__c period : periods) {
            String errorField = '';
            Accounting_Period__c oldPeriod = oldPeriodMap.get(period.Id);

            //If the status is changing to closed while a soft operation is occurring,
            //a different error is printed in preventMixOfOpenCloseAndSoftOpenClose.
            //So in this scenario, only print the error if the period was already closed.
            if (((period.Status__c == CLOSED_STATUS) && (oldPeriod.Status__c == CLOSED_STATUS)) || 
                ((period.Status__c == ARCHIVED_STATUS) && (oldPeriod.Status__c == ARCHIVED_STATUS))) {
                    if(period.Close_AP__c != oldPeriod.Close_AP__c) {
                        errorField = ' Close AP';
                    }

                    if(period.Close_AR__c != oldPeriod.Close_AR__c) {
                        errorField = (String.isEmpty(errorField)) ? ' Close AR' : errorField + ', Close AR';
                    }

                    if(AccountingSettingsHandler.isERPEnabled() && (period.get(ERP_PACKAGE_QUALIFIER + 'Close_Inventory__c') != oldPeriodMap.get(period.Id).get(ERP_PACKAGE_QUALIFIER + 'Close_Inventory__c'))) {
                        errorField = (String.isEmpty(errorField))  ? ' Close Inventory' : errorField + ',Close Inventory';
                    }
            }
            if(!String.isEmpty(errorField)) {
                    period.addError(CLOSE_AP_AR_INVENTORY_ERROR + errorField + '.');
            }
        }  
    }

    /*
    * Even though users should technically be able to hard close a period and soft close subsequent periods, 
    * the accounting period trigger makes doing this complicated as it fires batches to process periods one by one,
    * and the soft close process would need to be integrated into that batch loop.
    * For this reason, the decision was made to prevent all mixes of changes to status and changes in any soft change status
    */
    public static void preventMixOfOpenCloseAndSoftOpenClose(List<Accounting_Period__c> periods, Map<Id, Accounting_Period__c> oldPeriodMap) {
        Map<Id, Accounting_Period__c> newPeriodsMap = new Map<Id, Accounting_Period__c>();
        Set<Id> periodsWithOpenCloseOperation = new Set<Id>();
        Set<Id> periodsWithSoftOperation = new Set<Id>();
         for (Accounting_Period__c aPeriod : periods) {
             newPeriodsMap.put(aPeriod.Id, aPeriod);
             if (aPeriod.Status__c != oldPeriodMap.get(aPeriod.Id).Status__c) {
                periodsWithOpenCloseOperation.add(aPeriod.Id);
             }
             if (periodHasSoftOperation(aPeriod, oldPeriodMap.get(aPeriod.Id))) {
                periodsWithSoftOperation.add(aPeriod.Id);
             }

         }
        if (!periodsWithSoftOperation.isEmpty() && !periodsWithOpenCloseOperation.isEmpty()) {
            //the following results in periodsWithSoftOperation being the union of the two sets
            //used to put an error on any line associated with the mixed operation, soft or otherwise
            periodsWithSoftOperation.addAll(periodsWithOpenCloseOperation);
            for (Id periodId : periodsWithSoftOperation) {
               newPeriodsMap.get(periodId).addError(AccountingPeriodActions.MIXED_OPEN_CLOSE_WITH_SOFT_OPEN_CLOSE);
            }
        }
    }

    /**
     * Params - periods(i.e., Trigger.new)  and oldPeriodMap(i.e., Trigger.oldMap)
     * Description - This method is called from AccountingPeriod Trigger and used to create  AcctSeedERP__Inventory_Balance_History__c
     *               records if Close_Inventory__c checkbox is checked and status is open. 
     */
    public static void createInventoryHistoriesOnSoftClose(List<Accounting_Period__c> periods, Map<Id, Accounting_Period__c> oldPeriodMap){
        
        List<Date> datesToProcess = new List<Date>();
        Accounting_Settings__c acctSetting = AccountingSettingsHandler.getAccountingSettings();
        
        //Test.isRunningTest() is used to provide coverage since there is no other way to test the scenario as the fields below are from the ERP package.
        if((AccountingSettingsHandler.isERPEnabled() && (boolean)acctSetting.get(ERP_PACKAGE_QUALIFIER + 'Enable_Inventory_Period_History__c')) || Test.isRunningTest()){
            for(Accounting_Period__c period : periods){
                if(Test.isRunningTest() || ((boolean)period.get(ERP_PACKAGE_QUALIFIER + 'Close_Inventory__c') 
                    && !(boolean)oldPeriodMap.get(period.Id).get(ERP_PACKAGE_QUALIFIER + 'Close_Inventory__c') 
                    && period.Status__c == OPEN_STATUS))
                {      
                    datesToProcess.add(period.End_Date__c);
                }
            }   
        }

        if(datesToProcess.size() >0 && !Test.isRunningTest()){
            FinancialSuiteService.executeInventoryHistoryCreateBatch(datesToProcess);
        }
    }

    public static void deleteInventoryHistoriesOnSoftOpen(List<Accounting_Period__c> periods, Map<Id, Accounting_Period__c> oldPeriodMap){
        
        List<Date> datesToProcess = new List<Date>();
        Accounting_Settings__c acctSetting = AccountingSettingsHandler.getAccountingSettings();
        
        //Test.isRunningTest() is used to provide coverage since there is no other way to test the scenario as the fields below are from the ERP package.
        if((AccountingSettingsHandler.isERPEnabled() && (boolean)acctSetting.get(ERP_PACKAGE_QUALIFIER + 'Enable_Inventory_Period_History__c')) || Test.isRunningTest()){
            for(Accounting_Period__c period : periods){
                if(Test.isRunningTest() || (!(boolean)period.get(ERP_PACKAGE_QUALIFIER + 'Close_Inventory__c')  
                    && (boolean)oldPeriodMap.get(period.Id).get(ERP_PACKAGE_QUALIFIER + 'Close_Inventory__c') 
                    && period.Status__c == OPEN_STATUS))
                {      
                    datesToProcess.add(period.End_Date__c);
                }
            }   
        }

        if(datesToProcess.size() >0 && !Test.isRunningTest()){
            FinancialSuiteService.executeInventoryHistoryDeleteBatch(datesToProcess);
        }
    }
    
    /*
    * This function also prevents the soft close/open when an open/close is in progress, but for users
    * who would attempt those operations around the same time. Since soft close operations also launch jobs that
    * are checked by isAccountingPeriodJobInProgress, this also prevents multiple soft close operations from
    * occurring within a short time period. There may be a way to allow multiple soft ops around the same time,
    * but for now it's safest just to prevent this.
    */
    public static void preventSoftOperationWhenOpenCloseInProgress(List<Accounting_Period__c> periods, Map<Id, Accounting_Period__c> oldPeriodMap) {
        Map<Id, Accounting_Period__c> periodsWithSoftOperation = new Map<Id, Accounting_Period__c>();
        for (Accounting_Period__c aPeriod : periods) {
            if (periodHasSoftOperation(aPeriod, oldPeriodMap.get(aPeriod.Id))) {
                periodsWithSoftOperation.put(aPeriod.Id, aPeriod);
            }

        }
        if (!periodsWithSoftOperation.keySet().isEmpty() 
            && AccountingPeriodOpenCloseUtils.isAccountingPeriodJobInProgress() 
            /*&& !AccountingPeriodOpenCloseUtils.isPreventJobSearchSkip*/) {
            for (Id aPeriodId : periodsWithSoftOperation.keySet()) {
               periodsWithSoftOperation.get(aPeriodId).addError(AccountingPeriodActions.ERR_OPEN_CLOSE_OPERATION_IN_PROGRESS);
            }
        }
    }

    public static void preventClosedOrArchivedPeriodLDOInProgress(Map<Id, Accounting_Period__c> periodsByIds, Map<Id, Accounting_Period__c> oldPeriodMap) {
        Set<Id> commonClosePeriodIds = new Set<Id>();
        Set<Id> arSoftPeriodIds = new Set<Id>();
        Set<Id> apSoftPeriodIds = new Set<Id>();
        for (Accounting_Period__c period : periodsByIds.values()) {
            Accounting_Period__c oldPeriod = oldPeriodMap.get(period.Id);
            if (period.Status__c != oldPeriod.Status__c
                    && (period.Status__c == CLOSE_INTERIM_STATUS || CONSIDERED_CLOSED_STATUSES.contains(period.Status__c))) {
                commonClosePeriodIds.add(period.Id);
            }

            if (isARSoftClose(period, oldPeriod)) {
                arSoftPeriodIds.add(period.Id);
            }

            if (isAPSoftClose(period, oldPeriod)) {
                apSoftPeriodIds.add(period.Id);
            }
        }

        final Set<SObjectType> SOURCE_SOBJECT_TYPES = new Set<SObjectType>{
                Journal_Entry__c.getSObjectType(),
                Billing__c.getSObjectType(),
                Account_Payable__c.getSObjectType(),

                Cash_Receipt__c.getSObjectType(),
                Cash_Disbursement__c.getSObjectType(),

                Billing_Cash_Receipt__c.getSObjectType(),
                AP_Disbursement__c.getSObjectType()
        };

        for (SObjectType sObjType : SOURCE_SOBJECT_TYPES) {
            Set<Id> periodIds = new Set<Id>(commonClosePeriodIds);
            if (apSObjectTypes.contains(sObjType)) {
                periodIds.addAll(apSoftPeriodIds);
            }
            if (arSObjectTypes.contains(sObjType)) {
                periodIds.addAll(arSoftPeriodIds);
            }
            if (!periodIds.isEmpty()) {
                List<String> conditions = new List<String>{
                        PACKAGE_QUALIFIER + 'Accounting_Period__c =: arg0',
                        PACKAGE_QUALIFIER + 'Status__c =: arg1'
                };
                List<AggregateResult> sourcesByPeriods = DomainUtils.recordsByConditions(
                        sObjType,
                        new List<String>{'Count(Id) c0unt', PACKAGE_QUALIFIER + 'Accounting_Period__c periodId'},
                        String.join(conditions, ' AND ') + ' GROUP BY ' + PACKAGE_QUALIFIER + 'Accounting_Period__c',
                        new List<Object>{
                                periodIds,
                                new Set<String>{
                                        AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTING_IN_PROGRESS,
                                        AbstractPostHandler.DEFAULT_POSTING_STATUS_UNPOSTING_IN_PROGRESS
                                }
                        }
                );
                for (AggregateResult result : sourcesByPeriods) {
                    Id periodId = (Id)result.get('periodId');
                    periodsByIds.get(periodId).addError(Label.ERR_LDO_JOB_IN_PROGRESS);

                    commonClosePeriodIds.remove(periodId);
                    arSoftPeriodIds.remove(periodId);
                    apSoftPeriodIds.remove(periodId);
                }
            }
        }
    }

    private static Boolean isARSoftClose(Accounting_Period__c aPeriod, Accounting_Period__c oldPeriod) {
        return aPeriod.close_AR__c && oldPeriod.close_AR__c != aPeriod.close_AR__c;
    }

    private static Boolean isAPSoftClose(Accounting_Period__c aPeriod, Accounting_Period__c oldPeriod) {
        return aPeriod.close_AP__c && oldPeriod.close_AP__c != aPeriod.close_AP__c;
    }

    private static Boolean periodHasSoftOperation(Accounting_Period__c aPeriod, Accounting_Period__c oldPeriod) {
        if (
            aPeriod.Close_AP__c != oldPeriod.Close_AP__c  ||
            aPeriod.Close_AR__c != oldPeriod.Close_AR__c  ||
            (AccountingSettingsHandler.isERPEnabled() && 
            (aPeriod.get(ERP_PACKAGE_QUALIFIER + 'Close_Inventory__c') != oldPeriod.get(ERP_PACKAGE_QUALIFIER + 'Close_Inventory__c')))
        ) {
            return true;
        } else {
            return false;
        }
    }

}