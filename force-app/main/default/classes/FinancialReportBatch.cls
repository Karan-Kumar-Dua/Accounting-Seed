public with sharing class FinancialReportBatch implements Database.Batchable<SObject>, Database.Stateful {

    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static final Boolean IS_MULTI_CURRENCY_ENABLED = MultiCurrencyHandler.isMultiCurrencyEnabled;

    public FinancialReportGenerator generator;
    public Id reportStubId;
    public Boolean isFirstIteration;
    public String currencyISO;

    public FinancialReportBatch(String reportDefId, Integer periodNo, Integer year) {

    }

    public FinancialReportBatch(FinancialReportWrapper frw, FinancialReportOptions reportOptions) {
        this.isFirstIteration = true;
        this.currencyISO = reportOptions.currencyISO;
        this.generator = new FinancialReportGenerator(frw, reportOptions);
        this.reportStubId = generator.createFinReportResult();
        publishStartEvent();
    }

    public Database.QueryLocator start(Database.BatchableContext batchableContext) {
        Map<Id, Accounting_Period__c> periodsMap = new Map<Id, Accounting_Period__c>(
            AccountingPeriodHandler.getInstance().getAccountingPeriodsByName(
                new Set<String>(generator.reportOptions.getListOfPeriodNames())
            )
        );

        Set<Id> accountingPeriodIds = periodsMap.keySet();
        Set<Id> glAccountIds = new Map<Id, GL_Account__c>(generator.reportOptions.glAccounts).keySet();
        Set<Id> ledgerIds = new Set<Id>(generator.reportOptions.getLedgerIds());

        String query =
            'SELECT Id, ' +
                    'Name, ' +
                    PACKAGE_QUALIFIER + 'GL_Account__c, ' +
                    PACKAGE_QUALIFIER + 'GL_Account_Variable_4__c, ' +
                    PACKAGE_QUALIFIER + 'Opening_Balance__c, ' +
                    PACKAGE_QUALIFIER + 'GL_Account_Variable_3__c, ' +
                    PACKAGE_QUALIFIER + 'GL_Account_Variable_2__c, ' +
                    PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c, ' +
                    PACKAGE_QUALIFIER + 'Key__c, ' +
                    PACKAGE_QUALIFIER + 'Cube_Type__c, ' +
                    PACKAGE_QUALIFIER + 'Year__c, ' +
                    PACKAGE_QUALIFIER + 'Ledger__c, ' +
                    PACKAGE_QUALIFIER + 'Current_Period__c, ' +
                    PACKAGE_QUALIFIER + 'Accounting_Period__c, ' +
                    PACKAGE_QUALIFIER + 'Accounting_Period__r.Name, ' +
                    PACKAGE_QUALIFIER + 'Year_To_Date__c, ' +
                    PACKAGE_QUALIFIER + 'Transaction_Amount__c, ' +
                    PACKAGE_QUALIFIER + 'Amount__c, ' +
                    PACKAGE_QUALIFIER + 'GL_Account__r.Name ' +
            'FROM ' + PACKAGE_QUALIFIER + 'Financial_Cube__c ' +
            'WHERE (' + PACKAGE_QUALIFIER + 'Current_Period__c != 0 OR ' + PACKAGE_QUALIFIER + 'Opening_Balance__c != 0) ' +
            'AND ' + PACKAGE_QUALIFIER + 'Accounting_Period__c IN :accountingPeriodIds ' +
            'AND ' + PACKAGE_QUALIFIER + 'GL_Account__c IN :glAccountIds ' +
            'AND ' + PACKAGE_QUALIFIER + 'Ledger__c IN :ledgerIds ' +
            (IS_MULTI_CURRENCY_ENABLED ? 'AND CurrencyIsoCode = \'' + String.escapeSingleQuotes(currencyISO) + '\' ' : '') +
            'ORDER BY ' + PACKAGE_QUALIFIER + 'Accounting_Period__r.Name';

        return DomainUtils.getQueryLocatorForFinancialReportBatch(query, accountingPeriodIds, glAccountIds, ledgerIds);
    }

    public void execute(Database.BatchableContext batchableContext, List<SObject> scope) {
        if (isFirstIteration) {
            generator.createReportStub();
            isFirstIteration = false;
        }

        for (SObject s : scope) {
            generator.processCube(s);
        }

        generator.calculateReportValues();
        generator.balanceBuilderInstance.clear();
    }

    public void finish(Database.BatchableContext batchableContext) {
        generator.finishReport();
        publishEndEvent();
    }

    private void publishStartEvent() {
        EventPubSub.publish(new ImmediateEvent(
            EventRegistry.RegisteredEvent.FINANCIAL_REPORTER_GENERATE_START,
            reportStubId,
            null
        ));
    }

    private void publishEndEvent() {
        EventPubSub.publish(new CommitEvent(
            EventRegistry.RegisteredEvent.FINANCIAL_REPORTER_GENERATE_END,
            reportStubId,
            null
        ));
    }

}