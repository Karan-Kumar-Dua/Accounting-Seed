public with sharing class TrialBalanceFinancialReport extends AbstractFinancialReport {

    public override FinancialReportWrapper runReport(FinancialReportOptions reportOptions) {
        reportOptions.glAccounts = new List<GL_Account__c>();
        Set<Id> cyeGLAccounts = getCYEGLAccounts();

        for (GL_Account__c glAcct : DomainUtils.getGlAccountsForTrialBalanceReport()) {
            if (!cyeGLAccounts.contains(glAcct.Id)) {
                reportOptions.glAccounts.add(glAcct);
            }
        }

        this.reportOptions = reportOptions;
        this.reportOptions.setRoundingMode(FinancialReportOptions.FinancialReportRoundingMode.NO_ROUNDING);

        return super.generateReport();
    }

    private Set<Id> getCYEGLAccounts() {
        Set<Id> accounts = new Set<Id>();
        for (GL_Account_Default__c def : DomainUtils.gLAccountDefaultsBySpecification(new Set<String> {GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT})) {
            accounts.add(def.GL_Account__c);
        }
        return accounts;
    }
    
    public override FinancialReportWrapper createReportDefinition() {
        FinancialReportWrapper frw = new FinancialReportWrapper();
        //wrapper's property  to specify Landscape or Portrait View when the report will be rendered as PDF
        frw.viewModeInPDF = 'Portrait';
        //=================================================================================================
        Financial_Report_Definition__c frd = new Financial_Report_Definition__c(
            Name = reportOptions.getReportTypeName(),
            Subtitle__c = reportOptions.getReportSubtitle()
        );
        frw.reportDefinition = frd;
        
        Financial_Report_Row__c frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
        Integer position = 10;
        
        for (GL_Account__c glAcct : reportOptions.glAccounts) {

            frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
            position += 10;
            frr.Position__c = position;
            frr.Indent__c = '1';
            frr.GL_Account__c = glAcct.Id;
            frr.Type__c = FinancialReportRowActions.FRR_TYPE_GL_ACCOUNT;
            frr.GL_Account_Variable_1__c = reportOptions.glVariable1;
            frr.GL_Account_Variable_2__c = reportOptions.glVariable2;
            frr.GL_Account_Variable_3__c = reportOptions.glVariable3;
            frr.GL_Account_Variable_4__c = reportOptions.glVariable4;
            frr.Row_Label__c = glAcct.Name;
            
            if (glAcct.Type__c == GLAccountActions.GL_ACCOUNT_TYPE_EXPENSE
                    || (glAcct.Type__c == GLAccountActions.GL_ACCOUNT_TYPE_BALANCE_SHEET
                            && glAcct.Sub_Type_1__c == GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_ASSETS)) {

                frr.Normal_Balance__c = FinancialReportRowActions.FRR_NORMAL_BALANCE_DEBIT;
            }

            frw.rowList.add(frr);
        }

        frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
        position += 10;
        frr.Position__c = position;
        frr.Type__c = FinancialReportRowActions.FRR_TYPE_BLANK;
        frw.rowList.add(frr);

        frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
        position += 10;
        frr.Position__c = position;
        frr.Indent__c = '1';
        frr.Type__c = FinancialReportRowActions.FRR_TYPE_CALCULATION_NUMBER;
        frr.Calculation__c = '{r10:r' + (position - 10) + '}';
        frr.Row_Label__c = 'Total';
        frw.rowList.add(frr); 

        Financial_Report_Column__c fcd = new Financial_Report_Column__c(Financial_Report_Definition__c = frd.Id);
        fcd.Ledger__c = reportOptions.ledger;
        fcd.Position__c = 0;
        fcd.Type__c = (reportOptions.isTrialBalanceForTranslatedBase()) ? FinancialReportColumnActions.FRC_TYPE_OPENING_BALANCE : FinancialReportColumnActions.FRC_TYPE_YEAR_TO_DATE;
        fcd.Offset__c = (reportOptions.isTrialBalanceForTranslatedBase()) ? 0 : -1;
        fcd.Header_1_Value__c = 'Text';
        fcd.Header_1__c = 'Opening Balance';
        fcd.Suppress_Print__c = reportOptions.suppressOpeningBalanceAndPeriodColumns;
        frw.colList.add(fcd);

        fcd = new Financial_Report_Column__c(Financial_Report_Definition__c = frd.Id);
        fcd.Ledger__c = reportOptions.ledger;
        fcd.Position__c = 1;
        fcd.Type__c = FinancialReportColumnActions.FRC_TYPE_CURRENT_PERIOD;
        fcd.Offset__c = 0;
        fcd.Header_1_Value__c = 'Period Name';
        fcd.Suppress_Print__c = reportOptions.suppressOpeningBalanceAndPeriodColumns;
        frw.colList.add(fcd);

        fcd = new Financial_Report_Column__c(Financial_Report_Definition__c = frd.Id);
        fcd.Ledger__c = reportOptions.ledger;
        fcd.Position__c = 2;
        fcd.Type__c = FinancialReportColumnActions.FRC_TYPE_YEAR_TO_DATE;
        fcd.Offset__c = 0;
        fcd.Header_1_Value__c = 'Text';
        fcd.Header_1__c = FinancialReportColumnActions.FRC_TYPE_YEAR_TO_DATE;
        frw.colList.add(fcd);

        return frw;
    }
}