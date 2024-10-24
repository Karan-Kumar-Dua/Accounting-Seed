public with sharing class AccountingPeriodOpenCloseOptions {

    private Accounting_Period__c currentPeriod;
    private Accounting_Period__c nextPeriod;
    private Integer currentYear;
    private Integer nextYear;
    private Integer currentMonth;
    private Integer nextMonth;
    private Integer currentIndex;
    private AccountingPeriodHandler acctPeriodHandler;

    public List<Accounting_Period__c> selectedPeriods;
    public AccountingPeriodOpenCloseUtils.PeriodUpdateContext context;

    public AccountingPeriodOpenCloseOptions(List<Accounting_Period__c> selectedPeriods,
                                            Integer index,
                                            AccountingPeriodOpenCloseUtils.PeriodUpdateContext context) {

        this.selectedPeriods = selectedPeriods;
        this.currentIndex = (index != NULL) ? index : 0;
        this.acctPeriodHandler = AccountingPeriodHandler.getInstance();
        this.context = context;

        initialize();
    }

    private void initialize() {
        this.currentPeriod = selectedPeriods.get(currentIndex);
        this.nextPeriod = acctPeriodHandler.getNextAccountingPeriod(currentPeriod);
        this.currentYear = Integer.valueOf(currentPeriod.Name.substring(0, 4));
        this.currentMonth = Integer.valueOf(currentPeriod.Name.subString(5, 7));
        this.nextYear = Integer.valueOf(nextPeriod.Name.substring(0, 4));
        this.nextMonth = Integer.valueOf(nextPeriod.Name.subString(5, 7));
    }

    public Boolean hasNext() {
        return selectedPeriods.size() > (currentIndex + 1);
    }

    public Boolean hasPrevious() {
        return currentIndex > 0;
    }

    public Integer getIndex() {
        return currentIndex;
    }

    public Integer getCurrentYear() {
        return currentYear;
    }
    public Integer getCurrentMonth() {
        return currentMonth;
    }
    public Integer getNextYear() {
        return nextYear;
    }
    public Integer getNextMonth() {
        return nextMonth;
    }
    public Accounting_Period__c getCurrentPeriod() {
        return this.currentPeriod;
    }
    public Accounting_Period__c getNextPeriod() {
        return this.nextPeriod;
    }

    public Boolean isNextMonthNewFiscalYear() {
        return (nextMonth == 1);
    }

    public Boolean isCurrentMonthNewFiscalYear() {
        return (currentMonth == 1);
    }

    public void setIndex(Integer aIndex) {
        this.currentIndex = aIndex;
        initialize();
    }

    public List<Accounting_Period__c> getUnprocessedPeriods() {
        List<Accounting_Period__c> result = new List<Accounting_Period__c>();
        for (Accounting_Period__c selectedPeriod : selectedPeriods) {
            if (context == AccountingPeriodOpenCloseUtils.PeriodUpdateContext.OPENING) {
                if (selectedPeriods.indexOf(selectedPeriod) <= currentIndex) {
                    Accounting_Period__c updateableAcctPeriod = new Accounting_Period__c(
                        Id = selectedPeriod.Id, Name = selectedPeriod.Name
                    );
                    result.add(updateableAcctPeriod);
                }
            }
            else {
                if (selectedPeriods.indexOf(selectedPeriod) >= currentIndex) {
                    Accounting_Period__c updateableAcctPeriod = new Accounting_Period__c(
                        Id = selectedPeriod.Id, Name = selectedPeriod.Name
                    );
                    result.add(updateableAcctPeriod);
                }
            }
        }
        return result;
    }

    public String getPeriodNames() {
        String result = '\n';
        for (Accounting_Period__c period : selectedPeriods) {
            result += period.Name;
            result += '\n';
        }
        return result;
    }

}