global with sharing class RestResult {
    global Boolean isSuccess {get; private set;}
    global String id {get; private set;}
    global RestErrorResult[] errors {get; private set;}

    global RestResult(Boolean isSuccess, String id, RestErrorResult[] errors) {
        this.isSuccess = isSuccess;
        this.id = id;
        this.errors = errors;
    }
    
    global class RestErrorResult {
        global String statusCode {get; private set;}
        global String message {get; private set;}

        global RestErrorResult(String statusCode, String message) {
            this.statusCode = statusCode;
            this.message = message;
        }   
    }
}