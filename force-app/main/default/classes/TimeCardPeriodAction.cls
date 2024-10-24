public with sharing class TimeCardPeriodAction {

    public static Boolean isFirstRun = true;
    private static final String DELETE_ERROR = Label.ERR_DELETE_TIME_CARD;

    // Method to offset the end date based on the time card period start date
    public static void setPeriodEndDate(List<Time_Card_Period__c> periods) {
        for (Time_Card_Period__c period : periods) {
            period.End_Date__c = period.Start_Date__c + 6;
        }
    }

    public static void validateStatusFieldSet(List<Time_Card_Period__c> periods) {
        for (Time_Card_Period__c newPeriod : periods) {
            if (String.isBlank(newPeriod.Status__c)) {
                newPeriod.Status__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
        }
    }

    // Method prevents changing a time card period end or start date if a time card exists for the period
    public static void preventUpdateDateChangedAndTimeCard( Map<Id, Time_Card_Period__c> oldPeriods,
                                                            Map<Id, Time_Card_Period__c> newPeriods) {

        Map<Id, Time_Card_Period__c> checkTimeCardPeriods = new Map<Id, Time_Card_Period__c>();
        Map<Id, Time_Card_Period__c> errorTimeCardPeriods = new Map<Id, Time_Card_Period__c>();

        // Loop through time cards to determine if any start or end dates have changed
        for (Time_Card_Period__c newPeriod : newPeriods.values()) {
            Time_Card_Period__c oldPeriod = oldPeriods.get(newPeriod.Id);
            if (newPeriod.Start_Date__c != oldPeriod.Start_Date__c || newPeriod.End_Date__c != oldPeriod.End_Date__c) {
                checkTimeCardPeriods.put(newPeriod.Id, newPeriod);
            }
        }

        for (Time_Card_Period__c period : DomainUtils.getTimeCardPeriodWithTimeCardsById(checkTimeCardPeriods.keySet())) {

            if (!period.Time_Cards__r.isEmpty()) {
                checkTimeCardPeriods
                    .get(period.Id)
                    .addError(Label.ERR_CANNOT_CHANGE_START_END_DATE_FOR_TIME_CARD);
            }

        }

    }

    public static void validateDateRanges(List<Time_Card_Period__c> periods) {
        Boolean isError = false;
        Set<Integer> years = new Set<Integer>();

        // Want to restrict time card periods we retrive to only the years
        for (Time_Card_Period__c period : periods) {
            years.add(period.Start_Date__c.year());
            years.add(period.End_Date__c.year());
        }

        for (Time_Card_Period__c checkPeriod : DomainUtils.getTimeCardPeriodsByYear(years)) {

            for (Time_Card_Period__c period : periods) {
                //Checks to make sure the start date is not in an existing range
                if (period.Start_Date__c >= checkPeriod.Start_Date__c
                    && period.Start_Date__c <= checkPeriod.End_Date__c && checkPeriod.Id != period.Id) {
                    isError = true;

                }
                //Checks to make sure the end date is not in an existing range
                if (period.End_Date__c >= checkPeriod.Start_Date__c
                    && period.End_Date__c <= checkPeriod.End_Date__c && checkPeriod.Id != period.Id) {
                    isError = true;
                }

                if (isError) {
                    period.addError(Label.ERR_TIME_CARD_UNIQUE_DATE_RANGE);
                }
                isError = false;
            }
        }

    }

    public static void checkAccountingPeriodsExist(List<Time_Card_Period__c> periods) {
        Set<Integer> years = new Set<Integer>();

        // Want to restrict accounting periods we retrieve to only the years
        for (Time_Card_Period__c period : periods) {
            years.add(period.Start_Date__c.year());
            years.add(period.End_Date__c.year());
        }

        List<Accounting_Period__c> accountingPeriods =
            AccountingPeriodHandler.getInstance().getAccountingPeriodsByYears(years, SOQLBuilder.SortOrder.DESCENDING);

        for (Time_Card_Period__c period : periods) {
            Boolean isStartFound = false;
            Boolean isEndFound = false;
            for (Accounting_Period__c acctPeriod : accountingPeriods) {
                if (period.Start_Date__c >= acctPeriod.Start_Date__c && period.Start_Date__c <= acctPeriod.End_Date__c) {
                    isStartFound = true;
                }

                if (period.End_Date__c >= acctPeriod.Start_Date__c && period.End_Date__c <= acctPeriod.End_Date__c) {
                    isEndFound = true;
                }

                if (isStartFound && isEndFound) {
                    break;
                }
            }

            String error = '';
            if (!isStartFound) {
                error = Label.ERR_ACCOUNTING_PERIOD_MUST_EXIST_WITH_TC_START_DATE;
            }

            if (!isEndFound) {
                error += Label.ERR_ACCOUNTING_PERIOD_MUST_EXIST_WITH_TC_END_DATE;
            }

            if (error != '') {
                period.addError(error);
            }
        }
    }

    public static void associateTimeCardPeriodAndAccountingPeriod(List<Time_Card_Period__c> periods) {
        Set<Integer> years = new Set<Integer>();
        Map<String, Time_Card_Accounting_Period__c> tcPeriods = new Map<String, Time_Card_Accounting_Period__c>();

        // Want to restrict accounting periods we retrive to only the years
        for (Time_Card_Period__c period : periods) {
            years.add(period.Start_Date__c.year());
            years.add(period.End_Date__c.year());
        }

        List<Accounting_Period__c> accountingPeriods =
            AccountingPeriodHandler.getInstance().getAccountingPeriodsByYears(years, SOQLBuilder.SortOrder.DESCENDING);

        for (Time_Card_Period__c period : periods) {
            Boolean isStartFound = false;
            Boolean isEndFound = false;
            for (Accounting_Period__c acctPeriod : accountingPeriods) {
                if (period.Start_Date__c >= acctPeriod.Start_Date__c && period.Start_Date__c <= acctPeriod.End_Date__c) {
                    Time_Card_Accounting_Period__c tcPeriod = new Time_Card_Accounting_Period__c();
                    tcPeriod.Time_Card_Period__c = period.Id;
                    tcPeriod.Accounting_Period__c = acctPeriod.Id;
                    tcPeriods.put(String.valueOf(acctPeriod.Id) + String.valueOf(period.Id), tcPeriod);
                    isStartFound = true;
                }

                if (period.End_Date__c >= acctPeriod.Start_Date__c && period.End_Date__c <= acctPeriod.End_Date__c) {
                    Time_Card_Accounting_Period__c tcPeriod = new Time_Card_Accounting_Period__c();
                    tcPeriod.Time_Card_Period__c = period.Id;
                    tcPeriod.Accounting_Period__c = acctPeriod.Id;
                    tcPeriods.put(String.valueOf(acctPeriod.Id) + String.valueOf(period.Id), tcPeriod);
                    isEndFound = true;
                }

                if (isStartFound && isEndFound)
                    break;
            }
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Set<Id> timeCardPeriodIds = new Map<Id, Time_Card_Period__c>(periods).keySet();
            SFDCSecurityUtils.deleteProxy(
                DomainUtils.getTimeCardAccountingPeriodsByTimeCardPeriod(timeCardPeriodIds)
            );

            SFDCSecurityUtils.insertProxy(tcPeriods.values());
        }
        catch (DMLException ex) {
            Database.rollback(sp);
        }
    }

}