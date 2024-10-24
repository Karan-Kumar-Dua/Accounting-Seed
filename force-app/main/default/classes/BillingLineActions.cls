public with sharing class BillingLineActions {
       
    @TestVisible
    private static final String BILLING_LINE_REPARENTING_ERROR = Label.ERR_BILLING_LINE_REPARENTING;

    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    public static Boolean isBypassGLAccountValidations = false;
    public static Boolean isLDVSourceBatchInProgress = false;
    public static Boolean isSkipLineUpdateTrigger4LDV = false;

    public static final Map<SObjectField, Integer> currencyAndNumberFields = new Map<SObjectField, Integer> {
        Billing_Line__c.Rate__c => 6,
        Billing_Line__c.Hours_Units__c => 6,
        Billing_Line__c.List_Price__c => 2,
        Billing_Line__c.Product_Unit_Cost__c => 6,
        Billing_Line__c.Tax_Amount2__c => 2
    };

    public static void preventTaxGroup(List<Billing_Line__c> billLines) {
        Set<Id> billingIds = new Set<Id>();
        Set<Id> taxGroupIds = new Set<Id>();
        
        for (Billing_Line__c billLine: billLines) {
            taxGroupIds.add(billLine.Tax_Group__c);
        }
        
        Map<Id, Tax_Group__c> taxGroupsByBillingLineId =
            new Map<Id, Tax_Group__c>(DomainUtils.getTaxGroupWithTaxRatesByIds(taxGroupIds));
        
        for (Billing_Line__c billLine : billLines) {
            if (taxGroupsByBillingLineId.containsKey(billLine.Tax_Group__c)
                    && taxGroupsByBillingLineId.get(billLine.Tax_Group__c).Tax_Inclusive__c ) {

                billingIds.add(billLine.Billing__c);
            }
        }
        
        Map<Id, Billing__c> billingMap = new Map<Id, Billing__c>(DomainUtils.getBillingsById(billingIds));
        
        for (Billing_Line__c billLine : billLines) {
            if (billingMap.containsKey(billLine.Billing__c)
                    && AvaTaxHelper.isAvalaraTaxCalculationEnabled(billingMap.get(billLine.Billing__c))) {

                billLine.Tax_Group__c.addError(Label.ERR_PREVENT_AVATAX_MESSAGE);
            }
        }
    }

    public static void requireRevenueGLAccount(List<Billing_Line__c> billLines) {
        for (Billing_Line__c billLine : billLines) {
            if (billLine.Revenue_GL_Account__c == NULL) {
                billLine.Revenue_GL_Account__c.addError(SObjectActions.REQUIRED_FIELD_ERROR, false);
            }
        }
    }

    public static void setVATReportingFields(List<Billing_Line__c> newLines) {
        Set<Id> taxGroupIds = new Set<Id>();
        Map<Id, Tax_Group__c> taxGroupMap = new Map<Id, Tax_Group__c>();

        for (Billing_Line__c bl : newLines) {
            if (bl.Tax_Group__c != NULL) {
                taxGroupIds.add(bl.Tax_Group__c);
            }
        }
        if (!taxGroupIds.isEmpty()) {
            taxGroupMap = new Map<Id, Tax_Group__c>(DomainUtils.getTaxGroupByIds(taxGroupIds));
        }

        for (Billing_Line__c bl : newLines) {
            if (bl.Tax_Group__c != NULL) {
                bl.Is_VAT_Related__c = taxGroupMap.get(bl.Tax_Group__c).External_Id2__c != NULL ? true : false;                
            }
            else {
                bl.Is_VAT_Related__c = false;
            }
        }
    }

    public static void preventReparentingIfBillingIsPosted(List<Billing_Line__c> newBillingLines, Map<Id, Billing_Line__c> oldBillingLinesMap) {
        for (Billing_Line__c newLine : newBillingLines) {
            Billing_Line__c oldLine = oldBillingLinesMap.get(newLine.Id);
            if (newLine.Billing__c != oldLine.Billing__c
                    && (oldLine.Parent_Status__c == 'Posted' || newLine.Parent_Status__c == 'Posted')) {

                newLine.Billing__c.addError(BILLING_LINE_REPARENTING_ERROR);
            }
        }
    }

    public static void associateDefaultGLAccounts(List<Billing_Line__c> newBillingLines) {
        Set<Id> parentBillingIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();
        Map<Id, Product2> productMap = new Map<Id, Product2>();

        for (Billing_Line__c newBillingLine : newBillingLines) {
            if (newBillingLine.Product__c != NULL) {
                productIds.add(newBillingLine.Product__c);
            }
            parentBillingIds.add(newBillingLine.Billing__c);
        }
        Map<Id, Id> billingsByLedgers = SObjectActions.ledgerIdBySourceId(DomainUtils.getBillingsById(parentBillingIds));
        Map<Id, Map<String, GL_Account_Default__c>> defaults = GLAccount.glAccountDefaultsMapByLedgerId(new Set<Id> (billingsByLedgers.values()));

        for (Product2 prod : DomainUtils.getProductsById(productIds)) {
            productMap.put(prod.Id, prod);
        }

        for (Billing_Line__c newBillingLine : newBillingLines) {
            //associate Default Revenue GL Account
            //from Product
            if (newBillingLine.Revenue_GL_Account__c == NULL
                    && newBillingLine.Product__c != NULL
                    && productMap.containsKey(newBillingLine.Product__c)
                    && productMap.get(newBillingLine.Product__c).Revenue_GL_Account__c != NULL) {

                newBillingLine.Revenue_GL_Account__c = productMap.get(newBillingLine.Product__c).Revenue_GL_Account__c;
            }//or from Defaults
            else if (newBillingLine.Revenue_GL_Account__c == NULL
                    && defaults.containsKey(billingsByLedgers.get(newBillingLine.Billing__c))
                    && defaults.get(billingsByLedgers.get(newBillingLine.Billing__c)).containsKey(GLAccountDefaultsHandler.REVENUE_GL_ACCOUNT)) {

                newBillingLine.Revenue_GL_Account__c =
                    defaults.get(billingsByLedgers.get(newBillingLine.Billing__c)).get(GLAccountDefaultsHandler.REVENUE_GL_ACCOUNT).GL_Account__c;
            }

            //associate Inventory GL Account from Product
            if (newBillingLine.Inventory_GL_Account__c == NULL
                    && newBillingLine.Product__c != NULL
                    && productMap.containsKey(newBillingLine.Product__c)
                    && productMap.get(newBillingLine.Product__c).Inventory_GL_Account__c != NULL) {

                newBillingLine.Inventory_GL_Account__c = productMap.get(newBillingLine.Product__c).Inventory_GL_Account__c;
            }

            //associate Expense GL Account from Product
            if (newBillingLine.Expense_GL_Account__c == NULL
                    && newBillingLine.Product__c != NULL
                    && productMap.containsKey(newBillingLine.Product__c)
                    && productMap.get(newBillingLine.Product__c).Expense_GL_Account__c != NULL) {

                newBillingLine.Expense_GL_Account__c = productMap.get(newBillingLine.Product__c).Expense_GL_Account__c;
            }

            //populate Product's Unit Cost
            if (newBillingLine.Product_Unit_Cost__c == NULL
                    && newBillingLine.Product__c != NULL
                    && productMap.containsKey(newBillingLine.Product__c)
                    && productMap.get(newBillingLine.Product__c).Unit_Cost__c != NULL) {

                newBillingLine.Product_Unit_Cost__c = productMap.get(newBillingLine.Product__c).Unit_Cost__c;
            }
        }
    }

    public static void calculateTaxAmountAndSetTaxGroup(List<Billing_Line__c> billLines, Map<Id, Billing_Line__c> oldBillingLinesMap) {
        Set<Id> parentBillingIds = new Set<Id>();
        for (Billing_Line__c newBillingLine : billLines) {
            parentBillingIds.add(newBillingLine.Billing__c);
            if (newBillingLine.Tax_Group__c == null) {
                newBillingLine.Tax_Inclusive__c = false;
                newBillingLine.Combined_Tax_Rate__c = 0;
            }
        }
        TaxService.parentSObjectById = new Map<Id, Billing__c> (DomainUtils.getBillingsById(parentBillingIds));
        TaxService.calcTaxes(billLines, oldBillingLinesMap);
    }

    public static void validateTax(List<Billing_Line__c> billLines, Map<Id, Billing_Line__c> oldBillingLinesMap) {
        if (TaxService.parentSObjectById == null) {
            Set<Id> parentBillingIds = new Set<Id>();
            for (Billing_Line__c newBillingLine : billLines) {
                parentBillingIds.add(newBillingLine.Billing__c);
            }
            TaxService.parentSObjectById = new Map<Id, Billing__c> (DomainUtils.getBillingsById(parentBillingIds));
        }
        TaxService.validate(billLines, oldBillingLinesMap);
    }

}