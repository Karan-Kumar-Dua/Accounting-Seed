public with sharing abstract class AbstractLWCHelper {

    public static final Boolean IS_MULTI_CURRENCY_ENABLED = MultiCurrencyHandler.isMultiCurrencyEnabled;
    public static final String CORPORATE_CURRENCY = MultiCurrencyHandler.CORPORATE_CURRENCY;
    public static final Map<ExceptionCode,String> codeTranslations = new Map<ExceptionCode,String> {
        ExceptionCode.DML => 'DML',
        ExceptionCode.CRUD_FLS_WRITE => 'CRUD_FLS_WRITE',
        ExceptionCode.CRUD_FLS_READ => 'CRUD_FLS_READ',
        ExceptionCode.WRITE_CONFLICT => 'WRITE_CONFLICT',
        ExceptionCode.VALIDATION => 'VALIDATION',
        ExceptionCode.UNKNOWN => 'UNKNOWN'
    };
    public enum ExceptionCode { DML, CRUD_FLS_WRITE, CRUD_FLS_READ, WRITE_CONFLICT, VALIDATION, UNKNOWN }

    public static AuraHandledException buildException(ExceptionCode code, String msg) {
        ExceptionData data = new ExceptionData();
        data.code = codeTranslations.get(code);
        data.message = msg;
        String jsonData = JSON.serialize(data);
        AuraHandledException ex = new AuraHandledException(jsonData);
        ex.setMessage(jsonData);
        return ex;
    }

    public static Object deserialize(String jsonStr, Type t) {
        String s = String.isBlank(jsonStr) ? '{}' : jsonStr;
        return JSON.deserialize(s, t);
    }

    public static String getUrl(Id objectId) {
        return objectId != NULL ? '/lightning/r/' + objectId + '/view' : '';
    }

    public static Decimal convertNullToZero(Decimal value) {
        return value != null ? value : 0;
    }

    public static Decimal scaleHalfUp(Decimal value) {
        return value.setScale(2, System.RoundingMode.HALF_UP);
    }

    public static String getCurrencyIsoCode(SObject obj) {
        String result;
        if (IS_MULTI_CURRENCY_ENABLED) {
            result = (String) obj.get('CurrencyIsoCode');
        }
        else {
            result = MultiCurrencyHandler.CORPORATE_CURRENCY;
        }
        return result;
    }

    public class ExceptionData {
        public String code;
        public String message;
    }

    public with sharing class CustomSelectOption implements Comparable{
        @AuraEnabled
        public String value {get; set;}
        @AuraEnabled
        public String label {get; set;}

        public CustomSelectOption(SObject record) {
            this.value = record.Id;
            this.label = (String) record.get('Name');
        }

        public CustomSelectOption(String aId, String aName) {
            this.value = aId;
            this.label = aName;
        }

        public Integer compareTo(Object selectOption) {
            CustomSelectOption obj = (CustomSelectOption) selectOption;
            if (label == obj.label) { return 0; } 
            if (label > obj.label) { return 1; }
            return -1;        
        }
    }

    public virtual class SObjectData {
        @AuraEnabled
        public SObject obj;
        @AuraEnabled
        public String sobjType;
        @AuraEnabled
        public String recordURL;

        public SObjectData() {}
        public SObjectData(SObjectData cloneFrom) {
            this.obj = cloneFrom.obj.clone();
            this.sobjType = cloneFrom.sobjType;
            this.recordURL = cloneFrom.recordURL;
        }
    }

    public with sharing class SaveResponse {
        @AuraEnabled
        public List<ResponseResult> result;
        @AuraEnabled
        public Boolean isSuccess;
        @AuraEnabled
        public List<ResponseError> errors;

        public SaveResponse() {
            this.errors = new List<ResponseError>();
            this.result = new List<ResponseResult>();
        }

        public SaveResponse(ServiceResult serviceResult) {
            this.isSuccess = serviceResult.isSuccess;
            this.result = new List<ResponseResult>();
            setErrors(serviceResult.errors);
        }

        private void setErrors(List<ServiceResult.Error> serviceErrors) {
            this.errors = new List<ResponseError>();
            for (ServiceResult.Error error : serviceErrors) {
            this.errors.add(new ResponseError(error));
            }
        }
    }

    public with sharing class ResponseError {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String code;
        @AuraEnabled
        public String detail;

        public ResponseError(ServiceResult.Error resultError) {
            this.id = resultError.id;
            this.code = resultError.code;
            this.detail = resultError.detail;
        }
    }

    public with sharing class ResponseResult {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String detail;

        public ResponseResult(Id id, String name) {
            this.id = id;
            this.name = name;
        }
    }
}