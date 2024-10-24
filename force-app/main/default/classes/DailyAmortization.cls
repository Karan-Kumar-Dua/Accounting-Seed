public with sharing class DailyAmortization extends AbstractAmortization {

    private Decimal totalAmount2Recognize;
    private Decimal dailyExpense;
    private Decimal delta;

    public override AmortizationResult amortize(AmortizationOptions options, SObject sourceDocument) {
        AmortizationResult result = new AmortizationResult();
        try {
            result.amortizationEntries = this.create(options, sourceDocument);
            result.isSuccess = true;
        }
        catch (Exception ex) {
            result.errors.add(ex.getMessage());
            result.isSuccess = false;
        }
        acctPeriods = null;
        return result;
    }

    public override void validateAmortizationOptions(AmortizationOptions options, SObject sourceDocument) {
        super.validateAmortizationOptions(options, sourceDocument);
        Amortization.validateEndDate(options.startDate, options.endDate);
        if (acctPeriods == null) {
            try {
                this.setPeriodList(options.startDate, options.endDate);
            }
            catch (Exception e) {
                throw new Amortization.AmortizationException(Amortization.ERROR_NO_OPEN_PERIODS);
            }

        }
        Amortization.validatePeriods(acctPeriods, options.startDate, options.endDate);
    }

    private List<Scheduled_Revenue_Expense__c> create(AmortizationOptions options, SObject sourceDocument) {
        List<Scheduled_Revenue_Expense__c> sreItems = new List<Scheduled_Revenue_Expense__c>();
        totalAmount2Recognize = delta = options.amount != null ? options.amount : getSobjectTotal(sourceDocument);
        dailyExpense = totalAmount2Recognize / (options.startDate.daysBetween(options.endDate) + 1);
        if (acctPeriods == null) {
            setPeriodList(options.startDate, options.endDate);
        }

        for (Accounting_Period__c ap : acctPeriods) {
            Scheduled_Revenue_Expense__c ae = this.getBaseAmortizationEntry(options, sourceDocument);
            ae.Name += '-' + ap.Name;
            ae.Accounting_Period__c = ap.Id;
            ae.Transaction_Date__c = this.calculateTransactionDate(ap, options);
            ae.Amount__c = this.getAmount(options, ap);
            sreItems.add(ae);
            delta -= ae.Amount__c;
        }
        sreItems[sreItems.size() - 1].Amount__c += delta;
        return sreItems;
    }

    private Decimal getAmount(AmortizationOptions options, Accounting_Period__c period) {
        Date startDateInCurrentAcctPeriod = period.Start_Date__c < options.startDate
            ? options.startDate
            : period.Start_Date__c;

        Date endDateInCurrentAcctPeriod = period.End_Date__c < options.endDate
            ? period.End_Date__c
            : options.endDate;

        return (dailyExpense * (startDateInCurrentAcctPeriod.daysBetween(endDateInCurrentAcctPeriod) + 1))
            .setScale(2, System.RoundingMode.HALF_UP);
    }

}