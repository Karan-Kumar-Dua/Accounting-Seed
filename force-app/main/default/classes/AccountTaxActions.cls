public with sharing class AccountTaxActions {

    public static final String FIELDS_VALIDATION_ERROR = System.Label.ERR_NEW_TAX_FIELD_VALIDATION;
    public static Boolean skipValidation = false;

    public static void validateTaxRateProduct(List<Account_Tax__c> newAcctTaxes, Map<Id, Account_Tax__c> oldAcctTaxesMap) {

        List<Account_Tax__c> acctTaxesNeedValidateList = new List<Account_Tax__c>();
        List<Account_Tax__c> acctTaxWithoutProduct = new List<Account_Tax__c>();
        List<Account_Tax__c> acctTaxWithProduct = new List<Account_Tax__c>();
        List<Account_Tax__c> nonValidAcctTaxes = new List<Account_Tax__c>();
        Map<Id, List<Account_Tax__c>> productIdToAccountTaxes = new Map<Id, List<Account_Tax__c>>();
        Set<Id> productIds = new Set<Id>();

        if (oldAcctTaxesMap == NULL) {//means on insert
            acctTaxesNeedValidateList.addAll(newAcctTaxes);
        }
        else {//means on update
            for (Account_Tax__c newAcctTax : newAcctTaxes) {
                if (newAcctTax.Tax_Rate__c != oldAcctTaxesMap.get(newAcctTax.Id).Tax_Rate__c
                        || newAcctTax.Tax_Type__c != oldAcctTaxesMap.get(newAcctTax.Id).Tax_Type__c) {

                    acctTaxesNeedValidateList.add(newAcctTax);
                }
            }
        }

        for (Account_Tax__c newAcctTax : acctTaxesNeedValidateList) {
            if (newAcctTax.Tax_Rate__c == NULL) {
                acctTaxWithoutProduct.add(newAcctTax);
            }
            else {
                productIds.add(newAcctTax.Tax_Rate__c);
                acctTaxWithProduct.add(newAcctTax);
            }
        }

        if (!acctTaxWithoutProduct.isEmpty()) {
            for (Account_Tax__c newAcctTax : acctTaxWithoutProduct) {
                newAcctTax.Tax_Rate__c.addError(FIELDS_VALIDATION_ERROR, false);
            }
        }

        if (!acctTaxWithProduct.isEmpty()) {
            Map<Id, Product2> relatedProductsMap = new Map<Id, Product2>(
                DomainUtils.getProductsById(productIds)
            );

            for (Account_Tax__c newAcctTax : acctTaxWithProduct) {
                
                Product2 preselectedProduct = relatedProductsMap.get(newAcctTax.Tax_Rate__c);
                
                if (preselectedProduct == NULL || preselectedProduct.Tax_Rate__c == NULL
                        || preselectedProduct.Accounting_Type__c == NULL
                        || !preselectedProduct.Accounting_Type__c.equalsIgnoreCase('Tax Rate')
                        || (newAcctTax.Tax_Type__c == 'Sales' && preselectedProduct.Revenue_GL_Account__c == NULL)
                        || (newAcctTax.Tax_Type__c == 'Purchase' && preselectedProduct.Expense_GL_Account__c == NULL)
                        || (newAcctTax.Tax_Type__c == 'Sales & Purchase' 
                                && (preselectedProduct.Expense_GL_Account__c == NULL 
                                    || preselectedProduct.Revenue_GL_Account__c == NULL))) {
                
                    newAcctTax.Tax_Rate__c.addError(FIELDS_VALIDATION_ERROR, false);
                }
            }
        }

    }
    
}