trigger FinRepColTrigger on Financial_Report_Column__c (after insert, after update) {

    if (Trigger.isAfter && Trigger.isInsert) {
        FinancialReportColumnActions.validateColType(Trigger.new);
        FinancialReportColumnActions.validateFormula(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        FinancialReportColumnActions.validateColType(Trigger.new);
        FinancialReportColumnActions.validateFormula(Trigger.new);
    }
}