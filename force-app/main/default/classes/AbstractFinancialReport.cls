public with sharing abstract class AbstractFinancialReport implements FinancialReport {

    public class ReportRowException extends Exception {}
    public static final String TOO_MANY_ROWS_ERROR = Label.ERR_FIN_REPORT_TOO_MANY_ROWS;
    public static final String NO_NON_ZERO_ROWS_ERROR = Label.ERR_FIN_REPORT_NO_NON_ZERO_ROWS;

    public static Integer REPORT_CELL_LIMIT = 5000;

    @TestVisible
    protected FinancialReportOptions reportOptions;
    protected Accounting_Settings__c main;
    public abstract FinancialReportWrapper runReport(FinancialReportOptions fro);
    protected abstract FinancialReportWrapper createReportDefinition();

    protected FinancialReportWrapper generateReport() {
        FinancialReportWrapper frw = createReportDefinition();
        FinancialReportBatch batch = new FinancialReportBatch(frw, reportOptions);

        Id batchProcessId = Database.executeBatch(batch);

        List<Financial_Report_Result__c> finReportResults =
            DomainUtils.getFinancialReportResultsById(new Set<Id>{batch.reportStubId});

        if (!finReportResults.isEmpty()) {
            finReportResults[0].Batch_Id__c = batchProcessId;
            finReportResults[0].Report_Type__c = reportOptions.getReportTypeName();
            SFDCSecurityUtils.updateProxy(finReportResults);
            frw.reportResult = finReportResults[0];
        }

        return frw;
    }

    protected Accounting_Settings__c getAccountingSettings() {
        if (main == NULL) {
            main = AccountingSettingsHandler.getAccountingSettings();
        }
        return main;
    }

    protected Boolean isExpenseGLAccountExisted(List<GL_Account__c> xGlAccounts) {
        Boolean result = false;
        for (GL_Account__c xGlAccount : xGlAccounts) {
            if (xGlAccount.Type__c == GLAccountActions.GL_ACCOUNT_TYPE_EXPENSE && xGlAccount.Sub_Type_1__c != null) {
                result = true;
                break;
            }
        }
        return result;
    }

    protected GL_Account__c createDummyExpenseGLAccount() {
        return new GL_Account__c(
            Id = FinancialSuiteUtils.getFakeId(GL_Account__c.SObjectType),
            Name = 'Dummy GL Account',
            Type__c = GLAccountActions.GL_ACCOUNT_TYPE_EXPENSE,
            Sub_Type_1__c = 'Cost of Goods Sold',
            Sub_Type_2__c = 'Labor'
        );
    }

    protected Boolean isAssetsGlAccountExisted(List<GL_Account__c> xGlAccounts) {
        Boolean result = false;
        for (GL_Account__c xGlAccount : xGlAccounts) {
            if (xGlAccount.Sub_Type_1__c == GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_ASSETS) {
                result = true;
                break;
            }
        }
        return result;
    }

    protected Boolean isLiabilitiesGlAccountExisted(List<GL_Account__c> xGlAccounts) {
        Boolean result = false;
        for (GL_Account__c xGlAccount : xGlAccounts) {
            if (xGlAccount.Sub_Type_1__c == GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_LIABILITIES) {
                result = true;
                break;
            }
        }
        return result;
    }

    protected Boolean isOwnersEquityGlAccountExisted(List<GL_Account__c> xGlAccounts) {
        Boolean result = false;
        for (GL_Account__c xGlAccount : xGlAccounts) {
            if (xGlAccount.Sub_Type_1__c == GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_OWNERS_EQUITY) {
                result = true;
                break;
            }
        }
        return result;
    }

    protected Boolean includeTotal(String subType, Boolean isSuppressEmpty) {
        return (subType != NUll && subType != 'Uncategorized') || (subType == 'Uncategorized' && !isSuppressEmpty);
    }

    protected Boolean isLastSubTypeIncluded(String subType, String lastIncluded) {
        return subType == lastIncluded;
    }

    protected Boolean checkTypePicklistIsOrderedCorrectly() {
        Schema.DescribeFieldResult dfr = GL_Account__c.Type__c.getDescribe();
        Integer revenuePos = 0;
        Integer expensePos = 0;
        Integer pos = 0;
        for (Schema.PicklistEntry plValue : dfr.getPicklistValues()) {
            if (plValue.getValue().equalsIgnoreCase(GLAccountActions.GL_ACCOUNT_TYPE_REVENUE)) {
                revenuePos = pos;
            }
            else if (plValue.getValue().equalsIgnoreCase(GLAccountActions.GL_ACCOUNT_TYPE_EXPENSE)) {
                expensePos = pos;
            }
            pos++;
        }

        return expensePos > revenuePos;
    }

    protected List<GL_Account__c> doCustomOrdering(List<GL_Account__c> glAccounts) {
        List<GL_Account__c> result = new List<GL_Account__c>();
        List<GL_Account__c> revenueGlAccounts = new List<GL_Account__c>();
        List<GL_Account__c> expenseGlAccounts = new List<GL_Account__c>();

        for (GL_Account__c glAcct : glAccounts) {
            if (glAcct.Type__c == GLAccountActions.GL_ACCOUNT_TYPE_REVENUE) {
                revenueGlAccounts.add(glAcct);
            }
            else {
                expenseGlAccounts.add(glAcct);
            }
        }

        result.addAll(revenueGlAccounts);
        result.addAll(expenseGlAccounts);

        return result;
    }

    protected Integer getEstimatedNumberOfRowsForProfitAndLoss(List<GL_Account__c> glAccounts, Boolean isGroupBySubtype1, Boolean isGroupBySubtype2) {
        Integer totalRowCount = 13; // Initial non-GL Account rows
        Map<String, Integer> allSubtypesMap;
        if (isGroupBySubtype2) {
            allSubtypesMap = countNumberOfSubTypeValues(glAccounts);
            //header and total rows of each Sub Type 1
            totalRowCount += 2 * (allSubtypesMap.get('subType1') + 1);//+1 because uncategorized for each Type
            //header and total rows of each Sub Type 2
            totalRowCount += 2 * (allSubtypesMap.get('subType2') + 1);//+1 because uncategorized for each Type
            //header and total rows of each Uncategorized Sub Type 2
            totalRowCount += 2 * (allSubtypesMap.get('subType1AndEmptySubType2'));
            //2 empty rows after each Sub Type 1 Total
            totalRowCount += 2 * (allSubtypesMap.get('subType1'));
            //add GL Account rows
            totalRowCount += glAccounts.size();
        }
        else if (isGroupBySubtype1) {
            allSubtypesMap = countNumberOfSubTypeValues(glAccounts);
            //header and total rows of each Sub Type 1
            totalRowCount += 2 * (allSubtypesMap.get('subType1') + 1);//+1 because uncategorized for each Type
            //2 empty rows after each Sub Type 1 Total except last one
            totalRowCount += 2 * (allSubtypesMap.get('subType1') + 1);//+1 because uncategorized for each Type
            //add GL Account rows
            totalRowCount += glAccounts.size();
        }
        else {
            //add GL Account rows
            totalRowCount += glAccounts.size();
        }

        return totalRowCount;
    }

    protected Integer getEstimatedNumberOfRowsForBalanceSheet(List<GL_Account__c> glAccounts, Boolean isGroupBySubtype2) {
        Integer totalRowCount = 11; // Initial non-GL Account rows
        Map<String, Integer> allSubtypesMap;
        if (isGroupBySubtype2) {
            allSubtypesMap = countNumberOfSubTypeValues(glAccounts);
            //2 empty rows after each of Type header rows
            totalRowCount += 6;
            //header and total rows of each Sub Type 2
            totalRowCount += 2 * (allSubtypesMap.get('subType2'));
            //2 empty rows after each Sub Type 2 Total except last one
            totalRowCount += 2 * (allSubtypesMap.get('subType2') - 1);
            //add GL Account rows
            totalRowCount += glAccounts.size();
        }
        else {
            //add GL Account rows
            totalRowCount += glAccounts.size();
        }

        return totalRowCount;
    }

    private Map<String, Integer> countNumberOfSubTypeValues(List<GL_Account__c> glAccounts) {
        Set<String> subType1Values = new Set<String>();
        Set<String> subType2Values = new Set<String>();
        Set<String> subType1ValuesWhereSubType2IsEmpty = new Set<String>();
        //Put unique values including NULL(Uncategorized)
        for (GL_Account__c glAcct : glAccounts) {
            subType1Values.add(glAcct.Sub_Type_1__c);
            subType2Values.add(glAcct.Sub_Type_2__c);

            if (glAcct.Sub_Type_1__c != NULL && glAcct.Sub_Type_2__c == NULL) {
                subType1ValuesWhereSubType2IsEmpty.add(glAcct.Sub_Type_1__c);
            }
        }

        return new Map<String, Integer>{
            'subType1' => subType1Values.size(),
            'subType2' => subType2Values.size(),
            'subType1AndEmptySubType2' => subType1ValuesWhereSubType2IsEmpty.size()
        };
    }

}