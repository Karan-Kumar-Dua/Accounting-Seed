public with sharing class PurgeBillingAgingHistoryBatch extends PurgeBaseBatch {

    public final Id accPeriodId;

    public PurgeBillingAgingHistoryBatch(Id valuePeriodId) {
        this.objectLabel = Billing_Aging_History__c.getsObjectType().getDescribe().getLabel();
        this.accPeriodId = valuePeriodId;
    }

    public override Database.QueryLocator start(Database.BatchableContext BC){
        Set<Id> closedAccIds;
        String query = 'SELECT Id FROM Billing_Aging_History__c WHERE ';
        try {
            closedAccIds = getClosedAccountingPeriodsById(accPeriodId);
            if (closedAccIds != NULL) {
                query += 'Accounting_Period__c IN :genericIdSet';
            }
            else {
                query += 'Id = NULL';
            }
        }
        catch (AccountingPeriodHandler.AccountingPeriodException ex) {
            query += 'Id = NULL';
        }

        return DomainUtils.getQueryLocator(query, closedAccIds);
    }

}