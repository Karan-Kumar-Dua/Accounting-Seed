public with sharing class TimeCardActions {

    public static final Integer MAX_DAY_COUNT = 1000;
    public static final String TYPE_VALUE_ACTUAL = 'Actual';
    public static final String TYPE_VALUE_BUDGET = 'Budget';
    public static final String MAX_DAY_ERROR = Label.COMMON_YOU_CANNOT_HAVE_MORE_THAN + MAX_DAY_COUNT + Label.COMMON_TIME_CARD_DAYS;
    public static final String PERIOD_EXIST_ERROR = Label.ERR_PERIOD_EXIST;
    public static final String PERIOD_IS_NOT_OPEN_ERROR = Label.ERR_PERIOD_IS_NOT_OPEN;
    public static final String TIME_CARD_PERIOD_UPDATE_ERROR = Label.ERR_TIME_CARD_PERIOD_UPDATE;
    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    public static void validateRequiredFieldsOnTimeCard(List<Time_Card__c> newTimeCards) {
        for (Time_Card__c newTimeCard : newTimeCards) {
            if (newTimeCard.Ledger__c == NULL) {
                newTimeCard.Ledger__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }

            if (newTimeCard.Employee__c == NULL) {
                newTimeCard.Employee__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }

            if (newTimeCard.Type__c == NULL) {
                newTimeCard.Type__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
        }
    }

    public static void updateTypeField(Map<Id, Time_Card__c> newTimeCards, Map<Id, Time_Card__c> oldTimeCards) {
        for (Time_Card__c newTimeCard : newTimeCards.values()) {
            Time_Card__c oldTimeCard = oldTimeCards.get(newTimeCard.Id);

            if (oldTimeCard.Type__c == NULL && newTimeCard.Type__c == NULL) {
                newTimeCard.Type__c = TYPE_VALUE_ACTUAL;
            }
        }
    }

    public static void validateTimeCardPeriodIsOpen(List<Time_Card__c> newTimeCards) {
        Set<Id> timeCardPeriodIds = new Set<Id>();
        for (Time_Card__c newTimeCard : newTimeCards) {
            //Time Card Period Lookup field is required on th DB level
            //no need to check for NULL
            timeCardPeriodIds.add(newTimeCard.Time_Card_Period__c);
        }

        Map<Id, Time_Card_Period__c> existedTCPeriods = new Map<Id, Time_Card_Period__c>(DomainUtils.getTimeCardPeriodsById(timeCardPeriodIds));
        for (Time_Card__c newTimeCard : newTimeCards) {
            if (existedTCPeriods.get(newTimeCard.Time_Card_Period__c).Status__c != 'Open') {
                newTimeCard.addError(PERIOD_IS_NOT_OPEN_ERROR);
            }
        }
    }

    public static void validateTimeCardDoesNotExistPeriod(Map<Id, Time_Card__c> newTimeCards, Map<Id, Time_Card__c> oldTimeCards) {
        Map<String,Time_Card__c> newTimeCardsCheck = new Map<String,Time_Card__c>();
        Set<Id> employeeIds = new Set<Id>();
        Set<Id> periodIds = new Set<Id>();
        Set<Id> ledgerIds = new Set<Id>();

        for (Time_Card__c newTimeCard : newTimeCards.values()) {
            Time_Card__c oldTimeCard = oldTimeCards != NULL ? oldTimeCards.get(newTimeCard.Id) : NULL;
            if (newTimeCard.Type__c == TYPE_VALUE_ACTUAL || (oldTimeCard != NULL && oldTimeCard.Type__c == NULL && newTimeCard.Type__c == NULL)) {
                String timeCardKey = String.valueOf(newTimeCard.Employee__c) +
                    String.valueOf(newTimeCard.Time_Card_Period__c) +
                    String.valueOf(newTimeCard.Ledger__c);
                if (oldTimeCard == null
                    || (newTimeCard.Employee__c != oldTimeCard.Employee__c
                    || newTimeCard.Time_Card_Period__c != oldTimeCard.Time_Card_Period__c
                    || newTimeCard.Ledger__c != (oldTimeCard.Ledger__c != NULL ? oldTimeCard.Ledger__c : LedgerHandler.getLegacyDefaultLedgerId())
                    || newTimeCard.Type__c != oldTimeCard.Type__c)) {

                    if (newTimeCardsCheck.containsKey(timeCardKey)) {
                        newTimeCard.addError(PERIOD_EXIST_ERROR);
                    }
                    else {
                        newTimeCardsCheck.put(timeCardKey, newTimeCard);
                        employeeIds.add(newTimeCard.Employee__c);
                        periodIds.add(newTimeCard.Time_Card_Period__c);
                        ledgerIds.add(newTimeCard.Ledger__c);
                    }
                }
            }
        }

        for (Time_Card__c checkTimeCard : DomainUtils.getTimeCardsByEmployeeAndTimeCardPeriod(employeeIds, periodIds, ledgerIds)) {
            if (checkTimeCard.Type__c == TYPE_VALUE_ACTUAL || checkTimeCard.Type__c == NULL) {
                String timeCardKey = String.valueOf(checkTimeCard.Employee__c) +
                    String.valueOf(checkTimeCard.Time_Card_Period__c) +
                    String.valueOf((checkTimeCard.Ledger__c != NULL ? checkTimeCard.Ledger__c : LedgerHandler.getLegacyDefaultLedgerId()));

                if (newTimeCardsCheck.containsKey(timeCardKey) && !newTimeCards.containsKey(checkTimeCard.Id)) {
                    newTimeCardsCheck.get(timeCardKey).addError(PERIOD_EXIST_ERROR);
                }
            }
        }
    }

    public static void preventUpdateDayCount(List<Time_Card__c> timeCards) {
        for (Time_Card__c timeCard : timeCards) {
            if (timeCard.Day_Count__c > MAX_DAY_COUNT) {
                timeCard.addError(MAX_DAY_ERROR,false);
            }
        }
    }

    /*
    Prevent change Time Card Period in case if there are some Time Card Days associated with updated record
    */
    public static void preventUpdateTimeCardPeriod(List<Time_Card__c> newTimeCards, Map<Id, Time_Card__c> oldTimeCardMap) {
        for (Time_Card__c timeCard : newTimeCards) {
            if (timeCard.Time_Card_Period__c != oldTimeCardMap.get(timeCard.Id).Time_Card_Period__c
                    && timeCard.Day_Count__c > 0) {

                timeCard.Time_Card_Period__c.addError(TIME_CARD_PERIOD_UPDATE_ERROR);
            }
        }
    }

    public static void setCloneTimeCardValues(List<Time_Card__c> timeCards) {
        for (Time_Card__c timeCard : timeCards) {
            if (timeCard.isClone()) {
                timeCard.Status__c = FinancialSuiteUtils.getDefaultPostingStatus(Time_Card__c.Status__c);
            }
        }
    }

    public static void cloneTimeCardLines(List<Time_Card__c> timeCards) {
        Map<Id, Id> oldIdsByNewIds = new Map<Id, Id>();
        for (Time_Card__c timeCard : timeCards) {
            if (timeCard.isClone() && timeCard.Type__c != NULL && timeCard.Employee__c != NULL) {
                oldIdsByNewIds.put(timeCard.getCloneSourceId(), timeCard.Id);
            }
        }

        if (!oldIdsByNewIds.isEmpty()) {
            cloneTimeCardLines(oldIdsByNewIds);
        }
    }

    private static void cloneTimeCardLines(Map<Id, Id> oldIdsByNewIds) {
        List<Time_Card_Line__c> linesToClone = DomainUtils.getTimeCardLinesByTimeCardId(oldIdsByNewIds.keySet());
        List<Time_Card_Line__c> linesInsert = new List<Time_Card_Line__c>();
        for (Time_Card_Line__c line : linesToClone) {
            Time_Card_Line__c newline = line.clone(false, false, false, false);
            newline.Time_Card__c = oldIdsByNewIds.get(line.Time_Card__c);
            newline.Overtime__c = false;
            linesInsert.add(newline);
        }
        SFDCSecurityUtils.insertProxy(linesInsert);
    }
}