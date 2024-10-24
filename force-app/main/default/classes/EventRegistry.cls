public with sharing class EventRegistry {
    
    /**
     * event types
     */
    public enum RegisteredEvent {
        BANK_RECONCILIATION_COMPLETED_STATUS_CHANGE,
        BANK_RECONCILIATION_IN_PROGRESS_STATUS_CHANGE,
        BANK_RECONCILIATION_AUTO_CLEAR_RUNNING_STATUS_CHANGE,
        BANK_RECONCILIATION_WORKING_STATUS_CHANGE,
        BANK_RECONCILIATION_GL_BALANCE_CALCULATED,
        BANK_RECONCILIATION_CLEAR_ITEMS,
        BANK_TRANSACTIONS_DOWNLOAD_START,
        BANK_TRANSACTIONS_DOWNLOAD_END,
        BANK_TRANSACTIONS_ERROR,
        FINANCIAL_REPORTER_GENERATE_START,
        FINANCIAL_REPORTER_GENERATE_END,
        PAYMENT_PROPOSAL_PUBLISH_START,
        PAYMENT_PROPOSAL_PUBLISH_END
    }

    /**
     * information about an event
     */
    public class EventDefinition {
        public RegisteredEvent eventType {get; protected set;}
        public Type payloadType {get; private set;}
        public EventDefinition(Type payloadType) {
            this.payloadType = payloadType;
        }
    }

    /**
     * Event subscriber
     */
    public class Subscriber {
        public Type type {get; private set;}
        public Subscriber(Type type) {
            this.type = type;
        }
    }

    // event definition lookup table
    private static Map<RegisteredEvent,EventDefinition> registry = new Map<RegisteredEvent,EventDefinition>{
        RegisteredEvent.BANK_RECONCILIATION_COMPLETED_STATUS_CHANGE 
            => new EventDefinition(null),
        RegisteredEvent.BANK_RECONCILIATION_IN_PROGRESS_STATUS_CHANGE 
            => new EventDefinition(null),
        RegisteredEvent.BANK_RECONCILIATION_AUTO_CLEAR_RUNNING_STATUS_CHANGE
            => new EventDefinition(null),
        RegisteredEvent.BANK_RECONCILIATION_WORKING_STATUS_CHANGE
            => new EventDefinition(null),
        RegisteredEvent.BANK_RECONCILIATION_GL_BALANCE_CALCULATED 
            => new EventDefinition(GLAccountBalance.Balance.class),
        RegisteredEvent.BANK_RECONCILIATION_CLEAR_ITEMS 
            => new EventDefinition(null),
        RegisteredEvent.BANK_TRANSACTIONS_DOWNLOAD_START
            => new EventDefinition(null),
        RegisteredEvent.BANK_TRANSACTIONS_DOWNLOAD_END 
            => new EventDefinition(String.class),
        RegisteredEvent.BANK_TRANSACTIONS_ERROR
            => new EventDefinition(String.class),
        RegisteredEvent.FINANCIAL_REPORTER_GENERATE_START
            => new EventDefinition(null),
        RegisteredEvent.FINANCIAL_REPORTER_GENERATE_END
            => new EventDefinition(null),
        RegisteredEvent.PAYMENT_PROPOSAL_PUBLISH_START
            => new EventDefinition(null),
        RegisteredEvent.PAYMENT_PROPOSAL_PUBLISH_END
            => new EventDefinition(null)
    };

    // event subscription lookup table
    private static Map<RegisteredEvent,Subscriber> subscriptions = new Map<RegisteredEvent,Subscriber>{
        RegisteredEvent.BANK_RECONCILIATION_IN_PROGRESS_STATUS_CHANGE 
            => new Subscriber(BankRecEventCallbacks.class),
        RegisteredEvent.BANK_RECONCILIATION_AUTO_CLEAR_RUNNING_STATUS_CHANGE 
            => new Subscriber(BankRecEventCallbacks.class),
        RegisteredEvent.BANK_RECONCILIATION_WORKING_STATUS_CHANGE 
            => new Subscriber(BankRecEventCallbacks.class),
        RegisteredEvent.BANK_RECONCILIATION_GL_BALANCE_CALCULATED 
            => new Subscriber(BankRecEventCallbacks.class),
        RegisteredEvent.BANK_RECONCILIATION_CLEAR_ITEMS 
            => new Subscriber(BankRecEventCallbacks.class),
        RegisteredEvent.BANK_TRANSACTIONS_DOWNLOAD_START
            => new Subscriber(null),
        RegisteredEvent.BANK_TRANSACTIONS_DOWNLOAD_END
            => new Subscriber(null),
        RegisteredEvent.BANK_TRANSACTIONS_ERROR
            => new Subscriber(null),
        RegisteredEvent.FINANCIAL_REPORTER_GENERATE_START
            => new Subscriber(null),
        RegisteredEvent.FINANCIAL_REPORTER_GENERATE_END
            => new Subscriber(null),
        RegisteredEvent.PAYMENT_PROPOSAL_PUBLISH_START
            => new Subscriber(null),
        RegisteredEvent.PAYMENT_PROPOSAL_PUBLISH_END
            => new Subscriber(null)
    };

    /**
     * !!! TEST ONLY !!!
     * All registered events will map to the provided inputs so you can inject a mock callable.
     */
    @TestVisible
    private static void registerTestEvent(EventDefinition def, Subscriber sub) {
        if (Test.isRunningTest()) {
            for (RegisteredEvent regEvent : registry.keySet()) {
                def.eventType = regEvent;
                registry.put(regEvent, def);
                subscriptions.put(regEvent, sub);
            }
        }
    }

    /**
     * Get the EventDefinition corresponding to the input RegisteredEvent.
     * If no definition is found null is returned.
     * @param RegisteredEvent event - registered event.
     * @return `EventDefinition` - definition corresponding to the input event.
     */
    public static EventDefinition lookup(RegisteredEvent event) {
        EventDefinition def = registry.get(event);
        if (def != null) {
            def.eventType = event;
        }
        return def;
    }

    /**
     * Get the subscribers/listeners for this event. Curently, there is only support 
     * for 1-1 mapping of events to subscriptions.
     * @param RegisteredEvent event - registered event
     * @return List<Subscriber> - all listeners for the input event
     */
    public static Subscriber getSubscriber(RegisteredEvent event) {
        return subscriptions.get(event);
    }

    /**
     * Get a RegisteredEvent based on name.
     * @param String registeredEvent - name of a RegisteredEvent.
     * @return RegisteredEvent - the registered event corresponding to the input name.
     */
    public static RegisteredEvent getRegisteredEventByName (String registeredEventName) {
        if (registeredEventName == null) {
            return null;
        }
        for (RegisteredEvent event : RegisteredEvent.values()) {
            if (registeredEventName.equalsIgnoreCase(event.name())) {
                return event;
            }
        }
        return null;
    }

}