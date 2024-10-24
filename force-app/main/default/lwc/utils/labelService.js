// common
import ERR_COMMON_APPLIED_DATE_OPEN_PERIOD from '@salesforce/label/c.ERR_COMMON_APPLIED_DATE_OPEN_PERIOD';
import ERR_COMMON_GREATER_APPLIED_DATE from '@salesforce/label/c.ERR_COMMON_GREATER_APPLIED_DATE';
import COMMON_SMALL_RESULTS from '@salesforce/label/c.COMMON_SMALL_RESULTS';
import COMMON_SEARCH from '@salesforce/label/c.COMMON_SEARCH';
import COMMON_INFO from '@salesforce/label/c.COMMON_INFO';
import COMMON_WARNING from '@salesforce/label/c.COMMON_WARNING';
import COMMON_AT from '@salesforce/label/c.COMMON_AT';
import COMMON_PAYABLE from '@salesforce/label/c.COMMON_PAYABLE';
import COMMON_BILLING from '@salesforce/label/c.COMMON_BILLING';
import COMMON_DEFERRED_REVENUE from '@salesforce/label/c.COMMON_DEFERRED_REVENUE';
import COMMON_DEFERRED_EXPENSE from '@salesforce/label/c.COMMON_DEFERRED_EXPENSE';
import commonAll from '@salesforce/label/c.COMMON_ALL';
import commonAdd from '@salesforce/label/c.COMMON_ADD';
import commonAddEditLines from '@salesforce/label/c.COMMON_ADD_EDIT_LINES';
import commonOn from '@salesforce/label/c.COMMON_ON';
import commonOff from '@salesforce/label/c.COMMON_OFF';
import commonOk from '@salesforce/label/c.COMMON_OK';
import commonBack from '@salesforce/label/c.COMMON_BACK';
import commonCancel from '@salesforce/label/c.COMMON_CANCEL';
import commonSave from '@salesforce/label/c.COMMON_SAVE';
import commonSaveNew from '@salesforce/label/c.COMMON_SAVE_AND_NEW';
import commonDelete from '@salesforce/label/c.COMMON_DELETE';
import commonUtilities from '@salesforce/label/c.COMMON_UTILITIES';
import commonConfiguration from '@salesforce/label/c.COMMON_CONFIG';
import commonAutomations from '@salesforce/label/c.COMMON_AUTOMATIONS';
import commonNext from '@salesforce/label/c.COMMON_NEXT';
import commonPrevious from '@salesforce/label/c.COMMON_PREVIOUS';
import commonPreviewCalculations from '@salesforce/label/c.COMMON_PREVIEW_CALCULATIONS';
import commonCreateEntries from '@salesforce/label/c.COMMON_CREATE_ENTRIES';
import commonView from '@salesforce/label/c.COMMON_VIEW';
import commonNew from '@salesforce/label/c.COMMON_NEW';
import commonRefresh from '@salesforce/label/c.COMMON_REFRESH';
import commonEdit from '@salesforce/label/c.COMMON_EDIT';
import commonCreate from '@salesforce/label/c.COMMON_CREATE';
import commonConfirm from '@salesforce/label/c.COMMON_CONFIRM';
import commonRemove from '@salesforce/label/c.COMMON_REMOVE';
import commonRun from '@salesforce/label/c.COMMON_RUN';
import commonClose from '@salesforce/label/c.COMMON_CLOSE';
import commonNone from '@salesforce/label/c.COMMON_NONE';
import commonHelp from '@salesforce/label/c.COMMON_HELP';
import commonValidated from '@salesforce/label/c.COMMON_VALIDATED';
import commonBilling from '@salesforce/label/c.COMMON_BILLING';
import commonPayable from '@salesforce/label/c.COMMON_PAYABLE';
import commonAccountingInformation from '@salesforce/label/c.COMMON_ACCOUNTING_INFORMATION';
import commonPeriods from '@salesforce/label/c.COMMON_PERIODS';
import commonAmounts from '@salesforce/label/c.COMMON_AMOUNTS';
import commonNumberAccountingPeriods from '@salesforce/label/c.COMMON_NUMBER_ACCOUNTING_PERIODS';
import commonEndDate from '@salesforce/label/c.COMMON_END_DATE';
import commonDescription from '@salesforce/label/c.COMMON_DESCRIPTION';
import commonApplied from '@salesforce/label/c.COMMON_APPLIED';
import commonBalance from '@salesforce/label/c.COMMON_BALANCE';
import commonAccountingHome from '@salesforce/label/c.COMMON_ACCOUNTING_HOME';
import commonAmortizationEntries from '@salesforce/label/c.COMMON_AMORTIZATION_ENTRIES';
import commonAPDisbursements from '@salesforce/label/c.COMMON_AP_DISBURSEMENTS';
import commonBillingsBCaps from '@salesforce/label/c.COMMON_BILLINGS_B_CAPS';
import commonCashDisbursements from '@salesforce/label/c.COMMON_CASH_DISBURSEMENTS';
import commonCashReceipts from '@salesforce/label/c.COMMON_CASH_RECEIPTS';
import commonJournalEntries from '@salesforce/label/c.COMMON_JOURNAL_ENTRIES';
import commonTimeCards from '@salesforce/label/c.COMMON_TIME_CARDS';
import commonPayments from '@salesforce/label/c.COMMON_PAYMENTS';
import commonDeposits from '@salesforce/label/c.COMMON_DEPOSITS';
import commonCharges from '@salesforce/label/c.COMMON_CHARGES';
import commonCompleted from '@salesforce/label/c.COMMON_COMPLETED';
import commonInProgress from '@salesforce/label/c.COMMON_IN_PROGRESS';
import commonWorking from '@salesforce/label/c.COMMON_WORKING';
import commonAutoClearRunning from '@salesforce/label/c.COMMON_AUTO_CLEAR_RUNNING';
import commonCreditCard from '@salesforce/label/c.COMMON_CREDIT_CARD_PAYMENT_METHOD_TYPE';
import commonDifference from '@salesforce/label/c.COMMON_DIFFERENCE';
import commonBankReconciliation from '@salesforce/label/c.COMMON_BANK_RECONCILIATION';
import commonPDF from '@salesforce/label/c.COMMON_PDF';
import commonCSV from '@salesforce/label/c.COMMON_CSV';
import commonSummary from '@salesforce/label/c.COMMON_SUMMARY';
import commonFile from '@salesforce/label/c.COMMON_FILE';
import commonSmallFile from '@salesforce/label/c.COMMON_SMALL_FILE';
import commonSmallReport from '@salesforce/label/c.COMMON_SMALL_REPORT';
import commonBankDeposit from '@salesforce/label/c.COMMON_BANK_DEPOSIT';
import commonCloseDialog from '@salesforce/label/c.COMMON_CLOSE_DIALOG';
import commonDate from '@salesforce/label/c.COMMON_DATE';
import commonFilter from '@salesforce/label/c.COMMON_FILTER';
import commonCleared from '@salesforce/label/c.COMMON_CLEARED';
import commonPayee from '@salesforce/label/c.COMMON_PAYEE';
import commonUncleared from '@salesforce/label/c.COMMON_UNCLEARED';
import commonPayment from '@salesforce/label/c.COMMON_PAYMENT';
import commonCharge from '@salesforce/label/c.COMMON_CHARGE';
import commonInvalidDate from '@salesforce/label/c.COMMON_INVALID_DATE';
import commonApply from '@salesforce/label/c.COMMON_APPLY';
import commonJournalEntry from '@salesforce/label/c.COMMON_JOURNAL_ENTRY';
import commonChangesSaved from '@salesforce/label/c.X_DATA_SAVED_SUCCESSFULLY';
import commonSaveSuccessful from '@salesforce/label/c.COMMON_SAVE_SUCCESSFUL';
import commonDeposit from '@salesforce/label/c.COMMON_DEPOSIT';
import commonAccount from '@salesforce/label/c.COMMON_ACCOUNT';
import commonGLAccount from '@salesforce/label/c.COMMON_GL_ACCOUNT';
import commonDetails from '@salesforce/label/c.COMMON_DETAILS';
import commonProjectTask from '@salesforce/label/c.COMMON_PROJECT_TASK';
import commonCashFlowCategory from '@salesforce/label/c.COMMON_CASH_FLOW_CATEGORY';
import commonStatus from '@salesforce/label/c.COMMON_STATUS';
import commonSource from '@salesforce/label/c.COMMON_SOURCE';
import commonAdded from '@salesforce/label/c.COMMON_ADDED';
import commonCredit from '@salesforce/label/c.COMMON_CREDIT';
import commonDebit from '@salesforce/label/c.COMMON_DEBIT';
import commonProject from '@salesforce/label/c.COMMON_PROJECT';
import commonImport from '@salesforce/label/c.XCSV_UPLOAD';
import commonRecordsFound from '@salesforce/label/c.COMMON_RECORD_FOUND';
import commonCheckNo from '@salesforce/label/c.COMMON_CHECK_NO';
import commonContact from '@salesforce/label/c.COMMON_CONTACT';
import commonEmployee from '@salesforce/label/c.COMMON_EMPLOYEE';
import commonMatch from '@salesforce/label/c.COMMON_MATCH';
import commonUnsavedChanges from '@salesforce/label/c.COMMON_UNSAVED_CHANGES';
import commonUnsavedChangesDiscardContinue from '@salesforce/label/c.COMMON_UNSAVED_CHANGES_DISCARD_CONTINUE';
import commonLoadingText from '@salesforce/label/c.COMMON_LOADING_TEXT';
import commonSaveAndComplete from '@salesforce/label/c.COMMON_SAVE_AND_COMPLETE';
import commonSaveAndRefresh from '@salesforce/label/c.COMMON_SAVE_AND_REFRESH';
import commonBillingNo from '@salesforce/label/c.COMMON_BILLING_NUMBER';
import commonTotalApplied from '@salesforce/label/c.COMMON_TOTAL_APPLIED';
import commonAppliedAmount from '@salesforce/label/c.COMMON_APPLIED_AMOUNT';
import commonAppliedDate from '@salesforce/label/c.COMMON_APPLIED_DATE';
import commonCashDisbursement from '@salesforce/label/c.COMMON_CASH_DISBURSEMENT';
import commonPayableNumber from '@salesforce/label/c.COMMON_PAYABLE_NUMBER';
import commonPayableAmount from '@salesforce/label/c.COMMON_PAYABLE_AMOUNT';
import commonPayableBalance from '@salesforce/label/c.COMMON_PAYABLE_BALANCE';
import commonPaymentReference from '@salesforce/label/c.COMMON_PAYMENT_REFERENCE';
import commonCashReceipt from '@salesforce/label/c.COMMON_CASH_RECEIPT';
import commonReceivedAmt from '@salesforce/label/c.COMMON_RECEIVED_AMOUNT';
import commonAdjustmentGLAcct from '@salesforce/label/c.COMMON_ADJUSTMENT_GL_ACCOUNT';
import commonCompleteThisField from '@salesforce/label/c.COMMON_ERR_COMPLETE_THIS_FIELD';
import commonThe from '@salesforce/label/c.COMMON_THE';
import commonExpandAll from '@salesforce/label/c.COMMON_EXPAND_ALL';
import commonCollapseAll from '@salesforce/label/c.COMMON_COLLAPSE_ALL';
import commonRefreshText from '@salesforce/label/c.XCOMMON_REFRESH';
import commonCurrency from '@salesforce/label/c.COMMON_CURRENCY';
import commonClick from '@salesforce/label/c.COMMON_CLICK';
import commonName from '@salesforce/label/c.COMMON_NAME';
import commonProcessing from '@salesforce/label/c.COMMON_PROCESSING';
import commonSort from '@salesforce/label/c.COMMON_SORT';
import commonClone from '@salesforce/label/c.COMMON_CLONE';
import commonLine from '@salesforce/label/c.COMMON_LINE';
import commonExpenseAndMileageLines from '@salesforce/label/c.COMMON_EXPENSE_AND_MILEAGE_LINES';
import commonStartingAccountPeriod from '@salesforce/label/c.COMMON_STARTING_ACCOUNT_PERIOD';
import commonEndingAccountPeriod from '@salesforce/label/c.COMMON_ENDING_ACCOUNTING_PERIOD';
import commonSuppressZeroAmtRows from '@salesforce/label/c.COMMON_SUPPRESS_ZERO_AMT_ROWS';
import commonReportSubtitle from '@salesforce/label/c.COMMON_REPORT_SUBTITLE';
import commonReportSubtitleDisplay from '@salesforce/label/c.COMMON_REPORT_SUBTITLE_TEXT_DISPLAY';
import commonReportRounding from '@salesforce/label/c.COMMON_REPORT_ROUNDING';
import commonRunReport from '@salesforce/label/c.COMMON_RUN_REPORT';
import commonAggregateBy from '@salesforce/label/c.COMMON_AGGREGATE_BY';
import commonBillingLine from '@salesforce/label/c.COMMON_BILLING_LINE';
import commonJournalEntryLine from '@salesforce/label/c.COMMON_JOURNAL_ENTRY_LINE';
import commonPayableLine from '@salesforce/label/c.COMMON_PAYABLE_LINE';
import commonGLVariable from '@salesforce/label/c.COMMON_GL_VARIABLE';
import commonBudgetLedger from '@salesforce/label/c.COMMON_BUDGET_LEDGER';
import commonInquiryResultCount from '@salesforce/label/c.COMMON_INQUIRY_RESULT_COUNT';
import commonOpeningBalance from '@salesforce/label/c.COMMON_OPENING_BALANCE';
import commonInquiryAmount from '@salesforce/label/c.COMMON_INQUIRY_AMOUNT';
import commonYearToDateBalance from '@salesforce/label/c.COMMON_YEAR_TO_DATE_BALANCE';
import commonReportResults from '@salesforce/label/c.COMMON_REPORT_RESULTS';
import commonTotalAmount from '@salesforce/label/c.COMMON_TOTAL_AMOUNT';
import commonRunningBalance from '@salesforce/label/c.COMMON_RUNNING_BALANCE';
import commonCreatedBy from '@salesforce/label/c.COMMON_CREATED_BY';
import commonExcel from '@salesforce/label/c.COMMON_EXCEL';
import commonFinancialReports from '@salesforce/label/c.COMMON_FINANCIAL_REPORTS';
import commonStartPeriod from '@salesforce/label/c.COMMON_START_PERIOD';
import commonEndPeriod from '@salesforce/label/c.COMMON_END_PERIOD';
import commonPeriod from '@salesforce/label/c.COMMON_PERIOD';
import commonSettings from '@salesforce/label/c.COMMON_SETTINGS';
import commonErrorDuringSave from '@salesforce/label/c.ERR_DURING_SAVE';
import commonFinancialInstitution from '@salesforce/label/c.INF_FINANCIAL_INSTITUTION';
import commonBankGLAcct from '@salesforce/label/c.INF_BANK_GL_ACCOUNT';
import commonLastRefreshedDate from '@salesforce/label/c.INF_LAST_REFRESHED_DATE';
import commonBankSettings from '@salesforce/label/c.INF_BANK_SETTINGS';
import commonSectionTitle from '@salesforce/label/c.INF_SECTION_TITLE';
import commonActions from '@salesforce/label/c.INF_ACTIONS';
import commonLastPeriodClosed from '@salesforce/label/c.COMMON_LAST_PERIOD_CLOSED';
import commonDueDateStart from '@salesforce/label/c.COMMON_DUE_DATE_START';
import commonDueDateEnd from '@salesforce/label/c.COMMON_DUE_DATE_END';
import commonAreYouSure from '@salesforce/label/c.COMMON_WRN_ARE_YOU_SURE';
import commonSelectFile from '@salesforce/label/c.COMMON_SELECT_FILE';
import commonSearchBillings from '@salesforce/label/c.COMMON_SEARCH_BILLINGS';
import commonBillingAmount from '@salesforce/label/c.COMMON_BILLING_AMOUNT';
import commonBillingBalance from '@salesforce/label/c.COMMON_BILLING_BALANCE';
import commonHierarchy from '@salesforce/label/c.COMMON_HIERARCHY';
import commonLedgerType from '@salesforce/label/c.COMMON_LEDGER_TYPE';
import commonCurrentBalance from '@salesforce/label/c.COMMON_CURRENT_BALANCE';
import commonCreditVendor from '@salesforce/label/c.COMMON_CREDIT_CARD_VENDOR';
import commonExpenseType from '@salesforce/label/c.COMMON_EXPENSE_TYPE';
import commonMileageOrigin from '@salesforce/label/c.COMMON_MILEAGE_ORIGIN';
import commonMileageDestination from '@salesforce/label/c.COMMON_MILEAGE_DESTINATION';
import commonMiles from '@salesforce/label/c.COMMON_MILES';
import commonIncludeSubType2 from '@salesforce/label/c.COMMON_INCLUDE_SUB_TYPE_2';
import commonTransactionalLedgerForReport from '@salesforce/label/c.COMMON_TRANSACTIONAL_LEDGER_FOR_REPORT';
import commonIncludeSubType1 from '@salesforce/label/c.COMMON_INCLUDE_SUB_TYPE_1';
import commonShowAllPeriods from '@salesforce/label/c.COMMON_SHOW_ALL_PERIODS';
import commonCustomReports from '@salesforce/label/c.COMMON_CUSTOM_REPORTS';
import commomRecords from '@salesforce/label/c.COMMON_RECORDS';
import commonNoneOption from '@salesforce/label/c.SELECT_OPTION_NONE';
import commonForm1099Type from '@salesforce/label/c.COMMON_FORM_1099_TYPE';
import commonForm1099Box from '@salesforce/label/c.COMMON_FORM_1099_BOX';
import commonBillable from '@salesforce/label/c.COMMON_BILLABLE';
import commonOvertime from '@salesforce/label/c.COMMON_OVERTIME';
import commonVariableOne from '@salesforce/label/c.COMMON_VARIABLE_1';
import commonVariableTwo from '@salesforce/label/c.COMMON_VARIABLE_2';
import commonTotal from '@salesforce/label/c.COMMON_TOTAL';
import commonDrawer from '@salesforce/label/c.COMMON_DRAWER';
import commonLoading from '@salesforce/label/c.COMMON_LOADING';
import commonKnowledgeBase from '@salesforce/label/c.KNOWLEDGE_BASE';
import commonSupport from '@salesforce/label/c.SUPPORT';
import commonAmount from '@salesforce/label/c.COMMON_AMOUNT';
import commonSuccess from '@salesforce/label/c.COMMON_SUCCESS';
import commonErrorText from '@salesforce/label/c.COMMON_ERROR_TEXT';
import commonSaving from '@salesforce/label/c.COMMON_SAVING';
import commonPayables from '@salesforce/label/c.COMMON_PAYABLES';
import commonType from '@salesforce/label/c.COMMON_TYPE';
import commonPosted from '@salesforce/label/c.COMMON_POSTED';
import commonApproved from '@salesforce/label/c.COMMON_APPROVED';
import commonViewAll from '@salesforce/label/c.COMMON_VIEW_ALL';
import commonAddLine from '@salesforce/label/c.COMMON_ADD_LINE';
import commonYouHaveUnsavedChanges from '@salesforce/label/c.WRN_YOU_HAVE_UNSAVED_CHANGES';
import commonFrom from '@salesforce/label/c.COMMON_FROM';
import commonToDot from '@salesforce/label/c.COMMON_TO_DOT';
import commonValueReq from '@salesforce/label/c.COMMON_ERR_VALUE_REQUIRED';
import commonCreditMemoDate from '@salesforce/label/c.COMMON_CREDIT_MEMO_DATE';
import commonPostingStatus from '@salesforce/label/c.COMMON_POSTING_STATUS';
import commonDueDateRange from '@salesforce/label/c.COMMON_DUE_DATE_RANGE';
import commonRemoveSelectedOption from '@salesforce/label/c.COMMON_REMOVE_SELECTED_OPTION';
import commonMapFields from '@salesforce/label/c.COMMON_MAP_FIELDS';
import recordsUpdated from '@salesforce/label/c.INF_RECORDS_UPDATED';
import recordsFailed from '@salesforce/label/c.INF_RECORDS_FAILED';
import errorCreditMemoBalanceLessThanZero from '@salesforce/label/c.ERR_CREDIT_BAL_CANNOT_LESS_THAN_ZERO';
import errorAppliedAmountLessThanZero from '@salesforce/label/c.ERR_APPLIED_AMOUNT_LESS_THAN_0';
import errorAppliedDateMustBeGreaterThan from '@salesforce/label/c.ERR_APPLIED_DATE_TOO_EARLY';
import errorPayableBalanceCannotBeLessThanZero from '@salesforce/label/c.ERR_PAYABLE_BAL_CANNOT_LESS_THAN_0';
import errorOccured from '@salesforce/label/c.ERR_OCCURED';
import errorBillingBalanceNotLessThanZero from '@salesforce/label/c.ERR_BILLING_BAL_CANNOT_LESS_THAN_ZERO';
import errorMustEnterValue from '@salesforce/label/c.ERR_MUST_ENTER_VALUE';
import knowledgeBase from '@salesforce/label/c.KNOWLEDGE_BASE';
import commonHasBeenSuccessfullyDeleted from '@salesforce/label/c.COMMON_HAS_BEEN_SUCCESSFULLY_DELETED';
import commonHasBeenSuccessfullyUpdated from '@salesforce/label/c.COMMON_HAS_BEEN_SUCCESSFULLY_UPDATED';
import errorEndDateMustBeGreaterThanStart from '@salesforce/label/c.COMMON_ERR_END_DATE_MUST_BE_GREATER_THAN_START_DATE';
import errorMaxMustBeGreaterThanMin from '@salesforce/label/c.COMMON_ERR_MAX_MUST_BE_GREATER_THAN_MIN';
import errorPreventingSave from '@salesforce/label/c.ERR_PREVENTING_SAVE';
import errorRetrieving1099Data from '@salesforce/label/c.ERR_RETRIEVING_1099_DATA';
import commonSelected from '@salesforce/label/c.COMMON_SELECTED';
import commonRequired from '@salesforce/label/c.COMMON_REQUIRED';
import errorValueMissing from '@salesforce/label/c.ERR_MISSING_VALUE';
import errorNoAccess from '@salesforce/label/c.ERR_NO_ACCESS';
import errorNoAccessToFeature from '@salesforce/label/c.ERR_NO_ACCESS_TO_FEATURE';
import accountingSetup from '@salesforce/label/c.ACCOUNTING_SETUP';
import commonToastErrorTitle from '@salesforce/label/c.ERR_COMMON_TOAST_ERROR_TITLE';
import commonToastPageLoadErrorMsg from '@salesforce/label/c.ERR_COMMON_TOAST_PAGE_LOAD_ERROR_MSG';
import commonToastSuccessTitle from '@salesforce/label/c.INF_COMMON_TOAST_SUCCESS_TITLE';
import commonSaveChangesOrRemoveChanges from '@salesforce/label/c.COMMON_SAVE_CHANGES_OR_REMOVE_CHANGES';
import commonSaveSuccess from '@salesforce/label/c.INF_COMMON_SAVE_SUCCESS';
import commonCreateAndApply from '@salesforce/label/c.COMMON_CREATE_AND_APPLY';
import commonAvailable from '@salesforce/label/c.COMMON_AVAILABLE';
import common1099Information from '@salesforce/label/c.COMMON_1099_INF';
import sandbox from '@salesforce/label/c.SANDBOX';
import production from '@salesforce/label/c.PRODUCTION';
import calculateEstimateTax from '@salesforce/label/c.CALCULATE_ESTIMATE_TITLE';
import opportunity from '@salesforce/label/c.OPPORTUNITY';
import overrides from '@salesforce/label/c.OVERRIDES';
import customer from '@salesforce/label/c.CUSTOMER';
import taxMethodOnLedger from '@salesforce/label/c.TAX_METHOD_ON_LEDGER_LABEL';
import subtotal from '@salesforce/label/c.SUBTOTAL';
import discount from '@salesforce/label/c.DISCOUNT';
import estimatedTaxAmount from '@salesforce/label/c.ESTIMATED_TAX_AMOUNT';
import estimatedTotal from '@salesforce/label/c.ESTIMATED_TOTAL';
import originAddressOverride from '@salesforce/label/c.ORIGIN_ADDRESS_OVERRIDE';
import destinationAddressOverride from '@salesforce/label/c.DESTINATION_ADDRESS_OVERRIDE';
import opportunityProductLine from '@salesforce/label/c.OPPORTUNITY_PRODUCT_LINE';
import opportunityTaxProductLine from '@salesforce/label/c.OPPORTUNITY_TAX_PRODUCT_LINE';
import updateTax from '@salesforce/label/c.UPDATE_TAX';
import calculateTax from '@salesforce/label/c.CALCULATE_TAX';
import commonProduct from '@salesforce/label/c.COMMON_PRODUCT';
import quantity from '@salesforce/label/c.QUANTITY';
import commonPrice from '@salesforce/label/c.COMMON_PRICE';
import taxGroup from '@salesforce/label/c.TAX_GROUP';
import taxEstimateLedgerHelpText from '@salesforce/label/c.TAX_ESTIMATE_LEDGER_HELP_TEXT';
import taxMethodLedgerHelpText from '@salesforce/label/c.TAX_METHOD_LEDGER_HELP_TEXT';
import taxEstimateSuccessText from '@salesforce/label/c.TAX_ESTIMATE_SUCCESS_TEXT';
import taxRateName from '@salesforce/label/c.TAX_RATE_NAME';
import taxRatePercentage from '@salesforce/label/c.TAX_RATE_PERCENTAGE';
import avalaraTaxProduct from '@salesforce/label/c.AVALARA_TAX_PRODUCT';
import llpCreateInfoMessage from '@salesforce/label/c.TAX_LLP_CREATE_INFO_MESSAGE';
import automatedJobsSelectSchdPostTitle from '@salesforce/label/c.INF_AUTOMATED_JOBS_SELECT_SCHD_POST_TITLE';

