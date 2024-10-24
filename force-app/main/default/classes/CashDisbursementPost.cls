public with sharing class CashDisbursementPost extends AbstractSourceDocumentPost {
   
    private static final Integer ASYNC_POST_THRESHOLD = 100;
    private CashDisbursementPostHandler validator;

    @TestVisible
    private static final String ASYNC_BATCH_POST_IN_PROGRESS = Label.INF_ASYNC_BATCH_POST_IN_PROGRESS;

    public CashDisbursementPost(ApexPages.StandardController controller) {
        this.sObjects = getCashDisbursementsFromStandardController(controller);
        showForecastSection = true;
        showActionButton = true;
        init();
    }

    public CashDisbursementPost(ApexPages.StandardSetController controller) {
        this.sObjects = getCashDisbursementsFromStandardSetController(controller);
        showForecastSection = true;
        showActionButton = true;
        init();
    }

    private void init() {
        showErrorStatisticsTable = false;
        showSystemExceptionTable = false;
        onlyValidRecordIds = new Set<String>();
        isCashFlowStatementEnabled = AccountingSettingsHandler.getAccountingSettings().Enable_Cash_Flow_Statement__c;

        postStatisticsCodes = new Set<PostResult.StatusCode>{
            PostResult.StatusCode.NO_CONTROL_AP_ACCOUNT_DEFINED,
            PostResult.StatusCode.NO_DISCOUNT_PAYMENT_ACCOUNT,
            PostResult.StatusCode.ALREADY_POSTED,
            PostResult.StatusCode.PAYMENT_STATUS_VOID,
            PostResult.StatusCode.INCORRECT_APD_AMOUNT,
            PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD,
            PostResult.StatusCode.NO_DEBIT_GL_ACCOUNT,
            PostResult.StatusCode.NO_CASH_FLOW_CATEGORY,
            PostResult.StatusCode.CASH_FLOW_NON_CONFORMITY,
            PostResult.StatusCode.LINE_COUNT_LIMIT_EXCEEDED,
            PostResult.StatusCode.LEDGER_TYPE_NOT_ALLOWED,
            PostResult.StatusCode.STATUS_NOT_APPROVED,
            PostResult.StatusCode.LEDGER_NOT_ENROLLED,
            PostResult.StatusCode.CD_CURRENCY_NOT_USD,
            PostResult.StatusCode.AP_REMITTANCE_EMAIL_BLANK_ON_VENDOR,
            PostResult.StatusCode.NO_DEFAULT_PAYMENT_METHOD_ON_VENDOR_FOR_ACH_PAYMENT_SERVICE,
            PostResult.StatusCode.NO_BILLING_ADDRESS_ON_VENDOR_FOR_CHECK_PAYMENT_SERVICE,
            PostResult.StatusCode.CANT_PAY_CONTACT_OR_EMPLOYEE_FOR_TYPE_PAYMENT_SERVICE,
            PostResult.StatusCode.INACTIVE_DEFAULT_PAYMENT_METHOD,
            PostResult.StatusCode.CASH_DISBUREMENT_BALANCE_MUST_BE_ZERO,
            PostResult.StatusCode.NO_UNAPPLIED_EXPENSE_GL_ACCOUNT_DEFINED,
            PostResult.StatusCode.INACTIVE_VERIFICATION_STATUS_PAYMENT_METHOD
        };

        unpostStatisticsCodes = new Set<PostResult.StatusCode>{
            PostResult.StatusCode.ALREADY_UNPOSTED,
            PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD,
            PostResult.StatusCode.CLEARED_BANK_RECONCILIATION,
            PostResult.StatusCode.APPLIED_TO_PAYABLE
        };

        setHeaderMap();
        setHelpTextMap();
    }

    private List<Cash_Disbursement__c> getCashDisbursementsFromStandardController(ApexPages.StandardController controller) {
        List<Cash_Disbursement__c> result = new List<Cash_Disbursement__c>();
        if (controller.getRecord().getSObjectType() == Cash_Disbursement__c.SObjectType) {
            result.add((Cash_Disbursement__c) controller.getRecord());
            batchProcessing = false;
        }

        if (controller.getRecord().getSObjectType() == Cash_Disbursement_Batch__c.SObjectType) {
            //============================================================================
            // Cash disbursement batch and cash disbursement form a master detail relationship
            // user must have access to the cash disbursements at this point since controller of 
            // cash disbursement batch is used to query for cash disbursements
            //============================================================================
            List<Cash_Disbursement__c> cds = DomainUtils.getCashDisbursementsByCDB(controller.getId());
            result.addAll(cds);
            batchProcessing = true;
        }

        return result;
    }

    private List<Cash_Disbursement__c> getCashDisbursementsFromStandardSetController(ApexPages.StandardSetController controller) {
        batchProcessing = true;
        return (List<Cash_Disbursement__c>) controller.getSelected();
    }

    public override PageReference post() {
        if (sObjects.isEmpty()) {
            ApexPages.addMessage(
                new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    CashDisbursementPostHandler.NO_SELECTION_POSTED_ERROR_MESSAGE
                )
            );
            showActionButton = false;
            return NULL;
        }
        //post in asynchronous context if the threshold condition was met
        if (this.validator.dispatcher.getSuccessResultsQuantity() > ASYNC_POST_THRESHOLD) {
            asyncPostAboveThreshold((List<String>) new List<Id>(new Map<Id, SObject>(sObjects).keySet()));
            ApexPages.addMessage(
                new ApexPages.Message(
                    ApexPages.Severity.CONFIRM,
                    String.format(ASYNC_BATCH_POST_IN_PROGRESS, new List<String>{
                        String.valueOf(this.validator.dispatcher.getSuccessResultsQuantity()),
                        'posting'
                    })
                )
            );
            showActionButton = false;
            showErrorStatisticsTable = false;
            return NULL;
        }
        //try to post records in synchronous context
        AbstractPostHandler postHandler = new CashDisbursementPostHandler();
        results = postHandler.post(sObjects);
        //finalize the results
        return finish(postHandler.dispatcher);
    }

    public static void asyncPostAboveThreshold(List<String> cashDisbIds) {
        Database.executeBatch(new CashDisbursementPostBatch(cashDisbIds, PostResultDispatcher.ExecutionContext.POST), 200);
    }

    public static void asyncUnPostAboveThreshold(List<String> cashDisbIds) {
        Database.executeBatch(new CashDisbursementPostBatch(cashDisbIds, PostResultDispatcher.ExecutionContext.UNPOST), 200);
    }

    public override PageReference unpost() {
        if (sObjects.isEmpty()) {
            ApexPages.addMessage(
                new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    CashDisbursementPostHandler.NO_SELECTION_UNPOSTED_ERROR_MESSAGE
                )
            );
            showActionButton = false;
            return NULL;
        }
        //unpost in asynchronous context if the threshold condition has been met
        if (this.validator.dispatcher.getSuccessResultsQuantity() > ASYNC_POST_THRESHOLD) {
            asyncUnPostAboveThreshold((List<String>) new List<Id>(new Map<Id, SObject>(sObjects).keySet()));
            ApexPages.addMessage(
                new ApexPages.Message(
                    ApexPages.Severity.CONFIRM,
                    String.format(ASYNC_BATCH_POST_IN_PROGRESS, new List<String>{
                        String.valueOf(this.validator.dispatcher.getSuccessResultsQuantity()),
                        'unposting'
                    })
                )
            );
            showActionButton = false;
            showErrorStatisticsTable = false;
            return NULL;
        }
        //try to unpost records in synchronous context
        AbstractPostHandler postHandler = new CashDisbursementPostHandler();
        results = postHandler.unpost(sObjects);
        //finalize the results
        return finish(postHandler.dispatcher);
    }

    public PageReference validateBeforePost() {
        try {
            if (sObjects.isEmpty()) {
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.SEVERITY.ERROR,
                        CashDisbursementPostHandler.NO_SELECTION_POSTED_ERROR_MESSAGE
                    )
                );
                showActionButton = false;
                showForecastSection = false;
                return NULL;
            }

            this.validator = new CashDisbursementPostHandler();
            validator.validateBeforePost(sObjects, batchProcessing);
            this.results = validator.dispatcher.getPostResults();

            if (batchProcessing) {
                getBatchProcessingValidationResults(validator);
            }
            else {
                if (!processPostResults()) {
                    showActionButton = false;
                    showForecastSection = false;
                }
                else {
                    ApexPages.addMessage(
                        new ApexPages.Message(
                            ApexPages.SEVERITY.INFO,
                            POST_INFO_MESSAGE
                        )
                    );
                    showForecastSection = true;
                    forecastedTransactions = validator.getForecastedTransactions();
                }
            }
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
        }
        return NULL;
    }

    public PageReference validateBeforeUnpost() {
        try {
            if (sObjects.isEmpty()) {
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.SEVERITY.ERROR,
                        CashDisbursementPostHandler.NO_SELECTION_UNPOSTED_ERROR_MESSAGE
                    )
                );
                showActionButton = false;
                showForecastSection = false;
                return NULL;
            }

            this.validator = new CashDisbursementPostHandler();
            validator.validateBeforeUnpost(sObjects, batchProcessing);
            this.results = validator.dispatcher.getPostResults();

            if (batchProcessing) {
                getBatchProcessingValidationResults(validator);
            }
            else {
                if (!processPostResults()) {
                    showActionButton = false;
                    showForecastSection = false;
                }
                else {
                    ApexPages.addMessage(
                        new ApexPages.Message(
                            ApexPages.SEVERITY.INFO,
                            UNPOST_INFO_MESSAGE
                        )
                    );
                    showForecastSection = true;
                    forecastedTransactions = validator.getForecastedTransactions();
                }
            }
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
        }
        return NULL;
    }

}