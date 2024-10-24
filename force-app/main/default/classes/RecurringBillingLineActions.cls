public with sharing class RecurringBillingLineActions {

    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final Map<SObjectField, Integer> currencyAndNumberFields = new Map<SObjectField, Integer> {
        Recurring_Billing_Line__c.Rate__c => 6,
        Recurring_Billing_Line__c.Quantity__c => 6,
        Recurring_Billing_Line__c.Tax_Amount__c => 2
    };
    public static Boolean bypassGLAccountValidation = false;

    public static void setDefaultRevenueGLAccount(List<Recurring_Billing_Line__c> recurringBillingLines) {
        Accounting_Settings__c main = AccountingSettingsHandler.getAccountingSettings();
        Set<Id> parentRecBillingIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();
        Map<Id, Product2> productMap = new Map<Id, Product2>();

        for (Recurring_Billing_Line__c newRecurringBillingLine : recurringBillingLines) {
            if (newRecurringBillingLine.Product__c != NULL) {
                productIds.add(newRecurringBillingLine.Product__c);
            }
            parentRecBillingIds.add(newRecurringBillingLine.Recurring_Billing__c);
        }
        Map<Id, Id> recBillByLedgers = SObjectActions.ledgerIdBySourceId(DomainUtils.getRecurringBillingById(parentRecBillingIds));
        Map<Id, Map<String, GL_Account_Default__c>> defaults = GLAccount.glAccountDefaultsMapByLedgerId(new Set<Id> (recBillByLedgers.values()));

        for (Product2 prod : DomainUtils.getProductsById(productIds)) {
            productMap.put(prod.Id, prod);
        }

        for (Recurring_Billing_Line__c newRecurringBillingLine : recurringBillingLines) {
            //associate Default Revenue GL Account
            //from Product
            if (newRecurringBillingLine.Revenue_GL_Account__c == NULL
                    && newRecurringBillingLine.Product__c != NULL
                    && productMap.containsKey(newRecurringBillingLine.Product__c)
                    && productMap.get(newRecurringBillingLine.Product__c).Revenue_GL_Account__c != NULL) {
                newRecurringBillingLine.Revenue_GL_Account__c = productMap.get(newRecurringBillingLine.Product__c).Revenue_GL_Account__c;
            }//or from Defaults
            else if (newRecurringBillingLine.Revenue_GL_Account__c == NULL
                    && defaults.containsKey(recBillByLedgers.get(newRecurringBillingLine.Recurring_Billing__c))
                    && defaults.get(recBillByLedgers.get(newRecurringBillingLine.Recurring_Billing__c)).containsKey(GLAccountDefaultsHandler.REVENUE_GL_ACCOUNT)) {

                newRecurringBillingLine.Revenue_GL_Account__c =
                    defaults.get(recBillByLedgers.get(newRecurringBillingLine.Recurring_Billing__c)).get(GLAccountDefaultsHandler.REVENUE_GL_ACCOUNT).GL_Account__c;
            }
        }
    }

    public static void requireRevenueGLAccount(List<Recurring_Billing_Line__c> recurringBillingLines) {
        for (Recurring_Billing_Line__c recurringBillingLine : recurringBillingLines) {
            if (recurringBillingLine.Revenue_GL_Account__c == NULL) {
                recurringBillingLine.Revenue_GL_Account__c.addError(SObjectActions.REQUIRED_FIELD_ERROR, false);
            }
        }
    }

    public static void calculateTaxAmountAndSetTaxGroup(List<Recurring_Billing_Line__c> recurringBillingLines, Map<Id, Recurring_Billing_Line__c> oldRBillingLinesMap) {
        Set<Id> parentRBillingIds = new Set<Id>();
        for (Recurring_Billing_Line__c newRBillingLine : recurringBillingLines) {
            parentRBillingIds.add(newRBillingLine.Recurring_Billing__c);
            if (newRBillingLine.Tax_Group__c == null) {
                newRBillingLine.Tax_Inclusive__c = false;
                newRBillingLine.Combined_Tax_Rate__c = 0;
            }
        }
        TaxService.parentSObjectById = new Map<Id, Recurring_Billing__c> (DomainUtils.getRecurringBillingById(parentRBillingIds));
        TaxService.calcTaxes(recurringBillingLines, oldRBillingLinesMap);
    }

    public static void validateTax(List<Recurring_Billing_Line__c> recurringBillingLines, Map<Id, Recurring_Billing_Line__c> oldRBillingLinesMap) {
        if (TaxService.parentSObjectById == null) {
            Set<Id> parentRBillingIds = new Set<Id>();
            for (Recurring_Billing_Line__c newRBillingLine : recurringBillingLines) {
                parentRBillingIds.add(newRBillingLine.Recurring_Billing__c);
            }
            TaxService.parentSObjectById = new Map<Id, Recurring_Billing__c> (DomainUtils.getRecurringBillingById(parentRBillingIds));
        }
        TaxService.validate(recurringBillingLines, oldRBillingLinesMap);
    }

    public static void preventTaxGroup(List<Recurring_Billing_Line__c> recurringBillingLines) {
        Set<Id> billingIds = new Set<Id>();
        Set<Id> taxGroupIds = new Set<Id>();

        for (Recurring_Billing_Line__c billLine: recurringBillingLines) {
            taxGroupIds.add(billLine.Tax_Group__c);
        }

        Map<Id, Tax_Group__c> taxGroupsByBillingLineId = new Map<Id, Tax_Group__c>(DomainUtils.getTaxGroupWithTaxRatesByIds(taxGroupIds));

        for (Recurring_Billing_Line__c recBillLine : recurringBillingLines) {

            if(taxGroupsByBillingLineId.containsKey(recBillLine.Tax_Group__c) && taxGroupsByBillingLineId.get(recBillLine.Tax_Group__c).Tax_Inclusive__c ){
                billingIds.add(recBillLine.Recurring_Billing__c);
            }
        }

        Map<Id, Recurring_Billing__c> recBillingMap = new Map<Id, Recurring_Billing__c>(DomainUtils.getRecurringBillingById(billingIds));

        for (Recurring_Billing_Line__c recBillLine : recurringBillingLines) {
            if(recBillingMap.containsKey(recBillLine.Recurring_Billing__c) && AvaTaxHelper.isAvalaraTaxCalculationEnabled(recBillingMap.get(recBillLine.Recurring_Billing__c))){
                recBillLine.Tax_Group__c.addError(Label.ERR_PREVENT_AVATAX_MESSAGE);
            }
        }
    }

}