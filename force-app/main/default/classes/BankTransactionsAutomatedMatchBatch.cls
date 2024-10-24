public with sharing class BankTransactionsAutomatedMatchBatch implements Database.Stateful, Database.Batchable<Bank_Transaction__c> {

    private List<Bank_Transaction__c> bankTransactions;
    private List<Bank_Transaction__c> applicableToAdd;
    private Boolean isError;

    public BankTransactionsAutomatedMatchBatch(List<Bank_Transaction__c> bts) {
        this.bankTransactions = bts;
        this.applicableToAdd = new List<Bank_Transaction__c>();
        this.isError = false;
    }

    public List<Bank_Transaction__c> start(Database.BatchableContext bc) {
        return bankTransactions;
    }

    public void execute(Database.BatchableContext bc, List<Bank_Transaction__c> scope) {
        System.Savepoint sp = Database.setSavepoint();
        try {
            if (!isError) {
                Map<Id, SObject> applicableToMatch = new Map<Id, SObject>();
                BankTransactionsMatcher matcher = new BankTransactionsMatcher(
                    new Map<Id, Bank_Transaction__c>(scope).keySet(),
                    BankTransactionsMatcher.ExecutionContext.APEX_JOB
                );
                matcher.searchMatchingRecords();
                for (Bank_Transaction__c bt : scope) {
                    if (matcher.hasMatchingRecords(bt.Id)
                            && matcher.getMatchingRecords(bt.Id).size() == 1
                            && matcher.getBankTransactionsByMatchingRecord(matcher.getMatchingRecords(bt.Id).get(0).Id).size() == 1) {

                        applicableToMatch.put(bt.Id, matcher.getMatchingRecords(bt.Id).get(0));
                    }
                    else if (!matcher.hasMatchingRecords(bt.Id)) {
                        applicableToAdd.add(bt);
                    }
                }

                //Execute Automated Match if only one possible Source record match exists for the Bank Transaction
                if (AccountingSettingsHandler.isGlobalAutomatedMatchEnabled() && !applicableToMatch.isEmpty()) {
                    List<ServiceResult> acceptResults = BankTransactionsHelper.acceptMatchingRecord(
                        applicableToMatch,
                        new Map<Id, Bank_Transaction__c>(scope)
                    );
                    BankTransactionsHelper.updateBankTransactionsStatus(acceptResults, BankTransactionsHelper.BT_MATCHED_STATUS);
                }
            }
        }
        catch (Exception ex) {
            isError = true;
            Database.rollback(sp);
        }
    }

    public void finish(Database.BatchableContext bc) {
        try {
            //Execute Automated Add if there are Bank Transactions without any possible matching records
            if (AccountingSettingsHandler.isGlobalAutomatedAddEnabled() && !applicableToAdd.isEmpty() && !isError) {
                BankTransactionsAutomatedAddBatch autoAddBatchInstance = new BankTransactionsAutomatedAddBatch(applicableToAdd);
                Database.executeBatch(autoAddBatchInstance, ImportFileWizardHelper.TRANSACTIONS_PAGE_SIZE);
            }
            else {
                Set<Id> bankTransactionIds = new Map<Id, Bank_Transaction__c>(this.bankTransactions).keySet();
                BankTransactionsHelper.updateBankTransactionsStatus(
                    DomainUtils.getPendingBankTransactionsById(bankTransactionIds),
                    BankTransactionsHelper.BT_UNMATCHED_STATUS
                );
            }
        }
        catch (Exception ex) {}
    }

}