public with sharing class JournalEntryLDVUnpostBatch extends SourceDocumentBatchBase {

    public JournalEntryLDVUnpostBatch(SourceDocumentBatchOptions options){
        super(Journal_Entry__c.getSObjectType(), options);
        this.options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.UNPOST);
    }

    public JournalEntryLDVUnpostBatch(Set<Id> jeIds) {
        super(Journal_Entry__c.getSObjectType(), new SourceDocumentBatchOptions(jeIds));
        options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.UNPOST);
    }

    public JournalEntryLDVUnpostBatch() {
        super(Journal_Entry__c.getSObjectType(), new SourceDocumentBatchOptions(SourceDocumentBatchOptions.ExecutionContext.UNPOST, Journal_Entry__c.getSObjectType()));
        options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.UNPOST);
    }

    public override void callNextBatch(){
        Database.executeBatch((new JournalEntryLDVUnpostBatch(this.options)).ajrId(this.ajrId));
    }

    public override List<PostResult> processSourceDocumentData(List<LDVPostInput> scope){
        return accrualAndCashUnpost(scope);
    }

    private List<PostResult> accrualAndCashUnpost(List<LDVPostInput> scope) {
        JournalEntryPostHandler jeph = new JournalEntryPostHandler();
        List<PostResult> resultsForProcess = new List<PostResult>();
        List<PostResult> results = jeph.unpost(scope);

        for (PostResult res : results) {
            if (res.isSuccess) {
                resultsForProcess.add(res);
            }
        }
        if (!resultsForProcess.isEmpty()) {
            jeph.processLDVUnpostJETransactions(resultsForProcess);
        }
        return results;
    }
}