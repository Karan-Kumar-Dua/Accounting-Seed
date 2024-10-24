public with sharing class GLAccountCurrentBalanceController {

    private static final String MISSING_ARGUMENT_ERROR = Label.ERR_MISSING_GL_ACCOUNT;
    private static final String NO_LEDGERS_FOUND = Label.ERR_NO_LEDGER_AVAILAIBLE;
    private static final String TOO_MANY_FINANCIAL_CUBES_ERROR = Label.ERR_CURRENT_BALANCE_AGGREGATION_LIMIT;

    @AuraEnabled
    public static GLAccountCurrentBalanceSettings getSettings(Id recordId) {
        GLAccountCurrentBalanceSettings result;
        try {
            GL_Account__c theGlAccount = DomainUtils.getGlAccountsById(new Set<Id>{recordId}).get(0);
            GLAccountType glType = getGLAccountType(theGlAccount);
            List<Ledger__c> ledgers = LedgerHandler.getInstanceWithSharing().getTransactionalLedgers();
            result = new GLAccountCurrentBalanceSettings(glType, ledgers);
        }
        catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
        return result;
    }

    @AuraEnabled
    public static GLAccountCurrentBalanceResult getCurrentBalance(String recordId, String ledgerId) {
        try {
            if (String.isBlank(recordId)) {
                throw new GLAccountCurrentBalanceException(MISSING_ARGUMENT_ERROR);
            }
            if (String.isBlank(ledgerId)) {
                throw new GLAccountCurrentBalanceException(NO_LEDGERS_FOUND);
            }

            GL_Account__c theGlAccount = DomainUtils.getGlAccountsById(new Set<Id>{recordId}).get(0);
            //set of preliminary DB queries to consume query rows limit in advance before aggregation
            String ledgerCurrency = LedgerHandler.getLedgerCurrency(ledgerId);
            if (MultiCurrencyHandler.isMultiCurrencyEnabled && MultiCurrencyHandler.CORPORATE_CURRENCY != ledgerCurrency) {
                Map<String, SObject> allCurrencies = MultiCurrencyHandler.allCurrencies;
            }
            //=======================================================================================

            Decimal balance;
            GLAccountType glType = getGLAccountType(theGlAccount);
            if (glType == GLAccountType.BALANCE_SHEET) {
                balance = getCurrentBalanceForBalanceSheetGlAccount(theGlAccount, ledgerId);
            }
            else if (glType == GLAccountType.PROFIT_AND_LOSS) {
                balance = getCurrentBalanceForProfitAndLossGlAccount(theGlAccount, ledgerId);
            }

            return new GLAccountCurrentBalanceResult(balance, ledgerCurrency);
        }
        catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    private static Decimal getCurrentBalanceForBalanceSheetGlAccount(GL_Account__c theGlAccount, Id ledgerId) {
        AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
        Accounting_Period__c currentPeriod = acctPeriodHandler.getAccountingPeriodByDate(Date.today());
        Accounting_Period__c lastClosedPeriod = acctPeriodHandler.getLastClosedOrArchivedAccountingPeriod();
        List<Accounting_Period__c> priorOpenPeriods = acctPeriodHandler.getPreviousAccountingPeriods(
            currentPeriod,
            new Set<String>{AccountingPeriodActions.OPEN_STATUS, AccountingPeriodActions.CLOSE_INTERIM_STATUS},
            true
        );

        return aggregateBalance(theGlAccount, ledgerId, currentPeriod, lastClosedPeriod, priorOpenPeriods);
    }

    private static Decimal getCurrentBalanceForProfitAndLossGlAccount(GL_Account__c theGlAccount, Id ledgerId) {
        AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
        Accounting_Period__c currentPeriod = acctPeriodHandler.getAccountingPeriodByDate(Date.today());
        List<Accounting_Period__c> priorPeriodsInCurrentYear = acctPeriodHandler.getPriorAccountingPeriodsForThisYear(currentPeriod, true);
        Accounting_Period__c lastClosedPeriodInCurrentYear;
        List<Accounting_Period__c> priorOpenPeriodsInCurrentYear = new List<Accounting_Period__c>();
        for (Accounting_Period__c period : priorPeriodsInCurrentYear) {
            if (period.Status__c == AccountingPeriodActions.CLOSED_STATUS
                || period.Status__c == AccountingPeriodActions.ARCHIVED_STATUS
                || period.Status__c == AccountingPeriodActions.ARCHIVE_IN_PROGRESS_STATUS
                || period.Status__c == AccountingPeriodActions.OPEN_INTERIM_STATUS) {

                lastClosedPeriodInCurrentYear = period;
            }
            else if (period.Status__c == AccountingPeriodActions.OPEN_STATUS
                || period.Status__c == AccountingPeriodActions.CLOSE_INTERIM_STATUS) {

                priorOpenPeriodsInCurrentYear.add(period);
            }
        }

        return aggregateBalance(theGlAccount, ledgerId, currentPeriod, lastClosedPeriodInCurrentYear, priorOpenPeriodsInCurrentYear);
    }

    private static Decimal aggregateBalance(GL_Account__c theGlAccount,
        Id ledgerId,
        Accounting_Period__c currentPeriod,
        Accounting_Period__c lastClosedPeriod,
        List<Accounting_Period__c> priorOpenPeriods) {

        Integer currentLimit = Limits.getLimitQueryRows() - Limits.getQueryRows();

        Decimal balance = 0;
        if (lastClosedPeriod != NULL) {
            Set<Id> accountingPeriodIds = new Set<Id>{lastClosedPeriod.Id};
            Integer numberOfRecordsIncludedInAggregation = DomainUtils.getCountFinancialCubesByPeriodAndGLAccountAndLedger(
                accountingPeriodIds, new Set<Id>{theGlAccount.Id}, new Set<Id>{ledgerId}
            );

            if (numberOfRecordsIncludedInAggregation > currentLimit) {
                throw new GLAccountCurrentBalanceException(TOO_MANY_FINANCIAL_CUBES_ERROR);
            }
            else {
                Decimal ytdBalance = (Decimal) DomainUtils.getYTDBalanceForFinancialCubesByPeriodAndGLAccountAndLedger(
                    accountingPeriodIds, new Set<Id>{theGlAccount.Id}, new Set<Id>{ledgerId}
                ).get(0).get('balance');
                balance += (ytdBalance != NULL) ? MultiCurrencyHandler.getNormalizedBalance(ytdBalance, LedgerHandler.getLedgerCurrency(ledgerId)) : 0;

                currentLimit = currentLimit - numberOfRecordsIncludedInAggregation;

                if (lastClosedPeriod.Id == currentPeriod.Id) {
                    return balance;
                }
            }
        }

        Set<Id> accountingPeriodIds = new Map<Id, Accounting_Period__c>(priorOpenPeriods).keySet();
        Integer numberOfRecordsIncludedInAggregation = DomainUtils.getCountFinancialCubesByPeriodAndGLAccountAndLedger(
            accountingPeriodIds, new Set<Id>{theGlAccount.Id}, new Set<Id>{ledgerId}
        );

        if (numberOfRecordsIncludedInAggregation > currentLimit) {
            throw new GLAccountCurrentBalanceException(TOO_MANY_FINANCIAL_CUBES_ERROR);
        }
        else {
            Decimal periodBalance = (Decimal) DomainUtils.getPeriodBalanceForFinancialCubesByPeriodAndGLAccountAndLedger(
                accountingPeriodIds, new Set<Id>{theGlAccount.Id}, new Set<Id>{ledgerId}
            ).get(0).get('balance');
            balance += (periodBalance != NULL) ? MultiCurrencyHandler.getNormalizedBalance(periodBalance, LedgerHandler.getLedgerCurrency(ledgerId)) : 0;
        }

        return balance;
    }

    private static GLAccountType getGLAccountType(GL_Account__c theGlAccount) {
        if (theGlAccount.Type__c == 'Balance Sheet') {
            return GLAccountType.BALANCE_SHEET;
        }
        else if (theGlAccount.Type__c == 'Revenue' || theGlAccount.Type__c == 'Expense') {
            return GLAccountType.PROFIT_AND_LOSS;
        }
        else {
            return GLAccountType.CASH_FLOW;
        }
    }

    public enum GLAccountType {BALANCE_SHEET, PROFIT_AND_LOSS, CASH_FLOW}

    public with sharing class GLAccountCurrentBalanceSettings {
        @AuraEnabled
        public Boolean singleLedger;
        @AuraEnabled
        public Boolean singleCurrency;
        @AuraEnabled
        public Boolean isFeatureAvailable;
        @AuraEnabled
        public List<Ledger__c> ledgers;
        @AuraEnabled
        public String baseCurrency;
        @AuraEnabled
        public Boolean isMultiCurrencyOrganization;

        public GLAccountCurrentBalanceSettings(GLAccountType glaType, List<Ledger__c> ledgers) {
            this.isFeatureAvailable = (glaType == GLAccountType.BALANCE_SHEET || glaType == GLAccountType.PROFIT_AND_LOSS);
            this.ledgers = ledgers;
            this.singleLedger = ledgers.size() <= 1;
            this.isMultiCurrencyOrganization = MultiCurrencyHandler.isMultiCurrencyEnabled;
            this.singleCurrency = countCurrencies(ledgers);
            this.baseCurrency = LedgerHandler.getLedgerCurrency(LedgerHandler.getLedgerId());
        }

        private Boolean countCurrencies(List<Ledger__c> ledgers) {
            Boolean result = true;
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                Set<String> currencies = new Set<String>();
                for (Ledger__c ledger : ledgers) {
                    currencies.add((String) ledger.get('CurrencyIsoCode'));
                }
                if (currencies.size() > 1) {
                    result = false;
                }
            }
            return result;
        }
    }

    public with sharing class GLAccountCurrentBalanceResult {
        @AuraEnabled
        public Decimal balance;
        @AuraEnabled
        public String currencyIsoCode;
        @AuraEnabled
        public Boolean isMultiCurrencyOrganization;

        public GLAccountCurrentBalanceResult(Decimal balance, String currencyIsoCode) {
            this.balance = (balance != NULL) ? balance : 0;
            this.currencyIsoCode = currencyIsoCode;
            this.isMultiCurrencyOrganization = MultiCurrencyHandler.isMultiCurrencyEnabled;
        }
    }

    public class GLAccountCurrentBalanceException extends Exception {}

}