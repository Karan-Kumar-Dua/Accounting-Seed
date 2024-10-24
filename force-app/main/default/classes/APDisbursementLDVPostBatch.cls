public with sharing class APDisbursementLDVPostBatch extends SourceDocumentBatchBase {

    private Map<Id, RoundingAdjustmentWrapper> roundingAdjustmentMap = new Map<Id, RoundingAdjustmentWrapper>();
    private Map<Id, AP_Disbursement__c> paidAmountMap = new Map<Id, AP_Disbursement__c>();
    private Set<Id> currentMasterIds = new Set<Id>();

    public APDisbursementLDVPostBatch(SourceDocumentBatchOptions options){
        super(Account_Payable__c.getSObjectType(), options);
        this.options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.POST);
        masterSObjectType = AP_Disbursement__c.getSObjectType();
    }

    public APDisbursementLDVPostBatch(Set<Id> payableIds) {
        super(Account_Payable__c.getSObjectType(), new SourceDocumentBatchOptions(payableIds));
        options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.POST);
        this.options.addMasterRecordIds(payableIds);
        masterSObjectType = AP_Disbursement__c.getSObjectType();
    }

    public APDisbursementLDVPostBatch() {
        super(Account_Payable__c.getSObjectType(), new SourceDocumentBatchOptions(SourceDocumentBatchOptions.ExecutionContext.POST, AP_Disbursement__c.getSObjectType()));
        options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.POST);
        masterSObjectType = AP_Disbursement__c.getSObjectType();
    }

    public override void callNextBatch(){
        APDisbursementLDVPostBatch apdBatch = new APDisbursementLDVPostBatch(this.options);
        if (this.isScheduledPostJob) {
            apdBatch.isScheduledPostJob(this.isScheduledPostJob)
                .currentSourceRecordType(this.currentSourceRecordType)
                .schedSourceRecordTypes(this.schedSourceRecordTypes);
        }
        Database.executeBatch(apdBatch);
    }

    public override void setScheduledPostMasterRecords(){
        Set<Id> recordIds = getApprovedAPDIds();
        SourceDocumentBatchOptions opt = new SourceDocumentBatchOptions(recordIds);
        opt.setSourceSObjectType(AP_Disbursement__c.getSObjectType());
        if (this.options != null) {
            mergeOptions(opt, this.options);
        }
        this.options = opt;
        this.options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.POST);
        this.options.addMasterRecordIds(recordIds);
        masterSObjectType = AP_Disbursement__c.getSObjectType();
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
        APDisbursementPostHandler aph = new APDisbursementPostHandler();
        List<PostResult> resultsForProcess = new List<PostResult>();
        List<PostResult> results = aph.post(scope);
        for (PostResult res : results) {
            if (res.isSuccess) {
                resultsForProcess.add(res);
                addRoundingBalance(res, aph);
                if (res.transactionGroup.Line_Count__c == res.transactionGroup.Lines_Processed__c) {
                    this.options.removeMasterRecordId(res.id);
                    if (roundingAdjustmentMap.containsKey(res.id)) {
                        roundingAdjustmentMap.get(res.id).adjustTransactionsBalance();
                    }
                }
            }
        }
        if (!resultsForProcess.isEmpty()) {
            aph.processLDVPostTransactionConsolidation(resultsForProcess);
        }
        updateRoundingBalance(aph);
        return results;
    }

    private void init(Set<Id> recordIds, List<LDVPostInput> scope) {
        currentMasterIds = new Set<Id>();
        Set<Id> outstandingAPDIds = new Set<Id>();
        Map<Id, List<AP_Disbursement__c>> apdMap = new Map<Id, List<AP_Disbursement__c>>();
        for (AP_Disbursement__c apd : DomainUtils.getApDisbursementsByIdOrderByPeriod(recordIds)) {
            paidAmountMap.put(apd.Id, apd);
            if (!apdMap.containsKey(apd.Account_Payable__c)) {
                apdMap.put(apd.Account_Payable__c, new List<AP_Disbursement__c> {apd});
                currentMasterIds.add(apd.Id);
            } else {
                if (apdMap.get(apd.Account_Payable__c)[apdMap.get(apd.Account_Payable__c).size() - 1].CreatedDate == apd.CreatedDate) {
                    apdMap.get(apd.Account_Payable__c).add(apd);
                    currentMasterIds.add(apd.Id);
                } else {
                    outstandingAPDIds.add(apd.Id);
                }
            }
        }

        for (LDVPostInput input : scope) {
            if (apdMap.containsKey(input.id)) {
                input.relatedObjects = apdMap.get(input.id);
            }
        }

        this.options.addMasterRecordIds(outstandingAPDIds);
    }

    private Set<Id> getApprovedAPDIds() {
        String status = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED;
        String source = AccountPayablePaymentHandler.CD_SOURCE_PAYABLE;

        List<String> queryFields = new List<String> {
            'Id',
            'Cash_Disbursement__r.Source__c'
        };
        String queryCondition =
            'Status__c = :status AND Cash_Disbursement__r.Source__c != :source LIMIT 10000';

        SOQLBuilder theQuery = new SOQLBuilder(AP_Disbursement__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);
        return new Map<Id, AP_Disbursement__c> ((List<AP_Disbursement__c>) Database.query(theQuery.toSOQL())).keySet();
    }

    private void addRoundingBalance(PostResult res, APDisbursementPostHandler aph) {
        if (roundingAdjustmentMap.containsKey(res.id)) {
            roundingAdjustmentMap.get(res.id).addBalance(res.transactions);
        } else {
            Decimal appliedAmount = paidAmountMap.get(res.id).Paid_Amount__c + paidAmountMap.get(res.id).Discount_Amount__c;
            RoundingAdjustmentWrapper raw = new RoundingAdjustmentWrapper(res.transactions, appliedAmount);
            if (AccountingSettingsHandler.isLineLevelPost()) {
                raw.llpGLAccountMarker = aph.getCashDebitGLAccount(paidAmountMap.get(res.id));
                if (!res.transactions.isEmpty() && res.transactions[0].Foreign_Amount__c != null) {
                    raw.appliedAmount = aph.getAppliedAmountInLedgerCurrency(paidAmountMap.get(res.id));
                    raw.foreignAppliedAmount = paidAmountMap.get(res.id).Paid_Amount__c + paidAmountMap.get(res.id).Discount_Amount__c;
                }
            }
            raw.addBalance(res.transactions);
            roundingAdjustmentMap.put(res.id, raw);
        }
    }

    private void updateRoundingBalance(APDisbursementPostHandler aph) {
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
            for (Transaction__c tr : aph.getExistedTransactionByKeys(transactionKeys)) {
                if (roundingAdjustmentMap.containsKey(tr.AP_Disbursement__c)) {
                    if (roundingAdjustmentMap.get(tr.AP_Disbursement__c).transactionForAdjust == null
                        && isEqualTransactionKey(roundingAdjustmentMap.get(tr.AP_Disbursement__c).transactionKeyForAdjust, tr)) {
                        roundingAdjustmentMap.get(tr.AP_Disbursement__c).transactionForAdjust = tr;
                    }
                    if (AccountingSettingsHandler.isLineLevelPost()
                        && roundingAdjustmentMap.get(tr.AP_Disbursement__c).oppositeTransactionForAdjust == null
                        && isEqualTransactionKey(roundingAdjustmentMap.get(tr.AP_Disbursement__c).oppositeTransactionKeyForAdjust, tr)) {
                        roundingAdjustmentMap.get(tr.AP_Disbursement__c).oppositeTransactionForAdjust = tr;
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