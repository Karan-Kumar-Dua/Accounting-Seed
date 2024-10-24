public with sharing class AccountingPeriodOpenBillingAging implements Database.Batchable<SObject>, Database.Stateful {

    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private AccountingPeriodOpenCloseOptions periodInfoContainer;
    private Accounting_Period__c currentPeriod;
    private String query;

    public AccountingPeriodOpenBillingAging(AccountingPeriodOpenCloseOptions periodInfoContainer) {

        this.periodInfoContainer = periodInfoContainer;
        this.currentPeriod = periodInfoContainer.getCurrentPeriod();
        this.query =
            'SELECT Id, ' +
                    PACKAGE_QUALIFIER + 'Billing__r.' + PACKAGE_QUALIFIER + 'Closed_Accounting_Period__c ' +
            'FROM ' + PACKAGE_QUALIFIER + 'Billing_Aging_History__c ' +
            'WHERE ' + PACKAGE_QUALIFIER + 'Accounting_Period__c = \'' + currentPeriod.Id + '\''; 
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return DomainUtils.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        try {
                if(!(this.currentPeriod.close_AR__c)){
                   SFDCSecurityUtils.deleteProxy(scope, false);
                }
        }
        catch (Exception ex) {
            //The AP and Billing aging history close and open routines should silently fail with an exception.
            // The accounting period open and close processes should continue in this case.
        }
    }

    public void finish(Database.BatchableContext bc) {

        // if period is not soft open i.e., AR_close__C checkbox is unchecked and status is open then simply finish the Batch Finish method.
        if(periodInfoContainer.context != AccountingPeriodOpenCloseUtils.PeriodUpdateContext.SOFT_OPEN){
            Database.executeBatch(
                new AccountingPeriodOpenAPAging(periodInfoContainer),
                AccountingPeriodOpenCloseUtils.PAYABLE_AND_BILLING_AGING_BATCH_SIZE
            );
        }
        else{

            if (periodInfoContainer.hasNext()) {
                Integer nextIndex = periodInfoContainer.getIndex() + 1;
                periodInfoContainer.setIndex(nextIndex);
                Database.executeBatch(new AccountingPeriodOpenBillingAging(periodInfoContainer));
            }
        }
    }

}