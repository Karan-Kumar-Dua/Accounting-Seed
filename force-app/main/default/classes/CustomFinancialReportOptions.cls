global with sharing class CustomFinancialReportOptions extends FinancialReportOptions {

    @AuraEnabled
    public Id financialReportDefinitionId;
    private static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public Financial_Report_Definition__c financialReportDefinition;
    public List<Id> ledgerIds;

    global CustomFinancialReportOptions(Id financialReportDefinitionId) {
        super();
        this.reportType = FinancialReportType.CUSTOM;
        this.startingAccountingPeriod = AccountingPeriodHandler.getInstance().getLastClosedOrArchivedAccountingPeriod()?.Id;
        this.financialReportDefinitionId = financialReportDefinitionId;
     }

    private Accounting_Period__c getStartingAccountingPeriod() {
        Accounting_Period__c result;
        List<Accounting_Period__c> appropriateAcctPeriods =
            AccountingPeriodHandler.getInstance().getAllAccountingPeriods(
                new Set<String>{
                    AccountingPeriodActions.CLOSED_STATUS,
                    AccountingPeriodActions.ARCHIVED_STATUS,
                    AccountingPeriodActions.ARCHIVE_IN_PROGRESS_STATUS,
                    AccountingPeriodActions.OPEN_INTERIM_STATUS
                },
                SOQLBuilder.SortOrder.DESCENDING
            );

        if (!appropriateAcctPeriods.isEmpty()) {
            result = appropriateAcctPeriods[0];
        }

        return result;
    }

    public override List<String> getListOfPeriodNames() {
        return AccountingPeriodHandler.getInstance().toString(getAllPeriodsInReportingRange());
    }

    public override List<Accounting_Period__c> getAllPeriodsInReportingRange() {
        return AccountingPeriodHandler.getInstance().getAccountingPeriodsByFinancialReportColumns(
            this.startingAccountingPeriod, CustomReportFinancialReport.queryReportDefinition(this.financialReportDefinitionId).Financial_Report_Columns__r
        );
    }

    public override List<Id> getLedgerIds() {
        return this.ledgerIds;
    }

    private Boolean isNotValidCustomReportDefForAllPeriods(Financial_Report_Definition__c definition) {
        return isGLRepGroupBalanceSheet(definition) || isGLAccountBalanceSheet(definition) || isYTDColumn(definition);
    }

    private Boolean isGLRepGroupBalanceSheet(Financial_Report_Definition__c definition) {
        Set<Id> reportingGroupIds = new Set<Id>();

        for (Financial_Report_Row__c row : definition.Financial_Report_Rows__r) {
            if (row.GL_Account_Reporting_Group__c != NULL) {
                reportingGroupIds.add(row.GL_Account_Reporting_Group__c);
            }
        }

        for (GL_Account_Reporting_Group_Line__c rgl : DomainUtils.getGlAccountReportingGroupLinesByMasterId(reportingGroupIds)) {
            if (rgl.Type__c == GLAccountActions.GL_ACCOUNT_TYPE_BALANCE_SHEET) {
                return true;
            }
        }

        return false;
    }

    private Boolean isGLAccountBalanceSheet(Financial_Report_Definition__c definition) {
        Set<Id> glAccountIds = new Set<Id>();

        for (Financial_Report_Row__c row : definition.Financial_Report_Rows__r) {
            if (row.Type__c == FinancialReportRowActions.FRR_TYPE_GL_ACCOUNT && row.GL_Account__c != NULL) {
                glAccountIds.add(row.GL_Account__c);
            }
        }

        for (GL_Account__c glAcc : DomainUtils.getGlAccountsById(glAccountIds)) {
            if (glAcc.Type__c == GLAccountActions.GL_ACCOUNT_TYPE_BALANCE_SHEET) {
                return true;
            }
        }

        return false;
    }

    private Boolean isYTDColumn(Financial_Report_Definition__c definition) {
        for (Financial_Report_Column__c col : definition.Financial_Report_Columns__r) {
            if (col.Type__c == FinancialReportColumnActions.FRC_TYPE_YEAR_TO_DATE) {
                return true;
            }
        }
        return false;
    }

}