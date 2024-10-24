public with sharing class AccountPayableLineActions {

    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    
    public static Boolean isBypassGLAccountValidations = false;

    public static final Map<SObjectField, Integer> currencyAndNumberFields = new Map<SObjectField, Integer> {
        Account_Payable_Line__c.Amount__c => 2,
        Account_Payable_Line__c.Tax_Amount__c => 2,
        Account_Payable_Line__c.Quantity__c => 6,
        Account_Payable_Line__c.Unit_Cost__c => 6
    };
    
    public static void setVATReportingFields(List<Account_Payable_Line__c> newLines) {
        Set<Id> taxGroupIds = new Set<Id>();
        Map<Id, Tax_Group__c> taxGroupMap = new Map<Id, Tax_Group__c>();

        for (Account_Payable_Line__c apl : newLines) {
            if (apl.Tax_Group__c != NULL) {
                taxGroupIds.add(apl.Tax_Group__c);
            }
        }
        if (!taxGroupIds.isEmpty()) {
            taxGroupMap = new Map<Id, Tax_Group__c>(DomainUtils.getTaxGroupByIds(taxGroupIds));
        }

        for (Account_Payable_Line__c apl : newLines) {
            if (apl.Tax_Group__c != NULL) {
                apl.Is_VAT_Related__c = taxGroupMap.get(apl.Tax_Group__c).External_Id2__c != NULL ? true : false;
                apl.Reverse_Charge__c = taxGroupMap.get(apl.Tax_Group__c).Reverse_Charge__c;
            }
            else {
                apl.Is_VAT_Related__c = false;
                apl.Reverse_Charge__c = false;
            }
        }
    }

    public static void associateDefaultExpenseGLAccount(List<Account_Payable_Line__c> newLines) {
        Set<Id> acctPayableIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();
        Map<Id, Product2> productMap = new Map<Id, Product2>();

        for (Account_Payable_Line__c apl : newLines) {
            if (apl.Account_Payable__c != NULL) {
                acctPayableIds.add(apl.Account_Payable__c);
            }

            if (apl.Product__c != NULL) {
                productIds.add(apl.Product__c);
            }
        }

        Map<Id, Account_Payable__c> acctPayableMap = new Map<Id, Account_Payable__c>(DomainUtils.getAccountPayablesById(acctPayableIds));

        if (!productIds.isEmpty()) {
            productMap = new Map<Id, Product2>(DomainUtils.getProductsById(productIds));
        }

        Map<Id, Id> paysByLedgers = SObjectActions.ledgerIdBySourceId(acctPayableMap.values());
        Map<Id, Map<String, GL_Account_Default__c>> defaults = GLAccount.glAccountDefaultsMapByLedgerId(new Set<Id> (paysByLedgers.values()));

        for (Account_Payable_Line__c apl : newLines) {
            if (acctPayableIds.contains(apl.Account_Payable__c)) {//line has master-detail field populated
                if (isInventoryCostLine(acctPayableMap.get(apl.Account_Payable__c), apl, productMap.get(apl.Product__c))
                    && defaults.containsKey(paysByLedgers.get(apl.Account_Payable__c))
                    && defaults.get(paysByLedgers.get(apl.Account_Payable__c)).containsKey(GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT)) {
                    apl.Expense_GL_Account__c =
                        defaults.get(paysByLedgers.get(apl.Account_Payable__c)).get(GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT).GL_Account__c;
                }
                else if (apl.Expense_GL_Account__c == NULL && apl.Product__c != NULL && productMap.containsKey(apl.Product__c)) {
                    apl.Expense_GL_Account__c = productMap.get(apl.Product__c).Expense_GL_Account__c;
                }
                //if Expense GL Account has not been taken from either Accounting Settings or Product
                //get it from Vendor if possible
                if (apl.Expense_GL_Account__c == NULL
                        && acctPayableMap.get(apl.Account_Payable__c).Vendor__r.Default_Expense_GL_Account__c != NULL) {

                    apl.Expense_GL_Account__c = acctPayableMap.get(apl.Account_Payable__c).Vendor__r.Default_Expense_GL_Account__c;
                }
            }
        }
    }

    private static Boolean isInventoryCostLine(Account_Payable__c payable, Account_Payable_Line__c payableLine, Product2 product) {
        return payable != NULL && payableLine != NULL && product != NULL
            && AccountingSettingsHandler.isProductCostingEnabled()
            && payableLine.Product__c != NULL
            && product.Inventory_Product__c
            && (product.Inventory_Type__c == 'Purchased'
                    || product.Inventory_Type__c == 'Raw Material');
    }

    public static void requireFields(List<Account_Payable_Line__c> newLines) {
        for (Account_Payable_Line__c apl : newLines) {
            if (apl.Expense_GL_Account__c == NULL) {
                apl.Expense_GL_Account__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
            if (apl.Unit_Cost__c == NULL && apl.Amount__c == NULL) {
                apl.Unit_Cost__c .addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
        }
    }

    public static void calculateTaxAmountAndSetTaxGroup(List<Account_Payable_Line__c> payableLine, Map<Id, Account_Payable_Line__c> oldPayableLine) {
        Set<Id> parentPayableIds = new Set<Id>();
        for (Account_Payable_Line__c newPayableLine : payableLine) {
            parentPayableIds.add(newPayableLine.Account_Payable__c);
            if (newPayableLine.Tax_Group__c == null) {
                newPayableLine.Tax_Inclusive__c = false;
                newPayableLine.Combined_Tax_Rate__c = 0;
            }
        }
        TaxService.parentSObjectById = new Map<Id, Account_Payable__c> (DomainUtils.getAccountPayablesById(parentPayableIds));
        TaxService.calcTaxes(payableLine, oldPayableLine);
    }

    public static void validateTax(List<Account_Payable_Line__c> payableLine, Map<Id, Account_Payable_Line__c> oldPayableLine) {
        if (TaxService.parentSObjectById == null) {
            Set<Id> parentPayableIds = new Set<Id>();
            for (Account_Payable_Line__c newPayableLine : payableLine) {
                parentPayableIds.add(newPayableLine.Account_Payable__c);
            }
            TaxService.parentSObjectById = new Map<Id, Account_Payable__c> (DomainUtils.getAccountPayablesById(parentPayableIds));
        }
        TaxService.validate(payableLine, oldPayableLine);
    }
}