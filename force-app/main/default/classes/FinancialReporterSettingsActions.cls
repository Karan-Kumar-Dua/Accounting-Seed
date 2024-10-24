public with sharing class FinancialReporterSettingsActions {
   
    public static final String FRS_UPDATE_DML_RESTRICTION_ERROR = Label.ERR_FRS_UPDATE_DML_RESTRICTION;
    public static final String FRS_INSERT_DML_RESTRICTION_ERROR = Label.ERR_FRS_INSERT_DML_RESTRICTION;

    public static Boolean isDmlRestrictionBypassEnabled = false;


    public static void preventInsert(List<Financial_Reporter_Settings__c> frsList) {
        for (Financial_Reporter_Settings__c frs : frsList) {
            if (!isDmlRestrictionBypassEnabled) {
                frs.addError(FRS_INSERT_DML_RESTRICTION_ERROR);
            }
        }
    }

    public static void preventUpdate(List<Financial_Reporter_Settings__c> frsList) {
        for (Financial_Reporter_Settings__c frs : frsList) {
            if (!isDmlRestrictionBypassEnabled) {
                frs.addError(FRS_UPDATE_DML_RESTRICTION_ERROR);
            }
        }
    }

}