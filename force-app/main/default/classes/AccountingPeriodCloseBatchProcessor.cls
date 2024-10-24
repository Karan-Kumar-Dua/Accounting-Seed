public with sharing class AccountingPeriodCloseBatchProcessor implements Database.Batchable<SObject>, Database.Stateful {

    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private AccountingPeriodOpenCloseOptions periodInfoContainer;
    private String query;
    private Boolean isError;
    public class CurrentYearAndRetainedEarningsException extends Exception {}

    public AccountingPeriodCloseBatchProcessor(AccountingPeriodOpenCloseOptions periodInfoContainer) {
        this.periodInfoContainer = periodInfoContainer;
        this.isError = false;

        // We are iterating though the list of current year cubes in an iterative fashion and we are ordering by the gl account variable ids
        this.query =
            'SELECT Id, ' +
                    PACKAGE_QUALIFIER + 'Accounting_Period__c, ' +
                    PACKAGE_QUALIFIER + 'GL_Account__c, ' +
                    PACKAGE_QUALIFIER + 'GL_Account__r.' + PACKAGE_QUALIFIER + 'Type__c, ' +
                    PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c, ' +
                    PACKAGE_QUALIFIER + 'GL_Account_Variable_2__c, ' +
                    PACKAGE_QUALIFIER + 'GL_Account_Variable_3__c, ' +
                    PACKAGE_QUALIFIER + 'GL_Account_Variable_4__c, ' +
                    PACKAGE_QUALIFIER + 'Opening_Balance__c, ' +
                    PACKAGE_QUALIFIER + 'Amount__c, ' +
                    PACKAGE_QUALIFIER + 'Key_Group__c, ' +
                    PACKAGE_QUALIFIER + 'Cube_Type__c, ' +
                    PACKAGE_QUALIFIER + 'Transaction_Amount__c, ' +
                    PACKAGE_QUALIFIER + 'Ledger__c ' +
            'FROM ' + PACKAGE_QUALIFIER + 'Financial_Cube__c ' +
            'WHERE ' + PACKAGE_QUALIFIER + 'Ledger_Type__c IN (\'Transactional\', \'Eliminations-Transactional\')' +
            'AND (' +
                    PACKAGE_QUALIFIER + 'Cube_Type__c = \'Period\' ' +
                'OR ' + PACKAGE_QUALIFIER + 'Cube_Type__c = \'Cash Flow\'' +
            ') ' +
            'AND ' + PACKAGE_QUALIFIER + 'Accounting_Period__c = \'' + periodInfoContainer.getCurrentPeriod().Id + '\' ' +
            'AND Source_Cube__c = null ' +
            'ORDER BY ' +
                PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c, ' +
                PACKAGE_QUALIFIER + 'GL_Account_Variable_2__c, ' +
                PACKAGE_QUALIFIER + 'GL_Account_Variable_3__c, ' +
                PACKAGE_QUALIFIER + 'GL_Account_Variable_4__c';
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return DomainUtils.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        try {
            FinancialCubesPeriodProcessor fcp = new FinancialCubesPeriodProcessor(periodInfoContainer, (List<Financial_Cube__c>) scope);
            fcp.calculateNextPeriodFinancialCubes();

            FinancialCubesCurrentYearEarningsProcessor fce = new FinancialCubesCurrentYearEarningsProcessor(periodInfoContainer,(List<Financial_Cube__c>) scope);
            fce.calculateCurrentYearEarnings();

            FinancialCubesRetainedEarningsProcessor fre = new FinancialCubesRetainedEarningsProcessor(periodInfoContainer, fce.currentYearEarningsMap);
            fre.calculateRetainedEarningsForNewFiscalYear();
        }
        catch (Exception ex) {
            isError = true;
            AccountingPeriodOpenCloseUtils.rollBackAndNotify(ex, periodInfoContainer);
        }
    }

    public void finish(Database.BatchableContext bc) {
        try {
            if (!isError) {
                Database.executeBatch(
                    new AccountingPeriodCloseRetainedEarnings(periodInfoContainer)
                );
            }
        }
        catch (Exception ex) {
            AccountingPeriodOpenCloseUtils.rollBackAndNotify(ex, periodInfoContainer);
        }
    }

    @TestVisible
    private with sharing class FinancialCubesPeriodProcessor {
        private AbstractFinancialCube fcw;
        private List<Financial_Cube__c> currentPeriodFCubeList;
        private Set<String> currentPeriodsKeyGroupSet;
        private Map<String, Financial_Cube__c> nextPeriodCubesMap;
        private AccountingPeriodOpenCloseOptions periodInfoContainer;

        public FinancialCubesPeriodProcessor(AccountingPeriodOpenCloseOptions periodInfoContainer, List<Financial_Cube__c> currentPeriodFCubeList) {
            this.periodInfoContainer = periodInfoContainer;
            this.currentPeriodFCubeList = currentPeriodFCubeList;
            setCurrentPeriodKeyGroupSet();
            setPeriodCubesMapByPeriodKeyGroup();
        }

        public void calculateNextPeriodFinancialCubes() {
            try {
                for (Financial_Cube__c fCube : currentPeriodFCubeList) {
                    // Check to see if financial cube already exists for the next accounting period;
                    // Create opening balance financial cube for next accounting period if does not exist
                    fcw = new FinancialCubePeriod(fCube);
                    
                    if (!nextPeriodCubesMap.containsKey(fcw.getKeyGroup())
                            && fcw.isOpeningBalanceOrTransactionAmountNonZero()) {

                        Financial_Cube__c newCube = fcw.createCube(periodInfoContainer.getNextYear(), periodInfoContainer.getNextPeriod().Id);
                        nextPeriodCubesMap.put(fcw.getKeyGroup(), newCube);
                    }

                    // If not beginning of new accounting year or balance sheet carry opening balance over to next accounting period for the period financial cube.
                    // We all carry over the balance for a balance sheet gl account
                    // In the case of a revenue or expense gl account, we carry over for non year end accounting periods.
                    // For year end period, we set the opening balance to 0
                    if ((!periodInfoContainer.isNextMonthNewFiscalYear() || fcw.isBalanceSheetGLAccount())
                            && nextPeriodCubesMap.containsKey(fcw.getKeyGroup())) {

                        nextPeriodCubesMap.get(fcw.getKeyGroup()).Opening_Balance__c =
                            fcw.getTransactionAmount() + fcw.getOpeningBalance();
                    }
                    else if (nextPeriodCubesMap.containsKey(fcw.getKeyGroup()) && fcw.isPeriodCube()) {
                        nextPeriodCubesMap.get(fcw.getKeyGroup()).Opening_Balance__c = 0;
                    }
                }

                FinancialCubeActions.isPreventOverride = true;
                SFDCSecurityUtils.upsertProxy(nextPeriodCubesMap.values());
                FinancialCubeActions.isPreventOverride = false;
            }
            catch (Exception ex) {
                throw ex;
            }     
        }

        private void setCurrentPeriodKeyGroupSet() {
            currentPeriodsKeyGroupSet = new Set<String>();
            // Loop through the current period batch of cubes to set up a map to query for the next period cubes which match on the key group
            for (Financial_Cube__c fCube : currentPeriodFCubeList) {
                fcw = new FinancialCubePeriod(fCube);
                currentPeriodsKeyGroupSet.add(fcw.getKeyGroup());
            }
        }

        private void setPeriodCubesMapByPeriodKeyGroup() {
            nextPeriodCubesMap = new Map<String, Financial_Cube__c>();
            // Query and retrieve cubes for next accounting period; need to update the opening balance for the cubes
            Set<String> ledgerTypes = new Set<String>{LedgerActions.LEDGER_TYPE_TRANSACTIONAL, LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL};
            Set<String> cubeTypes = new Set<String>{FinancialCubeActions.FINANCIAL_CUBE_PERIOD, FinancialCubeActions.FINANCIAL_CUBE_CASH_FLOW};
            for (Financial_Cube__c fCube : DomainUtils.getFinancialCubesByLedgerByTypeByPeriodByGroupKeys(
                ledgerTypes, cubeTypes, periodInfoContainer.getNextPeriod().Id, currentPeriodsKeyGroupSet)
            ) {
                fcw = new FinancialCubePeriod(fCube);
                nextPeriodCubesMap.put(fcw.getKeyGroup(), fCube);
            }
        }
    }

    @TestVisible
    private with sharing class FinancialCubesCurrentYearEarningsProcessor {
        private AbstractFinancialCube fcw;
        private List<Financial_Cube__c> currentPeriodFCubeList;
        private Set<String> currentYearEarningsKeyGroupSet;
        public Map<String, Financial_Cube__c> currentYearEarningsMap {get; private set;}
        private AccountingPeriodOpenCloseOptions periodInfoContainer;

        public FinancialCubesCurrentYearEarningsProcessor(AccountingPeriodOpenCloseOptions periodInfoContainer, List<Financial_Cube__c> currentPeriodFCubeList) {
            this.periodInfoContainer = periodInfoContainer;
            this.currentPeriodFCubeList = currentPeriodFCubeList;
            setCurrentYearEarningsKeyGroupSet();
            setCurrentYearEarningsMap();
        }

        public void calculateCurrentYearEarnings() {
            try {
                // Loop through the current period cubes to calculate the current year earnings for the next accounting period
                for (Financial_Cube__c fCube : currentPeriodFCubeList) {
                    fcw = new FinancialCubeCurrentYearEarnings(fCube, getCurrentYearEarningsGLAccount(fCube.Ledger__c));
                    
                    if (fcw.isPeriodCube()) {
                        String currentYearEarningsKeyGroup = fcw.getKeyGroup();

                        // if this is a revenue or expense period financial cube we are going to calculate the current year earnings
                        if (fcw.isRevenueOrExpenseGLAccount()
                                && currentYearEarningsMap.containsKey(currentYearEarningsKeyGroup)) {

                            currentYearEarningsMap.get(currentYearEarningsKeyGroup).Amount__c += fcw.getTransactionAmount();
                            currentYearEarningsMap.get(currentYearEarningsKeyGroup).Opening_Balance__c += fcw.getOpeningBalance();
                        }
                        else if (fcw.isRevenueOrExpenseGLAccount()) {
                            Financial_Cube__c newCube = fcw.createCube(periodInfoContainer.getCurrentYear(), periodInfoContainer.getCurrentPeriod().Id);
                            newCube.Opening_Balance__c = getOpeningBalanceNewCurrentYearEarningsCube();
                            newCube.Amount__c = fcw.getTransactionAmount();
                            currentYearEarningsMap.put(currentYearEarningsKeyGroup, newCube);
                        }
                    }
                }

                FinancialCubeActions.isPreventOverride = true;
                SFDCSecurityUtils.upsertProxy(currentYearEarningsMap.values());
                FinancialCubeActions.isPreventOverride = false;
            }
            catch (Exception ex) {
                throw ex;
            }
        }

        private void setCurrentYearEarningsKeyGroupSet() {
            currentYearEarningsKeyGroupSet = new Set<String>();
            // Set up the current year earnings key group set to query for current year earnings cubes that exist in the current period
            for (Financial_Cube__c fCube : currentPeriodFCubeList) {
                fcw = new FinancialCubeCurrentYearEarnings(fCube, getCurrentYearEarningsGLAccount(fCube.Ledger__c));
                if (fcw.isPeriodCube()) {
                    currentYearEarningsKeyGroupSet.add(fcw.getKeyGroup());
                }
            }
        }

        private void setCurrentYearEarningsMap() {
            currentYearEarningsMap = new Map<String, Financial_Cube__c>();
            Set<String> ledgerTypes = new Set<String>{LedgerActions.LEDGER_TYPE_TRANSACTIONAL, LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL};
            Set<String> cubeTypes = new Set<String>{FinancialCubeActions.FINANCIAL_CUBE_CURRENT_YEAR_EARNINGS};
            for (Financial_Cube__c fCube : DomainUtils.getFinancialCubesByLedgerByTypeByPeriodByGroupKeys(
                ledgerTypes,
                cubeTypes,
                periodInfoContainer.getCurrentPeriod().Id,
                currentYearEarningsKeyGroupSet
            )) {
                fcw = new FinancialCubeCurrentYearEarnings(fCube, getCurrentYearEarningsGLAccount(fCube.Ledger__c));
                currentYearEarningsMap.put(fcw.getKeyGroup(), fCube);
            }
        }

        private Decimal getOpeningBalanceNewCurrentYearEarningsCube() {
            return periodInfoContainer.isCurrentMonthNewFiscalYear() ? 0 : fcw.getOpeningBalance();
        }

        private Id getCurrentYearEarningsGLAccount(Id ledgerId) {
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(ledgerId);
            if (defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT) != null) {
                return defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT)?.GL_Account__c;
            }
            else {
                throw new CurrentYearAndRetainedEarningsException(AccountingPeriodOpenCloseUtils.CURRENT_EARNINGS_ERROR);
            }
        }
    }

    @TestVisible
    public with sharing class FinancialCubesRetainedEarningsProcessor {
        private AbstractFinancialCube fcw;
        private Map<String, Financial_Cube__c> currentPeriodCubeMap;
        private Map<String, Financial_Cube__c> retainedEarningsMap;

        private Set<String> retainedEarningsKeyGroupSet;
        private Map<String, Financial_Cube__c> periodRetainedEarningsMap;
        private AccountingPeriodOpenCloseOptions periodInfoContainer;

        public FinancialCubesRetainedEarningsProcessor(AccountingPeriodOpenCloseOptions periodInfoContainer, Map<String, Financial_Cube__c> currentPeriodCubeMap) {
            this.periodInfoContainer = periodInfoContainer;
            periodRetainedEarningsMap = new Map<String, Financial_Cube__c>();
            retainedEarningsMap = new Map<String, Financial_Cube__c>();
            this.currentPeriodCubeMap = currentPeriodCubeMap != NULL ? currentPeriodCubeMap : new Map<String, Financial_Cube__c>();
        }

        public void calculateRetainedEarningsNextPeriod() {
            try {
                setRetainedEarningsKeyGroupSet();
                setNextPeriodRetainedEarningsMap();
                retainedEarningsMap = new Map<String, Financial_Cube__c>();

                for (Financial_Cube__c fCube : currentPeriodCubeMap.values()) {
                    
                    fcw = new FinancialCubeRetainedEarnings(fCube, getRetainedEarningsGLAccount(fCube.Ledger__c));

                    // Check to see if retained earning cube exists in next period.
                    // If not create a new retained earnings cube for the next period.
                    if (!periodRetainedEarningsMap.containsKey(fcw.getKeyGroup())) {
                        Financial_Cube__c newCube = fcw.createCube(periodInfoContainer.getNextYear(), periodInfoContainer.getNextPeriod().Id);
                        newCube.Opening_Balance__c = fcw.getOpeningBalance();
                        retainedEarningsMap.put(fcw.getKeyGroup(), newCube);
                    }
                }
            
                insertRetainedEarnings();
            }
            catch (Exception ex) {
                throw ex;
            }
        }

        public void calculateRetainedEarningsForNewFiscalYear() {
            try {
                if (periodInfoContainer.isNextMonthNewFiscalYear()) {
                    setRetainedEarningsKeyGroupSet();
                    setCurrentPeriodRetainedEarningsMap();
                    retainedEarningsMap = new Map<String, Financial_Cube__c>();

                    for (Financial_Cube__c fCube : currentPeriodCubeMap.values()) {
                        fcw = new FinancialCubeRetainedEarnings(fCube, getRetainedEarningsGLAccount(fCube.Ledger__c));
                        Decimal currentPeriodRetEarningsAmount = 0;
                        
                        // if current period retained earnings has fin cube, get the amount.
                        if (periodRetainedEarningsMap.containsKey(fcw.getKeyGroup())) {
                            Financial_Cube__c retainedEarnings = periodRetainedEarningsMap.get(fcw.getKeyGroup());
                            currentPeriodRetEarningsAmount = retainedEarnings.Opening_Balance__c;
                        }

                        Financial_Cube__c newCube = fcw.createCube(periodInfoContainer.getNextYear(), periodInfoContainer.getNextPeriod().Id);
                        newCube.Opening_Balance__c = fcw.getOpeningBalance() + fcw.getAmount() + currentPeriodRetEarningsAmount;
                        retainedEarningsMap.put(fcw.getKeyGroup(), newCube);
                    }
                    //get already existed Retained Earnings FCs for the next period
                    setNextPeriodRetainedEarningsMap();
                    //check all new Retained Earnings FCs to update corresponding by keyGroup records in DB
                    Map<String, Financial_Cube__c> newAndUpdatedRetainedFinCubes = new Map<String, Financial_Cube__c>();
                    for (String keyGroup : retainedEarningsMap.keySet()) {
                        //Retained Earnings FC by given keyGroup exists in DB - need update Opening Balance
                        if (periodRetainedEarningsMap.containsKey(keyGroup)) {
                            Financial_Cube__c existedFinancialCube = periodRetainedEarningsMap.get(keyGroup);
                            Financial_Cube__c newFinancialCube = retainedEarningsMap.get(keyGroup);
                            existedFinancialCube.Opening_Balance__c = newFinancialCube.Opening_Balance__c;
                            newAndUpdatedRetainedFinCubes.put(keyGroup, existedFinancialCube);
                        }
                        else {//this Retained Earnings FC is brand new record
                            newAndUpdatedRetainedFinCubes.put(keyGroup, retainedEarningsMap.get(keyGroup));
                        }
                    }
                    FinancialCubeActions.isPreventOverride = true;
                    SFDCSecurityUtils.upsertProxy(newAndUpdatedRetainedFinCubes.values());
                    FinancialCubeActions.isPreventOverride = false;
                }
            }
            catch (Exception ex) {
                throw ex;
            }
        }

        private void insertRetainedEarnings() {
            try {
                FinancialCubeActions.isPreventOverride = true;
                SFDCSecurityUtils.insertProxy(retainedEarningsMap.values());
                FinancialCubeActions.isPreventOverride = false;
            }
            catch (Exception ex) {
                throw ex;
            }
        }

        private void setRetainedEarningsKeyGroupSet() {
            retainedEarningsKeyGroupSet = new Set<String>();
            // Set up the retained earnings key group set to query for retained earnings cubes that exist in the current period
            for (Financial_Cube__c fCube : currentPeriodCubeMap.values()) {
                fcw = new FinancialCubeRetainedEarnings(fCube, getRetainedEarningsGLAccount(fCube.Ledger__c));
                retainedEarningsKeyGroupSet.add(fcw.getKeyGroup());
            }
        }

        private void setCurrentPeriodRetainedEarningsMap() {
            setRetainedEarningsMap(periodInfoContainer.getCurrentPeriod().Id);
        }

        private void setNextPeriodRetainedEarningsMap() {
            setRetainedEarningsMap(periodInfoContainer.getNextPeriod().Id);
        }

        private void setRetainedEarningsMap(Id periodId) {
            periodRetainedEarningsMap = new Map<String, Financial_Cube__c>();
            Set<String> ledgerTypes = new Set<String>{LedgerActions.LEDGER_TYPE_TRANSACTIONAL, LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL};
            Set<String> cubeTypes = new Set<String>{FinancialCubeActions.FINANCIAL_CUBE_RETAINED_EARNINGS};
            for (Financial_Cube__c fCube : DomainUtils.getFinancialCubesByLedgerByTypeByPeriodByGroupKeys(
                ledgerTypes, cubeTypes, periodId, retainedEarningsKeyGroupSet
            )) {
                fcw = new FinancialCubeRetainedEarnings(fCube, getRetainedEarningsGLAccount(fCube.Ledger__c));
                periodRetainedEarningsMap.put(fcw.getKeyGroup(), fCube);
            }
        }

        private Id getRetainedEarningsGLAccount(Id ledgerId) {
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(ledgerId);
            if (defaultsBySpecDevNames.get(GLAccountDefaultsHandler.RETAINED_EARNINGS_GL_ACCOUNT) != null) {
                return defaultsBySpecDevNames.get(GLAccountDefaultsHandler.RETAINED_EARNINGS_GL_ACCOUNT)?.GL_Account__c;
            }
            else {
                throw new CurrentYearAndRetainedEarningsException(AccountingPeriodOpenCloseUtils.RETAINED_EARNINGS_ERROR);
            }
        }
    }

    private enum FinancialCubeType {PERIOD, CASH_FLOW, CURRENT_YEAR_EARNINGS, RETAINED_EARNINGS}
    private with sharing abstract class AbstractFinancialCube {
        private Financial_Cube__c fCube;
        protected FinancialCubeType cubeType;
        protected Id glAccountId;

        private final String PERIOD_NAME = FinancialCubeActions.FINANCIAL_CUBE_PERIOD;
        private final String CASH_FLOW_NAME = FinancialCubeActions.FINANCIAL_CUBE_CASH_FLOW;
        private final String CURRENT_YEAR_EARNINGS_NAME = FinancialCubeActions.FINANCIAL_CUBE_CURRENT_YEAR_EARNINGS;
        private final String RETAINED_EARNINGS_NAME = FinancialCubeActions.FINANCIAL_CUBE_RETAINED_EARNINGS;

        public AbstractFinancialCube(Financial_Cube__c fCube) {
            this.fCube = fCube;
            this.glAccountId = fCube.GL_Account__c;
        }

        public Financial_Cube__c createCube(Integer year, Id periodId) {
            Financial_Cube__c newCube = new Financial_Cube__c();
            newCube.Ledger__c = fCube.Ledger__c;
            newCube.Year__c = year;
            newCube.Accounting_Period__c = periodId;
            newCube.GL_Account__c = glAccountId;
            newCube.Cube_Type__c = getTypeName();
            newCube.GL_Account_Variable_1__c = fCube.GL_Account_Variable_1__c;
            newCube.GL_Account_Variable_2__c = fCube.GL_Account_Variable_2__c;
            newCube.GL_Account_Variable_3__c = fCube.GL_Account_Variable_3__c;
            newCube.GL_Account_Variable_4__c = fCube.GL_Account_Variable_4__c;
            newCube.Opening_Balance__c = 0;
            newCube.Amount__c = 0;

            return newCube;
        }

        private String getGLVarGroup() {
            String acctVar1 = fCube.GL_Account_Variable_1__c != NULL ? String.valueOf(fCube.GL_Account_Variable_1__c) : 'null';
            String acctVar2 = fCube.GL_Account_Variable_2__c != NULL ? String.valueOf(fCube.GL_Account_Variable_2__c) : 'null';
            String acctVar3 = fCube.GL_Account_Variable_3__c != NULL ? String.valueOf(fCube.GL_Account_Variable_3__c) : 'null';
            String acctVar4 = fCube.GL_Account_Variable_4__c != NULL ? String.valueOf(fCube.GL_Account_Variable_4__c) : 'null';
            return acctVar1 + acctVar2 + acctVar3 + acctVar4;
        }

        public Boolean isPeriodCube() {
            return fCube.Cube_Type__c == PERIOD_NAME;
        }

        public Boolean isRevenueOrExpenseGLAccount() {
            return
                (fCube.GL_Account__r.Type__c == GLAccountActions.GL_ACCOUNT_TYPE_REVENUE
                    || fCube.GL_Account__r.Type__c == GLAccountActions.GL_ACCOUNT_TYPE_EXPENSE);
        }

        public Boolean isBalanceSheetGLAccount() {
            return fCube.GL_Account__r.Type__c == GLAccountActions.GL_ACCOUNT_TYPE_BALANCE_SHEET;
        }

        public Decimal getOpeningBalance() {
            return fCube.Opening_Balance__c != NULL ? fCube.Opening_Balance__c : 0;
        }

        public Decimal getAmount() {
            return fCube.Amount__c != NULL ? fCube.Amount__c : 0;
        }

        public Decimal getTransactionAmount() {
            return fCube.Transaction_Amount__c != NULL ? fCube.Transaction_Amount__c : 0;
        }

        public Boolean isOpeningBalanceOrTransactionAmountNonZero() {
            return (getOpeningBalance() != 0 || getTransactionAmount() != 0);
        }

        public String getTypeName() {
            String typeName = '';

            if (cubeType == FinancialCubeType.PERIOD) {
                typeName = PERIOD_NAME;
            }
            else if (cubeType == FinancialCubeType.CASH_FLOW) {
                typeName = CASH_FLOW_NAME;
            }
            else if (cubeType == FinancialCubeType.CURRENT_YEAR_EARNINGS) {
                typeName = CURRENT_YEAR_EARNINGS_NAME;    
            }
            else if (cubeType == FinancialCubeType.RETAINED_EARNINGS) {
                typeName = RETAINED_EARNINGS_NAME;
            }

            return typeName;
        }

        public String getTypeNameNoSpace() {
            return getTypeName().remove(' ');
        }

        public String getKeyGroup() {
            return (fCube.Ledger__c + getTypeNameNoSpace() + String.valueOf(glAccountId) + getGLVarGroup());
        }
    }

    private with sharing class FinancialCubePeriod extends AbstractFinancialCube {

        public FinancialCubePeriod(Financial_Cube__c fCube) {
            super(fCube);
            cubeType = (isPeriodCube()) ? FinancialCubeType.PERIOD : FinancialCubeType.CASH_FLOW;
        }
    }

    private with sharing class FinancialCubeCurrentYearEarnings extends AbstractFinancialCube {
        
        public FinancialCubeCurrentYearEarnings(Financial_Cube__c fCube, Id glAccountId) {
            super(fCube);
            cubeType = FinancialCubeType.CURRENT_YEAR_EARNINGS;
            this.glAccountId = glAccountId;
        }
    }

    private with sharing class FinancialCubeRetainedEarnings extends AbstractFinancialCube {

        public FinancialCubeRetainedEarnings(Financial_Cube__c fCube, Id glAccountId) {
            super(fCube); 
            cubeType = FinancialCubeType.RETAINED_EARNINGS;
            this.glAccountId = glAccountId;
        }
    }
}