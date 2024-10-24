@IsTest
private class BankTransactionActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testPreventUpdateBankTransaction() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankTransactions();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Bank_Transaction__c testBT = testData.bankTransactions.get(0);
            DmlException dmlEx;
            try {
                testBT.Status__c = BankTransactionsHelper.BT_ADDED_STATUS;
                update testBT;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(BankTransactionActions.BT_UPDATE_DML_RESTRICTION_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testBypassPreventUpdateBankTransaction() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankTransactions();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Bank_Transaction__c testBT = testData.bankTransactions.get(0);
            DmlException dmlEx;
            try {
                testBT.Status__c = BankTransactionsHelper.BT_ADDED_STATUS;
                BankTransactionActions.isDmlRestrictionBypassEnabled = true;
                update testBT;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);
        }
    }
}