@IsTest
public class TimeCardPostHandlerTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testPurgeUnlockedPostingStatusFieldOnly() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks();

        System.runAs(testData.users.get(1)) {

            //Put some field into set of unlocked fields just to check it later
            TriggerObserver.getInstance().unlockField(Account.GL_Account_Variable_1__c);
            //create and post records
            testData.createTimeCards(true);
            //Validate that Posting Status field was removed from the set of unlocked fields after the end of posting routine
            System.assertEquals(false, TriggerObserver.getInstance().isUnlockedField(Time_Card__c.Status__c));
            //Validate that originally unlocked field is still unlocked
            System.assertEquals(true, TriggerObserver.getInstance().isUnlockedField(Account.GL_Account_Variable_1__c));
        }
    }

    @IsTest
    public static void testPartialPosting() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            testData.timeCards[0].Status__c = 'In Process';
            update testData.timeCards[0];

            AbstractPostHandler postHandler = new TimeCardPostHandler();
            postHandler.post(testData.timeCards);

            System.assertEquals(1, [SELECT count() FROM Time_Card__c WHERE Status__c = 'Posted']);
        } 

    }
    
    @IsTest
    public static void testTimeCardPostNoControlAccountError() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            delete [SELECT Id FROM GL_Account_Default__c WHERE GL_Account_Specification__c = :GLAccountDefaultsHandler.LABOR_GL_ACCOUNT];
            GLAccountDefaultsHandler.instance = null;
            Test.startTest();

            AbstractPostHandler postHandler = new TimeCardPostHandler();
            List<PostResult> results = postHandler.post(testData.timeCards);
            Test.stopTest();

            System.assertEquals(PostResult.StatusCode.NO_LABOR_CONTROL_ACCOUNT_DEFINED, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testTimeCardPostNoSelectionError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createTimeCards();

        testData.timeCards[0].Status__c = 'In Process';
        update testData.timeCards[0];

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            AbstractPostHandler postHandler = new TimeCardPostHandler();
            List<PostResult> results = postHandler.post(testData.timeCards);
            Test.stopTest();
            System.assertEquals(PostResult.StatusCode.STATUS_NOT_APPROVED, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testTimeCardPostBatchLineCountError() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            delete testData.timeCardLines;

            List<Time_Card_Line__c> timeCardLines = new List<Time_Card_Line__c>();
            for (Time_Card__c tc : testData.timeCards) {
                for (Integer i = 0; i < 200; i++) {
                    timeCardLines.add(
                        new Time_Card_Line__c(
                            Project__c = testData.projects[0].Id,
                            Project_Task__c = testData.projectTasks[0].Id,
                            Time_Card__c = tc.Id
                        )
                    );
                }
            }

            insert timeCardLines;
            List<Time_Card_Day__c> timeCardDays = new List<Time_Card_Day__c>();

            for (Time_Card_Line__c timeCardLine : timeCardLines) {
                for (Integer i = 0; i < 5; i++) {
                    timeCardDays.add(
                        new Time_Card_Day__c(
                            Date__c = System.today() + i,
                            Hours__c = 8,
                            Time_Card_Line__c = timeCardLine.Id
                        )
                    );
                }
            }

            insert timeCardDays;

            AbstractPostHandler postHandler = new TimeCardPostHandler();
            List<PostResult> results = postHandler.post(testData.timeCards);

            System.assertEquals(PostResult.StatusCode.LINE_COUNT_LIMIT_EXCEEDED, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testTimeCardUnpostNoSelectionError() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            AbstractPostHandler postHandler = new TimeCardPostHandler();
            List<PostResult> results = postHandler.unpost(testData.timeCards);
            Test.stopTest();
            System.assertEquals(PostResult.StatusCode.ALREADY_UNPOSTED, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testTimeCardPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            AbstractPostHandler postHandler = new TimeCardPostHandler();
            List<PostResult> results = postHandler.post(testData.timeCards);

            System.assertEquals(
                16,
                [SELECT count() FROM Transaction__c WHERE Time_Card_Day__r.Time_Card_Line__r.Time_Card__c IN :testData.timeCards]
            );
            System.assertEquals(
                'Posted',
                [SELECT Status__c FROM Time_Card__c WHERE Id = :testData.timeCards[0].Id].Status__c
            );
            System.assertEquals(
                0, [
                    SELECT SUM(Amount__c) sum
                    FROM Transaction__c
                    WHERE Time_Card_Day__r.Time_Card_Line__r.Time_Card__c = :testData.timeCards[0].Id
                    GROUP BY Time_Card_Day__r.Time_Card_Line__r.Time_Card__c
                ][0].get('sum')
            );

            postHandler.dispatcher.clearResultsMap();
            results = postHandler.unpost(testData.timeCards);
            Test.stopTest();

            System.assertEquals(
                0, [
                    SELECT count()
                    FROM Transaction__c
                    WHERE Time_Card_Day__r.Time_Card_Line__r.Time_Card__c IN :testData.timeCards
                ]
            );

            System.assertEquals(
                'Approved',
                [SELECT Status__c FROM Time_Card__c WHERE Id = :testData.timeCards[0].Id].Status__c
            );
        }

    }

    @IsTest
    public static void testTimeCardPostWithOvertimeSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            //Set overtime checkbox for all related lines
            List<Time_Card_Line__c> overtimedTimeCardLines = new List<Time_Card_Line__c>();
            for (Time_Card_Line__c tcl : [SELECT Id, Overtime__c FROM Time_Card_Line__c]) {
                tcl.Overtime__c = true;
                tcl.Billable__c = true;
                overtimedTimeCardLines.add(tcl);
            }

            update overtimedTimeCardLines;

            Cost_Rates__c cr = new Cost_Rates__c();
            cr.Hourly_Cost__c = 60;
            cr.Overtime_Hourly_Cost__c = 100;
            cr.Employee__c = UserInfo.getUserId();
            insert cr;

            AbstractPostHandler postHandler = new TimeCardPostHandler();
            List<PostResult> results = postHandler.post(testData.timeCards);

            System.assertEquals(16, [SELECT count() FROM Transaction__c WHERE Time_Card_Day__r.Time_Card_Line__r.Time_Card__c IN :testData.timeCards]);
            System.assertEquals('Posted', [SELECT Status__c FROM Time_Card__c WHERE Id = :testData.timeCards[0].Id].Status__c);
            System.assertEquals(0, [SELECT SUM(Amount__c) sum FROM Transaction__c WHERE Time_Card_Day__r.Time_Card_Line__r.Time_Card__c = :testData.timeCards[0].Id GROUP BY Time_Card_Day__r.Time_Card_Line__r.Time_Card__c][0].get('sum'));

            postHandler.dispatcher.clearResultsMap();
            results = postHandler.unpost(testData.timeCards);
            Test.stopTest();

            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Time_Card_Day__r.Time_Card_Line__r.Time_Card__c IN :testData.timeCards]);
            System.assertEquals('Approved', [SELECT Status__c FROM Time_Card__c WHERE Id = :testData.timeCards[0].Id].Status__c);
        }

    }

    @IsTest
    public static void testTimeCardPostGetAllCostRates() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            List<Cost_Rates__c> costRateList = new List<Cost_Rates__c>();
            Set<Id> employeeIdSet = new Set<Id>();
            for (User u : testData.users) {
                costRateList.add(new Cost_Rates__c(Employee__c = u.Id, Hourly_Cost__c = 150));
                employeeIdSet.add(u.Id);
            }

            insert costRateList;

            AbstractPostHandler postHandler = new TimeCardPostHandler();
            List<PostResult> results = postHandler.post(testData.timeCards);

            System.assertEquals(true, results[0].isSuccess);
        }
    }

    @IsTest
    public static void testTimeCardGetCostRateByTimeCardLine() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {

            Test.startTest();
            TimeCardPostHandler postHandler = new TimeCardPostHandler();
            List<PostResult> results = postHandler.post(testData.timeCards);
            Test.stopTest();

            Map<String, Cost_Rates__c> timeResourceCostMap = new Map<String, Cost_Rates__c>();
            Time_Card_Line__c timeCardLine = [
                SELECT Id, Time_Card__r.Employee__c, Project__c, Project_Task__c
                FROM Time_Card_Line__c
                WHERE Id = :testData.timeCardLines[0].Id
            ];
            String empKey = String.valueOf(UserInfo.getUserId()) + 'nullnull';
            Cost_Rates__c cr1 = new Cost_Rates__c(Employee__c = UserInfo.getUserId(), Hourly_Cost__c = 100);
            timeResourceCostMap.put(empKey, cr1);
            System.assertEquals(cr1, postHandler.getCostRateByTimeCardLine(timeResourceCostMap, timeCardLine));

            String projKey = String.valueOf(UserInfo.getUserId()) + String.valueOf(timeCardLine.Project__c) + 'null';
            Cost_Rates__c cr2 = new Cost_Rates__c(Employee__c = UserInfo.getUserId(), Hourly_Cost__c = 150);
            timeResourceCostMap.put(projKey, cr2);
            System.assertEquals(cr2, postHandler.getCostRateByTimeCardLine(timeResourceCostMap, timeCardLine));

            String projTaskKey =
                String.valueOf(UserInfo.getUserId()) +
                    String.valueOf(timeCardLine.Project__c) +
                    String.valueOf(timeCardLine.Project_Task__c);

            Cost_Rates__c cr3 = new Cost_Rates__c(Employee__c = UserInfo.getUserId(), Hourly_Cost__c = 200);
            timeResourceCostMap.put(projTaskKey, cr3);
            System.assertEquals(cr3, postHandler.getCostRateByTimeCardLine(timeResourceCostMap, timeCardLine));
        }
    }

    @IsTest
    public static void testPostTimeCardWhenAccountingPeriodClosed() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            Time_Card__c testTimeCard = testData.timeCards[0];

            Accounting_Period__c testAccountingPeriod = testData.acctPeriods[0];
            testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testAccountingPeriod;

            Test.startTest();

            AbstractPostHandler postHandler = new TimeCardPostHandler();
            List<PostResult> results = postHandler.post(new List<Time_Card__c>{testTimeCard});

            System.assertEquals(false, results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testUnpostTimeCardWhenAccountingPeriodClosed() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Time_Card__c testTimeCard = testData.timeCards[0];

            AbstractPostHandler postHandler = new TimeCardPostHandler();
            List<PostResult> results = postHandler.post(new List<Time_Card__c>{testTimeCard});
            System.assertEquals(true, results[0].isSuccess);

            Accounting_Period__c testAccountingPeriod = testData.acctPeriods[0];
            testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testAccountingPeriod;
            results = postHandler.unpost(new List<Time_Card__c>{testTimeCard});
            System.assertEquals(false, results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD, results[0].errors[0].statusCode);
        }

    }

    @isTest
    public static void testTimeCardOlyActualError() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.timeCards[0].Type__c = TimeCardActions.TYPE_VALUE_BUDGET;
            testData.timeCards[1].Type__c = TimeCardActions.TYPE_VALUE_BUDGET;
            update testData.timeCards;

            AbstractPostHandler postHandler = new TimeCardPostHandler();
            List<PostResult> results = postHandler.post(testData.timeCards);
            Test.stopTest();

            System.assertEquals(PostResult.StatusCode.ONLY_ACTUAL_TIME_CARD_ALLOW, results[0].errors[0].statusCode);
        }

    }

}