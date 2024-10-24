@IsTest	
private class RecurringPeriodTaskSchedulableBatchTest {	

    @TestSetup	
    private static void setupTestData() {	
        TestDataSuite.getInstance(true);	
    }	

    @IsTest	
    public static void RecurringPeriodTaskSchedulableBatchTest() {	
        TestDataSuite testData = TestDataSuite.getInstance()	
                                .createPeriodTasks();	

        Accounting_Period__c currentPeriod = new Accounting_Period__c(	
                Name = String.valueOf(Date.Today().Year()) + '-' + String.valueOf(datetime.now().format('MM')),	
                Start_Date__c = Date.newInstance(Date.Today().Year(), Date.Today().Month(), 1),	
                End_Date__c = Date.newInstance(Date.Today().Year(), Date.Today().Month(), 28),	
                Status__c = AccountingPeriodActions.OPEN_STATUS	
        );	
        insert currentPeriod;	

        System.runAs(testData.users.get(1)) {	
            test.startTest();	
                Database.executeBatch(new RecurringPeriodTaskSchedulableBatch('Recurring Period Task Job'), 200);	
            test.stopTest();	
        }	

        Map<string, Task> tasksBySubject = new Map<string, Task>();	
        for(Task T : [SELECT Id, Subject, OwnerId, ActivityDate, WhatId FROM Task]){	
            tasksBySubject.put(T.subject, T);	
        }	

        for(Period_Task__c periodTask : [select Id, Name, Assignee__c, Due_Date__c, Active__c, Frequency_Type__c, Accounting_Period_Offset__c, Occurrences__c,	
                                         Last_Accounting_Period_Task_Date__c, Last_Accounting_Period_Task_Due_Date__c, 	
                                         Next_Accounting_Period_Task_Date__c, Next_Accounting_Period_Task_Due_Date__c from Period_Task__c]){	

            if(periodTask.Name == 'Inactive - Period'){	
                System.assertEquals(periodTask.Last_Accounting_Period_Task_Date__c, null, 'Target Accounting Period does not exist, no updates to source record should be performed');	
                System.assertEquals(periodTask.Next_Accounting_Period_Task_Date__c, null, 'Target Accounting Period does not exist, no updates to source record should be performed');	
                continue;	
            }   	

            if(periodTask.Name == 'Inactive - User'){	
                System.assertEquals(periodTask.Last_Accounting_Period_Task_Date__c, null, 'Target Accounting Period does not exist, no updates to source record should be performed');	
                System.assertEquals(periodTask.Next_Accounting_Period_Task_Date__c, null, 'Target Accounting Period does not exist, no updates to source record should be performed');	
                continue;	
            }   	

            if(periodTask.Active__c == true){	
                System.assert((Task)tasksBySubject.get(periodTask.Name) != null, 'Active period tasks should have a task record created');	
                System.assertEquals(periodTask.Last_Accounting_Period_Task_Date__c, Date.Today(), 'Period task last period task date did not update correctly');	
                System.assertEquals(1, periodTask.Occurrences__c, 'Period Task occurrences did not increment correctly');	
                System.assertEquals(currentPeriod.Id, ((Task)tasksBySubject.get(periodTask.Name)).WhatId, 'Task WhatId does not reference the correct accouting period');	

                switch on periodTask.Frequency_Type__c {	
                    when 'Days' {	
                        System.assertEquals(periodTask.Next_Accounting_Period_Task_Date__c, Date.Today().addDays(1), 'Recurring record did not increment Days correctly');	
                        System.assertEquals(periodTask.Next_Accounting_Period_Task_Due_Date__c, Date.Today().addDays(1), 'Recurring record did not increment Due Date correctly');	
                    }	
                    when 'Weeks' {	
                        System.assertEquals(periodTask.Next_Accounting_Period_Task_Date__c, Date.Today().addDays(7), 'Recurring record did not increment Weeks correctly');	
                        System.assertEquals(periodTask.Next_Accounting_Period_Task_Due_Date__c, Date.Today().addDays(7), 'Recurring record did not increment Due Date correctly');	
                    }	
                    when 'Months' {	
                        System.assertEquals(periodTask.Next_Accounting_Period_Task_Date__c, Date.Today().addMonths(1), 'Recurring record did not increment Months correctly');	
                        System.assertEquals(periodTask.Next_Accounting_Period_Task_Due_Date__c, Date.Today().addMonths(1), 'Recurring record did not increment Due Date correctly');	
                    }	
                    when 'Years' {	
                        System.assertEquals(periodTask.Next_Accounting_Period_Task_Date__c, Date.Today().addYears(1), 'Recurring record did not increment Years correctly');	
                        System.assertEquals(periodTask.Next_Accounting_Period_Task_Date__c, Date.Today().addYears(1), 'Recurring record did not increment Due Date correctly');	
                    }	
                }	
            }	

        }	

        //error task created for invalid accounting period	
        for(Task invalidPeriodTask : [SELECT Id, WhatId FROM Task WHERE WhatId = :testData.periodTasks[7].Id]){	
            System.assertNotEquals(null, invalidPeriodTask, 'Error task not created for invalid Accounting Period recurring task');	
        }	

        //error task created for inactive user	
        for(Task invalidPeriodTask : [SELECT Id, WhatId FROM Task WHERE WhatId = :testData.periodTasks[6].Id]){	
            System.assertNotEquals(null, invalidPeriodTask, 'Error task not created for recurring task with inactive user');	
        }	


    }	
}