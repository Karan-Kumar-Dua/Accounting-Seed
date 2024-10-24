public with sharing class MonthlyAmortization extends AbstractAmortization {
    private Decimal totalAmount2Recognize;
    private Decimal monthlyExpense;
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
        Amortization.validateNumberOfPeriod(options.numberOfPeriods);
        if (acctPeriods == null) {
            try {
                this.setPeriodList(options.startDate, options.numberOfPeriods);
            }
            catch (Exception e) {
                throw new Amortization.AmortizationException(Amortization.ERROR_NO_OPEN_PERIODS);
            }
        }
        Amortization.validatePeriods(acctPeriods, options.startDate);
        if(acctPeriods.size() != options.numberOfPeriods){
            throw new Amortization.AmortizationException(Amortization.ERROR_NO_OPEN_PERIODS);
        } 
    }

    private List<Scheduled_Revenue_Expense__c> create(AmortizationOptions options, SObject sourceDocument) {
        List<Scheduled_Revenue_Expense__c> sreItems = new List<Scheduled_Revenue_Expense__c>();
        totalAmount2Recognize = delta = options.amount != null ? options.amount : getSobjectTotal(sourceDocument);
        if (acctPeriods == null) {
            setPeriodList(options.startDate, options.numberOfPeriods);
        }
        monthlyExpense = (totalAmount2Recognize / acctPeriods.size()).setScale(2, System.RoundingMode.HALF_UP);
        for (Accounting_Period__c ap : acctPeriods) {
            Scheduled_Revenue_Expense__c sre = this.getBaseAmortizationEntry(options, sourceDocument);
            sre.Name += '-' + ap.Name;
            sre.Accounting_Period__c = ap.Id;
            sre.Transaction_Date__c = this.calculateTransactionDate(ap, options);
            sre.Amount__c = monthlyExpense;
            sreItems.add(sre);
            delta -= sre.Amount__c;
        }
        sreItems[sreItems.size() - 1].Amount__c += delta;
        return sreItems;
    }
    
}