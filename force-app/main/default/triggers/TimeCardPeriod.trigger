trigger TimeCardPeriod on Time_Card_Period__c (before insert, before update, after insert, after update) {

    if (Trigger.isBefore && Trigger.isInsert && TimeCardPeriodAction.isFirstRun) {
        TimeCardPeriodAction.setPeriodEndDate(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isInsert && TimeCardPeriodAction.isFirstRun) {
        TimeCardPeriodAction.isFirstRun = false;
        TimeCardPeriodAction.associateTimeCardPeriodAndAccountingPeriod(Trigger.new);
        TimeCardPeriodAction.validateDateRanges(Trigger.new);
        TimeCardPeriodAction.checkAccountingPeriodsExist(Trigger.new);
        TimeCardPeriodAction.validateStatusFieldSet(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate && TimeCardPeriodAction.isFirstRun) {
        TimeCardPeriodAction.setPeriodEndDate(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate && TimeCardPeriodAction.isFirstRun) {
        TimeCardPeriodAction.isFirstRun = false;
        TimeCardPeriodAction.associateTimeCardPeriodAndAccountingPeriod(Trigger.new);
        TimeCardPeriodAction.preventUpdateDateChangedAndTimeCard(Trigger.oldMap, Trigger.newMap);
        TimeCardPeriodAction.validateDateRanges(Trigger.new);
        TimeCardPeriodAction.checkAccountingPeriodsExist(Trigger.new);
        TimeCardPeriodAction.validateStatusFieldSet(Trigger.new);
    }
    
}