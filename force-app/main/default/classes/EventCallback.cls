public with sharing class EventCallback {

    private static final String NON_CALLABLE_TYPE_EXEPTION = Label.ERR_NON_CALLABLE_TYPE_EXEPTION;
    private static final String INVALID_INPUT_EXCEPTION = Label.ERR_INVALID_INPUT_PARAMETER;
 
    private Callable callableInstance;
    private EventRegistry.EventDefinition eventDef {get; private set;}

    public class NonCallableTypeException extends Exception {}
    public class InvalidInputException extends Exception {}
    
    private static void notNull(String paramName, Object value) {
        if (value == null) {
            throw new InvalidInputException(String.format(
                INVALID_INPUT_EXCEPTION, 
                new String[]{ paramName , 'null' }
            ));  
        }
    }

    private void createCallableInstance() {
        try {
            EventRegistry.Subscriber listener = EventRegistry.getSubscriber(eventDef.eventType);
            if (listener != null && listener.type != null) {
                callableInstance = (Callable) listener.type.newInstance();
            }
        } catch (TypeException ex) {                // subscriber does not implement callable
            throw new NonCallableTypeException(NON_CALLABLE_TYPE_EXEPTION);
        }
    }

    public EventCallback(EventRegistry.EventDefinition eventDef) {
        notNull('eventDef', eventDef);
        if (eventDef.eventType != null) {
            this.eventDef = eventDef;
            createCallableInstance();
        }
    }

    public void call(List<Consumable> events) {
        if (callableInstance != null) {
            callableInstance.call(eventDef.eventType.name(), new Map<String, Object> {
                'events' => events
            });
        } 
    }

}