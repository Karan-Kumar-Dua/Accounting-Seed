global with sharing class FinancialReporter {
   
    global class FinancialReporterException extends Exception{}
    @TestVisible
    private static final String INVALID_REPORT_TYPE_ERROR = Label.ERR_INVALID_REPORT_TYPE;
    @TestVisible
    private static final String START_PERIOD_REQUIRED_ERROR = Label.ERR_START_PERIOD_REQUIRED;
    @TestVisible
    private static final String PERIOD_REQUIRED_ERROR = Label.ERR_ACCOUNTING_PERIOD_REQUIRED;
    @TestVisible
    private static final String END_PERIOD_REQUIRED_ERROR = Label.ERR_END_PERIOD_REQUIRED;
    @TestVisible
    private static final String END_PERIOD_BEFORE_START_PERIOD_ERROR = Label.ERR_END_PERIOD_BEFORE_START_PERIOD;
    @TestVisible
    private static final String ACCOUNTING_PERIOD_RANGE_LIMIT_ERROR = String.format(Label.ERR_ACCOUNTING_PERIOD_RANGE_LIMIT, new List<Object>{ FinancialReportOptions.ACCOUNTING_PERIOD_RANGE_LIMIT });
    @TestVisible
    private static final String LEDGER_REQUIRED_ERROR = Label.ERR_LEDGER_REQUIRED;
    @TestVisible
    private static final String BUDGET_LEDGER_REQUIRED_ERROR = Label.ERR_BUDGET_LEDGER_REQUIRED;
    @TestVisible
    private static final String CURRENCY_MISMATCH_ERROR = Label.ERR_BUDGET_LEDGER_CURRENCY_TRANSACTION_CURRENCY_MISMATCH;
    @TestVisible
    private static final String LEDGER_TYPE_TRANSACTIONAL_ERROR = Label.ERR_LEDGER_TYPE_TRANSACTIONAL;
    @TestVisible
    private static final String BUDGET_LEDGER_TYPE_ERROR = Label.ERR_BUDGET_LEDGER_TYPE;
    @TestVisible
    private static final String END_PERIOD_STATUS_ERROR = Label.ERR_END_PERIOD_STATUS;
    @TestVisible
    private static final String START_PERIOD_STATUS_ERROR = Label.ERR_START_PERIOD_STATUS;
    @TestVisible
    private static final String PERIOD_STATUS_ERROR = Label.ERR_ACCOUNTING_PERIOD_STATUS;
    @TestVisible
    private static final String PERIOD_IS_IN_ARCHIVE_IN_PROGRESS_STATUS_ERROR = Label.ERR_RUN_REPORT_PERIOD_IS_IN_ARCHIVE_IN_PROGRESS_STATUS;
    @TestVisible
    private static final String PERIOD_IS_IN_OPEN_OR_CLOSED_INTERIM_STATUSES_ERROR = Label.ERR_RUN_REPORT_PERIOD_IS_IN_OPEN_OR_CLOSED_INTERIM_STATUSES;
    @TestVisible
    private static final String INVALID_RECORD_OR_ID = Label.ERR_INVALID_RECORD_OR_ID;
    @TestVisible
    private static final String CASH_FLOW_ACCOUNT_TYPE_ERROR = Label.ERR_CASH_FLOW_ACCOUNT_TYPE_LEDGER_INQUIRY_REPORT;
    @TestVisible
    private static final String CUSTOM_REPORT_REQUIRED_ERROR = Label.ERR_CUSTOM_REPORT_REQUIRED;
    @TestVisible
    public static final String CASH_FLOW_UNCATEGORIZED_RECORDS_ERROR = Label.ERR_CASH_RECEIPT_CASH_FLOW_UNCATEGORIZED_RECORDS;
    @TestVisible
    private static Integer MAX_RETRIEVE_REPORTS = 300;
    @TestVisible
    private static final Integer MAX_RETRIEVE_REPORT = 1;

    private Set<Id> reportResultIds;
    private FinancialReportOptions options;
    private FinancialReportOptions.FinancialReportType reportType;
    private ServiceResult serviceResult;
    private List<ServiceResult.Error> errors;
    private APIServiceContext.APIServiceEntry serviceEntry;

    public FinancialReporter() {
        serviceEntry = new APIServiceContext.APIServiceEntry();
        serviceEntry.isRestContextAccessible = true;
        serviceEntry.isTriggerContextAccessible = true;
    }

    public FinancialReporter(FinancialReportOptions options) {
        this();
        this.options = options;
        if (this.options.includeSubType2 && !this.options.includeSubType1
            && (this.options.reportType == FinancialReportOptions.FinancialReportType.PROFIT_AND_LOSS
                || this.options.reportType == FinancialReportOptions.FinancialReportType.PROFIT_AND_LOSS_VS_BUDGET)) {

            this.options.includeSubType1 = true;
        }
    }

    public FinancialReporter(Set<Id> reportResultIds) {
        this();
        this.reportResultIds = reportResultIds;
    }

    public FinancialReporter(FinancialReportOptions.FinancialReportType reportType) {
        this();
        this.reportType = reportType;
    }

    //=========================   GLOBAL ENTRY POINTS   ===========================================
    // InvocableOptions class is used becuase 
    // 1. FinancialReportOptions class has a constructor which is a limitation for the class containing @InvocableVariable
    // 2. The @InvocableVariable cannot be used with other annotations such as @AuraEnabled
    //
    @InvocableMethod(label='Run Report')
    global static List<FinancialReportResult> runReport(List<FinancialReporterInvocableOptions> invocableOptions) {
        List<FinancialReportResult> FinRepResults = new List<FinancialReportResult>();

        for(FinancialReporterInvocableOptions invocableOption : invocableOptions){
            FinancialReportOptions options = null;
            FinancialReportResult FinRepResult = new FinancialReportResult();
            ServiceResult serviceResult;

            try{
                //get report type enum from string param
                FinancialReportOptions.FinancialReportType finReportType = FinancialReportOptions.FinancialReportType.valueOf(invocableOption.reportType);
                
                //set options defaults based on report type
                switch on finReportType{
                    when PROFIT_AND_LOSS {
                        options = new ProfitAndLossFinancialReportOptions();
                    }
                    when PROFIT_AND_LOSS_VS_BUDGET {
                        ProfitAndLossVsBudgetFinReptOptions rptOptions = new ProfitAndLossVsBudgetFinReptOptions();
                        rptOptions.budgetLedger = invocableOption.budgetLedger != NULL ? invocableOption.budgetLedger : rptOptions.budgetLedger;
                        rptOptions.showAllPeriods = invocableOption.showAllPeriods != NULL ? invocableOption.showAllPeriods : rptOptions.showAllPeriods;
                        options = rptOptions;
                    }
                    when BALANCE_SHEET {
                        options = new BalanceSheetFinancialReportOptions();
                    }
                    when TRIAL_BALANCE {
                        options = new TrialBalanceFinancialReportOptions();
                    }
                    when CASH_FLOW {
                        CashFlowFinancialReportOptions rptOptions = new CashFlowFinancialReportOptions();
                        rptOptions.showAllPeriods = invocableOption.showAllPeriods != NULL ? invocableOption.showAllPeriods : rptOptions.showAllPeriods;
                        options = rptOptions;
                    }
                    when CUSTOM {
                        options = new CustomFinancialReportOptions(invocableOption.financialReportDefinitionId);
                    }
                    
                }
            } catch (Exception e){
                FinRepResult.isSuccess = false;
                FinRepResult.errors.add(INVALID_REPORT_TYPE_ERROR);
                FinRepResults.add(FinRepResult);
                continue;
            }



            //override defaults if values specified in Flow
            options.ledger = invocableOption.ledger != NULL ? invocableOption.ledger : options.ledger;
            options.startingAccountingPeriod = invocableOption.startingAccountingPeriod != NULL ? invocableOption.startingAccountingPeriod : options.startingAccountingPeriod;
            options.endingAccountingPeriod = invocableOption.endingAccountingPeriod != NULL ? invocableOption.endingAccountingPeriod : options.endingAccountingPeriod;
            options.includeSubType1 = invocableOption.includeSubType1 != NULL ? invocableOption.includeSubType1 : options.includeSubType1;
            options.includeSubType2 = invocableOption.includeSubType2 != NULL ? invocableOption.includeSubType2 : options.includeSubType2;
            options.suppressZeroAmountRows = invocableOption.suppressZeroAmountRows != NULL ? invocableOption.suppressZeroAmountRows : options.suppressZeroAmountRows;
            options.subtitle = invocableOption.subtitle != NULL ? invocableOption.subtitle : options.subtitle;
            options.glVariable1 = invocableOption.glVariable1 != NULL ? invocableOption.glVariable1 : options.glVariable1;
            options.glVariable2 = invocableOption.glVariable2 != NULL ? invocableOption.glVariable2 : options.glVariable2;
            options.glVariable3 = invocableOption.glVariable3 != NULL ? invocableOption.glVariable3 : options.glVariable3;
            options.glVariable4 = invocableOption.glVariable4 != NULL ? invocableOption.glVariable4 : options.glVariable4;
            options.suppressOpeningBalanceAndPeriodColumns = invocableOption.suppressOpeningBalanceAndPeriodColumns != NULL ? invocableOption.suppressOpeningBalanceAndPeriodColumns : options.suppressOpeningBalanceAndPeriodColumns;
            //we do not provide validation on this through the API, if a iso code is passed in that does not exist the report will run and have zero results
            options.currencyISO = invocableOption.currencyISO != NULL ? invocableOption.currencyISO : options.currencyISO;
            
            
            if(invocableOption.roundingMode != null){
                options.setRoundingMode(FinancialReportOptions.FinancialReportRoundingMode.valueOf(invocableOption.roundingMode));
            }
    
            serviceResult = FinancialReporter.runReport(options);
           
            if(serviceResult.isSuccess){
                FinRepResult.isSuccess = true;
                FinRepResult.data = serviceResult.data;
            }else{
                for(ServiceResult.Error e : serviceResult.errors){
                    FinRepResult.errors.add(e.detail);
                }
            }
            FinRepResults.add(FinRepResult);
        }
        return FinRepResults;
    }

    global static ServiceResult runReport(FinancialReportOptions options) {
        ServiceResult serviceResult;
        try {
            FinancialReporter finRepService = new FinancialReporter(options);
            serviceResult = APIServiceContext.validateServiceContext(finRepService.serviceEntry);
            if (serviceResult.isSuccess) {
                serviceResult = finRepService.runReport();
            }
        }
        catch (Exception ex) {
            serviceResult = new ServiceResult(null, ex.getTypeName(), ex.getMessage());
        }

        return serviceResult;
    }

    global static ServiceResult reRunReport(Id reportId) {
        ServiceResult serviceResult;

        try {
            FinancialReporter finRepService = new FinancialReporter();
            Financial_Report_Result__c FRR = retrieveReport(reportId);
            FinancialReportOptions options = finRepService.convertFinRepResultToFinRepOptions(FRR);
    
            finRepService = new FinancialReporter(options);
            serviceResult = APIServiceContext.validateServiceContext(finRepService.serviceEntry);
            if (serviceResult.isSuccess) {
                serviceResult = finRepService.runReport();
            }  
        }
        catch (Exception ex) {
            serviceResult = new ServiceResult(null, ex.getTypeName(), ex.getMessage());
        }

        return serviceResult;
    }

    global static ServiceResult deleteReports(Set<Id> reportIds) {
        ServiceResult serviceResult;
        try {
            FinancialReporter finRepService = new FinancialReporter(reportIds);
            serviceResult = APIServiceContext.validateServiceContext(finRepService.serviceEntry);
            if (serviceResult.isSuccess) {
                serviceResult = finRepService.deleteReports();
            }
        }
        catch (Exception ex) {
            serviceResult = new ServiceResult(null, ex.getTypeName(), ex.getMessage());
        }

        return serviceResult;
    }

    global static List<Financial_Report_Result__c> retrieveReports(FinancialReportOptions.FinancialReportType reportType) {
        List<Financial_Report_Result__c> results = new List<Financial_Report_Result__c>();

        FinancialReporter finRepService = new FinancialReporter(reportType);
        ServiceResult serviceResult = APIServiceContext.validateServiceContext(finRepService.serviceEntry);
        if (serviceResult.isSuccess) {
            results = finRepService.retrieveReports();
        }

        return results;
    }

    // TODO: For future use. Once used, change to global.
    public static Financial_Report_Result__c retrieveReport(Id reportId) {
        Financial_Report_Result__c result;

        FinancialReporter finRepService = new FinancialReporter(new Set<Id>{ reportId });
        ServiceResult serviceResult = APIServiceContext.validateServiceContext(finRepService.serviceEntry);
        if (serviceResult.isSuccess) {
            result = finRepService.retrieveReport();
        }

        return result;
    }
    //============================================================================================//

    private ServiceResult runReport() {
        if (options != NULL) {
            if (validateReportOptions()) {
                FinancialReport report = getReport();
                FinancialReportWrapper frw = report.runReport(options);
                serviceResult = new ServiceResult(frw.reportResult.Id, true);
            }
        }
        else {
            serviceResult = new ServiceResult(NULL, 'NO_DATA_PROVIDED', Label.ERR_FINANCIAL_REPORT_OPTIONS_NOT_PROVIDED);
        }
        return serviceResult;
    }

    private FinancialReport getReport() {
        AbstractFinancialReport afr;
        switch on options.reportType {
            when PROFIT_AND_LOSS {
                afr = new ProfitAndLossFinancialReport();
            }
            when PROFIT_AND_LOSS_VS_BUDGET {
                afr = new ProfitAndLossVsBudgetFinancialReport();
            }
            when BALANCE_SHEET {
                afr = new BalanceSheetFinancialReport();
            }
            when TRIAL_BALANCE {
                afr = new TrialBalanceFinancialReport();
            }
            when CASH_FLOW {
                afr = new CashFlowStatementReport();
            }
            when CUSTOM {
                afr = new CustomReportFinancialReport();
            }
        }
        return afr;
    }

    private ServiceResult deleteReports() {
        try {
            if (reportResultIds != null && !reportResultIds.isEmpty()) {
                SFDCSecurityUtils.deleteCheckCRUDAndFLS(
                    DomainUtils.getFinancialReportResultsById(reportResultIds)
                );
            }
            serviceResult = new ServiceResult(NULL, true);
        }
        catch (Exception ex) {
            serviceResult = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }
        return serviceResult;
    }

    private List<Financial_Report_Result__c> retrieveReports() {
        List<Financial_Report_Result__c> result = new List<Financial_Report_Result__c>();
        List<String> fields = new List<String> {
            'Id',
            'Name',
            'CreatedById',
            'CreatedBy.Name',
            'Run_Finished__c',
            'Status__c',
            'Ledger__c',
            'Ledger__r.Name',
            'Budget_Ledger__c',
            'Budget_Ledger__r.Name',
            'Accounting_Period__c',
            'Accounting_Period__r.Name',
            'End_Accounting_Period__c',
            'End_Accounting_Period__r.Name',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c',
            'GL_Account_Variable_1__r.Name',
            'GL_Account_Variable_2__r.Name',
            'GL_Account_Variable_3__r.Name',
            'GL_Account_Variable_4__r.Name',
            'Financial_Report_Definition__c',
            'Financial_Report_Definition__r.Name',
            'Suppress_Opening_Balance_and_Period__c',
            'Include_Sub_Type_1__c',
            'Include_Sub_Type_2__c',
            'Rounding__c',
            'Subtitle__c',
            'Suppress_Zero_Amount_Rows__c',
            'Report_Type__c',
            'Show_All_Periods__c'
        };

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            fields.add('CurrencyIsoCode');
        }

        String reportTypeName = FinancialReportOptions.getReportTypeName(reportType);
        String queryCondition = 'Report_Type__c = :reportTypeName';

        SOQLBuilder.Ordering ordering = new SOQLBuilder.Ordering('Financial_Report_Result__c', 'Run_Started__c', SOQLBuilder.SortOrder.DESCENDING);

        SOQLBuilder queryBuilder = new SOQLBuilder(Financial_Report_Result__c.SObjectType);
        queryBuilder
            .setStripInaccessible(AccessType.READABLE)
            .selectFields(fields)
            .setCondition(queryCondition)
            .setLimit(MAX_RETRIEVE_REPORTS)
            .addOrdering(ordering);

        result = (List<Financial_Report_Result__c>) queryBuilder.getAccessDecisionResult(
            Database.query(queryBuilder.toSOQL())
        );

        return result;
    }

    private Financial_Report_Result__c retrieveReport() {
        Financial_Report_Result__c result;

        List<String> fields = new List<String> {
            'Id',
            'Name',
            'CreatedById',
            'CreatedBy.Name',
            'Run_Finished__c',
            'Status__c',
            'Ledger__c',
            'Ledger__r.Name',
            'Budget_Ledger__c',
            'Budget_Ledger__r.Name',
            'Accounting_Period__c',
            'Accounting_Period__r.Name',
            'End_Accounting_Period__c',
            'End_Accounting_Period__r.Name',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c',
            'GL_Account_Variable_1__r.Name',
            'GL_Account_Variable_2__r.Name',
            'GL_Account_Variable_3__r.Name',
            'GL_Account_Variable_4__r.Name',
            'Financial_Report_Definition__c',
            'Financial_Report_Definition__r.Name',
            'Suppress_Opening_Balance_and_Period__c',
            'Include_Sub_Type_1__c',
            'Include_Sub_Type_2__c',
            'Rounding__c',
            'Subtitle__c',
            'Suppress_Zero_Amount_Rows__c',
            'Report_Type__c',
            'Show_All_Periods__c'
        };

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            fields.add('CurrencyIsoCode');
        }

        String queryCondition = 'Id IN :reportResultIds';

        SOQLBuilder queryBuilder = new SOQLBuilder(Financial_Report_Result__c.SObjectType);
        queryBuilder
            .setStripInaccessible(AccessType.READABLE)
            .selectFields(fields)
            .setCondition(queryCondition)
            .setLimit(MAX_RETRIEVE_REPORT);

        List<Financial_Report_Result__c> frrs = new List<Financial_Report_Result__c>();
        frrs = (List<Financial_Report_Result__c>) queryBuilder.getAccessDecisionResult(
            Database.query(queryBuilder.toSOQL())
        );
        result = frrs.isEmpty() ? NULL : frrs[0];

        return result;
    }

    private FinancialReportOptions convertFinRepResultToFinRepOptions(Financial_Report_Result__c FRR){
        FinancialReportOptions FinRepOptions = null;
        //Determine report type from FRR
        switch on FRR.Report_Type__c {
            when 'Profit & Loss' {
                FinRepOptions = new ProfitAndLossFinancialReportOptions();
            }
            when 'Profit & Loss Versus Budget' {
                ProfitAndLossVsBudgetFinReptOptions rptOptions = new ProfitAndLossVsBudgetFinReptOptions();
                rptOptions.budgetLedger = FRR.Budget_Ledger__c;
                rptOptions.showAllPeriods = FRR.Show_All_Periods__c;
                FinRepOptions = rptOptions;
            }
            when 'Balance Sheet' {
                FinRepOptions = new BalanceSheetFinancialReportOptions();
            }
            when 'Trial Balance'{
                FinRepOptions = new TrialBalanceFinancialReportOptions();
            }
            when 'Cash Flow Statement'{
                CashFlowFinancialReportOptions rptOptions = new CashFlowFinancialReportOptions();
                rptOptions.showAllPeriods = FRR.Show_All_Periods__c;
                FinRepOptions = rptOptions;
            }
            when 'Custom Report'{
                FinRepOptions = new CustomFinancialReportOptions(FRR.Financial_Report_Definition__c);
            }
            when else {
                throw new FinancialReporterException(INVALID_REPORT_TYPE_ERROR);
            }
        }

        FinRepOptions.ledger = FRR.Ledger__c;
        FinRepOptions.startingAccountingPeriod = FRR.Accounting_Period__c ;
        FinRepOptions.endingAccountingPeriod = FRR.End_Accounting_Period__c ;
        FinRepOptions.glVariable1 = FRR.GL_Account_Variable_1__c;
        FinRepOptions.glVariable2 = FRR.GL_Account_Variable_2__c;
        FinRepOptions.glVariable3 = FRR.GL_Account_Variable_3__c;
        FinRepOptions.glVariable4 = FRR.GL_Account_Variable_4__c;

        FinRepOptions.includeSubType1 = FRR.Include_Sub_Type_1__c;
        FinRepOptions.includeSubType2 = FRR.Include_Sub_Type_2__c;
        FinRepOptions.suppressZeroAmountRows = FRR.Suppress_Zero_Amount_Rows__c;
        FinRepOptions.subtitle = FRR.Subtitle__c;
        FinRepOptions.suppressOpeningBalanceAndPeriodColumns = FRR.Suppress_Opening_Balance_and_Period__c;
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            FinRepOptions.currencyISO = (String)FRR.get('CurrencyIsoCode');
        }
        
        FinRepOptions.currentRoundingMode = FRR.Rounding__c;
        
       

        return FinRepOptions;
    }

