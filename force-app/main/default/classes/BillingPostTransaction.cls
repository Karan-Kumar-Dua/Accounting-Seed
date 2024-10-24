public with sharing class BillingPostTransaction extends AbstractSourceDocumentPost {

    public Boolean getIsAvalaraCalcEnabled() {
        return AvaTaxHelper.isAvalaraTaxCalculationEnabled(sObjects);
    }

    public Boolean getIsHeaderLevelPostEnabled() {
        return AccountingSettingsHandler.isHeaderLevelPost();
    }

    public BillingPostTransaction(ApexPages.StandardController controller) {
        if (!Test.isRunningTest()) {
            controller.addFields(new List<String>{GlobalVariables.PACKAGE_QUALIFIER + 'Ledger__c'});
        }
        sObjects = new List<sObject>{controller.getRecord()};
        batchProcessing = false;
        showForecastSection = true;
        init();
    }

    public BillingPostTransaction(ApexPages.StandardSetController setController) {
        if (!Test.isRunningTest()) {
            setController.addFields(new List<String>{GlobalVariables.PACKAGE_QUALIFIER + 'Ledger__c'});
        }
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
            PostResult.StatusCode.NO_CONTROL_AR_ACCOUNT_DEFINED,
            PostResult.StatusCode.ALREADY_POSTED,
            PostResult.StatusCode.STATUS_NOT_APPROVED,
            PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD,
            PostResult.StatusCode.NO_LINES,
            PostResult.StatusCode.LINE_COUNT_LIMIT_EXCEEDED,
            PostResult.StatusCode.AVATAX_SERVICE_ERROR,
            PostResult.StatusCode.LEDGER_TYPE_NOT_ALLOWED,
            PostResult.StatusCode.LEDGER_NO_TAX_SETTINGS,
            PostResult.StatusCode.POSTING_IN_PROGRESS,
            PostResult.StatusCode.UNPOSTING_IN_PROGRESS
        };

        unpostStatisticsCodes = new Set<PostResult.StatusCode>{
            PostResult.StatusCode.ALREADY_UNPOSTED,
            PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD,
            PostResult.StatusCode.LINE_COUNT_LIMIT_EXCEEDED,
            PostResult.StatusCode.AVATAX_SERVICE_ERROR,
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
            postHandler = new BillingPostHandler();
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
                    BillingPostHandler.NO_SELECTION_UNPOSTED_ERROR_MESSAGE
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
            postHandler = new BillingPostHandler();
            results = postHandler.unpost(sObjects);
        }

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

            BillingPostHandler postHandler = new BillingPostHandler();
            postHandler.isLDVBatchContext(isLDVBatchContext);
            postHandler.validateBeforePost(sObjects, batchProcessing);
            this.results = postHandler.dispatcher.getPostResults();

            if (!this.results[0].isSuccess && this.results[0]?.errors[0]?.message.contains(Label.MULTIPLE_AVALARA_LICENSE_ERROR)) {
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.SEVERITY.ERROR,
                        Label.MULTIPLE_AVALARA_LICENSE_ERROR
                    )
                );
                showActionButton = false;
                showForecastSection = false;
                return NULL;
            }

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

                    if (trimForecastedTransactionCollectionTo1000()) {
                        ApexPages.addMessage(
                            new ApexPages.Message(
                                ApexPages.SEVERITY.WARNING,
                                String.format(
                                    POST_COLLECTION_LIMIT_WARNING_MESSAGE,
                                    new List<String>{String.valueOf(forecastedTransactionsCollectionSize)}
                                )
                            )
                        );
                    }
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
                        BillingPostHandler.NO_SELECTION_UNPOSTED_ERROR_MESSAGE
                    )
                );
                showActionButton = false;
                showForecastSection = false;
                return NULL;
            }

            BillingPostHandler postHandler = new BillingPostHandler();
            postHandler.isLDVBatchContext(isLDVBatchContext);
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

                    if (trimForecastedTransactionCollectionTo1000()) {
                        ApexPages.addMessage(
                            new ApexPages.Message(
                                ApexPages.SEVERITY.WARNING,
                                String.format(
                                    UNPOST_COLLECTION_LIMIT_WARNING_MESSAGE,
                                    new List<String>{String.valueOf(forecastedTransactionsCollectionSize)}
                                )
                            )
                        );
                    }
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