public with sharing class AccountingPeriodCloseRetainedEarnings implements Database.Batchable<SObject>, Database.Stateful {
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private AccountingPeriodOpenCloseOptions periodInfoContainer;
    private String query;
    private Boolean isError;

    public AccountingPeriodCloseRetainedEarnings(AccountingPeriodOpenCloseOptions periodInfoContainer) {
        this.periodInfoContainer = periodInfoContainer;
        this.isError = false;


        // We are iterating though the list of Retained Earnings cubes in an iterative fashion and we are ordering by the gl account variable ids
        this.query =
            'SELECT Id, ' +
                    PACKAGE_QUALIFIER + 'Accounting_Period__c, ' +
                    PACKAGE_QUALIFIER + 'GL_Account__c, ' +
                    PACKAGE_QUALIFIER + 'GL_Account__r.' + PACKAGE_QUALIFIER + 'Type__c, ' +
                    PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c, ' +
                    PACKAGE_QUALIFIER + 'GL_Account_Variable_2__c, ' +
                    PACKAGE_QUALIFIER + 'GL_Account_Variable_3__c, ' +
                    PACKAGE_QUALIFIER + 'GL_Account_Variable_4__c, ' +
                    PACKAGE_QUALIFIER + 'Opening_Balance__c, ' +
                    PACKAGE_QUALIFIER + 'Amount__c, ' +
                    PACKAGE_QUALIFIER + 'Key_Group__c, ' +
                    PACKAGE_QUALIFIER + 'Cube_Type__c, ' +
                    PACKAGE_QUALIFIER + 'Transaction_Amount__c, ' +
                    PACKAGE_QUALIFIER + 'Ledger__c ' +
            'FROM ' + PACKAGE_QUALIFIER + 'Financial_Cube__c ' +
            'WHERE ' + PACKAGE_QUALIFIER + 'Ledger_Type__c IN (\'Transactional\', \'Eliminations-Transactional\') ' +
            'AND ' + PACKAGE_QUALIFIER + 'Cube_Type__c = \'Retained Earnings\' ' +
            'AND ' + PACKAGE_QUALIFIER + 'Accounting_Period__c = \'' + periodInfoContainer.getCurrentPeriod().Id + '\' ' +
            'ORDER BY ' +
                    PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c, ' +
                    PACKAGE_QUALIFIER + 'GL_Account_Variable_2__c, ' +
                    PACKAGE_QUALIFIER + 'GL_Account_Variable_3__c, ' +
                    PACKAGE_QUALIFIER + 'GL_Account_Variable_4__c';
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return DomainUtils.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        try {
            AccountingPeriodCloseBatchProcessor.FinancialCubesRetainedEarningsProcessor fre =
                new AccountingPeriodCloseBatchProcessor.FinancialCubesRetainedEarningsProcessor(
                    periodInfoContainer, new Map<String, Financial_Cube__c>((List<Financial_Cube__c>) scope)
                );

            fre.calculateRetainedEarningsNextPeriod();
        }
        catch (Exception ex) {
            isError = true;
            AccountingPeriodOpenCloseUtils.rollBackAndNotify(ex, periodInfoContainer);
        }
    }

    public void finish(Database.BatchableContext bc) {
        try {
            if (!isError) {
                Database.executeBatch(
                    new AccountingPeriodCloseBillingAging(periodInfoContainer),
                    AccountingPeriodOpenCloseUtils.PAYABLE_AND_BILLING_AGING_BATCH_SIZE
                );
            }
        }
        catch (Exception ex) {
            AccountingPeriodOpenCloseUtils.rollBackAndNotify(ex, periodInfoContainer);
        }
    }
}