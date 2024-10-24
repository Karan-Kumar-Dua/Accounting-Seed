global with sharing class AwsServiceResult {
 
    global Boolean isSuccess;
    global AwsError error {get; set;}
    

    global AwsServiceResult(){}

    global AwsServiceResult(Boolean isSuccess){
        this.isSuccess = isSuccess;
    }

    global AwsServiceResult(Boolean isSuccess, AwsError error){
        this.isSuccess = isSuccess;
        this.error = error;
    }

    global class AwsError {
        global String requestId {get; set;}
        global String code {get; set;}
        global String message {get; set;}
        
        global AwsError(){}
        
        public AwsError(String message) {
            this.message = message;
        } 

        public AwsError(String code, String message) {
            this.code = code;
            this.message = message;
        }

        public AwsError(String requestId, String code, String message) {
            this.requestId = requestId;
            this.code = code;
            this.message = message;
        }      
    }
}