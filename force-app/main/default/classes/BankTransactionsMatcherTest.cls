@IsTest
private class BankTransactionsMatcherTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testSearchMatchingCashReceiptSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankTransactions()
            .setCashInDefaultMatchingSetting(5);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            BankTransactionsMatcher matcher = new BankTransactionsMatcher(testData.bankTransactions, BankTransactionsMatcher.ExecutionContext.APEX_JOB);
            matcher.searchMatchingRecords();
            System.assertEquals(true, matcher.hasMatchingRecords(testData.bankTransactions.get(0).Id));
        }

    }

    @IsTest
    private static void testSearchMatchingCashDisbursementSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createBankTransactions()
            .setCashOutDefaultMatchingSetting(1);

        System.runAs(testData.users.get(1)) {
            //update CDs to have applicable amounts
            List<Cash_Disbursement__c> testCDs = [
                SELECT Id, Amount__c
                FROM Cash_Disbursement__c
                WHERE Bank_Account__c = :testData.glAccounts.get(0).Id
            ];
            for (Cash_Disbursement__c cd : testCDs) {
                cd.Amount__c = testData.bankTransactions.get(1).Amount__c;
            }
            update testCDs;

            Test.startTest();
            BankTransactionsMatcher matcher = new BankTransactionsMatcher(testData.bankTransactions, BankTransactionsMatcher.ExecutionContext.APEX_JOB);
            matcher.searchMatchingRecords();
            System.assertEquals(true, matcher.hasMatchingRecords(testData.bankTransactions.get(1).Id));
            System.assertEquals(4, matcher.getMatchingRecords(testData.bankTransactions.get(1).Id).size());
        }

    }

    @IsTest
    private static void testSearchMatchingVoidCashDisbursement() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createBankTransactions()
            .setCashOutDefaultMatchingSetting(1);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            //Create Cash Disbursement
            Cash_Disbursement__c testCD = new Cash_Disbursement__c(
                Cash_Disbursement_Batch__c = testData.cashDisbursementBatch[0].Id,
                Disbursement_Date__c = testData.acctPeriods[0].Start_Date__c,
                Type__c = 'Check',
                Amount__c = testData.bankTransactions.get(1).Amount__c,
                Source__c = 'Manual',
                Bank_Account__c = testData.glAccounts[0].Id,
                Debit_GL_Account__c = testData.glAccounts[4].Id,
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Status__c = 'Approved',
                Reference__c = 'the reference 0',
                Ledger__c = testData.ledgers[0].Id
            );
            insert testCD;

            //Find match - expected: testCD is found as matching record
            BankTransactionsMatcher matcher = new BankTransactionsMatcher(
                testData.bankTransactions,
                BankTransactionsMatcher.ExecutionContext.APEX_JOB
            );
            matcher.searchMatchingRecords();
            System.assertEquals(true, matcher.hasMatchingRecords(testData.bankTransactions.get(1).Id));
            System.assertEquals(1, matcher.getMatchingRecords(testData.bankTransactions.get(1).Id).size());

            //Post this CD
            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Cash_Disbursement__c>{testCD});
            System.assertEquals(true, postResults[0].isSuccess);
            System.assertEquals(2, [
                SELECT count() FROM Transaction__c WHERE Cash_Disbursement__c = :testCD.Id
            ]);// +1 discount line

            //Void the CD
            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT
                    Id,
                    Status__c,
                    Disbursement_Date__c,
                    Payment_Status__c,
                    Accounting_Period__r.Status__c,
                    Type__c,
                    Bank_Account__c,
                    Amount__c,
                    Vendor__c
                FROM Cash_Disbursement__c
                WHERE Id = :testCD.Id
            ]);

            CashDisbursementVoid cdv = new CashDisbursementVoid(controller);
            cdv.cashDisbursementVoid.Void_Description__c = 'Void Reason';
            cdv.cashDisbursementVoid.Disbursement_Date__c = cdv.cashDisbursement.Disbursement_Date__c;
            cdv.voidCashDisbursement();

            System.assertEquals(4, [SELECT count() FROM Transaction__c WHERE Cash_Disbursement__c = :testCD.Id]);
            System.assertEquals(
                'Void',
                [SELECT Payment_Status__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id].Payment_Status__c
            );

            //Find match - expected: testCD is not treated as matching b/c it has been Voided
            matcher = new BankTransactionsMatcher(
                testData.bankTransactions,
                BankTransactionsMatcher.ExecutionContext.APEX_JOB
            );
            matcher.searchMatchingRecords();
            System.assertEquals(false, matcher.hasMatchingRecords(testData.bankTransactions.get(1).Id));
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
            .setCashOutDefaultMatchingSetting(10);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            BankTransactionsMatcher matcher = new BankTransactionsMatcher(testData.bankTransactions, BankTransactionsMatcher.ExecutionContext.UI);
            matcher.searchMatchingRecords();
            //no matching records expected because of Date value on Journal Entries
            System.assertEquals(false, matcher.hasMatchingRecords(testData.bankTransactions.get(1).Id));
            //Update Date to fit criteria
            testData.journalEntries[0].Journal_Date__c = testData.acctPeriods[0].Start_Date__c.addDays(11);//not within applicable date range (+-10)
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

            matcher = new BankTransactionsMatcher(
                testData.bankTransactions,
                BankTransactionsMatcher.ExecutionContext.APEX_JOB
            );
            matcher.searchMatchingRecords();
            System.assertEquals(true, matcher.hasMatchingRecords(testData.bankTransactions.get(1).Id));
            System.assertEquals(testData.journalEntryLines[0].Id, matcher.getMatchingRecords(testData.bankTransactions.get(1).Id)[0].Id);
        }

    }


}