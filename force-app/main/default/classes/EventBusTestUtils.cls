@IsTest
public with sharing class EventBusTestUtils {
    
    private static String[] allASTopics = new String[] {
        AS_Commit_Event__e.SObjectType.getDescribe().getName(),
        AS_Immediate_Event__e.SObjectType.getDescribe().getName()
    };

    /**
     * Get platform events published to EventBus by `EventPubSub::publish`.
     * These events may or may not have been delivered.
     */
    public static List<SObject> getPublishedEvents() {
        return EventPubSub.publishedPlatformEvents;
    }

    public static void deliverAllEvents() {
        Integer maxDeliveries = 10; //circuit breaker

        Map<String,Integer> positionsByTopic = new Map<String,Integer>();
        for (String topic : allASTopics) {
            positionsByTopic.put(topic, -1);
        }
        // get starting positions for all topics
        positionsByTopic = getTopicsWithUpdatedPos(positionsByTopic);
 
        // deliver messages until positions no longer update
        while (positionsByTopic.size() > 0 && maxDeliveries > 0) {
            Test.getEventBus().deliver();   // deliver next message on bus
            maxDeliveries --;               // decrease max deliveries counter
            positionsByTopic = getTopicsWithUpdatedPos(positionsByTopic);
        }
    }

    private static Map<String,Integer> getTopicsWithUpdatedPos(Map<String,Integer> posByTopic) {
        Map<String,Integer> result = new Map<String,Integer>();
        if (posByTopic == null || posByTopic.size() < 1) {
            return result;
        }

        List<String> topicClauses = new List<String>();
        for (String topic : posByTopic.keySet()) {
            topicClauses.add('(Topic = \'' + topic + '\' AND Position > ' + posByTopic.get(topic) + ') '); 
        }
        String topicClause = String.join(topicClauses, 'OR ');

        String q = 
            'SELECT Position, Topic ' + 
            'FROM EventBusSubscriber ' +
            'WHERE Type = \'ApexTrigger\' ' +
            'AND (' + topicClause + ')';

        List<EventBusSubscriber> subs = (List<EventBusSubscriber>) Database.query(q);
        for (EventBusSubscriber sub : subs) {
            result.put(sub.Topic, sub.Position);
        }
        return result;
    }

}