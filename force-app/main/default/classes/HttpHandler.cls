public with sharing class HttpHandler {

    @TestVisible
    public static HttpResponse get(String url, Map<String, String> headers) {
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        if (headers != null) {
            for (String k : headers.keySet()) {
                req.setHeader(k, headers.get(k));
            }
        }
        req.setEndpoint(url);
        req.setCompressed(true);
        req.setTimeout(120000);
        return h.send(req);
    }

    @TestVisible
    public static HttpResponse post(
        String url,
        Map<String, String> headers,
        String body
    ) {
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        try {
            req.setMethod('POST');
            if (headers != null) {
                for (String k : headers.keySet()) {
                    req.setHeader(k, headers.get(k));
                }
            }
            req.setEndpoint(url);
            req.setBody(body);
            req.setTimeout(120000);
        } catch (Exception ex) {
        }

        return h.send(req);
    }
}