global with sharing class ProfitAndLossVsBudgetFinReptOptions extends FinancialReportOptions {
    //===== GLOBAL class members ============//
    @AuraEnabled
    global Id budgetLedger;
    @AuraEnabled
    global Boolean showAllPeriods;

    global ProfitAndLossVsBudgetFinReptOptions() {
        super();
        this.reportType = FinancialReportType.PROFIT_AND_LOSS_VS_BUDGET;
        this.endingAccountingPeriod = AccountingPeriodHandler.getInstance().getFinancialReportEndPeriod()?.Id;
        this.startingAccountingPeriod = AccountingPeriodHandler.getInstance().getFinancialReportStartPeriod(
            this.endingAccountingPeriod, ACCOUNTING_PERIOD_RANGE_LIMIT
        )?.Id;
        this.showAllPeriods = false;
        this.includeSubType1 = true;
        setDefaultBudgetLedger();
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
        return new List<Id>{this.ledger, this.budgetLedger};
    }

    /**
        Populates `this.budgetLedger` with a default budget ledger id.
    */
    private void setDefaultBudgetLedger() {
        // retrieve all budget ledgers
        List<Ledger__c> ledgers = LedgerHandler.getInstanceWithSharing().getBudgetLedgers();

        // check budget ledgers exist
        if (ledgers.isEmpty()) {
            this.budgetLedger = null;
            return;
        }

        // try to find the ledger named 'Budget'
        for (Ledger__c ledger : ledgers) {
            if (ledger.Name == 'Budget') {
                this.budgetLedger = ledger.Id;
                return;
            }
        }

        // if not found, then use alphabetical order
        ledgers.sort();
        this.budgetLedger = ledgers.get(0).Id;
    }
}