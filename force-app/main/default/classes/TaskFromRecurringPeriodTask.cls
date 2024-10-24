public with sharing class TaskFromRecurringPeriodTask extends AbstractSourceFromRecurring {	

    public TaskFromRecurringPeriodTask() {	
        isError = false;	
        DML_LIMIT = 500;	
        isLDOAsyncProcessingEnabled = false; // ldo support is not implemented for this object
        //used for batch for create all possible billings until multipleRecordsEndDate	
        resultStatusMap = new Map<Id, RecurringRecordResult>();	
        populateDescribeInfo();	
        populateCheckListOfFields();	
    }	

    private void populateDescribeInfo() {	
        this.targetHeaderRecordType = Task.getSObjectType();	
        this.sourceRecurringRecordType = Period_Task__c.getSObjectType();	
    }	

    private void populateCheckListOfFields() {	

        this.checkFieldsOnTargetHeaderRecord = new List<String>{	
            'Description',	
            'OwnerId',	
            'Priority',	
            'ActivityDate',	
            'WhoId',	
            'WhatId',	
            'Subject'	
        };	

        this.checkFieldsOnSourceRecurringRecord = new List<String>{	
            'Last_Accounting_Period_Task_Due_Date__c',	
            'Next_Accounting_Period_Task_Due_Date__c',	
            'Last_Accounting_Period_Task_Date__c',	
            'Next_Accounting_Period_Task_Date__c',	
            'Frequency_Type__c',	
            'Frequency_Num__c',	
            'Occurrences__c'	
        };	

    }	

    public TaskFromRecurringPeriodTask(List<Period_Task__c> selectedPeriodTasks) {	
        this();	
        try {	
            rSObjectList = queryRecurringPeriodTasks(selectedPeriodTasks, true);	

            validateDmlLimitCount();	
            if (!isDmlLimitError) {	
                isNoSelectionError = rSObjectList.isEmpty() ? true : false;	

                if (!isNoSelectionError) {	
                    init();	
                }	
            }	
        }	
        catch (Exception ex) {	
            isError = true;	
            if (!isBatchContext) {	
                ApexPages.addMessages(ex);	
            }	
        }	

    }	

    private List<Period_Task__c> queryRecurringPeriodTasks(List<Period_Task__c> selectedRecords, Boolean onlyActive) {	
        //Select main query fields	
        List<String> queryFields = new List<String>{	
            'Id',	
            'Name',	
            'Accounting_Period_Offset__c',	
            'Assignee__c',	
            'Comments__c',	
            'Create_Date__c',	
            'Due_Date__c',	
            'End_Date__c',	
            'Ends_On__c',	
            'Exclude_from_Automation__c',	
            'Frequency_Type__c',	
            'Frequency_Num__c',	
            'Last_Accounting_Period_Task_Date__c',	
            'Last_Accounting_Period_Task_Due_Date__c',	
            'Ledger__c',	
            'Never__c',	
            'Next_Accounting_Period_Task_Date__c',	
            'Next_Accounting_Period_Task_Due_Date__c',	
            'Number_of_Occurrences__c',	
            'Priority__c',	
            'Sort_Order__c',	
            'Status__c',	
            'Occurrences__c',	
            'Active__c'	
        };	

        //Add main query condition	
        String queryCondition = 'Id IN :selectedRecords ';	

        SOQLBuilder theQuery = new SOQLBuilder(Period_Task__c.SObjectType);	
        theQuery	
            .assertIsAccessible()	
            .setEnforceFLS(true)	
            .selectFields(queryFields)	
            .setCondition(queryCondition);	

        return (List<Period_Task__c>) Database.query(theQuery.toSOQL());	
    }	

    private void init() {	
        try {	
            objList = new List<TaskWrapper>();	
            Set<Date> periodDates = new Set<Date>();	
            Set<Id> assigneeIDs = new Set<Id>();	

            for (Period_Task__c  rTask : (List<Period_Task__c>) rSObjectList) {	
                resultStatusMap.put(rTask.Id, new RecurringRecordResult('Recurring Period Task', rTask.Id));	
                Date NextTaskDate = rTask.Next_Accounting_Period_Task_Date__c == null ? rTask.Create_Date__c : rTask.Next_Accounting_Period_Task_Date__c;	
                Date periodDate = Date.newInstance(NextTaskDate.year(), NextTaskDate.month(), 1);	
                periodDates.add(periodDate);	
                periodDates.add(periodDate.addMonths(Integer.valueOf(rTask.Accounting_Period_Offset__c)));	
                assigneeIDs.add(rTask.Assignee__c);	
            }	
            Map<Id, User> assigneeMap = new Map<Id, User>();	
            for(User U : DomainUtils.getUserById(assigneeIDs))	
            {	
                assigneeMap.put(U.Id, U);	
            }	

            Map<Date, Accounting_Period__c> periodsMap = new Map<Date, Accounting_Period__c>();	
            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();	
            for (Date periodDate : periodDates) {	
                Accounting_Period__c period = acctPeriodHandler.getAccountingPeriodByStartDate(periodDate);	
                if (period != NULL) {	
                    periodsMap.put(period.Start_Date__c, period);	
                }	
            }	

            for (Period_Task__c rTask : (List<Period_Task__c>) rSObjectList) {	
                Date nextTaskDate = rTask.Next_Accounting_Period_Task_Date__c == null ? rTask.Create_Date__c : rTask.Next_Accounting_Period_Task_Date__c;	

                Task newTask = createTaskFromPeriodTask(rTask, nextTaskDate);	
                Date periodStartDate = Date.newInstance(NextTaskDate.year(), NextTaskDate.month(), 1);	
                periodStartDate = periodStartDate.addMonths(Integer.valueOf(rTask.Accounting_Period_Offset__c));	
                newTask.WhatId = periodsMap.containsKey(periodStartDate) ? periodsMap.get(periodStartDate).Id : NULL;            	

                User Assignee = assigneeMap.get(rTask.Assignee__c);	
                newTask.OwnerId = Assignee != null ? Assignee.IsActive == true ? Assignee.Id : null : null;	

                rTask.Next_Accounting_Period_Task_Date__c = nextTaskDate;	

                TaskWrapper tw = new TaskWrapper(rTask, newTask);	
                resultStatusMap.get(rTask.Id).totalRecords += 1;	
                objList.add(tw);	
            }	
        }	
        catch (Exception ex) {	
            if (!isBatchContext) {	
                ApexPages.addMessages(ex);	
            }	
        }	
    }	

    public void createTasks() {	
        SavePoint sp = Test.isRunningTest() ? NULL : Database.setSavepoint();	
        try {	
            validateAccountingPeriod();	
            validateAssignee();    
            RecurringRecordSchedulingWrapper schedulingFields = new RecurringRecordSchedulingWrapper();
            schedulingFields.originalCreateDate = PACKAGE_QUALIFIER + 'Create_Date__c';
            schedulingFields.previousCreateDate = PACKAGE_QUALIFIER + 'Last_Accounting_Period_Task_Date__c';
            schedulingFields.nextCreateDate = PACKAGE_QUALIFIER + 'Next_Accounting_Period_Task_Date__c';
            schedulingFields.originalDueDate = PACKAGE_QUALIFIER + 'Due_Date__c';
            schedulingFields.previousDueDate =  PACKAGE_QUALIFIER + 'Last_Accounting_Period_Task_Due_Date__c';
            schedulingFields.nextDueDate = PACKAGE_QUALIFIER + 'Next_Accounting_Period_Task_Due_Date__c';
            schedulingFields.frequency = PACKAGE_QUALIFIER + 'Frequency_Type__c';
            schedulingFields.frequencyNum =  PACKAGE_QUALIFIER + 'Frequency_Num__c';
            schedulingFields.occurrence = PACKAGE_QUALIFIER + 'Occurrences__c';	
            setFieldsOnRecurringRecords(schedulingFields);	
            doDMLs(false, true);	
            populateSuccessResults();	
            recordsCreated = true;    	
        }	
        catch (Exception ex) {	
            if (!(Test.isRunningTest())) {	
                Database.rollback(sp);	
            }	
            handleExternalExceptionAndRollBack(ex);	
        }	
    }	


    private Task createTaskFromPeriodTask(Period_Task__c rTask, Date nextTaskDate) {	
        Task newTask = new Task();	
        newTask.Subject = rTask.Name;	
        newTask.Description = rTask.Comments__c;	
        newTask.Priority = rTask.Priority__c;
        newTask.Status = rTask.Status__c;	
        newTask.ActivityDate = nextTaskDate.addDays(rTask.Create_Date__c.daysBetween(rTask.Due_Date__c ));	
        return newTask;	
    }	

    private void validateAccountingPeriod() {	
        for (TaskWrapper tw : (List<TaskWrapper>) objList) {	
            if (((Task)tw.obj).WhatId == NULL) {	
                tw.hasError = true;	
                tw.errorMsg = INVALID_PERIOD_ERROR_MESSAGE;	
                resultStatusMap.get(tw.rObj.Id).errors.add(	
                    new RecurringRecordErrorResult(	
                      StatusCode.ACCOUNTING_PERIOD_ERROR,	
                      INVALID_PERIOD_ERROR_MESSAGE	
                    )	
                );	
            } 	
        }	
    }	

    private void validateAssignee() {	
        for (TaskWrapper tw : (List<TaskWrapper>) objList) {	
            if (((Task)tw.obj).OwnerId == NULL) {	
                tw.hasError = true;	
                tw.errorMsg = INVALID_ASSIGNEE_ERROR_MESSAGE;	
                resultStatusMap.get(tw.rObj.Id).errors.add(	
                    new RecurringRecordErrorResult(	
                        StatusCode.USER_ERROR,	
                        INVALID_ASSIGNEE_ERROR_MESSAGE	
                    )	
                );	
            } 	
        }	
    }	

    public with sharing class TaskWrapper extends RecordWrapper {	

        public TaskWrapper(Period_Task__c rTask, Task newTask) {	
            super(rTask, newTask, 0);	
            this.hasError = false;	
        }	

        public override Boolean isHeaderDirty() {	
            return false; // this is used for ldo processing which isn't supported for this object
        }

    }	

}