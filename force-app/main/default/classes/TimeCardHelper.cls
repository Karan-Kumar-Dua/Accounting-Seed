public with sharing class TimeCardHelper {

    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public class TimeCardHelperException extends Exception{}

    @AuraEnabled
    public static Time_Card__c getNext() {
        try {
            Id employeeId = UserInfo.getUserId();
            Id ledgerId = LedgerHandler.getLedgerIdWithSharing();
            Date today = Date.today();

            List<String> fields = new List<String>{
                'Id',
                'End_Date__c'
            };
            String condition = 'End_Date__c >= :today AND Status__c = \'Open\'';
            SOQLBuilder.Ordering ordering = new SOQLBuilder.Ordering('Time_Card_Period__c', 'End_Date__c', SOQLBuilder.SortOrder.ASCENDING);

            String subRelationship = PACKAGE_QUALIFIER + 'Time_Cards__r';
            List<String> subFields = new List<String>{'Id'};
            String subCondition = 'Employee__c = :employeeId and Type__c = \'Actual\'';
            
            SOQLBuilder query = new SOQLBuilder(Time_Card_Period__c.SObjectType);
            query
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(fields)
                .setCondition(condition)
                .addOrdering(ordering)
                .subselectQuery(subRelationship)
                .selectFields(subFields)
                .setCondition(subCondition)
                .setLimit(1);
    
            List<Time_Card_Period__c> periods = (List<Time_Card_Period__c>) Database.query(query.toSOQL());

            Id periodId;
            for (Time_Card_Period__c period : periods) {
                if (period.Time_Cards__r.isEmpty()) {
                    periodId = period.Id;
                    break;
                }
            }            

            return new Time_Card__c(
                Employee__c = employeeId,
                Ledger__c = ledgerId,
                Time_Card_Period__c = periodId
            );
        }
        catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    @AuraEnabled
    public static TimeCardHelper.TimeCardWrapper getTimeCardData(String timeCardId) {
        try {
            Time_Card__c timeCard = queryTimeCard(timeCardId);
            Map<Integer, TimeCardHelper.TimeCardLineWrapper> wrapperMap = TimeCardHelper.wrapTimeCardLines(timeCard, false);
            return new TimeCardHelper.TimeCardWrapper(timeCard, wrapperMap.values());
        }
        catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    @AuraEnabled
    public static TimeCardHelper.TimeCardLineWrapper getNewTimeCardLine(String timeCardId) {
        try {
            Time_Card__c timeCard = queryTimeCard(timeCardId);
            return new TimeCardHelper.TimeCardLineWrapper(
                timeCard,
                new Time_Card_Line__c(),
                0,
                NULL,
                new List<SelectOption>{new SelectOption('', Label.SELECT_OPTION_NONE)}
            );
        }
        catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteTimeCardLine(Time_Card__c timeCard, String timeCardLineId) {
        try {
            validateTimeCardLastModifiedDate(timeCard.Id, timeCard.LastModifiedDate);
            SFDCSecurityUtils.deleteCheckCRUDAndFLS(new Time_Card_Line__c(Id = timeCardLineId));
        }
        catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    @AuraEnabled
    public static void saveTimeCardLines(Time_Card__c timeCard, List<String> serializedTimeCardLineWrappers) {

        Savepoint sp = Database.setSavepoint();
        try {
            List<TimeCardLineWrapper> wrappedLinesToUpdate = new List<TimeCardHelper.TimeCardLineWrapper>();
            List<Time_Card_Line__c> linesToUpdate = new List<Time_Card_Line__c>();
            validateTimeCardLastModifiedDate(timeCard.Id, timeCard.LastModifiedDate);
            for (String eachSerializedLine : serializedTimeCardLineWrappers) {
                TimeCardLineWrapper tempLine = (TimeCardLineWrapper) JSON.deserialize(eachSerializedLine, TimeCardLineWrapper.class);
                if (tempLine.timeCardLine.Time_Card__c == NULL) {
                    tempLine.timeCardLine.Time_Card__c = timeCard.Id;
                }
                wrappedLinesToUpdate.add(tempLine);
                linesToUpdate.add(tempLine.timeCardLine);
            }

            Set<Time_Card_Day__c> updateList = new Set<Time_Card_Day__c>();
            List<Time_Card_Day__c> insertList = new List<Time_Card_Day__c>();
            List<Time_Card_Day__c> deleteList = new List<Time_Card_Day__c>();

            SFDCSecurityUtils.upsertCheckCRUDAndFLS(linesToUpdate, new List<String>{
                'Project__c',
                'Project_Task__c'
            });

            for (TimeCardHelper.TimeCardLineWrapper wrappedLine : wrappedLinesToUpdate) {
                for (Time_Card_Day__c day : wrappedLine.days) {
                    if (day.Time_Card_Line__c == NULL) {
                        day.Time_Card_Line__c = wrappedLine.timeCardLine.Id;
                    }

                    if (day.Id != NULL) {
                        if (day.Hours__c != NULL) {
                            updateList.add(day);
                        } else if (day.Hours__c == NULL) {
                            deleteList.add(day);
                        }
                    }
                    else if (day.Hours__c != NULL && day.Id == NULL) {
                        insertList.add(day);
                    }
                }
            }
            
            SFDCSecurityUtils.updateCheckCRUDAndFLS(new List<Time_Card_Day__c>(updateList), new List<String>{'Hours__c'});
            SFDCSecurityUtils.insertCheckCRUDAndFLS(insertList, new List<String>());
            SFDCSecurityUtils.deleteCheckCRUDAndFLS(deleteList);
        }
        catch (Exception ex) {
            Database.rollback(sp);
            throw new AuraHandledException(ex.getMessage());
        }
    }

    private static void validateTimeCardLastModifiedDate(String timeCardId, DateTime oldLastModifiedDate) {
        Datetime currentLastModifiedDate = DomainUtils.getTimeCardsByIdForUpdate(new Set<Id>{timeCardId})[0].LastModifiedDate;
        // Has the time card been modified by another process?
        if (currentLastModifiedDate != oldLastModifiedDate) {
            throw new TimeCardHelperException(TimeCardControllerExt.LAST_MODIFIED_ERROR);
        }
    }

    public static List<String> getTimePeriodDayHeaders(Time_Card__c timeCard) {
        List<String> dayHeaders = new List<String>();

        if (timeCard != NULL
                && timeCard.Time_Card_Period__r != NULL
                && timeCard.Time_Card_Period__r.Start_Date__c != NULL
                && timeCard.Time_Card_Period__r.End_Date__c != NULL) {

            Integer dayCount = timeCard.Time_Card_Period__r.Start_Date__c.daysBetween(timeCard.Time_Card_Period__r.End_Date__c);
            dayHeaders = new List<String>();
            for (Integer i = 0; i <= dayCount; i++) {
                dayHeaders.add(DateTime.newInstance(timeCard.Time_Card_Period__r.Start_Date__c.addDays(i), Time.newInstance(0, 0, 0, 0)).format('E d'));
            }
        }

        return dayHeaders;
    }

    public static Integer lastRowIndex;

    public static Map<Integer, TimeCardHelper.TimeCardLineWrapper> wrapTimeCardLines(Time_Card__c timeCard, Boolean withEmptyLine) {
        Integer rowCount = 0;
        Map<Integer, TimeCardHelper.TimeCardLineWrapper> wrapperMap = new Map<Integer, TimeCardHelper.TimeCardLineWrapper>();
        Map<Id, List<SelectOption>> projectTaskMap = new Map<Id, List<SelectOption>>();

        List<Time_Card_Line__c> tcLines = TimeCardHelper.queryTimeCardLines(timeCard.Id);

        if (tcLines.isEmpty() && !withEmptyLine) {
            return wrapperMap;
        }

        for (Time_Card_Line__c timeCardLine : tcLines) {
            projectTaskMap.put(timeCardLine.Project__c, new List<SelectOption>{new SelectOption('', Label.SELECT_OPTION_NONE)});
        }

        List<Project_Task__c> projectTasks = FinancialSuiteUtils.queryProjectTasks(projectTaskMap.keySet());
        for (Project_Task__c theTask : projectTasks) {
            projectTaskMap.get(theTask.Project__c).add(new SelectOption(theTask.Id, theTask.Name));
        }

        for (Time_Card_Line__c timeCardLine : tcLines) {
            wrapperMap.put(
                rowCount,
                new TimeCardHelper.TimeCardLineWrapper(
                    timeCard,
                    timeCardLine,
                    rowCount,
                    timeCardLine.Time_Card_Days__r,
                    projectTaskMap.get(timeCardLine.Project__c)
                )
            );
            rowCount++;
        }

        if (wrapperMap.isEmpty()) {
            wrapperMap.put(
                rowCount,
                new TimeCardHelper.TimeCardLineWrapper(
                    timeCard,
                    new Time_Card_Line__c(),
                    rowCount,
                    NULL,
                    new List<SelectOption>{new SelectOption('', Label.SELECT_OPTION_NONE)}
                )
            );
        }

        lastRowIndex = rowCount;
        return wrapperMap;
    }

    public static TimeCardUIConfiguration getTimeCardUIConfiguration(Boolean isLEX) {
        TimeCardUIConfiguration uiConfig = new TimeCardUIConfiguration();
        try {
            if (isLEX) {
                uiConfig.showTCVariable1 = Schema.sObjectType.Time_Card_Line__c.fields.Time_Card_Variable_1__c.isAccessible();
                uiConfig.showTCVariable2 = Schema.sObjectType.Time_Card_Line__c.fields.Time_Card_Variable_2__c.isAccessible();
                uiConfig.showBillable = Schema.sObjectType.Time_Card_Line__c.fields.Billable__c.isAccessible();
                uiConfig.showOvertime = Schema.sObjectType.Time_Card_Line__c.fields.Overtime__c.isAccessible();
                uiConfig.invoiceCommentsAccessible = Schema.sObjectType.Time_Card_Day__c.fields.Invoice_Comment__c.isAccessible();
                uiConfig.internalCommentsAccessible = Schema.sObjectType.Time_Card_Day__c.fields.Internal_Comment__c.isAccessible();
                uiConfig.invoiceCommentsUpdateable = Schema.sObjectType.Time_Card_Day__c.fields.Invoice_Comment__c.isUpdateable();
                uiConfig.internalCommentsUpdateable = Schema.sObjectType.Time_Card_Day__c.fields.Internal_Comment__c.isUpdateable();
            }
            else {
                Accounting_Settings__c main = AccountingSettingsHandler.getAccountingSettings();
                uiConfig.variable1Name = main.Label_for_Time_Card_Variable_1__c;
                uiConfig.variable2Name = main.Label_for_Time_Card_Variable_2__c;
                uiConfig.showBillable = main.Display_Billable_Flag_in_Time_Card_Entry__c;
            }
        }
        catch (QueryException ex) {
            // catch exception for main object query
        }
        return uiConfig;
    }

    public static Time_Card__c queryTimeCard(String timeCardId) {
        List<String> queryFields = new List<String>{
            'Id',
            'Time_Card_Period__r.Start_Date__c',
            'Time_Card_Period__r.End_Date__c',
            'Status__c',
            'LastModifiedDate',
            'Ledger__c'
        };
        String queryCondition = 'Id = :timeCardId';
        SOQLBuilder theQuery = new SOQLBuilder(Time_Card__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (Time_Card__c) Database.query(theQuery.toSOQL());
    }

    public static List<Time_Card_Line__c> queryTimeCardLines(String timeCardId) {
        List<String> timeCardLineQueryFields = new List<String>{
            'Id',
            'Name',
            'Time_Card__c',
            'Project__c',
            'Project__r.Name',
            'Project_Task__c',
            'Project_Task__r.Name',
            'Billable__c',
            'Overtime__c',
            'Time_Card_Variable_1__c',
            'Time_Card_Variable_1__r.Name',
            'Time_Card_Variable_2__c',
            'Time_Card_Variable_2__r.Name',
            'Time_Card__r.Time_Card_Period__r.Start_Date__c',
            'Time_Card__r.Time_Card_Period__r.End_Date__c'
        };

        String timeCardLineQueryCondition = 'Time_Card__c = :timeCardId ORDER BY Project__r.Name, Project_Task__r.Name';

        List<String> timeCardDayQueryFields = new List<String>{
            'Id',
            'Time_Card_Line__c',
            'Date__c',
            'Hours__c',
            'Invoice_Comment__c',
            'Internal_Comment__c'
        };

        String timeCardDayRelationshipName = PACKAGE_QUALIFIER + 'Time_Card_Days__r';
        SOQLBuilder.Ordering timeCardDayOrdering = new SOQLBuilder.Ordering('Time_Card_Day__c', 'Date__c', SOQLBuilder.SortOrder.ASCENDING);

        SOQLBuilder theTimeCardLineQuery = new SOQLBuilder(Time_Card_Line__c.SObjectType);
        theTimeCardLineQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(timeCardLineQueryFields)
            .setCondition(timeCardLineQueryCondition)
            .subselectQuery(timeCardDayRelationshipName, false)
            .setEnforceFLS(false)
            .selectFields(timeCardDayQueryFields)
            .addOrdering(timeCardDayOrdering);

        return (List<Time_Card_Line__c>) Database.query(theTimeCardLineQuery.toSOQL());
    }

    public with sharing class TimeCardUIConfiguration {
        public String variable1Name {get; set;}
        public String variable2Name {get; set;}
        @AuraEnabled
        public Boolean showTCVariable1 {get; set;}
        @AuraEnabled
        public Boolean showTCVariable2 {get; set;}
        @AuraEnabled
        public Boolean showBillable {get; set;}
        @AuraEnabled
        public Boolean showOvertime {get; set;}
        @AuraEnabled
        public Boolean invoiceCommentsAccessible {get; set;}
        @AuraEnabled
        public Boolean internalCommentsAccessible {get; set;}
        @AuraEnabled
        public Boolean invoiceCommentsUpdateable {get; set;}
        @AuraEnabled
        public Boolean internalCommentsUpdateable {get; set;}
    }

    public with sharing class TimeCardWrapper {
        @AuraEnabled
        public Time_Card__c timeCard {get; set;}
        @AuraEnabled
        public List<TimeCardHelper.TimeCardLineWrapper> lines {get; set;}
        @AuraEnabled
        public List<String> dayHeaders {get; set;}
        @AuraEnabled
        public List<Decimal> dayHours {get; set;}
        @AuraEnabled
        public Decimal totalHours {get; set;}
        @AuraEnabled
        public TimeCardUIConfiguration uiConfig {get; set;}
        @AuraEnabled
        public Boolean isEditModeAvailable {get; set;}
        @AuraEnabled
        public String projectFieldOnTclLabel {get; set;}
        @AuraEnabled
        public String projectTaskFieldOnTclLabel {get; set;}

        public TimeCardWrapper(Time_Card__c timeCard, List<TimeCardHelper.TimeCardLineWrapper> lines) {
            this.timeCard = timeCard;
            this.lines = lines;
            this.uiConfig = TimeCardHelper.getTimeCardUIConfiguration(true);
            this.dayHeaders = TimeCardHelper.getTimePeriodDayHeaders(timeCard);
            this.dayHours = calculateDayHours();
            this.totalHours = calculateTotalHours();
            this.isEditModeAvailable =
                Time_Card_Line__c.SObjectType.getDescribe().isCreateable()
                    && Time_Card_Line__c.SObjectType.getDescribe().isUpdateable();
            this.projectFieldOnTclLabel = Time_Card_Line__c.Project__c.getDescribe().getLabel();
            this.projectTaskFieldOnTclLabel = Time_Card_Line__c.Project_Task__c.getDescribe().getLabel();
        }

        private List<Decimal> calculateDayHours() {
            Map<String, Decimal> perDayTotals = new Map<String, Decimal>();
            for (String dayHeader : dayHeaders) {
                perDayTotals.put(dayHeader, 0);
            }

            for (TimeCardHelper.TimeCardLineWrapper line : lines) {
                for (Time_Card_Day__c day : line.days) {
                    String key = DateTime.newInstance(day.Date__c, Time.newInstance(0, 0, 0, 0)).format('E d');
                    Decimal dayTotal = perDayTotals.get(key);
                    perDayTotals.put(key, dayTotal + ((day.Hours__c != NULL) ? day.Hours__c : 0));
                }
            }

            return perDayTotals.values();
        }

        private Decimal calculateTotalHours() {
            Decimal result = 0;
            for (Decimal dayHoursTotal : dayHours) {
                result += dayHoursTotal;
            }
            return result;
        }
    }

    public with sharing class TimeCardLineWrapper {
        @AuraEnabled
        public Integer rowCount {get; set;} //recCount acts as a index for row. This is used to identify a row
        @AuraEnabled
        public Time_Card_Line__c timeCardLine {get; set;}//Variable for Detail List
        @AuraEnabled
        public Boolean isProjectError {get; set;}
        @AuraEnabled
        public Boolean isProjectTaskError {get; set;}
        @AuraEnabled
        public List<Time_Card_Day__c> days {get; set;}
        @AuraEnabled
        public Double lineTotal {get; set;}

        @TestVisible
        private List<SelectOption> currentProjectTasks;
        private Id currentProject {get; set;}

        public TimeCardLineWrapper( Time_Card__c timeCard,
                                    Time_Card_Line__c timeCardLine,
                                    Integer intCount,
                                    List<Time_Card_Day__c> days,
                                    List<SelectOption> currentProjectTasks) {

            this.timeCardLine = timeCardLine;
            this.currentProjectTasks = currentProjectTasks;
            this.currentProject = timeCardLine.Project__c;
            this.rowCount = intCount;
            this.isProjectError = false;
            this.isProjectTaskError = false;
            this.days = getTimeCardDaysByTimeCardPeriod(timeCard.Time_Card_Period__r, this.timeCardLine.Id, days);
            this.lineTotal = getLineTotal();
        }

        private List<Time_Card_Day__c> getTimeCardDaysByTimeCardPeriod(Time_Card_Period__c tcPeriod, Id timeCardLineId, List<Time_Card_Day__c> existedTimeCardDays) {
            if (existedTimeCardDays == NULL) {
                existedTimeCardDays = new List<Time_Card_Day__c>();
            }

            Date startDate = tcPeriod.Start_Date__c;
            Date endDate = tcPeriod.End_Date__c;

            List<Time_Card_Day__c> result = new List<Time_Card_Day__c>();
            for (Integer i = 0; i <= (startDate.daysBetween(endDate)); i++) {
                Boolean isFound = false;
                for (Time_Card_Day__c timeCardDay : existedTimeCardDays) {
                    if (timeCardDay.Date__c == startDate.addDays(i)) {
                        result.add(timeCardDay);
                        isFound = true;
                        break;
                    }
                }
                if (!isFound) {
                    Time_Card_Day__c day = new Time_Card_Day__c();
                    day.Time_Card_Line__c = timeCardLineId;
                    day.Date__c = startDate.addDays(i);
                    result.add(day);
                }
            }

            return result;
        }

        public List<SelectOption> getProjectTasks() {
            if (currentProject == timeCardLine.Project__c) {
                return currentProjectTasks;
            }
            currentProjectTasks = new List<SelectOption>{new SelectOption('', Label.SELECT_OPTION_NONE)};

            try {
                for (Project_Task__c theTask : FinancialSuiteUtils.getProjectTasks(timeCardLine.Project__c)) {
                    currentProjectTasks.add(new SelectOption(theTask.Id, theTask.Name));
                }
            }
            catch (Exception ex) {

            }

            currentProject = timeCardLine.Project__c;
            return currentProjectTasks;
        }

        public Double getLineTotal() {
            Double total = 0;

            for (Time_Card_Day__c day : days) {
                total += day.Hours__c != NULL ? day.Hours__c : 0;
            }
            return total;
        }
    }

}