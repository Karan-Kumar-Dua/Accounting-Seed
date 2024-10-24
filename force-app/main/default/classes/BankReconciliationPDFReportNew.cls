public with sharing class BankReconciliationPDFReportNew {
    public Bank_Reconciliation2__c bankRec {get; set;}
    public String currencyIsoCode {get; set;}
    public Boolean isError {get; set;}
    public String errorMessage {get; set;}

    public BankReconciliationPDFReportNew() {
        try {
            this.isError = false;
            String bankReconciliationId = (Id) ApexPages.currentPage().getParameters().get('id');
            bankRec = queryBankRec(bankReconciliationId);

            currencyIsoCode = MultiCurrencyHandler.isMultiCurrencyEnabled ? (String) bankRec.get('CurrencyIsoCode') : MultiCurrencyHandler.CORPORATE_CURRENCY;
        }
        catch (Exception ex) {
            this.isError = true;
            this.errorMessage = ex.getMessage();
        }
    }

    private Bank_Reconciliation2__c queryBankRec(String bankReconciliationId) {
        //Query Bank Reconciliation record with CRUD and FLS checks
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Bank_Account__c',
            'Bank_Account__r.Name',

            'End_Date__c',
            'Beginning_Balance__c',
            'Ending_Balance__c',
            'Cleared_Deposits__c',
            'Cleared_Disbursements__c',
            'Calculated_Ending_Balance__c',
            'Calculated_GL_Balance__c',
            'Uncleared_Amount__c',
            'UnCleared_Deposits__c',
            'UnCleared_Payments__c',
            'GL_Ending_Balance__c',
            'Type__c',
            'Ledger__c',
            'Ledger__r.Name',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c',
            'GL_Account_Variable_1__r.Name',
            'GL_Account_Variable_2__r.Name',
            'GL_Account_Variable_3__r.Name',
            'GL_Account_Variable_4__r.Name',
            'LastModifiedDate'
        };
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }

        String queryCondition = 'Id = :bankReconciliationId';

        SOQLBuilder theQuery = new SOQLBuilder(Bank_Reconciliation2__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (Bank_Reconciliation2__c) Database.query(theQuery.toSOQL());
    }

    public String getBeginningBalance() {
        return FinancialSuiteUtils.getDecimalLocaleFormatString(bankRec.Beginning_Balance__c, 2);
    }

    public String getClearedDepositsString() {
        return FinancialSuiteUtils.getDecimalLocaleFormatString(getClearedDepositsDecimal(), 2);
    }

    public String getClearedDisbursementsString() {
        return FinancialSuiteUtils.getDecimalLocaleFormatString(getClearedDisbursementsDecimal(), 2);
    }

    public String getUnClearedDepositsString() {
        return FinancialSuiteUtils.getDecimalLocaleFormatString(getUnClearedDepositsDecimal(), 2);
    }

    public String getUnClearedDisbursementsString() {
        return FinancialSuiteUtils.getDecimalLocaleFormatString(getUnClearedDisbursementsDecimal(), 2);
    }

    public String getCalculatedEndingBalance() {
        return FinancialSuiteUtils.getDecimalLocaleFormatString(bankRec.Calculated_Ending_Balance__c, 2);
    }

    public String getEndingBalance() {
        return FinancialSuiteUtils.getDecimalLocaleFormatString(bankRec.GL_Ending_Balance__c, 2);
    }

    public String getEndingBalanceDifference() {
        return FinancialSuiteUtils.getDecimalLocaleFormatString(bankRec.Uncleared_Amount__c, 2);
    }

    public String getGLVariable1() {
        return bankRec.GL_Account_Variable_1__r.Name;
    }

    public String getGLVariable2() {
        return bankRec.GL_Account_Variable_2__r.Name;
    }

    public String getGLVariable3() {
        return bankRec.GL_Account_Variable_3__r.Name;
    }

    public String getGLVariable4() {
        return bankRec.GL_Account_Variable_4__r.Name;
    }

    public Decimal getClearedDepositsDecimal() {
        return isBankType() ? bankRec.Cleared_Deposits__c : bankRec.Cleared_Deposits__c * -1;
    }

    public Decimal getClearedDisbursementsDecimal() {
        return isBankType() ? bankRec.Cleared_Disbursements__c * -1 : bankRec.Cleared_Disbursements__c;
    }

    public Decimal getUnClearedDepositsDecimal() {
        return isBankType() ? bankRec.UnCleared_Deposits__c : bankRec.UnCleared_Deposits__c * -1;
    }

    public Decimal getUnClearedDisbursementsDecimal() {
        return isBankType() ? bankRec.UnCleared_Payments__c * -1 : bankRec.UnCleared_Payments__c;
    }

    private Boolean isBankType() {
        return bankRec.Type__c == 'Bank';
    }

}