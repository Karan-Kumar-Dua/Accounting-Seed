public with sharing class XDataService {

    @AuraEnabled
    public static List<sObject> query(String soql){
        return (soql != null  ? Database.query(soql) : null);
    }
    @AuraEnabled
    public static Integer getRecordsCount(String soql){
        return (soql != null  ? Database.countQuery(soql) : null);
    }
    @AuraEnabled
    public static UpsertInfo upsertData(String records,String recordsToDelete, String subqueryRelationshipApiName, String subgridParentApiName, String subgridDataToDelete){
        return upsertRecords(records,recordsToDelete,subqueryRelationshipApiName,subgridParentApiName,subgridDataToDelete);
    }
    private static UpsertInfo upsertRecords(String records,String recordsToDelete,String subqueryRelationshipApiName, String subgridParentApiName, String subgridDataToDelete){
        Map<String,String> recordErrors = new Map<String,String>();
        Map<String,String> successRecords = new Map<String,String>();
        Boolean hasError = false;
        UpsertInfo upsertDetails = new UpsertInfo();
    
        if(String.isBlank(records) == false && records != null ){
            List<RowKeys> rowKeys = (list<RowKeys>) JSON.deserialize(records, List<RowKeys>.class);
            List<sObject> recordSobjects = (list<sObject>) JSON.deserialize(records, List<sObject>.class);
            
            Map<String, Schema.SObjectField> fieldsToLabel;
            if (!recordSobjects.isEmpty()) {
                fieldsToLabel = recordSobjects[0].getSObjectType().getDescribe().fields.getMap();
            }
            List<Database.upsertResult> uResults = Database.upsert(recordSobjects,false);
            for(Integer i=0; i < uResults.size(); i++) {
                if(!uResults.get(i).isSuccess()) {
                    hasError = true;
                    String message = reduceErrors(uResults.get(i).getErrors(), fieldsToLabel);
                    recordErrors.put(rowKeys[i].rowKey, message);
                }else{
                    successRecords.put(uResults.get(i).getId(),rowKeys[i].rowKey);
                }
            }
            List<String> allChildRowKeys = getAllChildRowKeys(rowKeys,successRecords);

            upsertDetails = new UpsertInfo(hasError,recordErrors,recordSobjects,successRecords);

            if(!String.isBlank(subqueryRelationshipApiName)){
                upsertDetails = handleChildRecords(recordSobjects,subqueryRelationshipApiName,subgridParentApiName,upsertDetails,allChildRowKeys);
            }
        }
        if((subgridDataToDelete != null && subgridDataToDelete.length() > 2) ||  (recordsToDelete != null && recordsToDelete.length() > 2)){
            List<sObject> deleteableHeaders = (list<sObject>) JSON.deserialize(recordsToDelete, List<sObject>.class);
            deleteChildRelationships(deleteableHeaders,subqueryRelationshipApiName,subgridDataToDelete);
        }
        if(recordsToDelete != null && recordsToDelete.length() > 2 ){
            Database.delete((list<sObject>) JSON.deserialize(recordsToDelete, List<sObject>.class));
        }
        return upsertDetails;
    }
    private static UpsertInfo handleChildRecords(List<Sobject> recordSobjects, String subqueryRelationshipApiName,String subgridParentApiName,UpsertInfo upsertDetails,List<String> allChildRowKeys){
        List<Sobject> childRecords = new List<Sobject>();
        for(Sobject obj : recordSobjects){
            if(upsertDetails.successRecords.get(String.valueOf(obj.get('Id'))) != null && obj?.getSObjects(subqueryRelationshipApiName) != null){
                for(Sobject childObj : (List<SObject>)obj.getSObjects(subqueryRelationshipApiName)){
                    childObj.put(subgridParentApiName, obj.get('Id'));
                    childRecords.add(childObj);
                }
            }
        }
        if(!childRecords.isEmpty()){
            Map<String, Schema.SObjectField> fieldsToLabel;
            fieldsToLabel = childRecords[0].getSObjectType().getDescribe().fields.getMap();

            List<Database.upsertResult> uResults = Database.upsert(childRecords,false);
            for(Integer i=0; i < uResults.size(); i++) {
                if(!uResults.get(i).isSuccess()) {
                    upsertDetails.hasError = true;
                    String message = reduceErrors(uResults.get(i).getErrors(), fieldsToLabel);
                    upsertDetails.recordErrors.put(allChildRowKeys[i], message);
                }else{
                    upsertDetails.successRecords.put(uResults.get(i).getId(),allChildRowKeys[i]);
                }
            }
        }
        return upsertDetails;
    }
    private static void deleteChildRelationships(List<Sobject> recordSobjects, String subqueryRelationshipApiName,String subgridDataToDelete){
        List<Sobject> childRecords = new List<Sobject>();
        if(!String.isBlank(subqueryRelationshipApiName)){
            for(Sobject obj : recordSobjects){
                if(obj?.getSObjects(subqueryRelationshipApiName) != null){
                    childRecords.addAll((List<SObject>)obj.getSObjects(subqueryRelationshipApiName));
                }
            }
        }
        if(!String.isBlank(subgridDataToDelete)){
            childRecords.addAll((list<sObject>) JSON.deserialize(subgridDataToDelete, List<sObject>.class));
        }
        if(!childRecords.isEmpty()){
            Database.delete(childRecords);
        }
    }
    private static List<String> getAllChildRowKeys(List<RowKeys> rowKeys,Map<String,String> successRecords){
        Set<String> allSucceededRowKeys = new Set<String>();
        for(String successRowkey : successRecords.values()){
            allSucceededRowKeys.add(successRowkey);
        }
        List<String> childRowKeys = new List<String>();
        for(RowKeys rowKey : rowKeys){
            if(!String.isBlank(rowKey.childRowKeys) && allSucceededRowKeys.contains(rowKey.rowKey)){
                childRowKeys.addAll(rowKey.childRowKeys.split(','));
            }
        }
        return childRowKeys;
    }
    private static String reduceErrors(List<Database.Error> errors, Map<String, Schema.SObjectField> fieldsToLabel) {
        List<String> msgs = new List<String>();
        Set<String> requiredFields = new Set<String>();

        // inspect all errors
        System.StatusCode code;
        for(Database.Error err :  errors) {
            code = err.getStatusCode();  
            // collect database required fields
            if (code == System.StatusCode.REQUIRED_FIELD_MISSING) {
                requiredFields.addAll(err.getFields());
            // collect trigger required fields
            } else if (code == System.StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION 
                    && err.getMessage() == SObjectActions.REQUIRED_FIELD_ERROR) {
                requiredFields.addAll(err.getFields());
            // all other errors pass through normally
            } else {
                String msg = err.getMessage();
                // add period if missing
                msg += (msg.lastIndexOfIgnoreCase('.') != msg.length() - 1 ? '.' : '');
                msgs.add(msg);
            }
        }

        // combine required field errors into a single message
        if (!requiredFields.isEmpty()) {
            // convert field api names to labels
            List<String> requiredLabels = new List<String>();
            if (fieldsToLabel != null) {
                for (String field : requiredFields) {
                    String label = fieldsToLabel.get(field)?.getDescribe()?.getLabel();
                    if (String.isNotBlank(label)) {
                        requiredLabels.add('"' + label + '"');
                    } else {
                        requiredLabels.add(field);
                    }
                }
            } else {
                requiredLabels.addAll(requiredFields);
            }
            
            // construct message
            String msg = Label.REQUIRED_FIELDS_ARE_MISSING 
            + '. ['
            + String.join(requiredLabels, ', ')
            + ']';
            msgs.add(msg);
        }
        
        // combine messages
        return String.join(msgs, ' \n');
    }

    public class RowKeys{
        public String rowKey{get;set;}
        public String childRowKeys{get;set;}
    }
    public class UpsertInfo{
        @AuraEnabled
        public Boolean hasError{get;set;}
        @AuraEnabled
        public Map<String,String> recordErrors{get;set;}
        @AuraEnabled
        public Map<String,String> successRecords{get;set;}
        @AuraEnabled
        public List<sObject> records{get;set;}
        public UpsertInfo(Boolean hasError, Map<String,String> recErrors,List<sObject> records,Map<String,String> successRecords){
            this.hasError = hasError;
            this.recordErrors = recErrors;
            this.records = records;
            this.successRecords = successRecords;
        }
        public UpsertInfo(){
            this.hasError = false;
        }
    }
}