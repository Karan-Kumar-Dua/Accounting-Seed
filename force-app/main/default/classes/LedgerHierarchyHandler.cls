public with sharing class LedgerHierarchyHandler {

    private static LedgerHierarchyHandler sharingInstance;
    private static LedgerHierarchyHandler withoutSharingInstance;

    private List<Ledger_Hierarchy__c> hierarchies;

    private LedgerHierarchyHandler(List<Ledger_Hierarchy__c> hierarchies) {
        this.hierarchies = hierarchies;
    }

    public static LedgerHierarchyHandler getInstanceWithSharing() {
        if (sharingInstance == null) {
            sharingInstance = new LedgerHierarchyHandler(getLedgerHierarchies());
        }
        return sharingInstance;
    }

    public static LedgerHierarchyHandler getInstanceWithoutSharing() {
        if (withoutSharingInstance == null) {
            withoutSharingInstance = new LedgerHierarchyHandler(DomainUtils.getLedgerHierarchies());
        }
        return withoutSharingInstance;
    }

    public static void reset() {
        sharingInstance = null;
        withoutSharingInstance = null;
    }

    private static List<Ledger_Hierarchy__c> getLedgerHierarchies() {
        List<String> fields = new List<String>{
            'Id',
            'Name',
            'Last_Period__c',
            'Last_Period__r.Name',
            'Last_Run__c',
            'Generated_By__c',
            'Generated_By__r.Name',
            'Ledger__c',
            'Ledger__r.Name',
            'Ledger__r.Type__c',
            'Notes__c',
            'Parent_Ledger_Hierarchy__c',
            'Root_Node_ID__c',
            'Hierarchy_Status__c',
            'Sort_Order__c',
            'Hierarchy_Type__c',
            'LastModifiedBy.Name'
        };

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            fields.add('Ledger__r.CurrencyIsoCode');
        }

        SOQLBuilder q = new SOQLBuilder(Ledger_Hierarchy__c.SObjectType);
        q.setStripInaccessible(AccessType.READABLE)
         .selectFields(fields);

        return (List<Ledger_Hierarchy__c>) q.getAccessDecisionResult(Database.query(q.toSOQL()));
    }

    public List<Ledger_Hierarchy__c> getAllHierarchies() {
        return hierarchies;
    }

    /**
     * Get hierarchy roots and all child nodes.
     * Returns all `Ledger_Hierarchy__c`s with either ID or `Root_Node_ID__c` equal to `rootNodeId`.
     */
    public List<Ledger_Hierarchy__c> getHierarchiesByRootId(Id rootNodeId) {
        List<Ledger_Hierarchy__c> filteredHierarchies = new List<Ledger_Hierarchy__c>();
        for (Ledger_Hierarchy__c hierarchy : hierarchies) {
            if (rootNodeId == hierarchy.Id || rootNodeId == hierarchy.Root_Node_ID__c) {
                filteredHierarchies.add(hierarchy);
            }
        }
        return filteredHierarchies;
    }

    /**
     * Get hierarchies by ID.
     * Returns all `Ledger_Hierarchy__c`s with ID in `hierarchyIds`.
     */
    public List<Ledger_Hierarchy__c> getHierarchiesByIds(Set<Id> hierarchyIds) {
        List<Ledger_Hierarchy__c> filteredHierarchies = new List<Ledger_Hierarchy__c>();
        for (Ledger_Hierarchy__c hierarchy : hierarchies) {
            if (hierarchyIds.contains(hierarchy.Id)) {
                filteredHierarchies.add(hierarchy);
            }
        }
        return filteredHierarchies;
    }

    /**
     * Get hierarchies by ledger ID.
     * Returns all `Ledger_Hierarchy__c`s with `Ledger__c` in `ledgerIds`.
     */
    public List<Ledger_Hierarchy__c> getHierarchiesByLedgerIds(Set<Id> ledgerIds) {
        List<Ledger_Hierarchy__c> filteredHierarchies = new List<Ledger_Hierarchy__c>();
        for (Ledger_Hierarchy__c hierarchy : hierarchies) {
            if (ledgerIds.contains(hierarchy.Ledger__c)) {
                filteredHierarchies.add(hierarchy);
            }
        }
        return filteredHierarchies;
    }

}