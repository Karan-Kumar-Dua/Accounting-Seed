public with sharing abstract class ASEvent implements Publishable, Consumable {

    private static final String REQUIRED_INPUT_EXCEPTION_MSG = Label.ERR_REQUIRED_INPUT_EXCEPTION;
    private static final String PAYLOAD_TYPE_EXCEPTION_MSG = Label.ERR_PAYLOAD_TYPE_EXCEPTION;

    protected String eventId;
    protected String payload;
    protected EventRegistry.RegisteredEvent eventType;
    protected EventRegistry.EventDefinition eventDef;

    public class InvalidInputException extends Exception {}
    public class TypeMismatchException extends Exception {}

    public abstract SObject toPlatformEvent();

    protected void nonNull(Object obj, String paramName) {
        if (obj == null) {
            throw new InvalidInputException(String.format(REQUIRED_INPUT_EXCEPTION_MSG, new String[] {paramName}));
        }
    }

    protected void nonBlank(String s, String paramName) {
        if (String.isBlank(s)) {
            throw new InvalidInputException(String.format(REQUIRED_INPUT_EXCEPTION_MSG, new String[] {paramName}));
        }
    }

    protected void setId(String eventId) {
        nonBlank(eventId, 'eventId');
        this.eventId = eventId;
    }

    protected void setType(EventRegistry.RegisteredEvent eventType) {
        nonNull(eventType, 'eventType');
        this.eventType = eventType;
    }

    protected void setPayload(Object payload) {
        EventRegistry.EventDefinition eventDef = getEventDefinition();
        if (eventDef.payloadType == null) {
            return;
        }
        try {
            JSON.deserialize(JSON.serialize(payload), eventDef.payloadType);
        } catch (Exception ex) {
            throw new TypeMismatchException(PAYLOAD_TYPE_EXCEPTION_MSG);
        }
        this.payload = JSON.serialize(payload);
    }

    protected EventRegistry.EventDefinition getEventDefinition() {
        if (eventDef == null) {
            eventDef = EventRegistry.lookup(eventType);
        }
        return eventDef;
    }

    public String getId() {
        return eventId;
    }

    public Object getPayload() {
        EventRegistry.EventDefinition eventDef = getEventDefinition();
        if (payload == null || eventDef == null || eventDef.payloadType == null) {
            return null;
        }
        return JSON.deserialize(payload, eventDef.payloadType);
    }

    public EventRegistry.RegisteredEvent getType() {
        EventRegistry.EventDefinition eventDef = getEventDefinition();
        return eventDef.eventType; 
    }

    public EventCallback getCallback() {
        EventRegistry.EventDefinition eventDef = getEventDefinition();
        return new EventCallback(eventDef);
    }

}