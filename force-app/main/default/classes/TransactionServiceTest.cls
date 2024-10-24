@IsTest
public class TransactionServiceTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testCreateTransactionsAuthorizationError() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.journalEntries[0].Status__c = 'Approved';
            update testData.journalEntries[0];

            ApexPages.Standardcontroller controller = new ApexPages.Standardcontroller([
                SELECT  Id,
                        Total_Credits__c,
                        Total_Debits__c,
                        Status__c,
                        Journal_Date__c,
                        Accounting_Period__c,
                        Accounting_Period__r.Status__c
                FROM Journal_Entry__c
                WHERE Id = :testData.journalEntries[0].Id
            ]);

            JournalEntryPost jep = new JournalEntryPost(controller);
            jep.post();

            List<Transaction__c> transList = new List<Transaction__c>();

            for (Transaction__c tran : [SELECT  Id,
                                                Date__c,
                                                Amount__c,
                                                GL_Account__c,
                                                Journal_Entry_Line__c,
                                                Accounting_Period__c
                                        FROM Transaction__c
                                        WHERE Journal_Entry_Line__r.Journal_Entry__c = :testData.journalEntries[0].Id]) {

                transList.add(tran.clone(false, true));
            }
            System.assertEquals(
                2, [
                    SELECT count()
                    FROM Transaction__c
                    WHERE Journal_Entry_Line__r.Journal_Entry__c = :testData.journalEntries[0].Id
                ]
            );

            String authKey = 'grumpy';

            Exception ex;
            try {
                TransactionService.createTransactions(transList, authKey);
            }
            catch (TransactionService.TransactionServiceAuthorizationException tex) {
                ex = tex;
            }

            System.assertEquals(TransactionService.AUTHORIZATION_ERROR, ex.getMessage());
        }

    }

    @IsTest
    public static void testCreateTransactionsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.journalEntries[0].Status__c = 'Approved';
            update testData.journalEntries[0];

            ApexPages.Standardcontroller controller = new ApexPages.Standardcontroller([
                SELECT  Id,
                        Total_Credits__c,
                        Total_Debits__c,
                        Status__c,
                        Journal_Date__c,
                        Accounting_Period__c,
                        Accounting_Period__r.Status__c
                FROM Journal_Entry__c
                WHERE Id = :testData.journalEntries[0].Id
            ]);

            JournalEntryPost jep = new JournalEntryPost(controller);
            jep.post();

            List<Transaction__c> transList = new List<Transaction__c>();
            for (Transaction__c tran : [SELECT  Id,
                                                Date__c,
                                                Amount__c,
                                                GL_Account__c,
                                                Journal_Entry_Line__c,
                                                Accounting_Period__c,
                                                Ledger__c,
                                                Foreign_Amount__c
                                        FROM Transaction__c
                                        WHERE Journal_Entry_Line__r.Journal_Entry__c = :testData.journalEntries[0].Id]) {

                transList.add(tran.clone(false, true));
            }

            System.assertEquals(
                2, [
                    SELECT count()
                    FROM Transaction__c
                    WHERE Journal_Entry_Line__r.Journal_Entry__c = :testData.journalEntries[0].Id
                ]
            );

            String authKey = EncodingUtil.base64Encode(
                Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.TRANSACTION_CREATE_KEY))
            );
            TransactionService.createTransactions(transList, authKey);

            System.assertEquals(
                4, [
                    SELECT count()
                    FROM Transaction__c
                    WHERE Journal_Entry_Line__r.Journal_Entry__c = :testData.journalEntries[0].Id
                ]
            );
        }

    }

    @IsTest    
    public static void testDeleteTransactionsAuthorizationError() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.journalEntries[0].Status__c = 'Approved';
            update testData.journalEntries[0];

            ApexPages.Standardcontroller controller = new ApexPages.Standardcontroller([
                SELECT  Id,
                        Total_Credits__c,
                        Total_Debits__c,
                        Status__c,
                        Journal_Date__c,
                        Accounting_Period__c,
                        Accounting_Period__r.Status__c
                FROM Journal_Entry__c
                WHERE Id = :testData.journalEntries[0].Id
            ]);

            JournalEntryPost jep = new JournalEntryPost(controller);
            jep.post();

            List<Transaction__c> transList = [
                SELECT  Id,
                        Date__c,
                        Amount__c,
                        GL_Account__c,
                        Journal_Entry_Line__c,
                        Accounting_Period__c
                FROM Transaction__c
                WHERE Journal_Entry_Line__r.Journal_Entry__c = :testData.journalEntries[0].Id
            ];

            System.assertEquals(
                2, [
                    SELECT count()
                    FROM Transaction__c
                    WHERE Journal_Entry_Line__r.Journal_Entry__c = :testData.journalEntries[0].Id
                ]
            );

            String authKey = 'stumpy';

            Exception ex;
            try {
                TransactionService.deleteTransactions(transList, authKey);
            }
            catch (TransactionService.TransactionServiceAuthorizationException tex) {
                ex = tex;
            }

            System.assertEquals(TransactionService.AUTHORIZATION_ERROR, ex.getMessage());
        }

    }

    @IsTest    
    public static void testDeleteTransactionsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.journalEntries[0].Status__c = 'Approved';
            update testData.journalEntries[0];

            ApexPages.Standardcontroller controller = new ApexPages.Standardcontroller([
                SELECT  Id,
                        Total_Credits__c,
                        Total_Debits__c,
                        Status__c,
                        Journal_Date__c,
                        Accounting_Period__c,
                        Accounting_Period__r.Status__c
                FROM Journal_Entry__c
                WHERE Id = :testData.journalEntries[0].Id
            ]);

            JournalEntryPost jep = new JournalEntryPost(controller);
            jep.post();

            List<Transaction__c> transList = [
                SELECT  Id,
                        Date__c,
                        Amount__c,
                        GL_Account__c,
                        Journal_Entry_Line__c,
                        Accounting_Period__c
                FROM Transaction__c
                WHERE Journal_Entry_Line__r.Journal_Entry__c = :testData.journalEntries[0].Id
            ];

            System.assertEquals(
                2, [
                    SELECT count()
                    FROM Transaction__c
                    WHERE Journal_Entry_Line__r.Journal_Entry__c = :testData.journalEntries[0].Id
                ]
            );

            String authKey = EncodingUtil.base64Encode(
                Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.TRANSACTION_UPDATE_DELETE_KEY))
            );
            TransactionService.deleteTransactions(transList, authKey);

            System.assertEquals(
                0, [
                    SELECT count()
                    FROM Transaction__c
                    WHERE Journal_Entry_Line__r.Journal_Entry__c = :testData.journalEntries[0].Id
                ]
            );
        }
    }

}