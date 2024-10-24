@RestResource(urlMapping='/v1.0/billing/post/*')
global with sharing class BillingPostRestResource {

    @HttpPut
    global static RestResult doBillingsPostCreate() {
        RestRequest req = RestContext.request;
        String billingId = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);
        AbstractPostHandler.validateInputData(new List<String>{billingId});

        AbstractPostHandler postHandler = new BillingPostHandler();
        List<PostResult> postResults = postHandler.post(new List<String>{billingId});
        return convertPostResultsToRestResults(postResults)[0];
    }

    @HttpDelete
    global static RestResult doBillingsPostDelete() {
        RestRequest req = RestContext.request;
        String billingId = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);
        AbstractPostHandler.validateInputData(new List<String>{billingId});

        AbstractPostHandler postHandler = new BillingPostHandler();
        List<PostResult> unpostResults = postHandler.unpost(new List<String>{billingId});
        return convertPostResultsToRestResults(unpostResults)[0];
    }

    private static List<RestResult> convertPostResultsToRestResults(List<PostResult> postResults) {
        List<RestResult> results = new List<RestResult>();
        for (PostResult postResult : postResults) {
            List<RestResult.RestErrorResult> restErrorResults = new List<RestResult.RestErrorResult>();

            if (postResult.errors != NULL) {
                for (PostResult.PostErrorResult postErrorResult : postResult.errors) {
                    RestResult.RestErrorResult tempRestErrorResult =
                        new RestResult.RestErrorResult(postErrorResult.statusCode.name(), postErrorResult.message);

                    restErrorResults.add(tempRestErrorResult);
                }
            }

            RestResult tempRestResult = new RestResult(postResult.isSuccess, postResult.id, restErrorResults);
            results.add(tempRestResult);
        }

        return results;
    }

}