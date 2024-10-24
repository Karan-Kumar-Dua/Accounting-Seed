public with sharing class FinancialCubeTranslationBatch implements Database.Batchable<SObject>, Database.Stateful {

    public static final String GL_ACCT_RATE_TYPE_ERROR = Label.ERR_GL_ACCOUNT_RATE_TYPE_MISSING;
    private static final String CTA_LABEL = 'Cumulative Translation Adjustment';
    private Id accountingPeriodId;
    private Accounting_Period__c accountingPeriod;
    private Set<Id> ledgerIds = new Set<Id>();
    private String targetCurrency;
    private Boolean isError = false;
    private String errorMsg;
    private Map<String, LedgerBalanceContainer> ledgerBalance = new Map<String, LedgerBalanceContainer>();
    private Map<String, CYEBalanceContainer> cyeBalance = new Map<String, CYEBalanceContainer>();
    private Boolean runConsolidationRoutine = false;
    private LedgerHierarchyModel mainLedgerHierarchyModel;
    private LedgerHierarchyModel currentLedgerHierarchyModel;
    private LedgerHierarchyModel.Iterator lhIterator;
    private Boolean runForChildren;

    public FinancialCubeTranslationBatch(Set<Id> ledgers, Id periodId, String targetCurrency) {
        try {
            this.accountingPeriodId = periodId;
            this.accountingPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodById(this.accountingPeriodId);
            this.ledgerIds = ledgers;
            this.targetCurrency = targetCurrency;
            validateCumulativeGLAccount();
        }
        catch (Exception ex) {
            isError = true;
            errorMsg = ex.getMessage();
        }
    }

    public FinancialCubeTranslationBatch(LedgerHierarchyModel lhModel, Id periodId, Boolean runForChildren) {
        try {
            this.mainLedgerHierarchyModel = lhModel;
            this.lhIterator = lhModel.getIterator();
            this.runConsolidationRoutine = true;
            this.runForChildren = runForChildren;

            this.currentLedgerHierarchyModel = (runForChildren)
                ? this.lhIterator.viewNext()
                : this.mainLedgerHierarchyModel;

            this.accountingPeriodId = periodId;
            this.accountingPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodById(this.accountingPeriodId);
            this.ledgerIds = this.currentLedgerHierarchyModel.getChildLedgers();
            this.targetCurrency = LedgerHandler.getLedgerCurrency(this.currentLedgerHierarchyModel.value.Ledger__c);

            validateCumulativeGLAccount();
        }
        catch (Exception ex) {
            isError = true;
            errorMsg = ex.getMessage();
        }
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query =
            'SELECT Id, ' +
                'Name, ' +
                'GL_Account__c, ' +
                'GL_Account__r.Rate_Type__c, ' +
                'GL_Account__r.Type__c, ' +
                'GL_Account_Type__c, ' +
                'Opening_Balance__c, ' +
                'Current_Period__c, ' +
                'Ledger__c, ' +
                'Accounting_Period__c, ' +
                'Accounting_Period__r.Name, ' +
                'GL_Account_Variable_1__c, ' +
                'GL_Account_Variable_2__c, ' +
                'GL_Account_Variable_3__c, ' +
                'GL_Account_Variable_4__c, ' +
                'Key_Group__c, ' +
                'Key__c, ' +
                'Cube_Type__c, ' +
                'Amount__c ' +
                (MultiCurrencyHandler.isMultiCurrencyEnabled ? ', CurrencyIsoCode, Ledger__r.CurrencyIsoCode ' : '') +
                'FROM Financial_Cube__c ' +
                'WHERE Accounting_Period__c = :accountingPeriodId ' +
                'AND Ledger__c IN :ledgerIds ' +
                'AND IsTranslatedCube__c = false ' +
                'AND (Current_Period__c != 0 OR Opening_Balance__c != 0)';
        return DomainUtils.getQueryLocatorForFCTranslationBatch(query, accountingPeriodId, ledgerIds);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        if (!isError) {
            try {
                List<Financial_Cube__c> cubesToProcess = new List<Financial_Cube__c>();
                Set<String> existedCubeKey = new Set<String>();
                Set<Id> existedLedgers = new Set<Id>();

                for (Financial_Cube__c fc : (List<Financial_Cube__c>) scope) {
                    existedCubeKey.add(fc.Key__c + targetCurrency);
                    existedLedgers.add(fc.Ledger__c);
                    if (MultiCurrencyHandler.isMultiCurrencyEnabled && !LedgerHandler.isLedgerCurrency(targetCurrency, fc.Ledger__c)) {
                        cubesToProcess.add(fc);
                    }
                }

                if (!cubesToProcess.isEmpty()) {
                    validateGLAcctRateType(cubesToProcess);
                }

                if (!cubesToProcess.isEmpty() && !isError) {
                    validateAvailableActiveCurrency(cubesToProcess);
                }

                if (!cubesToProcess.isEmpty() && !isError) {
                    validateExchangeTables(cubesToProcess);
                }

                if (!existedCubeKey.isEmpty() && !isError) {
                    deleteOldTranslationFinCubes(existedCubeKey);
                }

                if (!existedLedgers.isEmpty() && !isError) {
                    deleteOldCTAFinCubes(existedLedgers);
                }

                if (!cubesToProcess.isEmpty() && !isError) {
                    insertNewTranslationFinCubes(processFinCubes(cubesToProcess));
                }
            }
            catch (Exception ex) {
                isError = true;
                errorMsg = ex.getMessage();
            }
        }
    }

    public void finish(Database.BatchableContext batchableContext) {
        if (!isError && !cyeBalance.isEmpty()) {
            List<Financial_Cube__c> cyeFinCubes = processCYEFinCubes();
            if (!cyeFinCubes.isEmpty()) {
                insertNewTranslationFinCubes(cyeFinCubes);
            }
        }

        if (!isError && !ledgerBalance.isEmpty()) {
            List<Financial_Cube__c> cumulativeFinCubes = processCumulativeFinCubes();
            if (!cumulativeFinCubes.isEmpty()) {
                insertNewTranslationFinCubes(cumulativeFinCubes);
            }
        }

        if (this.runConsolidationRoutine && !isError) {
            ConsolidationRoutineBatch consolidationBatchInstance = new ConsolidationRoutineBatch(
                this.mainLedgerHierarchyModel,
                this.accountingPeriodId,
                this.runForChildren
            );
            Database.executeBatch(consolidationBatchInstance);
        }
        else if (this.runConsolidationRoutine && isError) {
            createAutomatedJobResult();
            createActivity();
            updateLedgerHierarchyStatus();
        }
    }

    private void createAutomatedJobResult() {
        Integer total = runForChildren ? 0 : 1;
        Integer succeeded = 0;

        if (runForChildren) {
            // Count the total batch jobs and the successful batch jobs.
            // One batch job per `LedgerHierarchyModel`.
            LedgerHierarchyModel.Iterator itr = new LedgerHierarchyModel.Iterator(this.mainLedgerHierarchyModel);
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
        AutomatedJobResultsHandler.setJobType(ConsolidationRoutineBatch.JOB_NAME);
        AutomatedJobResultsHandler.setProcessed(total);
        AutomatedJobResultsHandler.setSucceeded(succeeded);
        AutomatedJobResultsHandler.setFailed(total - succeeded);
        if (AutomatedJobResultsHandler.isReportExist(ConsolidationRoutineBatch.JOB_NAME)) {
            AutomatedJobResultsHandler.addNote(
                AutomatedJobResultsHandler.getReportLink(ConsolidationRoutineBatch.JOB_NAME)
            );
        }
        AutomatedJobResultsHandler.saveAutomatedJobResults();
    }

    private void createActivity() {
        Task activity = FinancialSuiteUtils.setTask(
            currentLedgerHierarchyModel.value.Id,
            ConsolidationRoutineBatch.ACTIVITY_STATUS,
            ConsolidationRoutineBatch.ACTIVITY_PRIORITY,
            ConsolidationRoutineBatch.ACTIVITY_SUBJECT,
            errorMsg,
            UserInfo.getUserId()
        );
        SFDCSecurityUtils.insertProxy(activity);
    }

    private void updateLedgerHierarchyStatus() {
        List<Ledger_Hierarchy__c> ledgerHierarchiesToUpdate = new List<Ledger_Hierarchy__c>();

        currentLedgerHierarchyModel.value.Hierarchy_Status__c = LedgerHierarchyActions.LEDGER_HIERARCHY_STATUS_ERROR;
        currentLedgerHierarchyModel.value.Last_Period_Run__c = accountingPeriodId;
        ledgerHierarchiesToUpdate.add(currentLedgerHierarchyModel.value);

        if (runForChildren) {
            while (this.lhIterator.hasNext()) {
                LedgerHierarchyModel currentLH = this.lhIterator.next();
                if (currentLedgerHierarchyModel.value.Id != currentLH.value.Id) {
                    Ledger_Hierarchy__c ledgerHierarchyToUpdate = currentLH.value;
                    ledgerHierarchyToUpdate.Hierarchy_Status__c = LedgerHierarchyActions.LEDGER_HIERARCHY_STATUS_NOT_RUN;
                    ledgerHierarchiesToUpdate.add(ledgerHierarchyToUpdate);
                }
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

    private void validateAvailableActiveCurrency(List<Financial_Cube__c> cubesToProcess) {
        Map<SObjectField, Set<String>> uniquePicklistValuesBySObjectFields =
                FinancialSuiteUtils.fetchUniquePicklistValuesBySObjectFields(new List<SObjectField>{Exchange_Rate__c.From_Currency_Code__c});
        Set<String> currencyCodeCustomPicklistValues = uniquePicklistValuesBySObjectFields.get(Exchange_Rate__c.From_Currency_Code__c);

        for (Financial_Cube__c cube : cubesToProcess) {
            String ledgerCurrency = (String)cube.Ledger__r.get('CurrencyIsoCode');
            if (currencyCodeCustomPicklistValues == null ||
                    !currencyCodeCustomPicklistValues.contains(ledgerCurrency) ||
                    !currencyCodeCustomPicklistValues.contains(this.targetCurrency)) {
                isError = true;
                errorMsg = String.format(
                        ExchangeRateProvider.EXCHANGE_RATE_ERROR,
                        new List<String>{
                            cube.GL_Account__r.Rate_Type__c,
                            accountingPeriod.Name
                        }
                );
                break;
            }
        }
    }

    private void validateGLAcctRateType(List<Financial_Cube__c> cubesToProcess) {
        for (Financial_Cube__c cube : cubesToProcess) {
            if (!isCYECube(cube) && String.isBlank(cube.GL_Account__r.Rate_Type__c)) {
                isError = true;
                errorMsg = GL_ACCT_RATE_TYPE_ERROR;
                break;
            }
        }
    }

    private Boolean isCYECube(Financial_Cube__c cube) {
        Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(cube.Ledger__c);
        return cube.Cube_Type__c == FinancialCubeActions.FINANCIAL_CUBE_CURRENT_YEAR_EARNINGS
            || cube.GL_Account__c == defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT)?.GL_Account__c;
    }

    private void validateExchangeTables(List<Financial_Cube__c> cubesToProcess) {
        List<ExchangeRateProvider.ExchangeRateWrapper> paramsToValidate = new List<ExchangeRateProvider.ExchangeRateWrapper>();
        for (Financial_Cube__c cube : cubesToProcess) {
            if (!isCYECube(cube)) {
                paramsToValidate.add(
                    new ExchangeRateProvider.ExchangeRateWrapper(
                        accountingPeriod.Start_Date__c,
                        accountingPeriod.End_Date__c,
                        (String) cube.get('CurrencyIsoCode'),
                        targetCurrency,
                        cube.GL_Account__r.Rate_Type__c
                    ).accountingPeriodName(accountingPeriod.Name)
                );
            }
        }

        ExchangeRateProvider.AllExchangeRateTablesValidationResult validationResult = ExchangeRateProvider.isAllExchangeRateTablesValid(paramsToValidate);
        if (!validationResult.isValid) {
            isError = true;
            errorMsg = String.format(
                    ExchangeRateProvider.EXCHANGE_RATE_ERROR,
                    !validationResult.notValidRateTables.isEmpty() ?
                    new List<String>{
                        validationResult.notValidRateTables[0].rateType,
                        validationResult.notValidRateTables[0].accountingPeriodName
                    } :
                    new List<String>()
            );
        }
    }

    private List<Financial_Cube__c> processCYEFinCubes() {
        List<Financial_Cube__c> cubesResult = new List<Financial_Cube__c>();
        for (String key : cyeBalance.keySet()) {
            CYEBalanceContainer bc = cyeBalance.get(key);
            if (bc != null && bc.translatedCYECube != null) {
                bc.translatedCYECube.Amount__c = bc.amount;
                bc.translatedCYECube.Opening_Balance__c = bc.openingBalance;
                cubesResult.add(bc.translatedCYECube);
            }
        }
        return cubesResult;
    }

    private List<Financial_Cube__c> processCumulativeFinCubes() {
        List<Financial_Cube__c> cubesResult = new List<Financial_Cube__c>();
        for (Id ledgerId : ledgerBalance.keySet()) {
            LedgerBalanceContainer lbc = ledgerBalance.get(ledgerId);
            if (lbc != null && lbc.hasBalance()) {
                cubesResult.add(getCumulativeCube(ledgerId, ledgerBalance.get(ledgerId)));
            }
        }
        return cubesResult;
    }

    private Financial_Cube__c getCumulativeCube(Id ledgerId, LedgerBalanceContainer lbc) {
        Financial_Cube__c resultCube = new Financial_Cube__c();
        Ledger__c currentLedger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(ledgerId);

        Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(ledgerId);

        resultCube.Ledger__c = ledgerId;
        resultCube.GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CTA_GL_ACCOUNT)?.GL_Account__c;
        resultCube.IsTranslatedCube__c = true;
        resultCube.Accounting_Period__c = accountingPeriodId;
        resultCube.Amount__c = lbc.amount * -1;
        resultCube.Opening_Balance__c = lbc.openingBalance * -1;
        resultCube.Translation_Name__c = CTA_LABEL;
        resultCube.put('CurrencyIsoCode', targetCurrency);

        if (LedgerHandler.isConsolidationLedger(currentLedger)) {
            resultCube.Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_CONSOLIDATIONS;
        }
        return resultCube;
    }

    private List<Financial_Cube__c> processFinCubes(List<Financial_Cube__c> cubesToProcess) {
        List<Financial_Cube__c> cubesResult = new List<Financial_Cube__c>();
        for (Financial_Cube__c fc : cubesToProcess) {
            Financial_Cube__c translatedCube = getTranslatedCube(fc);
            if (isCYECube(fc)) {
                addCEYCube(translatedCube);
            }
            if (isValidForCalculateBalanceCubeType(fc)) {
                calculateLedgerBalance(translatedCube);
                calculateCEYBalance(translatedCube, fc);
            }

            if (!isCYECube(fc)) {
                cubesResult.add(translatedCube);
            }
        }
        return cubesResult;
    }

    private Boolean isValidForCalculateBalanceCubeType(Financial_Cube__c fc) {
        Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(fc.Ledger__c);
        return fc.Cube_Type__c != FinancialCubeActions.FINANCIAL_CUBE_CURRENT_YEAR_EARNINGS
            && fc.Cube_Type__c != FinancialCubeActions.FINANCIAL_CUBE_CASH_FLOW
            && fc.GL_Account__c != defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT)?.GL_Account__c
            && fc.GL_Account__r.Type__c != GLAccountActions.GL_ACCOUNT_TYPE_CASH_FLOW;
    }

    private Financial_Cube__c getTranslatedCube(Financial_Cube__c cube) {
        Decimal rate = 1;
        if (!isCYECube(cube)) {
            rate = ExchangeRateProvider.getExchangeRateForPeriod(
                accountingPeriod.Start_Date__c,
                accountingPeriod.End_Date__c,
                (String) cube.get('CurrencyIsoCode'),
                targetCurrency,
                cube.GL_Account__r.Rate_Type__c
            );
        }

        Financial_Cube__c resultCube = new Financial_Cube__c();
        resultCube.Ledger__c = cube.Ledger__c;
        resultCube.Accounting_Period__c = cube.Accounting_Period__c;
        resultCube.GL_Account__c = cube.GL_Account__c;
        resultCube.Key_Group__c = cube.Key_Group__c;
        resultCube.Key__c = cube.Key__c + targetCurrency;
        resultCube.GL_Account_Variable_1__c = cube.GL_Account_Variable_1__c;
        resultCube.GL_Account_Variable_2__c = cube.GL_Account_Variable_2__c;
        resultCube.GL_Account_Variable_3__c = cube.GL_Account_Variable_3__c;
        resultCube.GL_Account_Variable_4__c = cube.GL_Account_Variable_4__c;
        resultCube.Cube_Type__c = cube.Cube_Type__c;
        resultCube.put('CurrencyIsoCode', targetCurrency);
        resultCube.IsTranslatedCube__c = true;
        resultCube.Source_Cube__c = cube.Id;
        resultCube.Amount__c = (cube.Current_Period__c * (rate != null ? rate : 1)).setScale(2, System.RoundingMode.HALF_UP);
        resultCube.Opening_Balance__c = (cube.Opening_Balance__c * (rate != null ? rate : 1)).setScale(2, System.RoundingMode.HALF_UP);
        resultCube.Translation_Name__c =
            LedgerHandler.getInstanceWithoutSharing().getLedgerById(cube.Ledger__c).Name + ' ' + (String) resultCube.get('CurrencyIsoCode');
        resultCube.Translated_Rate__c = rate;
        return resultCube;
    }

    private void addCEYCube(Financial_Cube__c translatedCube) {
        if (cyeBalance.keySet().contains(getKey(translatedCube))) {
            cyeBalance.get(getKey(translatedCube)).setCube(translatedCube);
        }
        else {
            cyeBalance.put(getKey(translatedCube), new CYEBalanceContainer(translatedCube));
        }
    }

    private void calculateCEYBalance(Financial_Cube__c translatedCube, Financial_Cube__c originalCube) {
        if (originalCube.GL_Account_Type__c == GLAccountActions.GL_ACCOUNT_TYPE_EXPENSE
            || originalCube.GL_Account_Type__c == GLAccountActions.GL_ACCOUNT_TYPE_REVENUE) {
            if (cyeBalance.keySet().contains(getKey(translatedCube))) {
                cyeBalance.get(getKey(translatedCube)).addToBalance(translatedCube.Amount__c, translatedCube.Opening_Balance__c);
            }
            else {
                cyeBalance.put(getKey(translatedCube), new CYEBalanceContainer(translatedCube.Amount__c, translatedCube.Opening_Balance__c));
            }
        }
    }

    private String getKey(Financial_Cube__c originalCube) {
        String acctVar1 = originalCube.GL_Account_Variable_1__c != NULL ? String.valueOf(originalCube.GL_Account_Variable_1__c) : 'null';
        String acctVar2 = originalCube.GL_Account_Variable_2__c != NULL ? String.valueOf(originalCube.GL_Account_Variable_2__c) : 'null';
        String acctVar3 = originalCube.GL_Account_Variable_3__c != NULL ? String.valueOf(originalCube.GL_Account_Variable_3__c) : 'null';
        String acctVar4 = originalCube.GL_Account_Variable_4__c != NULL ? String.valueOf(originalCube.GL_Account_Variable_4__c) : 'null';
        return String.valueOf(originalCube.Ledger__c) + acctVar1 + acctVar2 + acctVar3 + acctVar4;
    }

    private void calculateLedgerBalance(Financial_Cube__c translatedCube) {
        if (ledgerBalance.keySet().contains(translatedCube.Ledger__c)) {
            ledgerBalance.get(translatedCube.Ledger__c).addToBalance(translatedCube);
        }
        else {
            ledgerBalance.put(translatedCube.Ledger__c, new LedgerBalanceContainer(translatedCube));
        }
    }

    private void deleteOldTranslationFinCubes(Set<String> existedCubeKey) {
        try {
            List<Financial_Cube__c> consCubes = DomainUtils.getTranslatedFinancialCubesByKey(existedCubeKey);
            FinancialCubeActions.isPreventOverride = true;
            SFDCSecurityUtils.deleteProxy(consCubes);
            FinancialCubeActions.isPreventOverride = false;
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    private void deleteOldCTAFinCubes(Set<Id> existedLedgers) {
        try {
            Set<Id> glAccountIds = new Set<Id>();
            for (Map<String, GL_Account_Default__c> defaultsBySpecDevNames : GLAccount.glAccountDefaultsMapByLedgerId(existedLedgers).values()) {
                glAccountIds.add(defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CTA_GL_ACCOUNT)?.GL_Account__c);
            }

            List<Financial_Cube__c> ctaCubes = DomainUtils.getFinancialCubesByGLAccountAndLedgerAndPeriod(
                glAccountIds,
                existedLedgers,
                new Set<Id> {accountingPeriodId}
            );
            FinancialCubeActions.isPreventOverride = true;
            SFDCSecurityUtils.deleteProxy(ctaCubes);
            FinancialCubeActions.isPreventOverride = false;
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    private void insertNewTranslationFinCubes(List<Financial_Cube__c> fCubesToInsert ) {
        try {
            FinancialCubeActions.isPreventOverride = true;
            SFDCSecurityUtils.insertProxy(fCubesToInsert);
            FinancialCubeActions.isPreventOverride = false;
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    private void validateCumulativeGLAccount () {
        ServiceResult sr = ExchangeRateProvider.validateCumulativeTranslateGLAccount(this.ledgerIds);
        isError = !sr.isSuccess;
        errorMsg = sr.data;
    }

    public with sharing class LedgerBalanceContainer {
        public Decimal amount;
        public Decimal openingBalance;
        public Id ledgerId;

        public LedgerBalanceContainer(Financial_Cube__c fCube) {
            this.openingBalance = (fCube.Opening_Balance__c != null) ? fCube.Opening_Balance__c : 0;
            this.amount = (fCube.Amount__c != null) ? fCube.Amount__c : 0;
            this.ledgerId = fCube.Ledger__c;
        }

        public void addToBalance(Financial_Cube__c fCube) {
            this.openingBalance += ((fCube.Opening_Balance__c != null) ? fCube.Opening_Balance__c : 0);
            this.amount += ((fCube.Amount__c != null) ? fCube.Amount__c : 0);
        }

        public Boolean hasBalance() {
            return openingBalance != 0 || amount != 0;
        }
    }

    public with sharing class CYEBalanceContainer {
        public Financial_Cube__c translatedCYECube;
        public Decimal amount = 0;
        public Decimal openingBalance = 0;

        public CYEBalanceContainer(Financial_Cube__c fCube) {
            setCube(fCube);
        }

        public CYEBalanceContainer(Decimal amount, Decimal openingBalance) {
            addToBalance(amount, openingBalance);
        }

        public void addToBalance(Decimal amount, Decimal openingBalance) {
            this.amount += (amount != null) ? amount : 0;
            this.openingBalance += (openingBalance != null) ? openingBalance : 0;
        }

        public void setCube(Financial_Cube__c fCube) {
            translatedCYECube = fCube;
        }
    }

}