// Account Settings -> Automated Jobs
import scheduledPost from '@salesforce/label/c.INF_AUTOMATED_JOBS_SCHEDULED_POST';
import scheduledBankDownload from '@salesforce/label/c.INF_AUTOMATED_JOBS_SCHEDULED_BANK_DL';
import npsp from '@salesforce/label/c.INF_AUTOMATED_JOBS_NPSP';
import jobScheduledSuccess from '@salesforce/label/c.INF_AUTOMATED_JOBS_SCHEDULED_SUCCESS';
import jobRemovedSuccess from '@salesforce/label/c.INF_AUTOMATED_JOBS_REMOVE_SUCCESS';
import notificationSettingsSuccess from '@salesforce/label/c.INF_AUTOMATED_JOBS_NOTIFY_SUCCESS';
import keepResultsError from '@salesforce/label/c.ERR_AUTOMATED_JOBS_KEEP_RESULT';
import automatedJobsPageHeader from '@salesforce/label/c.AUTOMATED_JOBS_PAGE_HEADER';
import automatedJobsAddEdit from '@salesforce/label/c.AUTOMATED_JOBS_ADD_EDIT';
import automatedJobsSelectLabel from '@salesforce/label/c.AUTOMATED_JOBS_SELECT_JOB_LABEL';
import automatedJobsSelectPlaceholder from '@salesforce/label/c.AUTOMATED_JOBS_SELECT_JOB_PLACEHOLDER';
import commonPreferredStartTime from '@salesforce/label/c.COMMON_PREFERRED_START_TIME';
import automatedJobsNotImeSlotsAvailable from '@salesforce/label/c.AUTOMATED_JOBS_NO_TIME_SLOTS_AVAILABLE';
import automatedJobsSelectedValueError from '@salesforce/label/c.AUTOMATED_JOBS_SELECT_VALUES_ERROR';
import automatedJobsAddButton from '@salesforce/label/c.AUTOMATED_JOBS_ADD_JOB_BTN';
import automatedJobsRun from '@salesforce/label/c.AUTOMATED_JOBS_RUN_JOB';
import automatedJobsRunNowButton from '@salesforce/label/c.AUTOMATED_JOBS_RUN_JOB_BTN';
import automatedJobsScheduled from '@salesforce/label/c.AUTOMATED_JOBS_SCHEDULED_JOBS';
import automatedJobsNoJobsScheduled from '@salesforce/label/c.AUTOMATED_JOBS_NO_SCHEDULED_JOBS';
import automatedJobsScheduledJob from '@salesforce/label/c.AUTOMATED_JOBS_SCHEDULED_JOBS_JOB';
import automatedJobsStartDate from '@salesforce/label/c.AUTOMATED_JOBS_SCHEDULED_JOBS_START_DATE';
import automatedJobsNextRunDate from '@salesforce/label/c.AUTOMATED_JOBS_SCHEDULED_JOBS_NEXT_RUN_DATE';
import automatedJobsAction from '@salesforce/label/c.AUTOMATED_JOBS_SCHEDULED_JOBS_ACTION';
import automatedJobsDelete from '@salesforce/label/c.COMMON_DELETE';
import automatedJobsNotifications from '@salesforce/label/c.AUTOMATED_JOBS_NOTIFICATIONS';
import automatedJobsEmailNotification from '@salesforce/label/c.AUTOMATED_JOBS_EMAIL_NOTIFICATIONS';
import automatedJobsDisableEmails from '@salesforce/label/c.AUTOMATED_JOBS_DISABLE_EMAILS';
import automatedJobsDisableEmailsHelp from '@salesforce/label/c.AUTOMATED_JOBS_DISABLE_EMAILS_HELP';
import automatedJobsManage from '@salesforce/label/c.AUTOMATED_JOBS_MANAGE';
import automatedJobsEnableRecordDeletion from '@salesforce/label/c.AUTOMATED_JOBS_ENABLE_RECORD_DELETION';
import automatedJobsEnableRecordDeletionHelp from '@salesforce/label/c.AUTOMATED_JOBS_ENABLE_RECORD_DELETION_HELP';
import automatedJobsKeepResults from '@salesforce/label/c.AUTOMATED_JOBS_KEEP_RESULTS';
import automatedJobsKeepResultsHelp from '@salesforce/label/c.AUTOMATED_JOBS_KEEP_RESULTS_HELP';
import automatedJobsDeletion from '@salesforce/label/c.AUTOMATED_JOBS_DELETION';
import automatedJobsDeletionHelp from '@salesforce/label/c.AUTOMATED_JOBS_DELETION_HELP';
import automatedJobsDeletionTitle from '@salesforce/label/c.AUTOMATED_JOBS_DELETION_TITLE';
import automatedJobsDeletionText from '@salesforce/label/c.AUTOMATED_JOBS_DELETION_TEXT';
import deleteSourceDocSuccess from '@salesforce/label/c.INF_DELETE_SOURCE_DOC_JOB_SUCCESS';

