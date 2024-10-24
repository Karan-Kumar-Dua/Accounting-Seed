trigger FinancialReportResultValue on Financial_Report_Result_Value__c (before insert, before update) {

    if (Trigger.isInsert && Trigger.isBefore) {
        FinancialReportResultValueActions.setCurrencyByParentLedger(Trigger.new);
    }

    if (Trigger.isUpdate && Trigger.isBefore) {
        FinancialReportResultValueActions.setCurrencyByParentLedger(Trigger.new);
    }
}