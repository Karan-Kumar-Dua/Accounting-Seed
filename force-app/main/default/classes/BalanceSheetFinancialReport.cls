public with sharing class BalanceSheetFinancialReport extends AbstractFinancialReport {

    public static final String DUMMY_ASSETS_GL_ACCOUNT = 'Dummy Assets GL Account';
    public static final String DUMMY_LIABILITIES_GL_ACCOUNT = 'Dummy Liabilities GL Account';
    public static final String DUMMY_OWNERS_GL_ACCOUNT = 'Dummy Owners Equity GL Account';

    public override FinancialReportWrapper runReport(FinancialReportOptions reportOptions) {
        reportOptions.glAccounts = new List<GL_Account__c>();
        reportOptions.includeSubType1 = reportOptions.includeSubType2;

        for (GL_Account__c glAcct : DomainUtils.getGlAccountsForBalanceSheetReport(reportOptions.includeSubType1)) {
            reportOptions.glAccounts.add(glAcct);
        }

        Integer reportRowLimit = (REPORT_CELL_LIMIT / (reportOptions.getListOfPeriodNames().size() + 1));
        Integer estimatedNumberOfRows = getEstimatedNumberOfRowsForBalanceSheet(
            reportOptions.glAccounts, reportOptions.includeSubType1
        );

        if (estimatedNumberOfRows > reportRowLimit || reportOptions.suppressZeroAmountRows) {
            Set<Id> glAccountIds = new Set<Id>();
            for (AggregateResult ar : DomainUtils.getNonZeroGlAccountsBalanceSheet(reportOptions)) {
                glAccountIds.add((Id) ar.get('glAccount'));
            }
            reportOptions.glAccounts = DomainUtils.getGlAccountsForBalanceSheetReportId(reportOptions.includeSubType1, glAccountIds);
            //if Suppress Zero Rows was not checked on UI but the quantity of rows is greater than limit
            //we will enforce suppression of zero rows
            reportOptions.suppressZeroAmountRows = true;
        }

        if (reportOptions.glAccounts.isEmpty()) {
            throw new ReportRowException(NO_NON_ZERO_ROWS_ERROR);
        }

        estimatedNumberOfRows = getEstimatedNumberOfRowsForBalanceSheet(
            reportOptions.glAccounts, reportOptions.includeSubType1
        );

        if (estimatedNumberOfRows > reportRowLimit) {
            throw new ReportRowException(TOO_MANY_ROWS_ERROR);
        }

        if (reportOptions.suppressZeroAmountRows && !isAssetsGlAccountExisted(reportOptions.glAccounts)) {
            reportOptions.glAccounts.add(
                new GL_Account__c(
                    Id = FinancialSuiteUtils.getFakeId(GL_Account__c.SObjectType),
                    Name = DUMMY_ASSETS_GL_ACCOUNT,
                    Type__c = GLAccountActions.GL_ACCOUNT_TYPE_BALANCE_SHEET,
                    Sub_Type_1__c = GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_ASSETS
                )
            );
        }

        if (reportOptions.suppressZeroAmountRows && !isLiabilitiesGlAccountExisted(reportOptions.glAccounts)) {
            reportOptions.glAccounts.add(
                new GL_Account__c(
                    Id = FinancialSuiteUtils.getFakeId(GL_Account__c.SObjectType),
                    Name = DUMMY_LIABILITIES_GL_ACCOUNT,
                    Type__c = GLAccountActions.GL_ACCOUNT_TYPE_BALANCE_SHEET,
                    Sub_Type_1__c = GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_LIABILITIES
                )
            );
        }

        if (reportOptions.suppressZeroAmountRows && !isOwnersEquityGlAccountExisted(reportOptions.glAccounts)) {
            reportOptions.glAccounts.add(
                new GL_Account__c(
                    Id = FinancialSuiteUtils.getFakeId(GL_Account__c.SObjectType),
                    Name = DUMMY_OWNERS_GL_ACCOUNT,
                    Type__c = GLAccountActions.GL_ACCOUNT_TYPE_BALANCE_SHEET,
                    Sub_Type_1__c = GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_OWNERS_EQUITY
                )
            );
        }

        this.reportOptions = reportOptions;
        return super.generateReport();
    }

    public override FinancialReportWrapper createReportDefinition() {
        Integer columnCount = (reportOptions != null && reportOptions.getListOfPeriodNames() != NULL ? reportOptions.getListOfPeriodNames().size() : 0);
        List<GL_Account__c> glAccountList = new List<GL_Account__c>();
        List<GL_Account__c> assets = new List<GL_Account__c>();
        List<GL_Account__c> liabilities = new List<GL_Account__c>();
        List<GL_Account__c> owners = new List<GL_Account__c>();

        for (GL_Account__c glAcct : reportOptions.glAccounts) {
            if (glAcct.Sub_Type_1__c == GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_ASSETS) {
                assets.add(glAcct);
            }
            if (glAcct.Sub_Type_1__c == GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_LIABILITIES) {
                liabilities.add(glAcct);
            }
            if (glAcct.Sub_Type_1__c == GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_OWNERS_EQUITY) {
                owners.add(glAcct);
            }
        }

        glAccountList.addAll(orderBySubType2NullsLast(assets));
        glAccountList.addAll(orderBySubType2NullsLast(liabilities));
        glAccountList.addAll(orderBySubType2NullsLast(owners));

        FinancialReportWrapper frw = new FinancialReportWrapper();
        //wrapper's property to specify Landscape or Portrait View when the report will be rendered as PDF
        frw.viewModeInPDF = columnCount < 5 ? 'Portrait' : 'Landscape';
        //================================================================================================
        String currentType = NULL;
        Financial_Report_Definition__c frd = new Financial_Report_Definition__c(
            Name = reportOptions.getReportTypeName(),
            Subtitle__c = reportOptions.getReportSubtitle()
        );
        
        frw.reportDefinition = frd;
        
        Financial_Report_Row__c frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
        Integer position = 10;
        Integer totalLiabilityRow = 0;
        Integer totalEquityRow = 0;
        String typeRowCalculation = '';

        String subType1 = NULL;
        Integer indentSpaces = 1;
        Integer glAccountIndent = indentSpaces;
        Integer subType1Indent = indentSpaces;
        Boolean suppressEmptyOwnersTotal = true;

        glAccountIndent += (reportOptions.includeSubType1 != NULL && reportOptions.includeSubType1 ? indentSpaces : 0);

        Integer subType1Count = 0;

        for (GL_Account__c glAcct : glAccountList) {

            String currentSubType2 = glAcct.Sub_Type_2__c == NULL ? 'Uncategorized' : glAcct.Sub_Type_2__c;

            if ((subType1 != currentSubType2 && subType1 != NULL && reportOptions.includeSubType1)
                    || (currentType != glAcct.Sub_Type_1__c && reportOptions.includeSubType1 && subType1 != null)) {

                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
                position += 10;
                frr.Position__c = position;
                frr.Indent__c = String.valueOf(subType1Indent + 1);
                frr.Type__c = FinancialReportRowActions.FRR_TYPE_CALCULATION_NUMBER;
                frr.Calculation__c = '{r' + (position - (subType1Count * 10)) + ':r' + (position - 10) + '}';
                typeRowCalculation += '{r' + position + '}+';
                frr.Row_Label__c = 'Total ' + subType1;
                frw.rowList.add(frr);
            }
            if (currentType == NULL) {
                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
                position += 10;
                frr.Position__c = position;
                typeRowCalculation = reportOptions.includeSubType1 ? '' : '{r' + (position + 10) + ':r';
                frr.Type__c = FinancialReportRowActions.FRR_TYPE_DESCRIPTION;
                frr.Row_Label__c = glAcct.Sub_Type_1__c;
                frw.rowList.add(frr);
                currentType = glAcct.Sub_Type_1__c;
            }
            if (currentType != glAcct.Sub_Type_1__c) {
                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
                position += 10;
                frr.Position__c = position;
                frr.Indent__c = String.valueOf(indentSpaces);
                frr.Row_Label__c = 'Total ' + currentType;
                frr.Type__c = FinancialReportRowActions.FRR_TYPE_CALCULATION_NUMBER;
                frr.Calculation__c = reportOptions.includeSubType1 ? typeRowCalculation + ('{r' + position + '}') : (typeRowCalculation + (position - 10) + '}');
                frw.rowList.add(frr);

                totalLiabilityRow = currentType == GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_LIABILITIES ? position : 0;

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
                frr.Row_Label__c = glAcct.Sub_Type_1__c;   
                frw.rowList.add(frr);
                
                currentType = glAcct.Sub_Type_1__c;
                subType1 = NULL;
                typeRowCalculation = reportOptions.includeSubType1 ? '' : '{r' + (position + 10) + ':r';
            }

            if (subType1 != currentSubType2 && reportOptions.includeSubType1 && !isFakeGLAccount(glAcct)) {
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
                frr.Row_Label__c = glAcct.Sub_Type_2__c == NULL ? 'Uncategorized' : glAcct.Sub_Type_2__c;
                frw.rowList.add(frr);
                subType1 = glAcct.Sub_Type_2__c == NULL ? 'Uncategorized' : glAcct.Sub_Type_2__c;
                subType1Count = 0;

                if (glAcct.Sub_Type_1__c != NULL && glAcct.Sub_Type_1__c == GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_OWNERS_EQUITY) {
                    suppressEmptyOwnersTotal = false;
                }
            }
            
            frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
            position += 10;
            frr.Position__c = position;
            frr.Indent__c = String.valueOf(glAccountIndent);
            frr.GL_Account__c = glAcct.Id;
            frr.Type__c = FinancialReportRowActions.FRR_TYPE_GL_ACCOUNT;
            frr.GL_Account_Variable_1__c = reportOptions.glVariable1;
            frr.GL_Account_Variable_2__c = reportOptions.glVariable2;
            frr.GL_Account_Variable_3__c = reportOptions.glVariable3;
            frr.GL_Account_Variable_4__c = reportOptions.glVariable4;
            frr.Row_Label__c = glAcct.Name;
            if (glAcct.Sub_Type_1__c == GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_ASSETS) {
                frr.Normal_Balance__c = FinancialReportRowActions.FRR_NORMAL_BALANCE_DEBIT;
            }  
            else {
                frr.Normal_Balance__c = FinancialReportRowActions.FRR_NORMAL_BALANCE_CREDIT;
            }

            frw.rowList.add(frr);
            subType1Count++;
        }

        if (reportOptions.includeSubType1 && includeTotal(subType1, suppressEmptyOwnersTotal)) {
            frr = new Financial_Report_Row__c(Financial_Report_Definition__c = frd.Id);
            position += 10;
            frr.Position__c = position;
            frr.Indent__c = String.valueOf(subType1Indent + 1);
            frr.Type__c = FinancialReportRowActions.FRR_TYPE_CALCULATION_NUMBER;
            frr.Calculation__c = '{r' + (position-(subType1Count * 10)) + ':r' + (position - 10) + '}';
            typeRowCalculation += '{r' + position + '}+';
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
        frr.Position__c = position;
        frr.Indent__c = String.valueOf(indentSpaces);
        frr.Row_Label__c = 'Total ' + currentType;
        frr.Type__c = FinancialReportRowActions.FRR_TYPE_CALCULATION_NUMBER;
        totalEquityRow = currentType == GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_OWNERS_EQUITY ? position : 0;
        frr.Calculation__c = reportOptions.includeSubType1 ? typeRowCalculation.removeEnd('+') : typeRowCalculation + (position - 30) + '}';
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
        frr.Position__c = position;
        frr.Row_Label__c = 'Total Liabilities & Equity';
        frr.Type__c = FinancialReportRowActions.FRR_TYPE_CALCULATION_NUMBER;
        frr.Calculation__c = '{r' + totalLiabilityRow + '}+{r' + totalEquityRow + '}';   
        frw.rowList.add(frr);
        currentType = GLAccountActions.GL_ACCOUNT_TYPE_EXPENSE;
        
        for (Integer i = 0; i < columnCount; i++) {
            Financial_Report_Column__c fcd = new Financial_Report_Column__c(Financial_Report_Definition__c = frd.Id);
            fcd.Ledger__c =  reportOptions.ledger;
            fcd.Position__c = i;
            fcd.Type__c = FinancialReportColumnActions.FRC_TYPE_YEAR_TO_DATE;
            fcd.Offset__c = i;
            fcd.Header_1_Value__c = 'Period Name';

            frw.colList.add(fcd);
        }
        
        return frw;
    }

    private Boolean isFakeGLAccount(GL_Account__c glAcct) {
        return glAcct.Name == DUMMY_ASSETS_GL_ACCOUNT
            || glAcct.Name == DUMMY_LIABILITIES_GL_ACCOUNT
            || glAcct.Name == DUMMY_OWNERS_GL_ACCOUNT;
    }

    private List<GL_Account__c> orderBySubType2NullsLast(List<GL_Account__c> sourceList) {
        List<GL_Account__c> result = new List<GL_Account__c>();
        List<GL_Account__c> glAccountSubtype2Null = new List<GL_Account__c>();
        for (GL_Account__c glAccount : sourceList) {
            if (reportOptions.includeSubType1 && glAccount.Sub_Type_2__c == null) {
                glAccountSubtype2Null.add(glAccount);
            }
            else {
                result.add(glAccount);
            }
        }
        result.addAll(glAccountSubtype2Null);
        return result;
    }

}