// Accounting Settings -> Multi Ledger Defaults
import multiLedgerDefaultsTitle from '@salesforce/label/c.MULTI_LEDGER_DEFAULTS_TITLE';
import multiLedgerDefaultsSubtitle from '@salesforce/label/c.COMMON_CONFIG';
import multiLedgerDefaultsSuccess from '@salesforce/label/c.INF_MULTI_LEDGER_DEFAULTS_SUCCESS';
import multiLedgerDefaultsError from '@salesforce/label/c.ERR_MULTI_LEDGER_DEFAULTS_UPDATE';

// Account Settings -> Purge Data
import purgeDataSectionHeader from '@salesforce/label/c.PURGE_DATA_SECTION_HEADER';
import purgeDataButtonText from '@salesforce/label/c.PURGE_DATA_BTN_TEXT';
import purgeDataAP from '@salesforce/label/c.PURGE_DATA_AP';
import purgeDataBilling from '@salesforce/label/c.PURGE_DATA_BILLING';
import purgeDataFinancialReport from '@salesforce/label/c.PURGE_DATA_FINANCIAL_REPORT';
import purgeDataZeroBalance from '@salesforce/label/c.PURGE_DATA_ZERO_BALANCE';
import purgeDataAutomatedJobs from '@salesforce/label/c.PURGE_DATA_AUROMATED_JOBS';
import commonAccountingPeriod from '@salesforce/label/c.COMMON_ACCOUNTING_PERIOD';
import purgeDataBeforeDate from '@salesforce/label/c.PURGE_DATA_BEFORE_DATE';
import purgeDataInventoryBalanceHistory from '@salesforce/label/c.PURGE_DATA_INVENTORY_BALANCE_HISTORY';

// Accounting Settings -> Default GL Accounts
import defaultGlAccountsTitle from '@salesforce/label/c.DEFAULT_GL_ACCOUNTS_TITLE';
import defaultGlAccountsSubtitle from '@salesforce/label/c.COMMON_CONFIG';
import defaultGlAccountsMultiCurrency from '@salesforce/label/c.DEFAULT_GL_ACCOUNTS_MULTI_CURRENCY';
import defaultGlAccountsAccountingClose from '@salesforce/label/c.DEFAULT_GL_ACCOUNTS_ACCOUNTING_CLOSE';
import defaultGlAccountsAccountsReceivable from '@salesforce/label/c.DEFAULT_GL_ACCOUNTS_ACCOUNTS_RECEIVABLE';
import defaultGlAccountsAccountsPayable from '@salesforce/label/c.DEFAULT_GL_ACCOUNTS_ACCOUNTS_PAYABLE';
import defaultGlAccountsProjectAccounting from '@salesforce/label/c.DEFAULT_GL_ACCOUNTS_PROJECT_ACCOUNTING';
import defaultGlAccountsProductCosting from '@salesforce/label/c.COMMON_PRODUCT_COSTING';
import defaultGlAccountsUserDefined from '@salesforce/label/c.DEFAULT_GL_ACCOUNTS_USER_DEFINED';
import defaultGlAccountsAmortizeDetails from '@salesforce/label/c.DEFAULT_GL_ACCOUNTS_AMORTIZE_DETAILS';
import defaultGlAccountsAmortizeRevenue from '@salesforce/label/c.DEFAULT_GL_ACCOUNTS_AMORTIZE_REVENUE';
import defaultGlAccountsAmortizeExpense from '@salesforce/label/c.DEFAULT_GL_ACCOUNTS_AMORTIZE_EXPENSE';
import defaultGlAccountsCashBasisAccounting from '@salesforce/label/c.DEFAULT_GL_ACCOUNTS_CASH_BASIS_ACCOUNTING';
import defaultGlAccountsForPrimaryLedgerModal  from '@salesforce/label/c.INF_DEFAULT_GL_ACCOUNTS_PRIMARY_LEDGER_MODAL';

// Accounting Settings -> Check Print Adjustments
import checkPrintAdjustmentsTitle from '@salesforce/label/c.CHECK_PRINT_ADJUSTMENTS_TITLE';
import checkPrintAdjustmentsSubtitle from '@salesforce/label/c.COMMON_CONFIG';
import checkPrintAdjustmentsTopOffset from '@salesforce/label/c.CHECK_PRINT_ADJUSTMENTS_TOP_OFFEST';
import checkPrintAdjustmentsRightLeftOffset from '@salesforce/label/c.CHECK_PRINT_ADJUSTMENTS_RIGHT_LEFT_OFFSET';

