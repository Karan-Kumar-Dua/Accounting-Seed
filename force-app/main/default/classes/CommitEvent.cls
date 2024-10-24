public with sharing class CommitEvent extends ASEvent implements Publishable, Consumable {
    
    private CommitEvent() {}

    public CommitEvent(EventRegistry.RegisteredEvent eventType, String eventId, Object jsonData) {
        this.setId(eventId);
        this.setType(eventType);
        this.setPayload(jsonData);
    }

    public CommitEvent(AS_Commit_Event__e event) {
        this.setId(event.Request_Id__c);
        this.payload = event.Payload__c;
        this.setType(EventRegistry.getRegisteredEventByName(event.Type__c));
    }

    override public SObject toPlatformEvent() {
        return new AS_Commit_Event__e(
            Request_Id__c = this.eventId,
            Type__c = this.eventType <> null ? this.eventType.name() : null,
            Payload__c = this.payload
        );
    }

}