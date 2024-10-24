@IsTest
public class TimeCardActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testPreventCreateIfTimeCardPeriodIsNotOpen() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks();
        System.runAs(testData.users.get(1)) {
            Time_Card_Period__c timeCardPeriod = new Time_Card_Period__c(
                Name = '1991-10',
                Start_Date__c = Date.newInstance(1991, 10, 1),
                End_Date__c = Date.newInstance(1991, 10, 7),
                Status__c = 'Closed'
            );

            insert timeCardPeriod;

            Time_Card__c timeCard = new Time_Card__c();
            timeCard.Time_Card_Period__c = timeCardPeriod.Id;
            timeCard.Employee__c = testData.users[0].Id;
            timeCard.Ledger__c = testData.ledgers[0].Id;
            timeCard.Status__c = 'In Process';

            DmlException dmlEx;
            try {
                insert timeCard;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(TimeCardActions.PERIOD_IS_NOT_OPEN_ERROR, dmlEx.getDMLMessage(0));
        }
    }

    @IsTest    
    public static void testPreventUpdateActionPosted() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards(true);

        System.runAs(testData.users.get(1)) {

            DMLException dmlEx;
            // Test update no error since no fields changed.
            Time_Card__c timeCard = [
                SELECT Id, Status__c
                FROM Time_Card__c
                WHERE Id = :testData.timeCards[0].Id LIMIT 1
            ];

            try {
                update timeCard;
            }
            catch(DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);

            // Test update error since attempted to change protected field on account payable.
            try {
                timeCard.Status__c = 'Approved';
                update timeCard;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(System.StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, dmlEx.getDmlType(0));
        }

    }
    
    @IsTest    
    public static void testValidateTimeCardDoesNotExistPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Time_Card__c> timeCards = new List<Time_Card__c>();

            Time_Card__c timeCard = new Time_Card__c();
            timeCard.Time_Card_Period__c = testData.periods[0].Id;
            timeCard.Employee__c = testData.users[0].Id;
            timeCard.Ledger__c = testData.ledgers[0].Id;
            timeCard.Status__c = 'In Process';
            timeCards.add(timeCard);

            Time_Card__c timeCard2 = new Time_Card__c();
            timeCard2.Time_Card_Period__c = testData.periods[0].Id;
            timeCard2.Employee__c = testData.users[0].Id;
            timeCard2.Ledger__c = testData.ledgers[0].Id;
            timeCard2.Status__c = 'In Process';
            timeCards.add(timeCard2);

            // Inserting this time card list should throw a DML exception
            DmlException dmlEx;
            try {
                insert timeCard;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            // Inserting this time card should throw a DML exception
            try {
                insert timeCard2;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(System.StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, dmlEx.getDmlType(0));
        }

    }

    @IsTest       
    public static void testTimeCardUnpostedDeleteSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.timeCards[0].Status__c = 'Approved';
            update testData.timeCards[0];

            DMLException dmlEx;
            try {
                delete testData.timeCards[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
        }

    }
    
    @IsTest    
    public static void testTimeCardPostedDeleteError() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            DMLException dmlEx;
            try {
                delete testData.timeCards[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.POSTED_DELETE_ERROR, dmlEx.getDMLMessage(0));
        }

    }

    @IsTest      
    public static void testPreventInsertMaxDayCountError() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Time_Card_Line__c> lineList = new List<Time_Card_Line__c>();
            for (Integer i = 0; i < (TimeCardActions.MAX_DAY_COUNT/7) + 1; i++) {
                lineList.add(testData.timeCardLines[0].clone(false, true));
            }
            insert lineList;

            List<Time_Card_Day__c> dayList = new List<Time_Card_Day__c>();
            Integer dayCount = 1;
            for (Time_Card_Line__c tLine : lineList) {
                for (Integer j = 0; j < 7; j++) {
                    Time_Card_Day__c tDay = testData.timeCardDays[3].clone(false, true);
                    tDay.Date__c = testData.timeCardDays[0].Date__c + dayCount++;
                    tDay.Time_Card_Line__c = tLine.Id;
                    dayList.add(tDay);
                }
            }

            DMLException dmlEx;
            try {
                insert dayList;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(TimeCardActions.MAX_DAY_ERROR, dmlEx.getDmlMessage(0));
        }

    }
    
    @IsTest    
    public static void testPreventInsertMaxLineDaySuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Time_Card_Line__c> lineList = new List<Time_Card_Line__c>();
            for (Integer i = 0; i < (TimeCardActions.MAX_DAY_COUNT/7) - 100; i++) {
                lineList.add(testData.timeCardLines[0].clone(false, true));
            }
            insert lineList;

            List<Time_Card_Day__c> dayList = new List<Time_Card_Day__c>();
            Integer dayCount = 1;
            for (Time_Card_Line__c tLine : lineList) {
                for (Integer j = 0; j < 7; j++) {
                    Time_Card_Day__c tDay = testData.timeCardDays[3].clone(false, true);
                    tDay.Date__c = testData.timeCardDays[3].Date__c + dayCount++;
                    tDay.Time_Card_Line__c = tLine.Id;
                    dayList.add(tDay);
                }
            }

            DMLException dmlEx;
            try {
                insert dayList;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
        }

    }

    @IsTest
    public static void testPreventUpdateTimeCardPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            //delete last TC to make second Time Card Period available for new TC
            delete [SELECT Id FROM Time_Card__c WHERE Id = :testData.timeCards.get(1).Id];
            //make sure that the TC has associated Time Card Days
            Time_Card__c testTC = testData.timeCards.get(0);
            System.assertNotEquals(0, [SELECT Day_Count__c FROM Time_Card__c WHERE Id = :testTC.Id].Day_Count__c);

            Test.startTest();
            DMLException dmlEx;
            try {
                //try to set new Time Card Period for the TC
                testTC.Time_Card_Period__c = testData.periods.get(1).Id;
                update testTC;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            //since this TC has associated Days records we expect DML error on update
            System.assertEquals(TimeCardActions.TIME_CARD_PERIOD_UPDATE_ERROR, dmlEx.getDmlMessage(0));
        }

    }
    
    @IsTest
    public static void testPopulateLedgerField() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Time_Card__c timeCard = testData.timeCards[0].clone(false, true);
            delete testData.timeCards[0];

            timeCard.Ledger__c = NULL;
            insert timeCard;

            System.assertEquals(
                testData.ledgers[0].Id, [
                    SELECT Id, Ledger__c FROM Time_Card__c WHERE Id = :timeCard.Id
                ].Ledger__c
            );
        }

    }

    @IsTest
    public static void testValidateRequiredFields() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects();

        System.runAs(testData.users.get(1)) {
            Time_Card_Period__c tcPeriod = new Time_Card_Period__c(
                Name = '1991-10',
                Start_Date__c = Date.newInstance(1991, 10, 1),
                End_Date__c = Date.newInstance(1991, 10, 7),
                Status__c = 'Open'
            );
            insert tcPeriod;

            Time_Card__c testTC = new Time_Card__c(
                Time_Card_Period__c = tcPeriod.Id,
                Status__c = 'In Process'
            );

            DmlException dmlEx;
            try {
                insert testTC;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    public static void testSetPreventUpdateStatusFieldPostedError() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            DMLException dmlEx = NULL;
            try {
                testData.timeCards[0].Status__c = 'Posted';
                update testData.timeCards[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.UPDATE_STATUS_ERROR, dmlEx.getDMLMessage(0));
        }

    }

    @IsTest
    public static void testTimeCardNoNullPointerExceptionInsert() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createProjects()
                .createProjectTasks()
                .createTimeCards();

            System.runAs(testData.users.get(1)) {
                DMLException dmlEx;

                Time_Card__c tc = new Time_Card__c();

                try {
                    insert tc;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }

                System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));

            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }


    @IsTest
    public static void testSetDefaultStatus() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            String defaultStatusTC;
            for (Schema.PicklistEntry pe : Time_Card__c.getSObjectType()
                                                .getDescribe().fields.getMap()
                                                .get(GlobalVariables.PACKAGE_QUALIFIER + 'Status__c')
                                                .getDescribe().getPicklistValues()) {

                if (pe.isDefaultValue()) {
                    defaultStatusTC = pe.getValue();
                    break;
                }
            }

            Time_Card_Period__c timeCardPeriod = new Time_Card_Period__c(
                Name = '1991-10',
                Start_Date__c = Date.newInstance(1991, 10, 1),
                End_Date__c = Date.newInstance(1991, 10, 7),
                Status__c = 'Open'
            );
            insert timeCardPeriod;

            //test when Status == NULL
            Time_Card__c timeCard  = new Time_Card__c(
                Time_Card_Period__c = timeCardPeriod.Id,
                Employee__c = UserInfo.getUserId()
            );

            insert timeCard;
            System.assertEquals(
                defaultStatusTC, [
                    SELECT Id, Status__c FROM Time_Card__c WHERE Id = :timeCard.Id
                ].Status__c
            );

            //test when Status was set to some undefined value
            timeCard.Status__c = 'Undefined Value';
            update timeCard;
            System.assertEquals(
                defaultStatusTC, [
                    SELECT Id, Status__c FROM Time_Card__c WHERE Id = :timeCard.Id
                ].Status__c
            );

            //test update to one of pre-defined values
            timeCard.Status__c = 'Approved';
            update timeCard;
            System.assertEquals(
                'Approved', [
                    SELECT Id, Status__c FROM Time_Card__c WHERE Id = :timeCard.Id
                ].Status__c
            );

        }
    }

    @IsTest
    public static void testValidateRequiredTypeField() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects();

        System.runAs(testData.users.get(1)) {
            Time_Card_Period__c tcPeriod = new Time_Card_Period__c(
                Name = '1991-10',
                Start_Date__c = Date.newInstance(1991, 10, 1),
                End_Date__c = Date.newInstance(1991, 10, 7),
                Status__c = 'Open'
            );
            insert tcPeriod;

            Time_Card__c testTC = new Time_Card__c(
                Time_Card_Period__c = tcPeriod.Id,
                Status__c = 'In Process',
                Employee__c = UserInfo.getUserId(),
                Ledger__c = testData.ledgers[0].Id,
                Type__c = NULL

            );

            DmlException dmlEx;
            try {
                insert testTC;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    public static void testValidateTimeCardDoesNotExistPeriodForBudgetType() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Time_Card__c> timeCards = new List<Time_Card__c>();

            Time_Card__c timeCard = new Time_Card__c();
            timeCard.Time_Card_Period__c = testData.periods[0].Id;
            timeCard.Employee__c = testData.users[0].Id;
            timeCard.Ledger__c = testData.ledgers[0].Id;
            timeCard.Status__c = 'In Process';
            timeCard.Type__c = TimeCardActions.TYPE_VALUE_BUDGET;
            timeCards.add(timeCard);

            Time_Card__c timeCard2 = new Time_Card__c();
            timeCard2.Time_Card_Period__c = testData.periods[0].Id;
            timeCard2.Employee__c = testData.users[0].Id;
            timeCard2.Ledger__c = testData.ledgers[0].Id;
            timeCard2.Status__c = 'In Process';
            timeCard.Type__c = TimeCardActions.TYPE_VALUE_BUDGET;
            timeCards.add(timeCard2);

            DmlException dmlEx;
            try {
                insert timeCard;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            try {
                insert timeCard2;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);
        }

    }

    @IsTest
    public static void testNativeCloneTimeCardLines() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        Time_Card_Line__c tlBillable = testData.timeCardLines[0];
        tlBillable.Billable__c = true;
        update tlBillable;

        System.runAs(testData.users[1]) {
            Time_Card_Period__c period = new Time_Card_Period__c(
                Name='1991-12',
                Start_Date__c = Date.newInstance(1991, 12, 1),
                End_Date__c = Date.newInstance(1991, 12, 7),
                Status__c = 'Open'
            );
            insert period;

            Time_Card__c newTimeCard = testData.timeCards.get(0).clone(false);
            newTimeCard.Time_Card_Period__c = period.Id;
            insert newTimeCard;

            List<Time_Card_Line__c> existedList = [SELECT Day_Count__c FROM Time_Card_Line__c WHERE Time_Card__c = :testData.timeCards.get(0).Id];
            List<Time_Card_Line__c> newList = [SELECT Day_Count__c, Billable__c, Overtime__c FROM Time_Card_Line__c WHERE Time_Card__c = :newTimeCard.Id];

            System.assertEquals(existedList.size(), newList.size());
            System.assertEquals(0, newList[0].Day_Count__c);
            System.assertEquals(true, newList[0].Billable__c);
            System.assertEquals(false, newList[0].Overtime__c);

            List<Time_Card_Day__c> newDayList = [SELECT Hours__c FROM Time_Card_Day__c WHERE Time_Card_Line__c = :newList[0].Id];

            System.assertEquals(0, newDayList.size());
        }
    }

    @IsTest
    public static void testNativeCloneTimeCardStatus() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards(true);
        System.runAs(testData.users[1]) {
            Time_Card_Period__c period = new Time_Card_Period__c(
                Name='1991-12',
                Start_Date__c = Date.newInstance(1991, 12, 1),
                End_Date__c = Date.newInstance(1991, 12, 7),
                Status__c = 'Open'
            );
            insert period;

            Time_Card__c newTimeCard = testData.timeCards.get(0).clone(false);
            newTimeCard.Time_Card_Period__c = period.Id;
            insert newTimeCard;

            Time_Card__c newTC = [SELECT Status__c FROM Time_Card__c WHERE Id = :newTimeCard.Id LIMIT 1];

            System.assertEquals(FinancialSuiteUtils.getDefaultPostingStatus(Time_Card__c.Status__c), newTC.Status__c);
        }
    }

    @IsTest
    public static void testNativeCloneTimeCardNoneType() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();
        System.runAs(testData.users[1]) {
            Time_Card_Period__c period = new Time_Card_Period__c(
                Name='1991-12',
                Start_Date__c = Date.newInstance(1991, 12, 1),
                End_Date__c = Date.newInstance(1991, 12, 7),
                Status__c = 'Open'
            );
            insert period;

            Time_Card__c newTimeCard = testData.timeCards.get(0).clone(false);
            newTimeCard.Time_Card_Period__c = period.Id;
            newTimeCard.Type__c = NULL;

            DmlException dmlEx;
            try {
                insert newTimeCard;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testNativeCloneTimeCardEmptyEmployee() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();
        System.runAs(testData.users[1]) {
            Time_Card_Period__c period = new Time_Card_Period__c(
                Name='1991-12',
                Start_Date__c = Date.newInstance(1991, 12, 1),
                End_Date__c = Date.newInstance(1991, 12, 7),
                Status__c = 'Open'
            );
            insert period;

            Time_Card__c newTimeCard = testData.timeCards.get(0).clone(false);
            newTimeCard.Time_Card_Period__c = period.Id;
            newTimeCard.Employee__c = NULL;

            DmlException dmlEx;
            try {
                insert newTimeCard;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }
    }
}