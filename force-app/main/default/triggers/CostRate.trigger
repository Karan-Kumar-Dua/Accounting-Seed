trigger CostRate on Cost_Rates__c (before insert, after insert, before update, after update) {

    if (Trigger.isInsert && Trigger.isBefore) {
        CostRateActions.preventSetOvertimeHourlyCostWithoutHourlyCost(Trigger.new);
    }

    if (Trigger.isInsert && Trigger.isAfter) {
        CostRateActions.preventWeeklySalaryAndProjectAndProjectTask(Trigger.new);
    }

    if (Trigger.isUpdate && Trigger.isBefore) {
        CostRateActions.preventSetOvertimeHourlyCostWithoutHourlyCost(Trigger.new);
    }

    if (Trigger.isUpdate && Trigger.isAfter) {
        CostRateActions.preventWeeklySalaryAndProjectAndProjectTask(Trigger.new);
    }

}