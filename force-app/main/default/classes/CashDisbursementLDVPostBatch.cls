public with sharing class CashDisbursementLDVPostBatch extends SourceDocumentBatchBase {
    public CashDisbursementLDVPostBatch(SourceDocumentBatchOptions options){
        super(Cash_Disbursement__c.getSObjectType(), options);
        this.options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.POST);
    }

    public CashDisbursementLDVPostBatch(Set<Id> recordIds) {
        super(Cash_Disbursement__c.getSObjectType(), new SourceDocumentBatchOptions(recordIds));
        options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.POST);
    }

    public CashDisbursementLDVPostBatch() {
        super(Cash_Disbursement__c.getSObjectType(), new SourceDocumentBatchOptions(SourceDocumentBatchOptions.ExecutionContext.POST, Cash_Disbursement__c.getSObjectType()));
        options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.POST);
    }

    public override void callNextBatch(){
        Database.executeBatch(new CashDisbursementLDVPostBatch(this.options));
    }

    public override List<PostResult> processSourceDocumentData(List<LDVPostInput> scope){
        return new CashDisbursementPostHandler().post(scope);
    }
}