// Account Settings -> Post Settings
import postSettingsTitle from '@salesforce/label/c.POST_SETTINGS_TITLE';
import postSettingsAutoSubTitle from '@salesforce/label/c.POST_SETTINGS_AUTO_SUB_TITLE';
import postSettingsSubtitle from '@salesforce/label/c.COMMON_AUTOMATIONS';
import postSettingsAuto from '@salesforce/label/c.POST_SETTINGS_AUTO';
import postSettingsBillable from '@salesforce/label/c.POST_SETTINGS_BILLABLE';
import postSettingsAutoOffMsg from '@salesforce/label/c.INF_POST_SETTINGS_AUTO_OFF_MSG';
import postSettingsAutoOffMsgExt from '@salesforce/label/c.INF_POST_SETTINGS_AUTO_OFF_MSG_EXT';
import postSettingsAutoOnMsg from '@salesforce/label/c.INF_POST_SETTINGS_AUTO_ON_MSG';
import postSettingsAutoOnMsgExt from '@salesforce/label/c.INF_POST_SETTINGS_AUTO_ON_MSG_EXT';

// Accounting Settings -> Default Ledgers
import defaultLedgerTitle from '@salesforce/label/c.DEFAULT_LEDGER_TITLE';
import defaultLedgerSubtitle from '@salesforce/label/c.COMMON_CONFIG';

// Account Settings -> Enablements
import enablementsTitle from '@salesforce/label/c.ENABLEMENTS_TITLE';
import enablementsSubtitle from '@salesforce/label/c.COMMON_CONFIG';
import enablementsMultiCurrency from '@salesforce/label/c.ENABLEMENTS_MULTI_CURRENCY';
import enablementsAgingHistory from '@salesforce/label/c.ENABLEMENTS_AGING_HISTORY';
import enablementsDefaultBillingDate from '@salesforce/label/c.ENABLEMENTS_DEFAULT_BILLING_DATE';
import enablementsCreditMemoDefault from '@salesforce/label/c.ENABLEMENTS_CREDIT_MEMO_DEFAULT';
import enablementsCreditMemoLabel from '@salesforce/label/c.INF_ENABLEMENTS_CREDIT_MEMO_LABEL';
import enablementsProductCosting from '@salesforce/label/c.COMMON_PRODUCT_COSTING';
import enablementsTimeCard from '@salesforce/label/c.ENABLEMENTS_TIME_CARD';
import enablementsCashFlow from '@salesforce/label/c.ENABLEMENTS_CASH_FLOW';
import enablementsModal from '@salesforce/label/c.INF_ENABLEMENTS_MODAL';
import enablementsCashDisbursementSourceLabel from '@salesforce/label/c.ENABLEMENTS_CASH_DISBURSEMENT_SOURCE_Header';
import enablementsCashDisbursementSourceHelpText from '@salesforce/label/c.ENABLEMENTS_CASH_DISBURSEMENT_SOURCE_HELP_TEXT';
import enablementsCashDisbursementSource from '@salesforce/label/c.ENABLEMENTS_CASH_DISBURSEMENT_SOURCE';

// Accounting Settings -> Tax Settings
import taxOptionNative from '@salesforce/label/c.TAX_OPTION_NATIVE';
import taxOptionAvatax from '@salesforce/label/c.TAX_OPTION_AVATAX';
import taxOptionAvavat from '@salesforce/label/c.TAX_OPTION_AVAVAT';
import taxTestConnection from '@salesforce/label/c.TAX_TEST_CONNECTION';
import taxValidateAddress from '@salesforce/label/c.TAX_VALIDATE_ADDRESS';
import vatReportingSettings from '@salesforce/label/c.COMMON_VAT_REPORTING_SETTINGS';
import taxCalculationOptionsLabel from '@salesforce/label/c.TAX_CALCULATION_OPTIONS_LABEL';
import taxCalculationOptionsSubLabel from '@salesforce/label/c.TAX_CALCULATION_OPTIONS_SUB_LABEL';
import taxAvalaraCredentialsSectionTitle from '@salesforce/label/c.TAX_AVALARA_CREDENTIALS_SECTION_TITLE';
import taxAvalaraConfigurationSectionTitle from '@salesforce/label/c.TAX_AVALARA_CONFIGURATION_SECTION_TITLE';
import taxAvalaraEndpointSectionTitle from '@salesforce/label/c.TAX_AVALARA_ENDPOINT_SECTION_TITLE';
import taxAvalaraEndpointTitle from '@salesforce/label/c.TAX_AVALARA_ENDPOINT_TITLE';
import taxAvalaraOriginAddressSectionTitle from '@salesforce/label/c.TAX_AVALARA_ORIGIN_ADDRESS_SECTION_TITLE';
import taxAvalaraHelpfulLinksSectionTitle from '@salesforce/label/c.TAX_AVALARA_HELPFUL_LINKS_SECTION_TITLE';
import taxAdminConsoleProductionLinkLabel from '@salesforce/label/c.TAX_ADMIN_CONSOLE_PRODUCTION_LINK_LABEL';
import taxAvalaraHelpCenterLinkLabel from '@salesforce/label/c.TAX_AVALARA_HELP_CENTER_LINK_LABEL';
import taxAvalaraCommunityLinkLabel from '@salesforce/label/c.TAX_AVALARA_COMMUNITY_LINK_LABEL';
import taxAvalaraVATCredentialsSectionTitle from '@salesforce/label/c.TAX_AVALARA_VAT_CREDENTIALS_SECTION_TITLE';
import taxAvalaraVATEndpointSectionTitle from '@salesforce/label/c.TAX_AVALARA_VAT_ENDPOINT_SECTION_TITLE';
import taxAvalaraVATEndpointTitle from '@salesforce/label/c.TAX_AVALARA_VAT_ENDPOINT_TITLE';
import taxAvalaraVATLedgerConfigurationSectionTitle from '@salesforce/label/c.TAX_AVALARA_VAT_LEDGER_CONFIGURATION_SECTION_TITLE';
import taxAvalaraVATReportingHelpfulLinksSectionTitle from '@salesforce/label/c.TAX_AVALARA_VAT_REPORTING_HELPFUL_LINKS_SECTION_TITLE';
import taxAvalaraVATReportingSupportLinkLabel from '@salesforce/label/c.TAX_AVALARA_VAT_REPORTING_SUPPORT_LINK_LABEL';
import taxAvalaraVATReportingHelpCenterLinkLabel from '@salesforce/label/c.TAX_AVALARA_VAT_REPORTING_HELP_CENTER_LINK_LABEL';
import taxAvalaraVATReportingInstallationGuideLinkLabel from '@salesforce/label/c.TAX_AVALARA_VAT_REPORTING_INSTALLATION_GUIDE_LINK_LABEL';

// Accounting Settings -> Tax Settings -> Address Validator
import addressValidatorTitle from '@salesforce/label/c.ADDRESS_VALIDATOR_TITLE';
import addressValidatorValidationStatus from '@salesforce/label/c.ADDRESS_VALIDATOR_VALIDATION_STATUS';
import addressValidatorOriginAddress from '@salesforce/label/c.ADDRESS_VALIDATOR_ORIGIN_ADDRESS';
import addressValidatorValidatedAddress from '@salesforce/label/c.ADDRESS_VALIDATOR_VALIDATED_ADDRESS';
import addressValidatorValidateBtn from '@salesforce/label/c.ADDRESS_VALIDATOR_VALIDATE_BTN';
import addressValidatorReplaceAddressBtn from '@salesforce/label/c.ADDRESS_VALIDATOR_REPLACE_ADDRESS_BTN';
import avalaraLicenseDropboxHelpText from '@salesforce/label/c.AVALARA_LICENSE_DROPBOX_HELP_TEXT';
import avalaraLicenseDoesNotExistMessage from '@salesforce/label/c.AVALARA_LICENSE_DOESNOT_EXIST_MESSAGE';

// Accounting Settings -> Stripe Settings
import stripeSettingsSubtitle from '@salesforce/label/c.COMMON_UTILITIES';
import paymentSettingsSuccess from '@salesforce/label/c.PAYMENT_SETTINGS_SUCCESS';
import stripeSettingsDefPaymentProcessor from '@salesforce/label/c.STRIPE_SETTINGS_DEF_PAYMENT_PROCESSOR';
import stripeSettingsConnectedAccounts from '@salesforce/label/c.STRIPE_SETTINGS_CONNECTED_ACCOUNTS';
import stripeSettingsPaymentLinkConfig from '@salesforce/label/c.STRIPE_SETTINGS_PAYMENT_LINK_CONFIG';
import stripeSettingsConnectButton from '@salesforce/label/c.STRIPE_SETTINGS_CONNECT_BUTTON';
import stripeSettingsConfigureButton from '@salesforce/label/c.STRIPE_SETTINGS_CONFIGURE_BUTTON';
import stripeSettingsReconfigureButton from '@salesforce/label/c.STRIPE_SETTINGS_RECONFIGURE_BUTTON';
import stripeSettingsAuthError from '@salesforce/label/c.ERR_STRIPE_SETTINGS_AUTH';
import stripeSettingsPaymentLinkError from '@salesforce/label/c.ERR_STRIPE_SETTINGS_PAYMENTLINK';
import stripeSettingsMoved from '@salesforce/label/c.INFO_STRIPE_SETTINGS_MOVED';

//Accounting Settings -> Payment Settings
import paymentSettingsAPLabel from '@salesforce/label/c.PAYMENT_SETTINGS_AP_LABEL';
import paymentSettingsARLabel from '@salesforce/label/c.PAYMENT_SETTINGS_AR_LABEL';
import paymentSettingsDefaultLedgerLabel from '@salesforce/label/c.PAYMENT_SETTINGS_DEFAULT_LEDGER';
import paymentSettingsCDStatusSettingHeader from '@salesforce/label/c.PAYMENT_SETTINGS_CD_STATUS_FOR_PP_HEADER';
import paymentSettingsCDStatusSettingSubHeader from '@salesforce/label/c.PAYMENT_SETTINGS_CD_STATUS_FOR_PP_SUB_HEADER';

