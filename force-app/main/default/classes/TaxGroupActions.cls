public with sharing class TaxGroupActions {
    
    public static final String TAX_RATE_SALES_TAX_GL_ACCOUNT_MISSING_ERROR =
        Label.ERR_TAX_RATE_SALES_TAX_GL_ACCOUNT_MISSING;
    public static final String TAX_RATE_PURCHASE_TAX_GL_ACCOUNT_MISSING_ERROR =
        Label.ERR_TAX_RATE_PURCHASE_TAX_GL_ACCOUNT_MISSING;
    public static final String TAX_RATE_SALES_AND_PURCHASE_TAX_GL_ACCOUNT_MISSING_ERROR =
        Label.ERR_TAX_RATE_SALES_AND_PURCHASE_TAX_GL_ACCOUNT_MISSING;
    public static final String AVAVAT_TAX_RATE_SALES_AND_PURCHASE_TAX_GL_ACCOUNT_MISSING_ERROR =
        Label.ERR_AVAVAT_TAX_RATE_SALES_AND_PURCHASE_TAX_GL_ACCOUNT_MISSING;        
    public static final String EXISTED_RECORD_ERROR = Label.ERR_EXISTED_RECORD;
    public static final String SALES_TAX_TYPE_CHANGE_ERROR =
        Label.ERR_SALES_TAX_TYPE_CHANGE;
    public static final String PURCHASE_TAX_TYPE_CHANGE_ERROR =
        Label.ERR_PURCHASE_TAX_TYPE_CHANGE;
    public static final String MAX_LINE_ERROR = Label.ERR_MAX_RATE_LINE;
    public static final String EXTERNAL_ID_NOT_ALLOWED_ERROR = Label.ERR_EXTERNAL_ID_NOT_ALLOWED;
    public static final String COMBINED_TAX_RATE_UPDATE_ERROR =
        Label.ERR_COMBINED_TAX_RATE_UPDATE;
    public static final Integer MAX_TAX_RATES_COUNT = 5;
    public static final Integer AVAVAT_MAX_TAX_RATES_COUNT = 2;
    
    public static void validateExternalIDAllowed(List<Tax_Group__c> taxGroups) {
        Boolean isAvaVATReportingEnabled = AccountingSettingsHandler.isAvaVATReportingEnabled();
        for (Tax_Group__c taxGroup : taxGroups) {
            if (!isAvaVATReportingEnabled && taxGroup.External_Id2__c != NULL) {
                taxGroup.External_Id2__c.addError(EXTERNAL_ID_NOT_ALLOWED_ERROR);
            }
        }
    }

    public static void validateTaxRates(Map<Id, Tax_Group__c> newTaxGroupMap) {        
        for (Tax_Rate__c taxRate : DomainUtils.getTaxRatesByTaxGroupIds(newTaxGroupMap.keySet())) {
            if (newTaxGroupMap.get(taxRate.Tax_Group__c).Reverse_Charge__c == true
                    && (taxRate.Purchase_Tax_Expense_GL_Account__c == NULL || taxRate.Sales_Tax_Liability_GL_Account__c == NULL)) {

                newTaxGroupMap.get(taxRate.Tax_Group__c).Reverse_Charge__c.addError(AVAVAT_TAX_RATE_SALES_AND_PURCHASE_TAX_GL_ACCOUNT_MISSING_ERROR);
            }
            else if (newTaxGroupMap.get(taxRate.Tax_Group__c).Tax_Type__c == 'Sales'
                    && taxRate.Sales_Tax_Liability_GL_Account__c == NULL) {

                newTaxGroupMap.get(taxRate.Tax_Group__c).Tax_Type__c.addError(TAX_RATE_SALES_TAX_GL_ACCOUNT_MISSING_ERROR);
            }
            else if (newTaxGroupMap.get(taxRate.Tax_Group__c).Tax_Type__c == 'Purchase'
                    && taxRate.Purchase_Tax_Expense_GL_Account__c == NULL) {

                newTaxGroupMap.get(taxRate.Tax_Group__c).Tax_Type__c.addError(TAX_RATE_PURCHASE_TAX_GL_ACCOUNT_MISSING_ERROR);
            }
            else if (newTaxGroupMap.get(taxRate.Tax_Group__c).Tax_Type__c == 'Sales and Purchase'
                    && (taxRate.Purchase_Tax_Expense_GL_Account__c == NULL || taxRate.Sales_Tax_Liability_GL_Account__c == NULL)) {

                newTaxGroupMap.get(taxRate.Tax_Group__c).Tax_Type__c.addError(TAX_RATE_SALES_AND_PURCHASE_TAX_GL_ACCOUNT_MISSING_ERROR);
            }            
        }
    }

    public static void preventUpdateLineCountAndCombinedTaxRateIfHasAssociated(List<Tax_Group__c> newTaxGroups, Map<Id, Tax_Group__c> oldTaxGroupMap) {
        Boolean isAvaVATReportingEnabled = AccountingSettingsHandler.isAvaVATReportingEnabled();

        Boolean hasAssociated = (
            DomainUtils.countBillingLinesByTaxGroup(oldTaxGroupMap.keySet())
                + DomainUtils.countRecurringBillingLinesByTaxGroup(oldTaxGroupMap.keySet())
                + DomainUtils.countPayableLinesByTaxGroup(oldTaxGroupMap.keySet())
                + DomainUtils.countRecurringPayableLinesByTaxGroup(oldTaxGroupMap.keySet())
                + DomainUtils.countOpportunityLineItemByTaxGroup(oldTaxGroupMap.keySet())
        ) > 0;

        for (Tax_Group__c newTaxGroup : newTaxGroups) {
            Integer selectedLineCount =
                isAvaVATReportingEnabled && newTaxGroup.External_ID2__c != NULL
                    ? AVAVAT_MAX_TAX_RATES_COUNT
                    : MAX_TAX_RATES_COUNT;

            Tax_Group__c oldTaxGroup = oldTaxGroupMap.get(newTaxGroup.Id);
            if (hasAssociated && (isTaxRateCountChanged(newTaxGroup, oldTaxGroup) || isCombinedTaxRateChanged(newTaxGroup, oldTaxGroup))) {
                newTaxGroup.addError(COMBINED_TAX_RATE_UPDATE_ERROR);
            }
            else if (newTaxGroup.Tax_Rate_Count__c > selectedLineCount) {
                newTaxGroup.addError(String.format(MAX_LINE_ERROR, new List<String>{String.valueOf(selectedLineCount)}), false);
            }
            if (hasAssociated && isTaxInclusiveChanged(newTaxGroup, oldTaxGroup)) {
                newTaxGroup.addError(Label.ERR_TAX_GROUP_UPDATE_TAX_INCLUSIVE);
            }
        }
    }

    private static Boolean isTaxRateCountChanged(Tax_Group__c newTaxGroup, Tax_Group__c oldTaxGroup) {
        return newTaxGroup.Tax_Rate_Count__c != oldTaxGroup.Tax_Rate_Count__c;
    }

    private static Boolean isCombinedTaxRateChanged(Tax_Group__c newTaxGroup, Tax_Group__c oldTaxGroup) {
        return newTaxGroup.Combined_Tax_Rate__c != oldTaxGroup.Combined_Tax_Rate__c;
    }

    private static Boolean isTaxInclusiveChanged(Tax_Group__c newTaxGroup, Tax_Group__c oldTaxGroup) {
        return newTaxGroup.Tax_Inclusive__c != oldTaxGroup.Tax_Inclusive__c;
    }

    public static void preventTaxGroupDelete(Map<Id, Tax_Group__c> oldTaxGroupMap) {
        Integer countOfBillingLines = DomainUtils.countBillingLinesByTaxGroup(oldTaxGroupMap.keySet());
        Integer countOfRecBillingLines = DomainUtils.countRecurringBillingLinesByTaxGroup(oldTaxGroupMap.keySet());
        Integer countOfPayableLines = DomainUtils.countPayableLinesByTaxGroup(oldTaxGroupMap.keySet());
        Integer countOfRecPayableLines = DomainUtils.countRecurringPayableLinesByTaxGroup(oldTaxGroupMap.keySet());
        Integer countOfOpportunityLineItem = DomainUtils.countOpportunityLineItemByTaxGroup(oldTaxGroupMap.keySet());
        if ((countOfBillingLines + countOfRecBillingLines + countOfPayableLines + countOfRecPayableLines + countOfOpportunityLineItem) > 0) {
            for (Tax_Group__c tg : oldTaxGroupMap.values()) {
                tg.addError(EXISTED_RECORD_ERROR);
            }
        }
    }

    public static void validateTaxType(List<Tax_Group__c> newTaxGroups, Map<Id, Tax_Group__c> oldTaxGroupMap) {
        Set<Id> fromSalesToPurchase = new Set<Id>();
        Set<Id> fromPurchaseToSales = new Set<Id>();
        //Counter for Billing Lines & Recurring Billing Lines
        Integer countOfSalesLines = 0;
        //Counter for Payable Lines & Recurring Payable Lines
        Integer countOfPurchaseLines = 0;

        for (Tax_Group__c newTaxGroup : newTaxGroups) {
            Tax_Group__c oldTaxGroup = oldTaxGroupMap.get(newTaxGroup.Id);
            if (newTaxGroup.Tax_Type__c == 'Purchase'
                    && (oldTaxGroup.Tax_Type__c == 'Sales' || oldTaxGroup.Tax_Type__c == 'Sales and Purchase')) {

                fromSalesToPurchase.add(newTaxGroup.Id);
            }
            else if (newTaxGroup.Tax_Type__c == 'Sales'
                        && (oldTaxGroup.Tax_Type__c == 'Purchase' || oldTaxGroup.Tax_Type__c == 'Sales and Purchase')) {

                fromPurchaseToSales.add(newTaxGroup.Id);
            }
        }

        if (!fromSalesToPurchase.isEmpty()) {
            Integer billLineCount = DomainUtils.countBillingLinesByTaxGroup(fromSalesToPurchase);
            Integer recBillLineCount = DomainUtils.countRecurringBillingLinesByTaxGroup(fromSalesToPurchase);
            Integer countOfOpportunityLineItem = DomainUtils.countOpportunityLineItemByTaxGroup(fromSalesToPurchase);
            countOfSalesLines = billLineCount + recBillLineCount + countOfOpportunityLineItem;
        }
        if (!fromPurchaseToSales.isEmpty()) {
            Integer payableLineCount = DomainUtils.countPayableLinesByTaxGroup(fromPurchaseToSales);
            Integer recPayableLineCount = DomainUtils.countRecurringPayableLinesByTaxGroup(fromPurchaseToSales);
            countOfPurchaseLines = payableLineCount + recPayableLineCount;
        }

        for (Tax_Group__c newTaxGroup : newTaxGroups) {
            if (fromSalesToPurchase.contains(newTaxGroup.Id) && countOfSalesLines > 0) {
                newTaxGroup.Tax_Type__c.addError(SALES_TAX_TYPE_CHANGE_ERROR);
            }
            if (fromPurchaseToSales.contains(newTaxGroup.Id) && countOfPurchaseLines > 0) {
                newTaxGroup.Tax_Type__c.addError(PURCHASE_TAX_TYPE_CHANGE_ERROR);
            }
        }
    }

}