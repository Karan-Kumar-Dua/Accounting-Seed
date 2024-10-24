public with sharing class CashDisbursementLDVUnpostBatch extends SourceDocumentBatchBase {
    public CashDisbursementLDVUnpostBatch(SourceDocumentBatchOptions options){
        super(Cash_Disbursement__c.getSObjectType(), options);
        this.options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.UNPOST);
    }

    public CashDisbursementLDVUnpostBatch(Set<Id> billingIds) {
        super(Cash_Disbursement__c.getSObjectType(), new SourceDocumentBatchOptions(billingIds));
        options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.UNPOST);
    }

    public CashDisbursementLDVUnpostBatch() {
        super(Cash_Disbursement__c.getSObjectType(), new SourceDocumentBatchOptions(SourceDocumentBatchOptions.ExecutionContext.UNPOST, Cash_Disbursement__c.getSObjectType()));
        options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.UNPOST);
    }

    public override void callNextBatch(){
        Database.executeBatch(new CashDisbursementLDVUnpostBatch(this.options));
    }

    public override List<PostResult> processSourceDocumentData(List<LDVPostInput> scope){
        return new CashDisbursementPostHandler().unpost(scope);
    }
}