// Accounting Home
import accountingHomeNoErpError from '@salesforce/label/c.ERR_ACCOUNTING_HOME_NO_ERP';
import accountingHomeMaster from '@salesforce/label/c.ACCOUNTING_HOME_MASTER';
import accountingHomeLedger from '@salesforce/label/c.COMMON_LEDGER';
import accountingHomeSetup from '@salesforce/label/c.ACCOUNTING_HOME_SETUP';
import accountingHomeNoAvaTax from '@salesforce/label/c.ERR_ACCOUNTING_HOME_NO_AVATAX';
import accountingHomeTaxExceptionReport from '@salesforce/label/c.ACCOUNTING_HOME_TAX_EXCEPTION_REPORT';
import accountingHomeReportSettings from '@salesforce/label/c.ACCOUNTING_HOME_REPORT_SETTINGS';
import accountingHomeConsolidations from '@salesforce/label/c.ACCOUNTING_HOME_CONSOLIDATIONS';
import accountingHomeRunConsolidations from '@salesforce/label/c.ACCOUNTING_HOME_RUN_CONSOLIDATIONS';
import accountingHomeSetupConsolidations from '@salesforce/label/c.ACCOUNTING_HOME_SETUP_CONSOLIDATIONS';
import accountingHomeManagementReports from '@salesforce/label/c.ACCOUNTING_HOME_MANAGEMENT_REPORTS';
import accountingHomeDashboards from '@salesforce/label/c.ACCOUNTING_HOME_DASHBOARDS';
import accountingHomeCustomReports from '@salesforce/label/c.ACCOUNTING_HOME_CUSTOM_REPORTS';
import accountingHomeCustom from '@salesforce/label/c.ACCOUNTING_HOME_CUSTOM';
import accountingHomeStandard from '@salesforce/label/c.ACCOUNTING_HOME_STANDARD';
import accountingHomeRunReports from '@salesforce/label/c.ACCOUNTING_HOME_RUN_REPORTS';
import accountingHomeSerialNumSearch from '@salesforce/label/c.ACCOUNTING_HOME_SERIAL_NUM_SEARCH';
import accountingHomeInventoryQuantityAvailable from '@salesforce/label/c.ACCOUNTING_HOME_INVENTORY_QUANTITY_AVAILABLE';
import accountingHomeProductPrices from '@salesforce/label/c.ACCOUNTING_HOME_PRODUCT_PRICES';
import accountingHomeWarehouses from '@salesforce/label/c.ACCOUNTING_HOME_WAREHOUSES';
import accountingHomeWorkOrders from '@salesforce/label/c.ACCOUNTING_HOME_WORK_ORDERS';
import accountingHomeNoErpFslError from '@salesforce/label/c.ERR_ACCOUNTING_HOME_NO_ERP_FSL';
import accountingHomePurchaseOrders from '@salesforce/label/c.ACCOUNTING_HOME_PURCHASE_ORDERS';
import accountingHomeSalesOrders from '@salesforce/label/c.ACCOUNTING_HOME_SALES_ORDERS';
import accountingHomeOrders from '@salesforce/label/c.ACCOUNTING_HOME_ORDERS';
import commonPayrollImport from '@salesforce/label/c.COMMON_PAYROLL_IMPORT';
import accountingHomeBudgetEntries from '@salesforce/label/c.ACCOUNTING_HOME_BUDGET_ENTRIES';
import accountingHomeBDC from '@salesforce/label/c.ACCOUNTING_HOME_BDC';
import accountingHomeBanking from '@salesforce/label/c.ACCOUNTING_HOME_BANKING';
import accountingHomeExpenses from '@salesforce/label/c.ACCOUNTING_HOME_EXPENSES';
import accountingHomeRevenues from '@salesforce/label/c.ACCOUNTING_HOME_REVENUES';
import accountingHomeCreateEntries from '@salesforce/label/c.ACCOUNTING_HOME_CREATE_ENTRIES';
import accountingHomePaymentProcessor from '@salesforce/label/c.COMMON_PAYMENT_PROCESSOR';
import accountingHomeReleaseTitleWinter from '@salesforce/label/c.ACCOUNTING_HOME_RELEASE_TITLE_WINTER';
import accountingHomeReleaseTitleSpring from '@salesforce/label/c.ACCOUNTING_HOME_RELEASE_TITLE_SPRING';
import accountingHomeReleaseTitleSummer from '@salesforce/label/c.ACCOUNTING_HOME_RELEASE_TITLE_SUMMER';
import accountingHomeReleaseSubTitlePreview from '@salesforce/label/c.ACCOUNTING_HOME_RELEASE_SUB_TITLE_PREVIEW';
import accountingHomeReleaseFeatureSoftClose from '@salesforce/label/c.ACCOUNTING_HOME_RELEASE_FEATURE_SOFT_CLOSE';
import accountingHomeReleaseFeatureAutoPost from '@salesforce/label/c.ACCOUNTING_HOME_RELEASE_FEATURE_AUTO_POST';
import accountingHomeReleaseFeatureGLAcctDef from '@salesforce/label/c.ACCOUNTING_HOME_RELEASE_FEATURE_GL_ACCT_DEF';
import accountingHomeReleaseFeatureARAutomation from '@salesforce/label/c.ACCOUNTING_HOME_RELEASE_FEATURE_AR_AUTOMATION';
import ACCOUNTING_SEED_HUB from '@salesforce/label/c.ACCOUNTING_SEED_HUB';

import stdReportLedgerInquiry from '@salesforce/label/c.STD_REPORT_LEDGER_INQUIRY';
import stdReportCashFlow from '@salesforce/label/c.STD_REPORT_CASH_FLOW';
import stdReportTrialBalance from '@salesforce/label/c.STD_REPORT_TRIAL_BALANCE';
import stdReportBalanceSheet from '@salesforce/label/c.STD_REPORT_BALANCE_SHEET';
import stdReportPLVsBudget from '@salesforce/label/c.STD_REPORT_PL_VS_BUDGET';
import stdReportProfitLoss from '@salesforce/label/c.STD_REPORT_PROFIT_LOSS';
import reportClonedSuccessfully from '@salesforce/label/c.REPORT_CLONED_SUCCESSFULLY';
import reportGenerationInProgress from '@salesforce/label/c.REPORT_GENERATION_IN_PROGRESS';
import reportGenerationCompleteWithLink from '@salesforce/label/c.REPORT_GENERATION_COMPLETE_WITH_LINK';
import reportOpeningBalanceNote from '@salesforce/label/c.REPORT_OPENING_BALANCE_NOTE';
import reportCurrentYearEarningsNote from '@salesforce/label/c.REPORT_CURRENT_YEAR_EARNINGS_NOTE';
import frCurrencyValueMissing from '@salesforce/label/c.FR_CURRENCY_VALUE_MISSING';

import refundCreateTitle from '@salesforce/label/c.REFUND_CREATE_TITLE';
import refundCreateBillTotalHelp from '@salesforce/label/c.REFUND_CREATE_BILL_TOTAL_HELP';
import refundCreateBillRcvAmtHelp from '@salesforce/label/c.REFUND_CREATE_BILL_RCV_AMT_HELP';
import refundCreateBillBalanceHelp from '@salesforce/label/c.REFUND_CREATE_BILL_BALANCE_HELP';
import refundCreateNotPostedError from '@salesforce/label/c.ERR_REFUND_CREATE_NOT_POSTED';
import refundCreateNotInvoiceError from '@salesforce/label/c.ERR_REFUND_CREATE_NOT_INVOICE';

import creditMemoApplyDate from '@salesforce/label/c.CREDIT_MEMO_APPLY_DATE';
import creditMemoComment from '@salesforce/label/c.CREDIT_MEMO_COMMENT';
import creditMemoSumOfLines from '@salesforce/label/c.CREDIT_MEMO_LINES_SUM';
import creditMemoTotalCreditLines from '@salesforce/label/c.CREDIT_MEMO_TOTAL_CREDIT';
import creditMemoApplyDateHint from '@salesforce/label/c.INF_CREDIT_MEMO_APPLY_DATE';
import creditMemoCommentHint from '@salesforce/label/c.INF_CREDIT_MEMO_COMMENT';
import creditMemoSumOfLinesHint from '@salesforce/label/c.INF_CREDIT_MEMO_LINES_SUM';
import creditMemoTotalCreditLinesHint from '@salesforce/label/c.INF_CREDIT_MEMO_TOTAL_CREDIT';
import commonCreditMemo from '@salesforce/label/c.COMMON_CREDIT_MEMO';
import creditMemoLinesTitle from '@salesforce/label/c.CREDIT_MEMO_LINES_TITLE';
import creditMemoSumGreaterTotal from '@salesforce/label/c.ERR_CREDIT_SUM_GREATER_TOTAL';
import creditMemoZeroLinesSum from '@salesforce/label/c.ERR_CREDIT_ZERO_LINES_SUM';
import creditMemoCreateApplyInformation from '@salesforce/label/c.INF_CREDIT_MEMO_CREATE_APPLY_INFORMATION';
import billingMustBeCreditMemo from '@salesforce/label/c.ERR_BILLING_MUST_BE_CREDIT_MEMO';

import cashReceiptRefundTitle from '@salesforce/label/c.CASH_RECEIPT_REFUND_TITLE';
import cashReceiptRefundDateTitle from '@salesforce/label/c.CASH_RECEIPT_REFUND_DATE_TITLE';
import cashReceiptRefundAmountTitle from '@salesforce/label/c.CASH_RECEIPT_REFUND_AMOUNT_TITLE';
import cashReceiptRefundAmountHelp from '@salesforce/label/c.INF_CASH_RECEIPT_REFUND_AMOUNT';
import cashReceiptRefundDateHelp from '@salesforce/label/c.INF_CASH_RECEIPT_REFUND_DATE';
import cashReceiptRefundReferenceMessage from '@salesforce/label/c.CASH_RECEIPT_REFUND_REFERENCE_MESSAGE';
import cashReceiptRefundConfirmationMessage from '@salesforce/label/c.CASH_RECEIPT_REFUND_CONFIRMATION_MESSAGE';
import cashReceiptRefundAccessError from '@salesforce/label/c.ERR_NO_CASH_RECEIPT_REFUND_ACCESS';
import refundAmountExceededBalanceError from '@salesforce/label/c.REFUND_AMOUNT_EXCEEDED_BALANCE_ERROR';
import cashReceiptRefundAmountNegativeError from '@salesforce/label/c.CASH_RECEIPT_REFUND_AMOUNT_NEGATIVE_ERROR';
// Bank Direct Connect
import GLAM_UPDATE_DUPLICACY_ERROR	 from '@salesforce/label/c.GLAM_UPDATE_DUPLICACY_ERROR';
import MANAGE_PROVIDER_WARNING from '@salesforce/label/c.MANAGE_PROVIDER_WARNING';
import REGISTER_SUCCESS_MSG from '@salesforce/label/c.REGISTER_SUCCESS_MSG';
import DEREGISTER_SUCCESS_MSG from '@salesforce/label/c.DEREGISTER_SUCCESS_MSG';
import bdcConfirmFIDelete	 from '@salesforce/label/c.BDC_CONFIRM_FI_DELETE';
import bdcConfirmCancel	 from '@salesforce/label/c.BDC_CONFIRM_CANCEL';
import bdcCashInMatchingSetting from '@salesforce/label/c.BDC_CASH_IN_MATCHING_SETTING';
import bdcDeregisterWarning1 from '@salesforce/label/c.INF_BDC_DEREGISTER_MESSAGE_1';
import bdcDeregisterWarning2 from '@salesforce/label/c.INF_BDC_DEREGISTER_MESSAGE_2';

import recurringDeepCloneMessage from '@salesforce/label/c.INF_RECURRING_DEEP_CLONE_MESSAGE';
import importPayrollUniqueJournalEntryNameInfo from '@salesforce/label/c.INF_IMPORT_PAYROLL_UNIQUE_JOURNAL_ENTRY_NAME';
import importPayrollTransactionDateInfo from '@salesforce/label/c.INF_IMPORT_PAYROLL_TRANSACTION_DATE_FORMAT';
import importPayrollGlAccountInfo from '@salesforce/label/c.INF_IMPORT_PAYROLL_EXISTING_GL_ACCOUNT';
import importPayrollPositiveDebitInfo from '@salesforce/label/c.INF_IMPORT_PAYROLL_POSITIVE_DEBIT_AMOUNT';
import importPayrollPositiveCreditInfo from '@salesforce/label/c.INF_IMPORT_PAYROLL_POSITIVE_CREDIT_AMOUNT';
import importPayrollFileTitle from '@salesforce/label/c.IMPORT_PAYROLL_FILE_TITLE';
import importPayrollFileRequirementMessageTitle from '@salesforce/label/c.IMPORT_PAYROLL_FILE_REQUIREMENT_MESSAGE_TITLE';
import importPayrollFileTypeMismatchMessage from '@salesforce/label/c.IMPORT_PAYROLL_FILE_TYPE_MISMATCH_MESSAGE';
import importPayrollDataTableSearchTitle from '@salesforce/label/c.IMPORT_PAYROLL_DATA_TABLE_SEARCH_TITLE';
import importPayrollFileRecordCreatedMessage from '@salesforce/label/c.IMPORT_PAYROLL_FILE_RECORD_CREATED_MESSAGE';
import importPayrollFileRecordAlreadyExistsMessage from '@salesforce/label/c.IMPORT_PAYROLL_FILE_RECORD_ALREADY_EXISTS_MESSAGE';
import importPayrollCommonErrorMessageHeading from '@salesforce/label/c.ERR_IMPORT_PAYROLL_COMMON_ERROR_MESSAGE_HEADING';
import importPayrollCommonErrorMessageRequiredColumns from '@salesforce/label/c.ERR_IMPORT_PAYROLL_COMMON_ERROR_MESSAGE_REQUIRED_COLUMNS';
import importPayrollCommonErrorMessageDuplicates from '@salesforce/label/c.ERR_IMPORT_PAYROLL_COMMON_ERROR_MESSAGE_DUPLICATES';
import importPayrollCommonErrorMessageOptionalColumns from '@salesforce/label/c.ERR_IMPORT_PAYROLL_COMMON_ERROR_MESSAGE_OPTIONAL_COLUMNS';
import importPayrollCommonErrorMessageThousandRows from '@salesforce/label/c.ERR_IMPORT_PAYROLL_COMMON_ERROR_MESSAGE_THOUSAND_ROWS';
import BDCRefCredentials from '@salesforce/label/c.BDCRefreshCredentials';
import GLAMConnectionIssue from '@salesforce/label/c.GLAMConnectionIssue';
import UNSUPPORTED_CURRENCY_FOR_BANK from '@salesforce/label/c.UNSUPPORTED_CURRENCY_FOR_BANK';

