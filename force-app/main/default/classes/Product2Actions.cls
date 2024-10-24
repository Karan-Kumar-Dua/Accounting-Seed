public with sharing class Product2Actions {
    public static final String TAX_RATE_BLANK_ERROR =
        Label.ERR_TAX_RATE_BLANK;
    public static final String TAX_TYPE_UPDATE_ERROR = Label.ERR_TAX_TYPE_UPDATE;
    public static final String REVENUE_GL_ACCOUNT_UPDATE_ERROR =
        Label.ERR_REVENUE_GL_ACCOUNT_UPDATE;
    public static final String TYPE_UPDATE_ERROR = Label.ERR_TYPE_UPDATE;

    public static void preventUpdateTaxRateProduct(List<Product2> newProducts, Map<Id, Product2> oldProductMap) {
        //As a first step we will filter all incoming Product2 records
        //Only records which have related Account Taxes records will be proceed ...
        List<Product2> products = DomainUtils.getProductsByIdWithAccountTaxes(
            new Map<Id, Product2>(newProducts).keySet(), 1
        );

        Set<Id> validatedProductIds = new Set<Id>();
        for (Product2 eachQueriedProduct : products) {
            if (!eachQueriedProduct.Account_Taxes__r.isEmpty()) {
                validatedProductIds.add(eachQueriedProduct.Id);
            }
        }

        //Then we have to check some fields to prevent them from changing
        for (Product2 eachNewProduct : newProducts) {
            if (validatedProductIds.contains(eachNewProduct.Id)) {
                Product2 oldProduct = oldProductMap.get(eachNewProduct.Id);
                if (oldProduct.Tax_Rate__c != NULL && eachNewProduct.Tax_Rate__c == NULL) {
                    eachNewProduct.Tax_Rate__c.addError(TAX_RATE_BLANK_ERROR);
                }
                if (oldProduct.Accounting_Type__c == 'Tax Rate' && eachNewProduct.Accounting_Type__c != 'Tax Rate') {
                    eachNewProduct.Accounting_Type__c.addError(TAX_TYPE_UPDATE_ERROR);
                }
                if (oldProduct.Revenue_GL_Account__c != NULL && eachNewProduct.Revenue_GL_Account__c == NULL) {
                    eachNewProduct.Revenue_GL_Account__c.addError(REVENUE_GL_ACCOUNT_UPDATE_ERROR);
                }
            }
        }

    }

    public static void preventUpdateTypeProductWithRelatedParts(Map<Id, Product2> newProductsMap, Map<Id, Product2> oldProductMap) {
        Set<Id> productIds = new Set<Id>();
        for (Product2 newProduct : newProductsMap.values()) {
            Product2 oldProduct = oldProductMap.get(newProduct.Id);
            if (oldProduct.Inventory_Type__c != newProduct.Inventory_Type__c) {
                productIds.add(newProduct.Id);
            }
        }

        List<Product_Part__c> selectedProductPart = DomainUtils.getProductPartsByProductId(productIds);

        if (!selectedProductPart.isEmpty()) {
            for (Product_Part__c part : selectedProductPart) {
                newProductsMap.get(part.Product__c).addError(TYPE_UPDATE_ERROR);
            }
        }
    }

}