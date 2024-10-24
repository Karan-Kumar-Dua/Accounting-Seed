public with sharing class InventoryCostActions {

    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static String ERP_PACKAGE_QUALIFIER = GlobalVariables.ERPPACKAGE_QUALIFIER;
    public static final String UNIQUE_KEY_ERROR = Label.ERR_INVENTORY_COST_UNIQUE_KEY;
    public static final String INSERT_ERROR = Label.ERR_INVENTORY_COST_INSERT;
    public static final String UPDATE_ERROR = Label.ERR_INVENTORY_COST_UPDATE;
    public static final String DELETE_ERROR = Label.ERR_INVENTORY_COST_DELETE;
    public static Boolean isPreventInsertUpdateOverride = false;

    public static final Map<SObjectField, Integer> currencyAndNumberFields = new Map<SObjectField, Integer> {
        Inventory_Cost__c.Unit_Cost__c => 6
    };

    public static void requireFields(List<Inventory_Cost__c> newInventoryCosts) {
        for (Inventory_Cost__c newIC : newInventoryCosts) {
            if (newIC.Product__c == NULL) {
                newIC.Product__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
        }
    }

    public static void preventInventoryCostInsert(List<Inventory_Cost__c> newInventoryCosts) {
        for (Inventory_Cost__c newIC : newInventoryCosts) {
            if (isPreventInsertUpdateOverride) {
                break;
            }
            newIC.addError(INSERT_ERROR);
        }
    }

    public static void preventInventoryCostUpdate(Map<Id, Inventory_Cost__c> oldICMap, Map<Id, Inventory_Cost__c> newICMap) {
        if (isPreventInsertUpdateOverride) {
            return;
        }
        for (Inventory_Cost__c newIC : newICMap.values()) {
            Inventory_Cost__c oldIC = oldICMap.get(newIC.Id);
            if (oldIC.Ledger__c != newIC.Ledger__c || oldIC.Unit_Cost__c != newIC.Unit_Cost__c || oldIC.Product__c != newIC.Product__c) {
                newIC.addError(UPDATE_ERROR);
            }
        }
    }

    public static void preventInventoryCostDelete(List<Inventory_Cost__c> oldInventoryCosts) {
        Set<String> inventoryBalances = new Set<String>();
        Set<Id> productIds = new Set<Id>();
        Set<Id> ledgerIds = new Set<Id>();

        for (Inventory_Cost__c oldIC : oldInventoryCosts) {
            productIds.add(oldIC.Product__c);
            ledgerIds.add(oldIC.Ledger__c);
        }

        for (SObject ib : DomainUtils.getInventoryBalancesByProductByLedger(productIds, ledgerIds)) {
            inventoryBalances.add((String) ib.get(ERP_PACKAGE_QUALIFIER + 'Ledger__c') + (String) ib.get(ERP_PACKAGE_QUALIFIER + 'Product__c'));
        }

        for (Inventory_Cost__c oldIC : oldInventoryCosts) {
            if (inventoryBalances.contains((String) oldIC.Ledger__c + (String) oldIC.Product__c)) {
                oldIC.addError(DELETE_ERROR);
            }
        }
    }

    public static void preventInventoryCostDuplicates(List<Inventory_Cost__c> newInventoryCosts) {

        Set<Id> ledgerIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();
        Set<String> newInventoryCostsIds = new Set<String>();
        for (Inventory_Cost__c newIC : newInventoryCosts) {
            newInventoryCostsIds.add(newIC.Id);
            ledgerIds.add(newIC.Ledger__c);
            productIds.add(newIC.Product__c);
        }

        List<Inventory_Cost__c> existedIC = DomainUtils.getInventoryCostByProductIdAndLedgerId(productIds, ledgerIds);

        if (!existedIC.isEmpty()) {
            Set<String> existedICKey = new Set<String>();

            for (Inventory_Cost__c existIC : existedIC) {
                if (!newInventoryCostsIds.contains(String.valueOf(existIC.Id))) {
                    existedICKey.add(getICKey(existIC));
                }
            }

            for (Inventory_Cost__c newIC : newInventoryCosts) {
                if (existedICKey.contains(getICKey(newIC))) {
                    newIC.addError(UNIQUE_KEY_ERROR);
                }
            }
        }

    }

    private static String getICKey(Inventory_Cost__c icItem) {
        String key = String.valueOf(icItem.Product__c) + String.valueOf(icItem.Ledger__c);
        return key;
    }

}