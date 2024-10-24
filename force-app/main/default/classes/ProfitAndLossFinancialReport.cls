public with sharing class ProfitAndLossFinancialReport extends AbstractFinancialReport {

    public override FinancialReportWrapper runReport(FinancialReportOptions reportOptions) {
        reportOptions.glAccounts = new List<GL_Account__c>();
        for (GL_Account__c glAcct : DomainUtils.getGlAccountsForProfitAndLossReport(reportOptions.includeSubType1,
                                                                                    reportOptions.includeSubType2)) {

            reportOptions.glAccounts.add(glAcct);
        }

        Integer reportRowLimit = (REPORT_CELL_LIMIT / (reportOptions.getListOfPeriodNames().size() + 2));
        Integer estimatedNumberOfRows = getEstimatedNumberOfRowsForProfitAndLoss(
            reportOptions.glAccounts, reportOptions.includeSubType1, reportOptions.includeSubType2
        );

        if (estimatedNumberOfRows > reportRowLimit || reportOptions.suppressZeroAmountRows) {
            Set<Id> glAccountIds = new Set<Id>();
            for (AggregateResult ar : DomainUtils.getNonZeroGlAccountsProfitAndLoss(reportOptions)) {
                glAccountIds.add((Id) ar.get('glAccount'));
            }

            reportOptions.glAccounts = DomainUtils.getGlAccountsForProfitAndLossReportById(
                reportOptions.includeSubType1, reportOptions.includeSubType2, glAccountIds
            );

            //if Suppress Zero Rows was not checked on UI but the quantity of rows is greater than limit
            //we will enforce suppression of zero rows
            reportOptions.suppressZeroAmountRows = true;
        }

        if (reportOptions.glAccounts.isEmpty()) {
            throw new ReportRowException(NO_NON_ZERO_ROWS_ERROR);
        }

        estimatedNumberOfRows = getEstimatedNumberOfRowsForProfitAndLoss(
            reportOptions.glAccounts, reportOptions.includeSubType1, reportOptions.includeSubType2
        );

        if (estimatedNumberOfRows > reportRowLimit) {
            throw new ReportRowException(TOO_MANY_ROWS_ERROR);
        }

        if (!checkTypePicklistIsOrderedCorrectly()) {
            reportOptions.glAccounts = doCustomOrdering(reportOptions.glAccounts);
        }

        if (reportOptions.suppressZeroAmountRows && !isExpenseGLAccountExisted(reportOptions.glAccounts)) {
            reportOptions.glAccounts.add(createDummyExpenseGLAccount());
        }

        this.reportOptions = reportOptions;

        return super.generateReport();
    }
    
    public override FinancialReportWrapper createReportDefinition() {
        Integer columnCount =  (reportOptions != null && reportOptions.getListOfPeriodNames() != null ? reportOptions.getListOfPeriodNames().size() : 0);
        List<GL_Account__c> glAccountList = new List<GL_Account__c>();
        List<GL_Account__c> glAccountSubtype1Null = new List<GL_Account__c>();
        List<GL_Account__c> glAccountSubtype2Null = new List<GL_Account__c>();

        String type = GLAccountActions.GL_ACCOUNT_TYPE_REVENUE;
        String subType1 = null;
        String subType2 = null;
        /*
            Salesforce does not provide a means to sort picklists with nulls last. This code section sorts with nulls last
            if the subtype1 or subtype2 grouping is selected
        */
        for (GL_Account__c glAcct : reportOptions.glAccounts) {

            if (reportOptions.includeSubType1 && (subType1 == null || subType1 != glAcct.Sub_Type_1__c)) {
                subType1 = glAcct.Sub_Type_1__c;
                glAccountList.addAll(glAccountSubtype2Null);
                glAccountSubtype2Null.clear();
            }

            if (reportOptions.includeSubType1 && type != glAcct.Type__c) {
                type = glAcct.Type__c;
                glAccountList.addAll(glAccountSubtype1Null);
                glAccountSubtype1Null.clear();
            }

            if (reportOptions.includeSubType1 && glAcct.Sub_Type_1__c == null) {
                glAccountSubtype1Null.add(glAcct);
            }
            else if (reportOptions.includeSubType2 && glAcct.Sub_Type_2__c == null) {
                glAccountSubtype2Null.add(glAcct);
            } 
            else {
                glAccountList.add(glAcct);
            }
        }

        glAccountList.addAll(glAccountSubtype2Null);
        glAccountList.addAll(glAccountSubtype1Null);

        FinancialReportWrapper frw = new FinancialReportWrapper();
        //wrapper's property to specify Landscape or Portrait View when the report will be rendered as PDF
        frw.viewModeInPDF = columnCount < 5 ? 'Portrait' : 'Landscape';
        //================================================================================================
        String currentType = GLAccountActions.GL_ACCOUNT_TYPE_REVENUE;
        Financial_Report_Definition__c frd = new Financial_Report_Definition__c(
            Name = reportOptions.getReportTypeName(),
            Subtitle__c = reportOptions.getReportSubtitle()
        );
        
        frw.reportDefinition = frd;
        
        Financial_Report_Row__c frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
        Integer position = 10;
        Integer totalRevenueRow = 0;
        Integer totalExpenseRow = 0;
        
        frr.Position__c = position;
        frr.Type__c = FinancialReportRowActions.FRR_TYPE_DESCRIPTION;
        frr.Row_Label__c = GLAccountActions.GL_ACCOUNT_TYPE_REVENUE;
        frw.rowList.add(frr);

        subType1 = null;
        Integer indentSpaces = 1;
        Integer glAccountIndent = indentSpaces;  
        Integer subType1Indent = indentSpaces;
        Integer subType2Indent = indentSpaces + indentSpaces;
        
        glAccountIndent += (reportOptions.includeSubType1 ? indentSpaces : 0);
        glAccountIndent += (reportOptions.includeSubType2 ? indentSpaces : 0);
        
        Integer subType1Count = 0;

        subType2 = null;
        Integer subType2Count = 0;
        String calculationTotal = '';
        String calculationSubType1 = '';
        String calculationSubType2 = '';
        Integer startExpensePosition;
        Boolean suppressEmptyTotal = true;
        String lastSubType1Included = '';
        String lastSubType2Included = '';

        for (GL_Account__c glAcct : glAccountList) {
            lastSubType1Included = '';
            lastSubType2Included = '';

            String currentSubType1 = glAcct.Sub_Type_1__c == null ? 'Uncategorized' : glAcct.Sub_Type_1__c;
            String currentSubType2 = glAcct.Sub_Type_2__c == null ? 'Uncategorized' : glAcct.Sub_Type_2__c;

            // used for Uncategorized ST1 and ST2 after empty ST2 category. Edge use case when  Gl account has only ST1 but next one has empty ST1 and ST2.
            // In this case, both GL Accounts mark as Uncategorized.
            Boolean isUncategorizedCondition = (currentSubType1 == currentSubType2 && currentSubType2 == 'Uncategorized' && subType1 != 'Uncategorized')
                || (currentSubType2 == 'Uncategorized' && subType1 == currentSubType2 && subType2 == currentSubType2 && currentSubType1 != currentSubType2);

            if ((subType2 != currentSubType2 || isUncategorizedCondition)
                && subType2 != null
                && reportOptions.includeSubType2
                && (!isFakeGLAccount(glAcct) || String.isNotBlank(calculationSubType2))) {

                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
                position += 10;
                frr.Position__c = position;
                frr.Indent__c = String.valueOf(subType2Indent + 1);
                frr.Type__c = FinancialReportRowActions.FRR_TYPE_CALCULATION_NUMBER;
                frr.Calculation__c = calculationSubType2.removeEnd('+');
                calculationSubType2 = '';
                frr.Row_Label__c = 'Total ' + subType2;
                frw.rowList.add(frr);
                lastSubType2Included = subType2;
            }

            if (subType1 != currentSubType1
                && subType1 != null
                && reportOptions.includeSubType1
                && (!isFakeGLAccount(glAcct) || String.isNotBlank(calculationSubType1))) {

                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
                position += 10;
                frr.Position__c = position;
                frr.Indent__c = String.valueOf(subType1Indent + 1);
                frr.Type__c = FinancialReportRowActions.FRR_TYPE_CALCULATION_NUMBER;
                frr.Calculation__c = calculationSubType1.removeEnd('+');
                calculationTotal += '{r' + position + '}+';
                calculationSubType1 = '';
                frr.Row_Label__c = 'Total ' + subType1;
                frw.rowList.add(frr);
                lastSubType1Included = subType1;
            }

            if (currentType != glAcct.Type__c) {
                for (Integer i = 0; i <= 1; i++) {
                    frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
                    position += 10;
                    frr.Position__c = position;
                    frr.Type__c = FinancialReportRowActions.FRR_TYPE_BLANK;
                    frw.rowList.add(frr);
                }

                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);

                position += 10;
                frr.Position__c = totalRevenueRow = position;
                frr.Indent__c = String.valueOf(indentSpaces);
                frr.Row_Label__c = 'Total Revenue';
                frr.Type__c = FinancialReportRowActions.FRR_TYPE_CALCULATION_NUMBER;
                frr.Calculation__c = reportOptions.includeSubType1 ? calculationTotal.removeEnd('+') : '{r20:r' + (position - 30) + '}';
                calculationTotal = calculationSubType1 = calculationSubType2 = '';
                frw.rowList.add(frr);

                currentType = GLAccountActions.GL_ACCOUNT_TYPE_EXPENSE;

                for (Integer i = 0; i <= 1; i++) {
                    frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
                    position += 10;
                    frr.Position__c = position;
                    frr.Type__c = FinancialReportRowActions.FRR_TYPE_BLANK;
                    frw.rowList.add(frr);
                }

                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
                position += 10;
                frr.Position__c = position;
                frr.Type__c = FinancialReportRowActions.FRR_TYPE_DESCRIPTION;
                frr.Row_Label__c = GLAccountActions.GL_ACCOUNT_TYPE_EXPENSE;
                frw.rowList.add(frr);
                subType1 = null;
                subType2 = null;

                startExpensePosition = position + 10;
            }

            if (subType1 != currentSubType1 && reportOptions.includeSubType1 && !isFakeGLAccount(glAcct)) {
                for (Integer i = 0; i <= 1; i++) {
                    frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
                    position += 10;
                    frr.Position__c = position;
                    frr.Type__c = FinancialReportRowActions.FRR_TYPE_BLANK;
                    frw.rowList.add(frr);
                }
                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
                position += 10;
                frr.Position__c = position;
                frr.Indent__c = String.valueOf(subType1Indent);
                frr.Type__c = FinancialReportRowActions.FRR_TYPE_DESCRIPTION;
                frr.Row_Label__c = glAcct.Sub_Type_1__c == null ? 'Uncategorized' : glAcct.Sub_Type_1__c;
                frw.rowList.add(frr);
                subType1 = glAcct.Sub_Type_1__c == null ? 'Uncategorized' : glAcct.Sub_Type_1__c;
                subType1Count = 0;
                suppressEmptyTotal = false;
            }

            if ((subType2 != currentSubType2 || isUncategorizedCondition)
                && reportOptions.includeSubType2
                && !isFakeGLAccount(glAcct)) {
                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
                position += 10;
                frr.Position__c = position;
                frr.Indent__c = String.valueOf(subType2Indent);
                frr.Type__c = FinancialReportRowActions.FRR_TYPE_DESCRIPTION;
                frr.Row_Label__c = glAcct.Sub_Type_2__c == null ? 'Uncategorized' : glAcct.Sub_Type_2__c;
                frw.rowList.add(frr);
                subType2 = glAcct.Sub_Type_2__c == null ? 'Uncategorized' : glAcct.Sub_Type_2__c;
                subType2Count = 0;
                suppressEmptyTotal = false;
            }

            frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
            position += 10;
            frr.Position__c = position;
            frr.Indent__c = String.valueOf(glAccountIndent);
            frr.GL_Account__c = glAcct.Id;
            frr.GL_Account_Variable_1__c = reportOptions.glVariable1;
            frr.GL_Account_Variable_2__c = reportOptions.glVariable2;
            frr.GL_Account_Variable_3__c = reportOptions.glVariable3;
            frr.GL_Account_Variable_4__c = reportOptions.glVariable4;
            frr.Type__c = FinancialReportRowActions.FRR_TYPE_GL_ACCOUNT;
            frr.Row_Label__c = glAcct.Name;
            frr.Normal_Balance__c = currentType == GLAccountActions.GL_ACCOUNT_TYPE_REVENUE
                ? FinancialReportRowActions.FRR_NORMAL_BALANCE_CREDIT
                : FinancialReportRowActions.FRR_NORMAL_BALANCE_DEBIT;

            calculationSubType1 += '{r' + position + '}+';
            calculationSubType2 += '{r' + position + '}+';
            frw.rowList.add(frr);
            subType1Count++;
            subType2Count++;
        }

        if (reportOptions.includeSubType2 && includeTotal(subType2, suppressEmptyTotal)) {
            frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
            position += 10;
            frr.Position__c = position;
            frr.Indent__c = String.valueOf(subType2Indent + 1);
            frr.Type__c = FinancialReportRowActions.FRR_TYPE_CALCULATION_NUMBER;
            frr.Calculation__c = calculationSubType2.removeEnd('+');
            frr.Row_Label__c = 'Total ' + subType2;
            frw.rowList.add(frr);
        }

        if (reportOptions.includeSubType1 && includeTotal(subType1, suppressEmptyTotal) && !isLastSubTypeIncluded(subType1, lastSubType1Included)) {
            frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
            position += 10;
            frr.Position__c = position;
            frr.Indent__c = String.valueOf(subType1Indent + 1);
            frr.Type__c = FinancialReportRowActions.FRR_TYPE_CALCULATION_NUMBER;
            frr.Calculation__c = calculationSubType1.removeEnd('+');
            calculationTotal += '{r' + position + '}+';
            frr.Row_Label__c = 'Total ' + subType1;
            frw.rowList.add(frr);
        }

        for (Integer i = 0; i <= 1; i++) {
            frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
            position += 10;
            frr.Position__c = position;
            frr.Type__c = FinancialReportRowActions.FRR_TYPE_BLANK;
            frw.rowList.add(frr);
        }

        frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
        position += 10;
        frr.Position__c = totalExpenseRow = position;
        frr.Indent__c = String.valueOf(indentSpaces);
        frr.Row_Label__c = 'Total Expense';
        frr.Type__c = FinancialReportRowActions.FRR_TYPE_CALCULATION_NUMBER;
        frr.Calculation__c = reportOptions.includeSubType1 ? calculationTotal.removeEnd('+') : '{r' + startExpensePosition + ':r' + (position - 30) + '}';
        frw.rowList.add(frr);

        for (Integer i = 0; i <= 1; i++) {
            frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
            position += 10;
            frr.Position__c = position;
            frr.Type__c = FinancialReportRowActions.FRR_TYPE_BLANK;
            frw.rowList.add(frr);
        }

        frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
        position += 10;
        frr.Position__c = totalExpenseRow = position;
        frr.Row_Label__c = 'Net Income';
        frr.Type__c = FinancialReportRowActions.FRR_TYPE_CALCULATION_NUMBER;
        frr.Calculation__c = '{r' + totalRevenueRow + '}-{r' + (totalExpenseRow - 30) + '}';
        frw.rowList.add(frr);
        currentType = GLAccountActions.GL_ACCOUNT_TYPE_EXPENSE;

        for (Integer i = 0; i < columnCount; i++) {
            Financial_Report_Column__c fcd = new Financial_Report_Column__c(Financial_Report_Definition__c = frd.Id);
            fcd.Ledger__c = reportOptions.ledger;
            fcd.Position__c = i;
            fcd.Type__c = FinancialReportColumnActions.FRC_TYPE_CURRENT_PERIOD;
            fcd.Offset__c = i;
            fcd.Header_1_Value__c = 'Text';
            fcd.Header_1_Value__c = 'Period Name';
            frw.colList.add(fcd);
        }

        Financial_Report_Column__c fcd = new Financial_Report_Column__c(Financial_Report_Definition__c = frd.Id);
        fcd.Ledger__c = reportOptions.ledger;
        fcd.Position__c = columnCount;
        fcd.Type__c = FinancialReportColumnActions.FRC_TYPE_CALCULATION_NUMBER;
        fcd.Calculation__c = '{c0:c' + columnCount + '}';
        fcd.Offset__c = columnCount;
        fcd.Header_1_Value__c = 'Text';
        fcd.Header_1__c = 'Total';
        fcd.Column_Overide_Row__c = true;
        frw.colList.add(fcd);

        return frw;
    }

    private Boolean isFakeGLAccount(GL_Account__c glAcct) {
        return glAcct.Name == 'Dummy GL Account';
    }

}