import DELARCInfo11 from '@salesforce/label/c.INFO_DEL_SRC_DOCS_1_1';
import DELARCInfo12 from '@salesforce/label/c.INFO_DEL_SRC_DOCS_1_2';
import DELARCInfo13 from '@salesforce/label/c.INFO_DEL_SRC_DOCS_1_3';
import DELARCInfo2 from '@salesforce/label/c.INFO_DEL_SRC_DOCS_2';
import DELARCInfo3 from '@salesforce/label/c.INFO_DEL_SRC_DOCS_3';
import DELARCInfo4 from '@salesforce/label/c.INFO_DEL_SRC_DOCS_4';
import DELARCInfo5 from '@salesforce/label/c.INFO_DEL_SRC_DOCS_5';
import DELARCInfo6 from '@salesforce/label/c.INFO_DEL_SRC_DOCS_6';

import DELAPDsManual1 from '@salesforce/label/c.INFO_DEL_APDs_MANUAL_1';
import DELAPDsManual2 from '@salesforce/label/c.INFO_DEL_APDs_MANUAL_2';
import DELAPDsManual21 from '@salesforce/label/c.INFO_DEL_APDs_MANUAL_2_1';
import DELAPDsManual22 from '@salesforce/label/c.INFO_DEL_APDs_MANUAL_2_2';
import DELAPDsManual23 from '@salesforce/label/c.INFO_DEL_APDs_MANUAL_2_3';
import DELAPDsManual24 from '@salesforce/label/c.INFO_DEL_APDs_MANUAL_2_4';
import DELAPDsPayable1 from '@salesforce/label/c.INFO_DEL_APDs_PAYABLE_1';
import DELAPDsPayable11 from '@salesforce/label/c.INFO_DEL_APDs_PAYABLE_1_1';
import DELAPDsPayable12 from '@salesforce/label/c.INFO_DEL_APDs_PAYABLE_1_2';
import DELAPDsPayable2 from '@salesforce/label/c.INFO_DEL_APDs_PAYABLE_2';
import DELAPDsPayable21 from '@salesforce/label/c.INFO_DEL_APDs_PAYABLE_2_1';
import DELAPDsPayable22 from '@salesforce/label/c.INFO_DEL_APDs_PAYABLE_2_2';
import DELAPDsPayable23 from '@salesforce/label/c.INFO_DEL_APDs_PAYABLE_2_3';
import DELAPDsPayable24 from '@salesforce/label/c.INFO_DEL_APDs_PAYABLE_2_4';
import DELAPDsInfoNoAPD from '@salesforce/label/c.INF_NO_APD_DELETE';
import DELAPDsErrorNoAccess from '@salesforce/label/c.ERR_DELAPDs_NO_ACCESS';

// Financial Reports -> Report Settings -> Default Report Display
import finRepSettingsExpandRepRowsHelp from '@salesforce/label/c.FIN_REPORT_SETTINGS_EXPAND_REPORT_ROWS_HELP';

// ERR labels
import payTypeHelp from '@salesforce/label/c.ERR_PAYMENT_TYPE_HELPTEXT';
import payProcHelp from '@salesforce/label/c.ERR_PAYMENT_PROCESSOR_HELPTEXT';
import payMethodHelp from '@salesforce/label/c.ERR_PAYMENT_METHOD_HELPTEXT';
import earlyPayDiscountHelp from '@salesforce/label/c.ERR_EARLY_PAYMENT_DIS';
import discountAmountHelp from '@salesforce/label/c.ERR_DISCOUNT_AMOUNT_HELPTEXT';
import amountHelp from '@salesforce/label/c.ERR_AMOUNT_HELP';
import balanceOwedHelp from '@salesforce/label/c.ERR_BALANCE_OWED_HELP';
import discountDueDateHelp from '@salesforce/label/c.ERR_DISCOUNT_DUE_DATE_HELP';
import paymentType from '@salesforce/label/c.ERR_PAYMENT_TYPE';
import paymentProcessor from '@salesforce/label/c.COMMON_PAYMENT_PROCESSOR';
import paymentMethod from '@salesforce/label/c.COMMON_PAYMENT_METHOD';
import date from '@salesforce/label/c.COMMON_DATE';
import paymentReference from '@salesforce/label/c.COMMON_PAYMENT_REFERENCE';
import discountAmount from '@salesforce/label/c.COMMON_DISCOUNT_ADJUSTMENT_AMT';
import earlyPayment from '@salesforce/label/c.INF_EARLY_PAYMENT_DISCOUNT_AMT';
import billingTotal from '@salesforce/label/c.ERR_BILLING_TOTAL';
import currency from '@salesforce/label/c.COMMON_CURRENCY';
import ledger from '@salesforce/label/c.COMMON_LEDGER';
import bankAccount from '@salesforce/label/c.COMMON_BANK_ACCOUNT';
import balanceOwe from '@salesforce/label/c.ERR_BALANCE_OWED';
import receivedAmount from '@salesforce/label/c.COMMON_RECEIVED_AMOUNT';
import adjustmentGl from '@salesforce/label/c.COMMON_ADJUSTMENT_GL_ACCOUNT';
import discountDueDate from '@salesforce/label/c.INF_DISCOUNT_DUE_DATE';
import paymentInfo from '@salesforce/label/c.COMMON_PAYMENT_INFORMATION';
import accountingInfo from '@salesforce/label/c.COMMON_ACCOUNTING_INFORMATION';
//ERR Payments
import connectPP from '@salesforce/label/c.ERR_PAYMENTS_CONNECT_PAYMENT_PROCESSOR';
import pleaseConfirm from '@salesforce/label/c.ERR_PAYMENTS_PLEASE_CONFIRM';
import connectType from '@salesforce/label/c.ERR_PAYMENTS_CONNECT_TO_TYPE';
import connectMode from '@salesforce/label/c.ERR_PAYMENTS_CONNECT_MODE';
import connectNote from '@salesforce/label/c.ERR_PAYMENTS_CONNECT_NOTE';
import live from '@salesforce/label/c.ERR_PAYMENTS_CONNECT_LIVE';
import test from '@salesforce/label/c.ERR_PAYMENTS_CONNECT_TEST';
import commonConnect from '@salesforce/label/c.ERR_PAYMENTS_COMMON_CONNECT';
import connectInThe from '@salesforce/label/c.ERR_PAYMENTS_CONNECT_IN_THE';
import testModeWarningMessage from '@salesforce/label/c.ERR_PAYMENTS_TEST_MODE_WARNING_MESSAGE';

//ON-OFF amortization labels
import accountingPeriodCantEmpty from '@salesforce/label/c.ERR_NUMBER_OF_ACCOUNTING_PERIOD_CANNOT_BE_EMPTY';
import endDateCantEmpty from '@salesforce/label/c.ERR_END_DATE_CANNOT_BE_EMPTY';
import AMORT_SETTINGS from '@salesforce/label/c.AMORT_SETTINGS';

//cardknox labels
import paymentSettings from '@salesforce/label/c.AR_PAYMENT_SETTINGS';

//ONE-OFF Bank transaction labels
import refresh from '@salesforce/label/c.XCOMMON_REFRESH';
import commonYes from '@salesforce/label/c.COMMON_YES';
import commonNo from '@salesforce/label/c.COMMON_NO';
import bdcModalHeader from '@salesforce/label/c.BDC_MODAL_HEADER';
import bdcModalBody from '@salesforce/label/c.BDC_MODAL_BODY';
import enterValidWholeNumber from '@salesforce/label/c.ERR_ENTER_VALID_WHOLE_NUMBER';

//misc labels
import cashFlowStatementError from '@salesforce/label/c.INF_CASH_FLOW_NOT_ENABLED';

//Amortization Wizard
import amortizationWizardTitle from '@salesforce/label/c.AMORTIZATION_WIZARD_TITLE';
import depreciateWizardTitle from '@salesforce/label/c.DEPRECIATE_WIZARD_TITLE';
import amortizationWizardInfoMsg from '@salesforce/label/c.AMORTIZATION_WIZARD_INFO_MSG';
import depreciateWizardInfoMsg from '@salesforce/label/c.DEPRECIATE_WIZARD_INFO_MSG';
import amortizationWizardAmountGreaterWarningMsg from '@salesforce/label/c.AMORTIZATION_WIZARD_AMOUNT_GREATER_WARNING_MSG';
import depreciateWizardAmountGreaterWarningMsg from '@salesforce/label/c.DEPRECIATE_WIZARD_AMOUNT_GREATER_WARNING_MSG';
import amortizationWizardSelectMethod from '@salesforce/label/c.AMORTIZATION_WIZARD_SELECT_METHOD';
import depreciateWizardSelectMethod from '@salesforce/label/c.DEPRECIATE_WIZARD_SELECT_METHOD';
import amortizationWizardAmountHelpText from '@salesforce/label/c.AMORTIZATION_WIZARD_AMOUNT_HELP_TEXT';
import amortizationWizardPeriodHelpText from '@salesforce/label/c.AMORTIZATION_WIZARD_PERIOD_HELP_TEXT';
import amortizationWizardStartDateHelpText from '@salesforce/label/c.AMORTIZATION_WIZARD_START_DATE_HELP_TEXT';
import amortizationWizardEndDateHelpText from '@salesforce/label/c.AMORTIZATION_WIZARD_END_DATE_HELP_TEXT';
import amortizationWizardSuccessCreatePostMsg from '@salesforce/label/c.AMORTIZATION_WIZARD_SUCCESS_CREATE_POST_MSG';
import amortizationWizardSuccessCreateMsg from '@salesforce/label/c.AMORTIZATION_WIZARD_SUCCESS_CREATE_MSG';
import depreciateWizardAmountHelpText from '@salesforce/label/c.DEPRECIATE_WIZARD_AMOUNT_HELP_TEXT';
import depreciateWizardPeriodHelpText from '@salesforce/label/c.DEPRECIATE_WIZARD_PERIOD_HELP_TEXT';
import depreciateWizardStartDateHelpText from '@salesforce/label/c.DEPRECIATE_WIZARD_START_DATE_HELP_TEXT';
import depreciateWizardEndDateHelpText from '@salesforce/label/c.DEPRECIATE_WIZARD_END_DATE_HELP_TEXT';
import depreciateWizardSuccessCreatePostMsg from '@salesforce/label/c.DEPRECIATE_WIZARD_SUCCESS_CREATE_POST_MSG';
import depreciateWizardSuccessCreateMsg from '@salesforce/label/c.DEPRECIATE_WIZARD_SUCCESS_CREATE_MSG';
import depreciateWizardNumberPeriodOver from '@salesforce/label/c.DEPRECIATE_WIZARD_NUMBER_PERIOD_OVER_60';

