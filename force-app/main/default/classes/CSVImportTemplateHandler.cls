public with sharing class CSVImportTemplateHandler {
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static Import_Template__c getImportTemplate(String recordId){
        List<String> queryFields = new List<String>{
            'ID', 'Detail__c', 'Headers__c', 'Parent__c', 'Name','Parent_Relationship__c'
        };
        String queryCondition = 'Id = \''+ recordId + '\'';

        SOQLBuilder theQuery = new SOQLBuilder(Import_Template__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);
        List<Import_Template__c> resultList =  (List<Import_Template__c>)Database.query(theQuery.toSOQL());

        if(resultList.size() == 0 ){ return null;}
        return resultList[0];
    }
    public static List<ImportTemplate> getImportTemplates(String detailObject, String parentObject){
        List<ImportTemplate> templates = new List<ImportTemplate>();
        List<String> queryFields = new List<String>{
            'ID', 'Detail__c', 'Headers__c', 'Parent__c', 'Name','Parent_Relationship__c'
        };
        String queryCondition = '(Parent__c = \''+ parentObject +
                             '\' AND Detail__c = \'' + detailObject + '\')  OR  (Parent__c = '+
                             'null AND Detail__c = \'' + detailObject + '\')';

        SOQLBuilder theQuery = new SOQLBuilder(Import_Template__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);
        
        for(Import_Template__c template :  (List<Import_Template__c>)Database.query(theQuery.toSOQL())){
            templates.add(new ImportTemplate(template.Name,template.id,template.Headers__c));
        }
        return templates;
    }
    public static CSVImportTemplateService.CSVFieldMapper getFieldMappings(Import_Template__c importTemplate){
        return CSVImportTemplateService.getFieldMappings(importTemplate);
    }

    public static List<ImportFields> getImportFields(String recordId, String[] columns, String childObj){
        List<String> queryFields = new List<String>{
            'ID', 'Detail__c'
        };
        String queryCondition = 'Id = \''+ recordId + '\'';
        List<String> subQueryFields = new List<String>{
            'ID', 'Column_Header__c', 'Target_Object__c', 'Target_Field__c', 'Name' ,
                        'Lookup_Type__c','Lookup_Field__c','Key_Field__c','Group_By__c' 
        };
       
        SOQLBuilder theQuery = new SOQLBuilder(Import_Template__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .subselectQuery(PACKAGE_QUALIFIER + 'Import_Fields__r', true)
            .setEnforceFLS(true)
            .selectFields(subQueryFields);

        List<Import_Template__c> importTemplates = (List<Import_Template__c>)Database.query(theQuery.toSOQL());

        List<ImportFields> ImportFieldMapper = new List<ImportFields>();
        if(importTemplates != null && importTemplates.size() > 0 && importTemplates[0].Import_Fields__r.size() > 0){
            for(Import_Field__c importField : importTemplates[0].Import_Fields__r){
                ImportFieldMapper.add(new ImportFields(importField,importTemplates[0]));
            }
        }else{
            for(String col : columns){
                ImportFieldMapper.add(new ImportFields(col,importTemplates[0],childObj));
            }
        }
        return ImportFieldMapper;
    }

    public static List<String> saveImportFields(String importFieldsString){
        List<ImportFields> importFields = (list<ImportFields>) JSON.deserialize(importFieldsString, List<ImportFields>.class);
        List<Import_Field__c> importFieldRecords = new List<Import_Field__c>();

        String importTemplateId = '';
        for(ImportFields record : importFields){
            if(record.parentId != null){
                importTemplateId = record.parentId;
                break;
            }
        }
        Import_Template__c parent = getImportTemplate(importTemplateId);
        for(ImportFields record : importFields){
            Import_Field__c importField = new Import_Field__c();
            if(parent?.Headers__c == true){
                importField.Column_Header__c = record.header;
            }else{
                importField.Column_Index__c =Integer.valueOf(record.header);
            }
            importField.Target_Object__c= record.targetObject;
            importField.Target_Field__c=record.targetField;
            importField.Lookup_Type__c=record.lookupType;
            importField.Lookup_Field__c=record.lookupField;
            importField.Group_By__c = record.groupBy == 'true' ? true : false;
            importField.Id = record.Id;
            if(record.Id == null){
                importField.Import_Template__c = record.parentId;
            }
            importFieldRecords.add(importField);
        }
        if(importFieldRecords.size() > 0){
            List<String> fieldsToCheck = new List<String>{
                'Column_Header__c','Column_Index__c','Target_Object__c','Target_Field__c','Lookup_Type__c','Lookup_Field__c','Group_By__c'
            };
            List<Database.upsertResult> uResults = SFDCSecurityUtils.upsertCheckCRUDAndFLS(importFieldRecords, fieldsToCheck,false);
            List<String> messages = new List<String>();
            for(Integer i=0; i < uResults.size(); i++) {
                if(!uResults.get(i).isSuccess()) {
                    messages.addAll(getErrorMessage(uResults,i));
                }
            }
            return messages;
        }
        return new List<String>();
    }
    public static List<Records> getRecordIds(String recordsToFetch){
        List<Records> records = (list<Records>) JSON.deserialize(recordsToFetch, List<Records>.class);
        List<Records> response = new List<Records>();
        Map<String,List<Records>> responseRecord = new Map<String,List<Records>>();

        for(Records record : records){
            List<Records> recs = new List<Records>();
            if(responseRecord.containsKey(record.targetField)){
                responseRecord.get(record.targetField).add(record);
            }else{
                recs.add(record);
                responseRecord.put(record.targetField,recs);
            }
        }
        for(String recordName : responseRecord.keySet()){
            List<Records> recs = responseRecord.get(recordName);
            Set<String> uniqueNames = new Set<String>();
            for(Records rec : recs){
                uniqueNames.add(rec.value);
            }
            List<String> queryFields = new List<String>{
                'ID', ''+recs[0].field
            };
            String queryCondition = ''+recs[0].field + ' IN :uniqueNames';
            SObjectType sObjType = ((SObject) Type.forName(recs[0].Name).newInstance()).getSObjectType();

            SOQLBuilder theQuery = new SOQLBuilder(sObjType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition);

            Set<String> processedNames = new Set<String>(); 
            for(SObject result : Database.query(theQuery.toSOQL())){
                processedNames.add(String.valueOf(result.get(recs[0].field)));
                response.add(new Records( recs[0].Name,recs[0].targetField,String.valueOf(result.get(recs[0].field)),String.valueOf(result.get('Id')),null));
            }
            if(processedNames.size() != uniqueNames.size()){
                for(String str : uniqueNames){
                    if(!processedNames.contains(str)){
                        String message = String.format(Label.CSV_RECORD_NOT_EXIST, new List<Object>{recs[0].targetField,recs[0].field,str});
                        response.add(new Records( recs[0].Name,recs[0].targetField,str,null,message));
                    }
                }
            }
        }
        return response;
    }
    public static Response importRecords(String recordsToImport){
        List<sObject> recordSobjects = (list<sObject>) JSON.deserialize(recordsToImport, List<sObject>.class);
        List<ParentRecord> parentInfo = new List<ParentRecord>();        
        List<RowKeys> rowKeys = (list<RowKeys>) JSON.deserialize(recordsToImport, List<RowKeys>.class);
        Map<String, Schema.SObjectField> fieldsToLabel;
        if (!recordSobjects.isEmpty()) {
            fieldsToLabel = recordSobjects[0].getSObjectType().getDescribe().fields.getMap();
        }
        List<SObject> rjels = getStrictObjects(recordSobjects);
        List<String> fieldList = getObjectFields(recordSobjects);
    
        List<Database.upsertResult> uResults = SFDCSecurityUtils.upsertCheckCRUDAndFLS(rjels,fieldList,false);
        
        Boolean hasError = false;
        for(Integer i=0; i < uResults.size(); i++) {
            String message = '';
            if(!uResults.get(i).isSuccess()) {
                message = reduceErrors(uResults.get(i).getErrors(), fieldsToLabel);
                hasError = true;
            }
            parentInfo.add( new ParentRecord(rowKeys[i].rowKey, String.valueOf(uResults.get(i).getId()) ,message));
        }
        return new Response(hasError,parentInfo);
    }
    private static List<SObject> getStrictObjects(List<SObject> recordSobjects){
        // dynamically populate list generic using string concatenation
        String name = recordSobjects[0].getSobjectType().getDescribe().getName();
        Type T = Type.forName('List<' + name + '>');

        // create a new instance based on the list type generic
        List<SObject> rjels = (List<SObject>) T.newInstance();
        // transfer all items to typed list
        rjels.addAll(recordSobjects);
        return rjels;
    }
    private static List<String> getObjectFields(List<SObject> recordSobjects){
        List<String> fieldList = new List<String>();
        String name = recordSobjects[0].getSobjectType().getDescribe().getName();
        Schema.DescribeSObjectResult DescribeSObjectResultObj = Schema.getGlobalDescribe().get(name).getDescribe();
        Schema.DescribeFieldResult describeResult;

        Map<String, Object> fieldsToValue = recordSobjects[0].getPopulatedFieldsAsMap();
        
        for(String fieldVal : fieldsToValue.keySet()){
            describeResult = DescribeSObjectResultObj.fields.getMap().get(fieldVal)?.getDescribe();
            if(describeResult.isPermissionable() && fieldVal != 'Id'){
                fieldList.add(fieldVal);
            }
        }
        return fieldList;
    }
    public static Response getParentUpdatedRecords(String recordsToFetch,String records){
        List<ParentRecord> parentInfo = new List<ParentRecord>();
        List<sObject> recordSobjects = (list<sObject>) JSON.deserialize(records, List<sObject>.class);
        List<Records> recordCls = (list<Records>) JSON.deserialize(recordsToFetch, List<Records>.class);
        Set<String> values = new Set<String>();
        Map<String,sObject> recordSobjectsMap = new Map<String,sObject>();

        Map<String, Schema.SObjectField> fieldsToLabel;
        if (!recordSobjects.isEmpty()) {
            fieldsToLabel = recordSobjects[0].getSObjectType().getDescribe().fields.getMap();
        }

        for(sObject objInner : recordSobjects){
            recordSobjectsMap.put(String.valueOf(objInner.get(recordCls[0].targetField)),objInner);
        }
        recordSobjects = recordSobjectsMap.values();
        for(Records rec : recordCls ){
            values.add(rec.value);
        }

        List<String> queryFields = new List<String>{
            'ID', ''+recordCls[0].targetField 
        };
        String queryCondition = ''+ recordCls[0].targetField + ' IN :values';
        SObjectType sObjType = ((SObject) Type.forName(recordCls[0].Name).newInstance())
                                  .getSObjectType();

        SOQLBuilder theQuery = new SOQLBuilder(sObjType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        List<SObject> result = Database.query(theQuery.toSOQL());
        
        for(sObject obj : result){
            for(sObject objInner : recordSobjects){
                if(obj.get(recordCls[0].targetField) == objInner.get(recordCls[0].targetField)){
                    objInner.put('Id',obj.get('Id'));
                    continue;
                }
            }
        }
        Map<String,sObject> uniqueRecords = new Map<String,sObject>();
        
        Integer pos = 0;
        for(sObject objInner : recordSobjects){
            if((Id)objInner.get('Id') == null){
                uniqueRecords.put(String.valueOf(pos),objInner);
            }
            else if(!uniqueRecords.containsKey(String.valueOf(objInner.get('Id')))){
                uniqueRecords.put(String.valueOf(objInner.get('Id')),objInner);
            }
            pos++;
        }
        List<SObject> rjels = getStrictObjects(uniqueRecords.values());
        List<String> fieldList = getObjectFields(uniqueRecords.values());

        List<Database.upsertResult> uResults = SFDCSecurityUtils.upsertCheckCRUDAndFLS(rjels,fieldList,false);
        Boolean hasError = false; 
        for(Integer i=0; i < uResults.size(); i++) {
            String message = '';
            if(!uResults.get(i).isSuccess()) {
                message = reduceErrors(uResults.get(i).getErrors(), fieldsToLabel);
                hasError = true;
            }
            String key = uniqueRecords.containsKey(String.valueOf(uResults.get(i).getId())) ? String.valueOf(uniqueRecords.get(String.valueOf(uResults.get(i).getId())).get(recordCls[0].targetField)) : String.valueOf(uniqueRecords.get(String.valueOf(i)).get(recordCls[0].targetField));
            parentInfo.add( new ParentRecord(key, String.valueOf(uResults.get(i).getId()) ,message));
        }
        return new Response(hasError,parentInfo);
    }
    private static List<String> getErrorMessage(List<Database.upsertResult> uResults,Integer i){
        List<String> messages = new List<String>();
        String dotChar = '.';
        for(Database.Error error :  uResults.get(i).getErrors()){
            messages.add(
                    error.message +
                            (error.message.lastIndexOfIgnoreCase(dotChar) != error.message.length() - 1 ? dotChar : '')
            );
        }
        return messages;
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
    public class Response{
        @AuraEnabled
        public Boolean hasError;
        @AuraEnabled
        public List<ParentRecord> data;
        public Response(Boolean hasError, List<ParentRecord> data){
            this.hasError = hasError;
            this.data = data;
        }
    }
    public class ParentRecord{
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String message;
        public ParentRecord(String name,String id, String message){
            this.name = name;
            this.id = id;
            this.message = message;
        }
    }
    public class RowKeys{
        public String rowKey{get;set;}
    }
    public class Records{
        @AuraEnabled
        public String name{get;set;}
        @AuraEnabled
        public String field{get;set;}
        @AuraEnabled
        public String value{get;set;}
        @AuraEnabled
        public String targetField{get;set;}
        @AuraEnabled
        public String id{get;set;}
        @AuraEnabled
        public String errorMessage{get;set;}
        public Records(){}
        public Records(String name,String targetField,String value,String id,String errorMessage){
            this.name = name;
            this.targetField = targetField;
            this.value = value;
            this.id = id;
            this.errorMessage = errorMessage;
        }
    }
    public class ImportFields{
        @AuraEnabled
        public String header;
        @AuraEnabled
        public String objectName;
        @AuraEnabled
        public String parentId;
        @AuraEnabled
        public String targetObject;
        @AuraEnabled
        public String targetField;
        @AuraEnabled
        public String lookupType;
        @AuraEnabled
        public String lookupField;
        @AuraEnabled
        public String keyField;
        @AuraEnabled
        public String groupBy;
        @AuraEnabled
        public String id;
        @AuraEnabled
        public Boolean hasFields;
        public ImportFields(){}
        public ImportFields(String header,Import_Template__c template,String childObj){
            this.objectName = template?.Detail__c;
            this.parentId = template.Id;
            this.targetObject = childObj;
            this.header = header;
            this.hasFields = false;
        }
        public ImportFields(Import_Field__c importField, Import_Template__c template){
            this.id = importField.id;
            this.objectName = template.Detail__c;
            this.parentId = template.Id;
            this.header = importField.Column_Header__c;
            this.targetObject = importField.Target_Object__c;
            this.targetField = importField.Target_Field__c;
            this.lookupType = importField.Lookup_Type__c;
            this.lookupField = importField.Lookup_Field__c;
            this.keyField = importField.Key_Field__c;
            this.groupBy = importField.Group_By__c == true ? 'true' : 'false';
        }
    }
    public class ImportTemplate{
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String parent;
        @AuraEnabled
        public String detail;
        @AuraEnabled
        public Boolean hasHeaders;
        @AuraEnabled
        public String parentRelationship;
        public ImportTemplate(){}
        public ImportTemplate(String name,String id,Boolean hasHeaders){
            this.name = name;
            this.id = id;
            this.hasHeaders = hasHeaders;
        }
        public ImportTemplate(Import_Template__c temp){
            this.name = temp.Name;
            this.id = temp.id;
            this.parent = temp.Parent__c;
            this.detail = temp.Detail__c;
            this.hasHeaders = temp.Headers__c;
            this.parentRelationship = temp.Parent_Relationship__c;
        }
    }
}