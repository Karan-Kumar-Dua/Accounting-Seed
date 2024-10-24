public with sharing class CostRateActions {
   
    public static final String WEEKLEY_SALARY_PROJECT_ERROR = Label.ERR_WEEKLEY_SALARY_PROJECT;
    public static final String HOURLY_COST_MUST_BE_SET_ERROR = Label.ERR_HOURLY_COST_MUST_BE_SET;

    public static void preventWeeklySalaryAndProjectAndProjectTask(List<Cost_Rates__c> costRates) {
        for (Cost_Rates__c cr : costRates) {
            if (cr.Weekly_Salary_Cost__c != NULL && cr.Project__c != NULL) {
                cr.Project__c.addError(WEEKLEY_SALARY_PROJECT_ERROR);
            }
        }
    }

    public static void preventSetOvertimeHourlyCostWithoutHourlyCost(List<Cost_Rates__c> newCostRates) {
        for (Cost_Rates__c cr : newCostRates) {
            if (cr.Overtime_Hourly_Cost__c != NULL && cr.Hourly_Cost__c == NULL) {
                cr.Hourly_Cost__c.addError(HOURLY_COST_MUST_BE_SET_ERROR);
            }
        }
    }

}