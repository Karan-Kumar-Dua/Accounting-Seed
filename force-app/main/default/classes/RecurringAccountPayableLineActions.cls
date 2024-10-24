public with sharing class RecurringAccountPayableLineActions {

    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final Map<SObjectField, Integer> currencyAndNumberFields = new Map<SObjectField, Integer> {
        Recurring_Account_Payable_Line__c.Amount2__c => 2,
        Recurring_Account_Payable_Line__c.Tax_Amount__c => 2,
        Recurring_Account_Payable_Line__c.Quantity__c => 6,
        Recurring_Account_Payable_Line__c.Unit_Cost__c => 6
    };
    public static Boolean bypassGLAccountValidation = false;

    public static void associateDefaultExpenseGLAccount(List<Recurring_Account_Payable_Line__c> newLines) {
        Set<Id> recurringPayableIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();
        Map<Id, Product2> productMap = new Map<Id, Product2>();

        for (Recurring_Account_Payable_Line__c recurringPayableLine : newLines) {
            if (recurringPayableLine.Recurring_Account_Payable__c != NULL) {
                recurringPayableIds.add(recurringPayableLine.Recurring_Account_Payable__c);

                if (recurringPayableLine.Product__c != NULL) {
                    productIds.add(recurringPayableLine.Product__c);
                }
            }
        }

        Map<Id, Recurring_Account_Payable__c> recurringPayablesByIds = new Map<Id, Recurring_Account_Payable__c>(DomainUtils.getRecurringAccountPayablesById(recurringPayableIds));

        if (!productIds.isEmpty()) {
            productMap = new Map<Id, Product2>(DomainUtils.getProductsById(productIds));
        }

        Map<Id, Id> paysByLedgers = SObjectActions.ledgerIdBySourceId(recurringPayablesByIds.values());
        Map<Id, Map<String, GL_Account_Default__c>> defaults = GLAccount.glAccountDefaultsMapByLedgerId(new Set<Id> (paysByLedgers.values()));

        for (Recurring_Account_Payable_Line__c recurringPayableLine : newLines) {
            if (recurringPayableIds.contains(recurringPayableLine.Recurring_Account_Payable__c)) {
                if (isInventoryCostLine(recurringPayablesByIds.get(recurringPayableLine.Recurring_Account_Payable__c), recurringPayableLine, productMap.get(recurringPayableLine.Product__c))
                    && defaults.containsKey(paysByLedgers.get(recurringPayableLine.Recurring_Account_Payable__c))
                    && defaults.get(paysByLedgers.get(recurringPayableLine.Recurring_Account_Payable__c)).containsKey(GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT)) {
                    recurringPayableLine.Expense_GL_Account__c =
                        defaults.get(paysByLedgers.get(recurringPayableLine.Recurring_Account_Payable__c)).get(GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT).GL_Account__c;
                }
                else if (recurringPayableLine.Expense_GL_Account__c == NULL && recurringPayableLine.Product__c != NULL && productMap.containsKey(recurringPayableLine.Product__c) && productMap.get(recurringPayableLine.Product__c).Expense_GL_Account__c != NULL) {
                    recurringPayableLine.Expense_GL_Account__c = productMap.get(recurringPayableLine.Product__c).Expense_GL_Account__c;
                }
                else if (recurringPayableLine.Expense_GL_Account__c == NULL && recurringPayablesByIds.get(recurringPayableLine.Recurring_Account_Payable__c).Vendor__r.Default_Expense_GL_Account__c != NULL) {
                    recurringPayableLine.Expense_GL_Account__c = recurringPayablesByIds.get(recurringPayableLine.Recurring_Account_Payable__c).Vendor__r.Default_Expense_GL_Account__c;
                }
            }
        }
    }

    private static Boolean isInventoryCostLine(Recurring_Account_Payable__c recurringAccountPayable, Recurring_Account_Payable_Line__c recurringAccountPayableLine, Product2 product) {
        return recurringAccountPayable != NULL && recurringAccountPayableLine != NULL && product != NULL
                && AccountingSettingsHandler.isProductCostingEnabled()
                && recurringAccountPayableLine.Product__c != NULL
                && product.Inventory_Product__c
                && (product.Inventory_Type__c == 'Purchased'
                || product.Inventory_Type__c == 'Raw Material');
    }

    public static void requireFields(List<Recurring_Account_Payable_Line__c> newLines) {
        for (Recurring_Account_Payable_Line__c rapl : newLines) {
            if (rapl.Expense_GL_Account__c == NULL) {
                rapl.Expense_GL_Account__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
            if (rapl.Unit_Cost__c == NULL && rapl.Amount2__c == NULL) {
                rapl.Unit_Cost__c .addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
        }
    }

    public static void calculateTaxAmountAndSetTaxGroup(List<Recurring_Account_Payable_Line__c> payableRLine, Map<Id, Recurring_Account_Payable_Line__c> oldRPayableLine) {
        Set<Id> parentRPayableIds = new Set<Id>();
        for (Recurring_Account_Payable_Line__c newRPayableLine : payableRLine) {
            parentRPayableIds.add(newRPayableLine.Recurring_Account_Payable__c);
            if (newRPayableLine.Tax_Group__c == null) {
                newRPayableLine.Tax_Inclusive__c = false;
                newRPayableLine.Combined_Tax_Rate__c = 0;
            }
        }
        TaxService.parentSObjectById = new Map<Id, Recurring_Account_Payable__c> (DomainUtils.getRecurringAccountPayablesById(parentRPayableIds));
        TaxService.calcTaxes(payableRLine, oldRPayableLine);
    }

    public static void validateTax(List<Recurring_Account_Payable_Line__c> payableRLine, Map<Id, Recurring_Account_Payable_Line__c> oldRPayableLine) {
        if (TaxService.parentSObjectById == null) {
            Set<Id> parentRPayableIds = new Set<Id>();
            for (Recurring_Account_Payable_Line__c newRPayableLine : payableRLine) {
                parentRPayableIds.add(newRPayableLine.Recurring_Account_Payable__c);
            }
            TaxService.parentSObjectById = new Map<Id, Recurring_Account_Payable__c> (DomainUtils.getRecurringAccountPayablesById(parentRPayableIds));
        }
        TaxService.validate(payableRLine, oldRPayableLine);
    }
}