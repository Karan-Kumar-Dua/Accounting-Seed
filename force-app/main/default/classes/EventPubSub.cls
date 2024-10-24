public with sharing class EventPubSub {
   
    @TestVisible
    private static List<SObject> publishedPlatformEvents;
    private static void recordPublishedEvents(List<SObject> platformEvents) {
        if (Test.isRunningTest()) {
            if (publishedPlatformEvents == null) {
                publishedPlatformEvents = new List<SObject>();
            }
            publishedPlatformEvents.addAll(platformEvents);
        }
    }

    private static final String INVALID_INPUT_EXCEPTION = Label.ERR_INVALID_INPUT_PARAMETER;

    /**
     * Specifies when an event will be published
     */
    public enum PublishDelay {
        IMMEDIATE,
        ON_COMMIT
    }

    public class InvalidInputException extends Exception {}

    /**
     * Factory method for creating a domain event.
     * The returned event can be published using `EventBus::publish`
     * @param PublishDelay delay - when to publish the event
     * @param EventRegistry.RegisteredEvent eventType - the event type
     * @param String eventId - the event id
     * @param Object payload - the event payload
     * @return Publishable - a domain event
     */
    public static Publishable createEvent(
        PublishDelay delay, 
        EventRegistry.RegisteredEvent eventType, 
        String eventId, 
        Object payload
    ) {
        if (delay == PublishDelay.IMMEDIATE) {
            return new ImmediateEvent(eventType, eventId, payload);
        }
        else if (delay == PublishDelay.ON_COMMIT) {
            return new CommitEvent(eventType, eventId, payload);
        }
        throw new InvalidInputException(String.format(
            INVALID_INPUT_EXCEPTION, 
            new String[]{ 'delay', String.valueOf(delay) }
        ));
    }
    
    /**
     * Publishes a domain event by converting it to a Platform Event and calling EventBus__publish.
     * @param Publishable event - a domain event
     * @return Database.SaveResult - the result of publishing the event
     */
    public static Database.SaveResult publish(Publishable event) {
        if (event == null) {
            return null;
        }
        List<Database.SaveResult> results = publish(new Publishable[]{ event });
        return results.isEmpty() ? null : results[0];
    }

    /**
     * @see EventPubSub::publish(Publishable)
     */
    public static List<Database.SaveResult> publish(List<Publishable> events) {
        if (events == null || events.isEmpty()) {
            return null;
        }
        List<SObject> platformEvents = new List<SObject>();
        for (Publishable event : events) {
            platformEvents.add(event.toPlatformEvent());
        }
        recordPublishedEvents(platformEvents);
        return EventBus.publish(platformEvents);
    }

    /**
     * Execute Platform Event listeners.
     * @param AS_Immediate_Event__e[] events - the platform events to consume
     * @return errors encountered during processing
     */
    public static List<ConsumerError> consume(AS_Immediate_Event__e[] events) {
        List<ConsumerError> errors = new List<ConsumerError>();
        EventCallbackExecutor dispatcher = new EventCallbackExecutor();
        for (AS_Immediate_Event__e event : events) {
            try {
                dispatcher.add(new ImmediateEvent(event));
            } catch(ASEvent.InvalidInputException ex) {
                errors.add(new ConsumerError(event.Request_Id__c, ex));
            }
        } 
        errors.addAll(dispatcher.exec());
        return errors;
    }

    /**
     * @see EventPubSub::consume(AS_Immediate_Event__e[])
     */
    public static List<ConsumerError> consume(AS_Commit_Event__e[] events) {
        List<ConsumerError> errors = new List<ConsumerError>();
        EventCallbackExecutor dispatcher = new EventCallbackExecutor();
        for (AS_Commit_Event__e event : events) {
            try {
                dispatcher.add(new CommitEvent(event));
            } catch(ASEvent.InvalidInputException ex) {
                errors.add(new ConsumerError(event.Request_Id__c, ex));
            }
        }
        errors.addAll(dispatcher.exec());
        return errors;
    }

    private class EventCallbackExecutor {
        Map<EventRegistry.RegisteredEvent,List<ASEvent>> groupedEvents;
        
        public EventCallbackExecutor() {
            groupedEvents = new Map<EventRegistry.RegisteredEvent,List<ASEvent>>();
        }

        public void add(ASEvent event) {
            if (groupedEvents.containsKey(event.getType())) {
                groupedEvents.get(event.getType()).add(event);
            }
            else {
                groupedEvents.put(event.getType(), new ASEvent[] { event });
            }
        }

        public List<ConsumerError> exec() {
            List<ConsumerError> errors = new List<ConsumerError>();
            for (EventRegistry.RegisteredEvent regEvent : groupedEvents.keySet()) {
                EventCallback callback = groupedEvents.get(regEvent).get(0).getCallback();
                try {
                    callback.call(groupedEvents.get(regEvent));
                } catch(Exception ex) {
                    for (ASEvent event : groupedEvents.get(regEvent)) {
                        errors.add(new ConsumerError(event.getId(), ex));
                    }
                }
            }
            return errors;
        }
    }

    public class ConsumerError {
        public String eventRequestId;
        public Exception error;
        public ConsumerError(String eventRequestId, Exception error) {
            this.eventRequestId = eventRequestId;
            this.error = error;
        }
    }

}