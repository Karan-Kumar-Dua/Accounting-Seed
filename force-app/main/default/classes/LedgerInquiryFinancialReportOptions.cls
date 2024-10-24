public with sharing class LedgerInquiryFinancialReportOptions extends FinancialReportOptions {

    @AuraEnabled
    public Boolean isErpEnabled;
    @AuraEnabled
    public Boolean isHlpMode;
    @AuraEnabled
    public Id glAccount;
    @AuraEnabled
    public Id product;
    @AuraEnabled
    public Id project;
    @AuraEnabled
    public Id projectTask;
    @AuraEnabled
    public Id account;
    @AuraEnabled
    public List<String> source;
    @AuraEnabled
    public String aggregatedBy;
    @AuraEnabled
    public Boolean glAccountVariable1ReadAccess;
    @AuraEnabled
    public Boolean glAccountVariable2ReadAccess;
    @AuraEnabled
    public Boolean glAccountVariable3ReadAccess;
    @AuraEnabled
    public Boolean glAccountVariable4ReadAccess;
    @AuraEnabled
    public String glAccountVariable1FieldLabel;
    @AuraEnabled
    public String glAccountVariable2FieldLabel;
    @AuraEnabled
    public String glAccountVariable3FieldLabel;
    @AuraEnabled
    public String glAccountVariable4FieldLabel;

    public LedgerInquiryFinancialReportOptions() {
        super();
        this.endingAccountingPeriod = AccountingPeriodHandler.getInstance().getFirstOpenedPeriod()?.Id;
        this.startingAccountingPeriod = AccountingPeriodHandler.getInstance().getFinancialReportStartPeriod(
            this.endingAccountingPeriod, ACCOUNTING_PERIOD_RANGE_LIMIT
        )?.Id;

        this.isErpEnabled = AccountingSettingsHandler.isERPEnabled();
        this.isHlpMode = AccountingSettingsHandler.isHeaderLevelPost();
        this.source = new List<String>{'all'};
        this.aggregatedBy = 'none';
        this.glAccountVariable1ReadAccess = checkReadAccess(
            Financial_Report_Result__c.SObjectType,
            Financial_Report_Result__c.GL_Account_Variable_1__c
        );
        this.glAccountVariable2ReadAccess = checkReadAccess(
            Financial_Report_Result__c.SObjectType,
            Financial_Report_Result__c.GL_Account_Variable_2__c
        );
        this.glAccountVariable3ReadAccess = checkReadAccess(
            Financial_Report_Result__c.SObjectType,
            Financial_Report_Result__c.GL_Account_Variable_3__c
        );
        this.glAccountVariable4ReadAccess = checkReadAccess(
            Financial_Report_Result__c.SObjectType,
            Financial_Report_Result__c.GL_Account_Variable_3__c
        );
        this.glAccountVariable1FieldLabel = Financial_Report_Result__c.GL_Account_Variable_1__c.getDescribe().getLabel();
        this.glAccountVariable2FieldLabel = Financial_Report_Result__c.GL_Account_Variable_2__c.getDescribe().getLabel();
        this.glAccountVariable3FieldLabel = Financial_Report_Result__c.GL_Account_Variable_3__c.getDescribe().getLabel();
        this.glAccountVariable4FieldLabel = Financial_Report_Result__c.GL_Account_Variable_4__c.getDescribe().getLabel();
    }

    private Boolean checkReadAccess(SObjectType soType, SObjectField soField) {
        SFDCSecurityUtils.FlsInspectionResult result = SFDCSecurityUtils.checkFieldIsReadable(soType, soField);
        return !result.inspectionFailed;
    }

    public override List<String> getListOfPeriodNames() {
        return AccountingPeriodHandler.getInstance().toString(getAllPeriodsInReportingRange());
    }

    public override List<Accounting_Period__c> getAllPeriodsInReportingRange() {
        return AccountingPeriodHandler.getInstance().getAccountingPeriodsFromRange(
            this.startingAccountingPeriod, this.endingAccountingPeriod
        );
    }

    public override List<Id> getLedgerIds() {
        return new List<Id>{this.ledger};
    }
}