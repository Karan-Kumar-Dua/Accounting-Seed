public with sharing class CashReceiptLDVPostBatch extends SourceDocumentBatchBase {

    public CashReceiptLDVPostBatch(SourceDocumentBatchOptions options){
        super(Cash_Receipt__c.getSObjectType(), options);
        this.options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.POST);
    }

    public CashReceiptLDVPostBatch(Set<Id> cashReceiptIds) {
        super(Cash_Receipt__c.getSObjectType(), new SourceDocumentBatchOptions(cashReceiptIds));
        options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.POST);
    }

    public CashReceiptLDVPostBatch() {
        super(Cash_Receipt__c.getSObjectType(), new SourceDocumentBatchOptions(SourceDocumentBatchOptions.ExecutionContext.POST, Cash_Receipt__c.getSObjectType()));
        options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.POST);
    }

    public override void callNextBatch(){
        Database.executeBatch(new CashReceiptLDVPostBatch(this.options));
    }

    public override List<PostResult> processSourceDocumentData(List<LDVPostInput> scope){
        List<PostResult> results = new List<PostResult>();
        if (this.options.currentAccountingMethod() == SourceDocumentBatchOptions.AccountingMethod.CASH) {
            results = cashPost(scope);
        }
        else {
            results = accrualPost(scope);
        }
        return results;
    }

    private List<PostResult> accrualPost(List<LDVPostInput> scope) {
        return new CashReceiptPostHandler().post(scope);
    }

    private List<PostResult> cashPost(List<LDVPostInput> scope) {
        return new List<PostResult>();
    }

}