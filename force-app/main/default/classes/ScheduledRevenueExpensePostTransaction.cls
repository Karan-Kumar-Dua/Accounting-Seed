public with sharing class ScheduledRevenueExpensePostTransaction extends AbstractSourceDocumentPost {

    public ScheduledRevenueExpensePostTransaction(ApexPages.StandardController controller) {
        sObjects = new List<sObject>{controller.getRecord()};
        showForecastSection = true;
        batchProcessing = false;
        init();
    }

    public ScheduledRevenueExpensePostTransaction(ApexPages.StandardSetController setController) {
        sObjects = setController.getSelected();
        showForecastSection = false;
        batchProcessing = true;
        init();
    }

    private void init() {
        showActionButton = true;
        showErrorStatisticsTable = false;
        showSystemExceptionTable = false;
        onlyValidRecordIds = new Set<String>();

        postStatisticsCodes = new Set<PostResult.StatusCode>{
            PostResult.StatusCode.ALREADY_POSTED,
            PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD,
            PostResult.StatusCode.LEDGER_TYPE_NOT_ALLOWED
        };

        unpostStatisticsCodes = new Set<PostResult.StatusCode>{
            PostResult.StatusCode.ALREADY_UNPOSTED,
            PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD
        };

        setHeaderMap();
        setHelpTextMap();
    }

    public override PageReference post() {
        if (sObjects.isEmpty()) {
            ApexPages.addMessage(
                new ApexPages.Message(
                    ApexPages.SEVERITY.ERROR,
                    ScheduledRevenueExpensePostHandler.NO_SELECTION_POSTED_ERROR_MESSAGE
                )
            );
            showActionButton = false;
            return NULL;
        }
        //try to post records
        AbstractPostHandler postHandler = new ScheduledRevenueExpensePostHandler();
        results = postHandler.post(sObjects);
        //finalize the results
        return finish(postHandler.dispatcher);
    }

    public override PageReference unpost() {
        if (sObjects.isEmpty()) {
            ApexPages.addMessage(
                new ApexPages.Message(
                    ApexPages.SEVERITY.ERROR,
                    ScheduledRevenueExpensePostHandler.NO_SELECTION_UNPOSTED_ERROR_MESSAGE
                )
            );
            showActionButton = false;
            return NULL;
        }
        //try to unpost records
        AbstractPostHandler postHandler = new ScheduledRevenueExpensePostHandler();
        results = postHandler.unpost(sObjects);
        //checking the results
        return finish(postHandler.dispatcher);
    }

    public PageReference validateBeforePost() {
        try {
            if (sObjects.isEmpty()) {
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.SEVERITY.ERROR,
                        ScheduledRevenueExpensePostHandler.NO_SELECTION_POSTED_ERROR_MESSAGE
                    )
                );
                showActionButton = false;
                showForecastSection = false;
                return NULL;
            }

            ScheduledRevenueExpensePostHandler postHandler = new ScheduledRevenueExpensePostHandler();
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
                        ScheduledRevenueExpensePostHandler.NO_SELECTION_UNPOSTED_ERROR_MESSAGE
                    )
                );
                showActionButton = false;
                showForecastSection = false;
                return NULL;
            }

            ScheduledRevenueExpensePostHandler postHandler = new ScheduledRevenueExpensePostHandler();
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