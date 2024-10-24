public with sharing class AccountingPeriodOpenCubesDeletion implements Database.Batchable<sObject>, Database.Stateful {

    private AccountingPeriodOpenCloseOptions periodInfoContainer;

    public AccountingPeriodOpenCubesDeletion(AccountingPeriodOpenCloseOptions periodInfoContainer) {
        this.periodInfoContainer = periodInfoContainer;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Set<Id> currentPeriodIds = new Set<Id>{periodInfoContainer.getCurrentPeriod().Id};
        return DomainUtils.getQueryLocatorForCubesDeletion(
            new Set<String>{FinancialCubeActions.FINANCIAL_CUBE_CONSOLIDATIONS},
            currentPeriodIds
        );
    }

    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        FinancialCubeActions.isPreventOverride = true;
        SFDCSecurityUtils.deleteProxy(scope);
        FinancialCubeActions.isPreventOverride = false;
    }

    public void finish(Database.BatchableContext bc) {
        //delete CYE and RE Fin Cubes
        try {
            AccountingPeriodOpenCloseUtils.deleteCurrentAndRetainedEarningsBeforeNextBatch(periodInfoContainer);
        }
        catch (Exception ex) {}
    }
}