public with sharing class TaxSettingsActions {
    public static final String AVA_TAX_METHOD = 'AvaTax';
    public static final String NATIVE_TAX_METHOD = 'Accounting Seed Native Tax';
    public static Boolean isPreventUpdateOverride = false;

    public static void requireFields(List<Tax_Settings__c> taxSettings) {
        if (!isPreventUpdateOverride) {
            Boolean isLLP = AccountingSettingsHandler.isLineLevelPost();
            for (Tax_Settings__c taxSetting : taxSettings) {
                Boolean isAvaTaxMethod = taxSetting.Tax_Settings_Method__c == AVA_TAX_METHOD;
                if (isAvaTaxMethod && String.isBlank(taxSetting.Sales_Tax_Calculation_Mode__c)) {
                    taxSetting.Sales_Tax_Calculation_Mode__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
                }
                if (isAvaTaxMethod && String.isBlank(taxSetting.Origin_Address__c)) {
                    taxSetting.Origin_Address__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
                }
                if (isAvaTaxMethod && String.isBlank(taxSetting.Sales_Tax_GL_Account__c)) {
                    taxSetting.Sales_Tax_GL_Account__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
                }
                if (isLLP && isAvaTaxMethod && String.isBlank(taxSetting.Sales_Tax_Product__c)) {
                    taxSetting.Sales_Tax_Product__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
                }
                if (isAvaTaxMethod && String.isBlank(taxSetting.AvaTax_License__c)) {
                    taxSetting.AvaTax_License__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
                }
            }
        }
    }
}