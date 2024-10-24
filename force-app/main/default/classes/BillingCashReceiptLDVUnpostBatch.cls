public with sharing class BillingCashReceiptLDVUnpostBatch extends SourceDocumentBatchBase {
    public BillingCashReceiptLDVUnpostBatch(SourceDocumentBatchOptions options){
        super(Billing__c.getSObjectType(), options);
        this.options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.UNPOST);
        masterSObjectType = Billing_Cash_Receipt__c.getSObjectType();
    }

    public BillingCashReceiptLDVUnpostBatch(Set<Id> recordIds) {
        super(Billing__c.getSObjectType(), new SourceDocumentBatchOptions(recordIds));
        options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.UNPOST);
        this.options.addMasterRecordIds(recordIds);
        masterSObjectType = Billing_Cash_Receipt__c.getSObjectType();
    }

    public BillingCashReceiptLDVUnpostBatch() {
        super(Billing__c.getSObjectType(), new SourceDocumentBatchOptions(SourceDocumentBatchOptions.ExecutionContext.UNPOST, Billing_Cash_Receipt__c.getSObjectType()));
        options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.UNPOST);
        masterSObjectType = Billing_Cash_Receipt__c.getSObjectType();
    }

    public override void callNextBatch(){
        Database.executeBatch(new BillingCashReceiptLDVUnpostBatch(this.options));
    }

    public override List<PostResult> processSourceDocumentData(List<LDVPostInput> scope){
        init(this.options.getMasterRecordIds(), scope);
        return accrualAndCashUnpost(scope);
    }

    private List<PostResult> accrualAndCashUnpost(List<LDVPostInput> scope) {
        List<Id> bcrForDelete = new List<Id>();
        BillingCashReceiptPostHandler bph = new BillingCashReceiptPostHandler();
        List<PostResult> results = bph.unpost(scope);
        for (PostResult res : results) {
            if (res.isSuccess) {
                if (res.transactionGroup.Line_Count__c == res.transactionGroup.Lines_Processed__c) {
                    this.options.removeMasterRecordId(res.id);
                    bcrForDelete.add(res.id);
                }
            }
        }
        if (!bcrForDelete.isEmpty()) {
            deleteUnpostedBCR(bcrForDelete);
        }
        return results;
    }

    private void init(Set<Id> recordIds, List<LDVPostInput> scope) {
        Set<Id> outstandingBCRIds = new Set<Id>();
        Map<Id, List<Billing_Cash_Receipt__c>> bcrMap = new Map<Id, List<Billing_Cash_Receipt__c>>();
        for (Billing_Cash_Receipt__c bcr : DomainUtils.getBillingCashReceiptsByIdOrderByPeriod(recordIds)) {
            if (!bcrMap.containsKey(bcr.Billing__c)) {
                bcrMap.put(bcr.Billing__c, new List<Billing_Cash_Receipt__c> {bcr});
            } else {
                if (bcrMap.get(bcr.Billing__c)[bcrMap.get(bcr.Billing__c).size() - 1].Accounting_Period__c == bcr.Accounting_Period__c) {
                    bcrMap.get(bcr.Billing__c).add(bcr);
                } else {
                    outstandingBCRIds.add(bcr.Id);
                }
            }
        }

        for (LDVPostInput input : scope) {
            if (bcrMap.containsKey(input.id)) {
                input.relatedObjects = bcrMap.get(input.id);
            }
        }

        this.options.addMasterRecordIds(outstandingBCRIds);
    }

    private void deleteUnpostedBCR(List<Id> bcrForDelete) {
        try {
            SFDCSecurityUtils.deleteProxy(bcrForDelete);
        } catch (Exception e) {}
    }
}