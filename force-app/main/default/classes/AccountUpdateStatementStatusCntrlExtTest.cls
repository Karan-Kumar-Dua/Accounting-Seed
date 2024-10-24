@IsTest
private class AccountUpdateStatementStatusCntrlExtTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testRunAction() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users[1]) {

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.accounts);
            setController.setSelected(testData.accounts);
            AccountUpdateStatementStatusCntrlExt controller = new AccountUpdateStatementStatusCntrlExt(setController);
            controller.runAction();

            System.assertEquals(AccountUpdateStatementStatusCntrlExt.SUCCESS_MESSAGE, ApexPages.getMessages()[0].getSummary());
            }

        }

    @IsTest
    static void testNoSelected() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users[1]) {

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.accounts);
            AccountUpdateStatementStatusCntrlExt controller = new AccountUpdateStatementStatusCntrlExt(setController);
            controller.runAction();

            System.assertEquals(AccountUpdateStatementStatusCntrlExt.NO_RECORDS_SELECTED_ERROR, ApexPages.getMessages()[0].getSummary());
        }

    }

}