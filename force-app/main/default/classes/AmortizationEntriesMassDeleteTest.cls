@IsTest
public class AmortizationEntriesMassDeleteTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testMassDeleteNoSelection() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users[1]) {
            //validate records are posted
            Scheduled_Revenue_Expense__c testAmortizationEntry1 = [
                SELECT Id, Status__c
                FROM Scheduled_Revenue_Expense__c
                WHERE Id = :testData.scheduledRevenues[0].Id
            ];

            Scheduled_Revenue_Expense__c testAmortizationEntry2 = [
                SELECT Id, Status__c
                FROM Scheduled_Revenue_Expense__c
                WHERE Id = :testData.scheduledRevenues[1].Id
            ];

            System.assertEquals('Posted', testAmortizationEntry1.Status__c);
            System.assertEquals('Posted', testAmortizationEntry2.Status__c);

            ApexPages.StandardSetController stdController = new ApexPages.StandardSetController(
                new List<Scheduled_Revenue_Expense__c>{testAmortizationEntry1, testAmortizationEntry2}
            );

            stdController.setSelected(new List<Scheduled_Revenue_Expense__c>{
                testAmortizationEntry1, testAmortizationEntry2
            });

            AmortizationEntriesMassDelete controller = new AmortizationEntriesMassDelete(stdController);

            Test.startTest();
            controller.validateSelectedRecords();
            System.assertEquals(false, controller.showDeleteButton);
            System.assertEquals(AmortizationEntriesMassDelete.NO_SELECTION_ERROR_MESSAGE, ApexPages.getMessages()[0].getDetail());
        }
    }

    @IsTest
    public static void testMassDeleteSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users[1]) {
            //validate records are posted
            Scheduled_Revenue_Expense__c testAmortizationEntry1 = [
                SELECT Id, Status__c
                FROM Scheduled_Revenue_Expense__c
                WHERE Id = :testData.scheduledRevenues[0].Id
            ];

            Scheduled_Revenue_Expense__c testAmortizationEntry2 = [
                SELECT Id, Status__c
                FROM Scheduled_Revenue_Expense__c
                WHERE Id = :testData.scheduledRevenues[1].Id
            ];

            System.assertEquals('Posted', testAmortizationEntry1.Status__c);
            System.assertEquals('Posted', testAmortizationEntry2.Status__c);

            Test.startTest();
            //Unpost second record
            AbstractPostHandler postHandler = new ScheduledRevenueExpensePostHandler();
            List<PostResult> postResults = postHandler.unpost(new List<Scheduled_Revenue_Expense__c>{testAmortizationEntry2});
            System.assertEquals(true, postResults[0].isSuccess);

            ApexPages.StandardSetController stdController = new ApexPages.StandardSetController(
                new List<Scheduled_Revenue_Expense__c>{testAmortizationEntry1, testAmortizationEntry2}
            );

            stdController.setSelected(new List<Scheduled_Revenue_Expense__c>{
                testAmortizationEntry1, testAmortizationEntry2
            });

            AmortizationEntriesMassDelete controller = new AmortizationEntriesMassDelete(stdController);

            controller.validateSelectedRecords();
            System.assertEquals(true, controller.showDeleteButton);

            controller.deleteRecords();

            System.assertEquals(false, controller.showDeleteButton);
            System.assertEquals(AmortizationEntriesMassDelete.CONFIRMATION_MESSAGE, ApexPages.getMessages()[0].getDetail());
            //check record has been deleted
            System.assertEquals(0, [SELECT count() FROM Scheduled_Revenue_Expense__c WHERE Id = :testAmortizationEntry2.Id]);
        }
    }

}