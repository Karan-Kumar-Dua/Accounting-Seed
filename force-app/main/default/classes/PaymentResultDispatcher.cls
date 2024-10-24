public with sharing class PaymentResultDispatcher {

    private Map<String, PaymentResult> theResultsMap;

    public String BLOCKER_ERROR_KEY {
        public get {
            return 'generalError';
        }
        private set;
    }

    public PaymentResultDispatcher() {
        this.theResultsMap = new Map<String, PaymentResult>();
    }

    /*
    Id parameter can contain SF Record Id or BLOCKER_ERROR_KEY identifier
     */
    public void addPaymentErrorResult(String id, PaymentResult.PaymentResultError theErrorResult) {
        if (theResultsMap.containsKey(id)) {
            theResultsMap
                .get(id)
                .errors
                .add(theErrorResult);
        }
        else {
            theResultsMap.put(
                id,
                new PaymentResult(
                    false,
                    id,
                    new List<PaymentResult.PaymentResultError>{
                        theErrorResult
                    }
                )
            );
        }
    }

    public void addPaymentResult(String id, PaymentResult paymentResult) {
        this.theResultsMap.put(id, paymentResult);
    }

    public List<PaymentResult> getPaymentResults() {
        return theResultsMap.values();
    }

    public Map<String, PaymentResult> getPaymentResultsMap() {
        return theResultsMap;
    }

    public Boolean isGeneralErrorExists() {
        if (theResultsMap.containsKey(BLOCKER_ERROR_KEY)) {
            return true;
        }
        else {
            return false;
        }
    }

    public PaymentResult getGeneralErrorResult() {
        return theResultsMap.get(BLOCKER_ERROR_KEY);
    }

    public void clearResultsMap() {
        theResultsMap.clear();
    }

}