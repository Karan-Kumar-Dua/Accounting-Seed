public with sharing class TimeCardDayActions {
    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    public static final String DUPLICATE_ERROR = Label.ERR_TIME_CARD_DAY_RECORD_EXIST;

    public static void checkDuplicateTimeCardDay(List<Time_Card_Day__c> timeCardDayList) {
        Map<String,Time_Card_Day__c> timeCardDayMap = new Map<String,Time_Card_Day__c>();
        Map<Id,Time_Card_Line__c> timeCardLineMap = new Map<Id,Time_Card_Line__c>();

        for (Time_Card_Day__c timeCardDay : timeCardDayList) {
            timeCardLineMap.put(timeCardDay.Time_Card_Line__c,null);
        }

        timeCardLineMap = new Map<Id, Time_Card_Line__c>(DomainUtils.getTimeCardLinesById(timeCardLineMap.keySet()));

        // Check for duplicates in batch
        for (Time_Card_Day__c timeCardDay : timeCardDayList) {
            if (timeCardDayMap.containsKey(timeCardDay.Time_Card_Line__c + timeCardDay.Date__c.format())) {
                timeCardDay.addError(DUPLICATE_ERROR.replace('<DATE>', timeCardDay.Date__c.format()) + timeCardLineMap.get(timeCardDay.Time_Card_Line__c).Name, false);
            }
            else {
                timeCardDayMap.put(timeCardDay.Time_Card_Line__c + timeCardDay.Date__c.format(), timeCardDay);
            }
        }

        // Check for duplicates in database
        for (Time_Card_Day__c timeCardDay : DomainUtils.geTimeCardDaysByTimeCardLine(timeCardLineMap.keySet())) {
            if (timeCardDayMap.containsKey(timeCardDay.Time_Card_Line__c + timeCardDay.Date__c.format())
                    && timeCardDayMap.get(timeCardDay.Time_Card_Line__c + timeCardDay.Date__c.format()).Id != timeCardDay.Id) {

                timeCardDayMap.get(
                    timeCardDay.Time_Card_Line__c + timeCardDay.Date__c.format()
                ).addError(
                    DUPLICATE_ERROR.replace(
                        '<DATE>', timeCardDay.Date__c.format()
                    ) + timeCardLineMap.get(timeCardDay.Time_Card_Line__c).Name,
                    false
                );
            }
        }
    }

}