@IsTest
public with sharing class CommitEventTest {
    
    public class MockPayload {
        public String value = 'value';
    }

    public class MockCallback implements Callable {
        public Object call(String action, Map<String, Object> args) {
            return null;
        }
    }

    private static void registerMockEvent() {
        EventRegistry.EventDefinition def = new EventRegistry.EventDefinition(MockPayload.class);
        EventRegistry.Subscriber sub = new EventRegistry.Subscriber(MockCallback.class);
        EventRegistry.registerTestEvent(def, sub);
    }

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
        registerMockEvent();
    }

    @IsTest
    private static void testGetId() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            registerMockEvent();
            String eventId = 'test_id';
            CommitEvent event = new CommitEvent(
                EventRegistry.RegisteredEvent.BANK_RECONCILIATION_COMPLETED_STATUS_CHANGE, 
                eventId, 
                new MockPayload()
            );
            System.assertEquals(eventId, event.getId());
        }
    }

    @IsTest
    private static void testGetPayload() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            registerMockEvent();
            CommitEvent event = new CommitEvent(
                EventRegistry.RegisteredEvent.BANK_RECONCILIATION_COMPLETED_STATUS_CHANGE, 
                'test_id', 
                new MockPayload()
            );
            MockPayload payload = (MockPayload) event.getPayload();
            System.assertEquals('value', payload.value);
        }
    }

    @IsTest
    private static void testGetType() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            registerMockEvent();
            EventRegistry.RegisteredEvent regEvent = EventRegistry.RegisteredEvent.BANK_RECONCILIATION_COMPLETED_STATUS_CHANGE;
            CommitEvent event = new CommitEvent(
                regEvent, 
                'test_id', 
                null
            );
            System.assertEquals(regEvent, event.getType());
        }
    }

    @IsTest
    private static void testGetCallback() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            registerMockEvent();
            CommitEvent event = new CommitEvent(
                EventRegistry.RegisteredEvent.BANK_RECONCILIATION_COMPLETED_STATUS_CHANGE, 
                'test_id', 
                new MockPayload()
            );
            System.assertNotEquals(null, event.getCallback());
        }
    }

    @IsTest
    private static void testToPlatformEvent() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            registerMockEvent();
            EventRegistry.RegisteredEvent regEvent = EventRegistry.RegisteredEvent.BANK_RECONCILIATION_COMPLETED_STATUS_CHANGE;
            MockPayload payload = new MockPayload();
            CommitEvent event = new CommitEvent(
                regEvent, 
                'test_id', 
                payload
            );
            AS_Commit_Event__e platformEvent = (AS_Commit_Event__e) event.toPlatformEvent();
            System.assertEquals(regEvent.name(), platformEvent.Type__c);
            System.assertEquals('test_id', platformEvent.Request_Id__c);
            System.assertEquals(JSON.serialize(payload), platformEvent.Payload__c);
        }
    }

}