@IsTest
private class AccountUpdateStatementStatusBatchTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testBatchExecution() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users[1]) {
            Set<Id> accountIds = new Set<Id>();
            for (Account acc : testData.accounts) {
                accountIds.add(acc.Id);
            }

            Test.startTest();
            AccountUpdateStatementStatusBatch aub = new AccountUpdateStatementStatusBatch(accountIds);
            Database.executeBatch(aub);
            Test.stopTest();
            System.assertEquals(
                'Yes', [
                    SELECT Id, Statement_Needed__c
                    FROM Account
                    WHERE Id = :testData.accounts[0].Id
                ].Statement_Needed__c
            );
        }
    }

}