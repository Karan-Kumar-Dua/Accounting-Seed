public with sharing class ConsolidationRoutineBatch implements Database.Batchable<sObject>, Database.Stateful {
   
    public static final String JOB_NAME = 'Consolidation Routine Job';
    public static final String ACTIVITY_STATUS = 'Completed';
    public static final String ACTIVITY_SUBJECT = Label.ERR_CONSOLIDATION_ROUTINE_BATCH_FAIL;
    public static final String ACTIVITY_PRIORITY = 'Normal';

    @TestVisible
    private Id mainConsolidationLedgerId;
    private Set<Id> consolidatedLedgers;
    private String accountingPeriodId;
    private String errorMsg;
    private LedgerHierarchyModel mainLedgerHierarchyModel;
    private LedgerHierarchyModel currentLedgerHierarchyModel;
    private LedgerHierarchyModel.Iterator lhIterator;
    private Boolean runForChildren;
    @TestVisible
    private Boolean isError;
    private String consolidationCurrency;
    private Set<String> replacedCubesKeys;

    public ConsolidationRoutineBatch(LedgerHierarchyModel lhModel, Id periodId, Boolean runForChildren) {
        this.isError = false;
        this.replacedCubesKeys = new Set<String>();
        this.runForChildren = runForChildren;
        this.mainLedgerHierarchyModel = lhModel;
        this.lhIterator = lhModel.getIterator();
        this.currentLedgerHierarchyModel = (runForChildren) ? this.lhIterator.next() : mainLedgerHierarchyModel;
        this.mainConsolidationLedgerId = currentLedgerHierarchyModel.value.Ledger__c;
        this.consolidationCurrency = LedgerHandler.getLedgerCurrency(this.mainConsolidationLedgerId);
        this.consolidatedLedgers = new Set<Id>();
        for (Id consolidatedLedgerId : currentLedgerHierarchyModel.getChildLedgers()) {
            if (LedgerHandler.getLedgerAccountingMethod(consolidatedLedgerId) == LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH) {
                this.consolidatedLedgers.add(LedgerHandler.getShadowLedger(consolidatedLedgerId)?.Id);
            }
            this.consolidatedLedgers.add(consolidatedLedgerId);
        }

        this.accountingPeriodId = periodId;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        List<String> fields = new List<String>{
                'Id',
                'Name',
                'GL_Account__c',
                'GL_Account_Variable_1__c',
                'GL_Account_Variable_2__c',
                'GL_Account_Variable_3__c',
                'GL_Account_Variable_4__c',
                'Opening_Balance__c',
                'Current_Period__c',
                'Amount__c',
                'Ledger__c',
                'Ledger__r.Accounting_Method__c'
        };
        List<String> conditions = new List<String>{
                'Accounting_Period__c = :accountingPeriodId',
                'Ledger__c IN :consolidatedLedgers'
        };
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            conditions.add('CurrencyIsoCode = \'' + LedgerHandler.getLedgerCurrency(this.mainConsolidationLedgerId) + '\'');
        }
        String query = String.format('SELECT {0} FROM {1} WHERE {2}', new List<String>{
                String.join(fields, ','),
                'Financial_Cube__c',
                String.join(conditions, ' AND ')
        });

        return DomainUtils.getQueryLocatorForConsolidationRoutineBatch(query, accountingPeriodId, consolidatedLedgers);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        FinancialCubesConsolidator consolidator = new FinancialCubesConsolidator(mainConsolidationLedgerId, accountingPeriodId);
        try {
            //Aggregate Financial Cubes
            for (Financial_Cube__c fc : (List<Financial_Cube__c>) scope) {
                consolidator.addCube(fc);
            }

            //Get Aggregated keys
            Set<String> aggregatedKeys = consolidator.getAggregationKeys();

            //Delete old Cons Cubes only once per batch execution
            Set<String> keysToDelete = new Set<String>();
            List<Financial_Cube__c> fCubesToDelete = new List<Financial_Cube__c>();
            for (String aggregatedKey : aggregatedKeys) {
                if (!replacedCubesKeys.contains(aggregatedKey)) {
                    keysToDelete.add(aggregatedKey);
                }
            }

            fCubesToDelete = DomainUtils.getOriginalConsolidationFinancialCubesByKeys(keysToDelete);
            deleteOldConsolidationFinCubes(fCubesToDelete);
            this.replacedCubesKeys.addAll(keysToDelete);

            //Update existed FCubes or create new records
            Set<String> keysOfUpdatedCubes = new Set<String>();
            List<Financial_Cube__c> fCubesToUpdate = new List<Financial_Cube__c>();
            List<Financial_Cube__c> fCubesToInsert = new List<Financial_Cube__c>();

            //Query existed Fin Cubes and update OB and Amount fields
            for (Financial_Cube__c exConsCube : DomainUtils.getOriginalConsolidationFinancialCubesByKeys(aggregatedKeys)) {
                FinancialCubesConsolidator.ConsolidatedResult consResult = consolidator.getConsolidatedResultByKey(exConsCube.Key__c);
                if (exConsCube.Opening_Balance__c != null) {
                    exConsCube.Opening_Balance__c += consResult.openingBalance;
                }
                else {
                    exConsCube.Opening_Balance__c = consResult.openingBalance;
                }

                if (exConsCube.Amount__c != null) {
                    exConsCube.Amount__c += consResult.currentPeriod;
                }
                else {
                    exConsCube.Amount__c = consResult.currentPeriod;
                }

                fCubesToUpdate.add(exConsCube);
                keysOfUpdatedCubes.add(exConsCube.Key__c);
            }
            //Create new Fin Cubes
            for (String aggregatedKey : aggregatedKeys) {
                if (!keysOfUpdatedCubes.contains(aggregatedKey)) {
                    Financial_Cube__c newConsCube = consolidator.getConsolidationCubeByKey(aggregatedKey);
                    fCubesToInsert.add(newConsCube);
                }
            }

            updateConsolidationFinCubes(fCubesToUpdate);
            insertNewConsolidationFinCubes(fCubesToInsert);
        }
        catch (Exception ex) {
            isError = true;
            errorMsg = ex.getMessage();
        }
    }

    public void finish (Database.BatchableContext BC) {
        try {
            if (!isError) {
                if (!Test.isRunningTest() && this.runForChildren && lhIterator.hasNext()) {
                    if (lhIterator.viewNext().needTranslations()) {
                        FinancialCubeTranslationBatch translationBatchInstance = new FinancialCubeTranslationBatch(
                            mainLedgerHierarchyModel, accountingPeriodId, runForChildren
                        );
                        Database.executeBatch(translationBatchInstance);
                    }
                    else {
                        Database.executeBatch(
                            new ConsolidationRoutineBatch(mainLedgerHierarchyModel, accountingPeriodId, runForChildren)
                        );
                    }
                //end of batch chain reached
                } else if (this.runForChildren && !lhIterator.hasNext()) {
                    createAutomatedJobResult();
                }
            }
        }
        catch (Exception ex) {
            isError = true;
            errorMsg = ex.getMessage();
        }
        finally {
            // an error occurred stopping the batch chain
            // OR batch is only running for current hierarchy level
            if (isError || !runForChildren ){
                createAutomatedJobResult();
            }
            if (isError) {
                createActivity();
            }

            updateLedgerHierarchyStatus();
        }
    }

    private void createActivity() {
        Task activity = FinancialSuiteUtils.setTask(
            currentLedgerHierarchyModel.value.Id, 
            ACTIVITY_STATUS, 
            ACTIVITY_PRIORITY, 
            ACTIVITY_SUBJECT, 
            errorMsg, 
            UserInfo.getUserId()
        );
        SFDCSecurityUtils.insertProxy(activity);
    }

    private void createAutomatedJobResult() {
        Integer total = runForChildren ? 0 : 1;
        Integer succeeded = 0;

        if (runForChildren) {
            // Count the total batch jobs and the successful batch jobs.
            // One batch job per `LedgerHierarchyModel`.
            LedgerHierarchyModel.Iterator itr = new LedgerHierarchyModel.Iterator(mainLedgerHierarchyModel);
            Boolean reachedError = false;
            while (itr.hasNext()) {
                LedgerHierarchyModel current = itr.next();
                if (isError && currentLedgerHierarchyModel.value.Ledger__c == current.value.Ledger__c) {
                    // there was an error in the current batch
                    reachedError = true;
                }
                if (!reachedError) {
                    // either there was no error, or the batch job for 
                    // `current` finished successfully.
                    succeeded++;
                }
                total++;
            }
        } else {
            if (!isError) {
                succeeded++;
            }
        }

        // create the `Automated_Job_Results__c` record
        AutomatedJobResultsHandler.setJobType(JOB_NAME);
        AutomatedJobResultsHandler.setProcessed(total);
        AutomatedJobResultsHandler.setSucceeded(succeeded);
        AutomatedJobResultsHandler.setFailed(total - succeeded);
        if (AutomatedJobResultsHandler.isReportExist(JOB_NAME)) {
            AutomatedJobResultsHandler.addNote(
                AutomatedJobResultsHandler.getReportLink(JOB_NAME)
            );
        }
        AutomatedJobResultsHandler.saveAutomatedJobResults();

    }

    private void insertNewConsolidationFinCubes(List<Financial_Cube__c> fCubes) {
        try {
            if (fCubes != null && !fCubes.isEmpty()) {
                FinancialCubeActions.isPreventOverride = true;
                SFDCSecurityUtils.insertProxy(fCubes);
                FinancialCubeActions.isPreventOverride = false;
            }
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    private void deleteOldConsolidationFinCubes(List<Financial_Cube__c> fCubes) {
        try {
            if (fCubes != null && !fCubes.isEmpty()) {
                FinancialCubeActions.isPreventOverride = true;
                SFDCSecurityUtils.deleteProxy(fCubes);
                FinancialCubeActions.isPreventOverride = false;
            }
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    private void updateConsolidationFinCubes(List<Financial_Cube__c> fCubes) {
        try {
            if (fCubes != null && !fCubes.isEmpty()) {
                FinancialCubeActions.isPreventOverride = true;
                SFDCSecurityUtils.updateProxy(fCubes);
                FinancialCubeActions.isPreventOverride = false;
            }
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    private void updateLedgerHierarchyStatus() {
        String errStatus = isError ? LedgerHierarchyActions.LEDGER_HIERARCHY_STATUS_ERROR : LedgerHierarchyActions.LEDGER_HIERARCHY_STATUS_COMPLETE;
        Datetime runDate = DateTime.now();
        List<Ledger_Hierarchy__c> ledgerHierarchiesToUpdate = new List<Ledger_Hierarchy__c>();

        currentLedgerHierarchyModel.value.Hierarchy_Status__c = errStatus;
        currentLedgerHierarchyModel.value.Last_Period_Run__c = accountingPeriodId;
        if (!isError) {
            currentLedgerHierarchyModel.value.Last_Period__c = accountingPeriodId;
            currentLedgerHierarchyModel.value.Last_Run__c = runDate;
            currentLedgerHierarchyModel.value.Generated_By__c = UserInfo.getUserId();
        }

        ledgerHierarchiesToUpdate.add(currentLedgerHierarchyModel.value);

        if (runForChildren && isError) {
            while (lhIterator.hasNext()) {
                LedgerHierarchyModel currentLH = lhIterator.next();
                Ledger_Hierarchy__c ledgerHierarchyToUpdate = currentLH.value;
                ledgerHierarchyToUpdate.Hierarchy_Status__c = LedgerHierarchyActions.LEDGER_HIERARCHY_STATUS_NOT_RUN;
                ledgerHierarchiesToUpdate.add(ledgerHierarchyToUpdate);
            }
        }

        Set<SObjectField> lockedFieldsToUpdate = new Set<SObjectField>{
            Ledger_Hierarchy__c.Hierarchy_Status__c,
            Ledger_Hierarchy__c.Last_Period__c,
            Ledger_Hierarchy__c.Last_Run__c,
            Ledger_Hierarchy__c.Generated_By__c,
            Ledger_Hierarchy__c.Last_Period_Run__c
        };

        TriggerObserver.getInstance().unlockFields(lockedFieldsToUpdate);
        LedgerHierarchyActions.bypassConsolidationRoutineValidation = true;
        SFDCSecurityUtils.updateProxy(ledgerHierarchiesToUpdate);
        TriggerObserver.purgeUnlockedFields(lockedFieldsToUpdate);
    }

}