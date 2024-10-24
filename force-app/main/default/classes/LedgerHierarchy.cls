public with sharing class LedgerHierarchy {

    public static final Set<String> APEX_JOB_IN_PROGRESS_STATUSES = GlobalVariables.APEX_JOB_STATUSES;
    private static final Set<String> AUTO_POST_BATCH_CLASSES = new Set<String>{
        'BillingPostBatch',
        'BillingCashReceiptPostBatch',
        'CashReceiptPostBatch',
        'PayablePostBatch',
        'CashDisbursementPostBatch',
        'APDisbursementPostBatch',
        'TimeCardPostBatch',
        'JournalEntryPostBatch',
        'AmortizationPostBatch',
        'InboundInventoryMovementPostBatch',
        'OutboundInventoryMovementPostBatch',
        'ManufacturingInvMovementPostBatch',
        'PurchaseOrderInventoryPostBatch',
        'SalesOrderInventoryMovementPostBatch'
    };

    private static final Set<String> CONSOLIDATION_BATCH_CLASSES = new Set<String>{
        'ConsolidationRoutineBatch'
    };
    
    @TestVisible
    private static final String CURRENT_PERIOD_NOT_CLOSED = Label.ERR_CURRENT_PERIOD_NOT_CLOSED;
    @TestVisible
    private static final String ACCOUNTING_PERIOD_JOB_RUNNING = Label.ERR_ACCOUNTING_PERIOD_JOB_RUNNING;
    @TestVisible
    private static final String CONSOLIDATION_JOB_RUNNING = Label.ERR_CONSOLIDATION_JOB_RUNNING;
    @TestVisible
    private static final String AUTO_POST_JOB_RUNNING = Label.ERR_AUTO_POST_JOB_RUNNING;
    
    
    private APIServiceContext.APIServiceEntry serviceEntry;
    private Id hierarchyId;
    APIOptions.SharingContext sharingContext;
    private ServiceResult serviceResult;
    private List<ServiceResult.Error> errors;


    public class LedgerHierarchyException extends Exception {}

    private LedgerHierarchy() {
        this.sharingContext = APIOptions.SharingContext.WITH_SHARING;
        serviceEntry = new APIServiceContext.APIServiceEntry();
    }

    private LedgerHierarchy(Id ledgerHierarchyId) {
        this.sharingContext = APIOptions.SharingContext.WITHOUT_SHARING;
        this.hierarchyId = ledgerHierarchyId;
        serviceEntry = new APIServiceContext.APIServiceEntry();
    }

    private LedgerHierarchy(APIOptions.SharingContext ctx) {
        this.sharingContext = ctx;
        serviceEntry = new APIServiceContext.APIServiceEntry();
    }

    private LedgerHierarchy(APIOptions.SharingContext ctx, Id ledgerHierarchyId) {
        this.sharingContext = ctx;
        this.hierarchyId = ledgerHierarchyId;
        serviceEntry = new APIServiceContext.APIServiceEntry();
    }

    /**
     * Runs the consolidation routine
     * @input `ledgerHierarchyId`: ID of the hierarchy to consolidate
     * @input `runForChildren`: consolidate child hierarchies first?
     * @input `periodId`: ID of the closed accounting period to consolidate
     */
    public static ServiceResult consolidate(Id ledgerHierarchyId, Boolean runForChildren, Id periodId) {
        LedgerHierarchy svc = new LedgerHierarchy(ledgerHierarchyId);
        checkServiceContextValidation(APIServiceContext.validateServiceContext(svc.serviceEntry));
        return svc.consolidate(runForChildren, periodId);
    }

    /**
     * Returns tree structure.
     * Retrieves the `LedgerHierarchyModel`s for all Ledger Hierarchies.
     */
    public static List<LedgerHierarchyModel> retrieve(APIOptions.SharingContext ctx) {
        LedgerHierarchy svc = new LedgerHierarchy(ctx);
        checkServiceContextValidation(APIServiceContext.validateServiceContext(svc.serviceEntry));
        return svc.retrieveAllHierarchies();
    }

    /**
     * Returns tree structure.
     * Retrieves the `LedgerHierarchyModel` for the provided Ledger Hierarchy Id.
     */
    public static LedgerHierarchyModel retrieve(APIOptions.SharingContext ctx, Id ledgerHierarchyId) {
        LedgerHierarchy svc = new LedgerHierarchy(ctx, ledgerHierarchyId);
        checkServiceContextValidation(APIServiceContext.validateServiceContext(svc.serviceEntry));
        return svc.retrieveHierarchy();
    }

    /**
     * Returns flat structure.
     * Retrieves all `Ledger_Hierarchy__c`s.
     */
    public static List<Ledger_Hierarchy__c> retrieveFlat(APIOptions.SharingContext ctx) {
        LedgerHierarchy svc = new LedgerHierarchy(ctx);
        checkServiceContextValidation(APIServiceContext.validateServiceContext(svc.serviceEntry));
        return svc.retrieveAllHierarchiesFlat();
    }

    /**
     * If context validation failed, throw an error.
     */
    private static void checkServiceContextValidation(ServiceResult validationResult) {
        if (!validationResult.isSuccess) {
            List<String> msgs = new List<String>();
            for (ServiceResult.Error error : validationResult.errors) {
                msgs.add(String.valueOf(error));
            }
            throw new LedgerHierarchyException(String.join(msgs,','));
        }
    }

    /**
     * Run the consolidation for `this.hierarchyId`.
     * If `runForChildren` = true, consolidate all children in the selected hierarchy.; 
     */
    private ServiceResult consolidate(Boolean runForChildren, Id periodId) {
        Accounting_Period__c selectedPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodById(periodId);
        if (selectedPeriod != null && validateConsolidationRoutine(selectedPeriod)) {
            if (runForChildren) {
                List<Ledger_Hierarchy__c> allNodes = getAllNodes(retrieveHierarchy());
                updateLedgerHierarchyStatus(allNodes, LedgerHierarchyActions.LEDGER_HIERARCHY_STATUS_IN_PROGRESS);
            }
            else {
                updateLedgerHierarchyStatus(
                    LedgerHierarchyHandler.getInstanceWithoutSharing().getHierarchiesByIds(new Set<Id>{this.hierarchyId}),
                    LedgerHierarchyActions.LEDGER_HIERARCHY_STATUS_IN_PROGRESS
                );
            }

            LedgerHierarchyModel lhm = retrieveHierarchy();

            if ((runForChildren && lhm.getIterator().viewNext().needTranslations()) || (!runForChildren && lhm.needTranslations())) {
                FinancialCubeTranslationBatch translationBatchInstance = new FinancialCubeTranslationBatch(
                    lhm, periodId, runForChildren
                );
                Database.executeBatch(translationBatchInstance);
            }
            else {
                ConsolidationRoutineBatch consolidationBatchInstance = new ConsolidationRoutineBatch(
                    lhm,
                    selectedPeriod.Id,
                    runForChildren
                );
                Database.executeBatch(consolidationBatchInstance);
            }
        }
        else if (selectedPeriod == null) {
            serviceResult = new ServiceResult(NULL, false);
        }

        return serviceResult;
    }

    private List<Ledger_Hierarchy__c> getAllNodes(LedgerHierarchyModel rootLh) {
        LedgerHierarchyModel.Iterator rootLhIterator = rootLh.getIterator();
        List<Ledger_Hierarchy__c> result = new List<Ledger_Hierarchy__c>();
        while (rootLhIterator.hasNext()) {
            result.add(rootLhIterator.next().value);
        }
        return result;
    }

    private void updateLedgerHierarchyStatus(List<Ledger_Hierarchy__c> lhs, String status) {
        try {
            for (Ledger_Hierarchy__c lh : lhs) {
                lh.Hierarchy_Status__c = status;
            }
            TriggerObserver.getInstance().unlockField(Ledger_Hierarchy__c.Hierarchy_Status__c);
            SFDCSecurityUtils.updateProxy(lhs);
            TriggerObserver.purgeUnlockedFields(Ledger_Hierarchy__c.Hierarchy_Status__c);
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    /**
     * Retrieve all ledger hierarchies without filtering.
     */
    public List<Ledger_Hierarchy__c> retrieveAllHierarchiesFlat() {
        return getLedgerHierarchyHandler().getAllHierarchies();
    }

    /**
     * Retrieve all ledger hierarchies without filtering.
     */
    public List<LedgerHierarchyModel> retrieveAllHierarchies() {
        // get all hierarchies (nodes)
        List<Ledger_Hierarchy__c> nodes = getLedgerHierarchyHandler().getAllHierarchies();
        
        // get the tree represented as a map for easy retrieval of subgraphs
        Map<Id,LedgerHierarchyModel> tree = buildTree(nodes);

        // retrieve the root nodes
        List<LedgerHierarchyModel> models = new List<LedgerHierarchyModel>();
        for (Ledger_Hierarchy__c node : nodes) {
            if (node.Parent_Ledger_Hierarchy__c == null) {
                models.add(tree.get(node.Id));
            }
        }

        return models;
    }

    /**
     * Retrieve the hierarchy for `this.hierarchyId` with all child hierarchies.
     */
    public LedgerHierarchyModel retrieveHierarchy() {
        // get all hierarchies (nodes)
        List<Ledger_Hierarchy__c> nodes = getLedgerHierarchyHandler().getAllHierarchies();
        
        // get the tree represented as a map for easy retrieval of subgraphs
        Map<Id,LedgerHierarchyModel> tree = buildTree(nodes);

        return tree.get(this.hierarchyId);
    }

    /**
     * Given a set of nodes, constructs a tree of LedgerHierarchyModel indexed by node ID.
     * The resulting map provides easy node lookups. By providing a node ID the entire 
     * subgraph (LedgerHierarchyModel) can be retrieved without recalculation.
     */
    private Map<Id,LedgerHierarchyModel> buildTree(List<Ledger_Hierarchy__c> nodes) {
        Map<Id,LedgerHierarchyModel> tree = new Map<Id,LedgerHierarchyModel>();
        // first pass: create a LedgerHierarchyModel for each node
        for (Ledger_Hierarchy__c node : nodes) {
            tree.put(node.Id, new LedgerHierarchyModel(node));
        }
        // second pass: assign children to parent nodes
        for (Ledger_Hierarchy__c node : nodes) {
            LedgerHierarchyModel child = tree.get(node.Id);
            LedgerHierarchyModel parent = tree.get(node.Parent_Ledger_Hierarchy__c);
            if (parent != null) {
                parent.children.add(child);
            }
        }
        return tree;
    }

    /**
     * Get a LedgerHierarchyHandler instance based on `this.sharingContext`.
     */
    private LedgerHierarchyHandler getLedgerHierarchyHandler() {
        switch on this.sharingContext {
            when WITH_SHARING {
                return LedgerHierarchyHandler.getInstanceWithSharing();
            }
            when else {
                return LedgerHierarchyHandler.getInstanceWithoutSharing();
            }
        }
    }

    private Boolean validateConsolidationRoutine(Accounting_Period__c accountingPeriod) {
        this.errors = new List<ServiceResult.Error>();
        validateCurrentPeriodClosed(accountingPeriod);
        validatePeriodJobNotRunning();
        validateConsolidationJobNotRunning();

        if (this.errors.isEmpty()) {
            serviceResult = new ServiceResult(NULL, true);
        }
        else {
            serviceResult = new ServiceResult(NULL, false, errors);
        }

        return serviceResult.isSuccess;
    }

    private Boolean validateCurrentPeriodClosed(Accounting_Period__c accountingPeriod) {
        Boolean isValid = true;
        if (accountingPeriod == null || !AccountingPeriodHandler.getInstance().isConsideredClosed(accountingPeriod)) {
            ServiceResult.Error error = new ServiceResult.Error(String.format(CURRENT_PERIOD_NOT_CLOSED, new List<String>{accountingPeriod.Name}));
            this.errors.add(error);
            isValid = false;
        } 
        return isValid;
    }

    private Boolean validatePeriodJobNotRunning() {
        Boolean isValid = true;
        Set<String> inProgressStatuses = new Set<string>{
            AccountingPeriodActions.ARCHIVE_IN_PROGRESS_STATUS,
            AccountingPeriodActions.OPEN_INTERIM_STATUS,
            AccountingPeriodActions.CLOSE_INTERIM_STATUS
        };

        if (AccountingPeriodHandler.getInstance().getAllAccountingPeriods(inProgressStatuses).size() > 0) {
            ServiceResult.Error error = new ServiceResult.Error(ACCOUNTING_PERIOD_JOB_RUNNING);
            this.errors.add(error);
            isValid = false;
        } 
        return isValid;
    }

    private Boolean validateConsolidationJobNotRunning() {
        Boolean isValid = true;
        List<AsyncApexJob> apexJobInAction = DomainUtils.getAsyncApexJobByApexClassNameAndStatus(
            CONSOLIDATION_BATCH_CLASSES, APEX_JOB_IN_PROGRESS_STATUSES
        );
        if (!apexJobInAction.isEmpty()) {
            ServiceResult.Error error = new ServiceResult.Error(CONSOLIDATION_JOB_RUNNING);
            this.errors.add(error);
            isValid = false;
        } 
        return isValid;
    }

}