public with sharing class CashReceiptPost extends AbstractSourceDocumentPost {

    public CashReceiptPost(ApexPages.StandardController controller) {
        sObjects = new List<sObject>{controller.getRecord()};
        batchProcessing = false;
        showForecastSection = true;
        init();
    }

    public CashReceiptPost(ApexPages.StandardSetController setController) {
        sObjects = setController.getSelected();
        batchProcessing = true;
        showForecastSection = false;
        init();
    }

    private void init() {
        showActionButton = true;
        showErrorStatisticsTable = false;
        showSystemExceptionTable = false;
        onlyValidRecordIds = new Set<String>();
        isCashFlowStatementEnabled = AccountingSettingsHandler.getAccountingSettings().Enable_Cash_Flow_Statement__c;

        postStatisticsCodes = new Set<PostResult.StatusCode>{
            PostResult.StatusCode.ALREADY_POSTED,
            PostResult.StatusCode.STATUS_NOT_APPROVED,
            PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD,
            PostResult.StatusCode.NO_UNAPPLIED_CASH_CONTROL_ACCOUNT_DEFINED,
            PostResult.StatusCode.NO_CASH_FLOW_CATEGORY,
            PostResult.StatusCode.CASH_FLOW_NON_CONFORMITY,
            PostResult.StatusCode.LEDGER_TYPE_NOT_ALLOWED,
            PostResult.StatusCode.NO_UNAPPLIED_REVENUE_GL_ACCOUNT_DEFINED,
            PostResult.StatusCode.ERR_CASHRECEIPT_STATUS_VOID_ERROR_DECLINED,
            PostResult.StatusCode.ERR_CR_POSTED_VOID
        };

        unpostStatisticsCodes = new Set<PostResult.StatusCode>{
            PostResult.StatusCode.ALREADY_UNPOSTED,
            PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD,
            PostResult.StatusCode.BILLING_CASH_RECEIPTS_EXIST,
            PostResult.StatusCode.CLEARED_BANK_RECONCILIATION,
            PostResult.StatusCode.CLEARED_BANK_DEPOSIT
        };

        setHeaderMap();
        setHelpTextMap();
    }

    public override PageReference post() {
        if (sObjects.isEmpty()) {
            ApexPages.addMessage(
                new ApexPages.Message(
                    ApexPages.SEVERITY.ERROR,
                    AbstractPostHandler.NO_SELECTION_POSTED_ERROR_MESSAGE
                )
            );
            showActionButton = false;
            return NULL;
        }
        //try to post records
        AbstractPostHandler postHandler = new CashReceiptPostHandler();
        results = postHandler.post(sObjects);
        //finalize the results
        return finish(postHandler.dispatcher);
    }

    public override PageReference unpost() {
        if (sObjects.isEmpty()) {
            ApexPages.addMessage(
                new ApexPages.Message(
                    ApexPages.SEVERITY.ERROR,
                    CashReceiptPostHandler.NO_SELECTION_UNPOSTED_ERROR_MESSAGE
                )
            );
            showActionButton = false;
            return NULL;
        }
        //try to unpost records
        AbstractPostHandler postHandler = new CashReceiptPostHandler();
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
                        AbstractPostHandler.NO_SELECTION_POSTED_ERROR_MESSAGE
                    )
                );
                showActionButton = false;
                showForecastSection = false;
                return NULL;
            }

            CashReceiptPostHandler postHandler = new CashReceiptPostHandler();
            postHandler.validateBeforePost(sObjects, batchProcessing);
            this.results = postHandler.dispatcher.getPostResults();

            if (batchProcessing) {
                getBatchProcessingValidationResults(postHandler);
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
                    forecastedTransactions = postHandler.getForecastedTransactions();
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
                        CashReceiptPostHandler.NO_SELECTION_UNPOSTED_ERROR_MESSAGE
                    )
                );
                showActionButton = false;
                showForecastSection = false;
                return NULL;
            }

            CashReceiptPostHandler postHandler = new CashReceiptPostHandler();
            postHandler.validateBeforeUnpost(sObjects, batchProcessing);
            this.results = postHandler.dispatcher.getPostResults();

            if (batchProcessing) {
                getBatchProcessingValidationResults(postHandler);
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
                    forecastedTransactions = postHandler.getForecastedTransactions();
                }
            }
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
        }
        return NULL;
    }

}