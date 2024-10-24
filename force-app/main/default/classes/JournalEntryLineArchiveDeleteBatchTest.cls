@IsTest
private class JournalEntryLineArchiveDeleteBatchTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    
    @IsTest
    private static void testJournalEntryLineJob() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();
        
        System.runAs(testData.users[1]) {
            //Check total journalEntryLines Records
            System.assertEquals(
                6, [
                    SELECT Id FROM Journal_Entry_Line__c
                ].size() 
            );

            List<Journal_Entry__c> selJE = [SELECT Id FROM Journal_Entry__c];
            //Check total journalEntry Records
            System.assertEquals(3, selJE.size());

            JournalEntryPostService.postJournalEntries(new List<Journal_Entry__c> {selJE[0], selJE[1]});
            List<Transaction__c> transactionList = [
                SELECT Id FROM Transaction__c WHERE Journal_Entry_Line__r.Journal_Entry__c =:selJE[0].Id OR Journal_Entry_Line__r.Journal_Entry__c =:selJE[1].Id]
            ;
            TransactionActions.isPreventDeleteOverride = true;
            delete transactionList;
            
            Test.startTest();
            //Run batch job to delete journalEntryLines Records.
            AbstractArchiveDeleteBatch.executeBatchChain(new AbstractArchiveDeleteBatch.ArchiveDeleteChainController(testData.acctPeriods[0].Id), null);
            Test.stopTest();
            
            //Make sure journalEntryLines Records deleted.
            System.assertEquals(
                2, [
                    SELECT Id FROM Journal_Entry_Line__c 
                ].size() 
            );      
        }
    }

    @IsTest
    private static void testJournalEntryLineJobPreventDeleteWithBRECAndBD() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries()
            .createBankDeposits()
            .createBankReconciliations();

        System.runAs(testData.users[1]) {
            //Check total journalEntryLines Records
            System.assertEquals(
                6, [
                    SELECT Id FROM Journal_Entry_Line__c
                ].size()
            );

            testData.bankReconciliations[0].End_Date__c = System.today().addDays(2);
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Bank_Reconciliation2__c.End_Date__c});
            update testData.bankReconciliations[0];

            testData.bankDeposits[0].Deposit_Date__c = System.today().addDays(2);
            update testData.bankDeposits[0];

            testData.journalEntryLines[0].Bank_Deposit__c = testData.bankDeposits[0].Id;
            testData.journalEntryLines[1].Bank_Reconciliation__c = testData.bankReconciliations[0].Id;

            TriggerObserver.getInstance().unlockField(Journal_Entry_Line__c.Bank_Deposit__c);
            TriggerObserver.getInstance().unlockField(Journal_Entry_Line__c.Bank_Reconciliation__c);
            update testData.journalEntryLines;
            TriggerObserver.purgeUnlockedFields(Journal_Entry_Line__c.Bank_Deposit__c);
            TriggerObserver.purgeUnlockedFields(Journal_Entry_Line__c.Bank_Reconciliation__c);

            List<Journal_Entry__c> selJE = [SELECT Id FROM Journal_Entry__c];
            //Check total journalEntry Records
            System.assertEquals(3, selJE.size());

            JournalEntryPostService.postJournalEntries(new List<Journal_Entry__c> {selJE[0], selJE[1]});
            List<Transaction__c> transactionList = [
                SELECT Id FROM Transaction__c WHERE Journal_Entry_Line__r.Journal_Entry__c =:selJE[0].Id OR Journal_Entry_Line__r.Journal_Entry__c =:selJE[1].Id]
            ;
            TransactionActions.isPreventDeleteOverride = true;
            delete transactionList;

            Test.startTest();
            //Run batch job to delete journalEntryLines Records.
            AbstractArchiveDeleteBatch.executeBatchChain(new AbstractArchiveDeleteBatch.ArchiveDeleteChainController(testData.acctPeriods[0].Id), null);
            Test.stopTest();

            //Make sure journalEntryLines Records deleted.
            System.assertEquals(
                4, [
                    SELECT Id FROM Journal_Entry_Line__c
                ].size()
            );

            System.assertEquals(2, [SELECT Id FROM Journal_Entry__c].size());
        }
    }
}