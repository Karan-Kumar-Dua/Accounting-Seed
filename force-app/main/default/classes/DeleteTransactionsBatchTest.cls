@IsTest
private class DeleteTransactionsBatchTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testDeleteTransactionAndTGObject() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Id batchId = FinancialSuiteUtils.getFakeId(Billing__c.SObjectType);

            Transaction_Group__c tg = new Transaction_Group__c();
            tg.Lines_Processed__c = 1;
            tg.Batch_Id__c = batchId;
            tg.Billing__c = testData.billings[0].Id;
            tg.Line_Count__c = 2;
            tg.Ledger__c = testData.ledgers[0].Id;

            insert tg;

            new PostProcessor().setPostingStatusInProgress(
                new List<Id> {testData.billings[0].Id},
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED
            );

            Billing__c bill = [SELECT Id, Status__c FROM Billing__c WHERE Id = :testData.billings[0].Id];
            System.assertEquals('Approved', bill.Status__c);

            List<Transaction__c> trans = [SELECT Id, Billing__c FROM Transaction__c WHERE Billing__c = :testData.billings[0].Id];
            System.assert(!trans.isEmpty());

            Database.executeBatch(new DeleteTransactionsBatch(batchId, Billing__c.SObjectType), 200);
            Test.stopTest();

            List<Transaction_Group__c> tgList = [SELECT Id FROM Transaction_Group__c];

            System.assert(tgList.isEmpty());
            List<Transaction__c> transAfter = [SELECT Id, Billing__c FROM Transaction__c WHERE Billing__c = :testData.billings[0].Id];
            System.assert(transAfter.isEmpty());
        }
    }
}