public with sharing class AccountPayablePostTransaction extends AbstractSourceDocumentPost {

    public Boolean getIsHeaderLevelPostEnabled() {
        return AccountingSettingsHandler.isHeaderLevelPost();
    }

    public AccountPayablePostTransaction(ApexPages.StandardController controller) {
        sObjects = new List<sObject>{controller.getRecord()};
        batchProcessing = false;
        showForecastSection = true;
        init();
    }

    public AccountPayablePostTransaction(ApexPages.StandardSetController setController) {
        sObjects = setController.getSelected();
        batchProcessing = true;
        showForecastSection = true;
        init();
    }
    
    private void init() {
        showActionButton = true;
        showErrorStatisticsTable = false;
        showSystemExceptionTable = false;
        onlyValidRecordIds = new Set<String>();

        postStatisticsCodes = new Set<PostResult.StatusCode>{
            PostResult.StatusCode.NO_CONTROL_AP_ACCOUNT_DEFINED,
            PostResult.StatusCode.ALREADY_POSTED,
            PostResult.StatusCode.STATUS_NOT_APPROVED,
            PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD,
            PostResult.StatusCode.NO_LINES,
            PostResult.StatusCode.LINE_COUNT_LIMIT_EXCEEDED,
            PostResult.StatusCode.LEDGER_TYPE_NOT_ALLOWED,
            PostResult.StatusCode.LEDGER_NO_TAX_SETTINGS,
            PostResult.StatusCode.POSTING_IN_PROGRESS,
            PostResult.StatusCode.UNPOSTING_IN_PROGRESS
        };

        unpostStatisticsCodes = new Set<PostResult.StatusCode>{
            PostResult.StatusCode.ALREADY_UNPOSTED,
            PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD,
            PostResult.StatusCode.LINE_COUNT_LIMIT_EXCEEDED,
            PostResult.StatusCode.LEDGER_NO_TAX_SETTINGS,
            PostResult.StatusCode.UNPOSTING_IN_PROGRESS,
            PostResult.StatusCode.POSTING_IN_PROGRESS
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

        AbstractPostHandler postHandler;
        if (isLDVBatchContext) {
            return ldvPostUnpost(SourceDocumentBatchOptions.ExecutionContext.POST);
        }
        else {
            postHandler = new AccountPayablePostHandler();
            results = postHandler.post(sObjects);
        }
        //finalize the results
        return finish(postHandler.dispatcher);
    }
    
    public override PageReference unpost() {
        if (sObjects.isEmpty()) {
            ApexPages.addMessage(
                new ApexPages.Message(
                    ApexPages.SEVERITY.ERROR,
                    AccountPayablePostHandler.NO_SELECTION_UNPOST_ERROR
                )
            );
            showActionButton = false;
            return NULL;
        }

        AbstractPostHandler postHandler;
        if (isLDVBatchContext) {
            return ldvPostUnpost(SourceDocumentBatchOptions.ExecutionContext.UNPOST);
        }
        else {
            postHandler = new AccountPayablePostHandler();
            results = postHandler.unpost(sObjects);
        }

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

            AccountPayablePostHandler postHandler = new AccountPayablePostHandler();
            postHandler.isLDVBatchContext(isLDVBatchContext);
            postHandler.validateBeforePost(sObjects, batchProcessing);
            this.results = postHandler.dispatcher.getPostResults();

            if (batchProcessing) {
                getBatchProcessingValidationResults(postHandler);
            }
            else {
                if (isLDVBatchContext) {
                    showForecastSection = false;
                }
                if (!processPostResults()) {
                    showActionButton = false;
                    showForecastSection = false;
                } else if (!isLDVBatchContext) {
                    ApexPages.addMessage(
                        new ApexPages.Message(
                            ApexPages.SEVERITY.INFO,
                            POST_INFO_MESSAGE
                        )
                    );
                    showForecastSection = true;
                    forecastedTransactions = postHandler.getForecastedTransactions();
                } else if (isLDVBatchContext) {
                    ldvBeforePostUnpost(SourceDocumentBatchOptions.ExecutionContext.POST);
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
                        AccountPayablePostHandler.NO_SELECTION_UNPOST_ERROR
                    )
                );
                showActionButton = false;
                showForecastSection = false;
                return NULL;
            }

            AccountPayablePostHandler postHandler = new AccountPayablePostHandler();
            postHandler.isLDVBatchContext(FeatureManagementHandler.isLargeDataVolumeModeEnabled());
            postHandler.validateBeforeUnpost(sObjects, batchProcessing);
            this.results = postHandler.dispatcher.getPostResults();

            if (batchProcessing) {
                getBatchProcessingValidationResults(postHandler);
            } else {
                if (isLDVBatchContext) {
                    showForecastSection = false;
                }
                if (!processPostResults()) {
                    showActionButton = false;
                    showForecastSection = false;
                }
                else if (!isLDVBatchContext) {
                    ApexPages.addMessage(
                        new ApexPages.Message(
                            ApexPages.SEVERITY.INFO,
                            UNPOST_INFO_MESSAGE
                        )
                    );
                    showForecastSection = true;
                    forecastedTransactions = postHandler.getForecastedTransactions();
                } else if (isLDVBatchContext) {
                    ldvBeforePostUnpost(SourceDocumentBatchOptions.ExecutionContext.UNPOST);
                }
            }
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
        }
        return NULL;
    }

}