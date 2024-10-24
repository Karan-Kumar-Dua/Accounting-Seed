public with sharing class LedgerHierarchyModel {
    public Ledger_Hierarchy__c value;
    public List<LedgerHierarchyModel> children;
    private Iterator iteratorInstance;

    public LedgerHierarchyModel(Ledger_Hierarchy__c value) {
        this.value = value;
        this.children = new List<LedgerHierarchyModel>();
    }

    public Set<Id> getChildLedgers() {
        Set<Id> result = new Set<Id>();
        for (LedgerHierarchyModel child : children) {
            result.add(child.value.Ledger__c);
        }
        return result;
    }

    public Boolean hasChildren() {
        return children != null && !children.isEmpty();
    }

    public Boolean needTranslations() {
        Boolean result = false;
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            for (LedgerHierarchyModel child : children) {
                String mainCurrency = String.valueOf(this.value.getSObject('Ledger__r').get('CurrencyIsoCode'));
                String childCurrency = String.valueOf(child.value.getSObject('Ledger__r').get('CurrencyIsoCode'));
                if (mainCurrency != childCurrency) {
                    result = true;
                    break;
                }
            }
        }
        return result;
    }

    public Iterator getIterator() {
        if (iteratorInstance == null) {
            iteratorInstance = new Iterator(this);
        }
        return iteratorInstance;
    }

    /**
     * Iterates over a `LedgerHierarchyModel` using a 
     * postorder traversal strategy.
     */
    public with sharing class Iterator {
        LedgerHierarchyModel model;
        List<LedgerHierarchyModel> queue;

        public Iterator(LedgerHierarchyModel model) {
            this.model = model;
            this.buildQueue();
        }

        public LedgerHierarchyModel next() {
            if (hasNext()) {
                return queue.remove(0);
            }
            return null;
        }

        public LedgerHierarchyModel viewNext() {
            if (hasNext()) {
                return queue.get(0);
            }
            return null;
        }

        public Boolean hasNext() {
            return !queue.isEmpty();
        }

        private void buildQueue() {
            queue = new List<LedgerHierarchyModel>();
            if (model.hasChildren()) {  
                // model is for a non-leaf node
                buildQueue(model);
            }
            else {  
                // model is for a leaf node
                queue.add(model);
            }
        }

        // recursive!!!
        private void buildQueue(LedgerHierarchyModel current) {
            if (current.hasChildren()) {
                for (LedgerHierarchyModel child : current.children) {
                    buildQueue(child);
                }
                queue.add(current);
            }
        }

    }
}