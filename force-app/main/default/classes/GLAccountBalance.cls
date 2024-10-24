public with sharing class GLAccountBalance {
    
    private final GLAccountBalanceOption options;
    private final AccountingPeriodHandler periodHandler;

    public class ArchivedTransactionRequiredException extends Exception {}

    public class Balance {
        public GLAccountBalanceOption options;
        public Decimal balance;
        public Balance(GLAccountBalanceOption options, Decimal balance) {
            this.options = options;
            this.balance = balance;
        }
    }

    public GLAccountBalance(GLAccountBalanceOption options) {
        this.options = options;
        this.periodHandler = AccountingPeriodHandler.getInstance();
    }

    public static void publishBalance(
        GLAccountBalanceOption options, 
        Decimal balance
    ) {
        Publishable event = EventPubSub.createEvent(
            EventPubSub.PublishDelay.IMMEDIATE, 
            EventRegistry.RegisteredEvent.BANK_RECONCILIATION_GL_BALANCE_CALCULATED, 
            options.requestId, 
            new Balance(options, balance)
        );
        EventPubSub.publish(event);
    }

    public void calculate() {
        Accounting_Period__c period = getPreviousClosedPeriod();
        Boolean calculateAsLDV = false;

        Decimal balance;    // GL account balance. last closed fin_cube balance + sum txs since
        Date startDate;     // sum txs starting on this date

        // no closed period exists
        if (period == null) {
            balance = 0;
            startDate = getFirstPeriod().Start_Date__c;   
        }
        // closed period exists
        else {
            startDate = period.End_Date__c.addDays(1);
            //Identify how to get YTD balance based on count of FCs to process: Sync or Async approach
            Integer currentLimit = Limits.getLimitQueryRows() - Limits.getQueryRows();
            Integer numberOfRecordsIncludedInAggregation = DomainUtils.getCountFinancialCubesByPeriodAndGLAccountAndLedger(
                new Set<Id>{period.Id}, new Set<Id>{options.glAccountId}, new Set<Id>{options.ledgerId}
            );
            if (numberOfRecordsIncludedInAggregation < currentLimit) { //Sync approach
                balance = sumCubesYTDForPeriod(period);
            }
            else { //Async approach
                calculateAsLDV = true;
                AggregateFinancialCubesBatch ytdAggregator = new AggregateFinancialCubesBatch(
                    options, period, startDate);
                Database.executeBatch(ytdAggregator, 2000);
            }
        }

        if (!calculateAsLDV) {
            // archived txs are needed for calculation
            if (requiresArchivedTxs(startDate)) {
                publishBalance(options, 0);
            }
            // inquiry date coincides with end of closed period
            else if (options.inquiryDate == startDate.addDays(-1)) {
                publishBalance(options, balance);
            }
            // sum open or partial periods in batch
            else {
                GLAccountBalanceBatch reducer = new GLAccountBalanceBatch(options, startDate, balance);
                Database.executeBatch(reducer, 2000);
            }
        }
    }

    private Accounting_Period__c getPreviousClosedPeriod() {
        for (Accounting_Period__c period : periodHandler.getAllAccountingPeriods(SOQLBuilder.SortOrder.DESCENDING)) {
            if (period.End_Date__c <= options.inquiryDate 
                && periodHandler.isConsideredClosed(period)) {
                return period;
            }
        }
        return null;
    }

    private Accounting_Period__c getFirstPeriod() {
        return periodHandler.getAllAccountingPeriods().get(0);
    }

    private Boolean requiresArchivedTxs(Date startDate) {
        String[] archiveStatus = new String[] { 
            AccountingPeriodActions.ARCHIVED_STATUS,
            AccountingPeriodActions.ARCHIVE_IN_PROGRESS_STATUS
        };

        for (Accounting_Period__c period : periodHandler.getAllAccountingPeriods()) {
            if (period.End_Date__c >= options.inquiryDate 
                && period.Start_Date__c <= startDate
                && archiveStatus.contains(period.Status__c)) {
                return true;
            }
        }
        return false;
    }

    private Decimal sumCubesYTDForPeriod(Accounting_Period__c period) {
        List<Financial_Cube__c> cubes = new List<Financial_Cube__c>();
        cubes = DomainUtils.getFinancialCubesForPeriod(period.Id, options);

        Decimal sum = 0;
        for (Financial_Cube__c cube : cubes) {
            sum += cube.Year_To_Date__c;
        }
        return sum;
    }

}