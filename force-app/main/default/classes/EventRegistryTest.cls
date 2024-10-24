@IsTest
public with sharing class EventRegistryTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testLookupSomeFound() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            EventRegistry.RegisteredEvent regEvent = EventRegistry.RegisteredEvent.BANK_RECONCILIATION_COMPLETED_STATUS_CHANGE;
            EventRegistry.EventDefinition def = EventRegistry.lookup(regEvent);
            System.assertNotEquals(null, def);
            System.assertEquals(regEvent, def.eventType);
        }
    }

    @IsTest
    private static void testLookupNoneFound() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            EventRegistry.RegisteredEvent regEvent = null;
            EventRegistry.EventDefinition def = EventRegistry.lookup(regEvent);
            System.assertEquals(null, def);
        }
    }

    @IsTest
    private static void testGetSubscriberSomeFound() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            EventRegistry.RegisteredEvent regEvent = EventRegistry.RegisteredEvent.BANK_RECONCILIATION_IN_PROGRESS_STATUS_CHANGE;
            EventRegistry.Subscriber sub = EventRegistry.getSubscriber(regEvent);
            System.assertNotEquals(null, sub);
            System.assertEquals(BankRecEventCallbacks.class, sub.type);
        }
    }

    @IsTest
    private static void testGetSubscriberNoneFound() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            EventRegistry.RegisteredEvent regEvent = null;
            EventRegistry.Subscriber sub = EventRegistry.getSubscriber(regEvent);
            System.assertEquals(null, sub);
        }
    }

    @IsTest
    private static void testGetRegisteredEventByNameSomeFound() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            EventRegistry.RegisteredEvent lookup = EventRegistry.RegisteredEvent.BANK_RECONCILIATION_COMPLETED_STATUS_CHANGE;
            EventRegistry.RegisteredEvent regEvent = EventRegistry.getRegisteredEventByName(lookup.name());
            System.assertEquals(lookup, regEvent);
        }
    }

    @IsTest
    private static void testGetRegisteredEventByNameNoneFound() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            String lookup = 'find_me';
            EventRegistry.RegisteredEvent regEvent = EventRegistry.getRegisteredEventByName(lookup);
            System.assertEquals(null, regEvent);
        }
    }

    @IsTest
    private static void testGetRegisteredEventByNameNullIn() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            String lookup = null;
            EventRegistry.RegisteredEvent regEvent = EventRegistry.getRegisteredEventByName(lookup);
            System.assertEquals(null, regEvent);
        }
    }

}