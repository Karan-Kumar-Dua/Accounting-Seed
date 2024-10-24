trigger FinRepRowTrigger on Financial_Report_Row__c (after insert, after update) {

    if (Trigger.isAfter && Trigger.isInsert) {
        FinancialReportRowActions.validateRowType(Trigger.new);
        FinancialReportRowActions.validateGLAccountType(Trigger.new);
        FinancialReportRowActions.validateGLAccountReportingGroup(Trigger.new);
        FinancialReportRowActions.validateFormula(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        FinancialReportRowActions.validateRowType(Trigger.new);
        FinancialReportRowActions.validateGLAccountType(Trigger.new);
        FinancialReportRowActions.validateGLAccountReportingGroup(Trigger.new);
        FinancialReportRowActions.validateFormula(Trigger.new);        
    }
}