public with sharing class DeleteAPDBatch implements Database.Batchable<sObject>, Database.Stateful {

    private Set<Id> apdIds;
    private Cash_Disbursement__c cd;

    public DeleteAPDBatch(Set<Id> apdIds, Cash_Disbursement__c cd) {
        this.apdIds = apdIds;
        this.cd = cd;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id, Status__c FROM AP_Disbursement__c WHERE Id IN :genericIdSet';
        return DomainUtils.getQueryLocator(query, apdIds);
    }

    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        List<AP_Disbursement__c> unpostList = new List<AP_Disbursement__c>();
        for (AP_Disbursement__c apd : (List<AP_Disbursement__c>) scope) {
            if (apd.Status__c == AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED) {
                unpostList.add(apd);
            }
        }
        if (!unpostList.isEmpty()) {
            APDisbursementPostHandler postHandler = new APDisbursementPostHandler();
            postHandler.unpost(unpostList);
        }
        TriggerObserver.bypassDeleteApDisbursement = true;
        SFDCSecurityUtils.deleteProxy(scope);
        TriggerObserver.bypassDeleteApDisbursement = false;
    }

    public void finish(Database.BatchableContext bc) {
        if (cd != null) {
            if (cd.Status__c == AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED) {
                CashDisbursementPostHandler postHandler = new CashDisbursementPostHandler();
                postHandler.unpost(new List<Cash_Disbursement__c> {cd});
            }
            SFDCSecurityUtils.deleteProxy(cd);
        }
    }

}