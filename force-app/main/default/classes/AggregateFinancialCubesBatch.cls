public with sharing class AggregateFinancialCubesBatch implements Database.Batchable<SObject>, Database.Stateful {

    private Decimal accumulator;
    private final GLAccountBalanceOption options;
    private final Accounting_Period__c period;
    private final Date startDate;

    public AggregateFinancialCubesBatch(
        GLAccountBalanceOption options,
        Accounting_Period__c period,
        Date startDate) {

        this.options = options;
        this.period = period;
        this.startDate = startDate;
        this.accumulator = 0;
    }

    public Database.QueryLocator start(Database.BatchableContext ctx) {
        return DomainUtils.getFinCubesQueryLocatorForGLAccountBalance(period.Id, options);
    }

    public void execute(Database.BatchableContext ctx, List<Financial_Cube__c> scope) {
        for (Financial_Cube__c tx : scope) {
            accumulator += tx.Year_To_Date__c;
        }
    }

    public void finish(Database.BatchableContext ctx) {
        // archived txs are needed for calculation
        if (requiresArchivedTxs(startDate)) {
            GLAccountBalance.publishBalance(options, 0);
        }
        // inquiry date coincides with end of closed period
        else if (options.inquiryDate == startDate.addDays(-1)) {
            GLAccountBalance.publishBalance(options, accumulator);
        }
        // sum open or partial periods in batch
        else {
            GLAccountBalanceBatch reducer = new GLAccountBalanceBatch(options, startDate, accumulator);
            Database.executeBatch(reducer, 2000);
        }
    }

    private Boolean requiresArchivedTxs(Date startDate) {
        String[] archiveStatus = new String[] {
            AccountingPeriodActions.ARCHIVED_STATUS,
            AccountingPeriodActions.ARCHIVE_IN_PROGRESS_STATUS
        };

        for (Accounting_Period__c period : AccountingPeriodHandler.getInstance().getAllAccountingPeriods()) {
            if (period.End_Date__c >= options.inquiryDate
                    && period.Start_Date__c <= startDate
                    && archiveStatus.contains(period.Status__c)) {

                return true;
            }
        }
        return false;
    }

}