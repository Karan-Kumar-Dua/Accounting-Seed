/**
 * Proxy class for the standard library Http class.
 * 
 * This proxy allows http requests to be modified before being sent.
 */
public with sharing class HttpProxy {

    private static List<HttpCalloutMock> mockReponses;

   /** 
    * When setting http mocks using the traditional approach in
    * unit tests we lose the flexibility to perform DML before the
    * mocked callout. This class will remove that barrier allowing
    * placement of Test.startTest() methods earlier in the test method
    * to avoid governor limits when setting up test data.
    */
    public static void setMock(HttpCalloutMock mock) {
        if (mockReponses == null) {
            mockReponses = new List<HttpCalloutMock>();
        }
        mockReponses.add(mock);
    }

    /**
     * If a test is running and a mock is available, return the mock response. 
     * Otherwise, send the request as normal.
     */
    public static HttpResponse send(Http client, HTTPRequest req) {
        if (Test.isRunningTest() && mockReponses != null && !mockReponses.isEmpty()) {
            return mockReponses.remove(0).respond(req);
        }
        return client.send(req);
    }

}