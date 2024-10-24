public with sharing class ProjectTaskActions {

    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final String DELETE_ERROR = Label.ERR_RELATED_DELETE;
    @TestVisible
    private static final String PROJECT_TASK_LABOR_GL_ACCOUNT_ERROR = Label.ERR_PROJECT_TASK_LABOR_GL_ACCOUNT;

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


    public static void associateDefaultLaborGLAccount(Project_Task__c[] projectTasks) {
        Accounting_Settings__c main;

        main = AccountingSettingsHandler.getAccountingSettings();

        for (Project_Task__c projectTask : projectTasks) {
            if ((main == NULL || main.Default_Project_Task_Labor_GL_Account__c == NULL)
                    && projectTask.Labor_GL_Account__c == NULL) {

                projectTask.Labor_GL_Account__c.addError(PROJECT_TASK_LABOR_GL_ACCOUNT_ERROR, false);
            }
            else if (projectTask.Labor_GL_Account__c == NULL) {
                projectTask.Labor_GL_Account__c = main.Default_Project_Task_Labor_GL_Account__c;
            }
        }
    }

    public static void preventDeleteIfRelatedRecordsExist(Map<Id, Project_Task__c> oldProjectTaskMap) {
        Set<Id> projectTaskIdsHavingRelatedRecs = new Set<Id>();

        for (String objName : relatedObjectForDeleteValidation) {
            Map<Id, AggregateResult> results = new Map<Id, AggregateResult>(
                DomainUtils.getRelatedObjectCountByApiNameAndLookupName(oldProjectTaskMap.keySet(), objName, 'Project_Task__c')
            );
            for (Id resId : results.keySet()) {
                if (results.get(resId).get('itemCount') != 0) {
                    projectTaskIdsHavingRelatedRecs.add(resId);
                }
            }
        }

        if (!projectTaskIdsHavingRelatedRecs.isEmpty()) {
            for (Id oldProjectTaskId : projectTaskIdsHavingRelatedRecs) {
                oldProjectTaskMap.get(oldProjectTaskId).addError(DELETE_ERROR);
            }
        }
    }

}