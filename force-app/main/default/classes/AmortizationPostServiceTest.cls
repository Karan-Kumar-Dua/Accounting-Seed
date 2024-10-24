@IsTest
private class AmortizationPostServiceTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testAPIPosting() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            Scheduled_Revenue_Expense__c testSRE = testData.scheduledRevenues[0];

            Scheduled_Revenue_Expense__c newTestSRE = new Scheduled_Revenue_Expense__c(
                Name = 'Test Rev 5',
                Amount__c = 200,
                Credit_GL_Account__c = testData.glAccounts[11].Id,
                Debit_GL_Account__c = testData.glAccounts[16].Id,
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Status__c = 'Scheduled'
            );
            insert newTestSRE;

            List<PostResult> results = AmortizationPostService.unpostAmortizationEntries(
                new List<Scheduled_Revenue_Expense__c>{testSRE, newTestSRE}
            );

            System.assertEquals(true, results[0].isSuccess);
            System.assertEquals(true, results[1].isSuccess);

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];

            Test.startTest();
            results = AmortizationPostService.postAmortizationEntries(
                new List<Scheduled_Revenue_Expense__c>{testSRE, newTestSRE}
            );
            Test.stopTest();

            System.assertEquals(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD, results[0].errors[0].statusCode);
            System.assertEquals(
                1, [
                SELECT count()
                FROM Scheduled_Revenue_Expense__c
                WHERE Status__c = :AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED
                AND (Id = :testSRE.Id OR Id = :newTestSRE.Id)
            ]);
        }

    }


}