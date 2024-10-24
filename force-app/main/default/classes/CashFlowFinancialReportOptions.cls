global with sharing class CashFlowFinancialReportOptions extends FinancialReportOptions {

    @AuraEnabled
    global Boolean showAllPeriods;

    @AuraEnabled
    public Boolean isCashFlowStatement;
    @AuraEnabled
    public String reportTypeName;
    public List<GL_Account__c> cashFlowCategories;
    public Id tempGLAccountReportingGroupId;

    global CashFlowFinancialReportOptions() {
        super();
        this.reportType = FinancialReportType.CASH_FLOW;
        this.reportTypeName = getReportTypeName();
        this.startingAccountingPeriod = AccountingPeriodHandler.getInstance().getFirstOpenedPeriod()?.Id;
        this.showAllPeriods = false;
        this.isCashFlowStatement = AccountingSettingsHandler.getAccountingSettings().Enable_Cash_Flow_Statement__c;
        this.cashFlowCategories = DomainUtils.getCashFlowCategories();
    }

    public override List<String> getListOfPeriodNames() {
        return AccountingPeriodHandler.getInstance().toString(getAllPeriodsInReportingRange());
    }

    public override List<Accounting_Period__c> getAllPeriodsInReportingRange() {
        List<Accounting_Period__c> periodsInReportingRange = new List<Accounting_Period__c>();
        AccountingPeriodHandler apHandler = AccountingPeriodHandler.getInstance();
        List<Accounting_Period__c> priorAccountingPeriods =
            apHandler.getPriorAccountingPeriodsForThisYear(startingAccountingPeriod, true);

        if (showAllPeriods) {
            if (!priorAccountingPeriods.isEmpty()) {
                Accounting_Period__c firstPeriod = apHandler.getAccountingPeriodByOffset(priorAccountingPeriods[0], -1);
                periodsInReportingRange.add(firstPeriod);
            }

            periodsInReportingRange.addAll(priorAccountingPeriods);
        }
        else {
            periodsInReportingRange.add(apHandler.getPreviousAccountingPeriod(startingAccountingPeriod));
            periodsInReportingRange.add(apHandler.getAccountingPeriodById(startingAccountingPeriod));
        }
        return periodsInReportingRange;
    }

    public override List<Id> getLedgerIds() {
        return new List<Id>{this.ledger};
    }

    public Map<String, List<GL_Account__c>> getCashFlowCategoriesGroupedByArea() {
        Map<String, List<GL_Account__c>> result = new Map<String, List<GL_Account__c>>();
        List<GL_Account__c> operatingAreaCFCs = new List<GL_Account__c>();
        List<GL_Account__c> investingAreaCFCs = new List<GL_Account__c>();
        List<GL_Account__c> financingAreaCFCs = new List<GL_Account__c>();

        if (this.cashFlowCategories != NULL && !cashFlowCategories.isEmpty()) {
            for (GL_Account__c cfc : this.cashFlowCategories) {
                if (cfc.Sub_Type_1__c == GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_OPERATING) {
                    operatingAreaCFCs.add(cfc);
                }
                if (cfc.Sub_Type_1__c == GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_INVESTING) {
                    investingAreaCFCs.add(cfc);
                }
                if (cfc.Sub_Type_1__c == GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_FINANCING) {
                    financingAreaCFCs.add(cfc);
                }
            }
        }

        result.put(GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_OPERATING, operatingAreaCFCs);
        result.put(GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_INVESTING, investingAreaCFCs);
        result.put(GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_FINANCING, financingAreaCFCs);
        return result;
    }

}