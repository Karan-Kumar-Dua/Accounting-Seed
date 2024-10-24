@IsTest
private class AccountingLimitHandlerTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testGetLedgerLimit() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Integer limitValue = AccountingLimitHandler.getInstance().getLimit(AccountingLimitHandler.LimitType.LEDGER_LIMIT);

            System.assertEquals(25, limitValue);
        }
    }

    @IsTest
    static void testGetArchivePeriodLimit() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Integer limitValue = AccountingLimitHandler.getInstance().getLimit(AccountingLimitHandler.LimitType.ARCHIVE_PERIOD_OFFSET);

            System.assertEquals(15, limitValue);
        }
    }

    @IsTest
    static void testSetLimit() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            AccountingLimitHandler limitHandler = AccountingLimitHandler.getInstance();
            System.assertEquals(25, limitHandler.getLimit(AccountingLimitHandler.LimitType.LEDGER_LIMIT));

            limitHandler.setLimit(AccountingLimitHandler.LimitType.LEDGER_LIMIT, 10);
            System.assertEquals(10, limitHandler.getLimit(AccountingLimitHandler.LimitType.LEDGER_LIMIT));
        }
    }
}