public with sharing class ArchiveFCubesBatch implements Database.Batchable<sObject>, Database.Stateful {

    private static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    private Accounting_Period__c acctPeriod;
    private String query;
    @TestVisible
    private Boolean isError;

    public ArchiveFCubesBatch(Accounting_Period__c acctPeriod) {
        this.acctPeriod = acctPeriod;
        this.query =
            'SELECT Id, ' +
                    PACKAGE_QUALIFIER + 'Transaction_Amount__c, ' +
                    PACKAGE_QUALIFIER + 'Amount__c, ' +
                    PACKAGE_QUALIFIER + 'Archived_Amount__c ' +
            'FROM ' + PACKAGE_QUALIFIER + 'Financial_Cube__c ' +
            'WHERE ' + PACKAGE_QUALIFIER + 'Cube_Type__c IN (\'Period\', \'Cash Flow\') ' +
            'AND Accounting_Period__c = \'' + acctPeriod.Id + '\'';
        this.isError = false;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return DomainUtils.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        try {
            List<Financial_Cube__c> fCubes = new List<Financial_Cube__c>();

            for (Financial_Cube__c fCube : (List<Financial_Cube__c>) scope) {
                //we need to be sure that Amount__c field will be set only once
                if (fCube.Archived_Amount__c == NULL) {//first run
                    fCube.Amount__c = fCube.Transaction_Amount__c;
                    fCube.Archived_Amount__c = fCube.Transaction_Amount__c;
                }
                else {//re-execution
                    if (fCube.Amount__c != fCube.Transaction_Amount__c) {
                        fCube.Amount__c = fCube.Archived_Amount__c;
                    }
                }

                fCubes.add(fCube);
            }

            FinancialCubeActions.isPreventOverride = true;
            SFDCSecurityUtils.updateProxy(fCubes);
            FinancialCubeActions.isPreventOverride = false;
        }
        catch (Exception ex) {
            isError = true;
            AccountingPeriodOpenCloseUtils.updateAndNotify(
                acctPeriod,
                AccountingPeriodActions.CLOSED_STATUS,
                String.format(AccountingPeriodOpenCloseUtils.ARCHIVE_FAILED_EMAIL_SUBJECT, new List<String>{acctPeriod.Name}),
                String.format(AccountingPeriodOpenCloseUtils.ARCHIVE_FAILED_EMAIL_BODY, new List<String>{acctPeriod.Name, ex.getMessage()})
            );
        }
    }

    public void finish(Database.BatchableContext bc) {
        if (!isError && !Test.isRunningTest()) {
            Database.executeBatch(new ArchiveAndDeleteTransactionsBatch(acctPeriod), 1000);
        }
    }

}