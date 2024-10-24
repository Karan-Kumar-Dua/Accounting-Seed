global with sharing class TrialBalanceFinancialReportOptions extends FinancialReportOptions {

    global TrialBalanceFinancialReportOptions() {
        super();
        this.suppressOpeningBalanceAndPeriodColumns = MultiCurrencyHandler.isMultiCurrencyEnabled;
        this.reportType = FinancialReportType.TRIAL_BALANCE;
        this.startingAccountingPeriod = AccountingPeriodHandler.getInstance().getFirstOpenedPeriod()?.Id;
    }

    public override List<String> getListOfPeriodNames() {
        return AccountingPeriodHandler.getInstance().toString(getAllPeriodsInReportingRange());
    }

    public override List<Accounting_Period__c> getAllPeriodsInReportingRange() {
        AccountingPeriodHandler apHandler = AccountingPeriodHandler.getInstance();
        List<Accounting_Period__c> periodsInReportingRange = new List<Accounting_Period__c>();
        if (!isTrialBalanceForTranslatedBase()) {
            periodsInReportingRange.add(apHandler.getPreviousAccountingPeriod(startingAccountingPeriod));
        }
        periodsInReportingRange.add(apHandler.getAccountingPeriodById(startingAccountingPeriod));
        return periodsInReportingRange;
    }

    public override List<Id> getLedgerIds() {
        return new List<Id>{this.ledger};
    }

}