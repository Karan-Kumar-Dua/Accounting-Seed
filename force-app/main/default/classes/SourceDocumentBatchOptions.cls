public with sharing class SourceDocumentBatchOptions {

    public static final Map<Schema.SObjectType, Schema.SObjectField> mChildRelationship = new Map<Schema.SObjectType, Schema.SObjectField>{
        Billing__c.getSObjectType() => Billing__c.Id,
        Account_Payable__c.getSObjectType() => Account_Payable__c.Id,
        Cash_Receipt__c.getSObjectType() => Cash_Receipt__c.Id,
        Journal_Entry__c.getSObjectType() => Journal_Entry__c.Id,
        Billing_Cash_Receipt__c.getSObjectType() => Billing_Cash_Receipt__c.Billing__c,
        Cash_Disbursement__c.getSObjectType() => Cash_Disbursement__c.Id,
        AP_Disbursement__c.getSObjectType() => AP_Disbursement__c.Account_Payable__c
    };

    public static final Set<SObjectType> SKIP_CASH_HANDLER_BATCH = new Set<SObjectType>{
            Billing__c.SObjectType,
            Account_Payable__c.SObjectType,
            Cash_Disbursement__c.SObjectType
    };

    public Schema.SObjectType sourceSObjectType;
    @TestVisible
    private Set<Id> sourceIds;
    private Set<Id> masterRecordIds = new Set<Id>();
    private Map<AccountingMethod, Set<Id>> sourcesByMethod;
    @TestVisible
    private AccountingMethod currentMethod;
    private Set<AccountingMethod> methods;
    @TestVisible
    private ExecutionContext context;
    public String jobName = 'Large Data Volume {0} Job';
    public Integer total = 0;
    public Integer failed = 0;
    public Set<String> processInProgressStatuses;
    public Id ajrId;

    public enum AccountingMethod {
        ACCRUAL,
        CASH
    }

    public enum ExecutionContext {
        POST,
        UNPOST
    }

    public SourceDocumentBatchOptions(ExecutionContext context, Schema.SObjectType sourceSObjectType, Set<String> processInProgressStatuses) {
        this.sourceSObjectType = sourceSObjectType;
        this.sourcesByMethod = new Map<AccountingMethod, Set<Id>>();
        this.context = context;
        this.methods = new Set<AccountingMethod>();
        this.processInProgressStatuses = processInProgressStatuses;
        populateAccountingMethod();
    }

    public SourceDocumentBatchOptions(ExecutionContext context, Schema.SObjectType sourceSObjectType) {
        this.sourceSObjectType = sourceSObjectType;
        this.sourcesByMethod = new Map<AccountingMethod, Set<Id>>();
        this.context = context;
        this.methods = new Set<AccountingMethod>();
        populateAccountingMethod();
    }

    public SourceDocumentBatchOptions(Set<Id> sourceIds) {
        this.sourceIds = sourceIds;
        this.sourcesByMethod = new Map<AccountingMethod, Set<Id>>();
        this.methods = new Set<AccountingMethod>();
        if (!sourceIds.isEmpty()) {
            this.sourceSObjectType = new List<Id> (this.sourceIds)[0].getSobjectType();
            populateSourcesByAccountingMethod();
        }
    }

    private void populateAccountingMethod() {
        for (AggregateResult res : queryMethodsByContext()) {
            String acctMethod = (String) res.get('acctMethod');
            acctMethod = String.isNotBlank(acctMethod) ? acctMethod : LedgerActions.ACCOUNTING_METHOD_ACCRUAL;

            if (acctMethod == LedgerActions.ACCOUNTING_METHOD_ACCRUAL) {
                methods.add(AccountingMethod.ACCRUAL);
            }
            else if (acctMethod == LedgerActions.ACCOUNTING_METHOD_CASH) {
                methods.add(AccountingMethod.CASH);
            }
            else {
                methods.add(AccountingMethod.ACCRUAL);
                if (!SKIP_CASH_HANDLER_BATCH.contains(this.sourceSObjectType)) {
                    methods.add(AccountingMethod.CASH);
                }
            }
        }
        setNext();

    }

    private void populateSourcesByAccountingMethod() {
        populateSourceByMethodMap();
        methods = sourcesByMethod.keySet().clone();
        setNext();
    }

    private void populateSourceByMethodMap() {
        for (Sobject obj : querySObject()) {
            String acctMethod = accountingMethodBySobject(obj);
            acctMethod = String.isNotBlank(acctMethod) ? acctMethod : LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            if (acctMethod == LedgerActions.ACCOUNTING_METHOD_ACCRUAL) {
                addAccrualSourceId((Id) obj.get(mChildRelationship.get(sourceSObjectType)));
            }
            else if (acctMethod == LedgerActions.ACCOUNTING_METHOD_CASH) {
                addCashSourceId((Id) obj.get(mChildRelationship.get(sourceSObjectType)));
            }
            else {
                addAccrualSourceId((Id) obj.get(mChildRelationship.get(sourceSObjectType)));
                if (!SKIP_CASH_HANDLER_BATCH.contains(this.sourceSObjectType)) {
                    addCashSourceId((Id) obj.get(mChildRelationship.get(sourceSObjectType)));
                }
            }
        }
    }

    private void addCashSourceId(Id objId) {
        if (sourcesByMethod.containsKey(AccountingMethod.CASH)) {
            sourcesByMethod.get(AccountingMethod.CASH).add(objId);
        }
        else {
            sourcesByMethod.put(AccountingMethod.CASH, new Set<Id> {objId});
        }
    }

    private void addAccrualSourceId(Id objId) {
        if (sourcesByMethod.containsKey(AccountingMethod.ACCRUAL)) {
            sourcesByMethod.get(AccountingMethod.ACCRUAL).add(objId);
        }
        else {
            sourcesByMethod.put(AccountingMethod.ACCRUAL, new Set<Id> {objId});
        }
    }

    public void setSourceSObjectType(Schema.SObjectType sourceSObjectType) {
        this.sourceSObjectType = sourceSObjectType;
    }

    public Boolean hasNext() {
        return (sourceSObjectType == Billing_Cash_Receipt__c.getSObjectType() || sourceSObjectType == AP_Disbursement__c.getSObjectType()) ?
            !masterRecordIds.isEmpty() : !methods.isEmpty();
    }

    public void setNext() {
        if (!(sourceSObjectType == Billing_Cash_Receipt__c.getSObjectType() || sourceSObjectType == AP_Disbursement__c.getSObjectType()) && !methods.isEmpty()) {
            currentMethod = methods.contains(AccountingMethod.ACCRUAL) ? AccountingMethod.ACCRUAL : new List<AccountingMethod>(methods)[0];
            methods.remove(currentMethod);
        }
    }

    public Boolean isAllowUpdateStatus() {
        return !(sourceSObjectType == Billing_Cash_Receipt__c.getSObjectType() || sourceSObjectType == AP_Disbursement__c.getSObjectType());
    }

    public AccountingMethod currentAccountingMethod() {
        return currentMethod;
    }

    public ExecutionContext currentContext() {
        return context;
    }

    public void setCurrentContext(ExecutionContext context) {
        this.context = context;
    }

    public Set<Id> getCurrentContextSourceIds() {
        Set<Id> result = new Set<Id>();
        if (sourceSObjectType == Billing_Cash_Receipt__c.getSObjectType() || sourceSObjectType == AP_Disbursement__c.getSObjectType()) {
            for (Set<Id> ids : sourcesByMethod.values()) {
                result.addAll(ids);
            }
        } else if (!sourcesByMethod.isEmpty() && sourcesByMethod.containsKey(currentMethod)) {
            result = sourcesByMethod.get(currentMethod);
        }
        return result;
    }

    public void setCurrentContextSourceIds(Set<Id> sourceIds) {
        if (!sourcesByMethod.isEmpty() && sourcesByMethod.containsKey(currentMethod)) {
            sourcesByMethod.put(currentMethod, sourceIds);
        }
    }

    public void removeFailed(Set<Id> failedSourceIds) {
        if (!sourcesByMethod.isEmpty() && sourcesByMethod.containsKey(currentMethod)) {
            sourcesByMethod.get(currentMethod).removeAll(failedSourceIds);
        }
    }

    public void removeFailed(Id failedSourceId) {
        if (!sourcesByMethod.isEmpty() && sourcesByMethod.containsKey(currentMethod)) {
            sourcesByMethod.get(currentMethod).remove(failedSourceId);
        }
    }

    public Boolean isValidForCurrentMethod(Id ledgerId) {
        Boolean result = false;
        String acctMethod = LedgerHandler.getLedgerAccountingMethod(ledgerId);
        acctMethod = String.isNotBlank(acctMethod) ? acctMethod : LedgerActions.ACCOUNTING_METHOD_ACCRUAL;

        if ((acctMethod == LedgerActions.ACCOUNTING_METHOD_ACCRUAL && currentAccountingMethod() == AccountingMethod.ACCRUAL)
            || (acctMethod == LedgerActions.ACCOUNTING_METHOD_CASH && currentAccountingMethod() == AccountingMethod.CASH)
            || isValidForCurrentSobjectType(acctMethod)) {
            result = true;
        }
        return result;
    }

    private Boolean isValidForCurrentSobjectType(String acctMethod) {
        return acctMethod == LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH
            && (currentAccountingMethod() == AccountingMethod.ACCRUAL
            || (currentAccountingMethod() == AccountingMethod.CASH && sourceSObjectType != Journal_Entry__c.getSObjectType()));
    }

    public void addMasterRecordIds(Set<Id> masterRecordIds) {
        this.masterRecordIds.addAll(masterRecordIds);
    }

    public void addMasterRecordIds() {
        if (sourceIds != null) {
            this.masterRecordIds.addAll(sourceIds);
        }
    }

    public void removeAllMasterRecordIds() {
        this.masterRecordIds.clear();
    }

    public void removeMasterRecordId(Id masterRecordId) {
        if (this.masterRecordIds != null && this.masterRecordIds.contains(masterRecordId)) {
            this.masterRecordIds.remove(masterRecordId);
        }
    }

    public Set<Id> getMasterRecordIds() {
        return this.masterRecordIds;
    }

    private String accountingMethodBySobject(Sobject obj) {
        if (this.sourceSObjectType == AP_Disbursement__c.getSObjectType()) {
            return (String) obj.getSObject('Account_Payable__r').getSObject('Ledger__r').get('Accounting_Method__c');
        }
        else if (this.sourceSObjectType == Billing_Cash_Receipt__c.getSObjectType()) {
            return (String) obj.getSObject('Billing__r').getSObject('Ledger__r').get('Accounting_Method__c');
        }
        return (String) obj.getSObject('Ledger__r').get('Accounting_Method__c');
    }

    private List<SObject> querySObject() {
        List<String> fieldsToQuery = new List<String> {
            'Id',
            getLedgerPattern(),
            getCustomFieldPattern()
        };
        String queryCondition = 'Id IN :sourceIds';
        String dynamicSOQL = SOQLBuilder.buildDynamicSoqlQuery(
            fieldsToQuery,
            null,
            this.sourceSObjectType,
            queryCondition,
            false,
            false
        );
        return (List<SObject>) Database.query(dynamicSOQL);
    }

    private List<AggregateResult> queryMethodsByContext() {
        String status = context == SourceDocumentBatchOptions.ExecutionContext.POST
                ? AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED
                : AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED;
        if (processInProgressStatuses != null && !processInProgressStatuses.isEmpty()) {
            status = new List<String>(processInProgressStatuses)[0];
        }
        String ledgerPattern = getLedgerPattern();
        String queryString = 'SELECT Count(Id),' + ledgerPattern + ' acctMethod '
            + 'FROM ' + this.sourceSObjectType + ' WHERE '
            + ' Status__c = \'' + status
            + '\' GROUP BY ' + ledgerPattern + ' ORDER BY ' + ledgerPattern + ' ASC';
        return (List<AggregateResult>) Database.query(queryString);
    }

    private String getLedgerPattern() {
        String ledgerPattern = '';
        if (this.sourceSObjectType == AP_Disbursement__c.getSObjectType()) {
            ledgerPattern = 'Account_Payable__r.Ledger__r.Accounting_Method__c';
        }
        else if (this.sourceSObjectType == Billing_Cash_Receipt__c.getSObjectType()) {
            ledgerPattern = 'Billing__r.Ledger__r.Accounting_Method__c';
        }
        else {
            ledgerPattern = 'Ledger__r.Accounting_Method__c';
        }
        return ledgerPattern;
    }

    private String getCustomFieldPattern() {
        String customFieldPattern = '';
        if (this.sourceSObjectType == AP_Disbursement__c.getSObjectType()) {
            customFieldPattern = 'Account_Payable__c';
        }
        else if (this.sourceSObjectType == Billing_Cash_Receipt__c.getSObjectType()) {
            customFieldPattern = 'Billing__c';
        }
        else {
            customFieldPattern = 'Name';
        }
        return customFieldPattern;
    }

}