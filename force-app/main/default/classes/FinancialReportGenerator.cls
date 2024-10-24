public with sharing class FinancialReportGenerator {

    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    //Report definition data
    private Financial_Report_Definition__c reportDefinition;
    private Set<Id> reportingGroupIds = new Set<Id>();

    private List<Financial_Report_Row__c> rowList = new List<Financial_Report_Row__c>();
    private List<Financial_Report_Column__c> colList = new List<Financial_Report_Column__c>();

    @TestVisible
    private Map<Integer, Financial_Report_Row__c> rowMap = new Map<Integer, Financial_Report_Row__c>();
    @TestVisible
    private Map<Integer, Financial_Report_Column__c> colMap = new Map<Integer, Financial_Report_Column__c>();
    @TestVisible
    private Map<String, List<String>> reportingGroupMap = new Map<String, List<String>>();

    //used to check actual period transaction in case of balance sheet report
    @TestVisible
    private Map<Integer,Decimal> periodBalMap = new Map<Integer,Decimal>();
    //Results
    @TestVisible
    private Financial_Report_Result__c reportResult;
    private FinancialReportWrapper frw;
    @TestVisible
    private Map<String, Decimal> rowColMap = new Map<String, Decimal>();

    public List<Financial_Report_Result_Value__c> reportValues {get; private set;}
    public FinancialReportOptions reportOptions;
    //Balances
    public BalanceBuilder balanceBuilderInstance;
    public class FinancialReportGeneratorException extends Exception {}
    private Id currentYearEarningsGLAccountId;
    private Id retainedEarningsGLAccountId;


    //Constructor
    public FinancialReportGenerator(FinancialReportWrapper frw, FinancialReportOptions reportOptions) {
        reportValues = new List<Financial_Report_Result_Value__c>();
        this.reportOptions = reportOptions;
        this.balanceBuilderInstance = new BalanceBuilder(reportOptions.isTrialBalanceForTranslatedBase());
        this.frw = frw;
        this.reportDefinition = frw.reportDefinition;
        this.rowList = frw.rowList;
        this.colList = frw.colList;
        Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(reportOptions.ledger);
        currentYearEarningsGLAccountId = defaultsBySpecDevNames?.get(GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT)?.GL_Account__c;
        retainedEarningsGLAccountId = defaultsBySpecDevNames?.get(GLAccountDefaultsHandler.RETAINED_EARNINGS_GL_ACCOUNT)?.GL_Account__c;
    }

    public Id createFinReportResult() {
        try {
            reportResult = new Financial_Report_Result__c();
            reportResult.Financial_Report_Definition__c = reportDefinition.Id;
            reportResult.Status__c = 'Running';
            reportResult.Run_Started__c = System.now();
            reportResult.GL_Account_Variable_1__c = reportOptions.glVariable1;
            reportResult.GL_Account_Variable_2__c = reportOptions.glVariable2;
            reportResult.GL_Account_Variable_3__c = reportOptions.glVariable3;
            reportResult.GL_Account_Variable_4__c = reportOptions.glVariable4;
            reportResult.Ledger__c = reportOptions.ledger;
            reportResult.Rounding__c = reportOptions.currentRoundingMode;
            reportResult.Include_Sub_Type_1__c = reportOptions.includeSubType1;
            reportResult.Include_Sub_Type_2__c = reportOptions.includeSubType2;
            reportResult.Subtitle__c = reportOptions.subtitle;
            reportResult.Suppress_Zero_Amount_Rows__c = reportOptions.suppressZeroAmountRows;
            reportResult.Suppress_Opening_Balance_and_Period__c = reportOptions.suppressOpeningBalanceAndPeriodColumns == null ? false: reportOptions.suppressOpeningBalanceAndPeriodColumns ;
           
            if(reportOptions.reportType == FinancialReportOptions.FinancialReportType.PROFIT_AND_LOSS_VS_BUDGET){
                reportResult.Budget_Ledger__c = ((ProfitAndLossVsBudgetFinReptOptions)reportOptions).budgetLedger;
                reportResult.Show_All_Periods__c = ((ProfitAndLossVsBudgetFinReptOptions)reportOptions).showAllPeriods;
            }
           
            if(reportOptions.reportType == FinancialReportOptions.FinancialReportType.CASH_FLOW){
                reportResult.Show_All_Periods__c = ((CashFlowFinancialReportOptions)reportOptions).showAllPeriods;
            }

            setAccountingPeriod();

            if (!reportOptions.getListOfPeriodNames().isEmpty()
                && AccountingPeriodHandler.getInstance().getAccountingPeriodByName(reportOptions.getListOfPeriodNames()[reportOptions.getListOfPeriodNames().size() - 1]) != null) {
                reportResult.End_Accounting_Period__c =
                    AccountingPeriodHandler.getInstance().getAccountingPeriodByName(reportOptions.getListOfPeriodNames()[reportOptions.getListOfPeriodNames().size() - 1]).Id;
            }

            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                reportResult.put('CurrencyIsoCode', reportOptions.currencyISO);
            }

            SFDCSecurityUtils.insertProxy(reportResult);

            if (reportResult.Id != null) {
                return reportResult.Id;
            }
        }
        catch (Exception ex) {
            throw ex;
        }
        return null;
    }
    
    //Create the stub report with the stubs for the values as well
    public void createReportStub() {
        try {
            //Create the stub result values with the appropriate parameters copied over.
            Integer recNum = 0;
            for (Financial_Report_Column__c c : colList) {

                for (Financial_Report_Row__c r : rowList) {

                    if (r.GL_Account_Reporting_Group__c != null) {
                        reportingGroupIds.add(r.GL_Account_Reporting_Group__c);
                    }

                    Financial_Report_Result_Value__c val = new Financial_Report_Result_Value__c();
                    val.Financial_Report_Result__c = reportResult.Id;
                    val.Financial_Report_Row__c = r.Id;
                    val.Financial_Report_Column__c = c.Id;
                    val.Row_Label__c = r.Row_Label__c;
                    val.Column_Type__c = c.Type__c;
                    val.Row_Type__c = r.Type__c;
                    val.Row_Position__c = r.Position__c;
                    val.Column_Position__c = c.Position__c;
                    val.Underline__c = r.Underline__c;
                    val.Suppress_Print__c = r.Suppress_Print__c || c.Suppress_Print__c ? true : false;
                    val.Column_Override_Row__c = c.Column_Overide_Row__c;

                    if (r.Indent__c == null) {
                        val.Indent__c = 0;
                    }
                    else {
                        val.Indent__c = Integer.valueOf(r.Indent__c);
                    }

                    if (c.Header_1_Value__c == 'Period Name') {
                        val.Column_Header_1__c =
                            AccountingPeriodHandler.getInstance()
                                .getAccountingPeriodByOffset(reportOptions.startingAccountingPeriod, Integer.valueOf(c.Offset__c))
                                .Name;
                    }
                    else {
                        val.Column_Header_1__c = c.Header_1__c;
                    }

                    if (c.Header_2_Value__c == 'Period Name') {
                        val.Column_Header_2__c =
                            AccountingPeriodHandler.getInstance()
                                .getAccountingPeriodByOffset(reportOptions.startingAccountingPeriod, Integer.valueOf(c.Offset__c))
                                .Name;
                    }
                    else {
                        val.Column_Header_2__c = c.Header_2__c;
                    }

                    reportValues.add(val);
                    colMap.put(recNum, c);
                    rowMap.put(recNum, r);
                    periodBalMap.put(recNum,0);

                    recNum++;
                }

            }

            populateGlAccountReportingGroupMap();
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    private void populateGlAccountReportingGroupMap() {
        try {
            if (!reportingGroupIds.isEmpty()) {
                for (GL_Account_Reporting_Group_Line__c grp : DomainUtils.getGlAccountReportingGroupLinesByMasterId(reportingGroupIds)) {
                    if (reportingGroupMap.containsKey(grp.GL_Account_Reporting_Group__c)) {
                        reportingGroupMap.get(grp.GL_Account_Reporting_Group__c).add(grp.GL_Account__c);
                    }
                    else {
                        reportingGroupMap.put(grp.GL_Account_Reporting_Group__c, new List<String>{grp.GL_Account__c});
                    }
                }
            }
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    public void processCube(SObject s) {
        Financial_Cube__c finCube = (Financial_Cube__c) s;
        balanceBuilderInstance.addCube(finCube);
    }

    public void calculateReportValues() {
        Integer recNum = 0;
        for (Financial_Report_Result_Value__c r : reportValues) {

            Financial_Report_Row__c thisrow = rowMap.get(recNum);
            Financial_Report_Column__c thiscol = colMap.get(recNum);
            Financial_Report_Column__c initialColumn = colMap.get(0);
            List<String> reportingGroupList = reportingGroupMap.get(thisrow.GL_Account_Reporting_Group__c);
            
            ReportValueProcessor.ReportValueCalculationResult result = new ReportValueProcessor(reportOptions, reportingGroupList, balanceBuilderInstance)
                .calculateReportValue(r, thisrow, thiscol, initialColumn, periodBalMap.get(recNum));

            if (result.isSuccess) {
                periodBalMap.put(recNum, result.periodBalance);                                                                                                                        
                if (result.rowColKey != '') {
                    rowColMap.put(result.rowColKey, r.Currency_Value__c);
                }
            }
            
            recNum++;
            //clear out the result object to save heap space
            result = null;
        }
    }

    //START finishReport()
    public void finishReport() {

        try {
            Integer percentageScale =
                (this.reportDefinition.isSet(Financial_Report_Definition__c.Percentage_Decimal_Places__c)
                    && this.reportDefinition.Percentage_Decimal_Places__c != null)
                    ? Integer.valueOf(this.reportDefinition.Percentage_Decimal_Places__c)
                    : 2;
            Integer recNum = 0;
            for (Financial_Report_Result_Value__c r : reportValues) {
                Financial_Report_Row__c thisrow = rowMap.get(recNum);
                Financial_Report_Column__c thiscol = colMap.get(recNum);
                recNum++;

                new ReportValueProcessor(reportOptions, null, balanceBuilderInstance)
                    .performRowAndColumnCalculations(r, thisrow, thiscol, rowColMap, percentageScale);
            }

            //insert reportvalues;
            handleReportValuesInsertion(reportvalues, reportOptions.suppressZeroAmountRows);

            String jsonDefinition = frw != null ? JSON.serialize(frw) : null;

            Attachment attachment = new Attachment();
            attachment.Body = Blob.valueOf(jsonDefinition);
            attachment.Name = String.valueOf('Financial_Report_Definition');
            attachment.ParentId = reportResult.Id; 
            
            SFDCSecurityUtils.insertProxy(attachment);

            setAccountingPeriod();
            reportResult.Run_Finished__c = System.now();
            reportResult.Status__c = 'Complete';
           
            SFDCSecurityUtils.updateProxy(reportResult);

            //remove temp GL Reporting Group
            if (reportOptions.reportType == FinancialReportOptions.FinancialReportType.CASH_FLOW) {
                SFDCSecurityUtils.deleteProxy(
                    new GL_Account_Reporting_Group__c(Id = ((CashFlowFinancialReportOptions) reportOptions).tempGLAccountReportingGroupId)
                );
            }
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    private void handleReportValuesInsertion(List<Financial_Report_Result_Value__c> reportValues, Boolean removeZeroBalanceRows) {
        // handle case where first period in fiscal year; we do not want to have an opening balance for revenue or expense GL Accounts
        if (reportOptions.reportType == FinancialReportOptions.FinancialReportType.TRIAL_BALANCE) {
            reportValues = setTrialBalanceRetainedEarnings(reportValues);
            if (reportOptions.getStartPeriodName() != null && reportOptions.getStartPeriodName().subString(5, 7) == '01') {
                reportValues = setTrialBalanceOpeningBalanceZero(reportValues);
            }
        }

        if (removeZeroBalanceRows == null || removeZeroBalanceRows == false) {
            SFDCSecurityUtils.insertProxy(reportValues);
        }
        else {
            List<Financial_Report_Result_Value__c> nonZeroAmountCells;
            if (reportOptions.reportType == FinancialReportOptions.FinancialReportType.PROFIT_AND_LOSS_VS_BUDGET) {
                nonZeroAmountCells = getNonZeroAmountCellsForProfitAndLossVsBudgetReport(reportValues);
            } else {
                nonZeroAmountCells = getNonZeroAmountCells(reportValues, reportOptions.reportType);
            }

            SFDCSecurityUtils.insertProxy(nonZeroAmountCells);
        }
    }

    private List<Financial_Report_Result_Value__c> getNonZeroAmountCellsForProfitAndLossVsBudgetReport(List<Financial_Report_Result_Value__c> reportValues) {
        List<Financial_Report_Result_Value__c> nonZeroAmountCells = new List<Financial_Report_Result_Value__c>();
        Map<Integer, Financial_Report_Result_Value__c> rowPositionToZeroActualCell = new Map<Integer, Financial_Report_Result_Value__c>();
        Map<Integer, Financial_Report_Result_Value__c> rowPositionToZeroBudgetCell = new Map<Integer, Financial_Report_Result_Value__c>();
        Set<Integer> rowsPositionsForSuppress = new Set<Integer>();

        for (Financial_Report_Result_Value__c eachCell : reportValues) {
            if (eachCell.Column_Header_1__c == 'Actual Total' && eachCell.Row_Type__c == 'GL Account' && eachCell.Currency_Value__c == 0) {
                rowPositionToZeroActualCell.put( (Integer) eachCell.Row_Position__c, eachCell );
            }
        }

        for (Financial_Report_Result_Value__c eachCell : reportValues) {
            if (eachCell.Column_Header_1__c == 'Budget Total' && eachCell.Row_Type__c == 'GL Account' && eachCell.Currency_Value__c == 0) {
                rowPositionToZeroBudgetCell.put( (Integer) eachCell.Row_Position__c, eachCell );
            }
        }

        for (Integer rowPosition : rowPositionToZeroActualCell.keySet()) {
            if (rowPositionToZeroBudgetCell.get(rowPosition) != null) {
                rowsPositionsForSuppress.add(rowPosition);
            }
        }

        for (Financial_Report_Result_Value__c eachCell : reportValues) {
            if (rowsPositionsForSuppress.contains( (Integer) eachCell.Row_Position__c) ) {
                continue;
            }
            else {
                nonZeroAmountCells.add(eachCell);
            }
        }

        return nonZeroAmountCells;
    }

    private List<Financial_Report_Result_Value__c> getNonZeroAmountCells(
        List<Financial_Report_Result_Value__c> reportValues,
        FinancialReportOptions.FinancialReportType reportType) {

        List<Financial_Report_Result_Value__c> nonZeroAmountCells = new List<Financial_Report_Result_Value__c>();
        Map<Decimal, Decimal> rowPositionToAmount = new Map<Decimal, Decimal>();

        for (Financial_Report_Result_Value__c eachCell : reportValues) {
            Boolean processCell = false;
            if (reportType == FinancialReportOptions.FinancialReportType.CUSTOM) {
                processCell = (eachCell.Column_Type__c == 'Year To Date' || eachCell.Column_Type__c == 'Current Period') && (eachCell.Row_Type__c == 'GL Account' || eachCell.Row_Type__c == 'Reporting Group');    
            } else if (reportType == FinancialReportOptions.FinancialReportType.BALANCE_SHEET) {
                processCell = eachCell.Column_Type__c == 'Year To Date' && eachCell.Row_Type__c == 'GL Account';
            } else if (reportType == FinancialReportOptions.FinancialReportType.CASH_FLOW || reportType == FinancialReportOptions.FinancialReportType.TRIAL_BALANCE) {
                processCell = (eachCell.Column_Type__c == 'Year To Date' || eachCell.Column_Type__c == 'Current Period') && eachCell.Row_Type__c == 'GL Account';
            } else if (reportType == FinancialReportOptions.FinancialReportType.PROFIT_AND_LOSS) {
                processCell = eachCell.Column_Type__c == 'Current Period' && eachCell.Row_Type__c == 'GL Account';
            }
                        
            if (processCell) {
                Decimal tempAmount = eachCell.Currency_Value__c == null ? 0 : eachCell.Currency_Value__c.abs();
                if (!rowPositionToAmount.containsKey(eachCell.Row_Position__c)) {
                    rowPositionToAmount.put(eachCell.Row_Position__c, tempAmount);
                }
                else {
                    rowPositionToAmount.put(eachCell.Row_Position__c, rowPositionToAmount.get(eachCell.Row_Position__c) + tempAmount);
                }
            }
        }

        Set<Decimal> rowPositionsToSuppress = new Set<Decimal>();
        for (Decimal rowPosition : rowPositionToAmount.keySet()) {
            if (rowPositionToAmount.get(rowPosition) == 0) {
                rowPositionsToSuppress.add(rowPosition);
            }
        }

        for (Financial_Report_Result_Value__c eachCell : reportValues) {
            if (!rowPositionsToSuppress.contains(eachCell.Row_Position__c)) {
                nonZeroAmountCells.add(eachCell);
            }
        }
        
        return nonZeroAmountCells;
    }

    private List<Financial_Report_Result_Value__c> setTrialBalanceOpeningBalanceZero(List<Financial_Report_Result_Value__c> reportValues) {
        Map<Id, String> glAccountMap = new Map<Id, String>();
        Decimal total = 0;
        Integer rowCount = 0;

        for (Financial_Report_Result_Value__c eachCell : reportValues) {
           
            if (eachCell.Row_Type__c == 'GL Account' && eachCell.Column_Position__c == 0) {
                glAccountMap.put(rowMap.get(rowCount).GL_Account__c, null);
            }

            rowCount++;
        }

        for (GL_Account__c glAccount : DomainUtils.getGlAccountsById(glAccountMap.keySet())) {
            glAccountMap.put(glAccount.Id, glAccount.Type__c);
        }

        rowCount = 0;

        for (Financial_Report_Result_Value__c eachCell : reportValues) {
            String glAccountId = rowMap.get(rowCount).GL_Account__c;

            if (eachCell.Row_Type__c == 'GL Account' && eachCell.Column_Position__c == 0
                    && glAccountMap.containsKey(glAccountId)
                    && (glAccountMap.get(glAccountId) == 'Expense' || glAccountMap.get(glAccountId) == 'Revenue')) {
                eachCell.Currency_Value__c = 0.00;
                eachCell.Text_Value__c = eachCell.Currency_Value__c.toPlainString();
            }

            if (eachCell.Row_Type__c == 'GL Account' && eachCell.Column_Position__c == 0) {
                if (eachCell.Currency_Value__c != null) {
                    total += eachCell.Currency_Value__c;
                }
            }

            if (eachCell.Row_Label__c == 'Total' && eachCell.Column_Position__c == 0) {
                eachCell.Currency_Value__c = total.setScale(2, System.RoundingMode.HALF_UP);
                eachCell.Text_Value__c = eachCell.Currency_Value__c.toPlainString();
            }

            rowCount++;
        }
      
        return reportValues;
    }

    @TestVisible
    private List<Financial_Report_Result_Value__c> setTrialBalanceRetainedEarnings(List<Financial_Report_Result_Value__c> reportValues) {
        try {
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(reportOptions.ledger);
            String retainedEarningsGLAccountId = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.RETAINED_EARNINGS_GL_ACCOUNT)?.GL_Account__c;
            Id startPeriodId = reportOptions.startingAccountingPeriod;
            Id ledgerId = reportOptions.ledger;
            Id glVariable1 = reportOptions.glVariable1;
            Id glVariable2 = reportOptions.glVariable2;
            Id glVariable3 = reportOptions.glVariable3;
            Id glVariable4 = reportOptions.glVariable4;

            String dynamicQueryString =
                'SELECT SUM(' + PACKAGE_QUALIFIER + 'Opening_Balance_Number__c)obSum, ' +
                        PACKAGE_QUALIFIER + 'GL_Account__c ' +
                'FROM ' + PACKAGE_QUALIFIER + 'Financial_Cube__c ' +
                'WHERE ' + PACKAGE_QUALIFIER + 'Accounting_Period__c = :startPeriodId ' +
                'AND ' + PACKAGE_QUALIFIER + 'GL_Account__c = :retainedEarningsGLAccountId ' +
                'AND ' +  PACKAGE_QUALIFIER + 'Ledger__c = :ledgerId ' +
                ((String.isBlank(glVariable1)) ? '' : 'AND ' + PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c = :glVariable1 ') +
                ((String.isBlank(glVariable2)) ? '' : 'AND ' + PACKAGE_QUALIFIER + 'GL_Account_Variable_2__c = :glVariable2 ') +
                ((String.isBlank(glVariable3)) ? '' : 'AND ' + PACKAGE_QUALIFIER + 'GL_Account_Variable_3__c = :glVariable3 ') +
                ((String.isBlank(glVariable4)) ? '' : 'AND ' + PACKAGE_QUALIFIER + 'GL_Account_Variable_4__c = :glVariable4 ') +
                (MultiCurrencyHandler.isMultiCurrencyEnabled ? 'AND CurrencyIsoCode = \'' + String.escapeSingleQuotes(reportOptions.currencyISO) + '\' ' : '') +
                'GROUP BY ' + PACKAGE_QUALIFIER + 'GL_Account__c';
            
            AggregateResult[] groupedResults = Database.query(dynamicQueryString);

            Decimal sum = (Decimal)groupedResults[0].get('obSum');

            Integer rowCount = 0;
            for (Financial_Report_Result_Value__c eachCell : reportValues) {
                String glAccountId = rowMap.get(rowCount).GL_Account__c;

                if (glAccountId == defaultsBySpecDevNames.get(GLAccountDefaultsHandler.RETAINED_EARNINGS_GL_ACCOUNT)?.GL_Account__c
                    && eachCell.Row_Type__c == 'GL Account' && eachCell.Column_Position__c == 0) {
                    eachCell.Currency_Value__c = sum.setScale(2, System.RoundingMode.HALF_UP);
                    eachCell.Text_Value__c = eachCell.Currency_Value__c.toPlainString();
                }

                rowCount++;
            }

        }
        catch (Exception ex) {

        }

        return reportValues;
    }

    private void setAccountingPeriod() {
        if (reportOptions.reportType == FinancialReportOptions.FinancialReportType.CUSTOM
            && !reportOptions.getListOfPeriodNames().isEmpty()
            && AccountingPeriodHandler.getInstance().getAccountingPeriodByName(reportOptions.getListOfPeriodNames()[0]) != null) {
            reportResult.Accounting_Period__c = AccountingPeriodHandler.getInstance().getAccountingPeriodByName(reportOptions.getListOfPeriodNames()[0]).Id;
        }
        else {
            reportResult.Accounting_Period__c = reportOptions.startingAccountingPeriod;
        }
    }

}