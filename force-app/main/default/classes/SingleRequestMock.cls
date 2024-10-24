@IsTest
public class SingleRequestMock implements HttpCalloutMock {
    protected Integer code;
    protected String status;
    protected String bodyAsString;
    protected Blob bodyAsBlob;
    protected List<String> bodyValues;
    protected Map<String, String> responseHeaders;
    protected Integer calloutCounter;

    public SingleRequestMock(Integer code, String status, String body, Map<String, String> responseHeaders) {
        this.calloutCounter = 0;
        this.code = code;
        this.status = status;
        this.bodyAsString = body;
        this.bodyAsBlob = NULL;
        this.responseHeaders = responseHeaders;
    }

    public SingleRequestMock(Integer code, String status, List<String> bodyValues, Map<String, String> responseHeaders) {
        this.calloutCounter = 0;
        this.code = code;
        this.status = status;
        this.bodyAsString = bodyValues[0];
        this.bodyValues = bodyValues;
        this.bodyAsBlob = NULL;
        this.responseHeaders = responseHeaders;
    }

    public SingleRequestMock(Integer code, String status) {
        this.calloutCounter = 0;
        this.code = code;
        this.status = status;
    }

    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse resp = new HttpResponse();
        resp.setStatusCode(code);
        resp.setStatus(status);
        if (calloutCounter > 0 && bodyValues != NULL && bodyValues.size() > calloutCounter) {
            resp.setBody(bodyValues.get(calloutCounter));
        }
        else {
            if (bodyAsBlob != NULL) {
                resp.setBodyAsBlob(bodyAsBlob);
            } else if (bodyAsString != NULL) {
                resp.setBody(bodyAsString);
            }
            else {
                resp.setBody('');
            }
        }

        if (responseHeaders != NULL) {
            for (String key : responseHeaders.keySet()) {
                resp.setHeader(key, responseHeaders.get(key));
            }
        }
        calloutCounter++;
        return resp;
    }
}