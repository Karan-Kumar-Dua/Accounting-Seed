public with sharing class ReportValueProcessor {
    //string constants
    private static final String ENDING_CASH_BALANCE = 'Ending Cash Balance';

    private String led;
    private String gla;
    private String rg;
    private String av1;
    private String av2;
    private String av3;
    private String av4;
    private Integer offset;
    @TestVisible
    private Id currentYearEarningsGLAccountId;
    @TestVisible
    private Id retainedEarningsGLAccountId;
    @TestVisible
    private FinancialReportOptions reportOptions;
    @TestVisible
    private List<String> reportingGroupList;
    @TestVisible
    private BalanceBuilder balancebuilder;    

    public ReportValueProcessor(FinancialReportOptions options,
                                List<String> rgList,
                                BalanceBuilder balancebuilder) {
        Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(options.ledger);
        this.currentYearEarningsGLAccountId = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT)?.GL_Account__c;
        this.retainedEarningsGLAccountId = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.RETAINED_EARNINGS_GL_ACCOUNT)?.GL_Account__c;
        this.reportOptions = options;
        this.reportingGroupList = rgList;
        this.balancebuilder = balancebuilder;
        
    }

    private Boolean isReportTypeCashFlowStatement() {
        return reportOptions.reportType == FinancialReportOptions.FinancialReportType.CASH_FLOW;
    }

    private Boolean isColumnTypeCurrentPeriod(Financial_Report_Result_Value__c r) {
        return r.Column_Type__c == FinancialReportColumnActions.FRC_TYPE_CURRENT_PERIOD;
    }

    private Boolean isColumnTypeYearToDate(Financial_Report_Result_Value__c r) {
        return r.Column_Type__c == FinancialReportColumnActions.FRC_TYPE_YEAR_TO_DATE;
    }

    private Boolean isFirstRowInReport(Financial_Report_Result_Value__c r) {
        return r.Row_Position__c == 10; //means it is the first row in the report
    }

    private Boolean isRowTypeReportingGroup(Financial_Report_Result_Value__c r) {
        return r.Row_Type__c == FinancialReportRowActions.FRR_TYPE_REPORTING_GROUP;
    }

    private Boolean isRowLabelEndingCashBalance(Financial_Report_Result_Value__c r) {
        return r.Row_Label__c == ENDING_CASH_BALANCE;
    }

    private Boolean isColumnTypeCalculationNumber(Financial_Report_Column__c thiscol) {
        return thiscol.Type__c == FinancialReportColumnActions.FRC_TYPE_CALCULATION_NUMBER;
    }

    private Boolean isRowTypeCalculationNumber(Financial_Report_Row__c thisrow) {
        return thisrow.Type__c == FinancialReportRowActions.FRR_TYPE_CALCULATION_NUMBER;
    }

    private Boolean isColumnTypeCalculationPercentage(Financial_Report_Column__c thiscol) {
        return thiscol.Type__c == FinancialReportColumnActions.FRC_TYPE_CALCULATION_PERCENTAGE
                || thiscol.Type__c == FinancialReportColumnActions.FRC_TYPE_CALCULATION_PERCENTAGE_SYMBOL;
    }

    private Boolean isRowTypeCalculationPercentage(Financial_Report_Row__c thisrow) {
        return thisrow.Type__c == FinancialReportRowActions.FRR_TYPE_CALCULATION_PERCENTAGE
                || thisrow.Type__c == FinancialReportRowActions.FRR_TYPE_CALCULATION_PERCENTAGE_SYMBOL;
    }

    private Boolean isColumnTypeCalculation(Financial_Report_Column__c thiscol) {
        return isColumnTypeCalculationNumber(thiscol) || isColumnTypeCalculationPercentage(thiscol);
    }

    private Boolean isRowTypeCalculation(Financial_Report_Row__c thisrow) {
        return isRowTypeCalculationNumber(thisrow) || isRowTypeCalculationPercentage(thisrow);
    }

    private Boolean isRowTypeDescription(Financial_Report_Row__c thisrow) {
        return thisrow.Type__c == FinancialReportRowActions.FRR_TYPE_DESCRIPTION;
    }

    private Boolean isRowTypeBlank(Financial_Report_Row__c thisrow) {
        return thisrow.Type__c == FinancialReportRowActions.FRR_TYPE_BLANK;
    }    

    private Boolean isRowGLAccountBalanceAndColumnNotCalculation(Financial_Report_Row__c thisrow, Financial_Report_Column__c thiscol) {
        return
            (thisrow.Type__c == FinancialReportRowActions.FRR_TYPE_GL_ACCOUNT
                || thisRow.Type__c == FinancialReportRowActions.FRR_TYPE_REPORTING_GROUP)
                && !isColumnTypeCalculation(thiscol);
    }
    
    private Boolean isTypeCurrentPeriod(Financial_Report_Column__c thiscol) {
        return thiscol.Type__c == FinancialReportColumnActions.FRC_TYPE_CURRENT_PERIOD;
    }

    private Boolean isTypeYearToDate(Financial_Report_Column__c thiscol) {
        return thiscol.Type__c == FinancialReportColumnActions.FRC_TYPE_YEAR_TO_DATE;
    }

    private Boolean isTypeOpeningBalance(Financial_Report_Column__c thiscol) {
        return thiscol.Type__c == FinancialReportColumnActions.FRC_TYPE_OPENING_BALANCE;
    }

    private Boolean isTypeGLAccount(Financial_Report_Row__c thisrow) {
        return thisrow.Type__c == FinancialReportRowActions.FRR_TYPE_GL_ACCOUNT;
    }

    private Boolean isTypeReportingGroup(Financial_Report_Row__c thisrow) {
        return thisrow.Type__c == FinancialReportRowActions.FRR_TYPE_REPORTING_GROUP;
    }

    private Boolean suppressDrillDownHyperlink(Decimal periodBalance) {
        //need to suppress drill down hyperlink for this cell if this column is associated with the budget ledger=
        //need to suppress drill down hyperlink for this cell if this column do not contain actual transactions for the period
        Ledger__c theLedger = LedgerHandler.getInstanceWithoutSharing().getAllLedgersMap().get(led);
        Boolean suppressByLedgerType =
            theLedger != null
                && (LedgerHandler.isBudgetLedger(theLedger) || LedgerHandler.isConsolidationLedger(theLedger));

        return suppressByLedgerType
            || periodBalance == 0
            || currentYearEarningsGLAccountId == gla
            || retainedEarningsGLAccountId == gla;
    }

    private void setProperties(Financial_Report_Row__c thisrow, Financial_Report_Column__c thiscol) {
        led = thiscol.Ledger__c;
        gla = thisrow.GL_Account__c;
        rg = thisrow.GL_Account_Reporting_Group__c;
        av1 = thisrow.GL_Account_Variable_1__c;
        av2 = thisrow.GL_Account_Variable_2__c;
        av3 = thisrow.GL_Account_Variable_3__c;
        av4 = thisrow.GL_Account_Variable_4__c;
        offset = thiscol.Offset__c.intValue();
    }

    private Boolean handleCashFlowReportType(Financial_Report_Result_Value__c r, Financial_Report_Column__c thiscol, Integer initialColumnOffset) {
        //=========== CASH FLOW STATEMENT report has non-standard behaviour ===========================//
        //== First row (Beginning Cash Balance) => Sum of the FC's Year To Date field values for the PRIOR accounting period
        Boolean isTempColumnType = false;
        if (isColumnTypeCurrentPeriod(r)
                && isFirstRowInReport(r)
                && isRowTypeReportingGroup(r)) {
            this.offset--;//for Period column we take values from prior period
            r.Column_Type__c = FinancialReportColumnActions.FRC_TYPE_YEAR_TO_DATE;
            thiscol.Type__c = FinancialReportColumnActions.FRC_TYPE_YEAR_TO_DATE;
            isTempColumnType = true;
        }
        else if (isColumnTypeYearToDate(r)
                && isFirstRowInReport(r)
                && isRowTypeReportingGroup(r)) {
            //for YTD column we take values from prior period for first period in the report
            this.offset = this.offset + (/*always negative -> */initialColumnOffset - 1);            
        }
        //== Last row (Ending Cash Balance) => Sum of FC's Year To Date field values for CURRENT accounting period
        if (isColumnTypeCurrentPeriod(r) 
                && isRowTypeReportingGroup(r)
                && isRowLabelEndingCashBalance(r)) {
            r.Column_Type__c = FinancialReportColumnActions.FRC_TYPE_YEAR_TO_DATE;
            thiscol.Type__c = FinancialReportColumnActions.FRC_TYPE_YEAR_TO_DATE;
            isTempColumnType = true;
        }
        return isTempColumnType;
    }

    private void handleTempColumn(Financial_Report_Result_Value__c r, Financial_Report_Column__c thiscol) {
        r.Column_Type__c = (isColumnTypeCurrentPeriod(r)) ? FinancialReportColumnActions.FRC_TYPE_YEAR_TO_DATE : FinancialReportColumnActions.FRC_TYPE_CURRENT_PERIOD;
        thiscol.Type__c = r.Column_Type__c;
    }

    private String performCalculation(String calculationValue, Map<String, Decimal> rowColMap, RowColumnData rowColumn) {
        Boolean foundvalue = false;
        String p = '(\\{.*?\\})';
        String calcstring = calculationValue.trim().replaceAll(' ', '').toLowerCase();
        Pattern patt = Pattern.compile(p);
        Matcher matcher = patt.matcher(calcstring);
        foundvalue = matcher.find();
        Boolean isRow = rowColumn.type == 'Row' ? true : false;
        
        if (foundvalue) {
            do {
                //EXPERIMENTAL SUPPORT FOR RANGES
                Decimal fetchedvalue = 0;
                if (matcher.group(1).contains(':')) {
                    String[] tokens = matcher.group(1).split(':');
                    Integer val1Int;
                    Integer val2Int;
                    if (isRow) {
                        val1Int = Integer.valueOf(tokens[0].replaceAll('c', '').replaceAll('\\{', '').replaceAll('\\}', ''));
                        val2Int = Integer.valueOf(tokens[1].replaceAll('c', '').replaceAll('\\{', '').replaceAll('\\}', ''));     
                    } else if (!isRow) {
                        val1Int = Integer.valueOf(tokens[0].replaceAll('r', '').replaceAll('\\{', '').replaceAll('\\}', ''));
                        val2Int = Integer.valueOf(tokens[1].replaceAll('r', '').replaceAll('\\{', '').replaceAll('\\}', ''));                                  
                    }                    
                    for (Integer i = val1Int; i <= val2Int; i++) {
                        String rowColMapKey = isRow
                            ? rowColumn.rowColumnValue + new RowColumnData(i, false).rowColumnValue
                            : new RowColumnData(i, true).rowColumnValue + rowColumn.rowColumnValue;

                        if (rowColMap.containsKey(rowColMapKey)) {
                            fetchedvalue = fetchedvalue + rowColMap.get(rowColMapKey);
                        }
                    }
                }
                else {
                    String rowColMapKey = isRow ? 
                                                rowColumn.rowColumnValue + matcher.group(1) :
                                                matcher.group(1) + rowColumn.rowColumnValue;

                    if (rowColMap.containsKey(rowColMapKey)) {
                        fetchedvalue = rowColMap.get(rowColMapKey);
                    }
                }
                String formattedmatch = matcher.group(1).replaceAll('\\{', '\\\\{').replaceAll('\\}', '\\\\}');
                calcstring = calcstring.replaceAll('(' + formattedmatch + ')', fetchedvalue.toPlainString());
                matcher = patt.matcher(calcstring);
                foundvalue = matcher.find();
            }
            while (foundvalue);
        }
        return calcstring;
    }

    public Boolean performRowAndColumnCalculations(
                                                    Financial_Report_Result_Value__c r, 
                                                    Financial_Report_Row__c thisrow, 
                                                    Financial_Report_Column__c thiscol,
                                                    Map<String, Decimal> rowColMap,
                                                    Integer percentageScale) {
        setProperties(thisrow, thiscol);
        CalculationEngine c = new CalculationEngine();
        RowColumnData rowData = new RowColumnData(thisrow.Position__c, true);
        String row = rowData.rowColumnValue;
        RowColumnData colData = new RowColumnData(thiscol.Position__c, false);
        String col = colData.rowColumnValue;
        Boolean isCalculated = false;

        //Now perform a row calc if the criteria is met
        if (isRowTypeCalculation(thisrow) && thiscol.Column_Overide_Row__c != true) {
            try {
                Decimal newvalue = c.calculate(
                    performCalculation(
                        getCalculationFormula(thisrow),
                        rowColMap,
                        colData
                    )
                );
                rowColMap.put(row + col, newvalue);
                r.Currency_Value__c = newvalue;
                if (isRowTypeCalculationNumber(thisrow)) {
                    newvalue = newvalue.setScale(2, System.RoundingMode.HALF_UP);
                    r.Text_Value__c = newvalue.toPlainString();
                    r.Currency_Value__c = newvalue;
                }
                else if (isRowTypeCalculationPercentage(thisRow)) {
                    newvalue = (newvalue * 100).setScale(percentageScale, System.RoundingMode.HALF_UP);
                    r.Text_Value__c = newvalue.toPlainString();
                    r.Currency_Value__c = newvalue;
                }
                isCalculated = true;
            }
            catch (MathException me) {
                r.Text_Value__c = '(ERR) DIV/0';
            }
            //continue;
        }

        //Now check the column and do calcs if
        if (!isCalculated && isColumnTypeCalculation(thiscol) && !isRowTypeDescription(thisrow) && !isRowTypeBlank(thisrow)) {
            try {
                Decimal newvalue = c.calculate(performCalculation(thiscol.Calculation__c, rowColMap, rowData));
                rowColMap.put(row + col, newvalue);
                r.Currency_Value__c = newvalue;
                if (isColumnTypeCalculationNumber(thiscol)) {
                    newvalue = newvalue.setScale(2, System.RoundingMode.HALF_UP);
                    r.Text_Value__c = newvalue.toPlainString();
                    r.Currency_Value__c = newvalue;
                }
                else
                    if (isColumnTypeCalculationPercentage(thiscol)) {
                        newvalue = (newvalue * 100).setScale(percentageScale, System.RoundingMode.HALF_UP);
                        r.Text_Value__c = newvalue.toPlainString();
                        r.Currency_Value__c = newvalue;
                    }
            }
            catch (MathException me) {
                r.Text_Value__c = '(ERR) DIV/0';
            }
            //continue;
        }
        return true;
    }

    private String getCalculationFormula(Financial_Report_Row__c thisrow) {
        return (thisrow.Calculation__c == FinancialReportRowActions.CALC_IS_MOVED_PLACEHOLDER) ? thisrow.Calculation_Long__c : thisrow.Calculation__c;
    }

    public ReportValueCalculationResult calculateReportValue(
                                                                Financial_Report_Result_Value__c r,
                                                                Financial_Report_Row__c thisrow,
                                                                Financial_Report_Column__c thiscol,
                                                                Financial_Report_Column__c initialColumn,
                                                                Decimal periodBalance
                                                                ) {
        
        String rcKey = '';
        setProperties(thisrow, thiscol);

        Boolean isTempColumnType = false;
        if (isReportTypeCashFlowStatement()) {
            isTempColumnType = handleCashFlowReportType(r, thiscol, initialColumn.Offset__c.intValue());
        }       
        
        Decimal value = 0;
        Decimal currentPeriodValue = 0;//used to check actual period transaction in case of balance sheet report

        String periodNameValue = AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(reportOptions.startingAccountingPeriod, offset).Name;

        //Row is a GL Account balance and column is not a calculation
        if (isRowGLAccountBalanceAndColumnNotCalculation(thisrow, thiscol)) {
            if ((isTypeCurrentPeriod(thiscol) || isTypeYearToDate(thiscol)) && isTypeReportingGroup(thisrow)) {
                currentPeriodValue = balancebuilder.getPeriodBalanceForGroup(periodNameValue, led, reportingGroupList, av1, av2, av3, av4);
            }

            if ((isTypeCurrentPeriod(thiscol) || isTypeYearToDate(thiscol)) && isTypeGLAccount(thisrow)) {
                currentPeriodValue = balancebuilder.getPeriodBalance(periodNameValue, led, gla, av1, av2, av3, av4);
            }
            
            if (isTypeCurrentPeriod(thiscol)) {
                value = currentPeriodValue;
            }
            //special scenario for TB + FCT =============================================================
            if (isTypeOpeningBalance(thiscol) && isTypeGLAccount(thisrow)) {
                value = balancebuilder.getOpeningBalance(periodNameValue, led, gla, av1, av2, av3, av4);
            }
            //===========================================================================================
            if (isTypeYearToDate(thiscol) && isTypeGLAccount(thisrow)) {
                value = balancebuilder.getYTDBalance(periodNameValue, led, gla, av1, av2, av3, av4);
            }

            if (isTypeYearToDate(thiscol) && isTypeReportingGroup(thisrow)) {
                value = balancebuilder.getYTDBalanceForGroup(periodNameValue, led, reportingGroupList, av1, av2, av3, av4);                    
            }

            if (periodBalance == 0 && currentPeriodValue.setScale(2, System.RoundingMode.HALF_UP) != 0) {
                periodBalance = currentPeriodValue.setScale(2, System.RoundingMode.HALF_UP);
            }

            if (thisrow.Normal_Balance__c == FinancialReportRowActions.FRR_NORMAL_BALANCE_CREDIT
                    && LedgerHandler.getInstanceWithoutSharing().getAllLedgersMap().get(led) != NULL
                    && !LedgerHandler.isBudgetLedger(LedgerHandler.getInstanceWithoutSharing().getAllLedgersMap().get(led))) {

                value = value * -1;
            }

            value = doRounding(value);
            r.Currency_Value__c = (r.Currency_Value__c == NULL ? 0 : r.Currency_Value__c) + value;
            r.Text_Value__c = r.Currency_Value__c.toPlainString();

            r.Suppress_Cell_Hyperlink__c = suppressDrillDownHyperlink(periodBalance);

            if (isTempColumnType == true) {
                handleTempColumn(r, thiscol);
            }

            String row = new RowColumnData(thisrow.Position__c, true).rowColumnValue; //{r' + String.valueOf(thisrow.Position__c) + '}';
            String col = new RowColumnData(thiscol.Position__c, false).rowColumnValue; //'{c' + String.valueOf(thiscol.Position__c) + '}';
            rcKey = row + col;
        }
        
        Boolean isSuccess = true;
        return new ReportValueCalculationResult(periodBalance, rcKey, isSuccess);
    }

    @TestVisible
    private Decimal doRounding(Decimal originalValue) {
        Decimal result;
        FinancialReportOptions.FinancialReportRoundingMode roundingMode =
            this.reportOptions.getFinancialReportRoundingMode();

        switch on roundingMode {
            when NO_ROUNDING {
                result = originalValue.setScale(2, System.RoundingMode.HALF_UP);
            }
            when WHOLE_AMOUNTS {
                result = originalValue.round(System.RoundingMode.HALF_UP);
            }
            when ROUND_TO_1000 {
                result = (originalValue.abs() < 500) ? 0 : (originalValue / 1000).round(System.RoundingMode.HALF_UP);
            }
        }
        return result;
    }

    public with sharing class ReportValueCalculationResult {
        public Decimal periodBalance;
        public String rowColKey;
        public Boolean isSuccess;

        public ReportValueCalculationResult( 
                                            Decimal periodBal,
                                            String rcKey,
                                            Boolean isSuccess) {
            this.periodBalance = periodBal;
            this.rowColKey = rcKey;
            this.isSuccess = isSuccess;
        }
    }

    private with sharing class RowColumnData {
        public String rowColumnValue;
        public String type;

        public RowColumnData( Decimal position, Boolean isRow ) {
            this.rowColumnValue = isRow == true ? '{r' : '{c';
            this.rowColumnValue += String.valueOf(position) + '}';
            this.type = isRow == true ? 'Row' : 'Column';
        }

        public RowColumnData( Integer position, Boolean isRow ) {
            this.rowColumnValue = isRow == true ? '{r' : '{c';
            this.rowColumnValue += String.valueOf(position) + '}';
            this.type = isRow == true ? 'Row' : 'Column';
        }
    }
}