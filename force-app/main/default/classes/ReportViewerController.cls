public with sharing class ReportViewerController {
    private static final String NO_REPORT_DEFINITION_FOUND_ERROR =
        Label.ERR_NO_REPORT_DEFINITION_FOUND;

    public transient Financial_Report_Result__c report {get; private set;}
    public transient FinancialReportWrapper frw {get; private set;}
    public String outputOption {get; private set;}
    public Boolean showPage {get; private set;}
    public class ReportViewerControllerException extends Exception {}

    public ReportViewerController(ApexPages.StandardController controller) {
        try {
            showPage = true;
            if (report == NULL) {
                outputOption =
                    ApexPages.currentPage().getParameters().get('output') == NULL
                        ? 'pdf'
                        : ApexPages.currentPage().getParameters().get('output');

                frw = new FinancialReportWrapper();
                report = queryFinancialReportResultById(controller.getId());
                
                Attachment attachment;
                try {
                    attachment = queryAttachment(report.Id);
                }
                catch (QueryException ex) {

                }

                if (attachment != NULL) {
                    String jsonDefinition = attachment.Body.toString();
                    frw = (FinancialReportWrapper) JSON.deserialize(jsonDefinition, FinancialReportWrapper.class);
                }
                else if (report.Financial_Report_Definition__r != NULL) {
                    frw.reportDefinition = report.Financial_Report_Definition__r;
                    frw.rowList = queryFinancialReportRows(frw.reportDefinition.Id);
                    frw.colList = queryFinancialReportColumns(frw.reportDefinition.Id);
                }
                else {
                    throw new ReportViewerControllerException(String.format(NO_REPORT_DEFINITION_FOUND_ERROR, new List<String>{report.Name}));
                }

                // if page param `layout` is set then override financial report's value
                String displayOrientation = ApexPages.currentPage().getParameters().get('layout');
                if (String.isNotEmpty(displayOrientation)) {
                    frw.viewModeInPDF = displayOrientation;
                }
                frw.viewModeInPDF = frw.viewModeInPDF.toLowerCase();

                if (frw.reportResult == null) {
                    frw.reportResult = report;
                }
                frw.reportvalues = queryFinancialReportResultValues(report.Id);
            }
        }
        catch (Exception ex) {
            showPage = false;
            ApexPages.addMessages(ex);
        }
    }

    //we have to check read access to Fin Statement Result record and specially to Accounting_Period__r field
    //because we use this data as a required parameter of ReportTableComponent, so we must be sure in advance
    // that this data is available for an user
    private Financial_Report_Result__c queryFinancialReportResultById(String finReportResultId) {
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Financial_Report_Definition__r.Name',
            'Financial_Report_Definition__r.Subtitle__c',
            'Accounting_Period__c',
            'Accounting_Period__r.Name'
        };
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }
        String queryCondition = 'Id = :finReportResultId';
        SOQLBuilder theQuery = new SOQLBuilder(Financial_Report_Result__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (Financial_Report_Result__c) Database.query(theQuery.toSOQL());
    }

    private List<Financial_Report_Row__c> queryFinancialReportRows(String financialReportDefinitionId) {
        List<String> queryFields = new List<String>{
            'GL_Account__c',
            'Position__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c'
        };
        String queryCondition =
            'Financial_Report_Definition__c = :financialReportDefinitionId ORDER BY Position__c ASC';
        SOQLBuilder theQuery = new SOQLBuilder(Financial_Report_Row__c.SObjectType);
        theQuery
//            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Financial_Report_Row__c>) Database.query(theQuery.toSOQL());
    }

    private List<Financial_Report_Column__c> queryFinancialReportColumns(String financialReportDefinitionId) {
        List<String> queryFields = new List<String>{
            'Offset__c',
            'Position__c',
            'Type__c'
        };
        String queryCondition =
            'Financial_Report_Definition__c = :financialReportDefinitionId ORDER BY Position__c ASC';
        SOQLBuilder theQuery = new SOQLBuilder(Financial_Report_Column__c.SObjectType);
        theQuery
//            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Financial_Report_Column__c>) Database.query(theQuery.toSOQL());
    }

    private List<Financial_Report_Result_Value__c> queryFinancialReportResultValues(String finReportResultId) {
        List<String> queryFields = new List<String>{
            'Column_Header_1__c',
            'Column_Header_2__c',
            'Text_Value__c',
            'Currency_Value__c',
            'Financial_Report_Column__c',
            'Indent__c',
            'Underline__c',
            'Row_Position__c',
            'Column_Position__c',
            'Financial_Report_Column__r.Position__c',
            'Financial_Report_Column__r.Ledger__c',
            'Row_Type__c',
            'Column_Type__c',
            'Financial_Report_Row__c',
            'Suppress_Print__c',
            'Financial_Report_Row__r.Position__c',
            'Row_Label__c',
            'Financial_Report_Result__r.Financial_Report_Definition__c',
            'Column_Override_Row__c',
            'Financial_Report_Result__c',
            'Suppress_Cell_Hyperlink__c',
            'Id',
            'Name'
        };
        String queryCondition =
            'Financial_Report_Result__c = :finReportResultId ' +
            'AND Suppress_Print__c = false ' +
            'ORDER BY Column_Position__c ASC, Row_Position__c ASC';

        SOQLBuilder theQuery = new SOQLBuilder(Financial_Report_Result_Value__c.SObjectType);
        theQuery
//            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        //to add localized currency value
        String soqlString = theQuery.toSOQL().replace('Currency_Value__c', 'Currency_Value__c, FORMAT(Currency_Value__c) currValue');

        return (List<Financial_Report_Result_Value__c>) Database.query(soqlString);
    }

    private Attachment queryAttachment(String finReportResultId) {
        List<String> queryFields = new List<String>{
            'Id', 'Name', 'Body'
        };
        String queryCondition =
            'ParentId = :finReportResultId AND Name = \'Financial_Report_Definition\' ORDER BY CreatedDate DESC LIMIT 1';
        SOQLBuilder theQuery = new SOQLBuilder(Attachment.SObjectType);
        theQuery
//            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (Attachment) Database.query(theQuery.toSOQL());
    }

}