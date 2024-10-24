public with sharing class AccountingPeriodDeleteEarningsCubesBatch implements Database.Batchable<sObject>, Database.Stateful {

    private AccountingPeriodOpenCloseOptions periodInfoContainer;
    private Set<Id> currentPeriodIds;
    private Set<Id> nextPeriodIds;
    private Boolean isError;

    public AccountingPeriodDeleteEarningsCubesBatch(AccountingPeriodOpenCloseOptions periodInfoContainer, Set<Id> currentPeriodIds, Set<Id> nextPeriodIds) {
        this.periodInfoContainer = periodInfoContainer;
        this.currentPeriodIds = currentPeriodIds;
        this.nextPeriodIds = nextPeriodIds;
        this.isError = false;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return DomainUtils.getQueryLocatorForDeleteCurrentAndRetainedEarningsBatch(currentPeriodIds, nextPeriodIds);
    }

    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        try {
            FinancialCubeActions.isPreventOverride = true;
            SFDCSecurityUtils.deleteProxy((List<Financial_Cube__c>) scope);
            FinancialCubeActions.isPreventOverride = false;
        }
        catch (Exception ex) {
            isError = true;
            if (periodInfoContainer.context == AccountingPeriodOpenCloseUtils.PeriodUpdateContext.CLOSING) {
                AccountingPeriodOpenCloseUtils.rollBackAndNotify(ex, periodInfoContainer);
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        if (!isError && periodInfoContainer.context == AccountingPeriodOpenCloseUtils.PeriodUpdateContext.CLOSING) {
            Database.executeBatch(new AccountingPeriodCloseBatchProcessor(periodInfoContainer));
        }
        else if (periodInfoContainer.context == AccountingPeriodOpenCloseUtils.PeriodUpdateContext.OPENING) {
            Database.executeBatch(
                new AccountingPeriodOpenBillingAging(periodInfoContainer),
                AccountingPeriodOpenCloseUtils.PAYABLE_AND_BILLING_AGING_BATCH_SIZE
            );
        }
    }

}