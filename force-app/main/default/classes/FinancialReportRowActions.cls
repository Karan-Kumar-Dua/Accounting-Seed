public with sharing class FinancialReportRowActions {

    public static final String POSITION_VALUE_ERROR = Label.ERR_POSITION_VALUE_GREATER_ZERO;
    public static final String BLANK_TYPE_ERROR = Label.ERR_BLANK_TYPE;
    public static final String INVALID_TYPE_ERROR = Label.ERR_INVALID_TYPE;
    public static final String MUST_SELECT_GL_ACCOUNT_TYPE_ERROR = Label.ERR_MUST_SELECT_GL_ACCOUNT_TYPE;
    public static final String MUST_SELECT_GL_ACCOUNT_REPORTING_GROUP_TYPE_ERROR = Label.ERR_MUST_SELECT_GL_ACCOUNT_REPORTING_GROUP_TYPE;
    public static final String EMPTY_CALCULATION_ERROR = Label.ERR_EMPTY_CALCULATION_ROW;
    public static final String CASH_FLOW_RELATED_GL_ACCOUNT_ERROR = Label.ERR_CASH_FLOW_RELATED_GL_ACCOUNT;
    public static final String CASH_FLOW_RELATED_GL_ACCOUNT_IN_GROUP_ERROR = Label.ERR_CASH_FLOW_RELATED_GL_ACCOUNT_IN_GROUP;
    public static final String EMPTY_GL_ACCOUNT_REPORTING_GROUP = Label.ERR_EMPTY_GL_ACCOUNT_REPORTING_GROUP;

    //=== TYPE picklist values =============================================
    public static final String FRR_TYPE_GL_ACCOUNT = 'GL Account';
    public static final String FRR_TYPE_REPORTING_GROUP = 'Reporting Group';
    public static final String FRR_TYPE_DESCRIPTION = 'Description';
    public static final String FRR_TYPE_BLANK = 'Blank';
    public static final String FRR_TYPE_CALCULATION_NUMBER = 'Calculation Number';
    public static final String FRR_TYPE_CALCULATION_PERCENTAGE = 'Calculation Percentage';
    public static final String FRR_TYPE_CALCULATION_PERCENTAGE_SYMBOL = 'Calculation %';
    //=== NORMAL BALANCE picklist values =====================================
    public static final String FRR_NORMAL_BALANCE_DEBIT = 'Debit';
    public static final String FRR_NORMAL_BALANCE_CREDIT = 'Credit';
    //Placeholder-marker for moved calculation formula
    public static final String CALC_IS_MOVED_PLACEHOLDER = '{r999999}';

    public static Set<String> validRowTypes = new Set<String> {
        FRR_TYPE_GL_ACCOUNT,
        FRR_TYPE_REPORTING_GROUP,
        FRR_TYPE_DESCRIPTION,
        FRR_TYPE_BLANK,
        FRR_TYPE_CALCULATION_NUMBER,
        FRR_TYPE_CALCULATION_PERCENTAGE,
        FRR_TYPE_CALCULATION_PERCENTAGE_SYMBOL/*legacy support*/
    };

    public static Set<ValidationType> preventValidationTypes = new Set<ValidationType>();
    
    public static void validateRowType(List<Financial_Report_Row__c> newFinReportRows) {

        for (Financial_Report_Row__c aRow : newFinReportRows) {

            if (aRow.Position__c <= 0) {
                aRow.Position__c.addError(POSITION_VALUE_ERROR);
                continue;
            }

            //Validate row types
            if (aRow.Type__c == NULL) {
                aRow.Type__c.addError(BLANK_TYPE_ERROR);
                continue;
            }
            if (!validRowTypes.contains(aRow.Type__c)) {
                aRow.Type__c.addError(INVALID_TYPE_ERROR);
                continue;
            }
            if (aRow.Type__c == FRR_TYPE_GL_ACCOUNT && aRow.GL_Account__c == NULL) {
                aRow.GL_Account__c.addError(MUST_SELECT_GL_ACCOUNT_TYPE_ERROR);
                continue;
            }
            if (aRow.Type__c == FRR_TYPE_REPORTING_GROUP && aRow.GL_Account_Reporting_Group__c == NULL) {
                aRow.GL_Account_Reporting_Group__c.addError(MUST_SELECT_GL_ACCOUNT_REPORTING_GROUP_TYPE_ERROR);
                continue;
            }
            if (!preventValidationTypes.contains(ValidationType.CALCULATION) && aRow.Type__c.startsWith('Calculation') && aRow.Calculation__c == NULL) {
                aRow.Calculation__c.addError(EMPTY_CALCULATION_ERROR);
                continue;
            }

        }

    }

    public static void validateGLAccountType(List<Financial_Report_Row__c> newFinReportRows) {

        Set<Id> glAccountIds = new Set<Id>();
        for (Financial_Report_Row__c aRow : newFinReportRows) {
            if (aRow.Type__c == FRR_TYPE_GL_ACCOUNT && aRow.GL_Account__c != NULL) {
                glAccountIds.add(aRow.GL_Account__c);
            }
        }

        if (!glAccountIds.isEmpty()) {
            Map<Id, GL_Account__c> glAccountMap = new Map<Id, GL_Account__c>(
                DomainUtils.getGlAccountsById(glAccountIds)
            );

            for (Financial_Report_Row__c aRow : newFinReportRows) {
                if (aRow.Type__c == FRR_TYPE_GL_ACCOUNT
                        && aRow.GL_Account__c != NULL
                        && glAccountMap.containsKey(aRow.GL_Account__c)
                        && glAccountMap.get(aRow.GL_Account__c).Type__c == GLAccountActions.GL_ACCOUNT_TYPE_CASH_FLOW) {

                    aRow.GL_Account__c.addError(CASH_FLOW_RELATED_GL_ACCOUNT_ERROR);
                }
            }
        }
    }

    public static void validateGLAccountReportingGroup(List<Financial_Report_Row__c> newFinReportRows) {
        Set<Id> glAcctReportingGroupIds = new Set<Id>();
        for (Financial_Report_Row__c aRow : newFinReportRows) {
            if (aRow.Type__c == FRR_TYPE_REPORTING_GROUP && aRow.GL_Account_Reporting_Group__c != NULL) {
                glAcctReportingGroupIds.add(aRow.GL_Account_Reporting_Group__c);
            }
        }

        if (!glAcctReportingGroupIds.isEmpty()) {
            Map<Id, GL_Account_Reporting_Group__c> cashFlowGlAcctReportingGroupMap = new Map<Id, GL_Account_Reporting_Group__c>(
                DomainUtils.getGlAccountReportingGroupWithCashFlowRelatedLines(glAcctReportingGroupIds)
            );
            Map<Id, GL_Account_Reporting_Group__c> glAcctReportingGroupMap = new Map<Id, GL_Account_Reporting_Group__c>(
                DomainUtils.getGlAccountReportingGroupByIdWithRelatedLines(glAcctReportingGroupIds, null)
            );

            for (Financial_Report_Row__c aRow : newFinReportRows) {
                //validate Cash Flow GL Account in a group
                if (aRow.Type__c == FRR_TYPE_REPORTING_GROUP
                        && aRow.GL_Account_Reporting_Group__c != NULL
                        && cashFlowGlAcctReportingGroupMap.containsKey(aRow.GL_Account_Reporting_Group__c)
                        && !cashFlowGlAcctReportingGroupMap.get(aRow.GL_Account_Reporting_Group__c).GL_Account_Reporting_Group_Lines__r.isEmpty()) {

                    aRow.GL_Account_Reporting_Group__c.addError(CASH_FLOW_RELATED_GL_ACCOUNT_IN_GROUP_ERROR);
                }
                //validate empty GL Accounting Group
                if (aRow.Type__c == FRR_TYPE_REPORTING_GROUP
                        && aRow.GL_Account_Reporting_Group__c != NULL
                        && glAcctReportingGroupMap.containsKey(aRow.GL_Account_Reporting_Group__c)
                        && glAcctReportingGroupMap.get(aRow.GL_Account_Reporting_Group__c).GL_Account_Reporting_Group_Lines__r.isEmpty()) {

                    aRow.GL_Account_Reporting_Group__c.addError(EMPTY_GL_ACCOUNT_REPORTING_GROUP);
                }
            }
        }
    }

    public static void validateFormula(List<Financial_Report_Row__c> newFinReportRows) {

        for (Financial_Report_Row__c aRow : newFinReportRows) {
            
            if (!preventValidationTypes.contains(ValidationType.CALCULATION) && aRow.Type__c != NULL && aRow.Type__c.startsWith('Calculation') && aRow.Calculation__c != NULL) {
                Integer p = Integer.valueOf(aRow.Position__c);
                FinancialReportFormulaValidator f = new FinancialReportFormulaValidator(aRow.Calculation__c, FinancialReportFormulaValidator.FormulaTypes.ROW, p, p);
                
                FinancialReportFormulaValidator.ValidationResult res = f.validate();

                if (res.errors != NULL && res.errors.size() > 0) {
                    for (FinancialReportFormulaValidator.ValidationResultError vr : res.errors) {
                        aRow.Calculation__c.addError(vr.message);
                    }
                    continue;
                }
            }

        }
        
    }

    public enum ValidationType {
        CALCULATION
    }

}