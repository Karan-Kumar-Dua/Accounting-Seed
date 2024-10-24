global with sharing class ProfitAndLossFinancialReportOptions extends FinancialReportOptions {

    global ProfitAndLossFinancialReportOptions() {
        super();
        this.reportType = FinancialReportType.PROFIT_AND_LOSS;
        this.endingAccountingPeriod = AccountingPeriodHandler.getInstance().getFinancialReportEndPeriod()?.Id;
        this.startingAccountingPeriod = AccountingPeriodHandler.getInstance().getFinancialReportStartPeriod(
            this.endingAccountingPeriod, ACCOUNTING_PERIOD_RANGE_LIMIT
        )?.Id;
        this.includeSubType1 = true;
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