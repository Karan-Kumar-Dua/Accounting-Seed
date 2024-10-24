global with sharing class BalanceSheetFinancialReportOptions extends FinancialReportOptions {

    global BalanceSheetFinancialReportOptions() {
        super();
        this.reportType = FinancialReportType.BALANCE_SHEET;
        this.endingAccountingPeriod = AccountingPeriodHandler.getInstance().getFirstOpenedPeriod()?.Id;
        this.startingAccountingPeriod = AccountingPeriodHandler.getInstance().getFinancialReportStartPeriod(
            this.endingAccountingPeriod, FinancialReportOptions.ACCOUNTING_PERIOD_RANGE_LIMIT
        )?.Id;
        this.includeSubType2 = true;
    }

    public override List<String> getListOfPeriodNames() {
        return AccountingPeriodHandler.getInstance().toString(getAllPeriodsInReportingRange());
    }

    public override List<Accounting_Period__c> getAllPeriodsInReportingRange() {
        return AccountingPeriodHandler.getInstance().getAccountingPeriodsFromRange(
            this.startingAccountingPeriod, this.endingAccountingPeriod
        );
    }

    public override List<Id> getLedgerIds() {
        return new List<Id>{this.ledger};
    }

}