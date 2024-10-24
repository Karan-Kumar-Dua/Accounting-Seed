public with sharing class ImmediateEvent extends ASEvent implements Publishable, Consumable {
    
    private ImmediateEvent() {}

    public ImmediateEvent(EventRegistry.RegisteredEvent eventType, String eventId, Object jsonData) {
        this.setId(eventId);
        this.setType(eventType);
        this.setPayload(jsonData);
    }

    public ImmediateEvent(AS_Immediate_Event__e event) {
        this.setId(event.Request_Id__c);
        this.payload = event.Payload__c;
        this.setType(EventRegistry.getRegisteredEventByName(event.Type__c));
    }

    override public SObject toPlatformEvent() {
        return new AS_Immediate_Event__e(
            Request_Id__c = this.eventId,
            Type__c = this.eventType <> null ? this.eventType.name() : null,
            Payload__c = this.payload
        );
    }

}