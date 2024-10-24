@IsTest
public with sharing class EventPubSubTest {
    
    private static Integer callableCounter = 0;

    public class CallMe implements Callable {
        public Object call(String action, Map<String, Object> args) {
            EventPubSubTest.callableCounter++;
            return null;
        }
    }

    public class CallMeBroken implements Callable {
        public Object call(String action, Map<String, Object> args) {
            EventPubSubTest.callableCounter++;
            return 1/0;
        }
    }

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testCreateEventImmediate() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            Publishable event = EventPubSub.createEvent(
                EventPubSub.PublishDelay.IMMEDIATE, 
                EventRegistry.RegisteredEvent.BANK_RECONCILIATION_COMPLETED_STATUS_CHANGE, 
                'test', 
                null
            );
            System.assert(event instanceof ImmediateEvent);
        }
    }

    @IsTest
    private static void testCreateEventCommit() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            Publishable event = EventPubSub.createEvent(
                EventPubSub.PublishDelay.ON_COMMIT, 
                EventRegistry.RegisteredEvent.BANK_RECONCILIATION_COMPLETED_STATUS_CHANGE, 
                'test', 
                null
            );
            System.assert(event instanceof CommitEvent);
        }
    }

    @IsTest
    private static void testCreateEventNullDelay() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            Exception expectedEx;
            try {
                EventPubSub.createEvent(
                    null, 
                    EventRegistry.RegisteredEvent.BANK_RECONCILIATION_COMPLETED_STATUS_CHANGE, 
                    'test', 
                    null
                );
            } catch(EventPubSub.InvalidInputException ex) {
                expectedEx = ex;
            }
            System.assertNotEquals(null, expectedEx);
        }
    }

    @IsTest
    private static void testPublishNull() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            Test.startTest();
            Publishable pub1 = null;
            EventPubSub.publish(pub1);
            Publishable[] pub2 = null;
            EventPubSub.publish(pub2);
            Publishable[] pub3 = new Publishable[]{};
            EventPubSub.publish(pub3);
            Test.stopTest();

            System.assertEquals(null, EventBusTestUtils.getPublishedEvents());
        }
    }

    @IsTest
    private static void testPublishSingle() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            EventRegistry.EventDefinition def = new EventRegistry.EventDefinition(null);
            EventRegistry.registerTestEvent(def, null);
            
            EventPubSub.publish(
                EventPubSub.createEvent(
                    EventPubSub.PublishDelay.IMMEDIATE, 
                    EventRegistry.RegisteredEvent.BANK_RECONCILIATION_CLEAR_ITEMS, 
                    'test', 
                    null
                )
            );

            System.assertEquals(1, EventBusTestUtils.getPublishedEvents().size());
        }
    }

    @IsTest
    private static void testPublishMultiple() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            EventRegistry.EventDefinition def = new EventRegistry.EventDefinition(null);
            EventRegistry.registerTestEvent(def, null);

            Publishable[] events = new Publishable[] {
                EventPubSub.createEvent(
                    EventPubSub.PublishDelay.IMMEDIATE, 
                    EventRegistry.RegisteredEvent.BANK_RECONCILIATION_CLEAR_ITEMS, 
                    'test', 
                    null
                ),
                EventPubSub.createEvent(
                    EventPubSub.PublishDelay.ON_COMMIT, 
                    EventRegistry.RegisteredEvent.BANK_RECONCILIATION_CLEAR_ITEMS, 
                    'test', 
                    null
                )
            };

            EventPubSub.publish(events);

            System.assertEquals(2, EventBusTestUtils.getPublishedEvents().size());
        }
    }

    @IsTest
    private static void testConsumeImmediate() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            callableCounter = 0;

            EventRegistry.EventDefinition def = new EventRegistry.EventDefinition(null);
            EventRegistry.Subscriber sub = new EventRegistry.Subscriber(CallMe.class);
            EventRegistry.registerTestEvent(def, sub);

            List<AS_Immediate_Event__e> events = new List<AS_Immediate_Event__e>();
            events.add(new AS_Immediate_Event__e(
                Request_Id__c = 'test',
                Type__c = EventRegistry.RegisteredEvent.BANK_RECONCILIATION_COMPLETED_STATUS_CHANGE.name()
            ));
            events.add(new AS_Immediate_Event__e(
                Request_Id__c = 'test',
                Type__c = EventRegistry.RegisteredEvent.BANK_RECONCILIATION_IN_PROGRESS_STATUS_CHANGE.name()
            ));

            List<EventPubSub.ConsumerError> errors = EventPubSub.consume(events);

            System.assertEquals(0, errors.size());
            System.assertEquals(2, EventPubSubTest.callableCounter);
        }
    }

    @IsTest
    private static void testConsumeCommit() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            callableCounter = 0;

            EventRegistry.EventDefinition def = new EventRegistry.EventDefinition(null);
            EventRegistry.Subscriber sub = new EventRegistry.Subscriber(CallMe.class);
            EventRegistry.registerTestEvent(def, sub);

            List<AS_Commit_Event__e> events = new List<AS_Commit_Event__e>();
            events.add(new AS_Commit_Event__e(
                Request_Id__c = 'test',
                Type__c = EventRegistry.RegisteredEvent.BANK_RECONCILIATION_COMPLETED_STATUS_CHANGE.name()
            ));
            events.add(new AS_Commit_Event__e(
                Request_Id__c = 'test',
                Type__c = EventRegistry.RegisteredEvent.BANK_RECONCILIATION_IN_PROGRESS_STATUS_CHANGE.name()
            ));

            List<EventPubSub.ConsumerError> errors = EventPubSub.consume(events);

            System.assertEquals(0, errors.size());
            System.assertEquals(2, EventPubSubTest.callableCounter);
        }
    }

    @IsTest
    private static void testConsumeCommitUnregistered() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            callableCounter = 0;

            EventRegistry.EventDefinition def = new EventRegistry.EventDefinition(null);
            EventRegistry.Subscriber sub = new EventRegistry.Subscriber(CallMe.class);
            EventRegistry.registerTestEvent(def, sub);

            List<AS_Commit_Event__e> events = new List<AS_Commit_Event__e>();
            events.add(new AS_Commit_Event__e(
                Request_Id__c = 'test',
                Type__c = null
            ));
            events.add(new AS_Commit_Event__e(
                Request_Id__c = 'test',
                Type__c = EventRegistry.RegisteredEvent.BANK_RECONCILIATION_COMPLETED_STATUS_CHANGE.name()
            ));

            List<EventPubSub.ConsumerError> errors = EventPubSub.consume(events);

            System.assertEquals(1, errors.size());
            System.assertEquals(1, EventPubSubTest.callableCounter);
        }
    }

    @IsTest
    private static void testConsumeImmediateUnregistered() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            callableCounter = 0;

            EventRegistry.EventDefinition def = new EventRegistry.EventDefinition(null);
            EventRegistry.Subscriber sub = new EventRegistry.Subscriber(CallMe.class);
            EventRegistry.registerTestEvent(def, sub);

            List<AS_Immediate_Event__e> events = new List<AS_Immediate_Event__e>();
            events.add(new AS_Immediate_Event__e(
                Request_Id__c = 'test',
                Type__c = null
            ));
            events.add(new AS_Immediate_Event__e(
                Request_Id__c = 'test',
                Type__c = EventRegistry.RegisteredEvent.BANK_RECONCILIATION_COMPLETED_STATUS_CHANGE.name()
            ));

            List<EventPubSub.ConsumerError> errors = EventPubSub.consume(events);

            System.assertEquals(1, errors.size());
            System.assertEquals(1, EventPubSubTest.callableCounter);
        }
    }

    @IsTest
    private static void testConsumeCommitBrokenCallback() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            callableCounter = 0;

            EventRegistry.EventDefinition def = new EventRegistry.EventDefinition(null);
            EventRegistry.Subscriber sub = new EventRegistry.Subscriber(CallMeBroken.class);
            EventRegistry.registerTestEvent(def, sub);

            List<AS_Commit_Event__e> events = new List<AS_Commit_Event__e>();
            events.add(new AS_Commit_Event__e(
                Request_Id__c = 'test',
                Type__c = EventRegistry.RegisteredEvent.BANK_RECONCILIATION_COMPLETED_STATUS_CHANGE.name()
            ));

            List<EventPubSub.ConsumerError> errors = EventPubSub.consume(events);

            System.assertEquals(1, errors.size());
            System.assertEquals(1, EventPubSubTest.callableCounter);
        }
    }

    @IsTest
    private static void testConsumeImmediateBrokenCallback() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            callableCounter = 0;

            EventRegistry.EventDefinition def = new EventRegistry.EventDefinition(null);
            EventRegistry.Subscriber sub = new EventRegistry.Subscriber(CallMeBroken.class);
            EventRegistry.registerTestEvent(def, sub);

            List<AS_Immediate_Event__e> events = new List<AS_Immediate_Event__e>();
            events.add(new AS_Immediate_Event__e(
                Request_Id__c = 'test',
                Type__c = EventRegistry.RegisteredEvent.BANK_RECONCILIATION_COMPLETED_STATUS_CHANGE.name()
            ));

            List<EventPubSub.ConsumerError> errors = EventPubSub.consume(events);

            System.assertEquals(1, errors.size());
            System.assertEquals(1, EventPubSubTest.callableCounter);
        }
    }

    @IsTest
    private static void testConsumeCommitBadType() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            callableCounter = 0;

            EventRegistry.EventDefinition def = new EventRegistry.EventDefinition(null);
            EventRegistry.Subscriber sub = new EventRegistry.Subscriber(CallMe.class);
            EventRegistry.registerTestEvent(def, sub);

            List<AS_Commit_Event__e> events = new List<AS_Commit_Event__e>();
            events.add(new AS_Commit_Event__e(
                Type__c = 'RegisteredEvent.FAKE',    
                Request_Id__c = 'poi5ed4wsxedrcftvgybhunijmko',    
                Payload__c = '{"option":1, "data":"asdfeasdbewa"}'
            ));

            List<EventPubSub.ConsumerError> errors = EventPubSub.consume(events);

            System.assertEquals(1, errors.size());
            System.assertEquals(0, EventPubSubTest.callableCounter);
        }
    }

    @IsTest
    private static void testConsumeImmediateBadType() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            callableCounter = 0;

            EventRegistry.EventDefinition def = new EventRegistry.EventDefinition(null);
            EventRegistry.Subscriber sub = new EventRegistry.Subscriber(CallMe.class);
            EventRegistry.registerTestEvent(def, sub);

            List<AS_Immediate_Event__e> events = new List<AS_Immediate_Event__e>();
            events.add(new AS_Immediate_Event__e(
                Type__c = 'RegisteredEvent.FAKE',    
                Request_Id__c = 'poi5ed4wsxedrcftvgybhunijmko',    
                Payload__c = '{"option":1, "data":"asdfeasdbewa"}'
            ));

            List<EventPubSub.ConsumerError> errors = EventPubSub.consume(events);

            System.assertEquals(1, errors.size());
            System.assertEquals(0, EventPubSubTest.callableCounter);
        }
    }

    @IsTest
    private static void testConsumeCommitMissingData() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            callableCounter = 0;

            EventRegistry.EventDefinition def = new EventRegistry.EventDefinition(null);
            EventRegistry.Subscriber sub = new EventRegistry.Subscriber(CallMe.class);
            EventRegistry.registerTestEvent(def, sub);

            List<AS_Commit_Event__e> events = new List<AS_Commit_Event__e>();
            events.add(new AS_Commit_Event__e(
                Type__c = null,    
                Request_Id__c = 'poi5ed4wsxedrcftvgybhunijmko',    
                Payload__c = '{"option":1, "data":"asdfeasdbewa"}'
            ));
            events.add(new AS_Commit_Event__e(
                Type__c = '',    
                Request_Id__c = 'poi5ed4wsxedrcftvgybhunijmko',    
                Payload__c = '{"option":1, "data":"asdfeasdbewa"}'
            ));
            events.add(new AS_Commit_Event__e(
                Type__c = EventRegistry.RegisteredEvent.BANK_RECONCILIATION_COMPLETED_STATUS_CHANGE.name(),    
                Request_Id__c = null,    
                Payload__c = '{"option":1, "data":"asdfeasdbewa"}'
            ));
            events.add(new AS_Commit_Event__e(
                Type__c = EventRegistry.RegisteredEvent.BANK_RECONCILIATION_COMPLETED_STATUS_CHANGE.name(),    
                Request_Id__c = '',    
                Payload__c = '{"option":1, "data":"asdfeasdbewa"}'
            ));

            List<EventPubSub.ConsumerError> errors = EventPubSub.consume(events);

            System.assertEquals(4, errors.size());
            System.assertEquals(0, EventPubSubTest.callableCounter);
        }
    }

    @IsTest
    private static void testConsumeImmediateMissingData() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            callableCounter = 0;

            EventRegistry.EventDefinition def = new EventRegistry.EventDefinition(null);
            EventRegistry.Subscriber sub = new EventRegistry.Subscriber(CallMe.class);
            EventRegistry.registerTestEvent(def, sub);

            List<AS_Immediate_Event__e> events = new List<AS_Immediate_Event__e>();
            events.add(new AS_Immediate_Event__e(
                Type__c = null,    
                Request_Id__c = 'poi5ed4wsxedrcftvgybhunijmko',    
                Payload__c = '{"option":1, "data":"asdfeasdbewa"}'
            ));
            events.add(new AS_Immediate_Event__e(
                Type__c = '',    
                Request_Id__c = 'poi5ed4wsxedrcftvgybhunijmko',    
                Payload__c = '{"option":1, "data":"asdfeasdbewa"}'
            ));
            events.add(new AS_Immediate_Event__e(
                Type__c = EventRegistry.RegisteredEvent.BANK_RECONCILIATION_COMPLETED_STATUS_CHANGE.name(),    
                Request_Id__c = null,    
                Payload__c = '{"option":1, "data":"asdfeasdbewa"}'
            ));
            events.add(new AS_Immediate_Event__e(
                Type__c = EventRegistry.RegisteredEvent.BANK_RECONCILIATION_COMPLETED_STATUS_CHANGE.name(),    
                Request_Id__c = '',    
                Payload__c = '{"option":1, "data":"asdfeasdbewa"}'
            ));

            List<EventPubSub.ConsumerError> errors = EventPubSub.consume(events);

            System.assertEquals(4, errors.size());
            System.assertEquals(0, EventPubSubTest.callableCounter);
        }
    }

}