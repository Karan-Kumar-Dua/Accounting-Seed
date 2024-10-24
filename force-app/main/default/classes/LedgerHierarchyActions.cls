public with sharing class LedgerHierarchyActions {

    public static final String ONLY_LEDGER_WITH_CORRECT_TYPE_ERROR = Label.ERR_ONLY_LEDGER_WITH_CORRECT_TYPE;
    public static final String ONLY_LEDGER_WITH_CORRECT_ACCOUNTING_METHOD_ERROR = Label.ERR_ONLY_LEDGER_WITH_CORRECT_ACCOUNTING_METHOD;
    public static final String CHOOSE_LEDGER_WITH_CORRECT_TYPE_ERROR = Label.ERR_CHOOSE_LEDGER_WITH_CORRECT_TYPE;
    public static final String CONSOLIDATION_LEDGER_ASSOCIATION_ERROR = Label.ERR_CONSOLIDATION_LEDGER_ASSOCIATION;
    public static final String LEDGER_EXIST_IN_HIERARCHY_ERROR = Label.ERR_LEDGER_EXIST_IN_HIERARCHY;
    public static final String INSERT_CONSOLIDATION_ROUTINE_IS_IS_PROGRESS_ERROR = Label.ERR_INSERT_CONSOLIDATION_ROUTINE_IS_IS_PROGRESS;
    public static final String UPDATE_CONSOLIDATION_ROUTINE_IS_IS_PROGRESS_ERROR = System.Label.ERR_UPDATE_CONSOLIDATION_ROUTINE_IS_PROGRESS_ERROR;
    public static final String DELETE_CONSOLIDATION_ROUTINE_IS_IS_PROGRESS_ERROR = Label.ERR_DELETE_CONSOLIDATION_ROUTINE_IS_IS_PROGRESS;
    public static final String ASSOCIATED_CONSOLIDATION_FINANCIAL_CUBES_ERROR = Label.ERR_ASSOCIATED_CONSOLIDATION_FINANCIAL_CUBES;
    public static final String PREVENT_REMOVE_CL_WITH_CHILD_ERROR = Label.ERR_PREVENT_REMOVE_CL_WITH_CHILD;
    public static final String MANUAL_ELIMINATION_HIERARCHY_ERROR = Label.ERR_MANUAL_ELIMINATION_HIERARCHY;
    public static final String TRANSACTIONAL_TEMPLATE = LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL + ' ' + Label.COMMON_OR + ' ' + LedgerActions.LEDGER_TYPE_TRANSACTIONAL;
    public static final String BUDGET_TEMPLATE = LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_BUDGET + ' ' + Label.COMMON_OR + ' ' + LedgerActions.LEDGER_TYPE_BUDGET;
    public static final String LEDGER_HIERARCHY_STATUS_IN_PROGRESS = 'In Progress';
    public static final String LEDGER_HIERARCHY_STATUS_COMPLETE = 'Completed';
    public static final String LEDGER_HIERARCHY_STATUS_ERROR = 'Failed';
    public static final String LEDGER_HIERARCHY_STATUS_NOT_RUN = 'Not Run';
    public static final String LEDGER_HIERARCHY_TYPE_TRANSACTIONAL = 'Transactional';
    public static final String LEDGER_HIERARCHY_TYPE_BUDGET = 'Budget';

    public static final Set<String> LEDGER_TRANSACTIONAL_TYPES = new Set<String>{
        LedgerActions.LEDGER_TYPE_TRANSACTIONAL,
        LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL
    };
    public static final Set<String> LEDGER_BUDGET_TYPES = new Set<String>{
        LedgerActions.LEDGER_TYPE_BUDGET,
        LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_BUDGET
    };

    public static Boolean bypassConsolidationRoutineValidation = false;

    //make the parameter available on update to avoid unnecessary database query
    private static List<Ledger_Hierarchy__c> rootLedgerHierarchies;
    public static Set<ValidationType> preventValidationTypes = new Set<ValidationType>();
    private static List<Id> eLedgerHierarchyIds4Remove = new List<Id>();

    public static void initialValidation(List<Ledger_Hierarchy__c> ledgerHierarchies) {
        Set<Id> ledgerIds = new Set<Id>();
        Set<Id> parentLedgerHierarchyIds = new Set<Id>();
        for (Ledger_Hierarchy__c ledgerHierarchy : ledgerHierarchies) {
            ledgerIds.add(ledgerHierarchy.Ledger__c);
            parentLedgerHierarchyIds.add(ledgerHierarchy.Parent_Ledger_Hierarchy__c);
        }

        Map<Id, Ledger_Hierarchy__c> parentLedgerHierarchiesByIds = new Map<Id, Ledger_Hierarchy__c>(
            DomainUtils.getLedgerHierarchiesByIds(parentLedgerHierarchyIds)
        );
        Set<Id> rootNodeIds = collectRootNodeIds(parentLedgerHierarchiesByIds.values());

        List<Ledger_Hierarchy__c> rootLedgerHierarchies = !rootNodeIds.isEmpty() ?
            DomainUtils.getLedgerHierarchiesByIds(rootNodeIds) : new List<Ledger_Hierarchy__c>();
        Map<Id, Boolean> consolidationRoutineFlagsByRootNodeIds = getConsolidationRoutineFlagsByRootNodeIds(rootLedgerHierarchies);
        Map<Id, Ledger__c> consolidationLedgersByRootNodeIds = getConsolidationLedgersWithFinancialCubes(parentLedgerHierarchiesByIds.values());

        Map<Id, Ledger__c> addedLedgersByIds = new Map<Id, Ledger__c>(
            DomainUtils.getLedgersWithLedgerHierarchyByIds(rootNodeIds, ledgerIds)
        );
        Map<Id, Set<Id>> rootNodeIdsByLedgerIds = getRootNodeIdsByAddedLedgerIds(addedLedgersByIds.values());

        for (Ledger_Hierarchy__c ledgerHierarchy : ledgerHierarchies) {
            Ledger_Hierarchy__c parentLedgerHierarchy = parentLedgerHierarchiesByIds.get(ledgerHierarchy.Parent_Ledger_Hierarchy__c);
            if (parentLedgerHierarchy != null) {
                ledgerHierarchy.Root_Node_ID__c = String.isNotBlank(parentLedgerHierarchy.Root_Node_ID__c) ?
                                parentLedgerHierarchy.Root_Node_ID__c : parentLedgerHierarchy.Id;
            }

            Ledger__c ledger = addedLedgersByIds.get(ledgerHierarchy.Ledger__c);
            if (ledger != null) {
                ledgerHierarchy.Name = String.isNotBlank(ledgerHierarchy.Name) ? ledgerHierarchy.Name : ledger.Name;

                checkTypeMatching(ledger, ledgerHierarchy, parentLedgerHierarchy);
                checkAccountingMethodMatching(ledger, ledgerHierarchy, parentLedgerHierarchy);
                checkConsolidationLedgerUniqueness(ledger, ledgerHierarchy);
                checkLedgerUniquenessInHierarchy(rootNodeIdsByLedgerIds.get(ledger.Id), ledgerHierarchy);
                checkConsolidationRoutine(consolidationRoutineFlagsByRootNodeIds, ledgerHierarchy);
                checkClosedConsolidationFinancialCube(consolidationLedgersByRootNodeIds, ledgerHierarchy);
            }
        }
    }

    public static void updateValidation(List<Ledger_Hierarchy__c> ledgerHierarchies) {
        for (Ledger_Hierarchy__c ledgerHierarchy : ledgerHierarchies) {
            requireFields(ledgerHierarchy);
        }
    }

    private static void checkTypeMatching(Ledger__c ledger, Ledger_Hierarchy__c ledgerHierarchy, Ledger_Hierarchy__c parentLedgerHierarchy) {
        Boolean isTransactionalError = isTransactionalErrorMatch(ledger, ledgerHierarchy, parentLedgerHierarchy);
        Boolean isBudgetError = isBudgetErrorMatch(ledger, ledgerHierarchy, parentLedgerHierarchy);
        if (!LedgerHandler.isEliminationLedger(ledger) && (isTransactionalError || isBudgetError)) {
            ledgerHierarchy.addError(
                String.format(
                    ONLY_LEDGER_WITH_CORRECT_TYPE_ERROR,
                    new List<String>{
                        isTransactionalError ? TRANSACTIONAL_TEMPLATE
                            : isBudgetError ? BUDGET_TEMPLATE : ''
                    }
                )
            );
        }

        if (!LedgerHandler.isConsolidationLedger(ledger) && parentLedgerHierarchy == null) {
            ledgerHierarchy.addError(CHOOSE_LEDGER_WITH_CORRECT_TYPE_ERROR);
        }

        if (LedgerHandler.isEliminationLedger(ledger) && !preventValidationTypes.contains(ValidationType.ELIMINATION_CREATING)) {
            ledgerHierarchy.addError(MANUAL_ELIMINATION_HIERARCHY_ERROR);
        }
    }

    private static void checkAccountingMethodMatching(Ledger__c ledger, Ledger_Hierarchy__c ledgerHierarchy, Ledger_Hierarchy__c parentLedgerHierarchy) {
        Ledger__c parentLedger = parentLedgerHierarchy?.Ledger__r;
        Boolean isMatching = parentLedger == null
                || (
                    ledger.Accounting_Method__c == LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH
                            && parentLedger.Accounting_Method__c != LedgerActions.ACCOUNTING_METHOD_CASH
                )
                || (
                    parentLedger.Accounting_Method__c == LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH
                            && ledger.Accounting_Method__c != LedgerActions.ACCOUNTING_METHOD_CASH
                )
                || parentLedger.Accounting_Method__c == ledger.Accounting_Method__c;
        if (!isMatching) {
            Set<String> accrualMethods = new Set<String>{LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH, LedgerActions.ACCOUNTING_METHOD_ACCRUAL};
            List<String> methods = new List<String>();
            for (String acctMethod : accrualMethods.contains(parentLedger.Accounting_Method__c)
                    ? new List<String>(accrualMethods)
                    : new List<String>{LedgerActions.ACCOUNTING_METHOD_CASH}) {
                methods.add('"' + acctMethod + '"');
            }
            ledgerHierarchy.addError(
                    String.format(
                            ONLY_LEDGER_WITH_CORRECT_ACCOUNTING_METHOD_ERROR,
                            new List<String>{
                                    String.join(methods, ' ' + Label.COMMON_OR + ' ')
                            }
                    )
            );
        }
    }

    private static Boolean isTransactionalErrorMatch(Ledger__c ledger, Ledger_Hierarchy__c ledgerHierarchy, Ledger_Hierarchy__c parentLedgerHierarchy) {
        return !LEDGER_TRANSACTIONAL_TYPES.contains(ledger.Type__c) && (ledgerHierarchy.Hierarchy_Type__c == LEDGER_HIERARCHY_TYPE_TRANSACTIONAL
            || parentLedgerHierarchy != null && parentLedgerHierarchy.Hierarchy_Type__c == LEDGER_HIERARCHY_TYPE_TRANSACTIONAL);
    }

    private static Boolean isBudgetErrorMatch(Ledger__c ledger, Ledger_Hierarchy__c ledgerHierarchy, Ledger_Hierarchy__c parentLedgerHierarchy) {
        return !LEDGER_BUDGET_TYPES.contains(ledger.Type__c) && (ledgerHierarchy.Hierarchy_Type__c == LEDGER_HIERARCHY_TYPE_BUDGET
            || parentLedgerHierarchy != null && parentLedgerHierarchy.Hierarchy_Type__c == LEDGER_HIERARCHY_TYPE_BUDGET);
    }

    private static void checkConsolidationLedgerUniqueness(Ledger__c ledger, Ledger_Hierarchy__c ledgerHierarchy) {
        if (LedgerHandler.isConsolidationLedger(ledger) && !ledger.Ledger_Hierarchy__r.isEmpty()) {
            ledgerHierarchy.addError(CONSOLIDATION_LEDGER_ASSOCIATION_ERROR);
        }
    }

    private static void checkLedgerUniquenessInHierarchy(Set<Id> tempRootNodeIds, Ledger_Hierarchy__c ledgerHierarchy) {
        if (tempRootNodeIds != null && tempRootNodeIds.contains(ledgerHierarchy.Root_Node_ID__c)) {
            ledgerHierarchy.addError(LEDGER_EXIST_IN_HIERARCHY_ERROR);
        }
    }

    public static void checkConsolidationRoutine(List<Ledger_Hierarchy__c> ledgerHierarchies) {
            Map<Id, Boolean> consolidationRoutineFlagsByRootNodeIds = getConsolidationRoutineFlagsByRootNodeIds(
                    getRootLedgerHierarchies(ledgerHierarchies)
            );
            for (Ledger_Hierarchy__c ledgerHierarchy : ledgerHierarchies) {
                checkConsolidationRoutine(consolidationRoutineFlagsByRootNodeIds, ledgerHierarchy);
            }
    }

    private static void checkConsolidationRoutine(Map<Id, Boolean> consolidationRoutineFlagsByRootNodeIds, Ledger_Hierarchy__c ledgerHierarchy) {
        if (!bypassConsolidationRoutineValidation) {
            if (!preventValidationTypes.contains(ValidationType.CONSOLIDATION_ROUTINE)
                    && ((consolidationRoutineFlagsByRootNodeIds.containsKey(ledgerHierarchy.Root_Node_ID__c)
                            && consolidationRoutineFlagsByRootNodeIds.get(ledgerHierarchy.Root_Node_ID__c))
                                || (consolidationRoutineFlagsByRootNodeIds.containsKey(ledgerHierarchy.Id)
                                        && consolidationRoutineFlagsByRootNodeIds.get(ledgerHierarchy.Id)))
                                            && !isAllowResetStatus(ledgerHierarchy)) {

                if (Trigger.isInsert) {
                    ledgerHierarchy.addError(INSERT_CONSOLIDATION_ROUTINE_IS_IS_PROGRESS_ERROR);
                } else if (Trigger.isUpdate) {
                    ledgerHierarchy.addError(UPDATE_CONSOLIDATION_ROUTINE_IS_IS_PROGRESS_ERROR);
                } else {
                    ledgerHierarchy.addError(DELETE_CONSOLIDATION_ROUTINE_IS_IS_PROGRESS_ERROR);
                }
            }
        }
    }

    private static Boolean isAllowResetStatus(Ledger_Hierarchy__c ledgerHierarchy) {
        return Trigger.isUpdate && String.isBlank((String) ledgerHierarchy.get(Ledger_Hierarchy__c.Hierarchy_Status__c));
    }

    private static List<Ledger_Hierarchy__c> getParentLedgerHierarchies(List<Ledger_Hierarchy__c> ledgerHierarchies) {
        Set<Id> parentLedgerHierarchyIds = new Set<Id>();
        for (Ledger_Hierarchy__c ledgerHierarchy : ledgerHierarchies) {
            Id parentLedgerHierarchyId = String.isNotBlank(ledgerHierarchy.Parent_Ledger_Hierarchy__c)
                ? ledgerHierarchy.Parent_Ledger_Hierarchy__c
                : (String.isNotBlank(ledgerHierarchy.Id) ? ledgerHierarchy.Id : null);

            if (String.isNotBlank(parentLedgerHierarchyId)) {
                parentLedgerHierarchyIds.add(parentLedgerHierarchyId);
            }
        }

        return
            !parentLedgerHierarchyIds.isEmpty()
                ? DomainUtils.getLedgerHierarchiesByIds(parentLedgerHierarchyIds) : new List<Ledger_Hierarchy__c>();
    }

    private static List<Ledger_Hierarchy__c> getRootLedgerHierarchies(List<Ledger_Hierarchy__c> ledgerHierarchies) {
        if (LedgerHierarchyActions.rootLedgerHierarchies == null) {
            Set<Id> rootNodeIds = collectRootNodeIds(ledgerHierarchies);
            LedgerHierarchyActions.rootLedgerHierarchies = !rootNodeIds.isEmpty() ?
                    DomainUtils.getLedgerHierarchiesByIds(rootNodeIds) : new List<Ledger_Hierarchy__c>();
        }

        return LedgerHierarchyActions.rootLedgerHierarchies;
    }

    public static void checkClosedConsolidationFinancialCube(List<Ledger_Hierarchy__c> ledgerHierarchies) {
        Map<Id, Ledger__c> consolidationLedgersByRootNodeIds = getConsolidationLedgersWithFinancialCubes(
                getParentLedgerHierarchies(ledgerHierarchies)
        );
        for (Ledger_Hierarchy__c ledgerHierarchy : ledgerHierarchies) {
            checkClosedConsolidationFinancialCube(consolidationLedgersByRootNodeIds, ledgerHierarchy);
        }
    }

    private static void checkClosedConsolidationFinancialCube(Map<Id, Ledger__c> consolidationLedgersByRootNodeIds, Ledger_Hierarchy__c ledgerHierarchy) {
        Ledger__c consolidationLedger = String.isNotBlank(ledgerHierarchy.Parent_Ledger_Hierarchy__c) ?
                consolidationLedgersByRootNodeIds.get(ledgerHierarchy.Parent_Ledger_Hierarchy__c) :
                (String.isNotBlank(ledgerHierarchy.Id) ? consolidationLedgersByRootNodeIds.get(ledgerHierarchy.Id) : null);
        if (consolidationLedger != null && !consolidationLedger.Financial_Cubes__r.isEmpty()) {
            ledgerHierarchy.addError(ASSOCIATED_CONSOLIDATION_FINANCIAL_CUBES_ERROR);
        }
    }

    private static Set<Id> collectRootNodeIds(List<Ledger_Hierarchy__c> ledgerHierarchies) {
        Set<Id> rootNodeIds = new Set<Id>();
        for (Ledger_Hierarchy__c ledgerHierarchy : ledgerHierarchies) {
            rootNodeIds.add(String.isNotBlank(ledgerHierarchy.Root_Node_ID__c) ? ledgerHierarchy.Root_Node_ID__c : ledgerHierarchy.Id);
        }

        return rootNodeIds;
    }

    private static Map<Id, Boolean> getConsolidationRoutineFlagsByRootNodeIds(List<Ledger_Hierarchy__c> rootLedgerHierarchies) {
        Map<Id, Boolean> consolidationRoutineFlagsByRootNodeIds = new Map<Id, Boolean>();
        for (Ledger_Hierarchy__c rootLedgerHierarchy : rootLedgerHierarchies) {
            consolidationRoutineFlagsByRootNodeIds.put(rootLedgerHierarchy.Id, rootLedgerHierarchy.Hierarchy_Status__c == LEDGER_HIERARCHY_STATUS_IN_PROGRESS);
        }
        return consolidationRoutineFlagsByRootNodeIds;
    }

    private static Map<Id, Set<Id>> getRootNodeIdsByAddedLedgerIds(List<Ledger__c> ledgers) {
        Map<Id, Set<Id>> rootNodeIdsByLedgerIds = new Map<Id, Set<Id>>();
        for (Ledger__c ledger : ledgers) {
            for (Ledger_Hierarchy__c ledgerHierarchy : ledger.Ledger_Hierarchy__r) {
                if (String.isNotBlank(ledgerHierarchy.Root_Node_ID__c)) {
                    Set<Id> tempRootNodeIds = rootNodeIdsByLedgerIds.containsKey(ledger.Id) ?
                            rootNodeIdsByLedgerIds.get(ledger.Id) : new Set<Id>();
                    tempRootNodeIds.add(ledgerHierarchy.Root_Node_ID__c);
                    rootNodeIdsByLedgerIds.put(ledger.Id, tempRootNodeIds);
                }
            }
        }

        return rootNodeIdsByLedgerIds;
    }

    private static Map<Id, Ledger__c> getConsolidationLedgersWithFinancialCubes(List<Ledger_Hierarchy__c> parentLedgerHierarchies) {
        Map<Id, Ledger__c> ledgersByParentLedgerHierarchyIds = new Map<Id, Ledger__c>();

        Set<Id> consolidationLedgerIds = new Set<Id>();
        for (Ledger_Hierarchy__c ledgerHierarchy : parentLedgerHierarchies) {
            consolidationLedgerIds.add(ledgerHierarchy.Ledger__c);
        }

        if (!consolidationLedgerIds.isEmpty()) {
            Map<Id, Ledger__c> ledgersByIds = new Map<Id, Ledger__c>(
                DomainUtils.getCLedgersWithFinancialCubesByIds(consolidationLedgerIds)
            );

            for (Ledger_Hierarchy__c ledgerHierarchy : parentLedgerHierarchies) {
                Ledger__c consolidationLedger = ledgersByIds.get(ledgerHierarchy.Ledger__c);
                if (consolidationLedger != null) {
                    ledgersByParentLedgerHierarchyIds.put(ledgerHierarchy.Id, consolidationLedger);
                }
            }
        }

        return ledgersByParentLedgerHierarchyIds;
    }

    public static void checkCLedgerWithChildren(Map<Id, Ledger_Hierarchy__c> ledgerHierarchiesByIds) {
        List<AggregateResult> countOfCLHierarchyChildren =
                DomainUtils.getCountOfCLHierarchyChildren(ledgerHierarchiesByIds.keySet());

        for (AggregateResult result : countOfCLHierarchyChildren) {
            Ledger_Hierarchy__c ledgerHierarchy = ledgerHierarchiesByIds.get((Id)result.get('hierarchyId'));
            if (ledgerHierarchy != null) {
                ledgerHierarchy.addError(PREVENT_REMOVE_CL_WITH_CHILD_ERROR);
            }
        }
    }

    public static void createEliminationHierarchy(List<Ledger_Hierarchy__c> ledgerHierarchies) {
        Map<Id, Ledger_Hierarchy__c> ledgerHierarchiesByLedgerIds = new Map<Id, Ledger_Hierarchy__c>();
        for (Ledger_Hierarchy__c ledgerHierarchy : ledgerHierarchies) {
            ledgerHierarchiesByLedgerIds.put(ledgerHierarchy.Ledger__c, ledgerHierarchy);
        }

        List<Ledger__c> eliminationLedgers = LedgerHandler.getInstanceWithoutSharing()
            .getEliminationLedgersByConsolidationIds(ledgerHierarchiesByLedgerIds.keySet());

        List<Ledger_Hierarchy__c>  eliminationLedgerHierarchies = new List<Ledger_Hierarchy__c>();
        for (Ledger__c eliminationLedger : eliminationLedgers) {
            Ledger_Hierarchy__c consolidationLedgerHierarchy = ledgerHierarchiesByLedgerIds.get(eliminationLedger.Consolidation_Ledger_ID__c);
            if (consolidationLedgerHierarchy != null) {
                eliminationLedgerHierarchies.add(
                    new Ledger_Hierarchy__c(
                        Ledger__c = eliminationLedger.Id,
                        Parent_Ledger_Hierarchy__c = consolidationLedgerHierarchy.Id,
                        Sort_Order__c = 1
                    )
                );
            }
        }

        if (!eliminationLedgerHierarchies.isEmpty()) {
            Set<ValidationType> validationTypes = new Set<ValidationType>{
                    ValidationType.CONSOLIDATION_ROUTINE, ValidationType.ELIMINATION_CREATING
            };
            preventValidationTypes.addAll(validationTypes);
            SFDCSecurityUtils.insertCheckCRUDAndFLS(eliminationLedgerHierarchies, new List<String>());
            preventValidationTypes.removeAll(validationTypes);
        }
    }

    public static void prepareRecords4Remove(Map<Id, Ledger_Hierarchy__c> ledgerHierarchiesByIds) {
        Set<Id> ledgerIds = new Set<Id>();
        for (Ledger_Hierarchy__c ledgerHierarchy : ledgerHierarchiesByIds.values()) {
            ledgerIds.add(ledgerHierarchy.Ledger__c);
        }

        eLedgerHierarchyIds4Remove.addAll(new Map<Id, Ledger_Hierarchy__c>(DomainUtils.getEliminationsLedgerHierarchies(ledgerHierarchiesByIds.keySet())).keySet());
    }

    public static void removeEliminationHierarchy(Map<Id, Ledger_Hierarchy__c> ledgerHierarchiesByIds) {
        List<Id> tempELedgerHierarchyIds4Remove = new List<Id>(eLedgerHierarchyIds4Remove);
        eLedgerHierarchyIds4Remove = new List<Id>();
        if (!tempELedgerHierarchyIds4Remove.isEmpty()) {
            SFDCSecurityUtils.deleteProxy(tempELedgerHierarchyIds4Remove);
        }
    }

    public enum ValidationType {
        CONSOLIDATION_ROUTINE, ELIMINATION_CREATING
    }

    public static void setDefaultSortOrder(List<Ledger_Hierarchy__c> ledgerHierarchies) {
        Set<Id> parentLedgerHierarchyIds = new Set<Id>();
        Map<Id, Decimal> maxOrderForNewHierarchies = new Map<Id, Decimal>();
        for (Ledger_Hierarchy__c ledgerHierarchy : ledgerHierarchies) {
            parentLedgerHierarchyIds.add(ledgerHierarchy.Parent_Ledger_Hierarchy__c);
        }

        Map<Id, AggregateResult> sortOrders = DomainUtils.getLedgerHierarchiesMaxSortOrder(parentLedgerHierarchyIds);
        List<Ledger_Hierarchy__c> lhParent = DomainUtils.getParentLedgerHierarchiesMaxSortOrder();

        Id fakeLhId = FinancialSuiteUtils.getFakeId(Ledger_Hierarchy__c.SObjectType);

        for (Ledger_Hierarchy__c ledgerHierarchy : ledgerHierarchies) {
            if (!maxOrderForNewHierarchies.containsKey(getLhId(ledgerHierarchy.Parent_Ledger_Hierarchy__c, fakeLhId))) {
                if (ledgerHierarchy.Parent_Ledger_Hierarchy__c == null) {
                    ledgerHierarchy.Sort_Order__c = !lhParent.isEmpty() ? lhParent[0].Sort_Order__c + 1 : 1;
                }
                else if (sortOrders.containsKey(ledgerHierarchy.Parent_Ledger_Hierarchy__c)) {
                    ledgerHierarchy.Sort_Order__c = (Decimal) sortOrders.get(ledgerHierarchy.Parent_Ledger_Hierarchy__c).get('max') + 1;
                }
            }
            else if (maxOrderForNewHierarchies.containsKey(getLhId(ledgerHierarchy.Parent_Ledger_Hierarchy__c, fakeLhId))) {
                ledgerHierarchy.Sort_Order__c = maxOrderForNewHierarchies.get(getLhId(ledgerHierarchy.Parent_Ledger_Hierarchy__c, fakeLhId)) + 1;
            }
            else {
                ledgerHierarchy.Sort_Order__c = 1;
            }
            maxOrderForNewHierarchies.put(getLhId(ledgerHierarchy.Parent_Ledger_Hierarchy__c, fakeLhId), ledgerHierarchy.Sort_Order__c);
        }

    }

    private static Id getLhId(Id parentId, Id fakeId) {
        return parentId != null ? parentId : fakeId;
    }

    private static void requireFields(Ledger_Hierarchy__c ledgerHierarchy) {
        if (String.isBlank(ledgerHierarchy.Name)) {
            ledgerHierarchy.Name.addError(SObjectActions.REQUIRED_FIELD_ERROR);
        }
    }

}