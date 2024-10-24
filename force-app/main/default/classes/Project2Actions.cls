public with sharing class Project2Actions {

    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final String DELETE_ERROR = Label.ERR_RELATED_DELETE;

    public static final List<String> relatedObjectForDeleteValidation {
        get {
            relatedObjectForDeleteValidation = new List<String> {
                PACKAGE_QUALIFIER + 'Billing_Line__c',
                PACKAGE_QUALIFIER + 'Account_Payable_Line__c',
                PACKAGE_QUALIFIER + 'Journal_Entry_Line__c',
                PACKAGE_QUALIFIER + 'Cash_Receipt__c',
                PACKAGE_QUALIFIER + 'Cash_Disbursement__c',
                PACKAGE_QUALIFIER + 'Transaction__c',
                PACKAGE_QUALIFIER + 'Scheduled_Revenue_Expense__c',
                PACKAGE_QUALIFIER + 'Recurring_Billing_Line__c',
                PACKAGE_QUALIFIER + 'Recurring_Journal_Entry_Line__c',
                PACKAGE_QUALIFIER + 'Recurring_Account_Payable_Line__c'
            };
            return relatedObjectForDeleteValidation;
        }
        private set;
    }

    public static void preventDeleteIfRelatedRecordsExist(Map<Id, Project__c> oldProjectMap) {
        Set<Id> projectIdsHavingRelatedRecs = new Set<Id>();

        for (String objName : relatedObjectForDeleteValidation) {
            Map<Id, AggregateResult> results = new Map<Id, AggregateResult>(
                DomainUtils.getRelatedObjectCountByApiNameAndLookupName(oldProjectMap.keySet(), objName, 'Project__c')
            );
            for (Id resId : results.keySet()) {
                if (results.get(resId).get('itemCount') != 0) {
                    projectIdsHavingRelatedRecs.add(resId);
                }
            }
        }

        if (!projectIdsHavingRelatedRecs.isEmpty()) {
            for (Id oldProjectId : projectIdsHavingRelatedRecs) {
                oldProjectMap.get(oldProjectId).addError(DELETE_ERROR);
            }
        }
    }

}