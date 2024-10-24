public with sharing abstract class AbstractPostHandler {

    protected List<Id> processedRecordIds = new List<Id>();
    public List<SObject> sourceRecords = new List<SObject>();
    protected List<SObject> sourceRecordLines = new List<SObject>();

    protected Map<Id, String> sourceIdToCurrencyCode { get; set; }
    protected Map<Id, Decimal> sourceIdToCurrencyConversionRate { get; set; }

    public virtual List<PostResult> post(List<LDVPostInput> inputs) {
        return new List<PostResult>();
    }
    public abstract List<PostResult> post(List<SObject> processedRecords);
    public abstract List<PostResult> post(List<String> processedRecordsIds);
    public virtual List<PostResult> unpost(List<LDVPostInput> inputs) {
        return new List<PostResult>();
    }
    public abstract List<PostResult> unpost(List<SObject> processedRecords);
    public abstract List<PostResult> unpost(List<String> processedRecordsIds);

    public class PostHandlerException extends Exception {}
    public PostResultDispatcher dispatcher = new PostResultDispatcher();

    protected final Boolean IS_MULTI_CURRENCY_ENABLED = MultiCurrencyHandler.isMultiCurrencyEnabled;
    protected final Boolean IS_ERP_ENABLED = AccountingSettingsHandler.isERPEnabled();
    protected final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    protected final Boolean IS_HEADER_LEVEL_POST = AccountingSettingsHandler.isHeaderLevelPost();
    protected Boolean isLDVBatchContext = false;

    public void isLDVBatchContext(Boolean isLDVBatchContext) {
        this.isLDVBatchContext = isLDVBatchContext;
    }

    public static final String DEFAULT_POSTING_STATUS_NOT_POSTED = 'Approved';
    public static final String DEFAULT_POSTING_STATUS_POSTED = 'Posted';
    public static final String DEFAULT_LDV_POSTING_STATUS_NOT_POSTED = 'In Process';
    public static final String DEFAULT_POSTING_STATUS_POSTING_IN_PROGRESS = 'Posting in Progress';
    public static final String DEFAULT_POSTING_STATUS_UNPOSTING_IN_PROGRESS = 'Unposting in Progress';
    public static final String DEFAULT_POSTING_STATUS_BCR_REFUND = 'Refund';

    protected Accounting_Settings__c main;
    protected Map<Id, Map<String, GL_Account_Default__c>> glAccountDefaults = new Map<Id, Map<String, GL_Account_Default__c>>();

    private static final Integer AVALARA_SELECTED_RECORDS_LIMIT = 100;
    public static final Integer LDV_AVALARA_SELECTED_RECORDS_LIMIT = 8000;

    //=========================================================================================
    //========== Group of Batch Post Matrix hover help text
    //=========================================================================================
    public static final String ONLY_ACTUAL_TIME_CARD_ALLOW_HELP_TEXT = Label.INF_ONLY_ACTUAL_TIME_CARD_ALLOWED;
    public static final String MAX_TIME_CARD_DAYS_EXCEEDED_HELP_TEXT = Label.INF_MAX_TIME_CARD_DAYS_EXCEEDED_HELP_TEXT;
    public static final String LINE_COUNT_LIMIT_EXCEEDED_HELP_TEXT = Label.INF_LINE_COUNT_LIMIT_EXCEEDED_HELP_TEXT;
    public static final String AVATAX_SERVICE_ERROR_HELP_TEXT = Label.INF_AVATAX_SERVICE_ERROR_HELP_TEXT;
    public static final String TAX_RECORD_COUNT_LIMIT_EXCEEDED_HELP_TEXT = String.format(System.Label.INF_TAX_RECORD_COUNT_LIMIT_EXCEEDED_HELP_TEXT, new List<Object>{ AVALARA_SELECTED_RECORDS_LIMIT});
    public static final String LDV_TAX_RECORD_COUNT_LIMIT_EXCEEDED_HELP_TEXT = String.format(System.Label.INF_TAX_RECORD_COUNT_LIMIT_EXCEEDED_HELP_TEXT, new List<Object>{ LDV_AVALARA_SELECTED_RECORDS_LIMIT});
    public static final String BALANCE_OVERAPPLIED_HELP_TEXT = Label.INF_BALANCE_OVERAPPLIED_HELP_TEXT;
    public static final String NO_LINES_HELP_TEXT = Label.INF_NO_LINES_HELP_TEXT;
    public static final String CLOSED_ACCOUNTING_PERIOD_HELP_TEXT = Label.INF_CLOSED_ACCOUNTING_PERIOD_HELP_TEXT;
    public static final String ALREADY_POSTED_HELP_TEXT = Label.INF_ALREADY_POSTED_HELP_TEXT;
    public static final String STATUS_NOT_APPROVED_HELP_TEXT = Label.INF_STATUS_NOT_APPROVED_HELP_TEXT;
    public static final String NO_CONTROL_AR_ACCOUNT_DEFINED_HELP_TEXT = Label.INF_NO_CONTROL_AR_ACCOUNT_DEFINED_HELP_TEXT;
    public static final String ALREADY_UNPOSTED_HELP_TEXT = Label.INF_ALREADY_UNPOSTED_HELP_TEXT;
    public static final String BILLING_CASH_RECEIPTS_EXIST_HELP_TEXT = Label.INF_BILLING_CASH_RECEIPTS_EXIST_HELP_TEXT;
    public static final String BILLING_CREDIT_MEMOS_EXIST_HELP_TEXT = Label.INF_BILLING_CREDIT_MEMOS_EXIST_HELP_TEXT;
    public static final String NO_CONTROL_AP_ACCOUNT_DEFINED_HELP_TEXT = Label.INF_NO_CONTROL_AP_ACCOUNT_DEFINED_HELP_TEXT;
    public static final String AP_DISBURSEMENTS_EXIST_HELP_TEXT = Label.INF_AP_DISBURSEMENTS_EXIST_HELP_TEXT;
    public static final String AP_CREDIT_MEMOS_EXIST_HELP_TEXT = Label.INF_AP_CREDIT_MEMOS_EXIST_HELP_TEXT;
    public static final String CREDITS_DEBITS_NOT_EQUAL_HELP_TEXT = Label.INF_CREDITS_DEBITS_NOT_EQUAL_HELP_TEXT;
    public static final String CLEARED_BANK_RECONCILIATION_HELP_TEXT = Label.INF_CLEARED_BANK_RECONCILIATION_HELP_TEXT;
    public static final String CLEARED_BANK_DEPOSIT_HELP_TEXT = Label.INF_CLEARED_BANK_DEPOSIT_HELP_TEXT;
    public static final String NO_UNAPPLIED_CASH_CONTROL_ACCOUNT_DEFINED_HELP_TEXT = Label.INF_NO_UNAPPLIED_CASH_CONTROL_ACCOUNT_DEFINED_HELP_TEXT;
    public static final String PAYMENT_STATUS_VOID_HELP_TEXT = Label.INF_PAYMENT_STATUS_VOID_HELP_TEXT;
    public static final String NO_DISCOUNT_PAYMENT_ACCOUNT_HELP_TEXT = Label.INF_NO_DISCOUNT_PAYMENT_ACCOUNT_HELP_TEXT;
    public static final String NO_LABOR_CONTROL_ACCOUNT_DEFINED_HELP_TEXT = Label.INF_NO_LABOR_CONTROL_ACCOUNT_DEFINED_HELP_TEXT;
    public static final String NO_TASK_EXPENSE_GL_ACCOUNT_DEFINED_HELP_TEXT = Label.INF_NO_TASK_EXPENSE_GL_ACCOUNT_DEFINED_HELP_TEXT;
    public static final String NO_CONTROL_AR_OR_UNAPPLIED_CASH_ACCOUNT_DEFINED_HELP_TEXT = Label.INF_NO_CONTROL_AR_OR_UNAPPLIED_CASH_ACCOUNT_DEFINED_HELP_TEXT;
    public static final String DEBIT_GL_ACCOUNT_IS_NULL_OR_SET_TO_AP_CONTROL_ACCOUNT_HELP_TEXT = Label.INF_DEBIT_GL_ACCOUNT_IS_NULL_OR_SET_TO_AP_CONTROL_ACCOUNT_HELP_TEXT;
    public static final String NO_DEBIT_GL_ACCOUNT_HELP_TEXT = Label.INF_NO_DEBIT_GL_ACCOUNT_HELP_TEXT;
    public static final String APPLIED_TO_PAYABLE_CREDIT_MEMO_HELP_TEXT = Label.INF_APPLIED_TO_PAYABLE_CREDIT_MEMO_HELP_TEXT;
    public static final String APPLIED_TO_PAYABLE_HELP_TEXT = Label.INF_APPLIED_TO_PAYABLE_HELP_TEXT;
    public static final String NO_CASH_FLOW_CATEGORY_HELP_TEXT = Label.INF_NO_CASH_FLOW_CATEGORY_HELP_TEXT;
    public static final String CASH_FLOW_NON_CONFORMITY_HELP_TEXT = Label.INF_CASH_FLOW_NON_CONFORMITY_HELP_TEXT;
    public static final String PAID_AMOUNT_NOT_EQUAL_CD_AMOUNT_HELP_TEXT = Label.INF_PAID_AMOUNT_NOT_EQUAL_CD_AMOUNT_HELP_TEXT;
    public static final String STATUS_NOT_POSTED_HELP_TEXT = Label.INF_STATUS_NOT_POSTED_HELP_TEXT;
    public static final String LEDGER_TYPE_NOT_ALLOWED_HELP_TEXT = Label.INF_LEDGER_TYPE_NOT_ALLOWED_HELP_TEXT;
    public static final String NO_LEDGER_TAX_SETTINGS_HELP_TEXT = Label.NO_LEDGER_TAX_SETTINGS_HELP_TEXT;
    public static final String INF_LEDGER_NOT_ENROLLED_HELP_TEXT = Label.INF_LEDGER_NOT_ENROLLED_HELP_TEXT;
    public static final String INF_CD_CANNOT_POST_CURRENCY_NOT_EQUALS_USD_HELP_TEXT = Label.INF_CD_CANNOT_POST_CURRENCY_NOT_EQUALS_USD_HELP_TEXT;
    public static final String INF_AP_REMITTANCE_EMAIL_BLANK_ON_VENDOR_HELP_TEXT= Label.INF_AP_REMITTANCE_EMAIL_BLANK_ON_VENDOR_HELP_TEXT;
    public static final String INF_PAYMENT_METHOD_REQUIRED_ON_VENDOR_HELP_TEXT = Label.INF_PAYMENT_METHOD_REQUIRED_ON_VENDOR_HELP_TEXT;
    public static final String INF_BILLING_ADDRESS_REQUIRED_ON_VENDOR_HELP_TEXT = Label.INF_BILLING_ADDRESS_REQUIRED_ON_VENDOR_HELP_TEXT;
    public static final String INF_CD_CANNOT_BE_POSTED_FOR_CONTACT_OR_EMPLOYEE_HELP_TEXT = Label.ERR_CD_CANNOT_BE_POSTED_FOR_CONTACT_OR_EMPLOYEE;
    public static final String INF_POSTING_IN_PROGRESS_HELP_TEXT = Label.INF_POSTING_IN_PROGRESS_HELP_TEXT;
    public static final String INF_UNPOSTING_IN_PROGRESS_HELP_TEXT = Label.INF_UNPOSTING_IN_PROGRESS_HELP_TEXT;
    public static final String NO_UNAPPLIED_EXPENSE_GL_ACCOUNT_DEFINED_HELP_TEXT = Label.ERR_CD_NO_UNAPPLIED_EXPENSE_GL_ACCOUNT;
    public static final String NO_UNAPPLIED_REVENUE_GL_ACCOUNT_DEFINED_HELP_TEXT = Label.ERR_CR_NO_UNAPPLIED_REVENUE_GL_ACCOUNT;
    public static final String ERR_CASHRECEIPT_STATUS_VOID_ERROR_DECLINED = Label.ERR_CASHRECEIPT_STATUS_VOID;
    public static final String INF_CASHRECEIPT_VOID_OR_POST_HELP_TEXT = Label.INF_CASHRECEIPT_VOID_OR_POST_HELP_TEXT;
    public static final String ERR_CR_POSTED_VOID = Label.ERR_CR_POSTED_VOID;
    public static final String INFO_VOIDED = Label.INF_VOIDED;

    public static final String NO_BILLING_CONTACT_FOR_PAYMENT_SERVICE_CD_HELP_TEXT = Label.NO_BILLING_CONTACT_FOR_PAYMENT_SERVICE_CD_HELP_TEXT;
    public static final String INF_PAYMENT_METHOD_INACTIVE_HELP_TEXT= Label.CD_CANNOT_BE_POSTED_DEFAULT_PAYMENT_SERVICE_INACTIVE;
    public static final String ERR_CD_BALANCE_MUST_BE_ZERO_HELP_TEXT = Label.CD_BALANCE_MUST_BE_ZERO_BEFORE_POSTING;
    public static final String INACTIVE_VERIFICATION_STATUS_PAYMENT_METHOD_HELP_TEXT = Label.INACTIVE_VERIFICATION_STATUS_PAYMENT_METHOD_HELP_TEXT;


    //=========================================================================================
    //========== Group of Batch Post Matrix column headers
    //=========================================================================================

    public static final String ONLY_ACTUAL_TIME_CARD_ALLOW_HEADER = Label.INF_ONLY_ACTUAL_TIME_CARD_ALLOWED;
    public static final String MAX_TIME_CARD_DAYS_EXCEEDED_HEADER = Label.INF_MAX_TIME_CARD_DAYS_EXCEEDED_HEADER;
    public static final String LINE_COUNT_LIMIT_EXCEEDED_HEADER = Label.INF_LINE_COUNT_LIMIT_EXCEEDED_HEADER;
    public static final String AVATAX_SERVICE_ERROR_HEADER = Label.ERR_AVATAX_SERVICE_ERROR_HEADER;
    public static final String NO_LINES_HEADER = Label.INF_NO_LINES_HEADER;
    public static final String CLOSED_ACCOUNTING_PERIOD_HEADER = Label.INF_CLOSED_ACCOUNTING_PERIOD_HEADER;
    public static final String ALREADY_POSTED_HEADER = Label.INF_ALREADY_POSTED_HEADER;
    public static final String STATUS_NOT_APPROVED_HEADER = Label.INF_STATUS_NOT_APPROVED_HEADER;
    public static final String NO_CONTROL_AR_ACCOUNT_DEFINED_HEADER = Label.INF_NO_CONTROL_AR_ACCOUNT_DEFINED_HEADER;
    public static final String ALREADY_UNPOSTED_HEADER = Label.INF_ALREADY_UNPOSTED_HEADER;
    public static final String BILLING_CASH_RECEIPTS_EXIST_HEADER = Label.INF_BILLING_CASH_RECEIPTS_EXIST_HEADER;
    public static final String BILLING_CREDIT_MEMOS_EXIST_HEADER = Label.INF_BILLING_CREDIT_MEMOS_EXIST_HEADER;
    public static final String NO_CONTROL_AP_ACCOUNT_DEFINED_HEADER = Label.INF_NO_CONTROL_AP_ACCOUNT_DEFINED_HEADER;
    public static final String AP_DISBURSEMENTS_EXIST_HEADER = Label.INF_AP_DISBURSEMENTS_EXIST_HEADER;
    public static final String AP_CREDIT_MEMOS_EXIST_HEADER = Label.INF_AP_CREDIT_MEMOS_EXIST_HEADER;
    public static final String CREDITS_DEBITS_NOT_EQUAL_HEADER = Label.INF_CREDITS_DEBITS_NOT_EQUAL_HEADER;
    public static final String CLEARED_BANK_RECONCILIATION_HEADER = Label.INF_CLEARED_BANK_RECONCILIATION_HEADER;
    public static final String CLEARED_BANK_DEPOSIT_HEADER = Label.INF_CLEARED_BANK_DEPOSIT_HEADER;
    public static final String NO_UNAPPLIED_CASH_CONTROL_ACCOUNT_DEFINED_HEADER = Label.INF_NO_UNAPPLIED_CASH_CONTROL_ACCOUNT_DEFINED_HEADER;
    public static final String PAYMENT_STATUS_VOID_HEADER = Label.INF_PAYMENT_STATUS_VOID_HEADER;
    public static final String NO_DISCOUNT_PAYMENT_ACCOUNT_HEADER = Label.INF_NO_DISCOUNT_PAYMENT_ACCOUNT_HEADER;
    public static final String NO_LABOR_CONTROL_ACCOUNT_DEFINED_HEADER = Label.INF_NO_LABOR_CONTROL_ACCOUNT_DEFINED_HEADER;
    public static final String NO_TASK_EXPENSE_GL_ACCOUNT_DEFINED_HEADER = Label.INF_NO_TASK_EXPENSE_GL_ACCOUNT_DEFINED_HEADER;
    public static final String NO_CONTROL_AR_OR_UNAPPLIED_CASH_ACCOUNT_DEFINED_HEADER = Label.INF_NO_CONTROL_AR_OR_UNAPPLIED_CASH_ACCOUNT_DEFINED_HEADER;
    public static final String DEBIT_GL_ACCOUNT_IS_NULL_OR_SET_TO_AP_CONTROL_ACCOUNT_HEADER = Label.INF_DEBIT_GL_ACCOUNT_IS_NULL_OR_SET_TO_AP_CONTROL_ACCOUNT_HEADER;
    public static final String NO_DEBIT_GL_ACCOUNT_HEADER = Label.INF_NO_DEBIT_GL_ACCOUNT_HEADER;
    public static final String APPLIED_TO_PAYABLE_CREDIT_MEMO_HEADER = Label.INF_APPLIED_TO_PAYABLE_CREDIT_MEMO_HEADER;
    public static final String APPLIED_TO_PAYABLE_HEADER = Label.INF_APPLIED_TO_PAYABLE_HEADER;
    public static final String NO_CASH_FLOW_CATEGORY_HEADER = Label.INF_NO_CASH_FLOW_CATEGORY_HEADER;
    public static final String CASH_FLOW_NON_CONFORMITY_HEADER = Label.INF_CASH_FLOW_NON_CONFORMITY_HEADER;
    public static final String PAID_AMOUNT_NOT_EQUAL_CD_AMOUNT_HEADER = Label.INF_PAID_AMOUNT_NOT_EQUAL_CD_AMOUNT_HEADER;
    public static final String LEDGER_TYPE_NOT_ALLOWED_HEADER = Label.ERR_LEDGER_TYPE_NOT_ALLOWED_HEADER;
    public static final String NO_LEDGER_TAX_SETTINGS_HEADER = Label.NO_LEDGER_TAX_SETTINGS_HEADER;
    public static final String LEDGER_NOT_ENROLLED_HEADER = Label.ERR_LEDGER_NOT_ENROLLED_HEADER;
    public static final String INF_PAYMENT_SERVICES_ERRORS_HEADER = Label.INF_PAYMENT_SERVICES_ERRORS_HEADER;
    public static final String INF_AP_REMITTANCE_ERROR_HEADER = Label.INF_AP_REMITTANCE_ERROR_HEADER;
    public static final String INF_ACH_ERRORS_HEADER = Label.INF_ACH_ERRORS_HEADER;
    public static final String INF_CHECK_ERRORS_HEADER = Label.INF_CHECK_ERRORS_HEADER;
    public static final String NO_BILLING_CONTACT_FOR_PAYMENT_SERVICE_CD_HEADER = Label.NO_BILLING_CONTACT_FOR_PAYMENT_SERVICE_CD_HEADER;
    public static final String INF_CONTACT_EMPLOYEE_HEADER = Label.INF_CONTACT_OR_EMPLOYEE_HEADER;
    public static final String INF_PAYMENT_METHOD_INACTIVE_HEADER = Label.INF_PAYMENT_METHOD_INACTIVE_HEADER;
    public static final String POSTING_IN_PROGRESS_HEADER = Label.POSTING_IN_PROGRESS;
    public static final String UNPOSTING_IN_PROGRESS_HEADER = Label.UNPOSTING_IN_PROGRESS;
    public static final String INF_CD_BALANCE_MUST_BE_ZERO_HEADER = Label.INF_CD_BALANCE_MUST_BE_ZERO_HEADER;
    public static final String NO_UNAPPLIED_EXPENSE_GL_ACCOUNT_DEFINED_HEADER = Label.INF_CD_NO_UNAPPLIED_EXPENSE_GL_ACCOUNT_HEADER;
    public static final String NO_UNAPPLIED_REVENUE_GL_ACCOUNT_DEFINED_HEADER = Label.INF_CR_NO_UNAPPLIED_REVENUE_GL_ACCOUNT_HEADER;
    public static final String INACTIVE_VERIFICATION_STATUS_PAYMENT_METHOD_HEADER = Label.INACTIVE_VERIFICATION_STATUS_PAYMENT_METHOD_HEADER;

    //=========================================================================================
    //========== Group of common error/info messages
    //========== Suitable for all kinds of records which can be posted/unposted
    //=========================================================================================
    public static final String ACCOUNTING_PERIOD_CLOSED_ERROR_MESSAGE = Label.INF_CLOSED_ACCOUNTING_PERIOD_HELP_TEXT;
    public static final String POSTED_ERROR_MESSAGE = Label.ERR_RECORD_ALREADY_POSTED;
    public static final String UNPOSTED_ERROR_MESSAGE = Label.ERR_RECORD_NOT_POSTED;
    public static final String NOT_APPROVED_ERROR_MESSAGE = Label.INF_STATUS_NOT_APPROVED_HELP_TEXT;
    public static final String NO_SELECTION_POSTED_ERROR_MESSAGE = Label.ERR_NO_SELECTION_POSTED;
    public static final String INSUFFICIENT_ACCESS_OR_READONLY_ERROR_MESSAGE = Label.ERR_INSUFFICIENT_ACCESS_OR_READONLY;
    public static final String LEDGER_TYPE_CONSOLIDATION_NOT_ALLOWED_ERROR_MESSAGE = Label.ERR_LEDGER_TYPE_CONSOLIDATION_NOT_ALLOWED;
    public static final String LEDGER_TYPE_ELIMINATION_NOT_ALLOWED_ERROR_MESSAGE = Label.ERR_LEDGER_TYPE_ELIMINATION_NOT_ALLOWED;

    //=========================================================================================
    //========== Group of common validation methods
    //========== Suitable for all kinds of records which can be posted/unposted
    //=========================================================================================

    public static void validateInputData(List<String> idsToCheck) {
        for (String idToCheck : idsToCheck) {
            Id tempId;
            try {
                tempId = Id.valueOf(idToCheck);
            }
            catch (Exception ex) {
                throw new PostHandlerException(Label.COMMON_RECORD_ID_INVALID + ' ' + idToCheck);
            }
        }
    }

    public static Map<String, LDVPostInput> ldvPostInputsByIds(List<LDVPostInput> sourceItems) {
        Map<String, LDVPostInput> ldvPostInputsByIds = new Map<String, LDVPostInput>();
        for (LDVPostInput sourceItem : sourceItems) {
            ldvPostInputsByIds.put(sourceItem.id, sourceItem);
        }
        return ldvPostInputsByIds;
    }

    protected List<SObject> filterSourceRecords4Update(List<LDVPostInput> sourceItems) {
        List<SObject> sourceRecords4Update = new List<SObject>();
        if (sourceItems != null) {
            Map<String, LDVPostInput> ldvPostInputsByIds = ldvPostInputsByIds(sourceItems);
            for (SObject sourceRecord : sourceRecords) {
                Transaction_Group__c transactionGroup = ldvPostInputsByIds.get(sourceRecord.Id)?.transactionGroup;
                System.debug(JSON.serialize(transactionGroup));
                Integer linesProcessed = transactionGroup.Lines_Processed__c != null
                        ? Integer.valueOf(transactionGroup.Lines_Processed__c)
                        : 0;
                if (linesProcessed >= Integer.valueOf(transactionGroup.Line_Count__c)) {
                    sourceRecords4Update.add(sourceRecord);
                }
            }
        } else {
            sourceRecords4Update = sourceRecords;
        }
        return sourceRecords4Update;
    }

    protected List<SObject> filterValidRecords(List<SObject> sourceRecords) {
        List<SObject> validRecords = new List<SObject>();
        for (SObject sourceRecord : sourceRecords) {
            if (!dispatcher.getPostResultsMap().containsKey(sourceRecord.Id)) {
                validRecords.add(sourceRecord);
            }
        }
        return validRecords;
    }

    protected List<SObject> filterRecordsByAcctMethods(List<SObject> sourceRecords, Set<String> acctMethods) {
        List<SObject> validRecords = new List<SObject>();
        for (SObject sourceRecord : sourceRecords) {
            String accountingMethod = (String) sourceRecord.getSObject('Ledger__r')?.get('Accounting_Method__c');
            if (sourceRecord.getSObject('Ledger__r') != null
                    && (
                    String.isNotBlank(accountingMethod)
                        && acctMethods.contains(accountingMethod)
                        || acctMethods.contains(LedgerActions.ACCOUNTING_METHOD_ACCRUAL)
                )
            ) {
                validRecords.add(sourceRecord);
            } else if (!dispatcher.getPostResultsMap().containsKey(sourceRecord.Id)) {
                dispatcher.addPostResult(sourceRecord.Id, new PostResult(true, sourceRecord.Id, NULL));
            }
        }
        return validRecords;
    }

    protected List<PostResult> ldvInputsToPostResults(List<LDVPostInput> sourceItems, Map<Id, PostResult> postResultsByIds) {
        List<PostResult> postResults = new List<PostResult>();
        for (LDVPostInput sourceItem : sourceItems) {
            if (postResultsByIds.containsKey(sourceItem.id)) {
                postResults.add(postResultsByIds.get(sourceItem.id));
            } else {
                PostResult postResult = dispatcher.getPostResultsMap().get(sourceItem.id);
                postResult.transactionGroup = sourceItem.transactionGroup;
                postResult.isSuccess(dispatcher.getPostResultsMap().get(sourceItem.Id).isSuccess);
                postResult.errors(dispatcher.getPostResultsMap().get(sourceItem.Id).errors);
                postResults.add(postResult);
            }
        }

        return postResults;
    }

    protected void ldvValidatePostResultMap(Map<Id, PostResult> postResultsByIds) {
        for (SObject sourceRecord : sourceRecords) {
            if (dispatcher.getPostResultsMap().containsKey(sourceRecord.Id)) {
                postResultsByIds.get(sourceRecord.Id).isSuccess(dispatcher.getPostResultsMap().get(sourceRecord.Id).isSuccess);
                postResultsByIds.get(sourceRecord.Id).errors(dispatcher.getPostResultsMap().get(sourceRecord.Id).errors);
            }
        }
    }

    protected void ldvValidateExceptionPostResultMap(Map<Id, PostResult> postResultsByIds) {
        for (Id sourceRecordId : dispatcher.getPostResultsMap().keySet()) {
            if (!postResultsByIds.containsKey(sourceRecordId)) {
                postResultsByIds.put(sourceRecordId, dispatcher.getPostResultsMap().get(sourceRecordId));
            }
        }
    }

    protected void ldvGetPostResultMap(Map<Id, PostResult> postResultsByIds, Map<Id, LDVPostInput> sourceMap) {
        for (SObject sourceRecord : sourceRecords) {
            if (dispatcher.getPostResultsMap().containsKey(sourceRecord.Id)) {
                postResultsByIds.put(sourceRecord.Id, dispatcher.getPostResultsMap().get(sourceRecord.Id));
                postResultsByIds.get(sourceRecord.Id).transactionGroup(sourceMap.get(sourceRecord.Id).transactionGroup);
            }
        }
    }

    public static final Map<SObjectType, List<SObjectField>> LEDGER_FIELDS_BY_SOBJECT_TYPES = new Map<SObjectType, List<SObjectField>>{
            AP_Disbursement__c.getSObjectType() => new List<SObjectField>{ AP_Disbursement__c.Account_Payable__c, Account_Payable__c.Ledger__c },
            Billing_Cash_Receipt__c.getSObjectType() => new List<SObjectField>{ Billing_Cash_Receipt__c.Ledger__c }
    };

    protected void validateInactiveLedger() {
        List<SObject> validRecords = new List<SObject>();
        SObjectType sObjType = !sourceRecords.isEmpty() ? sourceRecords[0].getSObjectType() : null;
        for (SObject masterRecord : sourceRecords) {

            Id ledgerId = (Id) FinancialSuiteUtils.fetchValue(masterRecord, LEDGER_FIELDS_BY_SOBJECT_TYPES.get(sObjType));
            if (!LedgerHandler.getInstanceWithoutSharing().isActiveLedger(ledgerId)) {
                dispatcher.addPostErrorResult(
                    masterRecord,
                    new PostResult.PostErrorResult(
                        masterRecord,
                        PostResult.StatusCode.POSTING_IN_PROGRESS,
                        Label.ERR_LEDGER_ACTIVE_ONLY
                    )
                );
            } else {
                validRecords.add(masterRecord);
            }
        }

        sourceRecords = validRecords;
    }

    protected void validateLedgerTaxSetting(Boolean fullStatistics) {
        List<SObject> validRecords = new List<SObject>();
        for (SObject masterRecord : sourceRecords) {
            if (masterRecord.getSObject('Ledger__r').get('Tax_Settings__c') == null) {
                dispatcher.addPostErrorResult(
                    masterRecord,
                    new PostResult.PostErrorResult(
                        masterRecord.getSObject('Ledger__r'),
                        PostResult.StatusCode.LEDGER_NO_TAX_SETTINGS,
                        TaxService.getNoTaxSettingErrorMessage(false)
                    )
                );
            } else {
                validRecords.add(masterRecord);
            }
        }

        if (!fullStatistics) {
            sourceRecords = validRecords;
        }
    }

    protected void validateAccountingPeriodIsOpen(Boolean fullStatistics) {
        List<SObject> validRecords = new List<SObject>();
        for (SObject masterRecord : sourceRecords) {
            if (AccountingPeriodHandler.getInstance().isConsideredClosed(masterRecord.getSObject('Accounting_Period__r').Id, masterRecord.getSObjectType())) {
                dispatcher.addPostErrorResult(
                    masterRecord,
                    new PostResult.PostErrorResult(
                        masterRecord.getSObject('Accounting_Period__r'),
                        PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD,
                        ACCOUNTING_PERIOD_CLOSED_ERROR_MESSAGE
                    )
                );
            } else {
                validRecords.add(masterRecord);
            }
        }

        if (!fullStatistics) {
            sourceRecords = validRecords;
        }
    }

    protected void filteredRecordsByStatus(String status) {
        List<SObject> validRecords = new List<SObject>();
        for (SObject masterRecord : sourceRecords) {
            if (!(masterRecord.get('Status__c') == status)) {
                validRecords.add(masterRecord);
            }
        }

        sourceRecords = validRecords;
    }

    protected void validateNotPosted(Boolean fullStatistics) {
        List<SObject> validRecords = new List<SObject>();
        for (SObject masterRecord : sourceRecords) {
            if (masterRecord.get('Status__c') == DEFAULT_POSTING_STATUS_POSTED) {
                dispatcher.addPostErrorResult(
                    masterRecord,
                    new PostResult.PostErrorResult(
                        masterRecord,
                        PostResult.StatusCode.ALREADY_POSTED,
                        POSTED_ERROR_MESSAGE
                    )
                );
            } else {
                validRecords.add(masterRecord);
            }
        }

        if (!fullStatistics) {
            sourceRecords = validRecords;
        }
    }

    protected void validateIsPostedByApproval(Boolean fullStatistics) {
        List<SObject> validRecords = new List<SObject>();
        for (SObject masterRecord : sourceRecords) {
            if (masterRecord.get('Status__c') == DEFAULT_POSTING_STATUS_NOT_POSTED) {
                dispatcher.addPostErrorResult(
                        masterRecord,
                        new PostResult.PostErrorResult(
                                masterRecord,
                                PostResult.StatusCode.ALREADY_UNPOSTED,
                                UNPOSTED_ERROR_MESSAGE
                        )
                );
            } else {
                validRecords.add(masterRecord);
            }
        }

        if (!fullStatistics) {
            sourceRecords = validRecords;
        }
    }

    protected void validateIsPosted(Boolean fullStatistics) {
        List<SObject> validRecords = new List<SObject>();
        for (SObject masterRecord : sourceRecords) {
            
            if (masterRecord.get('Status__c') == DEFAULT_POSTING_STATUS_POSTING_IN_PROGRESS) {
                dispatcher.addPostErrorResult(
                    masterRecord,
                    new PostResult.PostErrorResult(
                        masterRecord,
                        PostResult.StatusCode.POSTING_IN_PROGRESS,
                        UNPOSTED_ERROR_MESSAGE
                    )
                );
            } else if (masterRecord.get('Status__c') == DEFAULT_POSTING_STATUS_UNPOSTING_IN_PROGRESS) {
                dispatcher.addPostErrorResult(
                    masterRecord,
                    new PostResult.PostErrorResult(
                        masterRecord,
                        PostResult.StatusCode.UNPOSTING_IN_PROGRESS,
                        UNPOSTED_ERROR_MESSAGE
                    )
                );
            } else if (masterRecord.get('Status__c') != DEFAULT_POSTING_STATUS_POSTED) {
                dispatcher.addPostErrorResult(
                    masterRecord,
                    new PostResult.PostErrorResult(
                        masterRecord,
                        PostResult.StatusCode.ALREADY_UNPOSTED,
                        UNPOSTED_ERROR_MESSAGE
                    )
                );
            } else {
                validRecords.add(masterRecord);
            }
        }

        if (!fullStatistics) {
            sourceRecords = validRecords;
        }
    }

    protected void validateStatusApproved(Boolean fullStatistics) {
        List<SObject> validRecords = new List<SObject>();
        for (SObject masterRecord : sourceRecords) {
            if (masterRecord.get('Status__c') == DEFAULT_POSTING_STATUS_POSTING_IN_PROGRESS) {
                dispatcher.addPostErrorResult(
                    masterRecord,
                    new PostResult.PostErrorResult(
                        masterRecord,
                        PostResult.StatusCode.POSTING_IN_PROGRESS,
                        NOT_APPROVED_ERROR_MESSAGE
                    )
                );
            } else if (masterRecord.get('Status__c') == DEFAULT_POSTING_STATUS_UNPOSTING_IN_PROGRESS) {
                dispatcher.addPostErrorResult(
                    masterRecord,
                    new PostResult.PostErrorResult(
                        masterRecord,
                        PostResult.StatusCode.UNPOSTING_IN_PROGRESS,
                        NOT_APPROVED_ERROR_MESSAGE
                    )
                );
            } else if (masterRecord.get('Status__c') != DEFAULT_POSTING_STATUS_NOT_POSTED) {
                dispatcher.addPostErrorResult(
                    masterRecord,
                    new PostResult.PostErrorResult(
                        masterRecord,
                        PostResult.StatusCode.STATUS_NOT_APPROVED,
                        NOT_APPROVED_ERROR_MESSAGE
                    )
                );
            } else {
                validRecords.add(masterRecord);
            }
        }

        if (!fullStatistics) {
            sourceRecords = validRecords;
        }
    }

    protected void validateLedgerType(Boolean fullStatistics, Boolean allowElimination) {

        if (!sourceRecords.isEmpty()) {
            List<SObject> validRecords = new List<SObject>();
            String sourceDocumentLabel = sourceRecords.get(0).getSObjectType().getDescribe().getLabel();
            for (SObject masterRecord : sourceRecords) {
                Ledger__c currentLedger = (Ledger__c) masterRecord.getSObject('Ledger__r');
                if (LedgerHandler.isConsolidationLedger(currentLedger)) {
                    dispatcher.addPostErrorResult(
                        masterRecord,
                        new PostResult.PostErrorResult(
                            masterRecord.getSObject('Ledger__r'),
                            PostResult.StatusCode.LEDGER_TYPE_NOT_ALLOWED,
                            LEDGER_TYPE_CONSOLIDATION_NOT_ALLOWED_ERROR_MESSAGE
                        )
                    );
                } else if (LedgerHandler.isEliminationLedger(currentLedger) && !allowElimination) {
                    dispatcher.addPostErrorResult(
                        masterRecord,
                        new PostResult.PostErrorResult(
                            masterRecord.getSObject('Ledger__r'),
                            PostResult.StatusCode.LEDGER_TYPE_NOT_ALLOWED,
                            String.format(LEDGER_TYPE_ELIMINATION_NOT_ALLOWED_ERROR_MESSAGE, new List<String>{
                                sourceDocumentLabel
                            })
                        )
                    );
                } else {
                    validRecords.add(masterRecord);
                }
            }

            if (!fullStatistics) {
                sourceRecords = validRecords;
            }
        }

    }

    protected void validateNoQualifyingPostedRecords() {
        validateNoQualifyingPostedRecords(AbstractPostHandler.NO_SELECTION_POSTED_ERROR_MESSAGE);
    }

    protected void validateNoQualifyingPostedRecords(String error) {
        if (sourceRecords.isEmpty()) {
            for (Id recordId : processedRecordIds) {
                dispatcher.addPostErrorResult(
                    recordId,
                    new PostResult.PostErrorResult(
                        PostResult.StatusCode.NO_QUALIFYING_RECORDS,
                        error
                    )
                );
            }
        }
    }

    protected void validateNoQualifyingUnpostedRecords(String error) {
        if (sourceRecords.isEmpty()) {
            for (Id recordId : processedRecordIds) {
                dispatcher.addPostErrorResult(
                    recordId,
                    new PostResult.PostErrorResult(
                        PostResult.StatusCode.NO_QUALIFYING_RECORDS,
                        error
                    )
                );
            }
        }
    }

    protected void validateCashFlowCategoryIsDefined(Boolean fullStatistics) {
        List<SObject> validRecords = new List<SObject>();
        getAccountingSettings();
        if (main.Enable_Cash_Flow_Statement__c) {
            for (SObject masterRecord : sourceRecords) {
                if (masterRecord.get('Cash_Flow_Category__c') == NULL) {
                    dispatcher.addPostErrorResult(
                        masterRecord,
                        new PostResult.PostErrorResult(
                            masterRecord,
                            PostResult.StatusCode.NO_CASH_FLOW_CATEGORY,
                            NO_CASH_FLOW_CATEGORY_HELP_TEXT
                        )
                    );
                } else {
                    validRecords.add(masterRecord);
                }
            }

            if (!fullStatistics) {
                sourceRecords = validRecords;
            }
        }
    }

    protected void validateCashFlowStatementConformity(Boolean fullStatistics) {
        List<SObject> validRecords = new List<SObject>();
        getAccountingSettings();
        if (!main.Enable_Cash_Flow_Statement__c) {
            for (SObject masterRecord : sourceRecords) {
                if (masterRecord.get('Cash_Flow_Category__c') != NULL) {
                    dispatcher.addPostErrorResult(
                        masterRecord,
                        new PostResult.PostErrorResult(
                            masterRecord,
                            PostResult.StatusCode.CASH_FLOW_NON_CONFORMITY,
                            CASH_FLOW_NON_CONFORMITY_HELP_TEXT
                        )
                    );
                } else {
                    validRecords.add(masterRecord);
                }
            }

            if (!fullStatistics) {
                sourceRecords = validRecords;
            }
        }
    }

    protected void validatePostStatusSet() {
        validatePostStatusSet(sourceRecords);
    }

    protected void validatePostStatusSet(List<SObject> sourceRecords) {
        for (SObject masterRecord : sourceRecords) {
            if (masterRecord.get('Status__c') != DEFAULT_POSTING_STATUS_POSTED) {
                throw new PostHandlerException(STATUS_NOT_POSTED_HELP_TEXT);
            }
        }
    }

    //======================================================================================
    //=== Group of common utility methods ===================================
    //======================================================================================

    protected Accounting_Settings__c getAccountingSettings() {
        if (main == NULL) {
            main = AccountingSettingsHandler.getAccountingSettings();
        }
        return main;
    }

    protected Map<Id, Map<String, GL_Account_Default__c>> getGLAccountDefaults(List<SObject> sourceRecords) {
        Map<Id, Map<String, GL_Account_Default__c>> result = new Map<Id, Map<String, GL_Account_Default__c>>();
        if (!sourceRecords.isEmpty()) {
            Set<Id> ledgerIds = new Set<Id> (SObjectActions.ledgerIdBySourceId(sourceRecords).values());
            Set<Id> shadowLedgerIds = new Set<Id>();
            for (Id ledgerId : ledgerIds) {
                if (LedgerHandler.getInstanceWithoutSharing().isAccrualAndCashLedger(ledgerId)) {
                    shadowLedgerIds.add(LedgerHandler.getInstanceWithoutSharing().getShadowLedgerByParent(ledgerId).Id);
                }
            }
            ledgerIds.addAll(shadowLedgerIds);
            result = GLAccount.glAccountDefaultsMapByLedgerId(ledgerIds);
        }
        return result;
    }

    protected void getGLAccountDefaults() {
        glAccountDefaults = getGLAccountDefaults(sourceRecords);
    }

    protected void getCurrencyInformation() {
        if (IS_MULTI_CURRENCY_ENABLED && sourceIdToCurrencyCode == NULL && sourceIdToCurrencyConversionRate == NULL) {
            sourceIdToCurrencyCode = MultiCurrencyHandler.getCurrencyMap(sourceRecords);
            if (!sourceRecords.isEmpty() && sourceRecords[0].getSobjectType().getDescribe().fields.getMap().keySet().contains(PACKAGE_QUALIFIER.toLowerCase() + 'currency_conversion_rate__c')) {
                sourceIdToCurrencyConversionRate = MultiCurrencyHandler.getCurrencyConversionRate(sourceRecords);
            }
        }
    }

    protected void processSystemExceptions(Exception ex) {
        if (!sourceRecords.isEmpty()) {
            for (SObject sourceRecord : sourceRecords) {
                dispatcher.addPostErrorResult(
                    sourceRecord,
                    new PostResult.PostErrorResult(
                        sourceRecord,
                        PostResult.StatusCode.SYSTEM_EXCEPTION,
                        ex.getMessage()
                    )
                );
            }
        } else {
            for (Id recordId : processedRecordIds) {
                dispatcher.addPostErrorResult(
                    recordId,
                    new PostResult.PostErrorResult(
                        PostResult.StatusCode.SYSTEM_EXCEPTION,
                        ex.getMessage()
                    )
                );
            }
        }
    }

    protected void processDmlExceptions(DmlException dmlEx) {
        String errorMessage = dmlEx.getDmlMessage(0);
        if (dmlEx.getDmlType(0) == System.StatusCode.INSUFFICIENT_ACCESS_OR_READONLY) {
            errorMessage = INSUFFICIENT_ACCESS_OR_READONLY_ERROR_MESSAGE;
        }
        for (SObject sourceRecord : sourceRecords) {
            dispatcher.addPostErrorResult(
                sourceRecord,
                new PostResult.PostErrorResult(
                    sourceRecord,
                    PostResult.StatusCode.SYSTEM_EXCEPTION,
                    String.format(errorMessage, new List<String>{
                        sourceRecord.getSObjectType().getDescribe().Label
                    })
                )
            );
        }
    }

    protected void processPostResult() {
        for (SObject sourceRecord : sourceRecords) {
            if (!dispatcher.getPostResultsMap().containsKey(sourceRecord.Id)) {
                dispatcher.addPostResult(sourceRecord.Id, new PostResult(true, sourceRecord.Id, NULL));
            }
        }
    }

    protected Boolean isMultiCurrencyAndDifferentCurrency(Id recordId, Id ledgerId) {
        return IS_MULTI_CURRENCY_ENABLED  && sourceIdToCurrencyCode.get(recordId) != null
            && (sourceIdToCurrencyCode.get(recordId) !=
            (String) LedgerHandler.getInstanceWithoutSharing()
                .getAllLedgersMap()
                .get(ledgerId)
                .get('CurrencyIsoCode'));
    }

    protected List<Transaction__c> setLedgerIsoCodeToTransactions(List<Transaction__c> transactionsList) {
        for (Transaction__c tr : transactionsList) {
            tr.put(
                'CurrencyIsoCode',
                LedgerHandler.getInstanceWithoutSharing()
                    .getAllLedgersMap()
                    .get(tr.Ledger__c)
                    .get('CurrencyIsoCode'));
        }
        return transactionsList;
    }

    protected Set<String> getHeaderLevelIds(SObjectField headerId) {
        Set<String> headerIds = new Set<String>();
        for (SObject doc : sourceRecordLines) {
            headerIds.add((Id) doc.get(headerId));
        }
        return headerIds;
    }

    //Set the scale to the decimal precision of the sObject field that is being set
    @TestVisible protected Decimal sumDecimalResult(Decimal existingValue, Decimal newValue, Integer scale) {
        Integer decimalScale = scale == null ? 2 : scale;
        existingValue = existingValue != null ? existingValue.setScale(decimalScale, RoundingMode.HALF_UP) : 0;
        newValue = newValue != null ? newValue.setScale(decimalScale, RoundingMode.HALF_UP) : 0;
        return existingValue += newValue;
    }

    public void consolidateTransaction(Transaction__c newPt, Transaction__c existedPt) {
        existedPt.Amount__c = sumDecimalResult(existedPt.Amount__c, newPt.Amount__c, 2);
        existedPt.Units__c = sumDecimalResult(existedPt.Units__c, newPt.Units__c, 6);
        if (newPt.Foreign_Amount__c != null) {
            existedPt.Foreign_Amount__c = sumDecimalResult(existedPt.Foreign_Amount__c, newPt.Foreign_Amount__c, 2);
        }
    }

    protected void populateTransactionMap(Transaction__c pt,
        Map<String, Transaction__c> transactionMap,
        Boolean isTaxTransaction) {

        if (!transactionMap.containsKey(getTransactionKey(pt, isTaxTransaction))) {
            transactionMap.put(getTransactionKey(pt, isTaxTransaction), pt);
        } else {
            consolidateTransaction(pt, transactionMap.get(getTransactionKey(pt, isTaxTransaction)));
        }
    }

    protected virtual String getTransactionKey(Transaction__c pt, Boolean isTaxTransaction) {
        return '';
    }

    public List<Transaction__c> getExistedTransactionByKeys(Set<String> keys) {
        //=================================================
        //build dynamic SOQL query using SOQLBuilder class
        //=================================================
        //Select fields
        List<String> fieldsToQuery = new List<String>{
            'Id',
            'Name',
            'Billing__c',
            'Billing_Line__c',
            'Billing_Cash_Receipt__c',
            'Currency_Conversion_Rate__c',
            'Account_Payable__c',
            'Account_Payable_Line__c',
            'Journal_Entry_Line__c',
            'Cash_Disbursement__c',
            'Cash_Receipt__c',
            'AP_Disbursement__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c',
            'GL_Account__c',
            'Time_Card_Variable_1__c',
            'Time_Card_Variable_2__c',
            'Product__c',
            'Project__c',
            'Project_Task__c',
            'Amount__c',
            'Units__c',
            'Foreign_Amount__c',
            'Ledger__c',
            'Time_Card_Day__c',
            'Scheduled_Revenue_Expense__c',
            'Accounting_Period__c'
        };

        //Add query condition
        String queryCondition = 'Transaction_Key__c IN :keys';

        String dynamicSOQL = SOQLBuilder.buildDynamicSoqlQuery(
            fieldsToQuery,
            null,
            Transaction__c.SObjectType,
            queryCondition,
            true,
            false
        );

        return (List<Transaction__c>) Database.query(dynamicSOQL);
    }

    public static Boolean validatePostingStatus(String status) {
        return
            !new Set<String>{
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTING_IN_PROGRESS,
                AbstractPostHandler.DEFAULT_POSTING_STATUS_UNPOSTING_IN_PROGRESS
            }.contains(status);
    }
}