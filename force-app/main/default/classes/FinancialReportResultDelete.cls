public with sharing class FinancialReportResultDelete {

    private static final String CONFIRMATION_MESSAGE = Label.COMMON_WRN_DELETE_SELECTED_RECORDS;
    @TestVisible
    private static final String OPERATION_SUCCESS_MESSAGE = Label.INF_FINANCIAL_RESULT_DELETE_SUCCESS;
    @TestVisible
    private static final String NO_SELECTION_ERROR_MESSAGE = Label.ERR_NO_FINANCIAL_RESULT_SELECTED_DELETE;

    private List<Financial_Report_Result__c> reportResults;
    public Boolean isValidationPassed {get; set;}

    public FinancialReportResultDelete(ApexPages.StandardSetController setController) {
        try {
            this.reportResults = queryFinancialReportResults(setController.getSelected());
            this.isValidationPassed = validateOnLoad();
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
        }
    }

    private List<Financial_Report_Result__c> queryFinancialReportResults(List<Financial_Report_Result__c> selectedFRR) {
        String queryCondition = 'Id IN :selectedFRR';
        SOQLBuilder theQuery = new SOQLBuilder(Financial_Report_Result__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .setCondition(queryCondition);

        return (List<Financial_Report_Result__c>) Database.query(theQuery.toSOQL());
    }

    private Boolean validateOnLoad() {
        if (reportResults.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, NO_SELECTION_ERROR_MESSAGE));
            return false;
        }

        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, CONFIRMATION_MESSAGE));
        return true;
    }

    public PageReference deleteRecords() {
        if (isValidationPassed) {
            try {
                SFDCSecurityUtils.deleteCheckCRUDAndFLS(reportResults);
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.CONFIRM, OPERATION_SUCCESS_MESSAGE));
                isValidationPassed = false;
            }
            catch (Exception ex) {
                ApexPages.addMessages(ex);
            }
        }
        return NULL;
    }

}