//VALIDATION========================================================================================
    private Boolean validateReportOptions() {
        switch on options.reportType {
            when PROFIT_AND_LOSS {
                validateProfitAndLossOptions();
            } when PROFIT_AND_LOSS_VS_BUDGET {
                validateProfitAndLossVsBudgetOptions();
            } when BALANCE_SHEET {
                validateBalanceSheetOptions();
            } when TRIAL_BALANCE {
                validateTrialBalanceOptions();
            } when CASH_FLOW {
                validateCashFlowOptions();
            } when LEDGER_INQUIRY {
                validateLedgerInquiryOptions();
            } when CUSTOM {
                validateCustomReportOptions();
            }
        }
        return serviceResult.isSuccess;
    }

    public ServiceResult validateLedgerInquiryReportOptions(){
        validateLedgerInquiryOptions();
        return serviceResult;
    }

    private void validateProfitAndLossOptions() {
        this.errors = new List<ServiceResult.Error>();
        validateLedger();
        validateGLAVs();
        if (validateStartingAccountingPeriod() & validateEndingAccountingPeriod()) {
            //it makes sense to validate period's combinations only if both periods are valid
            validateEndingPeriodAfterStarting();
            validateAccountingPeriodRange();
            validateAccountingPeriodsInRangeNotBeingArchived(true);
        }
        if (this.errors.isEmpty()) {
            serviceResult = new ServiceResult(NULL, true);
        }
        else {
            serviceResult = new ServiceResult(NULL, false, errors);
        }
    }

    private void validateProfitAndLossVsBudgetOptions() {
        this.errors = new List<ServiceResult.Error>();
        validateLedger();
        validateBudgetLedger();
        validateGLAVs();
        if (validateStartingAccountingPeriod() & validateEndingAccountingPeriod()) {
            //it makes sense to validate period's combinations only if both periods are valid
            validateEndingPeriodAfterStarting();
            validateAccountingPeriodRange();
            validateAccountingPeriodsInRangeNotBeingArchived(true);
        }
        if (this.errors.isEmpty()) {
            serviceResult = new ServiceResult(NULL, true);
        }
        else {
            serviceResult = new ServiceResult(NULL, false, errors);
        }
    }

    private void validateBalanceSheetOptions() {
        this.errors = new List<ServiceResult.Error>();
        validateLedger();
        validateGLAVs();
        if (validateStartingAccountingPeriod() & validateEndingAccountingPeriod()) {
            validateEndingPeriodAfterStarting();
            validateAccountingPeriodRange();
            validateStartPeriodStatus();
            validateEndPeriodStatus();
            validateAccountingPeriodsInRangeNotBeingArchived(true);
            validateAccountingPeriodsInRangeNotBeingClosedOrOpened(true);
        }
        if (this.errors.isEmpty()) {
            serviceResult = new ServiceResult(NULL, true);
        }
        else {
            serviceResult = new ServiceResult(NULL, false, errors);
        }
    }

    private void validateTrialBalanceOptions() {
        this.errors = new List<ServiceResult.Error>();
        validateLedger();
        validateGLAVs();
        if (validateStartingAccountingPeriod()) {
            validateStartPeriodStatus();
            validateAccountingPeriodsInRangeNotBeingArchived(false);
            validateAccountingPeriodsInRangeNotBeingClosedOrOpened(false);

        }
        if (this.errors.isEmpty()) {
            serviceResult = new ServiceResult(NULL, true);
        }
        else {
            serviceResult = new ServiceResult(NULL, false, errors);
        }
    }

    private void validateCashFlowOptions() {
        this.errors = new List<ServiceResult.Error>();
        validateLedger();
        validateGLAVs();
        if (validateStartingAccountingPeriod()) {
            validateStartPeriodStatus();
            validateAccountingPeriodsInRangeNotBeingArchived(false);
            validateAccountingPeriodsInRangeNotBeingClosedOrOpened(false);
            validateCashFlowRecordsAreCategorized();
        }
        if (this.errors.isEmpty()) {
            serviceResult = new ServiceResult(NULL, true);
        }
        else {
            serviceResult = new ServiceResult(NULL, false, errors);
        }
    }

    private void validateLedgerInquiryOptions() {
        this.errors = new List<ServiceResult.Error>();
        validateLedger();
        validateLedgerInquiryGLAccountType();
        if (validateStartingAccountingPeriod() & validateEndingAccountingPeriod()) {
            validateEndingPeriodAfterStarting();
            validateAccountingPeriodRange();
            validateStartPeriodStatus();
            validateEndPeriodStatus();
            validateAccountingPeriodsInRangeNotBeingArchived(true);
            validateAccountingPeriodsInRangeNotBeingClosedOrOpened(true);
        }
        if (this.errors.isEmpty()) {
            serviceResult = new ServiceResult(NULL, true);
        }
        else {
            serviceResult = new ServiceResult(NULL, false, errors);
        }
    }

    private void validateCustomReportOptions() {
        this.errors = new List<ServiceResult.Error>();
        Boolean isCRDef = validateCustomReportDefinition();
        if (validateStartingAccountingPeriod() && isCRDef && !validateCustomReportOnlyExpenseOrRevenueGLAccounts()){
            validateStartPeriodStatus();
        }
        if (this.errors.isEmpty()) {
            serviceResult = new ServiceResult(NULL, true);
        }
        else {
            serviceResult = new ServiceResult(NULL, false, errors);
        }
    }


    private Boolean validateStartingAccountingPeriod() {
        Boolean isValid = true;
        ServiceResult.Error error = new ServiceResult.Error();
        if (!FinancialSuiteUtils.isValidId(this.options.startingAccountingPeriod, Accounting_Period__c.SObjectType)) {
            if(this.options.reportType == FinancialReportOptions.FinancialReportType.TRIAL_BALANCE ||
                this.options.reportType == FinancialReportOptions.FinancialReportType.CASH_FLOW ||
                this.options.reportType == FinancialReportOptions.FinancialReportType.CUSTOM){
                error = new ServiceResult.Error(PERIOD_REQUIRED_ERROR);
            }else{
                error = new ServiceResult.Error(START_PERIOD_REQUIRED_ERROR);
            }
            this.errors.add(error);
            isValid = false;
        }
        return isValid;
    }

    private Boolean validateEndingAccountingPeriod() {
        Boolean isValid = true;
        if (!FinancialSuiteUtils.isValidId(this.options.endingAccountingPeriod, Accounting_Period__c.SObjectType)) {
            ServiceResult.Error error = new ServiceResult.Error(END_PERIOD_REQUIRED_ERROR);
            this.errors.add(error);
            isValid = false;
        }
        return isValid;
    }

    private Boolean validateEndingPeriodAfterStarting() {
        Boolean isValid = true;
        if (AccountingPeriodHandler.getInstance().compareAccountingPeriods(this.options.startingAccountingPeriod, this.options.endingAccountingPeriod) > 0) {
            ServiceResult.Error error = new ServiceResult.Error(END_PERIOD_BEFORE_START_PERIOD_ERROR);
            this.errors.add(error);
            isValid = false;
        }
        return isValid;
    }

    private Boolean validateStartPeriodStatus() {
        Boolean isValid = true;
        ServiceResult.Error error = new ServiceResult.Error();
        if(AccountingPeriodHandler.getInstance().isConsideredOpenForReporting(this.options.startingAccountingPeriod)
            && AccountingPeriodHandler.getInstance().getNumberOfPrecededOpenPeriods(this.options.startingAccountingPeriod) > 0){
                switch on options.reportType {
                    when TRIAL_BALANCE {
                        error = new ServiceResult.Error(PERIOD_STATUS_ERROR);
                        this.errors.add(error);
                        isValid = false;
                    }
                    when CASH_FLOW {
                        error = new ServiceResult.Error(PERIOD_STATUS_ERROR);
                        this.errors.add(error);
                        isValid = false;
                    }
                    when CUSTOM{
                        error = new ServiceResult.Error(PERIOD_STATUS_ERROR);
                        this.errors.add(error);
                        isValid = false;
                    }
                    when LEDGER_INQUIRY {
                        GL_Account__c ledgerInquiryGLAccount = getLedgerInquiryGLAccount();
                        if (ledgerInquiryGLAccount == NULL
                                || ledgerInquiryGLAccount.Type__c == GLAccountActions.GL_ACCOUNT_TYPE_BALANCE_SHEET ) {

                            error = new ServiceResult.Error(START_PERIOD_STATUS_ERROR);
                            this.errors.add(error);
                            isValid = false;
                         }
                    }
                    when else {
                        error = new ServiceResult.Error(START_PERIOD_STATUS_ERROR);
                        this.errors.add(error);
                        isValid = false;
                    }
                }
        }
        return isValid;
    }

    private Boolean validateEndPeriodStatus() {
        Boolean isValid = true;
        ServiceResult.Error error = new ServiceResult.Error();
        if (AccountingPeriodHandler.getInstance().isConsideredOpenForReporting(this.options.endingAccountingPeriod)
                && AccountingPeriodHandler.getInstance().getNumberOfPrecededOpenPeriods(this.options.endingAccountingPeriod) > 0) {

                switch on options.reportType {
                    when LEDGER_INQUIRY {
                        GL_Account__c ledgerInquiryGLAccount = getLedgerInquiryGLAccount();
                        if (ledgerInquiryGLAccount == NULL
                                || ledgerInquiryGLAccount.Type__c == GLAccountActions.GL_ACCOUNT_TYPE_BALANCE_SHEET ) {

                            error = new ServiceResult.Error(END_PERIOD_STATUS_ERROR);
                            this.errors.add(error);
                            isValid = false;
                        }
                    }
                    when else {
                        error = new ServiceResult.Error(END_PERIOD_STATUS_ERROR);
                        this.errors.add(error);
                        isValid = false;
                    }
                }
        }
        return isValid;
    }


    private Boolean validateLedger() {
        Boolean isValid = true;
        if (this.options.ledger == NULL) {
            ServiceResult.Error error = new ServiceResult.Error(LEDGER_REQUIRED_ERROR);
            this.errors.add(error);
            isValid = false;
        } else if (!LedgerHandler.isTransactionalLedger(LedgerHandler.getInstanceWithSharing().getLedgerById(this.options.ledger))) {
            ServiceResult.Error error = new ServiceResult.Error(LEDGER_TYPE_TRANSACTIONAL_ERROR);
            this.errors.add(error);
            isValid = false;
        }
        return isValid;
    }

    private Boolean validateBudgetLedger() {
        Boolean isValid = true;
        Id budgetLedgerId = ((ProfitAndLossVsBudgetFinReptOptions) options).budgetLedger;

        if (budgetLedgerId == NULL) {
            ServiceResult.Error error = new ServiceResult.Error(BUDGET_LEDGER_REQUIRED_ERROR);
            this.errors.add(error);
            isValid = false;
        }
        else if (!LedgerHandler.isBudgetLedger(LedgerHandler.getInstanceWithSharing().getLedgerById(budgetLedgerId))) {
            ServiceResult.Error error = new ServiceResult.Error(BUDGET_LEDGER_TYPE_ERROR);
            this.errors.add(error);
            isValid = false;
        }
        else if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            String budgetLedgerCurrency = LedgerHandler.getLedgerCurrency(budgetLedgerId);
            String trxnLedgerCurrency = LedgerHandler.getLedgerCurrency(this.options.ledger);

            if (budgetLedgerCurrency != trxnLedgerCurrency && this.options.ledger != null) {
                ServiceResult.Error error = new ServiceResult.Error(CURRENCY_MISMATCH_ERROR);
                this.errors.add(error);
            }
        }

        return isValid;
    }

    private Boolean validateLedgerInquiryGLAccountType() {
        Boolean isValid = true;
        GL_Account__c ledgerInquiryGLAccount = getLedgerInquiryGLAccount();
        if (ledgerInquiryGLAccount?.Type__c == GLAccountActions.GL_ACCOUNT_TYPE_CASH_FLOW ) {
            ServiceResult.Error error = new ServiceResult.Error(CASH_FLOW_ACCOUNT_TYPE_ERROR);
            this.errors.add(error);
            isValid = false;
        }
        return isValid;
    }

    private Boolean validateAccountingPeriodRange() {
        Boolean isValid = true;
        List<Accounting_Period__c> periodsInRange =
            AccountingPeriodHandler.getInstance().getAccountingPeriodsFromRange(this.options.startingAccountingPeriod, this.options.endingAccountingPeriod);

            if (periodsInRange.size() > FinancialReportOptions.ACCOUNTING_PERIOD_RANGE_LIMIT) {
                ServiceResult.Error error = new ServiceResult.Error(ACCOUNTING_PERIOD_RANGE_LIMIT_ERROR);
                this.errors.add(error);
                isValid = false;
            }
        return isValid;
    }

    private Boolean validateAccountingPeriodsInRangeNotBeingArchived(Boolean checkPrecedingPeriod) {
        Boolean isValid = true;
        List<Accounting_Period__c> periodsToValidate = new List<Accounting_Period__c>();
        List<Accounting_Period__c> allPeriodsInReportingRange = this.options.getAllPeriodsInReportingRange();
        if (checkPrecedingPeriod && !allPeriodsInReportingRange.isEmpty()) {
            periodsToValidate.add(AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(allPeriodsInReportingRange[0]));
        }
        periodsToValidate.addAll(allPeriodsInReportingRange);

        for (Accounting_Period__c periodInRange : periodsToValidate) {
            if (periodInRange.Status__c == AccountingPeriodActions.ARCHIVE_IN_PROGRESS_STATUS) {
                ServiceResult.Error error = new ServiceResult.Error(PERIOD_IS_IN_ARCHIVE_IN_PROGRESS_STATUS_ERROR);
                this.errors.add(error);
                isValid = false;
                break;
            }
        }
        return isValid;
    }

    private Boolean validateAccountingPeriodsInRangeNotBeingClosedOrOpened(Boolean checkPrecedingPeriod) {
        Boolean isValid = true;
        List<Accounting_Period__c> periodsToValidate = new List<Accounting_Period__c>();
        List<Accounting_Period__c> allPeriodsInReportingRange = this.options.getAllPeriodsInReportingRange();
        if (checkPrecedingPeriod && !allPeriodsInReportingRange.isEmpty()) {
            periodsToValidate.add(AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(allPeriodsInReportingRange[0]));
        }
        periodsToValidate.addAll(allPeriodsInReportingRange);

        for (Accounting_Period__c periodInRange : periodsToValidate) {
            if (periodInRange.Status__c == AccountingPeriodActions.CLOSE_INTERIM_STATUS
                    || periodInRange.Status__c == AccountingPeriodActions.OPEN_INTERIM_STATUS) {

                ServiceResult.Error error = new ServiceResult.Error(PERIOD_IS_IN_OPEN_OR_CLOSED_INTERIM_STATUSES_ERROR);
                this.errors.add(error);
                isValid = false;
                break;
            }
        }
        return isValid;
    }

    private void validateGLAVs() {
        Set<Id> glavIds = new Set<Id>();
        if (isValidGlavId(options.glVariable1, 'glVariable1')) {
            glavIds.add(options.glVariable1);
        }
        if (isValidGlavId(options.glVariable2, 'glVariable2')) {
            glavIds.add(options.glVariable2);
        }
        if (isValidGlavId(options.glVariable3, 'glVariable3')) {
            glavIds.add(options.glVariable3);
        }
        if (isValidGlavId(options.glVariable4, 'glVariable4')) {
            glavIds.add(options.glVariable4);
        }

        Map<Id, Accounting_Variable__c> glavMap = new Map<Id, Accounting_Variable__c>(DomainUtils.getGLAVsById(glavIds));
        if (!glavMap.isEmpty()) {
            if (glavMap.containsKey(options.glVariable1)) {
                validateGlavType(glavMap.get(options.glVariable1), AccountingVariableActions.ACCOUNTING_VARIABLE_TYPE_1, 'glVariable1');
            }
            if (glavMap.containsKey(options.glVariable2)) {
                validateGlavType(glavMap.get(options.glVariable2), AccountingVariableActions.ACCOUNTING_VARIABLE_TYPE_2, 'glVariable2');
            }
            if (glavMap.containsKey(options.glVariable3)) {
                validateGlavType(glavMap.get(options.glVariable3), AccountingVariableActions.ACCOUNTING_VARIABLE_TYPE_3, 'glVariable3');
            }
            if (glavMap.containsKey(options.glVariable4)) {
                validateGlavType(glavMap.get(options.glVariable4), AccountingVariableActions.ACCOUNTING_VARIABLE_TYPE_4, 'glVariable4');
            }
        }

    }

    private Boolean isValidGlavId(Id glavId, String propertyName) {
        Boolean isValid = true;
        if (glavId != NULL && !FinancialSuiteUtils.isValidId(glavId, Accounting_Variable__c.SObjectType)) {
            ServiceResult.Error error = new ServiceResult.Error(propertyName + ': ' + INVALID_RECORD_OR_ID);
            this.errors.add(error);
            isValid = false;
        }
        return isValid;
    }

    private Boolean validateGlavType(Accounting_Variable__c glav, String type, String propertyName) {
        Boolean isValid = true;
        if (glav.Type__c != type) {
            ServiceResult.Error error = new ServiceResult.Error(propertyName + ': ' + INVALID_RECORD_OR_ID);
            this.errors.add(error);
            isValid = false;
        }
        return isValid;
    }

    private Boolean validateCustomReportDefinition() {
        Boolean isValid = true;
        Id customReportDefinitionId = ((CustomFinancialReportOptions) options).financialReportDefinitionId;
        if (customReportDefinitionId == NULL) {
            ServiceResult.Error error = new ServiceResult.Error(CUSTOM_REPORT_REQUIRED_ERROR);
            this.errors.add(error);
            isValid = false;
        }
        return isValid;
    }

    private Boolean validateCustomReportOnlyExpenseOrRevenueGLAccounts() {
        Boolean isValid = false;
        Id customReportDefinitionId = ((CustomFinancialReportOptions) options).financialReportDefinitionId;
        if (customReportDefinitionId != NULL) {
            List<Financial_Report_Definition__c> frd = DomainUtils.getFinancialReportDefinitionWithRows(customReportDefinitionId);
            isValid = frd[0].Financial_Report_Rows__r.size() == 0;
        }
        return isValid;
    }

    private GL_Account__c getLedgerInquiryGLAccount(){
        GL_Account__c ledgerInquiryGLAccount;
        List<GL_Account__c> glAccounts = DomainUtils.getGlAccountsById(new Set<Id>{((LedgerInquiryFinancialReportOptions)options).glAccount});
        if(!glAccounts.isEmpty()){
            ledgerInquiryGLAccount = glAccounts[0];
        }

        return ledgerInquiryGLAccount;
    }

    private Boolean validateCashFlowRecordsAreCategorized() {
        Integer queryLimit = 1;
        // use YTD periods
        List<Accounting_Period__c> prds = AccountingPeriodHandler.getInstance()
            .getPriorAccountingPeriodsForThisYear(options.startingAccountingPeriod, true);
        // check for any uncategorized src docs YTD
        if (!DomainUtils.getUncategorizedCashReceipts(prds, queryLimit).isEmpty()
                || !DomainUtils.getUncategorizedCashDisbursements(prds, queryLimit).isEmpty()
                || !DomainUtils.getUncategorizedJournalEntryLines(prds, queryLimit).isEmpty()) {

            ServiceResult.Error error = new ServiceResult.Error(CASH_FLOW_UNCATEGORIZED_RECORDS_ERROR);
            this.errors.add(error);
            return false;
        }
        return true;
    }

}