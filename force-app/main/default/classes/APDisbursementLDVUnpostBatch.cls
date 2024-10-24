public with sharing class APDisbursementLDVUnpostBatch extends SourceDocumentBatchBase {
    public APDisbursementLDVUnpostBatch(SourceDocumentBatchOptions options){
        super(Account_Payable__c.getSObjectType(), options);
        this.options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.UNPOST);
        masterSObjectType = AP_Disbursement__c.getSObjectType();
    }

    public APDisbursementLDVUnpostBatch(Set<Id> payableIds) {
        super(Account_Payable__c.getSObjectType(), new SourceDocumentBatchOptions(payableIds));
        options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.UNPOST);
        this.options.addMasterRecordIds(payableIds);
        masterSObjectType = AP_Disbursement__c.getSObjectType();
    }

    public APDisbursementLDVUnpostBatch() {
        super(Account_Payable__c.getSObjectType(), new SourceDocumentBatchOptions(SourceDocumentBatchOptions.ExecutionContext.UNPOST, AP_Disbursement__c.getSObjectType()));
        options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.UNPOST);
        masterSObjectType = AP_Disbursement__c.getSObjectType();
    }

    public override void callNextBatch(){
        Database.executeBatch(new APDisbursementLDVUnpostBatch(this.options));
    }

    public override List<PostResult> processSourceDocumentData(List<LDVPostInput> scope){
        init(this.options.getMasterRecordIds(), scope);
        return accrualAndCashUnpost(scope);
    }

    private List<PostResult> accrualAndCashUnpost(List<LDVPostInput> scope) {
        List<Id> apdForDelete = new List<Id>();
        APDisbursementPostHandler aph = new APDisbursementPostHandler();
        List<PostResult> results = aph.unpost(scope);
        for (PostResult res : results) {
            if (res.isSuccess) {
                if (res.transactionGroup.Line_Count__c == res.transactionGroup.Lines_Processed__c) {
                    this.options.removeMasterRecordId(res.id);
                    apdForDelete.add(res.id);
                }
            }
        }
        if (!apdForDelete.isEmpty()) {
            deleteUnpostedAPD(apdForDelete);
        }
        return results;
    }

    private void init(Set<Id> recordIds, List<LDVPostInput> scope) {
        Set<Id> outstandingAPDIds = new Set<Id>();
        Map<Id, List<AP_Disbursement__c>> apdMap = new Map<Id, List<AP_Disbursement__c>>();
        for (AP_Disbursement__c apd : DomainUtils.getApDisbursementsByIdOrderByPeriod(recordIds)) {
            if (!apdMap.containsKey(apd.Account_Payable__c)) {
                apdMap.put(apd.Account_Payable__c, new List<AP_Disbursement__c> {apd});
            } else {
                if (apdMap.get(apd.Account_Payable__c)[apdMap.get(apd.Account_Payable__c).size() - 1].Accounting_Period__c == apd.Accounting_Period__c) {
                    apdMap.get(apd.Account_Payable__c).add(apd);
                } else {
                    outstandingAPDIds.add(apd.Id);
                }
            }
        }

        for (LDVPostInput input : scope) {
            if (apdMap.containsKey(input.id)) {
                input.relatedObjects = apdMap.get(input.id);
            }
        }

        this.options.addMasterRecordIds(outstandingAPDIds);
    }

    private void deleteUnpostedAPD(List<Id> apdForDelete) {
        try {
            SFDCSecurityUtils.deleteProxy(apdForDelete);
        } catch (Exception e) {}
    }
}