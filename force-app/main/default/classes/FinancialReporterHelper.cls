public with sharing class FinancialReporterHelper extends AbstractLWCHelper {

    private static final Map<String, FinancialReportOptions.FinancialReportType> REPORT_TYPE = new Map<String, FinancialReportOptions.FinancialReportType> {
        'profitLoss' => FinancialReportOptions.FinancialReportType.PROFIT_AND_LOSS,
        'profitLossVsBudget' => FinancialReportOptions.FinancialReportType.PROFIT_AND_LOSS_VS_BUDGET,
        'balanceSheet' => FinancialReportOptions.FinancialReportType.BALANCE_SHEET,
        'trialBalance' => FinancialReportOptions.FinancialReportType.TRIAL_BALANCE,
        'cashFlow' => FinancialReportOptions.FinancialReportType.CASH_FLOW,
        'ledgerInquiry' => FinancialReportOptions.FinancialReportType.LEDGER_INQUIRY,
        'custom' => FinancialReportOptions.FinancialReportType.CUSTOM
    };

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> fetchRateTableCurrencies() {
        Schema.SObjectField fromCurrencyCode = Exchange_Rate__c.From_Currency_Code__c;
        Map<Schema.SObjectField, List<Schema.PicklistEntry>> picklistEntriesByFields =
                FinancialSuiteUtils.fetchPicklistEntriesBySObjectFields(new List<Schema.SObjectField>{fromCurrencyCode});

        List<Map<String, Object>> result = new List<Map<String, Object>>();
        List<Schema.PicklistEntry> picklistEntries = picklistEntriesByFields.get(fromCurrencyCode);
        if (picklistEntries != null) {
            for (Schema.PicklistEntry picklistEntry : picklistEntries) {
                result.add(new Map<String, Object>{
                        'label' => picklistEntry.label,
                        'value' => picklistEntry.value
                });
            }
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isMultiCurrencyEnabled(){
        return AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED;
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isHeaderLevelPostEnabled(){
        return AccountingSettingsHandler.isHeaderLevelPost();
    }

    @AuraEnabled (cacheable=true)
    public static Dashboard getAccountingDashboard(){
        try {
            return DomainUtils.getAccountingDashboard();
        } catch (AuraHandledException e) {
            throw new AuraHandledException(e.getMessage());
        }
    }


    @AuraEnabled(cacheable=true)
    public static ProfitAndLossFinancialReportOptions getProfitLossDefaults() {
        try {
            return new ProfitAndLossFinancialReportOptions();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static BalanceSheetFinancialReportOptions getBalanceSheetDefaults() {
        try {
            return new BalanceSheetFinancialReportOptions();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static CashFlowFinancialReportOptions getCashFlowDefaults() {
        try {
            return new CashFlowFinancialReportOptions();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
  
    @AuraEnabled(cacheable=true)
    public static ProfitAndLossVsBudgetFinReptOptions getProfitLossVsBudgetDefaults() {
        try {
            return new ProfitAndLossVsBudgetFinReptOptions();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static TrialBalanceFinancialReportOptions getTrialBalanceDefaults() {
        try {
            return new TrialBalanceFinancialReportOptions();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static LedgerInquiryFinancialReportOptions getLedgerInquiryDefaults() {
        try {
            return new LedgerInquiryFinancialReportOptions();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static CustomFinancialReportOptions getCustomReportDefaults(){
        try {
            return new CustomFinancialReportOptions(null);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

    }

    @AuraEnabled
    public static SaveResponse reRunReport(String reportId){
        SaveResponse response;
        try {
            response = new SaveResponse(FinancialReporter.reRunReport(reportId));   
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return response;
    }

    @AuraEnabled
    public static SaveResponse runProfitLoss(String options) {
        SaveResponse response;
        try {
            ProfitAndLossFinancialReportOptions opts =
                (ProfitAndLossFinancialReportOptions) JSON.deserialize(
                    options, ProfitAndLossFinancialReportOptions.class
                );
            opts.reportType = FinancialReportOptions.FinancialReportType.PROFIT_AND_LOSS;
            response = new SaveResponse(FinancialReporter.runReport(opts));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return response;
    }

    @AuraEnabled
    public static SaveResponse runProfitLossVsBudget(String options) {
        SaveResponse response;
        try {
            ProfitAndLossVsBudgetFinReptOptions opts =
                (ProfitAndLossVsBudgetFinReptOptions) JSON.deserialize(
                    options, ProfitAndLossVsBudgetFinReptOptions.class
                );
            opts.reportType = FinancialReportOptions.FinancialReportType.PROFIT_AND_LOSS_VS_BUDGET;
            response = new SaveResponse(FinancialReporter.runReport(opts));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return response;
    }

    @AuraEnabled
    public static SaveResponse runBalanceSheet(String options) {
        SaveResponse response;
        try {
            BalanceSheetFinancialReportOptions opts = (BalanceSheetFinancialReportOptions) JSON.deserialize(options, BalanceSheetFinancialReportOptions.class);
            opts.reportType = FinancialReportOptions.FinancialReportType.BALANCE_SHEET;
            response = new SaveResponse(FinancialReporter.runReport(opts));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return response;
    }

    @AuraEnabled
    public static SaveResponse runTrialBalance(String options) {
        SaveResponse response;
        try {
            TrialBalanceFinancialReportOptions opts = (TrialBalanceFinancialReportOptions) JSON.deserialize(options, TrialBalanceFinancialReportOptions.class);
            opts.reportType = FinancialReportOptions.FinancialReportType.TRIAL_BALANCE;
            response = new SaveResponse(FinancialReporter.runReport(opts));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return response;
    }

    @AuraEnabled
    public static SaveResponse runCashFlow(String options) {
        SaveResponse response;
        try {
            CashFlowFinancialReportOptions opts = (CashFlowFinancialReportOptions) JSON.deserialize(options, CashFlowFinancialReportOptions.class);
            opts.reportType = FinancialReportOptions.FinancialReportType.CASH_FLOW;
            opts.cashFlowCategories = DomainUtils.getCashFlowCategories();
            response = new SaveResponse(FinancialReporter.runReport(opts));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return response;
    }

    @AuraEnabled
    public static LedgerInquiryFinancialReport.LedgerInquiryResponse runLedgerInquiry(String options) {
        LedgerInquiryFinancialReport.LedgerInquiryResponse response = new LedgerInquiryFinancialReport.LedgerInquiryResponse();
        try {
            LedgerInquiryFinancialReportOptions opts = (LedgerInquiryFinancialReportOptions) JSON.deserialize(options, LedgerInquiryFinancialReportOptions.class);
            opts.reportType = FinancialReportOptions.FinancialReportType.LEDGER_INQUIRY;
            response = LedgerInquiryFinancialReport.runReport(opts);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return response;
    }

    @AuraEnabled
    public static SaveResponse runCustomReport(String options) {
        SaveResponse response;
        try {
            CustomFinancialReportOptions opts = (CustomFinancialReportOptions) JSON.deserialize(options, CustomFinancialReportOptions.class);
            opts.reportType = FinancialReportOptions.FinancialReportType.CUSTOM;
            response = new SaveResponse(FinancialReporter.runReport(opts));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return response;
    }

    @AuraEnabled
    public static List<Financial_Report_Result__c> getFinancialReportResults(String reportTypeName) {
        List<Financial_Report_Result__c> result = new List<Financial_Report_Result__c>();
        try {
            FinancialReportOptions.FinancialReportType reportType = FinancialReportOptions.FinancialReportType.PROFIT_AND_LOSS;
            if (reportTypeName != NULL) {
                reportType = REPORT_TYPE.get(reportTypeName);
            }
            result = FinancialReporter.retrieveReports(reportType);
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }

        return result;
    }

    @AuraEnabled
    public static SaveResponse deleteFinancialReportResults(List<Id> reportIds) {
        SaveResponse result = new SaveResponse();
        try {
            result = new SaveResponse(FinancialReporter.deleteReports(new Set<Id>(reportIds)));
        }
        catch (AuraHandledException ex) {
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        return result;
    }

    @AuraEnabled
    public static SaveResponse updateReportSubtitle(String reportId, String subtitle) {
        SaveResponse response = new SaveResponse();
        try {
            Attachment attachment;
            try {
                attachment = queryAttachment(reportId);
            }
            catch (QueryException ex) {}

            if (attachment != NULL) {
                String jsonDefinition = attachment.Body.toString();
                FinancialReportWrapper frw = (FinancialReportWrapper) JSON.deserialize(jsonDefinition, FinancialReportWrapper.class);
                frw.reportDefinition.Subtitle__c = subtitle;
                saveAttachment(frw, reportId);
                response.isSuccess = true;
                SFDCSecurityUtils.deleteProxy(attachment);
            }
            else {
                response.isSuccess = false;
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return response;
    }

    @AuraEnabled
    public static FinancialReportWrapper getFinancialReportResultsById(String reportId) {
        FinancialReportWrapper frw;
        try {
            frw = new FinancialReportWrapper();
            Financial_Report_Result__c report = queryFinancialReportResultById(reportId);

            Attachment attachment;
            try {
                attachment = queryAttachment(report.Id);
            }
            catch (QueryException ex) {}

            if (attachment != NULL) {
                String jsonDefinition = attachment.Body.toString();
                frw = (FinancialReportWrapper) JSON.deserialize(jsonDefinition, FinancialReportWrapper.class);
            }
            else if (report.Financial_Report_Definition__r != NULL) {
                frw.reportDefinition = report.Financial_Report_Definition__r;
                frw.rowList = queryFinancialReportRows(frw.reportDefinition.Id);
                frw.colList = queryFinancialReportColumns(frw.reportDefinition.Id);
            }

            frw.reportvalues = queryFinancialReportResultValues(report.Id);
            frw.reportPeriodsByOffset = getAccountingPeriodByOffsetMap(frw.colList, report);
            frw.reportResult = report;

            //validate report data in case of Trial Balance report for Consolidations-Transactional ledger
            if (report.Report_Type__c == 'Trial Balance'
                && report.Ledger__r.Type__c == LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL) {

                Accounting_Period__c priorPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(
                    report.Accounting_Period__c, -1
                );
                if (priorPeriod.Id != null) {
                    Integer fcsCount = DomainUtils.getCountFinancialCubesByPeriodAndTypeAndLedger(
                        new Set<Id>{priorPeriod.Id},
                        new Set<String>{FinancialCubeActions.FINANCIAL_CUBE_CONSOLIDATIONS},
                        new Set<Id>{report.Ledger__c}
                    );
                    if (fcsCount == 0) {
                        frw.missingOpeningBalanceData = true;
                    }
                }
            }
            //=================================================================================================
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }

        return frw;
    }

    @AuraEnabled
    public static Map<String, Object> cloneAsCustom(Map<String, String> params) {
        Map<String, Object> result;
        Savepoint point = Database.setSavepoint();
        try {
            String name = params.get('name');
            String description = params.get('description');
            String reportId = params.get('reportId');

            Attachment attachment;
            try {
                attachment = queryAttachment(reportId);
            }
            catch (QueryException ex) {}

            if (attachment != null) {
                String jsonDefinition = attachment.Body.toString();
                FinancialReportWrapper frw = (FinancialReportWrapper) JSON.deserialize(jsonDefinition, FinancialReportWrapper.class);

                Financial_Report_Definition__c definition = frw.reportDefinition;
                definition.Name = String.isNotBlank(name) ? name : definition.Name;
                definition.Description__c = String.isNotBlank(description) ? description : definition.Description__c;

                SFDCSecurityUtils.insertProxy(definition);

                List<Financial_Report_Column__c> columns = frw.colList;
                List<Decimal> currentPositions = new List<Decimal>();
                String[] formulaCorrections = new String[2];

                for (Financial_Report_Column__c column : columns) {
                    column.Financial_Report_Definition__c = definition.Id;
                    if (isCurrentPeriod(column)) {
                        column.Offset__c = column.Offset__c != 0 ? column.Offset__c * -1 : column.Offset__c;
                        currentPositions.add(column.Position__c);
                    }
                    // correct specific Profit and Loss vs Budget report formulas
                    if (column.Header_1__c == 'Actual Total') {
                        formulaCorrections.add(0, column.Calculation__c);
                    }
                    if (column.Header_1__c == 'Budget Total') {
                        formulaCorrections.add(1, column.Calculation__c);
                    }
                }
                setReverseColumnOrder(columns, currentPositions, formulaCorrections);

                FinancialReportColumnActions.preventValidationTypes.addAll(new Set<FinancialReportColumnActions.ValidationType>{
                        FinancialReportColumnActions.ValidationType.POSITION,
                        FinancialReportColumnActions.ValidationType.CALCULATION
                });

                SFDCSecurityUtils.insertProxy(columns);

                List<Financial_Report_Row__c> rows = frw.rowList;
                for (Financial_Report_Row__c row : rows) {
                    row.Financial_Report_Definition__c = definition.Id;
                    if (isFakeGLAccount(row)) {
                        row.Row_Label__c = null;
                        row.GL_Account__c = null;
                        row.Type__c = FinancialReportRowActions.FRR_TYPE_BLANK;
                    }
                    if (row.Row_Label__c == 'Total Revenue' || row.Row_Label__c == 'Total Expense' || isBalanceSheetTotal(row)) {
                        row.Indent__c = null;
                    }
                    // fix suppress zero empty row formula
                    if (row.Type__c == FinancialReportColumnActions.FRC_TYPE_CALCULATION_NUMBER && String.isBlank(row.Calculation__c)) {
                        row.Calculation__c = '{r' + String.valueOf(Integer.valueOf(row.Position__c - 10)) + '}';
                    }
                    //move Calculation formula from the Calculation field (MAX 255) to the Calculation Long (MAX 131072)
                    //if the formula has more than 255 characters
                    if (row.Type__c == FinancialReportColumnActions.FRC_TYPE_CALCULATION_NUMBER
                            && String.isNotBlank(row.Calculation__c)
                            && row.Calculation__c.length() > Financial_Report_Row__c.Calculation__c.getDescribe().getLength()) {

                        row.Calculation_Long__c = row.Calculation__c;
                        row.Calculation__c = FinancialReportRowActions.CALC_IS_MOVED_PLACEHOLDER;
                    }
                }
                FinancialReportRowActions.preventValidationTypes.addAll(new Set<FinancialReportRowActions.ValidationType>{
                        FinancialReportRowActions.ValidationType.CALCULATION
                });

                SFDCSecurityUtils.insertProxy(rows);

                result = new Map<String, Object>{'definitionId' => definition.Id};
            }
        } catch (AuraHandledException ex) {
            Database.rollback(point);
            throw ex;
        } catch (Exception ex) {
            Database.rollback(point);
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }

        return result;
    }

    private static void setReverseColumnOrder(List<Financial_Report_Column__c> columns,
                                                List<Decimal> currentPositions,
                                                List<String> formulaCorrections) {
        for (Financial_Report_Column__c column : columns) {
            if (isCurrentPeriod(column)) {
                column.Position__c = currentPositions[(currentPositions.size() - 1) - Integer.valueOf(column.Position__c)];
            }
            // correct specific Profit and Loss vs Budget report formulas
            if (column.Header_1__c == 'Actual Total' && formulaCorrections.get(1) != null) {
                column.Calculation__c = formulaCorrections.get(1);
            }
            if (column.Header_1__c == 'Budget Total' && formulaCorrections.get(0) != null) {
                column.Calculation__c = formulaCorrections.get(0);
            }
        }
    }

    private static Boolean isBalanceSheetTotal(Financial_Report_Row__c row) {
        return row.Row_Label__c == 'Total Assets'
            || row.Row_Label__c == 'Total Liabilities'
            || row.Row_Label__c == 'Total Owners Equity'
            || row.Row_Label__c == 'Total Liabilities & Equity';
    }

    private static Boolean isFakeGLAccount(Financial_Report_Row__c row) {
        return row.Row_Label__c == 'Dummy GL Account'
            || row.Row_Label__c == BalanceSheetFinancialReport.DUMMY_ASSETS_GL_ACCOUNT
            || row.Row_Label__c == BalanceSheetFinancialReport.DUMMY_LIABILITIES_GL_ACCOUNT
            || row.Row_Label__c == BalanceSheetFinancialReport.DUMMY_OWNERS_GL_ACCOUNT;
    }

    private static Boolean isCurrentPeriod(Financial_Report_Column__c column) {
        return column.Type__c == FinancialReportColumnActions.FRC_TYPE_CURRENT_PERIOD
            || column.Type__c == FinancialReportColumnActions.FRC_TYPE_YEAR_TO_DATE;
    }

    private static Financial_Report_Result__c queryFinancialReportResultById(String finReportResultId) {
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Financial_Report_Definition__r.Name',
            'Accounting_Period__c',
            'Accounting_Period__r.Name',
            'End_Accounting_Period__c',
            'Rounding__c',
            'Report_Type__c',
            'Ledger__c',
            'Ledger__r.Type__c',
            'Budget_Ledger__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c'
        };
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }
        String queryCondition = 'Id = :finReportResultId';
        SOQLBuilder theQuery = new SOQLBuilder(Financial_Report_Result__c.SObjectType);
        theQuery
            .setStripInaccessible(AccessType.READABLE)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        List<Financial_Report_Result__c> result = (List<Financial_Report_Result__c>) theQuery.getAccessDecisionResult(Database.query(theQuery.toSOQL()));
        return result.isEmpty() ? null : result.get(0);
    }

    private static List<Financial_Report_Row__c> queryFinancialReportRows(String financialReportDefinitionId) {
        List<String> queryFields = new List<String>{
            'GL_Account__c',
            'Position__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c'
        };
        String queryCondition =
            'Financial_Report_Definition__c = :financialReportDefinitionId ORDER BY Position__c ASC';
        SOQLBuilder theQuery = new SOQLBuilder(Financial_Report_Row__c.SObjectType);
        theQuery
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Financial_Report_Row__c>) Database.query(theQuery.toSOQL());
    }

    private static List<Financial_Report_Column__c> queryFinancialReportColumns(String financialReportDefinitionId) {
        List<String> queryFields = new List<String>{
            'Offset__c',
            'Position__c',
            'Type__c'
        };
        String queryCondition =
            'Financial_Report_Definition__c = :financialReportDefinitionId ORDER BY Position__c ASC';
        SOQLBuilder theQuery = new SOQLBuilder(Financial_Report_Column__c.SObjectType);
        theQuery
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Financial_Report_Column__c>) Database.query(theQuery.toSOQL());
    }

    private static List<Financial_Report_Result_Value__c> queryFinancialReportResultValues(String finReportResultId) {
        List<String> queryFields = new List<String>{
            'Column_Header_1__c',
            'Column_Header_2__c',
            'Text_Value__c',
            'Currency_Value__c',
            'Financial_Report_Column__c',
            'Indent__c',
            'Underline__c',
            'Row_Position__c',
            'Column_Position__c',
            'Financial_Report_Column__r.Position__c',
            'Financial_Report_Column__r.Ledger__c',
            'Row_Type__c',
            'Column_Type__c',
            'Financial_Report_Row__c',
            'Suppress_Print__c',
            'Financial_Report_Row__r.Position__c',
            'Row_Label__c',
            'Financial_Report_Result__r.Financial_Report_Definition__c',
            'Column_Override_Row__c',
            'Financial_Report_Result__c',
            'Suppress_Cell_Hyperlink__c',
            'Id',
            'Name'
        };
        String queryCondition =
            'Financial_Report_Result__c = :finReportResultId ' +
                'AND Suppress_Print__c = false ' +
                'ORDER BY Column_Position__c ASC, Row_Position__c ASC';

        SOQLBuilder theQuery = new SOQLBuilder(Financial_Report_Result_Value__c.SObjectType);
        theQuery
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        //to add localized currency value
        String soqlString = theQuery.toSOQL().replace('Currency_Value__c', 'Currency_Value__c, FORMAT(Currency_Value__c) currValue');

        return (List<Financial_Report_Result_Value__c>) Database.query(soqlString);
    }

    private static Attachment queryAttachment(String finReportResultId) {
        List<String> queryFields = new List<String>{
            'Id', 'Name', 'Body'
        };
        String queryCondition =
            'ParentId = :finReportResultId AND Name = \'Financial_Report_Definition\' ORDER BY CreatedDate DESC LIMIT 1';
        SOQLBuilder theQuery = new SOQLBuilder(Attachment.SObjectType);
        theQuery
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (Attachment) Database.query(theQuery.toSOQL());
    }

    private static Map<Integer, Accounting_Period__c> getAccountingPeriodByOffsetMap(
        List<Financial_Report_Column__c> colList, Financial_Report_Result__c report
    ) {
        String currentPeriodName = report.Accounting_Period__r.Name;
        Map<Integer, Accounting_Period__c> result = new Map<Integer, Accounting_Period__c>();
        AccountingPeriodHandler apHandler = AccountingPeriodHandler.getInstance();
        Integer zeroOffsetPosition = 0;

        for (Financial_Report_Column__c col : colList) {
            if (col.Type__c == FinancialReportColumnActions.FRC_TYPE_CURRENT_PERIOD
                || col.Type__c == FinancialReportColumnActions.FRC_TYPE_YEAR_TO_DATE) {
                if (Integer.valueOf(col.Offset__c) == 0) {
                    break;
                }
                zeroOffsetPosition ++;
            }
        }

        List<Accounting_Period__c> selectedPeriods = apHandler.getAccountingPeriodsFromRange(report.Accounting_Period__c, report.End_Accounting_Period__c);
        if (selectedPeriods.size() > zeroOffsetPosition) {
            currentPeriodName = selectedPeriods[zeroOffsetPosition].Name;
        }

        for (Financial_Report_Column__c col : colList) {
            if (col.Type__c == FinancialReportColumnActions.FRC_TYPE_CURRENT_PERIOD
                    || col.Type__c == FinancialReportColumnActions.FRC_TYPE_YEAR_TO_DATE) {

                Integer offset = Integer.valueOf(col.Offset__c);
                result.put(offset, apHandler.getAccountingPeriodByOffset(currentPeriodName, offset));
            }
        }
        return result;
    }

    private static void saveAttachment(FinancialReportWrapper frw, String reportResultId) {
        String jsonDefinition = frw != NULL ? JSON.serialize(frw) : NULL;

        Attachment attachment = new Attachment();
        attachment.Body = Blob.valueOf(jsonDefinition);
        attachment.Name = String.valueOf('Financial_Report_Definition');
        attachment.ParentId = reportResultId;

        SFDCSecurityUtils.insertProxy(attachment);
    }

}