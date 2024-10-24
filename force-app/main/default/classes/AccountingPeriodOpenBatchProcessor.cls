public with sharing class AccountingPeriodOpenBatchProcessor implements Database.Batchable<sObject>, Database.Stateful {

    private String query;
    private AccountingPeriodOpenCloseOptions periodInfoContainer;
    private Accounting_Period__c nextPeriod;
    private Boolean isError;

    public AccountingPeriodOpenBatchProcessor(AccountingPeriodOpenCloseOptions periodInfoContainer) {
        this.periodInfoContainer = periodInfoContainer;
        this.nextPeriod = periodInfoContainer.getNextPeriod();
        this.isError = false;

        this.query =
            'SELECT Id, Opening_Balance__c ' +
            'FROM Financial_Cube__c ' +
            'WHERE Accounting_Period__c = \'' + nextPeriod.Id + '\' ' +
            'AND Ledger_Type__c IN (\'Transactional\', \'Eliminations-Transactional\') ' +
            'AND (Cube_Type__c = \'Period\' OR Cube_Type__c = \'Cash Flow\')';
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        return DomainUtils.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        try {
            setFinancialCubesOpeningBalance((List<Financial_Cube__c>) scope);
        }
        catch (Exception ex) {
            isError = true;
            AccountingPeriodOpenCloseUtils.rollBackAndNotify(ex, periodInfoContainer);
        }
    }

    public void finish(Database.BatchableContext bc) {
        if (!isError) {
            //delete Consolidations Fin Cubes
            try {
                Database.executeBatch(new AccountingPeriodOpenCubesDeletion(periodInfoContainer));
            }
            catch (Exception ex) {}
        }
    }

    @TestVisible
    private void setFinancialCubesOpeningBalance(List<Financial_Cube__c> financialCubeList) {
        try {
            List<Financial_Cube__c> periodFinancialCubes = new List<Financial_Cube__c>();

            for (Financial_Cube__c fCube : financialCubeList) {
                fCube.Opening_Balance__c = 0;
                periodFinancialCubes.add(fCube);
            }
            FinancialCubeActions.isPreventOverride = true;
            SFDCSecurityUtils.updateProxy(periodFinancialCubes);
            FinancialCubeActions.isPreventOverride = false;
        }
        catch (Exception ex) {
            throw ex;
        }
    }

}