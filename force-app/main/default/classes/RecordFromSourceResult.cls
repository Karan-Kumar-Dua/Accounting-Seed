public with sharing class RecordFromSourceResult {

    public Boolean isSuccess {get; private set;}
    public String id {get; private set;}
    public List<RecordFromSourceResult.RecordFromSourceResultError> errors {get; private set;}

    public enum StatusCode {
        SYSTEM_EXCEPTION,
        NO_ACCOUNT_ID,
        CLOSED_ACCOUNTING_PERIOD
    }

    //Constructor
    public RecordFromSourceResult(  Boolean isSuccess,
                                    String id,
                                    List<RecordFromSourceResult.RecordFromSourceResultError> errors) {

        this.isSuccess = isSuccess;
        this.id = id;
        this.errors = errors;
    }

    //Inner class
    public with sharing class RecordFromSourceResultError {

        public StatusCode statusCode {get; private set;}
        public String message {get; private set;}

        public RecordFromSourceResultError(StatusCode statusCode, String message) {
            this.statusCode = statusCode;
            this.message = message;
        }

    }

}