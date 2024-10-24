@isTest
public class TimeCardPostTransactionTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    public static void testTimeCardPostCostRateSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            for (Time_Card__c tc : testData.timeCards) {
                tc.Status__c = 'Approved';
            }
            update testData.timeCards;

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.timeCards);
            setController.setSelected(setController.getRecords());
            TimeCardPostTransaction controller = new TimeCardPostTransaction(setController);
            controller.validateBeforePost();

            System.assertEquals(2, controller.results.size());
            System.assertEquals(true, controller.results[0].isSuccess);
            System.assertEquals(true, controller.results[1].isSuccess);

            controller.post();

            List<Time_Card__c> postedTimeCards = [
                SELECT Id, Name, Status__c
                FROM Time_Card__c
                WHERE Id IN :testData.timeCards
                AND Status__c = 'Posted'
            ];

            System.assertEquals(2, postedTimeCards.size());

            setController = new ApexPages.StandardSetController(postedTimeCards);
            setController.setSelected(setController.getRecords());
            controller = new TimeCardPostTransaction(setController);
            controller.unpost();

            System.assertEquals(true, controller.results[0].isSuccess);
            System.assertEquals(true, controller.results[1].isSuccess);

            List<Time_Card__c> unpostedTimeCards = [
                SELECT Id, Name, Status__c
                FROM Time_Card__c
                WHERE Id IN :testData.timeCards
                AND Status__c = 'Approved'
            ];

            System.assertEquals(2, unpostedTimeCards.size());
        }

    }

    @isTest
    public static void testTimeCardPostNoSelectionError() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            Time_Card__c testTimeCard1 = testData.timeCards[0];
            Time_Card__c testTimeCard2 = testData.timeCards[1];

            testTimeCard1.Status__c = 'In Process';
            testTimeCard2.Status__c = 'In Process';
            update new List<Time_Card__c> {testTimeCard1, testTimeCard2};

            ApexPages.StandardSetController setController =
                new ApexPages.StandardSetController(new List<Time_Card__c>{testTimeCard1, testTimeCard2});
            setController.setSelected(setController.getRecords());

            Test.startTest();
            TimeCardPostTransaction controller = new TimeCardPostTransaction(setController);
            setController.setSelected(setController.getRecords());
            controller.validateBeforePost();

            System.assertEquals(2, controller.errorStatisticsLines.size());
            System.assertEquals(String.valueOf(testTimeCard1.Id), controller.errorStatisticsLines[0].sourceObjectId);
            System.assertEquals(String.valueOf(testTimeCard2.Id), controller.errorStatisticsLines[1].sourceObjectId);
            System.assertEquals(
                String.valueOf(testTimeCard1.Id),
                controller.errorStatisticsLines[0].lineCells.get(PostResult.StatusCode.STATUS_NOT_APPROVED.name()).id
            );
            System.assertEquals(
                String.valueOf(testTimeCard2.Id),
                controller.errorStatisticsLines[1].lineCells.get(PostResult.StatusCode.STATUS_NOT_APPROVED.name()).id
            );
            System.assertEquals(false, controller.showActionButton);
        }

    }

    @isTest
    public static void testTimeCardUnpostNoSelectionError() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT Id, Name, Status__c
                FROM Time_Card__c
                WHERE Id IN :testData.timeCards
            ]);
            setController.setSelected(setController.getRecords());
            TimeCardPostTransaction tcp = new TimeCardPostTransaction(setController);

            setController = new ApexPages.StandardSetController([
                SELECT Id, Name, Status__c
                FROM Time_Card__c
                WHERE Id IN :testData.timeCards
            ]);
            tcp = new TimeCardPostTransaction(setController);
            tcp.unpost();
            System.assertEquals(TimeCardPostHandler.NO_POSTED_SELECTION_MESSAGE, ApexPages.getMessages()[0].getSummary());
        }

    }

    @isTest
    public static void testTimeBudgetSelectedError() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            Time_Card__c testTimeCard1 = testData.timeCards[0];
            Time_Card__c testTimeCard2 = testData.timeCards[1];
            testData.timeCards[0].Status__c = 'Approved';
            testData.timeCards[0].Type__c = TimeCardActions.TYPE_VALUE_BUDGET;
            testData.timeCards[1].Status__c = 'Approved';
            testData.timeCards[1].Type__c = TimeCardActions.TYPE_VALUE_BUDGET;

            update testData.timeCards;

            ApexPages.StandardSetController setController =
                new ApexPages.StandardSetController(new List<Time_Card__c>{testTimeCard1, testTimeCard2});
            setController.setSelected(setController.getRecords());

            Test.startTest();
            TimeCardPostTransaction controller = new TimeCardPostTransaction(setController);
            setController.setSelected(setController.getRecords());
            controller.validateBeforePost();

            System.assertEquals(2, controller.errorStatisticsLines.size());
            System.assertEquals(String.valueOf(testTimeCard1.Id), controller.errorStatisticsLines[0].sourceObjectId);
            System.assertEquals(String.valueOf(testTimeCard2.Id), controller.errorStatisticsLines[1].sourceObjectId);
            System.assertEquals(
                String.valueOf(testTimeCard1.Id),
                controller.errorStatisticsLines[0].lineCells.get(PostResult.StatusCode.ONLY_ACTUAL_TIME_CARD_ALLOW.name()).id
            );
            System.assertEquals(
                String.valueOf(testTimeCard2.Id),
                controller.errorStatisticsLines[1].lineCells.get(PostResult.StatusCode.ONLY_ACTUAL_TIME_CARD_ALLOW.name()).id
            );
            System.assertEquals(false, controller.showActionButton);
        }

    }

}