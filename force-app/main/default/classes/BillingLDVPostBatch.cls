public with sharing class BillingLDVPostBatch extends SourceDocumentBatchBase {

    public BillingLDVPostBatch(SourceDocumentBatchOptions options){
        super(Billing__c.getSObjectType(), options);
        this.scopeState = AccountingSettingsHandler.isLineLevelPost()
                ? new BillingScopeState(this.headerSObjectType, this.parentRelationshipField, SourceDocumentBatchOptions.ExecutionContext.POST)
                : this.scopeState;
        this.options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.POST);
    }

    public BillingLDVPostBatch(Set<Id> billingIds) {
        super(Billing__c.getSObjectType(), new SourceDocumentBatchOptions(billingIds));
        this.scopeState = AccountingSettingsHandler.isLineLevelPost()
                ? new BillingScopeState(this.headerSObjectType, this.parentRelationshipField, SourceDocumentBatchOptions.ExecutionContext.POST)
                : this.scopeState;
        options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.POST);
    }

    public BillingLDVPostBatch() {
        super(Billing__c.getSObjectType(), new SourceDocumentBatchOptions(SourceDocumentBatchOptions.ExecutionContext.POST, Billing__c.getSObjectType()));
        this.scopeState = AccountingSettingsHandler.isLineLevelPost()
                ? new BillingScopeState(this.headerSObjectType, this.parentRelationshipField, SourceDocumentBatchOptions.ExecutionContext.POST)
                : this.scopeState;
        options.setCurrentContext(SourceDocumentBatchOptions.ExecutionContext.POST);
    }

    public override void execute(Database.BatchableContext ctx, List<SObject> scope) {
        this.scopeState = presetConfigurations(scope, this.scopeState);
        super.execute(ctx, scope);
    }

    public static CurrentScopeState presetConfigurations(List<SObject> scope, CurrentScopeState scopeState) {
        if (AccountingSettingsHandler.isLineLevelPost()) {
            Set<Id> sourceIds = new Set<Id>();
            for (SObject line : scope) {
                if (((Billing_Line__c) line).Billing__r.Ledger__r.Tax_Settings__r.Tax_Settings_Method__c == TaxSettingsActions.AVA_TAX_METHOD) {
                    sourceIds.add((Id)line.get(Billing_Line__c.Billing__c));
                }
            }
            List<String> conditions = new List<String>{
                    String.valueOf(Billing_Line__c.Tax_Line__c) + ' = false',
                    String.valueOf(Billing_Line__c.Billing__c) + ' =: arg0'
            };
            if (!sourceIds.isEmpty()) {
                List<AggregateResult> aggregateResults = DomainUtils.recordsByConditions(
                        Billing_Line__c.SObjectType,
                        new List<String>{'Count(Id) c0unt', String.valueOf(Billing_Line__c.Billing__c) + ' sourceId'},
                        String.join(conditions, ' AND ') + ' GROUP BY ' + String.valueOf(Billing_Line__c.Billing__c),
                        new List<Object>{sourceIds}
                );
                for (AggregateResult result : aggregateResults) {
                    scopeState.configurationsBySourceIds().put(
                            (Id)result.get('sourceId'),
                            new Map<String, Object>{'c0unt' => (Integer)result.get('c0unt')}
                    );
                }
            }
        }

        return scopeState;
    }

    public override void callNextBatch(){
        Database.executeBatch(new BillingLDVPostBatch(this.options));
    }

    public override List<PostResult> processSourceDocumentData(List<LDVPostInput> scope){
        List<PostResult> results = new List<PostResult>();
        if (this.options.currentAccountingMethod() == SourceDocumentBatchOptions.AccountingMethod.CASH) {
            results = cashPost(scope);
        }
        else {
            results = accrualPost(scope);
        }
        return results;
    }

    private List<PostResult> accrualPost(List<LDVPostInput> scope) {
        BillingPostHandler bph = new BillingPostHandler();
        List<PostResult> resultsForProcess = new List<PostResult>();
        BillingLineActions.isLDVSourceBatchInProgress = true;
        List<PostResult> results = bph.post(scope);
        for (PostResult res : results) {
            if (res.isSuccess) {
                resultsForProcess.add(res);
            }
        }
        if (!resultsForProcess.isEmpty()) {
            bph.processLDVPostBillingsTransaction(resultsForProcess);
        }
        BillingLineActions.isLDVSourceBatchInProgress = false;
        return results;
    }

    private List<PostResult> cashPost(List<LDVPostInput> scope) {
        return new BillingPostHandlerCash().post(scope);
    }

    public class BillingScopeState extends CurrentScopeState {
        private SourceDocumentBatchOptions.ExecutionContext context;

        public BillingScopeState(Schema.SObjectType headerSObjectType, String parentRelationshipField, SourceDocumentBatchOptions.ExecutionContext context) {
            super(headerSObjectType, parentRelationshipField);
            this.context = context;
        }
        public BillingScopeState(Schema.SObjectType headerSObjectType, String parentRelationshipField) {
            super(headerSObjectType, parentRelationshipField);
        }

        private final Map<Id, Map<String, Object>> configurationsBySourceIds = new Map<Id, Map<String, Object>>();

        public override Map<Id, Map<String, Object>> configurationsBySourceIds() {
            return configurationsBySourceIds;
        }

        protected override Transaction_Group__c getTGObject(SObject record, Id batchId) {
            Transaction_Group__c transactionGroup = super.getTGObject(record, batchId);
            Integer lineCount = (Integer)configurationsBySourceIds.get((Id) record.get(this.parentRelationshipField))?.get('c0unt');
            if (AccountingSettingsHandler.isLineLevelPost()
                    && this.context == SourceDocumentBatchOptions.ExecutionContext.POST
                    && lineCount != null
                    && ((Billing_Line__c) record).Billing__r.Ledger__r.Tax_Settings__r.Tax_Settings_Method__c == TaxSettingsActions.AVA_TAX_METHOD) {
                transactionGroup.Line_Count__c = lineCount;
            }
            return transactionGroup;
        }
    }
}