public with sharing class InventoryCostHandler {
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static InventoryCostHandler instance;

    @TestVisible
    private Boolean isAverageCostEnabled;
    private Map<Id, Map<String, InventoryCostModel>> inventoryCostProductIdMap;

    public class InventoryCostHandlerException extends Exception {}

    private InventoryCostHandler() {
        init();
    }

    public static InventoryCostHandler getInstance() {
        if (instance == NULL) {
            instance = new InventoryCostHandler();
        }

        return instance;
    }

    public with sharing class InventoryCostModel {
        public Id inventoryCostId;
        public Id productId;
        public Id ledgerId;
        public Decimal unitCost;
    }
    
    public with sharing class InventoryCost {
        public Id inventoryCostId;
        public Id productId;
        public Id ledgerId;
        public Decimal unitCost;
        private Boolean isAverageCostEnabled;

        public InventoryCost(Sobject obj, Boolean isAverageCostEnabled) {
            this.isAverageCostEnabled = isAverageCostEnabled;
            String productField = isAverageCostEnabled ? PACKAGE_QUALIFIER + 'Product__c' : 'Id';
            productId = (Id) obj.get(productField);
            unitCost = (Decimal) obj.get(PACKAGE_QUALIFIER + 'Unit_Cost__c');
            ledgerId = isAverageCostEnabled ? (Id) obj.get(PACKAGE_QUALIFIER + 'Ledger__c') : NULL;
            inventoryCostId = isAverageCostEnabled ? (Id) obj.get('Id') : NULL;
        }
    
        public InventoryCost(Id productId, Boolean isAverageCostEnabled) {
            this.isAverageCostEnabled = isAverageCostEnabled;
            this.productId = productId;
            unitCost = 0;
            ledgerId = NULL;
        }

        public InventoryCost(InventoryMovement imo, Boolean isAverageCostEnabled) {
            this.isAverageCostEnabled = isAverageCostEnabled;
            productId = imo.productId;
            unitCost = imo.invMovUnitCost;
            ledgerId = imo.ledgerId;
        }

        public InventoryCost(InventoryCostModel ico, Boolean isAverageCostEnabled) {
            this.isAverageCostEnabled = isAverageCostEnabled;
            inventoryCostId = ico.inventoryCostId;
            productId = ico.productId;
            unitCost = ico.unitCost;
            ledgerId = ico.ledgerId;
        }
        
        public void setUnitCost(Decimal unitCost) {
            this.unitCost = unitCost;
        }
        
        public void setInventoryCostId(Id inventoryCostId) {
            this.inventoryCostId = inventoryCostId;
        }

        public String getInventoryCostKey() {
            return isAverageCostEnabled ? String.valueOf(productId) + String.valueOf(ledgerId) : String.valueOf(productId);
        }

        public Decimal getUnitCost() {
            return unitCost != NULL && unitCost > 0 ? unitCost : 0;
        }

        public void calculateUnitCost(InventoryMovement imo) {
            if (imo.invBalQuantity + imo.invMovQuantity > 0) {
                unitCost = ((imo.invBalQuantity * getUnitCost()) + (imo.invMovQuantity * imo.invMovUnitCost)) / (imo.invBalQuantity + imo.invMovQuantity);
            }
            else if (imo.invBalQuantity + imo.invMovQuantity <= 0) {
                unitCost = 0;
            }
        }

        public InventoryCostModel getInventoryCostModel() {
            InventoryCostModel icm = new InventoryCostModel();
            icm.inventoryCostId = inventoryCostId;
            icm.productId = productId;
            icm.ledgerId = ledgerId;
            icm.unitCost = unitCost;
            return icm;
        }

        public Inventory_Cost__c getInventoryCostSobject() {
            return new Inventory_Cost__c (
                Id = inventoryCostId,
                Product__c = productId,
                Ledger__c = ledgerId,
                Unit_Cost__c = unitCost
            );
        }

        public Inventory_Cost__c getInventorCostSobject(InventoryMovement imo) {
            return new Inventory_Cost__c (
                Product__c = imo.productId,
                Ledger__c = imo.ledgerId,
                Unit_Cost__c = imo.invMovUnitCost
            );
        }
    }

    public with sharing class InventoryMovement {
        public Id productId;
        public Id ledgerId;
        public Decimal invBalQuantity;
        public Decimal invMovQuantity;
        public Decimal invMovUnitCost;

        public String getInventoryCostKey() {
            return !String.isBlank(ledgerId) ? String.valueOf(productId) + String.valueOf(ledgerId) : String.valueOf(productId);
        }
    }
    
    private void init() {
        inventoryCostProductIdMap = new Map<Id, Map<String, InventoryCostModel>>();
        isAverageCostEnabled = AccountingSettingsHandler.isInventoryValuationAverageCost();
    }

    private void populateUnitCostMap(Set<Id> productIds) {
        Set<Id> productsNotInInventoryCostMap = getProductsNotInInventoryCostMap(productIds);
        List<SObject> objList = new List<SObject>();
        if (isAverageCostEnabled && !productsNotInInventoryCostMap.isEmpty()) {
            objList = DomainUtils.getInventoryCostByProductId(productsNotInInventoryCostMap);
        }
        else if (!productsNotInInventoryCostMap.isEmpty()) {
            objList = DomainUtils.getProductsById(productsNotInInventoryCostMap);
        }
        populateInventoryCostProductIdMapFromSource(objList);
    }

    private void populateInventoryCostProductIdMapFromSource(List<SObject> sourceList) {
        for (SObject obj : sourceList) {
            InventoryCost icObj = new InventoryCost(obj,isAverageCostEnabled);
            addInventoryCostProductIdMap(icObj);
        }
    }

    private void addInventoryCostProductIdMap(InventoryCost icObj) {
        if (!inventoryCostProductIdMap.containsKey(icObj.productId)) {
            inventoryCostProductIdMap.put(
                icObj.productId,
                new Map<String, InventoryCostModel> {icObj.getInventoryCostKey() => icObj.getInventoryCostModel()}
            );
        }
        else  {
            inventoryCostProductIdMap.get(icObj.productId).put(icObj.getInventoryCostKey(), icObj.getInventoryCostModel());
        }
    }

    private Set<Id> getProductsNotInInventoryCostMap(Set<Id> productIds) {
        Set<Id> result = new Set<Id>();
        for (Id productId : productIds) {
            if (!inventoryCostProductIdMap.containsKey(productId)) {
                result.add(productId);
            }
        }

        return result;
    }

    private Map<Id, List<InventoryCostModel>> getInventoryCostMapByProductIds(Set<Id> productIds) {
        Map<Id, List<InventoryCostModel>> result = new Map<Id, List<InventoryCostModel>>();
        for (Id productId : productIds) {
            if (inventoryCostProductIdMap.containsKey(productId)) {
                result.put(productId, inventoryCostProductIdMap.get(productId).values());
            }
            else {
                result.put(productId, new List<InventoryCostModel> {new InventoryCost(productId,this.isAverageCostEnabled).getInventoryCostModel()});
            }
        }
        return result;
    }

    //=================================================================================================
    //================================== INSTANCE UTILITY METHODS =====================================
    //=================================================================================================

    public Map<Id, List<InventoryCostModel>> getUnitCostByProductId(Set<Id> productIds) {
        populateUnitCostMap(productIds);
        Map<Id, List<InventoryCostModel>> result = getInventoryCostMapByProductIds(productIds);
        return result;
    }

    public List<InventoryCostModel> getUnitCostByProductId(Id productId) {
        return getUnitCostByProductId(new Set<Id> {productId}).get(productId);
    }
    
    private Inventory_Cost__c getInventoryCostFromIMO(InventoryMovement imo) {
        Inventory_Cost__c icObj;
        InventoryCost ic;

        if (inventoryCostProductIdMap.containsKey(imo.productId)
            && inventoryCostProductIdMap.get(imo.productId).containsKey(imo.getInventoryCostKey())) {
            InventoryCostModel icm = inventoryCostProductIdMap.get(imo.productId).get(imo.getInventoryCostKey());
            ic = new InventoryCost(icm,isAverageCostEnabled);
            icObj = ic.getInventoryCostSobject();
        }
        else {
            ic = new InventoryCost(imo,isAverageCostEnabled);
            icObj = ic.getInventorCostSobject(imo);
        }

        return icObj;
    }

    private void updateInventoryCostIdAfterUpsert(Map<String,Inventory_Cost__c> upsertMap) {
        for (String inventoryKey : upsertMap.keySet()) {
            Inventory_Cost__c ic = upsertMap.get(inventoryKey);
            String productId = String.valueOf(ic.Product__c);

            if (inventoryCostProductIdMap.containsKey(productId)) {
                InventoryCostModel icm = inventoryCostProductIdMap.get(productId).get(inventoryKey);
                icm.inventoryCostId = ic.Id;
                inventoryCostProductIdMap.get(productId).put(inventoryKey,icm);
            }
        }
    }

    //=================================================================================================
    //================================== STATIC UTILITY METHODS =====================================
    //=================================================================================================
    
    public static void upsertInventoryCost(List<InventoryMovement> imObjects) {
        if (InventoryCostHandler.getInstance().isAverageCostEnabled) {
            InventoryCostHandler icHandler = InventoryCostHandler.getInstance();

            Set<Id> productIds = new Set<Id>();
            for (InventoryMovement im : imObjects) {
                productIds.add(im.productId);
            }

            Map<String,Inventory_Cost__c> upsertMap = new Map<String,Inventory_Cost__c>();
            icHandler.getUnitCostByProductId(productIds);

            for (InventoryMovement imo : imObjects) {
                InventoryCost ic = new InventoryCost(imo,icHandler.isAverageCostEnabled);  
                Inventory_Cost__c icObj;         
                    
                if (upsertMap.containsKey(ic.getInventoryCostKey())) {
                    icObj = upsertMap.get(ic.getInventoryCostKey());
                }
                else {
                    icObj = icHandler.getInventoryCostFromIMO(imo);
                }
                
                ic.setInventoryCostId(icObj.Id);
                ic.setUnitCost(icObj.Unit_Cost__c);
                ic.calculateUnitCost(imo);
                icObj = ic.getInventoryCostSobject();
                icHandler.addInventoryCostProductIdMap(ic);
                upsertMap.put(ic.getInventoryCostKey(),icObj);
            }

            DomainUtils.inventoryCostForUpdate(upsertMap.values());
            InventoryCostActions.isPreventInsertUpdateOverride = true;
            SFDCSecurityUtils.upsertProxy(upsertMap.values());
            InventoryCostActions.isPreventInsertUpdateOverride = false;
            icHandler.updateInventoryCostIdAfterUpsert(upsertMap);

        }
    }
}