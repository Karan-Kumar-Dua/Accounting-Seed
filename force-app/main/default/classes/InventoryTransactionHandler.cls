public with sharing class InventoryTransactionHandler {

    private List<InventoryTransactionSource> sourceRecordList;
    private Map<Id, List<Product_Part__c>> productProductPartMap;
    public Set<Id> productIds {get; private set;}
    private Boolean isInventoryValuationAverageCost;
    private static InventoryTransactionHandler ict;
    private static final String ERPPACKAGE_QUALIFIER = GlobalVariables.ERPPACKAGE_QUALIFIER;

    private Map<Id, List<InventoryCostHandler.InventoryCostModel>> inventoryCostByProduct;
    private Boolean isIncludeKitChildProductsInvCost;

    private InventoryTransactionHandler(List<InventoryTransactionSource> sourceRecordList, Boolean isIncludeKitChildProductsInvCost) {
        this.isIncludeKitChildProductsInvCost = isIncludeKitChildProductsInvCost;
        this.sourceRecordList = sourceRecordList;
        isInventoryValuationAverageCost = AccountingSettingsHandler.isInventoryValuationAverageCost();
        inventoryCostByProduct = new Map<Id, List<InventoryCostHandler.InventoryCostModel>>();
    }

    public static void createInvCostTransactionsExcludeKitChildProducts(List<InventoryTransactionSource> sourceRecordList) {
        TransactionActions.createTransactions(getProductTransactions(sourceRecordList,false));
    }

    public static List<Transaction__c> getInvCostTransactionsIncludeKitChildProducts(List<InventoryTransactionSource> sourceRecordList) {
        return getProductTransactions(sourceRecordList, true);
    }

    private static List<Transaction__c> getProductTransactions(List<InventoryTransactionSource> sourceRecordList, Boolean isIncludeKitChildProductsInvCost) {

        List<Transaction__c> transList = new List<Transaction__c>();
        if (!sourceRecordList.isEmpty()) {
            ict = new InventoryTransactionHandler(sourceRecordList,isIncludeKitChildProductsInvCost);
            ict.getProductAndProductPartIds();
            ict.populateProductPartMap();

            ict.inventoryCostByProduct = InventoryCostHandler.getInstance().getUnitCostByProductId(ict.productIds);

            for (InventoryTransactionSource invTransSource : sourceRecordList) {
                if (invTransSource.isProduct() && isIncludeKitChildProductsInvCost && ict.productProductPartMap.get(invTransSource.productId) != NULL) {
                    List<Transaction__c> prodPartTransList = getProductPartTransactions(invTransSource);
                    transList.addAll(prodPartTransList);
                }
                else if(invTransSource.isProduct()) {
                    Decimal productUnitCost = ict.getUnitCostFromInventoryCostItem(invTransSource);

                    Transaction__c prodCostTrans = invTransSource.createProductCostingTransaction();
                    prodCostTrans.GL_Account__c = invTransSource.debitGLAccountId;
                    prodCostTrans.Units__c = invTransSource.getQuantity();
                    prodCostTrans.Amount__c = invTransSource.getAmount(productUnitCost);
                    transList.add(prodCostTrans);

                    prodCostTrans = invTransSource.createProductCostingTransaction();
                    prodCostTrans.GL_Account__c = invTransSource.creditGLAccountId;
                    prodCostTrans.Units__c = (invTransSource.getQuantity() * -1);
                    prodCostTrans.Amount__c = (invTransSource.getAmount(productUnitCost) * -1);
                    transList.add(prodCostTrans);
                }
            }
        }
        return transList;
    }

    private static List<Transaction__c> getProductPartTransactions(InventoryTransactionSource invTransSource) {
        List<Transaction__c> transList = new List<Transaction__c>();

        for (Product_Part__c productPart : ict.productProductPartMap.get(invTransSource.productId)) {
            if (ict.isInventoriedAndCorrectTypeProduct(productPart.Product_Part__r)) {
                Decimal productPartUnitCost = ict.getUnitCostFromProductPart(productPart, invTransSource.ledgerId);

                Transaction__c prodCostTrans = invTransSource.createProductCostingTransaction();
                prodCostTrans.GL_Account__c = productPart.Product_Part__r.Expense_GL_Account__c;
                prodCostTrans.Units__c = invTransSource.getProductPartsQuantity(invTransSource.getQuantity(), invTransSource.getProductPartQuantity(productPart.Quantity__c));
                prodCostTrans.Amount__c = invTransSource.getProductPartAmount(productPartUnitCost, invTransSource.getProductPartQuantity(productPart.Quantity__c));
                invTransSource.setGLVariablesAndProduct(prodCostTrans, productPart);
                transList.add(prodCostTrans);

                prodCostTrans = invTransSource.createProductCostingTransaction();
                prodCostTrans.GL_Account__c = productPart.Product_Part__r.Inventory_GL_Account__c;
                prodCostTrans.Units__c = (invTransSource.getProductPartsQuantity(invTransSource.getQuantity(), invTransSource.getProductPartQuantity(productPart.Quantity__c))) * -1;
                prodCostTrans.Amount__c = (invTransSource.getProductPartAmount(productPartUnitCost, invTransSource.getProductPartQuantity(productPart.Quantity__c))* -1);
                invTransSource.setGLVariablesAndProduct(prodCostTrans, productPart);

                transList.add(prodCostTrans);
            }
        }
        return transList;
    }

    private Boolean isInventoriedAndCorrectTypeProduct(Product2 prod) {
        return prod.Inventory_Product__c
            && (prod.Inventory_Type__c == 'Purchased'
            || prod.Inventory_Type__c == 'Manufactured'
            || (prod.Inventory_Type__c == 'Kit'));
    }

    private Decimal getUnitCostFromInventoryCostItem(InventoryTransactionSource pci) {
        Decimal result = 0;
        if(pci.isUnitCost()){
            result = pci.unitCost;
        }else{
            result = getUnitCostFromProductId(pci.productId, pci.getKey());
        }
        return result != null ? result.setScale(6, RoundingMode.HALF_UP): 0;
    }

    private Decimal getUnitCostFromProductPart(Product_Part__c productPart, String ledgerId) {
        Decimal result = 0;
        if(isInventoryValuationAverageCost){
            result = getUnitCostFromProductId(productPart.Product_Part__c, String.valueOf(productPart.Product_Part__c) + ledgerId);
        }else{
            result = productPart.Product_Part__r.Unit_Cost__c;
        }
        return result != null ? result.setScale(6, RoundingMode.HALF_UP): 0;
       
    }

    private Decimal getUnitCostFromProductId(Id productId, String key) {
        Decimal result = 0;
        List<InventoryCostHandler.InventoryCostModel> icResults = inventoryCostByProduct.get(productId);
        for (InventoryCostHandler.InventoryCostModel icResult : icResults) {
            InventoryCostHandler.InventoryCost ic = new InventoryCostHandler.InventoryCost(productId, isInventoryValuationAverageCost);
            if (ic.getInventoryCostKey() == key) {
                result = ic.getUnitCost();
            }
        }
        return result != null ? result.setScale(6, RoundingMode.HALF_UP): 0;
    }

    private void getProductAndProductPartIds() {
        productProductPartMap = new Map<Id, List<Product_Part__c>>();
        productIds = new Set<Id>();

        for (InventoryTransactionSource pci : sourceRecordList) {
            if (isIncludeKitChildProductsInvCost && pci.isProduct() && pci.isInventoryKitProduct()) {
                productProductPartMap.put(pci.productId, NULL);
            }

            if (pci.productId != NULL && pci.unitCost == NULL) {
                productIds.add(pci.productId);
            }
        }
    }

    private void populateProductPartMap() {
        if (isIncludeKitChildProductsInvCost && !productProductPartMap.keySet().isEmpty()) {
            for (Product_Part__c part : DomainUtils.getProductPartsByProductId(productProductPartMap.keySet())) {
                Id productId = part.Product__c;
                if (productProductPartMap.get(productId) != NULL) {
                    productProductPartMap.get(productId).add(part);
                }
                else {
                    productProductPartMap.put(productId, new List<Product_Part__c>{part});
                }

                if (isInventoryValuationAverageCost) {
                    productIds.add(part.Product__c);
                    productIds.add(part.Product_Part__c);
                }
            }
        }
    }

    public enum SourceType {BILLING_LINE, SO_INVENTORY_MOVEMENT, PO_INVENTORY_MOVEMENT, I_INVENTORY_MOVEMENT, O_INVENTORY_MOVEMENT, MO_INVENTORY_MOVEMENT}

    public class InventoryTransactionSource {
        public String inventoryType {get; set;}
        public Id sourceId {get; set;}
        public SourceType itemSourceType {get; set;}
        public Decimal quantity {get; set;}
        public Decimal unitCost {get; set;}
        public String ledgerId {get; set;}
        public Id accountingPeriodId {get; set;}
        public Id debitGLAccountId {get; set;}
        public Id creditGLAccountId {get; set;}
        public Date sourceDate {get; set;}
        public Id productId {get; set;}
        public Id projectId {get; set;}
        public Id projectTaskId {get; set;}
        public Id accountId {get; set;}
        public Id employeeId {get; set;}
        public String note {get; set;}
        public String description {get; set;}
        public Id glVariable1 {get; set;}
        public Id glVariable2 {get; set;}
        public Id glVariable3 {get; set;}
        public Id glVariable4 {get; set;}

        public Boolean isInventoryKitProduct() {
            return inventoryType == 'Kit';
        }

        public Boolean isProduct() {
            return !String.isBlank(productId);
        }

        public Boolean isUnitCost() {
            return unitCost != NULL;
        }

        public String getKey() {
            return String.valueOf(ledgerId) + String.valueOf(productId);
        }

        public Decimal getAmount(Decimal productUnitCost) {
            return (getQuantity() * productUnitCost).setScale(2, RoundingMode.HALF_UP);
        }

        public Decimal getProductPartAmount(Decimal productPartUnitCost, Decimal productPartQuantity) {
            return ((getQuantity() * productPartUnitCost).setScale(2, RoundingMode.HALF_UP) 
                    * getProductPartQuantity(productPartQuantity))
                    .setScale(2, RoundingMode.HALF_UP);
        }

        public Decimal getQuantity(){
            return quantity != null ? quantity.setScale(6, RoundingMode.HALF_UP) : 0;
        }

        public Decimal getProductPartQuantity(Decimal prodPartQuantity) {
            return prodPartQuantity != null ? prodPartQuantity.setScale(6,RoundingMode.HALF_UP) : 0;
        }

        public Decimal getProductPartsQuantity(Decimal quantity, Decimal prodPartQuantity) {
            return (quantity * prodPartQuantity).setScale(6, RoundingMode.HALF_UP);
        }

        public Boolean isSourceBillingLine() {
           return itemSourceType == SourceType.BILLING_LINE;
        }

        public Transaction__c createProductCostingTransaction() {
            Transaction__c pt = new Transaction__c();

            pt.Billing_Line__c = isSourceBillingLine() ? sourceId : NULL;

            setTransactionSource(pt);

            pt.Ledger__c = ledgerId;
            pt.Accounting_Period__c = accountingPeriodId;
            pt.Date__c = sourceDate;
            pt.Project_Task__c = projectTaskId;
            pt.Project__c = projectId;
            pt.Employee__c = employeeId;
            pt.Account__c = accountId;
            pt.Note__c = note;
            pt.Product__c = productId;
            pt.GL_Account_Variable_1__c = glVariable1;
            pt.GL_Account_Variable_2__c = glVariable2;
            pt.GL_Account_Variable_3__c = glVariable3;
            pt.GL_Account_Variable_4__c = glVariable4;

            return pt;
        }

        public void setGLVariablesAndProduct(Transaction__c pt, Product_Part__c productPart) {
            pt.Product__c = productPart.Product_Part__c;
            pt.GL_Account_Variable_1__c = glVariable1 != NULL ? glVariable1 : productPart.Product_Part__r.GL_Account_Variable_1__c;
            pt.GL_Account_Variable_2__c = glVariable2 != NULL ? glVariable2 : productPart.Product_Part__r.GL_Account_Variable_2__c;
            pt.GL_Account_Variable_3__c = glVariable3 != NULL ? glVariable3 : productPart.Product_Part__r.GL_Account_Variable_3__c;
            pt.GL_Account_Variable_4__c = glVariable4 != NULL ? glVariable4 : productPart.Product_Part__r.GL_Account_Variable_4__c;
        }

        private void setTransactionSource(Transaction__c pt) {
            if (!isSourceBillingLine()) {
                switch on itemSourceType {
                    when SO_INVENTORY_MOVEMENT {
                        pt.put(ERPPACKAGE_QUALIFIER + 'Sales_Order_Inventory_Movement__c', sourceId);
                    }
                    when PO_INVENTORY_MOVEMENT {
                        pt.put(ERPPACKAGE_QUALIFIER + 'Purchase_Order_Inventory_Movement__c', sourceId);
                    }
                    when I_INVENTORY_MOVEMENT {
                        pt.put(ERPPACKAGE_QUALIFIER + 'Inbound_Inventory_Movement__c', sourceId);
                    }
                    when O_INVENTORY_MOVEMENT {
                        pt.put(ERPPACKAGE_QUALIFIER + 'Outbound_Inventory_Movement__c', sourceId);
                    }
                    when MO_INVENTORY_MOVEMENT {
                        pt.put(ERPPACKAGE_QUALIFIER + 'Manufacturing_Inventory_Movement__c', sourceId);
                    }
                }
            }
        }
    }
}