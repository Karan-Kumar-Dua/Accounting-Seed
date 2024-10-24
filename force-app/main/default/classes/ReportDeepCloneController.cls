public with sharing class ReportDeepCloneController {

    public String newReportName {get; set;}
    public String newReportDescription {get; set;}
    public Financial_Report_Definition__c reportDef {get; private set;}

    public Boolean cloneRows {get; set;}
    public Boolean cloneCols {get; set;}

    public Boolean disableCloneRows {get; private set;}
    public Boolean disableCloneCols {get; private set;}

    public Integer numRows {get; private set;}
    public Integer numCols {get; private set;}

    private List<Financial_Report_Row__c> reportRows = new List<Financial_Report_Row__c>();
    private List<Financial_Report_Column__c> reportCols = new List<Financial_Report_Column__c>();
    @TestVisible
    private static final String NO_REPORT_NAME_ERROR = Label.ERR_NO_REPORT_NAME;

    @TestVisible
    private Financial_Report_Definition__c newReportDef;

    public ReportDeepCloneController(ApexPages.StandardController controller) {
        try {
            cloneRows = true;
            cloneCols = true;

            reportDef = queryFinancialReportDefinition((String) controller.getId());
            reportRows = queryFinancialReportRows((String) controller.getId());
            reportCols = queryFinancialReportColumns((String) controller.getId());

            newReportDescription = reportDef.Description__c;

            if (!reportRows.isEmpty()) {
                numRows = reportRows.size();
            }
            else {
                cloneRows = false;
                numRows = 0;
                disableCloneRows = true;
            }

            if (!reportCols.isEmpty()) {
                numCols = reportCols.size();
            }
            else {
                cloneCols = false;
                numCols = 0;
                disableCloneCols = true;
            }
        }
        catch (Exception ex) {
            addError(ex.getMessage());
        }
    }

    private Financial_Report_Definition__c queryFinancialReportDefinition(String frdId) {
        //Query Financial Report Definition record with CRUD and FLS checks
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Description__c',
            'Percentage_Decimal_Places__c'
        };

        String queryCondition = 'Id = :frdId LIMIT 1';
        SOQLBuilder theQuery = new SOQLBuilder(Financial_Report_Definition__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (Financial_Report_Definition__c) Database.query(theQuery.toSOQL());
    }

    private List<Financial_Report_Row__c> queryFinancialReportRows(String frdId) {
        //Query Financial Report Rows records with CRUD and FLS checks
        List<String> queryFields = new List<String>{
            'Id',
            'Underline__c',
            'Type__c',
            'Suppress_Print__c',
            'Row_Label__c',
            'Position__c',
            'Normal_Balance__c',
            'Indent__c',
            'GL_Account__c',
            'GL_Account_Variable_4__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Reporting_Group__c',
            'Financial_Report_Definition__c',
            'Calculation__c'
        };

        String queryCondition = 'Financial_Report_Definition__c = :frdId';
        SOQLBuilder theQuery = new SOQLBuilder(Financial_Report_Row__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Financial_Report_Row__c>) Database.query(theQuery.toSOQL());
    }

    private List<Financial_Report_Column__c> queryFinancialReportColumns(String frdId) {
        //Query Financial Report Columns records with CRUD and FLS checks
        List<String> queryFields = new List<String>{
            'Id',
            'Type__c',
            'Suppress_Print__c',
            'Position__c',
            'Offset__c',
            'Header_2__c',
            'Header_2_Value__c',
            'Header_1__c',
            'Header_1_Value__c',
            'Financial_Report_Definition__c',
            'Column_Overide_Row__c',
            'Calculation__c',
            'Ledger__c'
        };

        String queryCondition = 'Financial_Report_Definition__c = :frdId';
        SOQLBuilder theQuery = new SOQLBuilder(Financial_Report_Column__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Financial_Report_Column__c>) Database.query(theQuery.toSOQL());
    }

    public PageReference deepClone() {
        if (String.isBlank(newReportName)) {
            addError(NO_REPORT_NAME_ERROR);
            return NULL;
        }

        newReportDef = reportDef.clone(false, true);
        newReportDef.Name = newReportName;
        newReportDef.Description__c = newReportDescription;

        Savepoint sp = Database.setSavepoint();
        try {
            SFDCSecurityUtils.insertCheckCRUDAndFLS(newReportDef, new List<String>{
                'Name',
                'Description__c',
                'Percentage_Decimal_Places__c'
            });

            if (!reportRows.isEmpty() && cloneRows == true) {
                List<Financial_Report_Row__c> newReportRows = reportRows.deepClone(false);
                for (Financial_Report_Row__c r : newReportRows) {
                    r.Financial_Report_Definition__c = newReportDef.Id;
                }

                SFDCSecurityUtils.insertCheckCRUDAndFLS(newReportRows, new List<String>{
                    'Underline__c',
                    'Type__c',
                    'Suppress_Print__c',
                    'Row_Label__c',
                    'Position__c',
                    'Normal_Balance__c',
                    'Indent__c',
                    'GL_Account__c',
                    'GL_Account_Variable_4__c',
                    'GL_Account_Variable_3__c',
                    'GL_Account_Variable_2__c',
                    'GL_Account_Variable_1__c',
                    'GL_Account_Reporting_Group__c',
                    'Financial_Report_Definition__c',
                    'Calculation__c'
                });
            }

            if (!reportCols.isEmpty() && cloneCols == true) {
                Boolean isZeroPosition = false;
                List<Financial_Report_Column__c> newReportCols = reportCols.deepClone(false);
                for (Financial_Report_Column__c c : newReportCols) {
                    c.Financial_Report_Definition__c = newReportDef.Id;
                    if (!isZeroPosition && c.Position__c == 0) {
                        isZeroPosition = true;
                    }
                }

                if (isZeroPosition) {
                    FinancialReportColumnActions.preventValidationTypes.addAll(new Set<FinancialReportColumnActions.ValidationType>{
                        FinancialReportColumnActions.ValidationType.POSITION,
                        FinancialReportColumnActions.ValidationType.CALCULATION
                    });
                }

                SFDCSecurityUtils.insertCheckCRUDAndFLS(newReportCols, new List<String>{
                    'Type__c',
                    'Suppress_Print__c',
                    'Position__c',
                    'Offset__c',
                    'Header_2__c',
                    'Header_2_Value__c',
                    'Header_1__c',
                    'Header_1_Value__c',
                    'Financial_Report_Definition__c',
                    'Column_Overide_Row__c',
                    'Calculation__c',
                    'Ledger__c'
                });
            }

            PageReference ref = new PageReference('/' + newReportDef.Id);
            ref.setRedirect(true);
            return ref;
        }
        catch (Exception ex) {
            Database.rollback(sp);
            addError(ex.getMessage());
            return NULL;
        }

    }

    private void addError(String msg) {
        Boolean isExist = false;
        for (ApexPages.Message message : ApexPages.getMessages()) {
            if (message.getSummary().contains(msg) || msg.contains(message.getSummary())) {
                isExist = true;
            }
        }
        if (!isExist) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, msg));
        }
    }

}