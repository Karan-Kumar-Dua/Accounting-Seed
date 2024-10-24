public with sharing class EnablementsQueueable implements Queueable, Database.AllowsCallouts {

    private TriggerOperation triggerContext;
    private List<Accounting_Settings__c> data;

    public EnablementsQueueable(TriggerOperation triggerContext, List<Accounting_Settings__c> data) {
        this.triggerContext = triggerContext;
        this.data = data;
    }

    public void execute(QueueableContext context) {
        LEDService.sendData(triggerContext, data);
    }
}