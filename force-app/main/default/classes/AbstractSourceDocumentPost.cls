public with sharing abstract class AbstractSourceDocumentPost {

    public static final String POST_INFO_MESSAGE = Label.INF_POSTING_RECORD_TRANSACTION_CREATED;
    public static final String UNPOST_INFO_MESSAGE = Label.INF_UNPOSTING_RECORD_TRANSACTION_REMOVED;
    public static final String POST_COLLECTION_LIMIT_WARNING_MESSAGE = Label.WRN_POST_COLLECTION_LIMIT;
    public static final String UNPOST_COLLECTION_LIMIT_WARNING_MESSAGE = Label.WRN_UNPOST_COLLECTION_LIMIT;

    public Boolean IS_MULTI_CURRENCY_ENABLED {
        get {
            return MultiCurrencyHandler.isMultiCurrencyEnabled;
        }
    }

    protected List<SObject> sObjects;
    protected Boolean batchProcessing;
    protected Set<PostResult.StatusCode> postStatisticsCodes;
    protected Set<PostResult.StatusCode> unpostStatisticsCodes;
    protected Set<String> onlyValidRecordIds;
    @TestVisible
    protected List<PostResult> results = new List<PostResult>();
    @TestVisible
    protected Integer forecastedTransactionsCollectionSize;
    private List<PostResult> badResults = new List<PostResult>();
    public Boolean showActionButton {get; protected set;}
    public Boolean showForecastSection {get; protected set;}
    public Boolean showErrorStatisticsTable {get; protected set;}
    public Boolean showSystemExceptionTable {get; protected set;}
    public Boolean isCashFlowStatementEnabled {get; protected set;}
    public Map<String, String> headerMap {get; protected set;}
    public Map<String, String> helpTextMap {get; protected set;}
    public List<Transaction__c> forecastedTransactions {get; protected set;}
    public List<PostResultDispatcher.StatisticsLine> errorStatisticsLines {get; protected set;}
    public Boolean isLDVBatchContext {
        get {
            return FeatureManagementHandler.isLargeDataVolumeModeEnabled();
        }
        protected set;
    }
    public abstract PageReference post();
    public abstract PageReference unpost();

    //used only for single record post/unpost processing
    protected Boolean processPostResults() {
        for (PostResult result : results) {
            if (!result.isSuccess) {
                badResults.add(result);
            }
        }

        if (!badResults.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, badResults[0].errors[0].message));
            return false;
        }
        else {
            return true;
        }
    }

    protected PageReference ldvPostUnpost(SourceDocumentBatchOptions.ExecutionContext context) {
        List<Id> processedRecordsIds = new List<Id>();
        for (PostResult result : this.results) {
            if (result.isSuccess && String.isNotBlank(result.id)) {
                processedRecordsIds.add(result.id);
            }
        }
        if (!processedRecordsIds.isEmpty() && context == SourceDocumentBatchOptions.ExecutionContext.POST) {
            new PostProcessor().post(processedRecordsIds);
        }
        else if (!processedRecordsIds.isEmpty() && context == SourceDocumentBatchOptions.ExecutionContext.UNPOST) {
            new PostProcessor().unpost(processedRecordsIds);
        }

        ApexPages.addMessage(
            new ApexPages.Message(
                ApexPages.SEVERITY.CONFIRM,
                context == SourceDocumentBatchOptions.ExecutionContext.POST ?
                    Label.INF_LDV_POST_IN_PROGRESS : Label.INF_LDV_UNPOST_IN_PROGRESS
            )
        );
        showActionButton = false;
        showErrorStatisticsTable = false;
        return null;
    }

    protected void ldvBeforePostUnpost(SourceDocumentBatchOptions.ExecutionContext context) {
        ApexPages.addMessage(
            new ApexPages.Message(
                ApexPages.SEVERITY.INFO,
                context == SourceDocumentBatchOptions.ExecutionContext.POST ?
                    Label.INF_LDV_BEFORE_POST : Label.INF_LDV_BEFORE_UNPOST
            )
        );
    }

    //used for single or batch post/unpost processing
    protected PageReference finish(PostResultDispatcher dispatcher) {
        if (batchProcessing) {
            ApexPages.addMessage(
                new ApexPages.Message(
                    dispatcher.getApexPageSeverity(),
                    dispatcher.getExecutionReport()
                )
            );
            showActionButton = false;
            showErrorStatisticsTable = false;
            if (dispatcher.getAllResultsQuantity() > dispatcher.getSuccessResultsQuantity()
                    && !dispatcher.getPostResults().isEmpty()) {

                errorStatisticsLines = dispatcher.buildSystemExceptionLines();
                showSystemExceptionTable = true;
            }
            return NULL;
        }
        else {
            if (processPostResults()) {
                return new PageReference('/' + sObjects[0].Id);
            }
            else {
                showActionButton = false;
                return NULL;
            }
        }
    }

    protected void getBatchProcessingValidationResults(AbstractPostHandler postHandler) {
        if (postHandler.dispatcher.getErrorResultsQuantity() > 0) {
            errorStatisticsLines = postHandler.dispatcher.buildErrorStatisticsLines(
                (postHandler.dispatcher.getExecutionContext() == PostResultDispatcher.ExecutionContext.POST)
                    ? postStatisticsCodes
                    : unpostStatisticsCodes
            );
            showErrorStatisticsTable = true;
        }

        if (postHandler.dispatcher.getSuccessResultsQuantity() == 0) {
            showActionButton = false;
        } else if (postHandler.dispatcher.getSuccessResultsQuantity() > 0
                && isLDVBatchContext
                && !(new Set<SObjectType>{
                    Cash_Receipt__c.SObjectType,
                    Cash_Disbursement__c.SObjectType,
                    Time_Card__c.SObjectType,
                    Scheduled_Revenue_Expense__c.SObjectType
                }).contains(sObjects.getSObjectType())) {
            ldvBeforePostUnpost(postHandler.dispatcher.getExecutionContext() == PostResultDispatcher.ExecutionContext.POST ?
                SourceDocumentBatchOptions.ExecutionContext.POST : SourceDocumentBatchOptions.ExecutionContext.UNPOST);
        }

        ApexPages.addMessage(
            new ApexPages.Message(
                postHandler.dispatcher.getApexPageSeverity(),
                postHandler.dispatcher.getPreExecutionReport()
            )
        );
    }

    protected Boolean trimForecastedTransactionCollectionTo1000() {
        Boolean isCollectionTrimmed = false;
        forecastedTransactionsCollectionSize = this.forecastedTransactions.size();
        List<Transaction__c> trimmedCollection = new List<Transaction__c>();

        if (this.forecastedTransactions.size() > 1000) {
            isCollectionTrimmed = true;
            for (Integer i = 0; i < 1000; i++) {
                trimmedCollection.add(forecastedTransactions.get(i));
            }
            this.forecastedTransactions = trimmedCollection;
        }

        return isCollectionTrimmed;
    }

    protected void setHeaderMap() {
        headerMap = new Map<String, String>{
            'ONLY_ACTUAL_TIME_CARD_ALLOW' => AbstractPostHandler.ONLY_ACTUAL_TIME_CARD_ALLOW_HEADER,
            'MAX_TIME_CARD_DAYS_EXCEEDED' => AbstractPostHandler.MAX_TIME_CARD_DAYS_EXCEEDED_HEADER,
            'LINE_COUNT_LIMIT_EXCEEDED' => AbstractPostHandler.LINE_COUNT_LIMIT_EXCEEDED_HEADER,
            'AVATAX_SERVICE_ERROR' => AbstractPostHandler.AVATAX_SERVICE_ERROR_HEADER,
            'NO_LINES' => AbstractPostHandler.NO_LINES_HEADER,
            'CLOSED_ACCOUNTING_PERIOD' => AbstractPostHandler.CLOSED_ACCOUNTING_PERIOD_HEADER,
            'ALREADY_POSTED' => AbstractPostHandler.ALREADY_POSTED_HEADER,
            'STATUS_NOT_APPROVED' => AbstractPostHandler.STATUS_NOT_APPROVED_HEADER,
            'NO_CONTROL_AR_ACCOUNT_DEFINED' => AbstractPostHandler.NO_CONTROL_AR_ACCOUNT_DEFINED_HEADER,
            'ALREADY_UNPOSTED' => AbstractPostHandler.ALREADY_UNPOSTED_HEADER,
            'BILLING_CASH_RECEIPTS_EXIST' => AbstractPostHandler.BILLING_CASH_RECEIPTS_EXIST_HEADER,
            'BILLING_CREDIT_MEMOS_EXIST' => AbstractPostHandler.BILLING_CREDIT_MEMOS_EXIST_HEADER,
            'NO_CONTROL_AP_ACCOUNT_DEFINED' => AbstractPostHandler.NO_CONTROL_AP_ACCOUNT_DEFINED_HEADER,
            'AP_DISBURSEMENTS_EXIST' => AbstractPostHandler.AP_DISBURSEMENTS_EXIST_HEADER,
            'AP_CREDIT_MEMOS_EXIST' => AbstractPostHandler.AP_CREDIT_MEMOS_EXIST_HEADER,
            'CREDITS_DEBITS_NOT_EQUAL' => AbstractPostHandler.CREDITS_DEBITS_NOT_EQUAL_HEADER,
            'CLEARED_BANK_RECONCILIATION' => AbstractPostHandler.CLEARED_BANK_RECONCILIATION_HEADER,
            'CLEARED_BANK_DEPOSIT' => AbstractPostHandler.CLEARED_BANK_DEPOSIT_HEADER,
            'NO_UNAPPLIED_CASH_CONTROL_ACCOUNT_DEFINED' =>
                AbstractPostHandler.NO_UNAPPLIED_CASH_CONTROL_ACCOUNT_DEFINED_HEADER,
            'PAYMENT_STATUS_VOID' => AbstractPostHandler.PAYMENT_STATUS_VOID_HEADER,
            'NO_DISCOUNT_PAYMENT_ACCOUNT' => AbstractPostHandler.NO_DISCOUNT_PAYMENT_ACCOUNT_HEADER,
            'NO_LABOR_CONTROL_ACCOUNT_DEFINED' => AbstractPostHandler.NO_LABOR_CONTROL_ACCOUNT_DEFINED_HEADER,
            'NO_TASK_EXPENSE_GL_ACCOUNT_DEFINED' => AbstractPostHandler.NO_TASK_EXPENSE_GL_ACCOUNT_DEFINED_HEADER,
            'NO_CONTROL_AR_OR_UNAPPLIED_CASH_ACCOUNT_DEFINED' =>
                AbstractPostHandler.NO_CONTROL_AR_OR_UNAPPLIED_CASH_ACCOUNT_DEFINED_HEADER,
            'DEBIT_GL_ACCOUNT_IS_NULL_OR_SET_TO_AP_CONTROL_ACCOUNT' =>
                AbstractPostHandler.DEBIT_GL_ACCOUNT_IS_NULL_OR_SET_TO_AP_CONTROL_ACCOUNT_HEADER,
            'NO_DEBIT_GL_ACCOUNT' => AbstractPostHandler.NO_DEBIT_GL_ACCOUNT_HEADER,
            'APPLIED_TO_PAYABLE_CREDIT_MEMO' => AbstractPostHandler.APPLIED_TO_PAYABLE_CREDIT_MEMO_HEADER,
            'APPLIED_TO_PAYABLE' => AbstractPostHandler.APPLIED_TO_PAYABLE_HEADER,
            'NO_CASH_FLOW_CATEGORY' => AbstractPostHandler.NO_CASH_FLOW_CATEGORY_HEADER,
            'CASH_FLOW_NON_CONFORMITY' => AbstractPostHandler.CASH_FLOW_NON_CONFORMITY_HEADER,
            'INCORRECT_APD_AMOUNT' => AbstractPostHandler.PAID_AMOUNT_NOT_EQUAL_CD_AMOUNT_HEADER,
            'LEDGER_TYPE_NOT_ALLOWED' => AbstractPostHandler.LEDGER_TYPE_NOT_ALLOWED_HEADER,
            'LEDGER_NO_TAX_SETTINGS' => AbstractPostHandler.NO_LEDGER_TAX_SETTINGS_HEADER,
            'LEDGER_NOT_ENROLLED' => AbstractPostHandler.LEDGER_NOT_ENROLLED_HEADER,
            'CD_CURRENCY_NOT_USD' => AbstractPostHandler.INF_PAYMENT_SERVICES_ERRORS_HEADER,
            'AP_REMITTANCE_EMAIL_BLANK_ON_VENDOR' => AbstractPostHandler.INF_AP_REMITTANCE_ERROR_HEADER,
            'NO_DEFAULT_PAYMENT_METHOD_ON_VENDOR_FOR_ACH_PAYMENT_SERVICE' => AbstractPostHandler.INF_ACH_ERRORS_HEADER,
            'NO_BILLING_ADDRESS_ON_VENDOR_FOR_CHECK_PAYMENT_SERVICE' => AbstractPostHandler.INF_CHECK_ERRORS_HEADER,
            'CANT_PAY_CONTACT_OR_EMPLOYEE_FOR_TYPE_PAYMENT_SERVICE' => AbstractPostHandler.INF_CONTACT_EMPLOYEE_HEADER,
            'POSTING_IN_PROGRESS' => AbstractPostHandler.POSTING_IN_PROGRESS_HEADER,
            'UNPOSTING_IN_PROGRESS' => AbstractPostHandler.UNPOSTING_IN_PROGRESS_HEADER,
            'INACTIVE_DEFAULT_PAYMENT_METHOD' => AbstractPostHandler.INF_PAYMENT_METHOD_INACTIVE_HEADER,
            'CASH_DISBUREMENT_BALANCE_MUST_BE_ZERO' => AbstractPostHandler.INF_CD_BALANCE_MUST_BE_ZERO_HEADER,
            'NO_UNAPPLIED_EXPENSE_GL_ACCOUNT_DEFINED' => AbstractPostHandler.NO_UNAPPLIED_EXPENSE_GL_ACCOUNT_DEFINED_HEADER,
            'NO_UNAPPLIED_REVENUE_GL_ACCOUNT_DEFINED' => AbstractPostHandler.NO_UNAPPLIED_REVENUE_GL_ACCOUNT_DEFINED_HEADER,
            'INACTIVE_VERIFICATION_STATUS_PAYMENT_METHOD' => AbstractPostHandler.INACTIVE_VERIFICATION_STATUS_PAYMENT_METHOD_HEADER,
            'CASHRECEIPT_VOIDED' => AbstractPostHandler.INFO_VOIDED
        };
    }

    protected void setHelpTextMap() {
        helpTextMap = new Map<String, String>{
            'ONLY_ACTUAL_TIME_CARD_ALLOW' => AbstractPostHandler.ONLY_ACTUAL_TIME_CARD_ALLOW_HELP_TEXT,
            'MAX_TIME_CARD_DAYS_EXCEEDED' => AbstractPostHandler.MAX_TIME_CARD_DAYS_EXCEEDED_HELP_TEXT,
            'LINE_COUNT_LIMIT_EXCEEDED' => AbstractPostHandler.LINE_COUNT_LIMIT_EXCEEDED_HELP_TEXT,
            'AVATAX_SERVICE_ERROR' => AbstractPostHandler.AVATAX_SERVICE_ERROR_HELP_TEXT,
            'NO_LINES' => AbstractPostHandler.NO_LINES_HELP_TEXT,
            'CLOSED_ACCOUNTING_PERIOD' => AbstractPostHandler.CLOSED_ACCOUNTING_PERIOD_HELP_TEXT,
            'ALREADY_POSTED' => AbstractPostHandler.ALREADY_POSTED_HELP_TEXT,
            'STATUS_NOT_APPROVED' => AbstractPostHandler.STATUS_NOT_APPROVED_HELP_TEXT,
            'NO_CONTROL_AR_ACCOUNT_DEFINED' => AbstractPostHandler.NO_CONTROL_AR_ACCOUNT_DEFINED_HELP_TEXT,
            'ALREADY_UNPOSTED' => AbstractPostHandler.ALREADY_UNPOSTED_HELP_TEXT,
            'BILLING_CASH_RECEIPTS_EXIST' => AbstractPostHandler.BILLING_CASH_RECEIPTS_EXIST_HELP_TEXT,
            'BILLING_CREDIT_MEMOS_EXIST' => AbstractPostHandler.BILLING_CREDIT_MEMOS_EXIST_HELP_TEXT,
            'NO_CONTROL_AP_ACCOUNT_DEFINED' => AbstractPostHandler.NO_CONTROL_AP_ACCOUNT_DEFINED_HELP_TEXT,
            'AP_DISBURSEMENTS_EXIST' => AbstractPostHandler.AP_DISBURSEMENTS_EXIST_HELP_TEXT,
            'AP_CREDIT_MEMOS_EXIST' => AbstractPostHandler.AP_CREDIT_MEMOS_EXIST_HELP_TEXT,
            'CREDITS_DEBITS_NOT_EQUAL' => AbstractPostHandler.CREDITS_DEBITS_NOT_EQUAL_HELP_TEXT,
            'CLEARED_BANK_RECONCILIATION' => AbstractPostHandler.CLEARED_BANK_RECONCILIATION_HELP_TEXT,
            'CLEARED_BANK_DEPOSIT' => AbstractPostHandler.CLEARED_BANK_DEPOSIT_HELP_TEXT,
            'CASHRECEIPT_STATUS_VOID_ERROR_DECLINED' => AbstractPostHandler.ERR_CASHRECEIPT_STATUS_VOID_ERROR_DECLINED,
            'ERR_CR_POSTED_VOID' => AbstractPostHandler.ERR_CR_POSTED_VOID,
            'INF_CASHRECEIPT_VOID_OR_POST_HELP_TEXT' => AbstractPostHandler.INF_CASHRECEIPT_VOID_OR_POST_HELP_TEXT,
            'NO_UNAPPLIED_CASH_CONTROL_ACCOUNT_DEFINED' =>
                AbstractPostHandler.NO_UNAPPLIED_CASH_CONTROL_ACCOUNT_DEFINED_HELP_TEXT,
            'PAYMENT_STATUS_VOID' => AbstractPostHandler.PAYMENT_STATUS_VOID_HELP_TEXT,
            'NO_DISCOUNT_PAYMENT_ACCOUNT' => AbstractPostHandler.NO_DISCOUNT_PAYMENT_ACCOUNT_HELP_TEXT,
            'NO_LABOR_CONTROL_ACCOUNT_DEFINED' => AbstractPostHandler.NO_LABOR_CONTROL_ACCOUNT_DEFINED_HELP_TEXT,
            'NO_TASK_EXPENSE_GL_ACCOUNT_DEFINED' => AbstractPostHandler.NO_TASK_EXPENSE_GL_ACCOUNT_DEFINED_HELP_TEXT,
            'NO_CONTROL_AR_OR_UNAPPLIED_CASH_ACCOUNT_DEFINED' =>
                AbstractPostHandler.NO_CONTROL_AR_OR_UNAPPLIED_CASH_ACCOUNT_DEFINED_HELP_TEXT,
            'DEBIT_GL_ACCOUNT_IS_NULL_OR_SET_TO_AP_CONTROL_ACCOUNT' =>
                AbstractPostHandler.DEBIT_GL_ACCOUNT_IS_NULL_OR_SET_TO_AP_CONTROL_ACCOUNT_HELP_TEXT,
            'NO_DEBIT_GL_ACCOUNT' => AbstractPostHandler.NO_DEBIT_GL_ACCOUNT_HELP_TEXT,
            'APPLIED_TO_PAYABLE_CREDIT_MEMO' => AbstractPostHandler.APPLIED_TO_PAYABLE_CREDIT_MEMO_HELP_TEXT,
            'APPLIED_TO_PAYABLE' => AbstractPostHandler.APPLIED_TO_PAYABLE_HELP_TEXT,
            'NO_CASH_FLOW_CATEGORY' => AbstractPostHandler.NO_CASH_FLOW_CATEGORY_HELP_TEXT,
            'CASH_FLOW_NON_CONFORMITY' => AbstractPostHandler.CASH_FLOW_NON_CONFORMITY_HELP_TEXT,
            'INCORRECT_APD_AMOUNT' => AbstractPostHandler.PAID_AMOUNT_NOT_EQUAL_CD_AMOUNT_HELP_TEXT,
            'LEDGER_TYPE_NOT_ALLOWED' => AbstractPostHandler.LEDGER_TYPE_NOT_ALLOWED_HELP_TEXT,
            'LEDGER_NO_TAX_SETTINGS' => AbstractPostHandler.NO_LEDGER_TAX_SETTINGS_HELP_TEXT,
            'LEDGER_NOT_ENROLLED' => AbstractPostHandler.INF_LEDGER_NOT_ENROLLED_HELP_TEXT,
            'CD_CURRENCY_NOT_USD' => AbstractPostHandler.INF_CD_CANNOT_POST_CURRENCY_NOT_EQUALS_USD_HELP_TEXT,
            'AP_REMITTANCE_EMAIL_BLANK_ON_VENDOR' => AbstractPostHandler.INF_AP_REMITTANCE_EMAIL_BLANK_ON_VENDOR_HELP_TEXT,
            'NO_DEFAULT_PAYMENT_METHOD_ON_VENDOR_FOR_ACH_PAYMENT_SERVICE' => AbstractPostHandler.INF_PAYMENT_METHOD_REQUIRED_ON_VENDOR_HELP_TEXT,
            'NO_BILLING_ADDRESS_ON_VENDOR_FOR_CHECK_PAYMENT_SERVICE' => AbstractPostHandler.INF_BILLING_ADDRESS_REQUIRED_ON_VENDOR_HELP_TEXT,
            'CANT_PAY_CONTACT_OR_EMPLOYEE_FOR_TYPE_PAYMENT_SERVICE' => AbstractPostHandler.INF_CD_CANNOT_BE_POSTED_FOR_CONTACT_OR_EMPLOYEE_HELP_TEXT,
            'INF_POSTING_IN_PROGRESS_HELP_TEXT' => AbstractPostHandler.INF_POSTING_IN_PROGRESS_HELP_TEXT,
            'INF_UNPOSTING_IN_PROGRESS_HELP_TEXT' => AbstractPostHandler.INF_UNPOSTING_IN_PROGRESS_HELP_TEXT,
            'INACTIVE_DEFAULT_PAYMENT_METHOD' => AbstractPostHandler.INF_PAYMENT_METHOD_INACTIVE_HELP_TEXT,
            'CASH_DISBUREMENT_BALANCE_MUST_BE_ZERO' => AbstractPostHandler.ERR_CD_BALANCE_MUST_BE_ZERO_HELP_TEXT,
            'NO_UNAPPLIED_EXPENSE_GL_ACCOUNT_DEFINED' => AbstractPostHandler.NO_UNAPPLIED_EXPENSE_GL_ACCOUNT_DEFINED_HELP_TEXT,
            'NO_UNAPPLIED_REVENUE_GL_ACCOUNT_DEFINED' => AbstractPostHandler.NO_UNAPPLIED_REVENUE_GL_ACCOUNT_DEFINED_HELP_TEXT,
            'INACTIVE_VERIFICATION_STATUS_PAYMENT_METHOD' => AbstractPostHandler.INACTIVE_VERIFICATION_STATUS_PAYMENT_METHOD_HELP_TEXT
        };
    }

}