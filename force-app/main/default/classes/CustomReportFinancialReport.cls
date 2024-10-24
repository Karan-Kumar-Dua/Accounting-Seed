public with sharing class CustomReportFinancialReport extends AbstractFinancialReport {
    private static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    private Financial_Report_Definition__c financialReportDefinition;
    private List<Financial_Report_Row__c> rowList;
    private List<Financial_Report_Column__c> colList;

    public override FinancialReportWrapper runReport(FinancialReportOptions aReportOptions) {
        CustomFinancialReportOptions reportOptions = (CustomFinancialReportOptions) aReportOptions;
        reportOptions.glAccounts = new List<GL_Account__c>();

        List<String> ledgerIds = new List<String>();
        Set<Id> glAccountIds = new Set<Id>();
        Set<Id> reportingGroupIds = new Set<Id>();
        Map<String, List<String>> reportingGroupMap = new Map<String, List<String>>();

        financialReportDefinition = queryReportDefinition(reportOptions.financialReportDefinitionId);
        rowList = new List<Financial_Report_Row__c>();
        // populate row list using for loop to avoid issues when > 200 rows
        for (Financial_Report_Row__c row : financialReportDefinition.Financial_Report_Rows__r) {
            rowList.add(row);
        }
        colList = financialReportDefinition.Financial_Report_Columns__r;

        if (!rowList.isEmpty()) {
            //Loop through to get the GL Reporting Group id's
            for (Financial_Report_Row__c r : rowList) {
                if (r.GL_Account_Reporting_Group__c != NULL) {
                    reportingGroupIds.add(r.GL_Account_Reporting_Group__c);
                }
            }

            //Query and loop through the reporting groups to get the GL accounts and add them to the reporting group map
            List<GL_Account_Reporting_Group_Line__c> glAccountReportingGroupLines =
                DomainUtils.getGlAccountReportingGroupLinesByMasterId(reportingGroupIds);

            for (GL_Account_Reporting_Group_Line__c grp : glAccountReportingGroupLines) {
                if (reportingGroupMap.containsKey(grp.GL_Account_Reporting_Group__c)) {
                    reportingGroupMap.get(grp.GL_Account_Reporting_Group__c).add(grp.GL_Account__c);
                }
                else {
                    reportingGroupMap.put(grp.GL_Account_Reporting_Group__c, new List<String>{grp.GL_Account__c});
                }
            }
            
            //Loop through all of the rows again calling the track balance method to track all balances by gl's and av's
            for (Financial_Report_Row__c r : rowList) {
                if (r.Type__c == FinancialReportRowActions.FRR_TYPE_GL_ACCOUNT && r.GL_Account__c != NULL) {
                    glAccountIds.add(r.GL_Account__c);
                } 
                else if (r.Type__c == FinancialReportRowActions.FRR_TYPE_REPORTING_GROUP) {
                    //Get the reporting group from the map and loop through the gl accounts
                    for (String glAcc : reportingGroupMap.get(r.GL_Account_Reporting_Group__c)) {
                        glAccountIds.add((Id) glAcc);
                    }
                } 
            }
        }

        for (Financial_Report_Column__c col : financialReportDefinition.Financial_Report_Columns__r) {
            if (col.Ledger__c != NULL) {
                ledgerIds.add(col.Ledger__c);
            }
        }

        reportOptions.glAccounts = DomainUtils.getGlAccountsById(glAccountIds);
        reportOptions.ledgerIds = ledgerIds;
        if (!ledgerIds.isEmpty()) {
            reportOptions.ledger = ledgerIds[0];
        }
        this.reportOptions = reportOptions;

        return super.generateReport();
    }

    public override FinancialReportWrapper createReportDefinition() {
        FinancialReportWrapper frw = new FinancialReportWrapper();
        Integer columnCount = (reportOptions != null && reportOptions.getListOfPeriodNames() != NULL ? reportOptions.getListOfPeriodNames().size() : 0);
        //wrapper's property to specify Landscape or Portrait View when the report will be rendered as PDF
        frw.viewModeInPDF = columnCount < 5 ? 'Portrait' : 'Landscape';
        //================================================================================================
        frw.reportDefinition = financialReportDefinition;
        frw.reportDefinition.Subtitle__c = reportOptions.getReportSubtitle();
        frw.rowList = rowList;
        frw.colList = colList;
        return frw;
    }

    public static Financial_Report_Definition__c queryReportDefinition(Id selectedReportId) {
        //Main query
        List<String> queryFields = new List<String>{
            'Id', 'Name', 'Subtitle__c', 'Percentage_Decimal_Places__c'
        };
        String queryCondition = 'Id = :selectedReportId';
        //Rows SubQuery
        String rowsSubQueryRelationshipName = PACKAGE_QUALIFIER + 'Financial_Report_Rows__r';
        List<String> rowsQueryFields = new List<String>{
            'Id',
            'Name',
            'Underline__c',
            'Type__c',
            'SystemModstamp',
            'Suppress_Print__c',
            'Position__c',
            'Normal_Balance__c',
            'Indent__c',
            'GL_Account__c',
            'GL_Account__r.Name',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c',
            'Financial_Report_Definition__c',
            'GL_Account_Reporting_Group__c',
            'Row_Label__c',
            'Calculation__c',
            'Calculation_Long__c',
            'GL_Account__r.Type__c'
        };
        SOQLBuilder.Ordering rowsOrdering = new SOQLBuilder.Ordering('Financial_Report_Row__c', 'Position__c', SOQLBuilder.SortOrder.ASCENDING);
        //Columns Subquery
        String columnsSubQueryRelationshipName = PACKAGE_QUALIFIER + 'Financial_Report_Columns__r';
        List<String> columnsQueryFields = new List<String>{
            'Id',
            'Name',
            'Type__c',
            'Suppress_Print__c',
            'Position__c',
            'Header_2__c',
            'Header_1__c',
            'Financial_Report_Definition__c',
            'Column_Overide_Row__c',
            'Calculation__c',
            'Header_1_Value__c',
            'Header_2_Value__c',
            'Offset__c',
            'Ledger__c'
        };
        SOQLBuilder.Ordering columnsOrdering = new SOQLBuilder.Ordering('Financial_Report_Column__c', 'Position__c', SOQLBuilder.SortOrder.ASCENDING);

        SOQLBuilder theQuery = new SOQLBuilder(Financial_Report_Definition__c.SObjectType);
        theQuery
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);
        theQuery
            .subselectQuery(rowsSubQueryRelationshipName, false)
            .setEnforceFLS(false)
            .selectFields(rowsQueryFields)
            .addOrdering(rowsOrdering);
        theQuery
            .subselectQuery(columnsSubQueryRelationshipName, false)
            .setEnforceFLS(false)
            .selectFields(columnsQueryFields)
            .addOrdering(columnsOrdering);

        return (Financial_Report_Definition__c) Database.query(theQuery.toSOQL());
    }
}