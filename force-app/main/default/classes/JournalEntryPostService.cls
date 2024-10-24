global with sharing class JournalEntryPostService {

    global static final Integer JOURNAL_ENTRY_LINE_COUNT_LIMIT = 1000;//not used; still there because of global qualifier

    global static List<PostResult> postJournalEntries(List<Journal_Entry__c> journalEntries) {
        AbstractPostHandler postHandler = new JournalEntryPostHandler();
        return postHandler.post(journalEntries);
    }    

    global static List<PostResult> unpostJournalEntries(List<Journal_Entry__c> journalEntries) {
        AbstractPostHandler postHandler = new JournalEntryPostHandler();
        return postHandler.unpost(journalEntries);
    } 

}