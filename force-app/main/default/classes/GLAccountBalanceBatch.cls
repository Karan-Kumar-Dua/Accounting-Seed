public with sharing class GLAccountBalanceBatch implements Database.Batchable<SObject>, Database.Stateful {
    
    private Decimal accumulator;
    private final GLAccountBalanceOption options;
    private final Date startDate;

    public GLAccountBalanceBatch(
            GLAccountBalanceOption options, 
            Date startDate, 
            Decimal startBalance) {
        this.options = options;
        this.startDate = startDate;
        this.accumulator = startBalance <> null ? startBalance : 0;
    }

    public Database.QueryLocator start(Database.BatchableContext ctx) {
        return DomainUtils.getTransactionsQueryLocatorForGLAccountBalance(startDate, options);
    }

    public void execute(Database.BatchableContext ctx, List<Transaction__c> scope) {
        for (Transaction__c tx : scope) {
            accumulator += tx.Amount__c;
        }
    }

    public void finish(Database.BatchableContext ctx) {
        GLAccountBalance.publishBalance(options, accumulator);
    }

}