global with sharing class ServiceResult {
    global Boolean isSuccess {get; set;}
    global String data {get; set;}
    global Error[] errors {get; set;}
    global ServiceResult[] results {get; set;}

    public ServiceResult() {
        results = new List<ServiceResult>();
        errors = new List<Error>();
    }

    public ServiceResult(String data, Boolean isSuccess) {
        this();
        this.isSuccess = isSuccess;
        this.data = data;
    }

    public ServiceResult(String data, Boolean isSuccess, Error[] errors) {
        this.isSuccess = isSuccess;
        this.data = data;
        this.errors = errors;
        results = new List<ServiceResult>();
    }

    public ServiceResult(String data, Boolean isSuccess, Error[] errors, ServiceResult[] results) {
        this.isSuccess = isSuccess;
        this.data = data;
        this.errors = errors;
        this.results = results;
    }

    public ServiceResult(String data, String statusCode, String errorMsg) {
        this(data,false);
        this.errors.add(new ServiceResult.Error(statusCode, errorMsg));
    }

    global class Error {
        global Id id {get; set;}
        global String code {get; set;}
        global String detail {get; set;}
        
        global Error(){}
        
        public Error(String detail) {
            this.detail = detail;
        } 

        public Error(String code, String detail) {
            this.code = code;
            this.detail = detail;
        }

        public Error(Id id, String code, String detail) {
            this.id = id;
            this.code = code;
            this.detail = detail;
        }      
    }
}