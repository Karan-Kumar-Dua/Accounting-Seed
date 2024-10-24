public with sharing class CashFlowStatementReport extends AbstractFinancialReport {

    public override FinancialReportWrapper runReport(FinancialReportOptions aReportOptions) {
        CashFlowFinancialReportOptions reportOptions = (CashFlowFinancialReportOptions) aReportOptions;
        reportOptions.glAccounts = DomainUtils.getGlAccountsForCashFlowStatementReport();
        reportOptions.glAccounts.addAll(reportOptions.cashFlowCategories);

        //create temp GL Account Reporting Group
        GL_Account_Reporting_Group__c tempGlAccountReportingGroup = new GL_Account_Reporting_Group__c(
            Name = 'CashFlowStatementReport_Temporary_Group'
        );

        SFDCSecurityUtils.insertCheckCRUDAndFLS(tempGlAccountReportingGroup, new List<String>{'Name'});

        reportOptions.tempGLAccountReportingGroupId = tempGlAccountReportingGroup.Id;
        //add GL Accounts to the new group
        List<GL_Account_Reporting_Group_Line__c> newGroupLines = new List<GL_Account_Reporting_Group_Line__c>();
        //to prevent possible duplication of lines in the reporting group
        Set<Id> uniqGLAccountIds = new Set<Id>();
        List<GL_Account__c> onlyUniqGlAccounts = new List<GL_Account__c>();
        for (GL_Account__c glAccount : reportOptions.glAccounts) {
            if (!uniqGLAccountIds.contains(glAccount.Id)) {
                onlyUniqGlAccounts.add(glAccount);
            }
            uniqGLAccountIds.add(glAccount.Id);
        }
        reportOptions.glAccounts = onlyUniqGlAccounts;
        //add only Bank GL Accounts into temporary group
        for (GL_Account__c glAccount : reportOptions.glAccounts) {
            if (glAccount.Bank__c) {
                GL_Account_Reporting_Group_Line__c newGroupLine = new GL_Account_Reporting_Group_Line__c(
                    GL_Account_Reporting_Group__c = tempGlAccountReportingGroup.Id,
                    GL_Account__c = glAccount.Id
                );
                newGroupLines.add(newGroupLine);
            }
        }

        SFDCSecurityUtils.insertCheckCRUDAndFLS(
            newGroupLines,
            new List<String>{'GL_Account_Reporting_Group__c', 'GL_Account__c'}
        );

        this.reportOptions = reportOptions;
        return super.generateReport();
    }

    public override FinancialReportWrapper createReportDefinition() {
        CashFlowFinancialReportOptions reportOptions = (CashFlowFinancialReportOptions) reportOptions;
        //we always have one extra period (prior to selected)
        //that is why the number of Period Columns => (periods-in-list minus 1)
        Integer columnCount = (reportOptions != NULL && reportOptions.getListOfPeriodNames() != NULL ? reportOptions.getListOfPeriodNames().size() - 1 : 0);
        FinancialReportWrapper frw = new FinancialReportWrapper();
        //wrapper's property  to specify Landscape or Portrait View when the report will be rendered as PDF
        frw.viewModeInPDF = columnCount < 5 || !reportOptions.showAllPeriods ? 'Portrait' : 'Landscape';
        //=================================================================================================
        Financial_Report_Definition__c frd = new Financial_Report_Definition__c(
            Name = reportOptions.getReportTypeName(),
            Subtitle__c = reportOptions.getReportSubtitle()
        );
        frw.reportDefinition = frd;

        Financial_Report_Row__c frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
        Integer position = 10;
        Integer beginningBalancePosition = position;
        frr.Position__c = position;
        frr.Type__c = FinancialReportRowActions.FRR_TYPE_REPORTING_GROUP;
        frr.GL_Account_Reporting_Group__c = reportOptions.tempGLAccountReportingGroupId;
        frr.Row_Label__c = 'Beginning Cash Balance';
        frr.GL_Account_Variable_1__c = reportOptions.glVariable1;
        frr.GL_Account_Variable_2__c = reportOptions.glVariable2;
        frr.GL_Account_Variable_3__c = reportOptions.glVariable3;
        frr.GL_Account_Variable_4__c = reportOptions.glVariable4;
        frw.rowList.add(frr);

        frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
        position += 10;
        frr.Position__c = position;
        frr.Type__c = FinancialReportRowActions.FRR_TYPE_BLANK;
        frw.rowList.add(frr);

        //==========================================================================
        //================ CASH FLOW FROM OPERATING ACTIVITIES =====================
        //==========================================================================
        frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
        position += 10;
        frr.Position__c = position;
        frr.Type__c = FinancialReportRowActions.FRR_TYPE_DESCRIPTION;
        frr.Row_Label__c = 'Cash Flow from Operating Activities';
        frw.rowList.add(frr);

        List<GL_Account__c> operatingAreaCFCs = reportOptions.getCashFlowCategoriesGroupedByArea().get(
            GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_OPERATING
        );
        operatingAreaCFCs.sort();
        Integer startCalculationPosition = operatingAreaCFCs.isEmpty() ? position : (position + 10);

        for (Integer i = 0; i < operatingAreaCFCs.size(); i++) {
            GL_Account__c cashFlowCategory = operatingAreaCFCs[i];
            position += 10;

            if (i == operatingAreaCFCs.size() - 1) {
                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
                frr.Position__c = position;
                frr.Indent__c = '1';
                frr.Type__c = FinancialReportRowActions.FRR_TYPE_GL_ACCOUNT;
                frr.Row_Label__c = cashFlowCategory.Name;
                frr.GL_Account__c = cashFlowCategory.Id;
                frr.GL_Account_Variable_1__c = reportOptions.glVariable1;
                frr.GL_Account_Variable_2__c = reportOptions.glVariable2;
                frr.GL_Account_Variable_3__c = reportOptions.glVariable3;
                frr.GL_Account_Variable_4__c = reportOptions.glVariable4;
                frw.rowList.add(frr);
            }
            else {
                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
                frr.Position__c = position;
                frr.Indent__c = '1';
                frr.Type__c = FinancialReportRowActions.FRR_TYPE_GL_ACCOUNT;
                frr.Row_Label__c = cashFlowCategory.Name;
                frr.GL_Account__c = cashFlowCategory.Id;
                frr.GL_Account_Variable_1__c = reportOptions.glVariable1;
                frr.GL_Account_Variable_2__c = reportOptions.glVariable2;
                frr.GL_Account_Variable_3__c = reportOptions.glVariable3;
                frr.GL_Account_Variable_4__c = reportOptions.glVariable4;
                frw.rowList.add(frr);
            }
        }

        Integer endCalculationPosition = position;

        frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
        position += 10;
        frr.Position__c = position;
        frr.Type__c = FinancialReportRowActions.FRR_TYPE_CALCULATION_NUMBER;
        frr.Calculation__c = '{r' + startCalculationPosition + ':r' + endCalculationPosition + '}';
        frr.Row_Label__c = 'Net cash flow from Operating Activities';
        frw.rowList.add(frr);

        frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
        position += 10;
        frr.Position__c = position;
        frr.Type__c = FinancialReportRowActions.FRR_TYPE_BLANK;
        frw.rowList.add(frr);

        //==========================================================================
        //================ CASH FLOW FROM INVESTING ACTIVITIES =====================
        //==========================================================================
        frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
        position += 10;
        frr.Position__c = position;
        frr.Type__c = FinancialReportRowActions.FRR_TYPE_DESCRIPTION;
        frr.Row_Label__c = 'Cash Flow from Investing Activities';
        frw.rowList.add(frr);

        List<GL_Account__c> investingAreaCFCs = reportOptions.getCashFlowCategoriesGroupedByArea().get(
            GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_INVESTING
        );
        investingAreaCFCs.sort();
        startCalculationPosition = investingAreaCFCs.isEmpty() ? position : (position + 10);

        for (Integer i = 0; i < investingAreaCFCs.size(); i++) {
            GL_Account__c cashFlowCategory = investingAreaCFCs[i];
            position += 10;

            if (i == investingAreaCFCs.size() - 1) {
                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
                frr.Position__c = position;
                frr.Indent__c = '1';
                frr.Type__c = FinancialReportRowActions.FRR_TYPE_GL_ACCOUNT;
                frr.Row_Label__c = cashFlowCategory.Name;
                frr.GL_Account__c = cashFlowCategory.Id;
                frr.GL_Account_Variable_1__c = reportOptions.glVariable1;
                frr.GL_Account_Variable_2__c = reportOptions.glVariable2;
                frr.GL_Account_Variable_3__c = reportOptions.glVariable3;
                frr.GL_Account_Variable_4__c = reportOptions.glVariable4;
                frw.rowList.add(frr);
            }
            else {
                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
                frr.Position__c = position;
                frr.Indent__c = '1';
                frr.Type__c = FinancialReportRowActions.FRR_TYPE_GL_ACCOUNT;
                frr.Row_Label__c = cashFlowCategory.Name;
                frr.GL_Account__c = cashFlowCategory.Id;
                frr.GL_Account_Variable_1__c = reportOptions.glVariable1;
                frr.GL_Account_Variable_2__c = reportOptions.glVariable2;
                frr.GL_Account_Variable_3__c = reportOptions.glVariable3;
                frr.GL_Account_Variable_4__c = reportOptions.glVariable4;
                frw.rowList.add(frr);
            }
        }

        endCalculationPosition = position;

        frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
        position += 10;
        frr.Position__c = position;
        frr.Type__c = FinancialReportRowActions.FRR_TYPE_CALCULATION_NUMBER;
        frr.Row_Label__c = 'Net cash flow from Investing Activities';
        frr.Calculation__c = '{r' + startCalculationPosition + ':r' + endCalculationPosition + '}';
        frw.rowList.add(frr);

        frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
        position += 10;
        frr.Position__c = position;
        frr.Type__c = FinancialReportRowActions.FRR_TYPE_BLANK;
        frw.rowList.add(frr);

        //==========================================================================
        //================ CASH FLOW FROM FINANCING ACTIVITIES =====================
        //==========================================================================
        frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
        position += 10;
        frr.Position__c = position;
        frr.Type__c = FinancialReportRowActions.FRR_TYPE_DESCRIPTION;
        frr.Row_Label__c = 'Cash Flow from Financing Activities';
        frw.rowList.add(frr);

        List<GL_Account__c> financingAreaCFCs = reportOptions.getCashFlowCategoriesGroupedByArea().get(
            GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_FINANCING
        );
        financingAreaCFCs.sort();
        startCalculationPosition = financingAreaCFCs.isEmpty() ? position : (position + 10);

        for (Integer i = 0; i < financingAreaCFCs.size(); i++) {
            GL_Account__c cashFlowCategory = financingAreaCFCs[i];
            position += 10;

            if (i == financingAreaCFCs.size() - 1) {
                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
                frr.Position__c = position;
                frr.Indent__c = '1';
                frr.Type__c = FinancialReportRowActions.FRR_TYPE_GL_ACCOUNT;
                frr.Row_Label__c = cashFlowCategory.Name;
                frr.GL_Account__c = cashFlowCategory.Id;
                frr.GL_Account_Variable_1__c = reportOptions.glVariable1;
                frr.GL_Account_Variable_2__c = reportOptions.glVariable2;
                frr.GL_Account_Variable_3__c = reportOptions.glVariable3;
                frr.GL_Account_Variable_4__c = reportOptions.glVariable4;
                frw.rowList.add(frr);
            }
            else {
                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
                frr.Position__c = position;
                frr.Indent__c = '1';
                frr.Type__c = FinancialReportRowActions.FRR_TYPE_GL_ACCOUNT;
                frr.Row_Label__c = cashFlowCategory.Name;
                frr.GL_Account__c = cashFlowCategory.Id;
                frr.GL_Account_Variable_1__c = reportOptions.glVariable1;
                frr.GL_Account_Variable_2__c = reportOptions.glVariable2;
                frr.GL_Account_Variable_3__c = reportOptions.glVariable3;
                frr.GL_Account_Variable_4__c = reportOptions.glVariable4;
                frw.rowList.add(frr);
            }
        }

        endCalculationPosition = position;

        frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
        position += 10;
        frr.Position__c = position;
        frr.Type__c = FinancialReportRowActions.FRR_TYPE_CALCULATION_NUMBER;
        frr.Row_Label__c = 'Net cash flow from Financing Activities';
        frr.Calculation__c = '{r' + startCalculationPosition + ':r' + endCalculationPosition + '}';
        frw.rowList.add(frr);

        frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
        position += 10;
        frr.Position__c = position;
        frr.Type__c = FinancialReportRowActions.FRR_TYPE_BLANK;
        frw.rowList.add(frr);

        frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
        position += 10;
        Integer endingCashBalancePosition = position + 10 + 10;//second row after this
        frr.Position__c = position;
        frr.Type__c = FinancialReportRowActions.FRR_TYPE_CALCULATION_NUMBER;
        frr.Row_Label__c = 'Net increase (decrease) in cash';
        frr.Calculation__c =
            '{r' + endingCashBalancePosition + '} - {r' + beginningBalancePosition + '}';
        frw.rowList.add(frr);

        frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
        position += 10;
        frr.Position__c = position;
        frr.Type__c = FinancialReportRowActions.FRR_TYPE_BLANK;
        frw.rowList.add(frr);

        frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
        position += 10;
        frr.Position__c = position;
        frr.Type__c = FinancialReportRowActions.FRR_TYPE_REPORTING_GROUP;
        frr.GL_Account_Reporting_Group__c = reportOptions.tempGLAccountReportingGroupId;
        frr.Row_Label__c = 'Ending Cash Balance';
        frr.GL_Account_Variable_1__c = reportOptions.glVariable1;
        frr.GL_Account_Variable_2__c = reportOptions.glVariable2;
        frr.GL_Account_Variable_3__c = reportOptions.glVariable3;
        frr.GL_Account_Variable_4__c = reportOptions.glVariable4;
        frw.rowList.add(frr);

        //COLUMNS
        Financial_Report_Column__c fcd;

        if (reportOptions.showAllPeriods) {
            Integer y = -(columnCount-1);
            for (Integer i = 0; i < columnCount; i++) {
                fcd = new Financial_Report_Column__c(Financial_Report_Definition__c = frd.Id);
                fcd.Ledger__c = reportOptions.ledger;
                fcd.Position__c = i;
                fcd.Type__c = FinancialReportColumnActions.FRC_TYPE_CURRENT_PERIOD;
                fcd.Offset__c = y;
                fcd.Header_1_Value__c = 'Period Name';
                frw.colList.add(fcd);
                y++;
            }
        }
        else {
            fcd = new Financial_Report_Column__c(Financial_Report_Definition__c = frd.Id);
            fcd.Ledger__c = reportOptions.ledger;
            fcd.Position__c = 0;
            fcd.Type__c = FinancialReportColumnActions.FRC_TYPE_CURRENT_PERIOD;
            fcd.Offset__c = 0;
            fcd.Header_1_Value__c = 'Period Name';
            frw.colList.add(fcd);
        }

        fcd = new Financial_Report_Column__c(Financial_Report_Definition__c = frd.Id);
        fcd.Ledger__c = reportOptions.ledger;
        fcd.Position__c = columnCount;
        fcd.Type__c = FinancialReportColumnActions.FRC_TYPE_YEAR_TO_DATE;
        fcd.Offset__c = 0;
        fcd.Header_1_Value__c = 'Text';
        fcd.Header_1__c = FinancialReportColumnActions.FRC_TYPE_YEAR_TO_DATE;
        frw.colList.add(fcd);

        return frw;
    }

}