@isTest
public class ScheduledRevenueExpensePostTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    public static void testScheduledRevenueExpensePostBatchNoSelectionClosedPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            Scheduled_Revenue_Expense__c testAmortizationEntry1 = testData.scheduledRevenues[0];
            Scheduled_Revenue_Expense__c testAmortizationEntry2 = testData.scheduledRevenues[1];

            AbstractPostHandler postHandler = new ScheduledRevenueExpensePostHandler();
            List<PostResult> results = postHandler.unpost(
                new List<Scheduled_Revenue_Expense__c>{
                    testAmortizationEntry1, testAmortizationEntry2
                }
            );

            System.assertEquals(true, results[0].isSuccess);
            System.assertEquals(true, results[1].isSuccess);

            //Check unpost functionality
            System.assertEquals(
                'Approved', [
                    SELECT Status__c
                    FROM Scheduled_Revenue_Expense__c
                    WHERE Id = :testAmortizationEntry1.Id
                ].Status__c
            );

            System.assertEquals(
                'Approved', [
                    SELECT Status__c
                    FROM Scheduled_Revenue_Expense__c
                    WHERE Id = :testAmortizationEntry2.Id
                ].Status__c
            );

            //now close Accounting Period and try to post these records
            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];

            Test.startTest();
            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(
                new List<Scheduled_Revenue_Expense__c>{
                    testAmortizationEntry1, testAmortizationEntry2
                }
            );
            setController.setSelected(setController.getRecords());
            ScheduledRevenueExpensePostTransaction controller = new ScheduledRevenueExpensePostTransaction(setController);
            controller.validateBeforePost();

            System.assertEquals(2, controller.errorStatisticsLines.size());
            System.assertEquals(String.valueOf(testAmortizationEntry1.Id), controller.errorStatisticsLines[0].sourceObjectId);
            System.assertEquals(String.valueOf(testAmortizationEntry2.Id), controller.errorStatisticsLines[1].sourceObjectId);
            System.assertEquals(
                String.valueOf(testData.acctPeriods[0].Id),
                controller.errorStatisticsLines[0].lineCells.get(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD.name()).id
            );
            System.assertEquals(
                String.valueOf(testData.acctPeriods[0].Id),
                controller.errorStatisticsLines[1].lineCells.get(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD.name()).id
            );
            System.assertEquals(false, controller.showActionButton);
        }

    }

    @isTest
    public static void testScheduledRevenueExpensePostBatchNoSelectionError() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            Scheduled_Revenue_Expense__c testAmortizationEntry1 = testData.scheduledRevenues[0];
            Scheduled_Revenue_Expense__c testAmortizationEntry2 = testData.scheduledRevenues[1];

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(
                new List<Scheduled_Revenue_Expense__c>{testAmortizationEntry1, testAmortizationEntry2}
            );
            setController.setSelected(setController.getRecords());
            ScheduledRevenueExpensePostTransaction controller = new ScheduledRevenueExpensePostTransaction(setController);

            Test.startTest();
            controller.validateBeforePost();

            System.assertEquals(2, controller.errorStatisticsLines.size());
            System.assertEquals(String.valueOf(testAmortizationEntry1.Id), controller.errorStatisticsLines[0].sourceObjectId);
            System.assertEquals(String.valueOf(testAmortizationEntry2.Id), controller.errorStatisticsLines[1].sourceObjectId);
            System.assertEquals(
                String.valueOf(testAmortizationEntry1.Id),
                controller.errorStatisticsLines[0].lineCells.get(PostResult.StatusCode.ALREADY_POSTED.name()).id
            );
            System.assertEquals(
                String.valueOf(testAmortizationEntry2.Id),
                controller.errorStatisticsLines[1].lineCells.get(PostResult.StatusCode.ALREADY_POSTED.name()).id
            );
            System.assertEquals(false, controller.showActionButton);
        }

    }

    @isTest
    public static void testScheduledRevenueExpenseUnpostClosedPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            Scheduled_Revenue_Expense__c testSRE = testData.scheduledRevenues[0];

            ApexPages.StandardController controller = new ApexPages.StandardController(testSRE);

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];

            ScheduledRevenueExpensePostTransaction sce = new ScheduledRevenueExpensePostTransaction(controller);
            sce.unpost();

            System.assertEquals(
                AbstractPostHandler.ACCOUNTING_PERIOD_CLOSED_ERROR_MESSAGE,
                ApexPages.getMessages()[0].getSummary()
            );
        }

    }

    @IsTest
    public static void testScheduledRevenueExpenseBatchNoRecordsSelected() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT Id
                FROM Scheduled_Revenue_Expense__c
                WHERE Id = :testData.scheduledRevenues[0].Id
            ]);

            ScheduledRevenueExpensePostTransaction controller = new ScheduledRevenueExpensePostTransaction(setController);
            controller.post();

            System.assertEquals(
                ScheduledRevenueExpensePostHandler.NO_SELECTION_POSTED_ERROR_MESSAGE,
                ApexPages.getMessages()[0].getSummary()
            );

            controller.unpost();

            System.assertEquals(
                ScheduledRevenueExpensePostHandler.NO_SELECTION_UNPOSTED_ERROR_MESSAGE,
                ApexPages.getMessages()[1].getSummary()
            );
        }

    }

}