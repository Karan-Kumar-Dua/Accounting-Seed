public abstract with sharing class SourceDocumentBatchBase implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {

    protected Schema.SObjectType masterSObjectType;
    protected Schema.SObjectType headerSObjectType;
    protected Schema.SObjectType lineSObjectType;
    protected String parentRelationshipField;
    protected SourceDocumentBatchHelper helper = new SourceDocumentBatchHelper();
    protected Set<Id> headerIds = new Set<Id>();
    @TestVisible
    protected Boolean isScheduledPostJob = false;
    @TestVisible
    protected Set<AbstractSourceRecordPostBatch.SourceRecordType> schedSourceRecordTypes = new Set<AbstractSourceRecordPostBatch.SourceRecordType>();
    @TestVisible
    protected AbstractSourceRecordPostBatch.SourceRecordType currentSourceRecordType;
    @TestVisible
    protected SourceDocumentBatchOptions options;
    @TestVisible
    protected CurrentScopeState scopeState;
    protected Id ajrId;

    public SourceDocumentBatchBase(Schema.SObjectType sObjectType, SourceDocumentBatchOptions options) {
        this.options = options;
        this.headerSObjectType = sObjectType;
        this.lineSObjectType = helper.mParentToChild.get(this.headerSObjectType);
        this.parentRelationshipField = SourceDocumentBatchHelper.mChildRelationship.get(this.lineSObjectType).getDescribe().getName();
        this.headerIds = this.options.getCurrentContextSourceIds();
        this.scopeState = new CurrentScopeState(this.headerSObjectType, this.parentRelationshipField);
    }

    public SourceDocumentBatchBase ajrId(Id ajrId) {
        this.ajrId = ajrId;
        return this;
    }

    public SourceDocumentBatchBase isScheduledPostJob(Boolean isScheduledPostJob) {
        this.isScheduledPostJob = isScheduledPostJob;
        setScheduledPostMasterRecords();
        return this;
    }

    public SourceDocumentBatchBase schedSourceRecordTypes(Set<AbstractSourceRecordPostBatch.SourceRecordType> schedSourceRecordTypes) {
        this.schedSourceRecordTypes = schedSourceRecordTypes;
        return this;
    }

    public SourceDocumentBatchBase currentSourceRecordType(AbstractSourceRecordPostBatch.SourceRecordType currentSourceRecordType) {
        this.currentSourceRecordType = currentSourceRecordType;
        return this;
    }

    public SourceDocumentBatchBase options(SourceDocumentBatchOptions options) {
        this.options = options;
        this.options.addMasterRecordIds();
        this.headerIds = this.options.getCurrentContextSourceIds();
        return this;
    }

    public Database.QueryLocator start(Database.BatchableContext ctx) {
        SelectorAbstract lineSelector = (SelectorAbstract)this.helper.mSelectors.get(this.lineSObjectType).newInstance();
        lineSelector.setHeaderIds(headerIds);
        lineSelector.setContext(options.currentContext());
        String soql = lineSelector.getBaseQuery(options);
        //create AJR record in advance to populate its ID on all created Tasks
        AutomatedJobResultsHandler.setJobType(
            String.format(options.jobName, new List<String> {
                (options.currentContext() == SourceDocumentBatchOptions.ExecutionContext.UNPOST ? Label.COMMON_UNPOST : Label.COMMON_POST)
            })
        );
        setInitAJRIdValue();
        return headerIds != null && !headerIds.isEmpty() ?
            DomainUtils.getQueryLocator(soql, headerIds) : DomainUtils.getQueryLocator(soql);
    }

    public virtual void execute(Database.BatchableContext ctx, List<SObject> scope) {
        scopeState.resetInputsMap();
        scopeState.setGroupMap(helper.getCurrentGroupMap(scopeState.getInbound(), ctx.getJobId()));

        for (SObject record : scope) {
            if (headerIds.isEmpty() && !options.isValidForCurrentMethod((String) SourceDocumentBatchHelper.fetchRecordValue(record, SourceDocumentBatchHelper.ledgerFieldBySobjectType.get(headerSObjectType)))) {
                continue;
            }

            if (scopeState.isFirstIteration()) {
                scopeState.setInitValues(record, ctx.getJobId(), options.currentAccountingMethod());
            }
            else {
                scopeState.setCurrentValue(record, options.currentAccountingMethod());
            }
        }

        try {
            if (scopeState.isRecordsToProcess()) {
                Map<Id, PostResult> tempFailedMap = new Map<Id, PostResult>();
                for (PostResult res : this.processSourceDocumentData(scopeState.getInputs())) {
                    if (!res.isSuccess) {
                        scopeState.addFailed(res.id);
                        options.removeFailed(res.id);
                        options.removeMasterRecordId(res.id);
                        tempFailedMap.put(res.id, res);
                    }
                }
                if (headerIds.isEmpty() && scopeState.isNeedUpdatePostingStatus() && options.isAllowUpdateStatus()) {
                    helper.setPostingStatus(
                        new List<Id> (scopeState.getForUpdatePostingStatus()),
                        options.currentContext() == SourceDocumentBatchOptions.ExecutionContext.POST ?
                            AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTING_IN_PROGRESS : AbstractPostHandler.DEFAULT_POSTING_STATUS_UNPOSTING_IN_PROGRESS,
                        headerSObjectType,
                        new Set<String>{
                            options.currentContext() == SourceDocumentBatchOptions.ExecutionContext.POST
                                ? AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED
                                : AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED
                        }
                    );
                }
                if (!tempFailedMap.isEmpty()) {
                    setSourceRecordsStatusAfterException(tempFailedMap.keySet());
                    logOnActivity(tempFailedMap.values());
                }
            }
        } catch (Exception ex) {
            scopeState.addCurrentInboundFailed();
            options.removeFailed(scopeState.getFailed());
            options.removeAllMasterRecordIds();
            setSourceRecordsStatusAfterException(scopeState.getFailed());
            logExceptionActivity(ex.getMessage(), scopeState.getFailed());
        }

        if (!scopeState.getOutboundForDeleteTG().isEmpty()) {
            Set<Id> tgForDelete = new Set<Id>();
            for (Id sourceId : scopeState.getOutboundForDeleteTG()) {
                if (scopeState.getGroupMap().get(sourceId).Line_Count__c <= scopeState.getGroupMap().get(sourceId).Lines_Processed__c) {
                    tgForDelete.add(sourceId);
                }
            }
            if (!tgForDelete.isEmpty()) {
                helper.deleteOutboundTransactionGroup(tgForDelete, ctx.getJobId());
                scopeState.removeFromGroupMap(tgForDelete);
            }
        }
        helper.upsertCurrentGroupMap(scopeState.getGroupMap());
        scopeState.clearOutbound();
    }

    public void finish(Database.BatchableContext ctx) {
        options.total += scopeState.getTotalCount();
        options.failed += scopeState.getFailedCount();
        if (options.hasNext()) {
            options.setNext();
            callNextBatch();
        }
        else {
            Schema.SObjectType selectedSObjectType = masterSObjectType != null
                && (masterSObjectType == Billing_Cash_Receipt__c.getSObjectType()
                || masterSObjectType == AP_Disbursement__c.getSObjectType()) ? masterSObjectType : headerSObjectType;

            new PostProcessor().postOutstandingSourceRecords(selectedSObjectType, options.currentContext());
            processAutomatedJobResults();

            if (!this.isScheduledPostJob) {
                runNextSequenceBatch(selectedSObjectType);
            } else {
                AbstractSourceRecordPostBatch.sendEmail(
                        AbstractSourceRecordPostBatch.buildExecutionReport(
                                Label.COMMON_POSTING,
                                headerSObjectType.getDescribe().labelPlural,
                                options.total,
                                options.failed
                        ),
                        AbstractSourceRecordPostBatch.JOB_NAME
                );

                if (currentSourceRecordType != null) {
                    schedSourceRecordTypes.remove(currentSourceRecordType);
                    if (!schedSourceRecordTypes.isEmpty()) {
                        AbstractSourceRecordPostBatch.executeLDVBatch(
                                new List<AbstractSourceRecordPostBatch.SourceRecordType>(schedSourceRecordTypes)[0],
                                schedSourceRecordTypes
                        );
                    }
                }
            }
        }
        if (!scopeState.getInbound().isEmpty()) {
            helper.deleteOutboundTransactionGroup(scopeState.getInbound(), ctx.getJobId());
        }
        if (scopeState.isNeedRunDeleteBatch()) {
            callDeleteBatch(ctx.getJobId());
        }
    }

    public void processAutomatedJobResults() {
        if (String.isNotBlank(this.ajrId)) {
            AutomatedJobResultsHandler.presetJobResultRecord(this.ajrId);
        }
        AutomatedJobResultsHandler.setJobType(
                String.format(options.jobName, new List<String> {
                        (options.currentContext() == SourceDocumentBatchOptions.ExecutionContext.UNPOST ? Label.COMMON_UNPOST : Label.COMMON_POST)
                })
        );
        buildExecutionReport();
        if (String.isNotBlank(this.ajrId)) {
            AutomatedJobResultsHandler.updateAutomatedJobResults();
        } else {
            AutomatedJobResultsHandler.saveAutomatedJobResults();
        }
    }

    private void setInitAJRIdValue() {
        if (String.isBlank(this.ajrId) && options.ajrId != null) {
            this.ajrId = options.ajrId;
        } else if (String.isBlank(this.ajrId) && options.ajrId == null) {
            this.ajrId = AutomatedJobResultsHandler.saveAutomatedJobResults();
            options.ajrId = this.ajrId;
        }
    }

    public void runNextSequenceBatch(Schema.SObjectType selectedSObjectType) {
        Set<SObjectType> onlyOneByOne = new Set<SObjectType>();
        if (PostProcessor.ONLY_ONE_BY_ONE.contains(selectedSObjectType)) {
            onlyOneByOne.addAll(PostProcessor.ONLY_ONE_BY_ONE);
        }
        if (PostProcessor.ONLY_POST_OR_UNPOST.contains(selectedSObjectType)) {
            onlyOneByOne.add(selectedSObjectType);
        }
        if (!onlyOneByOne.isEmpty()) {
            for (SourceDocumentBatchOptions.ExecutionContext context : SourceDocumentBatchOptions.ExecutionContext.values()) {
                String inProgressStatus = context == SourceDocumentBatchOptions.ExecutionContext.POST
                        ? AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTING_IN_PROGRESS
                        : AbstractPostHandler.DEFAULT_POSTING_STATUS_UNPOSTING_IN_PROGRESS;
                for (SObjectType sObjType : onlyOneByOne) {
                    if (context == options.currentContext() && sObjType == selectedSObjectType) continue;

                    List<SObject> records = DomainUtils.inProgressRecordsBySObjectType(
                            sObjType,
                            SourceDocumentBatchHelper.statusFieldBySobjectType.get(sObjType),
                            inProgressStatus
                    );
                    List<AsyncApexJob> asyncApexJobs = new List<AsyncApexJob>();
                    if (!records.isEmpty()) {
                        asyncApexJobs = DomainUtils.getAsyncApexJobByApexClassNameAndStatus(
                                new Set<String>{ PostProcessor.BATCHES_BY_SOBJECT_TYPES.get(sObjType)?.get(context) },
                                GlobalVariables.APEX_JOB_STATUSES
                        );
                    }
                    if (!records.isEmpty() && asyncApexJobs.isEmpty()) {
                        String batchName = PostProcessor.BATCHES_BY_SOBJECT_TYPES.get(sObjType)?.get(context);
                        SourceDocumentBatchBase batchBase = String.isNotBlank(batchName)
                                ? (SourceDocumentBatchBase) Type.forName(batchName)?.newInstance()
                                : null;
                        if (batchBase != null) {
                            SourceDocumentBatchOptions options = null;
                            if (PostProcessor.ONLY_ONE_BY_ONE.contains(selectedSObjectType)) {
                                options = new SourceDocumentBatchOptions(
                                        context,
                                        sObjType,
                                        new Set<String>{inProgressStatus}
                                );
                            } else if (PostProcessor.ONLY_POST_OR_UNPOST.contains(selectedSObjectType)) {
                                options = new SourceDocumentBatchOptions(new Map<Id, SObject>(records).keySet());
                                options.setCurrentContext(context);
                            }
                            Database.executeBatch(
                                    batchBase.options(options),
                                    sObjType == Billing__c.getSObjectType()
                                            ? PostProcessor.BATCH_CHUNK_SIZE_WITH_API_CALLOUT
                                            : PostProcessor.BATCH_CHUNK_SIZE
                            );
                        }
                        return;
                    }
                }
            }
        }
    }

    public abstract List<PostResult> processSourceDocumentData(List<LDVPostInput> inputs);
    public abstract void callNextBatch();
    public virtual void setScheduledPostMasterRecords() {}
    public virtual void setSourceRecordsStatusAfterException(Set<Id> failedRecordsId) {
        if (options.isAllowUpdateStatus()) {
            setPostingStatusAfterException(failedRecordsId, headerSObjectType);
        }
    }

    protected void setPostingStatusAfterException(Set<Id> failedRecordsId, Schema.SObjectType sourceSObjectType) {
        helper.setPostingStatus(
            new List<Id> (failedRecordsId),
            options.currentContext() == SourceDocumentBatchOptions.ExecutionContext.POST
                ? AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED
                : AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
            sourceSObjectType,
            new Set<String>{
                options.currentContext() == SourceDocumentBatchOptions.ExecutionContext.POST
                    ? AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED
                    : AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED
            }
        );
    }

    private void callDeleteBatch(Id jobId){
        Database.executeBatch(new DeleteTransactionsBatch(jobId, this.headerSObjectType));
    }

    private void logExceptionActivity(String errorMessage, Set<Id> failedRecordIds) {
        List<PostResult> failedResults = new List<PostResult>();
        for (Id recordId : failedRecordIds) {
            failedResults.add(
                new PostResult(
                    false,
                    recordId,
                    null,
                    new List<PostResult.PostErrorResult>{new PostResult.PostErrorResult(null, errorMessage)}
                )
            );
        }
        if (!failedResults.isEmpty()) {
            logOnActivity(failedResults);
        }
    }

    private void logOnActivity(List<PostResult> failedResults) {
        List<Task> tasks = new List<Task>();
        for (PostResult pr : failedResults) {
            tasks.add(
                FinancialSuiteUtils.setTask(
                    pr.id,
                    Label.COMMON_TASK_COMPLETED,
                    null,
                    options.currentContext() == SourceDocumentBatchOptions.ExecutionContext.POST
                        ? Label.COMMON_ERR_CANNOT_POST_RECORD
                        : Label.ERR_CANNOT_UNPOST_RECORD,
                    pr.errors[0].message,
                    null,
                    this.ajrId
                )
            );
        }

        if (!tasks.isEmpty()) {
            SFDCSecurityUtils.insertProxy(tasks);
        }
    }

    private void buildExecutionReport() {
        String objName = options.sourceSObjectType.getDescribe().getLabelPlural();
        String reportsProcessed = String.format(Label.ERR_AUTOMATED_JOB_RESULT_PROCESSED, new List<Object>{objName, options.total});
        String reportsFailed = String.format(Label.ERR_AUTOMATED_JOB_RESULT_FAILED, new List<Object>{objName, options.failed});
        AutomatedJobResultsHandler.addProcessed(options.total);
        Integer succeeded = options.total - options.failed;
        AutomatedJobResultsHandler.addSucceeded(succeeded);
        AutomatedJobResultsHandler.addFailed(options.failed);
        AutomatedJobResultsHandler.setError(reportsProcessed);
        AutomatedJobResultsHandler.setError(
            Label.COMMON_NUMBER_OF + ' ' + objName + ' ' +
                (options.currentContext() == SourceDocumentBatchOptions.ExecutionContext.UNPOST ? Label.COMMON_UNPOSTED : Label.COMMON_SMALL_POSTED) + ' ' + Label.COMMON_SUCCESSFULLY
                +': ' + succeeded
        );
        AutomatedJobResultsHandler.setError(reportsFailed);
        AutomatedJobResultsHandler.setError(AutomatedJobResultsHandler.getReportLink(
            String.format(options.jobName, new List<String> {
                (options.currentContext() == SourceDocumentBatchOptions.ExecutionContext.UNPOST ? Label.COMMON_UNPOST : Label.COMMON_POST)
            }) + objName
        ));
    }

    protected Boolean isEqualTransactionKey(String key, Transaction__c tr) {
        return new TransactionKey(tr).hashCode() == key;
    }

    protected void mergeOptions(SourceDocumentBatchOptions newOptions, SourceDocumentBatchOptions oldOptions) {
        newOptions.ajrId = oldOptions.ajrId;
        newOptions.total = oldOptions.total;
        newOptions.failed = oldOptions.failed;
        newOptions.jobName = oldOptions.jobName;
        newOptions.processInProgressStatuses = oldOptions.processInProgressStatuses;
    }

    public virtual with sharing class CurrentScopeState {
        @TestVisible
        private Schema.SObjectType headerSObjectType;
        @TestVisible
        protected String parentRelationshipField;
        private Map<Id, LDVPostInput> inputs;
        private Map<Id, Transaction_Group__c> groupMap;
        private Set<Id> inbound;
        private Set<Id> outbound;
        private Set<Id> failed;
        private Set<Id> updatePostingStatus;
        private Id prevId;
        private Id jobId;
        private Boolean isFailed;
        private Integer totalCount = 0;
        private Integer failedCount = 0;

        public CurrentScopeState(Schema.SObjectType headerSObjectType, String parentRelationshipField) {
            this.headerSObjectType = headerSObjectType;
            this.parentRelationshipField = parentRelationshipField;
            resetInputsMap();
            this.inbound = new Set<Id>();
            this.outbound = new Set<Id>();
            this.failed = new Set<Id>();
            this.groupMap = new Map<Id, Transaction_Group__c>();
            this.isFailed = false;
        }

        public void resetInputsMap() {
            inputs = new Map<Id, LDVPostInput>();
            updatePostingStatus = new Set<Id>();
        }

        public Boolean isFirstIteration() {
            return prevId == null;
        }

        public Boolean isRecordsToProcess() {
            return !inputs.values().isEmpty() && !inbound.isEmpty();
        }

        public Boolean isNeedUpdatePostingStatus() {
            for (Id recordId : updatePostingStatus) {
                if (groupMap.containsKey(recordId) && groupMap.get(recordId).Lines_Processed__c >= groupMap.get(recordId).Line_Count__c) {
                    updatePostingStatus.remove(recordId);
                }
            }
            return !updatePostingStatus.isEmpty();
        }

        public Boolean isNeedRunDeleteBatch() {
            return isFailed;
        }

        public void setInitValues(SObject obj, Id jobId, SourceDocumentBatchOptions.AccountingMethod accountingMethod) {
            this.jobId = jobId;
            prevId = (Id) obj.get(this.parentRelationshipField);
            inbound.add(prevId);
            groupMap.put(prevId, getTGObject(obj, this.jobId));
            updatePostingStatus.add(prevId);
            setLDVPostInput(obj);
            groupMap.get(prevId).Lines_Processed__c ++;
            totalCount = increaseTotalCount(obj, accountingMethod);
        }

        public void setCurrentValue(SObject obj, SourceDocumentBatchOptions.AccountingMethod accountingMethod) {
            Id iParentId = (Id)obj.get(this.parentRelationshipField);
            if(iParentId != prevId && !inbound.contains(iParentId)) {
                inbound.add(iParentId);
                outbound.add(prevId);
                if (!groupMap.containsKey(iParentId)) {
                    groupMap.put(iParentId, getTGObject(obj, jobId));
                    updatePostingStatus.add(iParentId);
                    totalCount = increaseTotalCount(obj, accountingMethod);
                }
            }

            if (groupMap.containsKey(iParentId)) {
                groupMap.get(iParentId).Lines_Processed__c ++;
            }
            prevId = iParentId;

            if (!failed.contains(iParentId)) {
                setLDVPostInput(obj);
            }
            if (failed.contains(iParentId) && inbound.contains(iParentId)) {
                inbound.remove(iParentId);
            }
        }

        private Integer increaseTotalCount(SObject obj, SourceDocumentBatchOptions.AccountingMethod accountingMethod) {
            Integer increaseTotalCount = totalCount + 1;
            if (headerSObjectType == Journal_Entry__c.getSObjectType()
                    && accountingMethod == SourceDocumentBatchOptions.AccountingMethod.CASH) {
                Id ledgerId = (Id)SourceDocumentBatchHelper.fetchRecordValue(obj, SourceDocumentBatchHelper.ledgerFieldBySobjectType.get(headerSObjectType));
                if (LedgerHandler.getInstanceWithoutSharing().getLedgerById(ledgerId).Accounting_Method__c == LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH) {
                    increaseTotalCount = totalCount;
                }
            }
            return increaseTotalCount;
        }

        public void setGroupMap(Map<Id, Transaction_Group__c> groupMap) {
            this.groupMap = groupMap;
        }

        public Map<Id, Transaction_Group__c> getGroupMap() {
            return groupMap;
        }

        public Set<Id> getInbound() {
            return inbound;
        }

        public Set<Id> getFailed() {
            return failed;
        }

        public Set<Id> getForUpdatePostingStatus() {
            return updatePostingStatus;
        }

        public List<LDVPostInput> getInputs() {
            return inputs.values();
        }

        public Integer getTotalCount() {
            return totalCount;
        }

        public Integer getFailedCount() {
            return failedCount;
        }

        public void addFailed(Id failedId) {
            isFailed = true;
            failed.add(failedId);
            if (inbound.contains(failedId)) {
                inbound.remove(failedId);
            }
            failedCount ++;
        }

        public void addCurrentInboundFailed() {
            isFailed = true;
            failed.addAll(inbound);
            failedCount += inbound.size();
            inbound.clear();
        }

        public void clearOutbound() {
            inbound.removeAll(outbound);
            failed.removeAll(outbound);
            outbound = new Set<Id>();
        }

        public Set<Id> getOutboundForDeleteTG() {
            Set<Id> outboundForDeleteTG = new Set<Id>();
            for (Id out : outbound) {
                if (!failed.contains(out)) {
                    outboundForDeleteTG.add(out);
                }
            }
            return outboundForDeleteTG;
        }

        public void removeFromGroupMap(Set<Id> removeIds) {
            for (Id removeId : removeIds) {
                if (groupMap.keySet().contains(removeId)) {
                    groupMap.remove(removeId);
                }
            }
        }

        public virtual Map<Id, Map<String, Object>> configurationsBySourceIds() {
            return new Map<Id, Map<String, Object>>();
        }

        protected virtual Transaction_Group__c getTGObject(SObject record, Id batchId) {
            Transaction_Group__c result = new Transaction_Group__c();
            result.Line_Count__c = 0;
            result.Lines_Processed__c = 0;
            result.Batch_Id__c = batchId;
            switch on this.headerSObjectType.newSobject() {
                when Billing__c objRecord {
                    result.Billing__c = (Id) record.get(this.parentRelationshipField);
                    result.Line_Count__c = ((Billing_Line__c) record).Billing__r.Line_Count__c;
                    result.Ledger__c = ((Billing_Line__c) record).Billing__r.Ledger__c;
                }
                when Account_Payable__c objRecord {
                    result.Account_Payable__c = (Id) record.get(this.parentRelationshipField);
                    result.Line_Count__c = ((Account_Payable_Line__c) record).Account_Payable__r.Line_Count__c;
                    result.Ledger__c = ((Account_Payable_Line__c) record).Account_Payable__r.Ledger__c;
                }
                when Cash_Receipt__c objRecord {
                    result.Cash_Receipt__c = (Id) record.Id;
                    result.Line_Count__c = 1;
                    result.Ledger__c = ((Cash_Receipt__c) record).Ledger__c;
                }
                when Cash_Disbursement__c objRecord {
                    result.Cash_Disbursement__c = (Id) record.Id;
                    result.Line_Count__c = 1;
                    result.Ledger__c = ((Cash_Disbursement__c) record).Ledger__c;
                }
                when Journal_Entry__c objRecord {
                    result.Journal_Entry__c = (Id) record.get(this.parentRelationshipField);
                    result.Line_Count__c = ((Journal_Entry_Line__c) record).Journal_Entry__r.Line_Count__c;
                    result.Ledger__c = ((Journal_Entry_Line__c) record).Journal_Entry__r.Ledger__c;
                }
                when Billing_Cash_Receipt__c objRecord {
                    result.Billing__c = (Id) record.get(this.parentRelationshipField);
                    result.Line_Count__c = ((Billing_Line__c) record).Billing__r.Line_Count__c;
                    result.Ledger__c = ((Billing_Line__c) record).Billing__r.Ledger__c;
                }
                when AP_Disbursement__c objRecord {
                    result.Account_Payable__c = (Id) record.get(this.parentRelationshipField);
                    result.Line_Count__c = ((Account_Payable_Line__c) record).Account_Payable__r.Line_Count__c;
                    result.Ledger__c = ((Account_Payable_Line__c) record).Account_Payable__r.Ledger__c;
                }
            }

            return result;
        }

        private void setLDVPostInput(SObject line) {
            Id iParentId = (Id) line.get(this.parentRelationshipField);
            if (inputs.containsKey(iParentId)) {
                inputs.get(iParentId).lines.add(line);
            }
            else {
                LDVPostInput input = new LDVPostInput(groupMap.get(iParentId));
                input.id = iParentId;
                input.lines.add(line);
                inputs.put(iParentId, input);
            }
        }

    }

    public with sharing class RoundingAdjustmentWrapper {
        private Schema.SObjectType masterSObjectType;
        public Decimal appliedAmount = 0;
        public Decimal foreignAppliedAmount = 0;
        private Decimal roundingCommon = 0;
        private Decimal foreignRoundingCommon = 0;
        private Decimal roundingBalance = 0;
        private Decimal foreignRoundingBalance = 0;
        private Decimal amountForUpdate = 0;
        private Decimal foreignAmountForUpdate = 0;
        public String transactionKeyForAdjust;
        public String oppositeTransactionKeyForAdjust;
        private Decimal transactionAmountForAdjust = 0;
        public Transaction__c transactionForAdjust;
        public Transaction__c oppositeTransactionForAdjust;
        public Boolean needUpdateTransaction = false;
        public Id llpGLAccountMarker;
        private Boolean llpForeignCurrency = false;

        public RoundingAdjustmentWrapper(List<Transaction__c> transactions, Decimal appliedAmount) {
            this.appliedAmount = appliedAmount;
            if (masterSObjectType == null && !transactions.isEmpty()) {
                masterSObjectType = transactions[0].Billing_Cash_Receipt__c != null ? Billing_Cash_Receipt__c.getSObjectType() : AP_Disbursement__c.getSObjectType();
            }

        }

        public void addBalance(List<Transaction__c> transactions) {
            for (Transaction__c tr : transactions) {
                if (isCashTransaction(tr) &&
                    (LedgerHandler.getInstanceWithoutSharing().isCashLedger(tr.Ledger__c)
                    || LedgerHandler.getInstanceWithoutSharing().isShadowLedger(tr.Ledger__c))) {
                    if (tr.Billing_Cash_Receipt__c != null
                        && isValidCommonCondition(masterSObjectType, tr)) {
                        addCommonTransaction(tr);
                    } else if (tr.Billing_Cash_Receipt__c != null && tr.Amount__c < 0) {
                        addBalanceTransaction(tr);
                    }

                    if (tr.AP_Disbursement__c != null
                        && isValidCommonCondition(masterSObjectType, tr)) {
                        addCommonTransaction(tr);
                    } else if (tr.AP_Disbursement__c != null && tr.Amount__c > 0) {
                        addBalanceTransaction(tr);
                    }
                        setTransactionForAdjust(tr);
                }

            }

            if (AccountingSettingsHandler.isLineLevelPost()) {
                for (Transaction__c tr : transactions) {
                    if ((LedgerHandler.getInstanceWithoutSharing().isCashLedger(tr.Ledger__c)
                        || LedgerHandler.getInstanceWithoutSharing().isShadowLedger(tr.Ledger__c))
                        && transactionAmountForAdjust != null
                        && isOppositeValue(transactionAmountForAdjust, tr.Amount__c)) {
                        oppositeTransactionKeyForAdjust = new TransactionKey(tr).hashCode();
                    }
                }
            }

        }

        private Boolean isValidCommonCondition(Schema.SObjectType masterSObjectType, Transaction__c tr) {
            Boolean result = false;
            if (AccountingSettingsHandler.isLineLevelPost()) {
                result = (tr.GL_Account__c == llpGLAccountMarker);
            } else if (masterSObjectType == Billing_Cash_Receipt__c.getSObjectType()) {
                result = tr.Amount__c > 0;
            } else {
                result = tr.Amount__c < 0;
            }

            return result;
        }

        public void adjustTransactionsBalance() {
            if (AccountingSettingsHandler.isHeaderLevelPost()) {
                adjustHLPTransactions();
            } else {
                adjustLLPTransactions();
            }
        }

        public void setAdjustTransaction() {
            if (transactionForAdjust != null) {
                transactionForAdjust.Amount__c += transactionForAdjust.Amount__c > 0 ? amountForUpdate : amountForUpdate * -1;
                if (transactionForAdjust.Foreign_Amount__c != null && AccountingSettingsHandler.isHeaderLevelPost()) {
                    transactionForAdjust.Foreign_Amount__c += transactionForAdjust.Foreign_Amount__c > 0 ?
                        foreignAmountForUpdate : foreignAmountForUpdate * -1;
                }
                if (AccountingSettingsHandler.isLineLevelPost()) {
                    if (transactionForAdjust.Foreign_Amount__c != null) {
                        transactionForAdjust.Foreign_Amount__c += transactionForAdjust.Foreign_Amount__c > 0 ?
                            foreignAmountForUpdate :
                            foreignAmountForUpdate * -1;
                    }

                    oppositeTransactionForAdjust.Amount__c += oppositeTransactionForAdjust.Amount__c > 0 ? amountForUpdate : amountForUpdate * -1;
                    if (oppositeTransactionForAdjust.Foreign_Amount__c != null) {
                        oppositeTransactionForAdjust.Foreign_Amount__c += oppositeTransactionForAdjust.Foreign_Amount__c > 0 ?
                            foreignAmountForUpdate :
                            foreignAmountForUpdate * -1;
                    }
                }
            }
        }

        private void adjustHLPTransactions() {
            if (transactionKeyForAdjust != null && Math.abs(roundingCommon) != Math.abs(roundingBalance)) {
                amountForUpdate += (Math.abs(roundingCommon) - Math.abs(roundingBalance));
                needUpdateTransaction = true;
            }
            if (transactionKeyForAdjust != null && Math.abs(foreignRoundingCommon) != Math.abs(foreignRoundingBalance)) {
                foreignAmountForUpdate += (Math.abs(foreignRoundingCommon) - Math.abs(foreignRoundingBalance));
                needUpdateTransaction = true;
            }
        }

        private void adjustLLPTransactions() {
            if (transactionKeyForAdjust != null && Math.abs(appliedAmount) != Math.abs(roundingCommon)) {
                amountForUpdate += (Math.abs(appliedAmount) - Math.abs(roundingCommon));
                needUpdateTransaction = true;
            }

            if (llpForeignCurrency && transactionKeyForAdjust != null && Math.abs(foreignAppliedAmount) != Math.abs(foreignRoundingCommon)) {
                foreignAmountForUpdate += (Math.abs(foreignAppliedAmount) - Math.abs(foreignRoundingCommon));
                needUpdateTransaction = true;
            }
        }

        private void addCommonTransaction(Transaction__c tr) {
            roundingCommon += tr.Amount__c;
            if (tr.Foreign_Amount__c != null ) {
                foreignRoundingCommon += tr.Foreign_Amount__c;
                llpForeignCurrency = true;
            }
        }

        private void addBalanceTransaction(Transaction__c tr) {
            roundingBalance += tr.Amount__c;
            if (tr.Foreign_Amount__c != null ) {
                foreignRoundingBalance += tr.Foreign_Amount__c;
                llpForeignCurrency = true;
            }
        }

        private void setTransactionForAdjust(Transaction__c tr) {
            if ((transactionKeyForAdjust == null || Math.abs(transactionAmountForAdjust) < Math.abs(tr.Amount__c))
                && isBalanceTransaction(tr)) {
                transactionAmountForAdjust = tr.Amount__c;
                transactionKeyForAdjust = new TransactionKey(tr).hashCode();
            }
        }

        private Boolean isBalanceTransaction(Transaction__c tr) {
            return (tr.Billing_Cash_Receipt__c != null
                && (AccountingSettingsHandler.isLineLevelPost() ? (tr.GL_Account__c != llpGLAccountMarker && tr.Amount__c < 0) : tr.Amount__c < 0))
                || (tr.AP_Disbursement__c != null
                && (AccountingSettingsHandler.isLineLevelPost() ? (tr.GL_Account__c != llpGLAccountMarker && tr.Amount__c > 0) : tr.Amount__c > 0));
        }

        private Boolean isOppositeValue(Decimal transactionAmountForAdjust, Decimal amount) {
            if (transactionAmountForAdjust >= 0 && amount <= 0 && transactionAmountForAdjust == Math.abs(amount)) {
                return true;
            } else if (transactionAmountForAdjust <= 0 && amount >= 0 && Math.abs(transactionAmountForAdjust) == amount) {
                return true;
            }
            return false;
        }

        private Boolean isCashTransaction(Transaction__c tr) {
            return (tr.Billing_Cash_Receipt__c != null && (tr.Billing__c != null || tr.Billing_Line__c != null))
                || (tr.AP_Disbursement__c != null && (tr.Account_Payable__c != null || tr.Account_Payable_Line__c != null));
        }
    }

}