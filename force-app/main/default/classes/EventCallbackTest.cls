@IsTest
public with sharing class EventCallbackTest {
    private static Boolean callableCalled = false;
    private static String callableAction;
    private static Map<String, Object> callableArgs;

    public class CallMe implements Callable {
        public Object call(String action, Map<String, Object> args) {
            EventCallbackTest.callableCalled = true;
            EventCallbackTest.callableAction = action;
            EventCallbackTest.callableArgs = args;
            return null;
        }
    }

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testConstructorWithNullInput() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            Exception expectedEx;
            try {
                new EventCallback(null);
            } catch (EventCallback.InvalidInputException ex) {
                expectedEx = ex;
            }
            System.assertNotEquals(null, expectedEx);
        }
    }

    @IsTest
    private static void testConstructorWithNonCallable() {
        User theUser = TestDataSuite.getInstance().users.get(1);

        System.runAs(theUser) {
            EventRegistry.EventDefinition def = new EventRegistry.EventDefinition(null);
            EventRegistry.Subscriber sub = new EventRegistry.Subscriber(String.class);
            EventRegistry.registerTestEvent(def, sub);

            Exception expectedEx;
            try {
                new EventCallback(def);
            } catch (EventCallback.NonCallableTypeException ex) {
                expectedEx = ex;
            }
            System.assertNotEquals(null, expectedEx);
        }
    }

    @IsTest
    private static void testCall() {
        User theUser = TestDataSuite.getInstance().users.get(1);
        callableCalled = false;
        callableAction = null;
        callableArgs = null;

        System.runAs(theUser) {
            EventRegistry.EventDefinition def = new EventRegistry.EventDefinition(null);
            EventRegistry.Subscriber sub = new EventRegistry.Subscriber(CallMe.class);
            EventRegistry.registerTestEvent(def, sub);

            EventCallback callback = new EventCallback(def);
            ImmediateEvent event = new ImmediateEvent(
                EventRegistry.RegisteredEvent.BANK_RECONCILIATION_COMPLETED_STATUS_CHANGE,
                'test',
                null
            );
            callback.call(new Consumable[]{event});

            System.assert(callableCalled);
            System.assertEquals(
                EventRegistry.RegisteredEvent.BANK_RECONCILIATION_COMPLETED_STATUS_CHANGE.name(), 
                callableAction
            );
            System.assertEquals(1, ((Consumable[]) callableArgs.get('events')).size());
        }
    }

    @IsTest
    private static void testCallWithNoSubscriber() {
        User theUser = TestDataSuite.getInstance().users.get(1);
        callableCalled = false;
        callableAction = null;
        callableArgs = null;

        System.runAs(theUser) {
            EventRegistry.EventDefinition def = new EventRegistry.EventDefinition(null);
            EventRegistry.registerTestEvent(def, null);

            EventCallback callback = new EventCallback(def);
            ImmediateEvent event = new ImmediateEvent(
                EventRegistry.RegisteredEvent.BANK_RECONCILIATION_COMPLETED_STATUS_CHANGE,
                'test',
                null
            );
            callback.call(new Consumable[]{event});

            System.assert(!callableCalled);
        }
    }

}