//constants.js labels
import COMMON_TRANSACTIONAL from '@salesforce/label/c.COMMON_TRANSACTIONAL';
import COMMON_BUDGET from '@salesforce/label/c.COMMON_BUDGET';
import COMMON_CONSOLIDATIONS_TRANSACTIONAL from '@salesforce/label/c.COMMON_CONSOLIDATIONS_TRANSACTIONAL';
import COMMON_CONSOLIDATIONS_BUDGET from '@salesforce/label/c.COMMON_CONSOLIDATIONS_BUDGET';
import COMMON_ELIMINATIONS_TRANSACTIONAL from '@salesforce/label/c.COMMON_ELIMINATIONS_TRANSACTIONAL';
import COMMON_ELIMINATIONS_BUDGET from '@salesforce/label/c.COMMON_ELIMINATIONS_BUDGET';
import COMMON_OPEN_IN_PROGRESS from '@salesforce/label/c.COMMON_OPEN_IN_PROGRESS';
import COMMON_CLOSE_IN_PROGRESS from '@salesforce/label/c.COMMON_CLOSE_IN_PROGRESS';
import COMMON_OPEN from '@salesforce/label/c.COMMON_OPEN';
import COMMON_CLOSED from '@salesforce/label/c.COMMON_CLOSED';
import COMMON_ARCHIVED from '@salesforce/label/c.COMMON_ARCHIVED';
import COMMON_ARCHIVED_IN_PROGRESS from '@salesforce/label/c.COMMON_ARCHIVED_IN_PROGRESS';
import COMMON_AVERAGE_COST from '@salesforce/label/c.COMMON_AVERAGE_COST';
import COMMON_STANDARD_COST from '@salesforce/label/c.COMMON_STANDARD_COST';
import COMMON_AVATAX from '@salesforce/label/c.COMMON_AVATAX';
import TAX_OPTION_NATIVE from '@salesforce/label/c.TAX_OPTION_NATIVE';
import STD_REPORT_CASH_FLOW from '@salesforce/label/c.STD_REPORT_CASH_FLOW';
import COMMON_ACTIVITY_STMT from '@salesforce/label/c.COMMON_ACTIVITY_STMT';
import INF_OUTSTANDING_STATEMENT from '@salesforce/label/c.INF_OUTSTANDING_STATEMENT';
import COMMON_PACKING_SLIP from '@salesforce/label/c.COMMON_PACKING_SLIP';
import COMMON_PURCHASE_ORDER from '@salesforce/label/c.COMMON_PURCHASE_ORDER';
import COMMON_ACCRUAL_CASH from '@salesforce/label/c.COMMON_ACCRUAL_CASH';
import COMMON_ACCRUAL from '@salesforce/label/c.COMMON_ACCRUAL';
import COMMON_CASH from '@salesforce/label/c.COMMON_CASH';

import commonMenu from '@salesforce/label/c.COMMON_MENU';
import commonInfo from '@salesforce/label/c.INF_COMMON_TOAST_INFO_TITLE';
import commonPay from '@salesforce/label/c.COMMON_PAY';
import paymentProcessorsLV from '@salesforce/label/c.INF_PAYMENT_PROCESSORS_LISTVIEW';

