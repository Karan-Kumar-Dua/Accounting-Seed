@IsTest
public class MultiRequestMock implements HttpCalloutMock {
    private Map<String, HttpCalloutMock> requests;

    public MultiRequestMock(Map<String, HttpCalloutMock> requests) {
        this.requests = requests;
    }

    public HTTPResponse respond(HTTPRequest req) {
        HttpCalloutMock mock = requests.get(req.getEndpoint());
        if (mock != NULL) {
            return mock.respond(req);
        } else {
            throw new CustomCalloutException(Label.INF_HTTP_CALLOUT_NOT_SUPPORTED_TEST_METHODS);
        }
    }

    public void addRequestMock(String url, HttpCalloutMock mock) {
        requests.put(url, mock);
    }

    public class CustomCalloutException extends Exception {}

}