public with sharing class ArchiveDeleteFCubesBatch implements Database.Batchable<sObject>, Database.Stateful {

    private static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    private Accounting_Period__c acctPeriod;
    private Boolean isError;

    public ArchiveDeleteFCubesBatch(Accounting_Period__c acctPeriod) {
        this.acctPeriod = acctPeriod;
        this.isError = false;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        //query all FCs with type equals to "Period" & "Cash Flow" and with zero Opening Balance
        return DomainUtils.getQueryLocatorForArchiveDeleteFCubesBatch(acctPeriod);
    }

    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        try {
            List<Financial_Cube__c> finCubesToDelete = new List<Financial_Cube__c>();
            List<Financial_Cube__c> processedFinCubes = new List<Financial_Cube__c>();
            //remove FCs which have Transactional Amount value not equal to zero
            for (Financial_Cube__c finCube : (List<Financial_Cube__c>) scope) {
                if (finCube.Transaction_Amount__c == 0) {
                    processedFinCubes.add(finCube);
                }
            }
            //query FC Transactions which may exist for FCs in scope
            AggregateResult[] finCubeTransactionsAggregateResults =
                DomainUtils.getFinancialCubeTransactionsByFinCubesAggregateResults(processedFinCubes);
            //get FC Ids from existed FC Transactions records
            Set<Id> finCubeIdsHavingJunction = new Set<Id>();
            for (AggregateResult ar : finCubeTransactionsAggregateResults) {
                finCubeIdsHavingJunction.add((Id) ar.get(PACKAGE_QUALIFIER + 'Financial_Cube__c'));
            }
            //find FCs without any related transactions
            for (Financial_Cube__c fCube : processedFinCubes) {
                if (!finCubeIdsHavingJunction.contains(fCube.Id)) {
                    finCubesToDelete.add(fCube);
                }
            }

            SFDCSecurityUtils.deleteProxy(finCubesToDelete);
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
            Database.executeBatch(new ArchiveFCubesBatch(acctPeriod), 2000);
        }
    }
    
}