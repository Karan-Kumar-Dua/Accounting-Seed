public with sharing class JournalEntryLDVPostBatch extends SourceDocumentBatchBase {

    public JournalEntryLDVPostBatch(SourceDocumentBatchOptions options){
        super(Journal_Entry__c.getSObjectType(), options);
        this.options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.POST);
    }

    public JournalEntryLDVPostBatch(Set<Id> jeIds) {
        super(Journal_Entry__c.getSObjectType(), new SourceDocumentBatchOptions(jeIds));
        options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.POST);
    }

    public JournalEntryLDVPostBatch() {
        super(Journal_Entry__c.getSObjectType(), new SourceDocumentBatchOptions(SourceDocumentBatchOptions.ExecutionContext.POST, Journal_Entry__c.getSObjectType()));
        options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.POST);
    }

    public override void callNextBatch(){
        Set<Id> newCurrentContextSourceIds = new Set<Id>();
        for (Sobject obj : DomainUtils.getJournalEntryById(this.options.getCurrentContextSourceIds())) {

            Id ledgerId = (Id)SourceDocumentBatchHelper.fetchRecordValue(obj, new List<Schema.SObjectField>{ Journal_Entry__c.Ledger__c });
            if (LedgerHandler.getInstanceWithoutSharing().getLedgerById(ledgerId).Accounting_Method__c == LedgerActions.ACCOUNTING_METHOD_CASH) {
                newCurrentContextSourceIds.add(obj.Id);
            }
        }

        this.options.removeFailed(this.scopeState.getFailed());
        this.options.setCurrentContextSourceIds(newCurrentContextSourceIds);

        if (!this.options.getCurrentContextSourceIds().isEmpty() || this.isScheduledPostJob) {
            JournalEntryLDVPostBatch jeBatch = new JournalEntryLDVPostBatch(this.options);
            jeBatch.ajrId(this.ajrId);
            if (this.isScheduledPostJob) {
                jeBatch.isScheduledPostJob(this.isScheduledPostJob)
                    .currentSourceRecordType(this.currentSourceRecordType)
                    .schedSourceRecordTypes(this.schedSourceRecordTypes);
            }
            Database.executeBatch(jeBatch);
        } else {
            processAutomatedJobResults();
        }
    }

    public override List<PostResult> processSourceDocumentData(List<LDVPostInput> scope){
        return accrualAndCashPost(scope);
    }

    private List<PostResult> accrualAndCashPost(List<LDVPostInput> scope) {
        JournalEntryPostHandler jeph = new JournalEntryPostHandler();
        List<PostResult> resultsForProcess = new List<PostResult>();
        List<PostResult> results = jeph.post(scope);

        for (PostResult res : results) {
            if (res.isSuccess) {
                resultsForProcess.add(res);
            }
        }
        if (!resultsForProcess.isEmpty()) {
            jeph.processLDVPostJETransaction(resultsForProcess);
        }
        return results;
    }

}