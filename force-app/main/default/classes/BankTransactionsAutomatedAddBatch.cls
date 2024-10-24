public with sharing class BankTransactionsAutomatedAddBatch implements Database.Batchable<Bank_Transaction__c> {

    private List<Bank_Transaction__c> bankTransactions;

    public BankTransactionsAutomatedAddBatch(List<Bank_Transaction__c> bts) {
        this.bankTransactions = bts;
    }

    public List<Bank_Transaction__c> start(Database.BatchableContext bc) {
        return bankTransactions;
    }

    public void execute(Database.BatchableContext bc, List<Bank_Transaction__c> scope) {
        System.Savepoint sp = Database.setSavepoint();
        try {
            List<ServiceResult> addResults = BankTransactionsHelper.autoAddRecords(scope);
            BankTransactionsHelper.updateBankTransactionsStatus(addResults, BankTransactionsHelper.BT_ADDED_STATUS);
        }
        catch (Exception ex) {
            Database.rollback(sp);
        }
    }

    public void finish(Database.BatchableContext bc) {
        try {
            Set<Id> bankTransactionIds = new Map<Id, Bank_Transaction__c>(this.bankTransactions).keySet();
            BankTransactionsHelper.updateBankTransactionsStatus(
                DomainUtils.getPendingBankTransactionsById(bankTransactionIds),
                BankTransactionsHelper.BT_UNMATCHED_STATUS
            );
        }
        catch (Exception ex) {}
    }

}