public with sharing class TimeCardPostTransaction extends AbstractSourceDocumentPost {

    public TimeCardPostTransaction(ApexPages.StandardSetController setController) {
        sObjects = setController.getSelected();
        batchProcessing = true;
        init();
    }

    private void init() {
        showActionButton = true;
        showErrorStatisticsTable = false;
        showSystemExceptionTable = false;
        onlyValidRecordIds = new Set<String>();

        postStatisticsCodes = new Set<PostResult.StatusCode>{
            PostResult.StatusCode.NO_LABOR_CONTROL_ACCOUNT_DEFINED,
            PostResult.StatusCode.NO_TASK_EXPENSE_GL_ACCOUNT_DEFINED,
            PostResult.StatusCode.ALREADY_POSTED,
            PostResult.StatusCode.STATUS_NOT_APPROVED,
            PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD,
            PostResult.StatusCode.LINE_COUNT_LIMIT_EXCEEDED,
            PostResult.StatusCode.ONLY_ACTUAL_TIME_CARD_ALLOW,
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
                    TimeCardPostHandler.NO_APPROVED_SELECTION_MESSAGE
                )
            );
            showActionButton = false;
            return NULL;
        }
        //try to post records
        AbstractPostHandler postHandler = new TimeCardPostHandler();
        results = postHandler.post(sObjects);
        //finalize the results
        return finish(postHandler.dispatcher);
    }

    public override PageReference unpost() {
        if (sObjects.isEmpty()) {
            ApexPages.addMessage(
                new ApexPages.Message(
                    ApexPages.SEVERITY.ERROR,
                    TimeCardPostHandler.NO_POSTED_SELECTION_MESSAGE
                )
            );
            showActionButton = false;
            return NULL;
        }
        //try to unpost records
        AbstractPostHandler postHandler = new TimeCardPostHandler();
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
                        TimeCardPostHandler.NO_APPROVED_SELECTION_MESSAGE
                    )
                );
                showActionButton = false;
                showForecastSection = false;
                return NULL;
            }

            TimeCardPostHandler postHandler = new TimeCardPostHandler();
            postHandler.validateBeforePost(sObjects, batchProcessing);
            this.results = postHandler.dispatcher.getPostResults();

            //Time Cards only support batch post
            getBatchProcessingValidationResults(postHandler);
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
                        TimeCardPostHandler.NO_POSTED_SELECTION_MESSAGE
                    )
                );
                showActionButton = false;
                showForecastSection = false;
                return NULL;
            }

            TimeCardPostHandler postHandler = new TimeCardPostHandler();
            postHandler.validateBeforeUnpost(sObjects, batchProcessing);
            this.results = postHandler.dispatcher.getPostResults();

            //Time Cards only support batch post
            getBatchProcessingValidationResults(postHandler);
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
        }
        return NULL;
    }

}