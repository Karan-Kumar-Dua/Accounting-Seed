/*
* Service Results returned from BDCService method calls
*/
global class BDCServiceResult {
    global Boolean isSuccess;
    global BDCDataModel data;
    global BDCError[] errors {get; set;}
    

    global BDCServiceResult(){}

    global BDCServiceResult(BDCDataModel data, Boolean isSuccess){
        this.data = data;
        this.isSuccess = isSuccess;
    }

    global BDCServiceResult(BDCDataModel data, Boolean isSuccess, BDCError[] errors){
        this.data = data;
        this.isSuccess = isSuccess;
        this.errors = errors;
    }

    global class BDCError {
        global Id id {get; set;}
        global String code {get; set;}
        global String detail {get; set;}
        
        global BDCError(){}
        
        public BDCError(String detail) {
            this.detail = detail;
        } 

        public BDCError(String code, String detail) {
            this.code = code;
            this.detail = detail;
        }

        public BDCError(Id id, String code, String detail) {
            this.id = id;
            this.code = code;
            this.detail = detail;
        }      
    }
}