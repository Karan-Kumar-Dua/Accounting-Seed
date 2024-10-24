public with sharing class PostResultDispatcher {

    private Map<String, PostResult> theResultsMap;
    private ExecutionContext execContext;

    public enum ExecutionContext {
        POST,
        UNPOST
    }

    public Boolean isPreCheck {get; set;}

    public PostResultDispatcher() {
        this.theResultsMap = new Map<String, PostResult>();
        isPreCheck = true;
    }

    public void addPostErrorResult(String sourceRecordId, PostResult.PostErrorResult theErrorResult) {
        Id theId = (Id) sourceRecordId;
        SObject sourceRecord = theId.getSobjectType().newSObject(theId);
        addPostErrorResult(sourceRecord, theErrorResult);
    }

    public void addPostErrorResult(SObject sourceRecord, PostResult.PostErrorResult theErrorResult) {
        String sourceRecordId = String.valueOf(sourceRecord.Id);
        //to prevent the "SObject row was retrieved via SOQL without querying the requested field: Name" error
        //we have to check presence of the field in given SObject record first
        String sourceRecordName = (sourceRecord.getPopulatedFieldsAsMap().containsKey('Name')) ? String.valueOf(sourceRecord.get('Name')) : sourceRecordId;

        if (theResultsMap.containsKey(sourceRecordId)) {
            addUniqueOnlyErrorResult(sourceRecordId, sourceRecordName, theErrorResult);
        }
        else {
            theResultsMap.put(
                sourceRecordId,
                new PostResult(
                    false,
                    sourceRecordId,
                    sourceRecordName,
                    new List<PostResult.PostErrorResult>{
                        theErrorResult
                    }
                )
            );
        }
    }

    private void addUniqueOnlyErrorResult(String id, String name, PostResult.PostErrorResult theErrorResult) {
        PostResult.StatusCode newStatusCode = theErrorResult.statusCode;
        Boolean isDuplicatedErrorResult = false;

        if (theResultsMap.get(id).errors == NULL) {
            theResultsMap.put(id, new PostResult(false, id, name, new List<PostResult.PostErrorResult>{theErrorResult}));
        }

        for (PostResult.PostErrorResult error : theResultsMap.get(id).errors) {
            if (error.statusCode == newStatusCode) {
                isDuplicatedErrorResult = true;
                break;
            }
        }

        if (!isDuplicatedErrorResult) {
            theResultsMap.get(id).errors.add(theErrorResult);
        }
    }

    public Set<Id> getRecordIdsFailedBySystemException() {
        Set<Id> result = new Set<Id>();
        for (PostResult postRes : getPostResults()) {
            if (!postRes.isSuccess) {
                for (PostResult.PostErrorResult eachErrorResult : postRes.errors) {
                    if (eachErrorResult.statusCode == PostResult.StatusCode.SYSTEM_EXCEPTION) {
                        result.add(postRes.id);
                    }
                }
            }
        }

        return result;
    }

    public void mergeWith(PostResultDispatcher extDispatcher) {
        Map<String, PostResult> extPostResultMap = extDispatcher.getPostResultsMap();
        for (String recId : extPostResultMap.keySet()) {
            if (theResultsMap.containsKey(recId)) {
                theResultsMap.get(recId).errors.addAll(extPostResultMap.get(recId).errors);
            }
            else {
                theResultsMap.put(recId, extPostResultMap.get(recId));
            }
        }
    }

    public PostResultDispatcher.ExecutionContext getExecutionContext() {
        return execContext;
    }

    public void setExecutionContext(PostResultDispatcher.ExecutionContext c) {
        this.execContext = c;
    }

    public void addPostResult(String id, PostResult postResult) {
        this.theResultsMap.put(id, postResult);
    }

    public List<PostResult> getPostResults() {
        return theResultsMap.values();
    }

    public Map<String, PostResult> getPostResultsMap() {
        return theResultsMap;
    }

    public Integer getAllResultsQuantity() {
        return theResultsMap.size();
    }

    public List<PostResult> getSuccessfulResults() {
        return getPostResultsByIsSuccessStatus(true).values();
    }

    public Set<Id> getIdsFromSuccessfulResultsAsSet() {
        return getPostResultsByIsSuccessStatus(true).keySet();
    }

    public List<Id> getIdsFromSuccessfulResultsAsList() {
        return new List<Id>(getIdsFromSuccessfulResultsAsSet());
    }

    public List<PostResult> getFailedResults() {
        return getPostResultsByIsSuccessStatus(false).values();
    }

    public Set<Id> getIdsFromFailedResults() {
        return getPostResultsByIsSuccessStatus(false).keySet();
    }

    private Map<Id, PostResult> getPostResultsByIsSuccessStatus(Boolean isSuccess) {
        Map<Id, PostResult> resultsMap = new Map<Id, PostResult>();
        for (PostResult pr : getPostResults()) {
            if ((isSuccess && pr.isSuccess) || (!isSuccess && !pr.isSuccess)) {
                resultsMap.put(pr.id, pr);
            }
        }
        return resultsMap;
    }

    public Integer getErrorResultsQuantity() {
        return getFailedResults().size();
    }

    public Integer getSuccessResultsQuantity() {
        return getSuccessfulResults().size();
    }

    public void clearResultsMap() {
        theResultsMap.clear();
    }

    public ApexPages.SEVERITY getApexPageSeverity() {
        if (isPreCheck && getErrorResultsQuantity() == 0) {
            return ApexPages.Severity.INFO;
        }
        else if (isPreCheck && getSuccessResultsQuantity() > 0 && getErrorResultsQuantity() > 0) {
           return ApexPages.Severity.WARNING;
        }
        else if (getSuccessResultsQuantity() == 0) {
            return ApexPages.Severity.ERROR;
        }
        else {
            return ApexPages.Severity.CONFIRM;
        }
    }

    public String getPreExecutionReport() {
        List<String> reportParts = new List<String>{
            Label.COMMON_NUMBER_OF_RECORDS_SUBMITTED,
            Label.COMMON_NUMBER_OF_RECORDS_CAN_BE_POSTED,
            getSuccessResultsQuantity() > 0 ? Label.COMMON_CLICK_ON_THE_BUTTON : '</br>',
            Label.COMMON_NUMBER_OF_RECORDS_WITH_ERRORS,
            getErrorResultsQuantity() > 0 ?
                    Label.COMMON_CLICK_RECORD_TABLE_CELL_RESOLVE :
                    '</br>'
        };
        return String.format(String.join(reportParts, ''), new List<String>{
                execContext == PostResultDispatcher.ExecutionContext.POST ? '' : 'un',
                String.valueOf(getAllResultsQuantity()),
                String.valueOf(getSuccessResultsQuantity()),
                String.valueOf(getErrorResultsQuantity()),
                execContext == PostResultDispatcher.ExecutionContext.POST ? 'Post' : 'Unpost'
        });
    }

    public List<StatisticsLine> buildErrorStatisticsLines(Set<PostResult.StatusCode> statisticsCodes) {
        List<PostResultDispatcher.StatisticsLine> newLines = new List<PostResultDispatcher.StatisticsLine>();
        for (String id : theResultsMap.keySet()) {
            if (!theResultsMap.get(id).isSuccess) {
                PostResult theNegativePostResult = theResultsMap.get(id);
                PostResultDispatcher.StatisticsLine newLine =
                    new PostResultDispatcher.StatisticsLine(
                        theNegativePostResult.id,
                        theNegativePostResult.name,
                        theNegativePostResult.errors,
                        statisticsCodes
                    );

                newLines.add(newLine);
            }
        }

        return newLines;
    }

    public List<StatisticsLine> buildSystemExceptionLines() {
        List<PostResultDispatcher.StatisticsLine> newLines = new List<PostResultDispatcher.StatisticsLine>();
        for (String id : theResultsMap.keySet()) {
            if (!theResultsMap.get(id).isSuccess) {
                PostResult theNegativePostResult = theResultsMap.get(id);
                PostResultDispatcher.StatisticsLine newLine =
                    new PostResultDispatcher.StatisticsLine(
                        theNegativePostResult.id,
                        theNegativePostResult.name,
                        theNegativePostResult.errors
                    );

                newLines.add(newLine);
            }
        }
        return newLines;
    }

    public String getExecutionReport() {
        String contextVar1 = (execContext == PostResultDispatcher.ExecutionContext.POST) ? Label.COMMON_SMALL_POSTED : Label.COMMON_UNPOSTED;
        String contextVar2 = (execContext == PostResultDispatcher.ExecutionContext.POST) ? Label.COMMON_POSTING : Label.COMMON_UNPOSTING;
        String report =
            Label.COMMON_NUMBER_OF_RECORDS_PROCESSED_FOR +' '+ contextVar2 + ': <strong>(' + getAllResultsQuantity() + ')</strong>.<br/>';
        report += Label.COMMON_NUMBER_OF_RECORDS_SUCCESSFULLY +' ' + contextVar1 + ': <strong>(' + getSuccessResultsQuantity() + ')</strong>.<br/>';

        if (getAllResultsQuantity() > getSuccessResultsQuantity() && !getPostResults().isEmpty()) {
            report += '<br/>'+ Label.COMMON_ERRORS_DESCRIBED_BELOW;
        }

        return report;
    }

    public with sharing class StatisticsLine {
        public String sourceObjectId {get; set;}
        public String sourceObjectName {get; set;}
        public String systemExceptionErrorMessage {get; set;}
        public Map<String, StatisticsCell> lineCells {get; set;}

        public StatisticsLine(String id, String name, List<PostResult.PostErrorResult> errorResults) {

            this.sourceObjectId = id;
            this.sourceObjectName = name;
            this.systemExceptionErrorMessage = '';
            for (PostResult.PostErrorResult errorResult : errorResults) {
                if (!String.isBlank(systemExceptionErrorMessage)) {
                    systemExceptionErrorMessage += '<br/>';
                }
                systemExceptionErrorMessage += errorResult.message;
            }
        }

        public StatisticsLine(String id, String name, List<PostResult.PostErrorResult> errorResults, Set<PostResult.StatusCode> statisticsCodes  ) {
            this.sourceObjectId = id;
            this.sourceObjectName = name;
            this.lineCells = fillLineCells(errorResults, statisticsCodes);
        }

        private Map<String, StatisticsCell> fillLineCells(  List<PostResult.PostErrorResult> errorResults,
                                                            Set<PostResult.StatusCode> availableErrorCodes  ) {

            Map<String, StatisticsCell> lineCells = new Map<String, StatisticsCell>();
            for (PostResult.StatusCode statusCode : availableErrorCodes) {
                lineCells.put(statusCode.name(), new StatisticsCell('', ''));
            }

            for (PostResult.PostErrorResult errorResult : errorResults) {
                if (lineCells.containsKey(errorResult.statusCode.name())) {
                    lineCells.put(
                        errorResult.statusCode.name(),
                        new StatisticsCell(
                            (String) errorResult.errorSource.Id,
                            (String) errorResult.errorSource.get('Name'),
                            (String) errorResult.message
                        )
                    );
                }
            }

            return lineCells;
        }

    }

    public with sharing class StatisticsCell {
        public String id {get; set;}
        public String name {get; set;}
        public String message {get; set;}

        public StatisticsCell(String id, String name) {
            this.id = id;
            this.name = name;
        }

        public StatisticsCell(String id, String name, String message) {
            this(id, name);
            this.message = message;
        }
    }

}