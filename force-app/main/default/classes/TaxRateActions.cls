public with sharing class TaxRateActions {

    public static Boolean isPreventUpdateOverride = false;

    public static void validateGLAccountChanges(List<Tax_Rate__c> newTaxRates, Map<Id, Tax_Rate__c> oldTaxRates) {
        Set<Tax_Group__c> taxGroupsToUpdate = new Set<Tax_Group__c>();
        for (Tax_Rate__c newTaxRate : newTaxRates) {
            Tax_Rate__c oldTaxRate = oldTaxRates.get(newTaxRate.Id);
            //when some of GL Account lookups has been cleared
            if ((oldTaxRate.Sales_Tax_Liability_GL_Account__c != NULL && newTaxRate.Sales_Tax_Liability_GL_Account__c == NULL)
                    || (oldTaxRate.Purchase_Tax_Expense_GL_Account__c != NULL && newTaxRate.Purchase_Tax_Expense_GL_Account__c == NULL)) {

                taxGroupsToUpdate.add(new Tax_Group__c(Id = newTaxRate.Tax_Group__c));
            }
        }
        if (!taxGroupsToUpdate.isEmpty()) {
            //initiate update of Tax Group master record(s) to execute
            //Tax Type & populated GL Account(s) validation
            //on trigger-level for Tax Group object
            try {
                SFDCSecurityUtils.updateProxy(new List<Tax_Group__c>(taxGroupsToUpdate));
            }
            catch (DmlException ex) {
                for (Tax_Rate__c newTaxRate : newTaxRates) {
                    newTaxRate.addError(ex.getDmlMessage(0));
                }
            }
        }
    }

}