@IsTest
private class JournalEntryArchiveDeleteBatchTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    
    @IsTest
    private static void testJournalEntryJob() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();
        
        System.runAs(testData.users[1]) {
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
            //Run batch job to delete journalEntry Records.
            AbstractArchiveDeleteBatch.executeBatchChain(new AbstractArchiveDeleteBatch.ArchiveDeleteChainController(testData.acctPeriods[0].Id), null);
            Test.stopTest();
            
            //Make sure journalEntry Records deleted.
            System.assertEquals(
                1, [
                    SELECT Id FROM Journal_Entry__c 
                ].size() 
            );      
        }
    }
}