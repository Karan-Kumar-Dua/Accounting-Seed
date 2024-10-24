public with sharing class AccountingVariableActions {

    private static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    @TestVisible
    private static final Integer GLAV_TOTAL_LIMIT = FeatureManagementHandler.getCurrentGLAVsLimit();
    @TestVisible
    private static final String GLAV_MAX_LIMIT_REACHED = String.format(Label.ERR_GLAV_MAX_LIMIT_REACHED, 
                                                         new List<Object>{ GLAV_TOTAL_LIMIT });

    public static final String ACCOUNTING_VARIABLE_TYPE_1 = 'GL Account Variable 1';
    public static final String ACCOUNTING_VARIABLE_TYPE_2 = 'GL Account Variable 2';
    public static final String ACCOUNTING_VARIABLE_TYPE_3 = 'GL Account Variable 3';
    public static final String ACCOUNTING_VARIABLE_TYPE_4 = 'GL Account Variable 4';
    public static final String TIME_CARD_VARIABLE_1 = 'Time Card Variable 1';
    public static final String TIME_CARD_VARIABLE_2 = 'Time Card Variable 2';

    public static final String TYPE_CHANGE_ERROR = Label.ERR_ACCOUNTING_VARIABLE_TYPE_CHANGE;
    public static final String DELETE_ERROR = Label.ERR_ACCOUNTING_VARIABLE_DELETE;

    public static final List<String> relatedObjectForDeleteGLAVsValidation {
        get {
            relatedObjectForDeleteGLAVsValidation = new List<String> {
                'Account',
                PACKAGE_QUALIFIER + 'Scheduled_Revenue_Expense__c',
                PACKAGE_QUALIFIER + 'Bank_Deposit__c',
                PACKAGE_QUALIFIER + 'Bank_Reconciliation2__c',
                PACKAGE_QUALIFIER + 'Billing_Line__c',
                PACKAGE_QUALIFIER + 'Cash_Disbursement__c',
                PACKAGE_QUALIFIER + 'Cash_Receipt__c',
                PACKAGE_QUALIFIER + 'Expense_Line__c',
                PACKAGE_QUALIFIER + 'Financial_Cube__c',
                PACKAGE_QUALIFIER + 'Financial_Report_Result__c',
                PACKAGE_QUALIFIER + 'Financial_Report_Row__c',
                PACKAGE_QUALIFIER + 'Journal_Entry_Line__c',
                'OpportunityLineItem',
                'Product2',
                PACKAGE_QUALIFIER + 'Account_Payable_Line__c',
                PACKAGE_QUALIFIER + 'Project_Task__c',
                PACKAGE_QUALIFIER + 'Recurring_Billing_Line__c',
                PACKAGE_QUALIFIER + 'Recurring_Journal_Entry_Line__c',
                PACKAGE_QUALIFIER + 'Recurring_Account_Payable_Line__c',
                PACKAGE_QUALIFIER + 'Transaction__c'
            };
            return relatedObjectForDeleteGLAVsValidation;
        }
        private set;
    }

    public static final List<String> relatedObjectForDeleteTCVsValidation {
        get {
            relatedObjectForDeleteTCVsValidation = new List<String> {
                PACKAGE_QUALIFIER + 'Billing_Line__c',
                PACKAGE_QUALIFIER + 'Journal_Entry_Line__c',
                PACKAGE_QUALIFIER + 'Time_Card_Line__c',
                PACKAGE_QUALIFIER + 'Transaction__c'
            };
            return relatedObjectForDeleteTCVsValidation;
        }
        private set;
    }

    public static void validateTotalLimit(List<Accounting_Variable__c> newVariables) {
        Integer totalNmbOfGlavs = DomainUtils.countActiveGLAVs();
        if (totalNmbOfGlavs > GLAV_TOTAL_LIMIT) {
            for (Accounting_Variable__c glav : newVariables) {
                glav.addError(GLAV_MAX_LIMIT_REACHED);
            }
        }
    }

    public static void preventChangeTypeField(List<Accounting_Variable__c> newVariables, Map<Id, Accounting_Variable__c> oldVariableMap) {

        for (Accounting_Variable__c newVariable : newVariables) {
            Accounting_Variable__c oldVariable = oldVariableMap.get(newVariable.Id);

            if (oldVariable.Type__c != newVariable.Type__c) {
                newVariable.addError(TYPE_CHANGE_ERROR);
            }
        }
    }

    public static void preventDeleteIfRelatedRecordsExist(Map<Id, Accounting_Variable__c> oldVariablesMap) {
        Set<Id> acctVarIdsWithExistedRelatedRecs = new Set<Id>();

        Set<Id> GLAV1Ids = new Set<Id>();
        Set<Id> GLAV2Ids = new Set<Id>();
        Set<Id> GLAV3Ids = new Set<Id>();
        Set<Id> GLAV4Ids = new Set<Id>();
        Set<Id> TCV1Ids = new Set<Id>();
        Set<Id> TCV2Ids = new Set<Id>();

        for (Accounting_Variable__c glav : oldVariablesMap.values()) {
            if (glav.Type__c == ACCOUNTING_VARIABLE_TYPE_1) {
                GLAV1Ids.add(glav.Id);
            } else if (glav.Type__c == ACCOUNTING_VARIABLE_TYPE_2) {
                GLAV2Ids.add(glav.Id);
            } else if (glav.Type__c == ACCOUNTING_VARIABLE_TYPE_3) {
                GLAV3Ids.add(glav.Id);
            } else if (glav.Type__c == ACCOUNTING_VARIABLE_TYPE_4) {
                GLAV4Ids.add(glav.Id);
            }
            else if (glav.Type__c == TIME_CARD_VARIABLE_1) {
                TCV1Ids.add(glav.Id);
            }
            else if (glav.Type__c == TIME_CARD_VARIABLE_2) {
                TCV2Ids.add(glav.Id);
            }
        }

        if (!GLAV1Ids.isEmpty()) {
            acctVarIdsWithExistedRelatedRecs.addAll(
                getAccountingVariableIdsWithRelatedRecords(
                    GLAV1Ids, 'GL_Account_Variable_1__c', relatedObjectForDeleteGLAVsValidation
                )
            );
        }
        if (!GLAV2Ids.isEmpty()) {
            acctVarIdsWithExistedRelatedRecs.addAll(
                getAccountingVariableIdsWithRelatedRecords(
                    GLAV2Ids, 'GL_Account_Variable_2__c', relatedObjectForDeleteGLAVsValidation
                )
            );
        }
        if (!GLAV3Ids.isEmpty()) {
            acctVarIdsWithExistedRelatedRecs.addAll(
                getAccountingVariableIdsWithRelatedRecords(
                    GLAV3Ids, 'GL_Account_Variable_3__c', relatedObjectForDeleteGLAVsValidation
                )
            );
        }
        if (!GLAV4Ids.isEmpty()) {
            acctVarIdsWithExistedRelatedRecs.addAll(
                getAccountingVariableIdsWithRelatedRecords(
                    GLAV4Ids, 'GL_Account_Variable_4__c', relatedObjectForDeleteGLAVsValidation
                )
            );
        }
        if (!TCV1Ids.isEmpty()) {
            acctVarIdsWithExistedRelatedRecs.addAll(
                getAccountingVariableIdsWithRelatedRecords(
                    TCV1Ids, 'Time_Card_Variable_1__c', relatedObjectForDeleteTCVsValidation
                )
            );
        }
        if (!TCV2Ids.isEmpty()) {
            acctVarIdsWithExistedRelatedRecs.addAll(
                getAccountingVariableIdsWithRelatedRecords(
                    TCV2Ids, 'Time_Card_Variable_2__c', relatedObjectForDeleteTCVsValidation
                )
            );
        }

        if (!acctVarIdsWithExistedRelatedRecs.isEmpty()) {
            for (Id oldGlavId : acctVarIdsWithExistedRelatedRecs) {
                oldVariablesMap.get(oldGlavId).addError(DELETE_ERROR);
            }
        }
    }

    private static Set<Id> getAccountingVariableIdsWithRelatedRecords(Set<Id> recIds, String lookupFieldName, List<String> sobjectTypes) {
        Set<Id> acctVarIdsWithExistedRelatedRecs = new Set<Id>();
        for (String objName : sobjectTypes) {
            Map<Id, AggregateResult> results = new Map<Id, AggregateResult>(
                DomainUtils.getRelatedObjectCountByApiNameAndLookupName(recIds, objName, lookupFieldName)
            );
            for (Id resId : results.keySet()) {
                if (results.get(resId).get('itemCount') != 0) {
                    acctVarIdsWithExistedRelatedRecs.add(resId);
                    //if we have found out this Accounting Variable is populated on one of possible related records
                    //no need to validate it for the next SObject Type from the list
                    recIds.remove(resId);
                }
            }
        }
        return acctVarIdsWithExistedRelatedRecs;
    }

}