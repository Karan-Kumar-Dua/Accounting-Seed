public with sharing class AccountPayableLDVPostBatch extends SourceDocumentBatchBase {
    public AccountPayableLDVPostBatch(SourceDocumentBatchOptions options){
        super(Account_Payable__c.getSObjectType(), options);
        this.options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.POST);
    }

    public AccountPayableLDVPostBatch(Set<Id> payableIds) {
        super(Account_Payable__c.getSObjectType(), new SourceDocumentBatchOptions(payableIds));
        options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.POST);
    }

    public AccountPayableLDVPostBatch() {
        super(Account_Payable__c.getSObjectType(), new SourceDocumentBatchOptions(SourceDocumentBatchOptions.ExecutionContext.POST, Account_Payable__c.getSObjectType()));
        options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.POST);
    }

    public override void callNextBatch(){
        Database.executeBatch(new AccountPayableLDVPostBatch(this.options));
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
        AccountPayablePostHandler postHandler = new AccountPayablePostHandler();
        List<PostResult> resultsForProcess = new List<PostResult>();
        List<PostResult> results = postHandler.post(scope);
        for (PostResult res : results) {
            if (res.isSuccess) {
                resultsForProcess.add(res);
            }
        }
        if (!resultsForProcess.isEmpty()) {
            postHandler.processLDVPostPayableTransaction(resultsForProcess);
        }
        return results;
    }

    private List<PostResult> cashPost(List<LDVPostInput> scope) {
        return new AccountPayablePostHandlerCash().post(scope);
    }
}