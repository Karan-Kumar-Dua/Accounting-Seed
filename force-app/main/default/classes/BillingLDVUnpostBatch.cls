public with sharing class BillingLDVUnpostBatch  extends SourceDocumentBatchBase {

    public BillingLDVUnpostBatch(SourceDocumentBatchOptions options){
        super(Billing__c.getSObjectType(), options);
        this.scopeState = AccountingSettingsHandler.isLineLevelPost() ? new BillingLDVPostBatch.BillingScopeState(this.headerSObjectType, this.parentRelationshipField) : this.scopeState;
        this.options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.UNPOST);
    }

    public BillingLDVUnpostBatch(Set<Id> billingIds) {
        super(Billing__c.getSObjectType(), new SourceDocumentBatchOptions(billingIds));
        this.scopeState = AccountingSettingsHandler.isLineLevelPost() ? new BillingLDVPostBatch.BillingScopeState(this.headerSObjectType, this.parentRelationshipField) : this.scopeState;
        options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.UNPOST);
    }

    public BillingLDVUnpostBatch() {
        super(Billing__c.getSObjectType(), new SourceDocumentBatchOptions(SourceDocumentBatchOptions.ExecutionContext.UNPOST, Billing__c.getSObjectType()));
        this.scopeState = AccountingSettingsHandler.isLineLevelPost() ? new BillingLDVPostBatch.BillingScopeState(this.headerSObjectType, this.parentRelationshipField) : this.scopeState;
        options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.UNPOST);
    }

    public override void execute(Database.BatchableContext ctx, List<SObject> scope) {
        this.scopeState = BillingLDVPostBatch.presetConfigurations(scope, this.scopeState);
        super.execute(ctx, scope);
    }

    public override void callNextBatch(){
        Database.executeBatch(new BillingLDVUnpostBatch(this.options));
    }

    public override List<PostResult> processSourceDocumentData(List<LDVPostInput> scope){
        List<PostResult> results = new List<PostResult>();
        if (this.options.currentAccountingMethod() == SourceDocumentBatchOptions.AccountingMethod.CASH) {
            results = cashUnpost(scope);
        }
        else {
            results = accrualUnpost(scope);
        }
        return results;
    }

    private List<PostResult> accrualUnpost(List<LDVPostInput> scope) {
        BillingPostHandler bph = new BillingPostHandler();
        List<PostResult> resultsForProcess = new List<PostResult>();
        List<PostResult> results = bph.unpost(scope);
        for (PostResult res : results) {
            if (res.isSuccess) {
                resultsForProcess.add(res);
            }
        }
        if (!resultsForProcess.isEmpty()) {
            BillingLineActions.isLDVSourceBatchInProgress = true;
            bph.processLDVUnpostBillingsTransactions(resultsForProcess);
            BillingLineActions.isLDVSourceBatchInProgress = false;
        }
        return results;
    }

    private List<PostResult> cashUnpost(List<LDVPostInput> scope) {
        return new BillingPostHandlerCash().unpost(scope);
    }

}