public with sharing class CashDisbursementApplyModel {
    public Cash_Disbursement__c cashDisbursement;
    public List<CashApplication> cashApplications;

    public CashDisbursementApplyModel() {
        this.cashApplications = new List<CashApplication>();
    }
}