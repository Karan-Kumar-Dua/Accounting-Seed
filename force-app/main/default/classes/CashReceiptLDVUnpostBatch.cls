public with sharing class CashReceiptLDVUnpostBatch extends SourceDocumentBatchBase {
    public CashReceiptLDVUnpostBatch(SourceDocumentBatchOptions options){
        super(Cash_Receipt__c.getSObjectType(), options);
        this.options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.UNPOST);
    }

    public CashReceiptLDVUnpostBatch(Set<Id> cashReceiptIds) {
        super(Cash_Receipt__c.getSObjectType(), new SourceDocumentBatchOptions(cashReceiptIds));
        options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.UNPOST);
    }

    public CashReceiptLDVUnpostBatch() {
        super(Cash_Receipt__c.getSObjectType(), new SourceDocumentBatchOptions(SourceDocumentBatchOptions.ExecutionContext.UNPOST, Cash_Receipt__c.getSObjectType()));
        options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.UNPOST);
    }

    public override void callNextBatch(){
        Database.executeBatch(new CashReceiptLDVUnpostBatch(this.options));
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
        return new CashReceiptPostHandler().unpost(scope);
    }

    private List<PostResult> cashUnpost(List<LDVPostInput> scope) {
        return new List<PostResult>();
    }

}