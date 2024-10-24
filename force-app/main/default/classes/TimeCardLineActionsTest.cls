@isTest
public class TimeCardLineActionsTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    public static void testPreventUpdateActionPosted() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            DMLException dmlEx;

            try {
                update testData.timeCardLines[0];
            }
            catch(DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);

            // Test update error since attempted to change protected field.
            try {
                testData.timeCardLines[0].Project__c = testData.projects[1].Id;
                //set project task too because there is required filter on Project Task lookup field
                testData.timeCardLines[0].Project_Task__c = testData.projectTasks[2].Id;
                update testData.timeCardLines[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(System.StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, dmlEx.getDmlType(0));
        }

    }

    @isTest
    public static void testTimeCardLinePostedDeleteActionError() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            DMLException dmlEx;

            // Test delete associated with posted time card.
            try {
                delete testData.timeCardLines[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.POSTED_DELETE_ERROR, dmlEx.getDMLMessage(0));
        }

    }

    @isTest    
    public static void testTimeCardLineUnpostedDeleteSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.timeCards[0].Status__c = 'Approved';
            update testData.timeCards[0];

            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];

            DMLException dmlEx;
            try {
                delete testData.timeCardLines[0];
            }
            catch(DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
        }

    }
    
    @isTest
    public static void testSetTimeCardLinesFromBillingsAndSetTimeCardLineNonBilled() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createProjects()
            .createProjectTasks()
            .createTimeCards();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Time_Card_Day__c> timeCardDayList = new List<Time_Card_Day__c>();

            Integer index = 0;
            while (index < testData.timeCardLines.size()) {
                for (Time_Card_Day__c tcd : [SELECT Id
                                             FROM Time_Card_Day__c
                                             WHERE Time_Card_Line__c = :testData.timeCardLines[index].Id]) {

                    tcd.Billing_Line__c = testData.billingLines[index].Id;
                    timeCardDayList.add(tcd);
                }
                testData.timeCardLines[index].Billed__c = true;
                index++;
            }

            update testData.timeCardLines;
            update timeCardDayList;

            TimeCardLineActions.setTimeCardLinesFromBillings(new Map<Id,Billing__c>{testData.billings[0].Id => testData.billings[0]});
            System.assertEquals(2, TimeCardLineActions.timeCardLineIds.size());
            delete testData.billings;

            for (Time_Card_Line__c tcl : [SELECT Id, Billed__c
                                            FROM Time_Card_Line__c
                                            WHERE Id IN :TimeCardLineActions.timeCardLineIds]) {

                System.assertEquals(false, tcl.Billed__c);
            }
        }

    }

    @isTest
    public static void testSetTimeCardLinesFromBillingLinesAndSetTimeCardLineNonBilled() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createProjects()
            .createProjectTasks()
            .createTimeCards();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Time_Card_Day__c> timeCardDayList = new List<Time_Card_Day__c>();

            Integer index = 0;
            while (index < testData.timeCardLines.size()) {
                for (Time_Card_Day__c tcd : [SELECT Id
                                             FROM Time_Card_Day__c
                                             WHERE Time_Card_Line__c = :testData.timeCardLines[index].Id]) {

                    tcd.Billing_Line__c = testData.billingLines[index].Id;
                    timeCardDayList.add(tcd);
                }
                testData.timeCardLines[index].Billed__c = true;
                index++;
            }

            update testData.timeCardLines;
            update timeCardDayList;

            TimeCardLineActions.setTimeCardLinesFromBillings(new Map<Id,Billing__c>{testData.billings[0].Id => testData.billings[0]});

            System.assertEquals(2, TimeCardLineActions.timeCardLineIds.size());

            delete testData.billingLines;

            for (Time_Card_Line__c tcl : [SELECT Id, Billed__c
                                          FROM Time_Card_Line__c
                                          WHERE Id IN :TimeCardLineActions.timeCardLineIds]) {

                System.assertEquals(false, tcl.Billed__c);
            }
        }

    }

    @IsTest
    public static void testTimeCardLineNoNullPointerExceptionInsert() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createProjects()
                .createProjectTasks()
                .createTimeCards();

            System.runAs(testData.users.get(1)) {
                DMLException dmlEx;

                Time_Card_Line__c tcl = new Time_Card_Line__c();

                try {
                    insert tcl;
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

}