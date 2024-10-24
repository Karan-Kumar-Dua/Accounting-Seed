public with sharing class PaymentProposalStatusBatch implements Database.Batchable<SObject>, Database.Stateful{
    
    private String query; 
    private static Final String STATUS_PROCESSED = 'Processed';
    private Set<Id> payPropIds = new Set<Id>();

    public PaymentProposalStatusBatch(Set<Id> paymentProposalIds) {
        this.payPropIds = paymentProposalIds;
        this.query = 'SELECT Id, Status__c FROM Payment_Proposal__c WHERE Id IN :genericIdSet';
    }

    public Database.QueryLocator start(Database.BatchableContext batchableContext) {
        return DomainUtils.getQueryLocator(query, payPropIds);
    }

    public void execute(Database.BatchableContext batchableContext, List<Payment_Proposal__c> payProps) {
        for(Payment_Proposal__c payProp : payProps){
            payProp.Status__c = STATUS_PROCESSED;
        }

        SFDCSecurityUtils.updateCheckCRUDAndFLS(payProps, new List<String>{'Status__c'}, false);
    
    }

    public void finish(Database.BatchableContext batchableContext) {
        publishPayPropPublishFinishPlatformEvent();
    }

    private static void publishPayPropPublishFinishPlatformEvent(){
        EventPubSub.publish(
            EventPubSub.createEvent(
                EventPubSub.PublishDelay.IMMEDIATE,
                EventRegistry.RegisteredEvent.PAYMENT_PROPOSAL_PUBLISH_END,
                FinancialSuiteUtils.getUUID(),
                NULL
            )
        );
    }
}