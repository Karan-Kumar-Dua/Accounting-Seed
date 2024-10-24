public with sharing class FinancialReportWrapper {
    @AuraEnabled
    public Financial_Report_Definition__c reportDefinition {get; set;}
    @AuraEnabled
    public Financial_Report_Result__c reportResult {get; set;}
    @AuraEnabled
    public List<Financial_Report_Column__c> colList {get; set;}
    @AuraEnabled
    public List<Financial_Report_Row__c> rowList {get; set;}
    @AuraEnabled
    public List<Financial_Report_Result_Value__c> reportValues {get; set;}
    @AuraEnabled
    public Map<Integer, Accounting_Period__c> reportPeriodsByOffset = new Map<Integer, Accounting_Period__c>();
    @AuraEnabled
    public Boolean missingOpeningBalanceData = false;
    public String viewModeInPDF {
        get {
            if (viewModeInPDF == NULL) {
                return 'Landscape';//default mode
            }
            else {
                return viewModeInPDF;
            }
        }
        set;
    }

    public FinancialReportWrapper() {
        colList = new List<Financial_Report_Column__c>();
        rowList = new List<Financial_Report_Row__c>();
        reportValues = new List<Financial_Report_Result_Value__c>();
    }

    public String getLedgerId () {
        String result;
        for (Financial_Report_Column__c col : colList) {
            if (col.Ledger__c != NULL && col.Header_2__c != 'calculated-budget-column') {
                result = col.Ledger__c;
                break;
            }
        }
        return result;
    }

    public String getBudgetLedgerId () {
        String result;
        for (Financial_Report_Column__c col : colList) {
            if (col.Ledger__c != NULL && col.Header_2__c == 'calculated-budget-column') {
                result = col.Ledger__c;
                break;
            }
        }
        return result;
    }

    public String getGLVariable1Id () {
        String result;
        for (Financial_Report_Row__c rowItem : rowList) {
            if (rowItem.GL_Account_Variable_1__c != NULL) {
                result = rowItem.GL_Account_Variable_1__c;
                break;
            }
        }
        return result;
    }

    public String getGLVariable2Id () {
        String result;
        for (Financial_Report_Row__c rowItem : rowList) {
            if (rowItem.GL_Account_Variable_2__c != NULL) {
                result = rowItem.GL_Account_Variable_2__c;
                break;
            }
        }
        return result;
    }

    public String getGLVariable3Id () {
        String result;
        for (Financial_Report_Row__c rowItem : rowList) {
            if (rowItem.GL_Account_Variable_3__c != NULL) {
                result = rowItem.GL_Account_Variable_3__c;
                break;
            }
        }
        return result;
    }

    public String getGLVariable4Id () {
        String result;
        for (Financial_Report_Row__c rowItem : rowList) {
            if (rowItem.GL_Account_Variable_4__c != NULL) {
                result = rowItem.GL_Account_Variable_4__c;
                break;
            }
        }
        return result;
    }
}