public with sharing class PurgeAPAgingHistoryBatch extends PurgeBaseBatch {

    public final Id accPeriodId;

    public PurgeAPAgingHistoryBatch(Id valuePeriodId) {
        this.objectLabel = AP_Aging_History__c.getsObjectType().getDescribe().getLabel();
        this.accPeriodId = valuePeriodId;
    }

    public override Database.QueryLocator start(Database.BatchableContext bc) {
        Set<Id> closedAccIds;
        String query = 'SELECT Id FROM AP_Aging_History__c WHERE ';
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