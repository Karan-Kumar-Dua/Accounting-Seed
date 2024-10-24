@IsTest
private class AbstractSourceFromRecurringTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testSetNextDateByFrequency() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables();

        System.runAs(testData.users.get(1)) {
            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.recurringPayables);
            AccountPayableFromRecrAccountPayable ara = new AccountPayableFromRecrAccountPayable(setController);

            System.assertEquals(
                Date.newInstance(2012, 1, 15),
                ara.setNextDateByFrequency('Bi-weekly', Date.newInstance(2012, 1, 1))
            );

            System.assertEquals(
                Date.newInstance(2012, 2, 1),
                ara.setNextDateByFrequency('Monthly', Date.newInstance(2012, 1, 1))
            );

            System.assertEquals(
                Date.newInstance(2012, 4, 1),
                ara.setNextDateByFrequency('Quarterly', Date.newInstance(2012, 1, 1))
            );

            System.assertEquals(
                Date.newInstance(2012, 7, 1),
                ara.setNextDateByFrequency('Semi-annual', Date.newInstance(2012, 1, 1))
            );

            System.assertEquals(
                Date.newInstance(2013, 1, 1),
                ara.setNextDateByFrequency('Annual', Date.newInstance(2012, 1, 1))
            );
        }
    }

    @isTest
    private static void testCalculateResultStatistic() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables();

        System.runAs(testData.users.get(1)) {
            AbstractSourceFromRecurring.RecurringRecordResult result = new AbstractSourceFromRecurring.RecurringRecordResult('Payable', testData.recurringPayables[0].Id);
            result.totalRecords = 5;
            result.errors.add(new AbstractSourceFromRecurring.RecurringRecordErrorResult(
                AbstractSourceFromRecurring.StatusCode.CREATED,
                'Success'
            ));

            result.errors.add(new AbstractSourceFromRecurring.RecurringRecordErrorResult(
                AbstractSourceFromRecurring.StatusCode.CREATED,
                'Success'
            ));

            result.errors.add(new AbstractSourceFromRecurring.RecurringRecordErrorResult(
                AbstractSourceFromRecurring.StatusCode.CREATED,
                'Success'
            ));

            result.errors.add(new AbstractSourceFromRecurring.RecurringRecordErrorResult(
            AbstractSourceFromRecurring.StatusCode.POST_ERROR,
            'Post Error'
            ));

            result.errors.add(new AbstractSourceFromRecurring.RecurringRecordErrorResult(
                AbstractSourceFromRecurring.StatusCode.ACCOUNTING_PERIOD_ERROR,
                'Error'
            ));

            result.errors.add(new AbstractSourceFromRecurring.RecurringRecordErrorResult(
                AbstractSourceFromRecurring.StatusCode.EXTERNAL_ERROR,
                'Error'
            ));

            System.assertEquals(3, result.getSuccessRecordsCount());
            System.assertEquals(2, result.getPostedRecordsCount());
            System.assertEquals(2, result.getFailedRecordsCount());

        }
    }

}