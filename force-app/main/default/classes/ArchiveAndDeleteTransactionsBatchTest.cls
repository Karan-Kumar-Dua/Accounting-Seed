@IsTest
public class ArchiveAndDeleteTransactionsBatchTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testStartMethod() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            ArchiveAndDeleteTransactionsBatch batchInstance = new ArchiveAndDeleteTransactionsBatch(testData.acctPeriods[0]);
            Database.QueryLocatorIterator existedTransactions = batchInstance.start(NULL).iterator();

            System.assertEquals(true, existedTransactions.hasNext());
        }

    }

    @IsTest
    public static void testCloneTransaction() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            ArchiveAndDeleteTransactionsBatch batchInstance = new ArchiveAndDeleteTransactionsBatch(testData.acctPeriods[0]);
            List<Transaction__c> existedTransactions = (List<Transaction__c>) Database.query(batchInstance.transactionQuery);
            System.assertEquals(false, existedTransactions.isEmpty());
            List<SObject> archivedTransactions = batchInstance.cloneTransactions(existedTransactions);
            System.assertEquals(existedTransactions.size(), archivedTransactions.size());
            System.assertEquals(true, batchInstance.sanityCheck(existedTransactions, archivedTransactions));
        }

    }

    @IsTest
    public static void testFinishMethod() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            ArchiveAndDeleteTransactionsBatch batchInstance = new ArchiveAndDeleteTransactionsBatch(testData.acctPeriods[0]);
            batchInstance.finish(NULL);

            System.assertEquals(
                AccountingPeriodActions.ARCHIVED_STATUS,
                [SELECT Id, Status__c FROM Accounting_Period__c WHERE Id = :testData.acctPeriods[0].Id].Status__c
            );
        }
    }

}