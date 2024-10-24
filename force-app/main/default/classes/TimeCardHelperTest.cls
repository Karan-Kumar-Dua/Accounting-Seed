@IsTest
private with sharing class TimeCardHelperTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testGetTimeCardData() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users[1]) {
            Time_Card__c tc = testData.timeCards.get(0);
            TimeCardHelper.TimeCardWrapper data = TimeCardHelper.getTimeCardData(tc.Id);
            System.assertEquals(tc.Id, data.timeCard.Id);
        }
    }

    @IsTest
    public static void testGetProjectTasks() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users[1]) {
            List<Project_Task__c> tasksForProject = FinancialSuiteUtils.getProjectTasks(testData.projects.get(0).Id);
            System.assertNotEquals(true, tasksForProject.isEmpty());
        }
    }

    @IsTest
    public static void testGetNewTimeCardLine() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();
        System.runAs(testData.users[1]) {
            TimeCardHelper.TimeCardLineWrapper tcl = TimeCardHelper.getNewTimeCardLine(
                testData.timeCards.get(0).Id
            );

            System.assertNotEquals(NULL, tcl);
            System.assertEquals(7, tcl.days.size());
            System.assertEquals(0, tcl.lineTotal);
        }
    }

    @IsTest
    public static void testDeleteTimeCardLine() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();
        System.runAs(testData.users[1]) {
            System.assertEquals(2, [SELECT count() FROM Time_Card_Line__c WHERE Time_Card__c = :testData.timeCards.get(0).Id]);
            TimeCardHelper.deleteTimeCardLine(
                [SELECT Id, LastModifiedDate FROM Time_Card__c WHERE Id = :testData.timeCards.get(0).Id],
                testData.timeCardLines.get(0).Id
            );
            System.assertEquals(1, [SELECT count() FROM Time_Card_Line__c WHERE Time_Card__c = :testData.timeCards.get(0).Id]);
        }
    }

    @IsTest
    public static void testSaveTimeCardLines() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users[1]) {

            TimeCardHelper.TimeCardWrapper tcWrapper = TimeCardHelper.getTimeCardData(testData.timeCards.get(0).Id);
            System.assertNotEquals(NULL, tcWrapper);
            System.assertEquals(testData.timeCards.get(0).Id, tcWrapper.timeCard.Id);

            TimeCardHelper.TimeCardLineWrapper newLine = tcWrapper.lines.get(0).clone();
            newLine.currentProjectTasks = NULL;
            newLine.timeCardLine.Id = NULL;
            TimeCardHelper.saveTimeCardLines(
                [SELECT Id, LastModifiedDate FROM Time_Card__c WHERE Id = :testData.timeCards.get(0).Id],
                new List<String>{JSON.serialize(newLine, true)}
            );
            System.assertEquals(3, [SELECT count() FROM Time_Card_Line__c WHERE Time_Card__c = :testData.timeCards.get(0).Id]);
        }
    }

    @IsTest
    static void testGetNextBaseline() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createTimeCards();

        System.runAs(testData.users[1]) {
            Date today = Date.today();
            
            // create current period
            Time_Card_Period__c prd = testData.periods[0].clone(false, true);
            prd.Name = today.year() + '-' +  today.month();
            prd.Start_Date__c = today.addDays(-1);
            prd.End_Date__c = today.addDays(6);
            insert prd;

            Test.startTest();
            Time_Card__c tc = TimeCardHelper.getNext();
            Test.stopTest();

            Ledger__c ledger = LedgerHandler.getInstanceWithSharing()
                .getLedgerById(LedgerHandler.getLedgerIdWithSharing());

            System.assertEquals(prd.Id, tc.Time_Card_Period__c);
            System.assertEquals(UserInfo.getUserId(), tc.Employee__c);
            System.assertEquals(ledger.Id, tc.Ledger__c);
        }
    }

    @IsTest
    static void testGetNextWithNoSubsequentPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createTimeCards();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Time_Card__c tc = TimeCardHelper.getNext();
            Test.stopTest();

            Ledger__c ledger = LedgerHandler.getInstanceWithSharing()
                .getLedgerById(LedgerHandler.getLedgerIdWithSharing());

            System.assertEquals(null, tc.Time_Card_Period__c);
            System.assertEquals(UserInfo.getUserId(), tc.Employee__c);
            System.assertEquals(ledger.Id, tc.Ledger__c);
        }
    }

    @IsTest
    static void testGetNextWithGap() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createTimeCards();

        System.runAs(testData.users[1]) {
            // create periods
            Date startWeek = Date.today().toStartOfWeek().addDays(-7);
            
            List<Time_Card_Period__c> prds = new List<Time_Card_Period__c>();
            while(prds.size() < 3) {
                Date weekOf = startWeek.addDays(7 * prds.size());
                Time_Card_Period__c prd = testData.periods[0].clone(false, true);
                prd.Name = weekOf.year() + '-' +  weekOf.month();
                prd.Start_Date__c = weekOf;
                prd.End_Date__c = weekOf.addDays(7);
                prds.add(prd);
            }
            insert prds;

            // create timecards
            List<Time_Card__c> tcs = new list<Time_Card__c>();
            Time_Card__c previousTC = testData.timeCards[0].clone(false, true);
            previousTC.Time_Card_Period__c = prds[0].Id;
            tcs.add(previousTC);

            Time_Card__c nextPlusOneTC = testData.timeCards[0].clone(false, true);
            nextPlusOneTC.Time_Card_Period__c = prds[2].Id;
            tcs.add(nextPlusOneTC);

            insert tcs;

            Test.startTest();
            Time_Card__c tc = TimeCardHelper.getNext();
            Test.stopTest();

            Ledger__c ledger = LedgerHandler.getInstanceWithSharing()
                .getLedgerById(LedgerHandler.getLedgerIdWithSharing());

            System.assertEquals(prds[1].Id, tc.Time_Card_Period__c);
            System.assertEquals(UserInfo.getUserId(), tc.Employee__c);
            System.assertEquals(ledger.Id, tc.Ledger__c);
        }
    }

    @IsTest
    static void testGetNextWithLastGreaterThanToday() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createTimeCards();

        System.runAs(testData.users[1]) {
            // create periods
            Date startWeek = Date.today().toStartOfWeek();
            
            List<Time_Card_Period__c> prds = new List<Time_Card_Period__c>();
            while(prds.size() < 3) {
                Date weekOf = startWeek.addDays(7 * prds.size());
                Time_Card_Period__c prd = testData.periods[0].clone(false, true);
                prd.Name = weekOf.year() + '-' +  weekOf.month();
                prd.Start_Date__c = weekOf;
                prd.End_Date__c = weekOf.addDays(7);
                prds.add(prd);
            }
            insert prds;

            // create timecards
            List<Time_Card__c> tcs = new list<Time_Card__c>();
            
            Time_Card__c previousTC = testData.timeCards[0].clone(false, true);
            previousTC.Time_Card_Period__c = prds[0].Id;
            tcs.add(previousTC);

            Time_Card__c nextPlusOneTC = testData.timeCards[0].clone(false, true);
            nextPlusOneTC.Time_Card_Period__c = prds[1].Id;
            tcs.add(nextPlusOneTC);
            
            insert tcs;

            Test.startTest();
            Time_Card__c tc = TimeCardHelper.getNext();
            Test.stopTest();

            Ledger__c ledger = LedgerHandler.getInstanceWithSharing()
                .getLedgerById(LedgerHandler.getLedgerIdWithSharing());

            System.assertEquals(prds[2].Id, tc.Time_Card_Period__c);
            System.assertEquals(UserInfo.getUserId(), tc.Employee__c);
            System.assertEquals(ledger.Id, tc.Ledger__c);
        }
    }

    @IsTest
    static void testGetNextWithLastLessThanToday() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createTimeCards();

        System.runAs(testData.users[1]) {
            // create periods
            Date startWeek = Date.today().addDays(-16);
            
            List<Time_Card_Period__c> prds = new List<Time_Card_Period__c>();
            while(prds.size() < 3) {
                Date weekOf = startWeek.addDays(7 * prds.size());
                Time_Card_Period__c prd = testData.periods[0].clone(false, true);
                prd.Name = weekOf.year() + '-' +  weekOf.month();
                prd.Start_Date__c = weekOf;
                prd.End_Date__c = weekOf.addDays(7);
                prds.add(prd);
            }
            insert prds;

            // create timecards
            Time_Card__c previousTC = testData.timeCards[0].clone(false, true);
            previousTC.Time_Card_Period__c = prds[0].Id;
            insert previousTC;

            Test.startTest();
            Time_Card__c tc = TimeCardHelper.getNext();
            Test.stopTest();

            Ledger__c ledger = LedgerHandler.getInstanceWithSharing()
                .getLedgerById(LedgerHandler.getLedgerIdWithSharing());

            System.assertEquals(prds[2].Id, tc.Time_Card_Period__c);
            System.assertEquals(UserInfo.getUserId(), tc.Employee__c);
            System.assertEquals(ledger.Id, tc.Ledger__c);
        }
    }

    @IsTest
    static void testGetNextOnePerPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createTimeCards();

        System.runAs(testData.users[1]) {            
            Date startWeek = Date.today().addDays(-9);
            
            List<Time_Card_Period__c> prds = new List<Time_Card_Period__c>();
            while(prds.size() < 3) {
                Date weekOf = startWeek.addDays(7 * prds.size());
                Time_Card_Period__c prd = testData.periods[0].clone(false, true);
                prd.Name = weekOf.year() + '-' +  weekOf.month();
                prd.Start_Date__c = weekOf;
                prd.End_Date__c = weekOf.addDays(7);
                prds.add(prd);
            }
            insert prds;

            // create timecard with 'Actual' ledger
            Time_Card__c actualTC = testData.timeCards[0].clone(false, true);
            actualTC.Time_Card_Period__c = prds[1].Id;
            insert actualTC;

            // update user's ledger
            testData.ledgerSettings.Ledger_Id__c = testData.ledgers[2].Id;
            update testData.ledgerSettings;

            Test.startTest();
            Time_Card__c tc = TimeCardHelper.getNext();
            Test.stopTest();

            Ledger__c ledger = LedgerHandler.getInstanceWithSharing()
                .getLedgerById(LedgerHandler.getLedgerIdWithSharing());

            System.assertEquals(prds[2].Id, tc.Time_Card_Period__c);
            System.assertEquals(UserInfo.getUserId(), tc.Employee__c);
            System.assertEquals(ledger.Id, tc.Ledger__c);
        }
    }
    
}