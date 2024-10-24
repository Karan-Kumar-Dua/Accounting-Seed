public with sharing class BillingCashReceiptLDVPostBatch extends SourceDocumentBatchBase {

    private Map<Id, RoundingAdjustmentWrapper> roundingAdjustmentMap = new Map<Id, RoundingAdjustmentWrapper>();
    private Map<Id, Billing_Cash_Receipt__c> appliedAmountMap = new Map<Id, Billing_Cash_Receipt__c>();
    private Set<Id> currentMasterIds = new Set<Id>();

    public BillingCashReceiptLDVPostBatch(SourceDocumentBatchOptions options){
        super(Billing__c.getSObjectType(), options);
        this.options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.POST);
        masterSObjectType = Billing_Cash_Receipt__c.getSObjectType();
    }

    public BillingCashReceiptLDVPostBatch(Set<Id> recordIds) {
        super(Billing__c.getSObjectType(), new SourceDocumentBatchOptions(recordIds));
        this.options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.POST);
        this.options.addMasterRecordIds(recordIds);
        masterSObjectType = Billing_Cash_Receipt__c.getSObjectType();
    }

    public BillingCashReceiptLDVPostBatch() {
        super(Billing__c.getSObjectType(), new SourceDocumentBatchOptions(SourceDocumentBatchOptions.ExecutionContext.POST, Billing_Cash_Receipt__c.getSObjectType()));
        this.options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.POST);
        masterSObjectType = Billing_Cash_Receipt__c.getSObjectType();
    }

    public override void callNextBatch(){
        BillingCashReceiptLDVPostBatch bcrBatch = new BillingCashReceiptLDVPostBatch(this.options);
        if (this.isScheduledPostJob) {
            bcrBatch.isScheduledPostJob(this.isScheduledPostJob)
                .currentSourceRecordType(this.currentSourceRecordType)
                .schedSourceRecordTypes(this.schedSourceRecordTypes);
        }
        Database.executeBatch(bcrBatch);
    }

    public override void setScheduledPostMasterRecords(){
        Set<Id> recordIds = getApprovedBCRIds();
        SourceDocumentBatchOptions opt = new SourceDocumentBatchOptions(recordIds);
        opt.setSourceSObjectType(Billing_Cash_Receipt__c.getSObjectType());
        if (this.options != null) {
            mergeOptions(opt, this.options);
        }
        this.options = opt;
        this.options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.POST);
        this.options.addMasterRecordIds(recordIds);
        masterSObjectType = Billing_Cash_Receipt__c.getSObjectType();
        this.headerIds = this.options.getCurrentContextSourceIds();
    }

    public override void setSourceRecordsStatusAfterException(Set<Id> failedRecordsId){
        setPostingStatusAfterException(currentMasterIds, masterSObjectType);
    }

    public override List<PostResult> processSourceDocumentData(List<LDVPostInput> scope){
        init(this.options.getMasterRecordIds(), scope);
        return accrualAndCashPost(scope);
    }

    private List<PostResult> accrualAndCashPost(List<LDVPostInput> scope) {
        BillingCashReceiptPostHandler bph = new BillingCashReceiptPostHandler();
        List<PostResult> resultsForProcess = new List<PostResult>();
        List<PostResult> results = bph.post(scope);
        for (PostResult res : results) {
            if (res.isSuccess) {
                resultsForProcess.add(res);
                addRoundingBalance(res, bph);
                if (res.transactionGroup.Line_Count__c == res.transactionGroup.Lines_Processed__c) {
                    this.options.removeMasterRecordId(res.id);
                    if (roundingAdjustmentMap.containsKey(res.id)) {
                        roundingAdjustmentMap.get(res.id).adjustTransactionsBalance();
                    }
                }
            }
        }
        if (!resultsForProcess.isEmpty()) {
            bph.processLDVPostTransactionConsolidation(resultsForProcess);
        }
        updateRoundingBalance(bph);
        return results;
    }

    private void init(Set<Id> recordIds, List<LDVPostInput> scope) {
        currentMasterIds = new Set<Id>();
        Set<Id> outstandingBCRIds = new Set<Id>();
        Map<Id, List<Billing_Cash_Receipt__c>> bcrMap = new Map<Id, List<Billing_Cash_Receipt__c>>();
        for (Billing_Cash_Receipt__c bcr : DomainUtils.getBillingCashReceiptsByIdOrderByPeriod(recordIds)) {
            appliedAmountMap.put(bcr.Id, bcr);
            if (!bcrMap.containsKey(bcr.Billing__c)) {
                bcrMap.put(bcr.Billing__c, new List<Billing_Cash_Receipt__c> {bcr});
                currentMasterIds.add(bcr.Id);
            } else {
                if (bcrMap.get(bcr.Billing__c)[bcrMap.get(bcr.Billing__c).size() - 1].CreatedDate == bcr.CreatedDate) {
                    bcrMap.get(bcr.Billing__c).add(bcr);
                    currentMasterIds.add(bcr.Id);
                } else {
                    outstandingBCRIds.add(bcr.Id);
                }
            }
        }

        for (LDVPostInput input : scope) {
            if (bcrMap.containsKey(input.id)) {
                input.relatedObjects = bcrMap.get(input.id);
            }
        }

        this.options.addMasterRecordIds(outstandingBCRIds);
    }

    private Set<Id> getApprovedBCRIds() {
        String status = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED;
        List<String> queryFields = new List<String> {
            'Id'
        };
        String queryCondition =
            'Status__c = :status LIMIT 10000';

        SOQLBuilder theQuery = new SOQLBuilder(Billing_Cash_Receipt__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);
        return new Map<Id, Billing_Cash_Receipt__c> ((List<Billing_Cash_Receipt__c>) Database.query(theQuery.toSOQL())).keySet();
    }

    private void addRoundingBalance(PostResult res, BillingCashReceiptPostHandler bph) {
        if (roundingAdjustmentMap.containsKey(res.id)) {
            roundingAdjustmentMap.get(res.id).addBalance(res.transactions);
        } else {
            RoundingAdjustmentWrapper raw = new RoundingAdjustmentWrapper(res.transactions, appliedAmountMap.get(res.id).Applied_Amount__c);
            if (AccountingSettingsHandler.isLineLevelPost()) {
                raw.llpGLAccountMarker = bph.getCashCreditGLAccount(appliedAmountMap.get(res.id));
                if (!res.transactions.isEmpty() && res.transactions[0].Foreign_Amount__c != null) {
                    raw.appliedAmount = bph.getAppliedAmountInLedgerCurrency(appliedAmountMap.get(res.id));
                    raw.foreignAppliedAmount = appliedAmountMap.get(res.id).Applied_Amount__c;
                }
            }
            raw.addBalance(res.transactions);
            roundingAdjustmentMap.put(res.id, raw);
        }

    }

    private void updateRoundingBalance(BillingCashReceiptPostHandler bph) {
        List<Transaction__c> trForUpdate = new List<Transaction__c>();
        Set<String> transactionKeys = new Set<String>();
        for (RoundingAdjustmentWrapper rw : roundingAdjustmentMap.values()) {
            if (rw.needUpdateTransaction) {
                transactionKeys.add(rw.transactionKeyForAdjust);
                if (AccountingSettingsHandler.isLineLevelPost()) {
                    transactionKeys.add(rw.oppositeTransactionKeyForAdjust);
                }
            }
        }
        if (!transactionKeys.isEmpty()) {
            for (Transaction__c tr : bph.getExistedTransactionByKeys(transactionKeys)) {
                if (roundingAdjustmentMap.containsKey(tr.Billing_Cash_Receipt__c)) {
                    if (roundingAdjustmentMap.get(tr.Billing_Cash_Receipt__c).transactionForAdjust == null
                        && isEqualTransactionKey(roundingAdjustmentMap.get(tr.Billing_Cash_Receipt__c).transactionKeyForAdjust, tr)) {
                        roundingAdjustmentMap.get(tr.Billing_Cash_Receipt__c).transactionForAdjust = tr;
                    }
                    if (AccountingSettingsHandler.isLineLevelPost()
                        && roundingAdjustmentMap.get(tr.Billing_Cash_Receipt__c).oppositeTransactionForAdjust == null
                        && isEqualTransactionKey(roundingAdjustmentMap.get(tr.Billing_Cash_Receipt__c).oppositeTransactionKeyForAdjust, tr)) {
                        roundingAdjustmentMap.get(tr.Billing_Cash_Receipt__c).oppositeTransactionForAdjust = tr;
                    }
                }
            }
            for (RoundingAdjustmentWrapper rw : roundingAdjustmentMap.values()) {
                if (rw.needUpdateTransaction) {
                    rw.setAdjustTransaction();
                    trForUpdate.add(rw.transactionForAdjust);
                    if (AccountingSettingsHandler.isLineLevelPost()) {
                        trForUpdate.add(rw.oppositeTransactionForAdjust);
                    }
                    rw.needUpdateTransaction = false;
                }
            }

            if (!trForUpdate.isEmpty()) {
                try {
                    TransactionActions.isPreventUpdateOverride = true;
                    SFDCSecurityUtils.updateProxy(trForUpdate);
                    TransactionActions.isPreventUpdateOverride = false;
                } catch (Exception e) {}
            }
        }
    }
}