public with sharing class UnclearedBankReconciliationLineActions {
    @TestVisible
    private static final String INSERT_ERROR = Label.ERR_INSERT_RECONCILIATION;
    @TestVisible
    private static final String DELETE_ERROR = Label.ERR_DELETE_RECONCILIATION;
    @TestVisible
    private static final String ONE_SOURCE_DOCUMENT_ERROR =
        Label.ERR_ONE_SOURCE_DOCUMENT;
    @TestVisible
    private static List<SObjectField> exclusivelyPopulatedFields = new List<SObjectField>{
        Uncleared_Bank_Reconciliation_Line__c.Cash_Receipt__c,
        Uncleared_Bank_Reconciliation_Line__c.Cash_Disbursement__c,
        Uncleared_Bank_Reconciliation_Line__c.Journal_Entry_Line__c,
        Uncleared_Bank_Reconciliation_Line__c.Bank_Deposit__c,
        Uncleared_Bank_Reconciliation_Line__c.Bank_Disbursement__c
    };

    public static Boolean isPreventInsertOverride = false;
    public static Boolean isPreventDeleteOverride = false;

    public static void preventInsert(List<Uncleared_Bank_Reconciliation_Line__c> unclearedBRECLines) {
        if (!isPreventInsertOverride) {
            for (Uncleared_Bank_Reconciliation_Line__c brecLine : unclearedBRECLines) {
                brecLine.addError(INSERT_ERROR);
            }
        }
    }

    public static void preventDelete(List<Uncleared_Bank_Reconciliation_Line__c> unclearedBRECLines) {
        if (!isPreventDeleteOverride && !AccountingPeriodActions.isDelarcInProgress) {
            for (Uncleared_Bank_Reconciliation_Line__c brecLine : unclearedBRECLines) {
                brecLine.addError(DELETE_ERROR);
            }
        }
    }

    public static void thereCanBeOnlyOne(List<Uncleared_Bank_Reconciliation_Line__c> unclearedBRECLines) {
        for (Uncleared_Bank_Reconciliation_Line__c brecLine : unclearedBRECLines) {
            Set<Object> populatedValues = new Set<Object>();
            for (SObjectField exclusivelyPopulatedField : exclusivelyPopulatedFields) {
                if (brecLine.get(exclusivelyPopulatedField) != NULL) {
                    populatedValues.add(brecLine.get(exclusivelyPopulatedField));
                }
            }
            if (populatedValues.size() != 1) {
                brecLine.addError(ONE_SOURCE_DOCUMENT_ERROR);
            }
        }
    }

}