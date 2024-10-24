public with sharing class AccountPayableLDVUnpostBatch extends SourceDocumentBatchBase {
    public AccountPayableLDVUnpostBatch(SourceDocumentBatchOptions options){
        super(Account_Payable__c.getSObjectType(), options);
        this.options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.UNPOST);
    }

    public AccountPayableLDVUnpostBatch(Set<Id> payableIds) {
        super(Account_Payable__c.getSObjectType(), new SourceDocumentBatchOptions(payableIds));
        options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.UNPOST);
    }

    public AccountPayableLDVUnpostBatch() {
        super(Account_Payable__c.getSObjectType(), new SourceDocumentBatchOptions(SourceDocumentBatchOptions.ExecutionContext.UNPOST, Account_Payable__c.getSObjectType()));
        options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.UNPOST);
    }

    public override void callNextBatch(){
        Database.executeBatch(new AccountPayableLDVUnpostBatch(this.options));
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
        AccountPayablePostHandler postHandler = new AccountPayablePostHandler();
        List<PostResult> resultsForProcess = new List<PostResult>();
        List<PostResult> results = postHandler.unpost(scope);
        for (PostResult res : results) {
            if (res.isSuccess) {
                resultsForProcess.add(res);
            }
        }
        if (!resultsForProcess.isEmpty()) {
            postHandler.processLDVUnpostPayableTransactions(resultsForProcess);
        }
        return results;
    }

    private List<PostResult> cashUnpost(List<LDVPostInput> scope) {
        return new AccountPayablePostHandlerCash().unpost(scope);
    }
}