@isTest
public class TimeCardDayActionsTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    public static void testTimeCardDayPostedDeleteActionError() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            DMLException dmlEx;

            // Test delete associated with posted time card.
            try {
                delete testData.timeCardDays[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.POSTED_DELETE_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @isTest    
    public static void testTimeCardDayUnpostedDeleteSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.timeCards[0].Status__c = 'Approved';
            update testData.timeCards[0];

            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];
            Test.stopTest();

            DMLException dmlEx;
            try {
                delete testData.timeCardDays[0];
            }
            catch(DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
        }

    }    
    
    @isTest
    public static void testPreventUpdateActionPostedNoChangeSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            DMLException dmlEx;

            // Test update no error since no fields changed.
            try {
                update testData.timeCardDays[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);
        }

    } 

    @IsTest
    public static void testPreventUpdateActionPostedNoChangeSetScaleSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.timeCards[0].Status__c = 'Approved';
            update testData.timeCards[0];

            testData.timeCardDays[0].Hours__c = 40.6457545;
            update testData.timeCardDays[0];

            ApexPages.StandardSetcontroller controller = new ApexPages.StandardSetcontroller(
                new List<Time_Card__c>{[
                    SELECT Id, Status__c
                    FROM Time_Card__c
                    WHERE Id = :testData.timeCards[0].Id
                ]}
            );
            controller.setSelected(controller.getRecords());
            TimeCardPostTransaction pt = new TimeCardPostTransaction(controller);
            pt.post();

            System.assertEquals(
                'Posted',
                [SELECT Id, Status__c FROM Time_Card__c WHERE Id = :testData.timeCards[0].Id].Status__c
            );

            DMLException dmlEx;

            // Test update error since attempted to change protected field.
            try {
                testData.timeCardDays[0].Hours__c = 40.65;
                update testData.timeCardDays[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
        }

    }

    @IsTest
    public static void testPreventUpdateActionPostedError() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards(true);

        System.runAs(testData.users.get(1)) {

            DMLException dmlEx;

            // Test update error since attempted to change protected field.
            try {
                testData.timeCardDays[0].Hours__c = 40;
                update testData.timeCardDays[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(System.StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, dmlEx.getDmlType(0));
        }

    }
    
    @IsTest
    public static void testPreventDeleteLineActionPosted() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createTimeCards()
            .createJournalEntries(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            DMLException dmlEx;
            try {
                delete testData.journalEntryLines;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.POSTED_DELETE_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @isTest
    public static void testPreventTimeCardDayDuplicateInsertError() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Time_Card_Day__c timeCardDay = testData.timeCardDays[0].clone(false, true);

            DMLException dmlEx;

            try {
                insert timeCardDay;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                TimeCardDayActions.DUPLICATE_ERROR.replace('<DATE>',testData.timeCardDays[0].Date__c.format()) +
                    [SELECT Name FROM Time_Card_Line__c WHERE Id = :testData.timeCardLines[0].Id].Name,
                dmlEx.getDMLMessage(0)
            );
        }

    }
    
    @isTest
    public static void testPreventTimeCardDayDuplicateUpdateError() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.timeCardDays[0].Date__c = testData.timeCardDays[1].Date__c;

            DMLException dmlEx;

            try {
                update testData.timeCardDays[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                TimeCardDayActions.DUPLICATE_ERROR.replace('<DATE>',testData.timeCardDays[0].Date__c.format()) +
                    [SELECT Name FROM Time_Card_Line__c WHERE Id = :testData.timeCardLines[0].Id].Name,
                dmlEx.getDMLMessage(0)
            );
        }

    }

    @IsTest
    public static void testTimeCardDayNoNullPointerExceptionInsert() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency();

            System.runAs(testData.users.get(1)) {
                DMLException dmlEx;

                Time_Card_Day__c tcd = new Time_Card_Day__c();

                try {
                    insert tcd;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }

                System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));

            }
        }
        catch (Exception ex) {

        }
    }

}