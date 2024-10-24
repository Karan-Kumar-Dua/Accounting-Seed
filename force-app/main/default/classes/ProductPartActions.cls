public with sharing class ProductPartActions {

    public static final Integer MANUFACTURED_PRODUCT_PART_LIMIT = 100;
    public static final String KIT_PRODUCT_PART_LIMIT_ERROR = Label.ERR_KIT_PRODUCT_PART_LIMIT;
    public static final String MANUFACTURED_PRODUCT_PART_LIMIT_ERROR = Label.ERR_MANUFACTURED_PRODUCT_PART_LIMIT;
    public static final String PRODUCT_CHANGE_ERROR = Label.ERR_PRODUCT_CHANGE;

    public static final Integer KIT_PRODUCT_PART_LIMIT {
        get {
            KIT_PRODUCT_PART_LIMIT = 249;
            if (AccountingSettingsHandler.isStandardCostProductCostingEnabled()) {
                KIT_PRODUCT_PART_LIMIT = 5;
            }
            return KIT_PRODUCT_PART_LIMIT;
        }
        private set;
    }

    public static void validateProductPartRowsQuantity(List<Product_Part__c> newProductsPart) {
        Map<Id, List<Product_Part__c>> productPartProductMap = new  Map<Id, List<Product_Part__c>>();

        for (Product_Part__c part : newProductsPart) {
            if (part.Product__c != NULL && productPartProductMap.containsKey(part.Product__c)) {
                productPartProductMap.get(part.Product__c).add(part);
            }
            else if (part.Product__c != NULL && !productPartProductMap.containsKey(part.Product__c)) {
                productPartProductMap.put(part.Product__c, new List<Product_Part__c>{part});
            }
        }

        Map<Id, AggregateResult> kitProductPartsCountMap = DomainUtils.getProductPartsByProductCount(
            productPartProductMap.keySet(), 'Kit', KIT_PRODUCT_PART_LIMIT
        );
        Map<Id, AggregateResult> manufacturedProductPartsCountMap = DomainUtils.getProductPartsByProductCount(
            productPartProductMap.keySet(), 'Manufactured', MANUFACTURED_PRODUCT_PART_LIMIT
        );

        Set<Id> allProductIds = new Set<Id>();
        allProductIds.addAll(kitProductPartsCountMap.keySet());
        allProductIds.addAll(manufacturedProductPartsCountMap.keySet());

        if (!allProductIds.isEmpty()) {
            for (Id key : allProductIds) {
                if (kitProductPartsCountMap.containsKey(key)) {
                    for (Product_Part__c part : productPartProductMap.get(key)) {
                        part.Product__c.addError(getKitProductPartLimitError());
                    }
                }
                if (manufacturedProductPartsCountMap.containsKey(key)) {
                    for (Product_Part__c part : productPartProductMap.get(key)) {
                        part.Product__c.addError(getManufacturedProductPartLimitError()); 
                    }
                }
            }
        }

    }

    public static void validateMasterProductChanges(Map<Id,Product_Part__c> newProductMap, Map<Id,Product_Part__c> oldProductMap) {
        for (Product_Part__c partNew : newProductMap.values()) {
            Product_Part__c partOld = oldProductMap.get(partNew.Id);
            if (partNew.Product__c != partOld.Product__c) {
                partNew.Product__c.addError(PRODUCT_CHANGE_ERROR);
            }
        }
    }

    @TestVisible
    private static String getManufacturedProductPartLimitError() {
        return String.format(MANUFACTURED_PRODUCT_PART_LIMIT_ERROR, new String[]{String.valueOf(MANUFACTURED_PRODUCT_PART_LIMIT)});
    }
    
    @TestVisible
    private static String getKitProductPartLimitError() {
        return String.format(KIT_PRODUCT_PART_LIMIT_ERROR, new String[]{String.valueOf(KIT_PRODUCT_PART_LIMIT)});
    }
}