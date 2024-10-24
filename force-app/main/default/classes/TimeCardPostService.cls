global with sharing class TimeCardPostService {

    global static List<PostResult> postTimeCards(List<Time_Card__c> timeCards) {
        AbstractPostHandler postHandler = new TimeCardPostHandler();
        return postHandler.post(timeCards);
    }
    global static List<PostResult> unpostTimeCards(List<Time_Card__c> timeCards) {
        AbstractPostHandler postHandler = new TimeCardPostHandler();
        return postHandler.unpost(timeCards);
    }

}