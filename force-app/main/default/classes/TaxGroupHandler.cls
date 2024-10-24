public class TaxGroupHandler {
    private Map<Id, Tax_Group__c> taxGroups;
    private Map<Id, Id> productIdToGroupTaxIdMap;

    private static TaxGroupHandler instance;

    public static TaxGroupHandler getInstance() {
        if (instance == NULL) {
            instance = new TaxGroupHandler();
        }
        return instance;
    }

    public static void reset() {
        instance = NULL;
    }
    
    public TaxGroupHandler() {
        taxGroups = new Map<Id, Tax_Group__c>();
        productIdToGroupTaxIdMap = new Map<Id, Id>();
    }

    public Tax_Group__c getTaxGroup(Id taxGroupId) {
        Tax_Group__c taxGroup;
        if (hasTaxGroup(taxGroupId)) {
            taxGroup = taxGroups.get(taxGroupId);
        }
        return taxGroup;
    }

    public Map<Id, Tax_Group__c> getTaxGroupsMap() {
        return taxGroups;
    }

    public Boolean hasTaxGroup(Id taxGroupId) {
        return taxGroups.containsKey(taxGroupId);
    }

    public Boolean hasTaxGroupByProductId(Id prodId) {
        Id taxGroupId;
        if (productIdToGroupTaxIdMap.containsKey(prodId)) {
            taxGroupId = productIdToGroupTaxIdMap.get(prodId);
        }

        return taxGroupId != NULL && hasTaxGroup(taxGroupId);
    }

    public Tax_Group__c getTaxGroupByProductId(Id prodId) {
        Tax_Group__c taxGroup;

        if (hasTaxGroupByProductId(prodId)) {
            Id taxGroupId = productIdToGroupTaxIdMap.get(prodId);
            taxGroup = getTaxGroup(taxGroupId);
        }

        return taxGroup;
    }

    public TaxGroupHandler setTaxGroupsByProductIds(Set<Id> prodIds) {
        if (!productIdToGroupTaxIdMap.keySet().containsAll(prodIds)) {
            for (Product2 prod : DomainUtils.getProductsById(prodIds)) {
                if (prod.Tax_Group__c != NULL) {
                    productIdToGroupTaxIdMap.put(prod.Id, prod.Tax_Group__c);
                }
            }
        }

        return instance;
    }

    public TaxGroupHandler setTaxGroupsByTaxGroupIds() {

        if (!taxGroups.keySet().containsAll(productIdToGroupTaxIdMap.values())) {
            taxGroups.putAll(DomainUtils.getTaxGroupWithTaxRatesByIds(new Set<Id>(productIdToGroupTaxIdMap.values())));
        }

        return instance;
    }

    public TaxGroupHandler setTaxGroupsByTaxGroupIds(Set<Id> taxGroupIds) {
        if (!taxGroups.keySet().containsAll(productIdToGroupTaxIdMap.values())) {
            taxGroupIds.addAll(productIdToGroupTaxIdMap.values());
        }
        if (!taxGroups.keySet().containsAll(taxGroupIds)) {
            taxGroups.putAll(DomainUtils.getTaxGroupWithTaxRatesByIds(taxGroupIds));
        }

        return instance;
    }

    public TaxGroupHandler setTaxGroupsBySObjects(List<SObject> sObjs) {
        Set<Id> taxGroupIds = new Set<Id>();

        for (SObject obj : sObjs) {
            HeaderLevelTaxHelper.SourceDocumentTaxDecorator sdt = new HeaderLevelTaxHelper.SourceDocumentTaxDecorator(obj);
            if (!sdt.isTaxGroupNull() && !taxGroups.containsKey(sdt.getTaxGroupId())) {
                taxGroupIds.add(sdt.getTaxGroupId());
            }
            else if (!sdt.isTaxGroupNull() && taxGroups.containsKey(sdt.getTaxGroupId())) {
                Tax_Group__c taxGroup = taxGroups.get(sdt.getTaxGroupId());
                taxGroups.put(taxGroup.Id, taxGroup);
            }
        }

        if (!taxGroupIds.isEmpty()) {
            setTaxGroupsByTaxGroupIds(taxGroupIds);
        }
        
        return instance;
    }

    public static Map<Id, Tax_Group__c> getTaxGroupsBySObject(List<SObject> sObjs) {
        return TaxGroupHandler.getInstance().setTaxGroupsBySObjects(sObjs).getTaxGroupsMap();
    }
}