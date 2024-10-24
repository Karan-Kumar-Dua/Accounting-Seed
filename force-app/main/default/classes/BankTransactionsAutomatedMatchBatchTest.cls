@IsTest
private class BankTransactionsAutomatedMatchBatchTest {
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testSearchMatchingCashReceiptSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankTransactions()
            .setCashInDefaultMatchingSetting(5)
            .setGlobalAutomatedMatchEnabled();

        System.runAs(testData.users.get(1)) {
            BankTransactionsAutomatedMatchBatch batchInstance = new BankTransactionsAutomatedMatchBatch(testData.bankTransactions);
            Test.startTest();
            Database.executeBatch(batchInstance);
            Test.stopTest();

            //Query matched records
            List<Cash_Receipt__c> cashReceipts = [SELECT Id FROM Cash_Receipt__c WHERE Bank_Transaction__c IN :testData.bankTransactions];
            System.assertNotEquals(true, cashReceipts.isEmpty());
            List<Bank_Transaction__c> bts = [SELECT Id FROM Bank_Transaction__c WHERE Status__c = 'Matched'];
            System.assertNotEquals(true, bts.isEmpty());
        }

    }

    @IsTest
    private static void testSearchMatchingCashDisbursementSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createBankTransactions()
            .setCashOutDefaultMatchingSetting(1)
            .setGlobalAutomatedMatchEnabled();

        System.runAs(testData.users.get(1)) {
            BankTransactionsAutomatedMatchBatch batchInstance = new BankTransactionsAutomatedMatchBatch(testData.bankTransactions);

            Test.startTest();
            Database.executeBatch(batchInstance);
            Test.stopTest();

            //Query matched records
            List<Cash_Disbursement__c> cashDisbursements = [SELECT Id FROM Cash_Disbursement__c WHERE Bank_Transaction__c IN :testData.bankTransactions];
            System.assertNotEquals(true, cashDisbursements.isEmpty());
            List<Bank_Transaction__c> bts = [SELECT Id FROM Bank_Transaction__c WHERE Status__c = 'Matched'];
            System.assertNotEquals(true, bts.isEmpty());
        }

    }

    @IsTest
    private static void testSearchMatchingJournalEntryLineSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries()
            .createBankTransactions()
            .setCashInDefaultMatchingSetting(0)
            .setCashOutDefaultMatchingSetting(10)
            .setGlobalAutomatedMatchEnabled();

        System.runAs(testData.users.get(1)) {
            //Update Date to fit criteria
            testData.journalEntries[0].Journal_Date__c = testData.acctPeriods[0].Start_Date__c.addDays(11);
            update testData.journalEntries[0];
            List<Journal_Entry_Line__c> lines = [
                SELECT Id, Date__c
                FROM Journal_Entry_Line__c
                WHERE Journal_Entry__c = :testData.journalEntries[0].Id
            ];
            for (Journal_Entry_Line__c line : lines) {
                line.Date__c = testData.journalEntries[0].Journal_Date__c.addDays(-2);//within applicable date range (+-10)
            }
            update lines;

            BankTransactionsAutomatedMatchBatch batchInstance = new BankTransactionsAutomatedMatchBatch(testData.bankTransactions);

            Test.startTest();
            Database.executeBatch(batchInstance);
            Test.stopTest();

            //Query matched records
            List<Journal_Entry_Line__c> jels = [SELECT Id FROM Journal_Entry_Line__c WHERE Bank_Transaction__c IN :testData.bankTransactions];
            System.assertNotEquals(true, jels.isEmpty());
            List<Bank_Transaction__c> bts = [SELECT Id FROM Bank_Transaction__c WHERE Status__c = 'Matched'];
            System.assertNotEquals(true, bts.isEmpty());
        }

    }

}