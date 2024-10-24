public with sharing class PaymentResult {

    public Boolean isSuccess {get; private set;}
    public String id {get; private set;}
    public List<PaymentResult.PaymentResultError> errors {get; private set;}

    public enum StatusCode {
        SYSTEM_EXCEPTION,
        NOT_POSTED,
        NON_VALID_TYPE,
        ALREADY_PAID,
        NO_QUALIFYING_RECORDS,
        NOT_SAME_CURRENCY,
        NON_VALID_ACCOUNTING_PERIOD,
        NON_VALID_AMOUNT,
        NO_REQUIRED_PROJECT_TASK,
        NOT_SAME_LEDGER,
        ON_HOLD_PAYABLE
    }

    //Constructor
    public PaymentResult(Boolean isSuccess, String id, List<PaymentResult.PaymentResultError> errors) {
        this.isSuccess = isSuccess;
        this.id = id;
        this.errors = errors;
    }

    //Inner class
    public with sharing class PaymentResultError {
        public StatusCode statusCode {get; private set;}
        public String message {get; private set;}

        public PaymentResultError(StatusCode statusCode, String message) {
            this.statusCode = statusCode;
            this.message = message;
        }
    }

}