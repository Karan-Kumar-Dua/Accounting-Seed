global with sharing class PostResult {

    global Boolean isSuccess {get; private set;}
    global String id {get; private set;}
    global String name {get; private set;}
    global List<PostResult.PostErrorResult> errors {get; private set;}
    public List<Transaction__c> transactions {get; set;}
    public Transaction_Group__c transactionGroup {get; set;}

    global enum StatusCode {
        SYSTEM_EXCEPTION,
        LINE_COUNT_LIMIT_EXCEEDED,
        NO_LINES,
        CLOSED_ACCOUNTING_PERIOD,
        ALREADY_POSTED,
        STATUS_NOT_APPROVED,
        STATUS_NOT_IN_PROGRESS,
        NO_CONTROL_AR_ACCOUNT_DEFINED,
        ALREADY_UNPOSTED,
        BILLING_CASH_RECEIPTS_EXIST,
        BILLING_CREDIT_MEMOS_EXIST,
        NO_CONTROL_AP_ACCOUNT_DEFINED,
        NO_UNAPPLIED_EXPENSE_GL_ACCOUNT_DEFINED,
        NO_UNAPPLIED_REVENUE_GL_ACCOUNT_DEFINED,
        AP_DISBURSEMENTS_EXIST,
        AP_CREDIT_MEMOS_EXIST,
        CREDITS_DEBITS_NOT_EQUAL,
        CLEARED_BANK_RECONCILIATION,
        CLEARED_BANK_DEPOSIT,
        NO_UNAPPLIED_CASH_CONTROL_ACCOUNT_DEFINED,
        PAYMENT_STATUS_VOID,
        NO_DISCOUNT_PAYMENT_ACCOUNT,
        NO_QUALIFYING_RECORDS,
        INVALID_RECORD_ID,
        NO_LABOR_CONTROL_ACCOUNT_DEFINED,
        NO_TASK_EXPENSE_GL_ACCOUNT_DEFINED,
        NO_CONTROL_AR_OR_UNAPPLIED_CASH_ACCOUNT_DEFINED,
        DEBIT_GL_ACCOUNT_IS_NULL_OR_SET_TO_AP_CONTROL_ACCOUNT,
        NO_DEBIT_GL_ACCOUNT,
        APPLIED_TO_PAYABLE_CREDIT_MEMO,
        APPLIED_TO_PAYABLE,
        NO_CASH_FLOW_CATEGORY,
        CASH_FLOW_NON_CONFORMITY,
        INCORRECT_APD_AMOUNT,
        TAX_RECORD_COUNT_LIMIT_EXCEEDED,
        TAX_NO_PRODUCT_LINES,
        TAX_NO_TAXABLE_PRODUCT,
        TAX_NO_TAXES_ON_ACCOUNT,
        ONLY_ACTUAL_TIME_CARD_ALLOW,
        INCORRECT_MOVEMENT_TYPE,
        NO_UNIT_COST_ON_MOVEMENT,
        NO_DEBIT_GL_ACCOUNT_ON_MOVEMENT,
        NO_CREDIT_GL_ACCOUNT_ON_MOVEMENT,
        NO_VOUCHERS_PAYABLE_GL_ACCOUNT,
        NO_WORK_IN_PROCESS_GL_ACCOUNT,
        BALANCE_OVERAPPLIED,
        AVATAX_CALLOUT_ERROR, // No longer used
        TAX_INCORRECT_CURRENCY, // No longer used
        AVATAX_SERVICE_ERROR,
        LEDGER_TYPE_NOT_ALLOWED,
        LEDGER_NO_TAX_SETTINGS,
        NO_BILLING_CONTACT_ON_VENDOR_FOR_AS_PAY, //No longer used
        RELATED_BANK_ACCOUNT_NOT_APPROVED_FOR_AS_PAY,
        LEDGER_NOT_ENROLLED,
        CD_CURRENCY_NOT_USD,
        NO_BILLING_CONTACT_EMAIL_ON_VENDOR_FOR_VCARD_PAYMENT_SERVICE, //No longer used
        AP_REMITTANCE_EMAIL_BLANK_ON_VENDOR,
        NO_DEFAULT_PAYMENT_METHOD_ON_VENDOR_FOR_ACH_PAYMENT_SERVICE,
        NO_BILLING_ADDRESS_ON_VENDOR_FOR_CHECK_PAYMENT_SERVICE,
        CANT_PAY_CONTACT_OR_EMPLOYEE_FOR_TYPE_PAYMENT_SERVICE,
        INACTIVE_DEFAULT_PAYMENT_METHOD,
        POSTING_IN_PROGRESS,
        UNPOSTING_IN_PROGRESS,
        CASH_DISBUREMENT_BALANCE_MUST_BE_ZERO,
        INACTIVE_VERIFICATION_STATUS_PAYMENT_METHOD,
        ERR_CASHRECEIPT_STATUS_VOID_ERROR_DECLINED,
        ERR_CR_POSTED_VOID
    }

    //Constructor
    global PostResult(Boolean isSuccess, String id, List<PostResult.PostErrorResult> errors) {
        this.isSuccess = isSuccess;
        this.id = id;
        this.errors = errors;
    }

    global PostResult(Boolean isSuccess, String id, String name, List<PostResult.PostErrorResult> errors) {
        this.isSuccess = isSuccess;
        this.id = id;
        this.name = name;
        this.errors = errors;
    }

    public PostResult(Boolean isSuccess, String id, String name, Transaction_Group__c transactionGroup) {
        this.isSuccess = isSuccess;
        this.id = id;
        this.name = name;
        this.errors = errors;
        this.transactionGroup = transactionGroup;
        this.transactions = new List<Transaction__c>();
    }

    //Inner class
    global class PostErrorResult {
        global StatusCode statusCode {get; private set;}
        global String message {get; private set;}
        global SObject errorSource {get; private set;}
                
        global PostErrorResult(StatusCode statusCode, String message) {
            this.statusCode = statusCode;
            this.message = message;
        }

        global PostErrorResult(SObject errorSource, StatusCode statusCode, String message) {
            this.statusCode = statusCode;
            this.message = message;
            this.errorSource = errorSource;
        }
    }

    public PostResult isSuccess(Boolean isSuccess) {
        this.isSuccess = isSuccess;
        return this;
    }

    public PostResult errors(List<PostResult.PostErrorResult> errors) {
        this.errors = errors;
        return this;
    }

    public PostResult transactionGroup(Transaction_Group__c transactionGroup) {
        this.transactionGroup = transactionGroup;
        return this;
    }

}