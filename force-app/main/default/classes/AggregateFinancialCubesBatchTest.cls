@IsTest
private class AggregateFinancialCubesBatchTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testAggregateYTDBalance() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createBillings(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            GLAccountBalanceOption options = new GLAccountBalanceOption();
            options.inquiryDate = Date.today();
            options.requestId = 'my_request';
            options.ledgerId = testData.ledgers[0].Id;
            options.glAccountId = testData.glAccounts[10].Id;
            Date startDate = testData.acctPeriods[0].Start_Date__c;

            AggregateFinancialCubesBatch ytdAggregator = new AggregateFinancialCubesBatch(
                options, testData.acctPeriods[0], startDate);
            Database.executeBatch(ytdAggregator, 2000);

            Test.stopTest();
        }
    }
}