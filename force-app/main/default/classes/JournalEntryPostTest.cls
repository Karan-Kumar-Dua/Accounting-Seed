@IsTest
public class JournalEntryPostTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testJournalEntryPostWhenThereIsCashFlowNonConformity() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            //populate Cash Flow Category
            Cash_Disbursement__c testCD = testData.cashDisbursements[1];
            testData.createCashFlowCategories(false);

            Journal_Entry__c testJE = testData.journalEntries[0];
            testJE.Status__c = 'Approved';
            update testJE;

            Journal_Entry_Line__c testJeLine = testData.journalEntryLines[0];
            testJeLine.Cash_Flow_Category__c = testData.cashFlowCategories[0].Id;
            update testJeLine;

            ApexPages.Standardcontroller controller = new ApexPages.Standardcontroller(testJE);
            JournalEntryPost jep = new JournalEntryPost(controller);
            jep.post();

            System.assertEquals(AbstractPostHandler.CASH_FLOW_NON_CONFORMITY_HELP_TEXT, ApexPages.getMessages()[0].getSummary());
        }

    }

    @IsTest
    public static void testJournalEntryPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Journal_Entry__c testJE = testData.journalEntries[0];
            testJE.Status__c = 'Approved';
            update testJE;

            ApexPages.Standardcontroller controller = new ApexPages.Standardcontroller(testJE);
            JournalEntryPost jep = new JournalEntryPost(controller);

            Test.startTest();
            jep.post();
            Test.stopTest();

            System.assertEquals('Posted', [SELECT Status__c FROM Journal_Entry__c WHERE Id = :testJE.Id].Status__c);
            System.assertNotEquals(0, [SELECT count() FROM Transaction__c WHERE Journal_Entry_Line__r.Journal_Entry__c = :testJE.Id]);
            System.assertEquals(
                0,
                [
                    SELECT SUM(Amount__c) sum
                    FROM Transaction__c
                    WHERE Journal_Entry_Line__r.Journal_Entry__c = :testJE.Id
                    GROUP BY Journal_Entry_Line__r.Journal_Entry__c
                ][0].get('sum')
            );
        }

    }

    @IsTest
    public static void testJournalEntryPostNoSelectionError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Journal_Entry__c testJE = testData.journalEntries[0];

            ApexPages.StandardSetcontroller setController = new ApexPages.StandardSetcontroller(new List<Journal_Entry__c>{testJE});
            JournalEntryPost jep = new JournalEntryPost(setController);

            Test.startTest();
            jep.post();
            Test.stopTest();

            System.assertEquals(AbstractPostHandler.NO_SELECTION_POSTED_ERROR_MESSAGE, ApexPages.getMessages()[0].getSummary());
        }

    }

    @IsTest
    public static void testJournalEntryUnpostNoSelectionError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Journal_Entry__c testJE = testData.journalEntries[0];

            ApexPages.StandardSetcontroller setController = new ApexPages.StandardSetcontroller(new List<Journal_Entry__c>{testJE});
            JournalEntryPost jep = new JournalEntryPost(setController);

            Test.startTest();
            jep.unpost();
            Test.stopTest();

            System.assertEquals(JournalEntryPostHandler.NO_SELECTION_UNPOST_ERROR, ApexPages.getMessages()[0].getSummary());
        }

    }

    @IsTest
    public static void testJournalEntryUnpostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Journal_Entry__c testJE = testData.journalEntries[0];
            testJE.Status__c = 'Approved';
            update testJE;

            ApexPages.StandardController stdController = new ApexPages.StandardController(testJE);
            JournalEntryPost controller = new JournalEntryPost(stdController);

            Test.startTest();
            controller.post();

            System.assertEquals('Posted', [SELECT Status__c FROM Journal_Entry__c WHERE Id = :testJE.Id].Status__c);
            System.assertNotEquals(0, [SELECT count() FROM Transaction__c WHERE Journal_Entry_Line__r.Journal_Entry__c = :testJE.Id]);
            System.assertEquals(
                0,
                [
                    SELECT SUM(Amount__c) sum
                    FROM Transaction__c
                    WHERE Journal_Entry_Line__r.Journal_Entry__c = :testJE.Id
                    GROUP BY Journal_Entry_Line__r.Journal_Entry__c
                ][0].get('sum')
            );

            controller.unpost();
            Test.stopTest();

            System.assertNotEquals('Posted', [SELECT Status__c FROM Journal_Entry__c WHERE Id = :testJE.Id].Status__c);
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Journal_Entry_Line__r.Journal_Entry__c = :testJE.Id]);
        }

    }

    @IsTest
    public static void testJournalEntryPostAlreadyPostedError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Journal_Entry__c testJE = testData.journalEntries[0];
            testJE.Status__c = 'Approved';
            update testJE;

            ApexPages.StandardSetController stdSetController =
                new ApexPages.StandardSetController(new List<Journal_Entry__c>{testJE});
            stdSetController.setSelected(new List<Journal_Entry__c>{testJE});
            JournalEntryPost controller = new JournalEntryPost(stdSetController);
            controller.post();
            System.assertEquals('Posted', [SELECT Status__c FROM Journal_Entry__c WHERE Id = :testJE.Id].Status__c);

            controller = new JournalEntryPost(stdSetController);
            controller.validateBeforePost();//already posted

            System.assertEquals(1, controller.errorStatisticsLines.size());
            System.assertEquals(String.valueOf(testJE.Id), controller.errorStatisticsLines[0].sourceObjectId);
            System.assertEquals(
                String.valueOf(testJE.Id),
                controller.errorStatisticsLines[0].lineCells.get(PostResult.StatusCode.ALREADY_POSTED.name()).id
            );
            System.assertEquals(false, controller.showActionButton);
        }

    }

}