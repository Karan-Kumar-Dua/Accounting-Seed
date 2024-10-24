/**
 * Calculates an amortization schedule following the straight line method.
 */
public with sharing class StraightLineAmortization extends AbstractAmortization {

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
        //an extra period if needed when the start date is not on the first day of the period
        Boolean startsOnFirst = startsOnFirstOfPeriod(options.startDate);
        try {
            if (startsOnFirst) {
                this.setPeriodList(options.startDate, options.numberOfPeriods);
            } else {
                this.setPeriodList(options.startDate, options.numberOfPeriods + 1);
            }
        }
        catch (Exception e) {
            throw new Amortization.AmortizationException(Amortization.ERROR_NO_OPEN_PERIODS);
        }

        Amortization.validatePeriods(acctPeriods, options.startDate);
        if (
            (acctPeriods[0].Start_Date__c == options.startDate && acctPeriods.size() != options.numberOfPeriods) 
            || (acctPeriods[0].Start_Date__c < options.startDate && acctPeriods.size() != options.numberOfPeriods + 1)
        ) {
            throw new Amortization.AmortizationException(Amortization.ERROR_NO_OPEN_PERIODS);
        }
    }

    private List<Scheduled_Revenue_Expense__c> create(AmortizationOptions options, SObject sourceDocument) {
        List<Scheduled_Revenue_Expense__c> sreItems = new List<Scheduled_Revenue_Expense__c>();

        //delta will track the remaining amount to be amortized after each period
        Decimal delta;
        Decimal totalAmount2Recognize = delta = options.amount != null ? options.amount : getSobjectTotal(sourceDocument);
        if (acctPeriods == null) {
            //retrieve an extra period in case the start date does not fall on the first day of the first period
            Boolean startsOnFirst = startsOnFirstOfPeriod(options.startDate);
            if (startsOnFirst) {
                this.setPeriodList(options.startDate, options.numberOfPeriods);
            } else {
                this.setPeriodList(options.startDate, options.numberOfPeriods + 1);
            }
        }

        //Clone the main list of periods to not change the original collection on following calculations
        List<Accounting_Period__c> acctPeriodsCloned = acctPeriods.clone();

        Decimal amortizationPerPeriod = ((Decimal) totalAmount2Recognize/options.numberOfPeriods).setScale(2, System.RoundingMode.HALF_UP);

        Accounting_Period__c firstPeriod = acctPeriodsCloned.remove(0);
        Integer totalDaysInFirstPeriod = firstPeriod.Start_Date__c.daysBetween(firstPeriod.End_Date__C) + 1;
        Date lastDayOfFirstPeriod = firstPeriod.Start_Date__c.addDays(totalDaysInFirstPeriod- 1);
        Integer daysFirstPeriod = options.startDate.daysBetween(lastDayOfFirstPeriod) + 1;
        Decimal firstPeriodExpense = ((Decimal)(amortizationPerPeriod * daysFirstPeriod/totalDaysInFirstPeriod)).setScale(2, System.RoundingMode.HALF_UP);
        Scheduled_Revenue_Expense__c firstSRE = this.getBaseAmortizationEntry(options, sourceDocument);

        firstSRE.Name += '-' + firstPeriod.Name;
        firstSRE.Accounting_Period__c = firstPeriod.Id;
        firstSRE.Transaction_Date__c = this.calculateTransactionDate(firstPeriod, options);
        firstSRE.Amount__c = Math.abs(firstPeriodExpense) < Math.abs(delta) ? firstPeriodExpense : delta;
        sreItems.add(firstSRE);
        delta -= firstSRE.Amount__c;

        // only one accounting period
        if (acctPeriodsCloned.isEmpty()) {
            adjustAmount(sreItems, delta);
            return sreItems;
        }


        for (Accounting_Period__c ap : acctPeriodsCloned) {
            if (delta ==0) {
                break;
            }
            Boolean isLastPeriod = (ap == acctPeriodsCloned[acctPeriodsCloned.size() - 1]);
            Scheduled_Revenue_Expense__c sre = this.getBaseAmortizationEntry(options, sourceDocument);
            sre.Name += '-' + ap.Name;
            sre.Accounting_Period__c = ap.Id;
            sre.Transaction_Date__c = this.calculateTransactionDate(ap, options);
            if(isLastPeriod) {
                sre.Amount__c = delta;
            } else {
                sre.Amount__c = Math.abs(amortizationPerPeriod) < Math.abs(delta) ? amortizationPerPeriod : delta;
            }
            sreItems.add(sre);
            delta -= sre.Amount__c;
        }
        return sreItems;
    }

    //returns true if the startDate is the start date of the period it falls in
    private Boolean startsOnFirstOfPeriod(Date startDate) {
        Accounting_Period__c firstPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(startDate);
        return (firstPeriod.Start_Date__c == startDate);
    }

    private void adjustAmount(List<Scheduled_Revenue_Expense__c> sreItems, Decimal delta) {
        sreItems[sreItems.size() - 1].Amount__c += delta;
    }

}