const labels = {
    formatLabel: function (label, args) {
        return label.replace(/{(\d+)}/gm, (match, index) => {
            return args[index] === undefined ? '' : `${args[index]}`;
        });
    },
    ACCOUNTING_SEED_HUB,
    COMMON_SMALL_RESULTS,
    COMMON_SEARCH,
    COMMON_INFO,
    COMMON_WARNING,
    COMMON_AT,
    accountingHomeReportSettings,
    accountingHomeRunConsolidations,
    accountingHomeSetupConsolidations,
    accountingHomeManagementReports,
    AMORT_SETTINGS,
    ERR_COMMON_GREATER_APPLIED_DATE,
    ERR_COMMON_APPLIED_DATE_OPEN_PERIOD,
    GLAMConnectionIssue,
    UNSUPPORTED_CURRENCY_FOR_BANK,
    BDCRefCredentials,
    REGISTER_SUCCESS_MSG,
    DEREGISTER_SUCCESS_MSG,
    GLAM_UPDATE_DUPLICACY_ERROR,
    MANAGE_PROVIDER_WARNING,
    accountingSetup,
    accountingHomeNoErpError,
    accountingHomeMaster,
    accountingHomeLedger,
    accountingHomeSetup,
    accountingHomeNoAvaTax,
    accountingHomeTaxExceptionReport,
    accountingHomeConsolidations,
    accountingHomeDashboards,
    accountingHomeCustomReports,
    accountingHomeCustom,
    accountingHomeStandard,
    accountingHomeRunReports,
    accountingHomeSerialNumSearch,
    accountingHomeInventoryQuantityAvailable,
    accountingHomeProductPrices,
    accountingHomeWarehouses,
    accountingHomeWorkOrders,
    accountingHomeNoErpFslError,
    accountingHomePurchaseOrders,
    accountingHomeSalesOrders,
    accountingHomeOrders,
    commonPayrollImport,
    accountingHomeBudgetEntries,
    accountingHomeBDC,
    accountingHomeBanking,
    accountingHomeExpenses,
    accountingHomeRevenues,
    accountingHomeCreateEntries,
    accountingHomePaymentProcessor,
    accountingHomeReleaseTitleWinter,
    accountingHomeReleaseTitleSpring,
    accountingHomeReleaseTitleSummer,
    accountingHomeReleaseSubTitlePreview,
    accountingHomeReleaseFeatureSoftClose,
    accountingHomeReleaseFeatureAutoPost,
    accountingHomeReleaseFeatureGLAcctDef,
    accountingHomeReleaseFeatureARAutomation,
    scheduledPost,
    scheduledBankDownload,
    npsp,
    jobScheduledSuccess,
    automatedJobsSelectSchdPostTitle,
    jobRemovedSuccess,
    notificationSettingsSuccess,
    keepResultsError,
    automatedJobsPageHeader,
    automatedJobsAddEdit,
    automatedJobsSelectLabel,
    automatedJobsSelectPlaceholder,
    commonPreferredStartTime,
    automatedJobsNotImeSlotsAvailable,
    automatedJobsSelectedValueError,
    automatedJobsAddButton,
    automatedJobsRun,
    commonHasBeenSuccessfullyDeleted,
    commonHasBeenSuccessfullyUpdated,
    automatedJobsRunNowButton,
    automatedJobsScheduled,
    automatedJobsNoJobsScheduled,
    automatedJobsScheduledJob,
    automatedJobsStartDate,
    automatedJobsNextRunDate,
    automatedJobsAction,
    automatedJobsDelete,
    automatedJobsNotifications,
    automatedJobsEmailNotification,
    automatedJobsDisableEmails,
    automatedJobsDisableEmailsHelp,
    automatedJobsManage,
    automatedJobsEnableRecordDeletion,
    automatedJobsEnableRecordDeletionHelp,
    automatedJobsKeepResults,
    automatedJobsKeepResultsHelp,
    automatedJobsDeletion,
    automatedJobsDeletionHelp,
    automatedJobsDeletionTitle,
    automatedJobsDeletionText,
    checkPrintAdjustmentsTitle,
    checkPrintAdjustmentsSubtitle,
    checkPrintAdjustmentsTopOffset,
    checkPrintAdjustmentsRightLeftOffset,
    COMMON_BILLING,
    COMMON_PAYABLE,
    COMMON_DEFERRED_REVENUE,
    COMMON_DEFERRED_EXPENSE,
    commonAll,
    commonAdd,
    commonAddEditLines,
    commonOn,
    commonOff,
    commonOk,
    commonBack,
    commonCancel,
    commonSave,
    commonSaveNew,
    commonDelete,
    commonSaveSuccess,
    commonToastPageLoadErrorMsg,
    commonToastErrorTitle,
    commonToastSuccessTitle,
    commonUtilities,
    commonConfiguration,
    commonAutomations,
    commonCreateAndApply,
    commonAvailable,
    common1099Information,
    commonNext,
    commonPrevious,
    commonPreviewCalculations,
    commonCreateEntries,
    commonView,
    commonNew,
    commonRefresh,
    commonEdit,
    commonCreate,
    commonConfirm,
    commonRemove,
    commonRun,
    commonClose,
    commonNone,
    commonHelp,
    commonValidated,
    commonSaving,
    commonBilling,
    commonPayable,
    commonAccountingInformation,
    commonPeriods,
    commonAmounts,
    commonNumberAccountingPeriods,
    commonEndDate,
    commonDescription,
    commonApplied,
    commonBalance,
    commonAmortizationEntries,
    commonAPDisbursements,
    commonBillingsBCaps,
    commonCashDisbursements,
    commonCashReceipts,
    commonJournalEntries,
    commonSaveChangesOrRemoveChanges,
    commonPayables,
    commonTimeCards,
    commonPayments,
    commonDeposits,
    commonCharges,
    commonCompleted,
    commonInProgress,
    commonWorking,
    commonAutoClearRunning,
    commonCreditCard,
    commonDifference,
    commonBankReconciliation,
    commonLoading,
    commonPDF,
    commonCSV,
    commonSummary,
    commonFile,
    commonSmallFile,
    commonSmallReport,
    commonBankDeposit,
    commonCloseDialog,
    commonDate,
    commonFilter,
    commonCleared,
    commonType,
    commonPayee,
    commonUncleared,
    commonPayment,
    commonCharge,
    commonInvalidDate,
    commonApply,
    commonJournalEntry,
    commonChangesSaved,
    commonDeposit,
    commonAccount,
    commonGLAccount,
    commonDetails,
    commonProjectTask,
    commonCashFlowCategory,
    commonStatus,
    commonSource,
    commonAdded,
    commonCredit,
    commonDebit,
    commonProject,
    commonImport,
    commonRecordsFound,
    commonCheckNo,
    commonContact,
    commonEmployee,
    commonMatch,
    commonUnsavedChanges,
    commonUnsavedChangesDiscardContinue,
    commonSaveAndComplete,
    commonSaveAndRefresh,
    commonBillingNo,
    commonTotalApplied,
    commonAppliedAmount,
    commonAppliedDate,
    commonCashDisbursement,
    commonPayableAmount,
    commonPayableBalance,
    commonPaymentReference,
    commonCashReceipt,
    commonReceivedAmt,
    commonAdjustmentGLAcct,
    commonThe,
    commonExpandAll,
    commonCollapseAll,
    commonRefreshText,
    commonCurrency,
    commonClick,
    commonName,
    commonProcessing,
    commonSort,
    commonClone,
    commonLine,
    commonExpenseAndMileageLines,
    commonStartingAccountPeriod,
    commonEndingAccountPeriod,
    commonSuppressZeroAmtRows,
    commonReportSubtitle,
    commonReportSubtitleDisplay,
    commonReportRounding,
    commonRunReport,
    commonAggregateBy,
    commonBillingLine,
    commonJournalEntryLine,
    commonPayableLine,
    commonGLVariable,
    commonBudgetLedger,
    commonInquiryResultCount,
    commonOpeningBalance,
    commonInquiryAmount,
    commonYearToDateBalance,
    commonReportResults,
    commonTotalAmount,
    commonRunningBalance,
    commonCreatedBy,
    commonExcel,
    commonFinancialReports,
    commonStartPeriod,
    commonEndPeriod,
    commonPeriod,
    commonSettings,
    commonErrorDuringSave,
    commonFinancialInstitution,
    commonBankGLAcct,
    commonLastRefreshedDate,
    commonToDot,
    commonBankSettings,
    commonSectionTitle,
    commonActions,
    commonCreditMemoDate,
    commonDueDateStart,
    commonDueDateEnd,
    commonAreYouSure,
    commonSelectFile,
    commonSearchBillings,
    commonBillingAmount,
    commonBillingBalance,
    commonHierarchy,
    commonLedgerType,
    commonCurrentBalance,
    commonCreditVendor,
    commonExpenseType,
    commonMileageOrigin,
    commonMileageDestination,
    commonMiles,
    commonIncludeSubType2,
    commonTransactionalLedgerForReport,
    commonIncludeSubType1,
    commonShowAllPeriods,
    commonCustomReports,
    commomRecords,
    commonNoneOption,
    commonForm1099Type,
    commonForm1099Box,
    commonAccountingHome,
    commonSaveSuccessful,
    commonBillable,
    commonOvertime,
    commonVariableOne,
    commonVariableTwo,
    commonTotal,
    commonLoadingText,
    commonKnowledgeBase,
    commonAmount,
    commonSuccess,
    commonErrorText,
    commonPosted,
    commonApproved,
    commonPayableNumber,
    commonViewAll,
    commonAddLine,
    commonYouHaveUnsavedChanges,
    commonFrom,
    commonValueReq,
    commonPostingStatus,
    commonDueDateRange,
    commonLastPeriodClosed,
    commonRemoveSelectedOption,
    commonMapFields,
    recordsUpdated,
    recordsFailed,
    errorCreditMemoBalanceLessThanZero,
    errorAppliedAmountLessThanZero,
    errorAppliedDateMustBeGreaterThan,
    errorPayableBalanceCannotBeLessThanZero,
    errorOccured,
    errorBillingBalanceNotLessThanZero,
    knowledgeBase,
    errorMaxMustBeGreaterThanMin,
    errorEndDateMustBeGreaterThanStart,
    errorMustEnterValue,
    errorPreventingSave,
    errorRetrieving1099Data,
    commonDrawer,
    commonSupport,
    commonSelected,
    commonRequired,
    enablementsTitle,
    enablementsSubtitle,
    enablementsMultiCurrency,
    enablementsAgingHistory,
    enablementsDefaultBillingDate,
    enablementsCreditMemoDefault,
    enablementsCreditMemoLabel,
    enablementsCashDisbursementSource,
    enablementsCashDisbursementSourceLabel,
    enablementsCashDisbursementSourceHelpText,
    enablementsProductCosting,
    enablementsTimeCard,
    enablementsCashFlow,
    enablementsModal,
    errorValueMissing,
    errorNoAccess,
    errorNoAccessToFeature,
    defaultGlAccountsTitle,
    defaultGlAccountsSubtitle,
    defaultGlAccountsMultiCurrency,
    defaultGlAccountsAccountingClose,
    defaultGlAccountsAccountsReceivable,
    defaultGlAccountsAccountsPayable,
    defaultGlAccountsProjectAccounting,
    defaultGlAccountsProductCosting,
    defaultGlAccountsUserDefined,
    defaultGlAccountsAmortizeDetails,
    defaultGlAccountsAmortizeRevenue,
    defaultGlAccountsAmortizeExpense,
    defaultGlAccountsCashBasisAccounting,
    defaultGlAccountsForPrimaryLedgerModal,
    deleteSourceDocSuccess,
    postSettingsTitle,
    postSettingsAutoSubTitle,
    postSettingsSubtitle,
    postSettingsAuto,
    postSettingsBillable,
    postSettingsAutoOffMsg,
    postSettingsAutoOffMsgExt,
    postSettingsAutoOnMsg,
    postSettingsAutoOnMsgExt,
    multiLedgerDefaultsTitle,
    multiLedgerDefaultsSubtitle,
    multiLedgerDefaultsSuccess,
    multiLedgerDefaultsError,
    defaultLedgerTitle,
    defaultLedgerSubtitle,
    purgeDataSectionHeader,
    purgeDataButtonText,
    purgeDataAP,
    purgeDataBilling,
    purgeDataFinancialReport,
    purgeDataZeroBalance,
    purgeDataAutomatedJobs,
    commonAccountingPeriod,
    purgeDataBeforeDate,
    purgeDataInventoryBalanceHistory,
    production,
    refundCreateTitle,
    refundCreateBillTotalHelp,
    refundCreateBillRcvAmtHelp,
    refundCreateBillBalanceHelp,
    refundCreateNotPostedError,
    refundCreateNotInvoiceError,
    stripeSettingsSubtitle,
    paymentSettingsSuccess,
    stripeSettingsDefPaymentProcessor,
    stripeSettingsConnectedAccounts,
    stripeSettingsPaymentLinkConfig,
    stripeSettingsConnectButton,
    stripeSettingsConfigureButton,
    stripeSettingsReconfigureButton,
    stripeSettingsAuthError,
    stripeSettingsPaymentLinkError,
    stripeSettingsMoved,
    stdReportLedgerInquiry,
    stdReportCashFlow,
    stdReportTrialBalance,
    stdReportBalanceSheet,
    stdReportPLVsBudget,
    stdReportProfitLoss,
    sandbox,
    taxOptionNative,
    taxOptionAvatax,
    taxOptionAvavat,
    taxTestConnection,
    taxValidateAddress,
    vatReportingSettings,
    taxCalculationOptionsLabel,
    taxCalculationOptionsSubLabel,
    taxAvalaraCredentialsSectionTitle,
    taxAvalaraConfigurationSectionTitle,
    taxAvalaraEndpointSectionTitle,
    taxAvalaraEndpointTitle,
    taxAvalaraOriginAddressSectionTitle,
    taxAvalaraHelpfulLinksSectionTitle,
    taxAdminConsoleProductionLinkLabel,
    taxAvalaraHelpCenterLinkLabel,
    taxAvalaraCommunityLinkLabel,
    taxAvalaraVATCredentialsSectionTitle,
    taxAvalaraVATEndpointSectionTitle,
    taxAvalaraVATEndpointTitle,
    taxAvalaraVATLedgerConfigurationSectionTitle,
    taxAvalaraVATReportingHelpfulLinksSectionTitle,
    taxAvalaraVATReportingSupportLinkLabel,
    taxAvalaraVATReportingHelpCenterLinkLabel,
    taxAvalaraVATReportingInstallationGuideLinkLabel,
    addressValidatorTitle,
    addressValidatorValidationStatus,
    addressValidatorOriginAddress,
    addressValidatorValidatedAddress,
    addressValidatorValidateBtn,
    addressValidatorReplaceAddressBtn,
    avalaraLicenseDropboxHelpText,
    avalaraLicenseDoesNotExistMessage,
    finRepSettingsExpandRepRowsHelp,
    creditMemoApplyDate,
    creditMemoComment,
    creditMemoSumOfLines,
    creditMemoTotalCreditLines,
    creditMemoApplyDateHint,
    creditMemoCommentHint,
    creditMemoSumOfLinesHint,
    creditMemoTotalCreditLinesHint,
    commonCreditMemo,
    creditMemoLinesTitle,
    creditMemoSumGreaterTotal,
    creditMemoZeroLinesSum,
    creditMemoCreateApplyInformation,
    cashReceiptRefundTitle,
    cashReceiptRefundDateTitle,
    cashReceiptRefundAmountTitle,
    cashReceiptRefundAmountHelp,
    cashReceiptRefundDateHelp,
    cashReceiptRefundReferenceMessage,
    cashReceiptRefundConfirmationMessage,
    cashReceiptRefundAccessError,
    refundAmountExceededBalanceError,
    cashReceiptRefundAmountNegativeError,
    billingMustBeCreditMemo,
    bdcConfirmFIDelete,
    bdcConfirmCancel,
    bdcCashInMatchingSetting,
    recurringDeepCloneMessage,
    importPayrollUniqueJournalEntryNameInfo,
    importPayrollTransactionDateInfo,
    importPayrollGlAccountInfo,
    importPayrollPositiveDebitInfo,
    importPayrollPositiveCreditInfo,
    importPayrollFileTitle,
    importPayrollFileRequirementMessageTitle,
    importPayrollFileTypeMismatchMessage,
    importPayrollDataTableSearchTitle,
    importPayrollFileRecordCreatedMessage,
    importPayrollFileRecordAlreadyExistsMessage,
    importPayrollCommonErrorMessageHeading,
    importPayrollCommonErrorMessageRequiredColumns,
    importPayrollCommonErrorMessageDuplicates,
    importPayrollCommonErrorMessageOptionalColumns,
    importPayrollCommonErrorMessageThousandRows,
    reportClonedSuccessfully,
    reportGenerationInProgress,
    reportGenerationCompleteWithLink,
    reportOpeningBalanceNote,
    reportCurrentYearEarningsNote,
    frCurrencyValueMissing,
    calculateEstimateTax,
    opportunity,
    overrides,
    customer,
    taxMethodOnLedger,
    subtotal,
    discount,
    estimatedTaxAmount,
    estimatedTotal,
    originAddressOverride,
    destinationAddressOverride,
    opportunityProductLine,
    opportunityTaxProductLine,
    updateTax,
    calculateTax,
    commonProduct,
    quantity,
    commonPrice,
    taxGroup,
    taxEstimateLedgerHelpText,
    taxMethodLedgerHelpText,
    taxEstimateSuccessText,
    taxRateName,
    taxRatePercentage,
    avalaraTaxProduct,
    llpCreateInfoMessage,
    payTypeHelp,
    payProcHelp,
    payMethodHelp,
    earlyPayDiscountHelp,
    discountAmountHelp,
    amountHelp,
    discountDueDateHelp,
    paymentType,
    paymentProcessor,
    paymentMethod,
    date,
    paymentReference,
    discountAmount,
    earlyPayment,
    billingTotal,
    currency,
    ledger,
    bankAccount,
    balanceOwe,
    receivedAmount,
    adjustmentGl,
    discountDueDate,
    paymentInfo,
    balanceOwedHelp,
    connectNote,
    connectMode,
    connectType,
    pleaseConfirm,
    connectPP,
    commonConnect,
    live,
    test,
    connectInThe,
    accountingInfo,
    testModeWarningMessage,
    bdcDeregisterWarning1,
    bdcDeregisterWarning2,
    accountingPeriodCantEmpty,
    endDateCantEmpty,
    DELARCInfo11,
    DELARCInfo12,
    DELARCInfo13,
    DELARCInfo2,
    DELARCInfo3,
    DELARCInfo4,
    DELARCInfo5,
    DELARCInfo6,
    DELAPDsManual1,
    DELAPDsManual2,
    DELAPDsManual21,
    DELAPDsManual22,
    DELAPDsManual23,
    DELAPDsManual24,
    DELAPDsPayable1,
    DELAPDsPayable11,
    DELAPDsPayable12,
    DELAPDsPayable2,
    DELAPDsPayable21,
    DELAPDsPayable22,
    DELAPDsPayable23,
    DELAPDsPayable24,
    DELAPDsInfoNoAPD,
    DELAPDsErrorNoAccess,
    paymentSettings,
    refresh,
    commonYes,
    commonNo,
    bdcModalBody,
    bdcModalHeader,
    cashFlowStatementError,
    enterValidWholeNumber,
    commonCompleteThisField,
    COMMON_TRANSACTIONAL,
    COMMON_BUDGET,
    COMMON_CONSOLIDATIONS_TRANSACTIONAL,
    COMMON_CONSOLIDATIONS_BUDGET,
    COMMON_ELIMINATIONS_TRANSACTIONAL,
    COMMON_ELIMINATIONS_BUDGET,
    COMMON_OPEN_IN_PROGRESS,
    COMMON_CLOSE_IN_PROGRESS,
    COMMON_OPEN,
    COMMON_CLOSED,
    COMMON_ARCHIVED,
    COMMON_ARCHIVED_IN_PROGRESS,
    COMMON_AVERAGE_COST,
    COMMON_STANDARD_COST,
    COMMON_AVATAX,
    COMMON_ACCRUAL_CASH,
    COMMON_ACCRUAL,
    COMMON_CASH,
    TAX_OPTION_NATIVE,
    STD_REPORT_CASH_FLOW,
    COMMON_ACTIVITY_STMT,
    INF_OUTSTANDING_STATEMENT,
    COMMON_PACKING_SLIP,
    COMMON_PURCHASE_ORDER,
    commonMenu,
    commonInfo,
    paymentProcessorsLV,
    amortizationWizardTitle,
    depreciateWizardTitle,
    amortizationWizardInfoMsg,
    depreciateWizardInfoMsg,
    amortizationWizardAmountGreaterWarningMsg,
    depreciateWizardAmountGreaterWarningMsg,
    amortizationWizardSelectMethod,
    depreciateWizardSelectMethod,
    amortizationWizardAmountHelpText,
    amortizationWizardPeriodHelpText,
    amortizationWizardStartDateHelpText,
    amortizationWizardEndDateHelpText,
    amortizationWizardSuccessCreatePostMsg,
    amortizationWizardSuccessCreateMsg,
    depreciateWizardAmountHelpText,
    depreciateWizardPeriodHelpText,
    depreciateWizardStartDateHelpText,
    depreciateWizardEndDateHelpText,
    depreciateWizardSuccessCreatePostMsg,
    depreciateWizardSuccessCreateMsg,
    depreciateWizardNumberPeriodOver,
    paymentSettingsAPLabel,
    paymentSettingsARLabel,
    paymentSettingsDefaultLedgerLabel,
    paymentSettingsCDStatusSettingHeader,
    paymentSettingsCDStatusSettingSubHeader,
    commonPay
};

export {labels as LabelService};