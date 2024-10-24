public without sharing class FieldSetHandler {
    public static final String HYPERLINK = 'HYPERLINK'; 
    public static final String IMAGE = 'IMAGE'; 
    public static final String REFERENCE = 'REFERENCE'; 
    private static final String DEFAULT_SORT_ORDER = 'ASC';
    public static Map<String, String> nameFieldsBySObjects = new Map<String, String>();

    public String sObjectName {get; set;}
    public string subgridSobjectName {get;set;}
    public String childWithParentReference {get; set;}

    public FieldSetResponse response;
    public FieldSetHandler(){}
    public FieldSetHandler(FieldSetRequest fsRequest) {

        if(fsRequest.sObjectName == '' ||  fsRequest.mainFieldSetName == null){return;}

        this.childWithParentReference = fsRequest.sObjectName;
        this.subgridSobjectName = fsRequest.subquerySObjectName;
        this.sObjectName = fsRequest.sObjectName.substringBefore('.');
        //get the sobject by name
        Schema.DescribeSObjectResult DescribeSObjectResultObj = getObjectSchemaDescribe(this.sObjectName);
        
        //instantiate the return
        this.response = new FieldSetResponse();
        //get fieldSets
        Schema.FieldSet fieldSetObj = DescribeSObjectResultObj.fieldsets.getMap().get(fsRequest.mainFieldSetName);
        
        FieldSetProcessorReturnType fsprt;
        if(fsRequest.reOrderFieldName != ''){
            Schema.DescribeFieldResult describeResult = DescribeSObjectResultObj.fields.getMap().get(fsRequest.reOrderFieldName)?.getDescribe();

            if(describeResult != null){
                fsprt = prepareFieldCols(describeResult,new FieldSetProcessorReturnType(),null);
                this.response.rowNumberColumn = fsprt.colDefs.values()[0];
                this.response.fieldNames.addAll(fsprt.colNames);
            }
        }
        
        fsprt = processFieldSet(fieldSetObj);
        this.response.mainColumns.addAll(fsprt.colDefs.values());
        this.response.fieldNames.addAll(fsprt.colNames);

        if (!String.isEmpty(fsRequest.extraFieldSetName)){
            Schema.FieldSet extraFieldSetObj = DescribeSObjectResultObj.fieldsets.getMap().get(fsRequest.extraFieldSetName);
            fsprt = processFieldSet(extraFieldSetObj);
            this.response.extraColumns = fsprt.colDefs.values();
            this.response.fieldNames.addAll(fsprt.colNames);
        } 
        fsprt = processRequiredFields(DescribeSObjectResultObj,fsRequest.sObjectName);
        this.response.requiredColumns = fsprt.colDefs.values();
        this.response.fieldNames.addAll(fsprt.colNames);

        //handle subgrid column and fields
        fsprt =  getSubGridColumns(fsRequest);
        if(fsprt != null){
            this.subgridSobjectName = fsRequest.subquerySObjectName;
            this.response.subGridColumns = fsprt.colDefs.values();
            this.response.subGridFieldNames = new Set<String>(fsprt.colNames);
            this.response.subqueryRelationshipName = fsRequest.subqueryRelationshipName.endsWithIgnoreCase('__c') ? 
                    fsRequest.subqueryRelationshipName.replaceAll('__c','__r') : fsRequest.subqueryRelationshipName;
            this.response.subgridParentApiName = getSubgridParentApiName(fsRequest.subquerySObjectName);
        }
    }
    private String getSubgridParentApiName(String subGridObjectName){
        Map<String, Schema.SObjectField> fieldsSchema = Schema.getGlobalDescribe().get(subGridObjectName).getDescribe().fields.getMap();
        for(String fieldName : fieldsSchema.keySet())
        {
            Schema.DescribeFieldResult field = fieldsSchema.get(fieldName).getDescribe();
            if(String.valueOf(field.getType()) == REFERENCE && 
                field.getSObjectField().getDescribe().getReferenceTo()[0].getDescribe().getName() == this.sObjectName){
                return field.getName();
            }
        }
        return '';

    }
    /**
     * Fetch schema describe to get the columns and fields
     * param : sObjectName : object for which coulumn is required
     * return : Schema.DescribeSObjectResult : object schema
     */
    private Schema.DescribeSObjectResult getObjectSchemaDescribe(String sObjectName){
        Schema.SObjectType sObjectTypeObj = Schema.getGlobalDescribe().get(sObjectName);
        return sObjectTypeObj.getDescribe();
    }
    /**
     * method to prepare columns for sub grid and combine that with the response
     * param : fsRequest : containing information about the subquery object
     * return : FieldSetProcessorReturnType : containing information about the columns and fields
     */
    private FieldSetProcessorReturnType getSubGridColumns(FieldSetRequest fsRequest){
        if(!String.isEmpty(fsRequest.subquerySObjectName) && fsRequest.subquerySObjectName != '' && 
            !String.isEmpty(fsRequest.subqueryRelationshipFieldset) && fsRequest.subqueryRelationshipFieldset != ''){
            //get the sobject by name
            Schema.DescribeSObjectResult DescribeSObjectResultObj = getObjectSchemaDescribe(fsRequest.subquerySObjectName); 
            Schema.FieldSet fieldSetObj = DescribeSObjectResultObj.fieldsets.getMap().get(fsRequest.subqueryRelationshipFieldset);
            return processFieldSet(fieldSetObj);
        }
        return null;
    }
    /**
     * this will query all the records that matches the filter logic including all the subgrid rows if any
     * param : filter : filter criteria
     * return : String : dynamic query string
     */
    public String createQueryString(FieldSetRequest fsRequest) {
        if(this.response == null){return null;}
        String fields = '';
        for (String f : this.response.fieldNames) {
            fields += (fields == ''?'' : ', ') + f;
        }
        String subGridQuery = getSubGridQuery();
        if(!String.isBlank(subGridQuery)){
            fields = fields + ', ';
        }
        String orderBy = fsRequest.orderByField != null && fsRequest.orderByField != '' ? ' ORDER BY ' + fsRequest.orderByField + ' ' + (fsRequest.orderByDir != null ? fsRequest.orderByDir : DEFAULT_SORT_ORDER) : '';
        String condition = ' WHERE '+this.childWithParentReference.substringAfter('.') + ' = \''+fsRequest.filter+'\'';
        String limitCondition = fsRequest.recordsLimit != null && fsRequest.recordsLimit != '' ? ' LIMIT ' + fsRequest.recordsLimit : '';
        return String.format('SELECT {0} {1} FROM {2} {3} WITH SECURITY_ENFORCED {4} {5}', new String[]{fields, subGridQuery,this.sObjectName, condition,orderBy,limitCondition});
    }
    /**
     * this will query the count of all records for a parent
     * param : fsRequest : request parameter
     * return : String : dynamic count query string
     */
    public String getCountQueryString(FieldSetRequest fsRequest){
        if(this.response == null){return null;}
        String condition = ' WHERE '+this.childWithParentReference.substringAfter('.') + ' = \''+fsRequest.filter+'\'';
        return String.format('SELECT Count() FROM {0} {1} WITH SECURITY_ENFORCED', new String[]{this.sObjectName, condition});
    }
    /**
     * prepare the sub grid query for sub grid records
     * return : String : formatted string  
     */
    private String getSubGridQuery(){
        String subGridQuery = '';
        if(!this.response.subGridFieldNames.isEmpty() && !String.isBlank(this.response.subqueryRelationshipName)){
            String subGridFields = '';
            for (String f : this.response.subGridFieldNames) {
                subGridFields += (subGridFields == ''?'' : ', ') + f;
            }
            subGridQuery = String.format('(SELECT {0} FROM {1})', new String[]{subGridFields,this.response.subqueryRelationshipName});
        }
        return subGridQuery;
    }
    private FieldSetProcessorReturnType processRequiredFields(Schema.DescribeSObjectResult desResult,String sObjectName){
        FieldSetProcessorReturnType retVal = new FieldSetProcessorReturnType();
        Map<String,Schema.SObjectField> fields = desResult.fields.getMap();
        for(String field : fields.keySet()) {
            Schema.DescribeFieldResult describeResult = fields.get(field).getDescribe();
            if(describeResult.getName() == sObjectName.substringAfter('.')){
                retVal = prepareFieldCols(describeResult,retVal,null);
            }
        }
        return retVal;
    }
    private FieldSetProcessorReturnType processFieldSet(Schema.FieldSet fieldSetObj) {
        FieldSetProcessorReturnType retVal = new FieldSetProcessorReturnType();
        for (Schema.FieldSetMember eachFieldSetMember : fieldSetObj.getFields()) {
            Schema.DescribeFieldResult dfr = eachFieldSetMember.getSObjectField().getDescribe();
            retVal = prepareFieldCols(dfr,retVal,eachFieldSetMember);
        }
        return retVal;
    }
    private FieldSetProcessorReturnType prepareFieldCols(Schema.DescribeFieldResult dfr,FieldSetProcessorReturnType retVal,Schema.FieldSetMember eachFieldSetMember ){
        if (dfr.isAccessible()) {
            String dataType = String.valueOf(dfr.getType()).toLowerCase();
            if (dataType == 'Double') {
                dataType = 'number';
            }

            if(dfr.isCalculated() == true  && dfr.getCalculatedFormula() != null && (dfr.getCalculatedFormula().startsWith(HYPERLINK) || dfr.getCalculatedFormula().startsWith(IMAGE) )){
                dataType = 'formula';
            }
            //create a new FieldSetColumn
            FieldSetColumn fsc = new FieldSetColumn();
            fsc.typeAttributes = new Map<String, Object>();
            fsc.apiName = String.valueOf(dfr.getName());
            fsc.label = String.valueOf(dfr.getLabel());
            fsc.isNameField = dfr.isNameField();
            if(dfr.isNameField()){
                fsc.typeAttributes.put('target', 'self');
                fsc.typeAttributes.put('label', new Map<String, Object>{'fieldName' => fsc.apiName});
            }
            fsc.type = dataType;
            fsc.isAutoNumber = dfr?.isAutoNumber();
            fsc.isNormalField = true;
            fsc.isCreateable = dfr.isCreateable();
            fsc.isUnique = dfr.isUnique();
            fsc.updateable = ((String.valueOf(dfr.getSObjectType()) != sObjectName && String.valueOf(dfr.getSObjectType()) != subgridSobjectName) ? false : dfr.isUpdateable());
            fsc.isRequired = (eachFieldSetMember != null ? ((dfr.isCreateable() && !dfr.isNillable()) || eachFieldSetMember.getRequired() == true) : (dfr.isCreateable() && !dfr.isNillable()));
            fsc.inlineHelpText = dfr.getInlineHelpText();
            fsc.hasInlineHelpText = fsc.inlineHelpText != null && fsc.inlineHelpText != '' ? true : false; 
            //figure out how to determine if a field is read only
            //figure out what to set for defaultWidth, resizable, sortable, defaultSortOrder, and currencyStyle

            //handle the odd data types
            switch on dataType {
                when 'currency'{
                    fsc.isNormalField = false;
                    fsc.isCurrency = true;
                    fsc.isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
                    if(!fsc.isMultiCurrencyEnabled){
                        fsc.currencyCode = UserInfo.getDefaultCurrency();
                    }else{
                        retVal.colNames.add('CurrencyIsoCode');
                    }
                    fsc.typeAttributes.put('minimumFractionDigits', dfr.getScale());
                }   
                when 'date' {
                    fsc.typeAttributes.put('month', '2-digit');
                    fsc.typeAttributes.put('day', '2-digit');
                    fsc.typeAttributes.put('year', 'numeric');
                    fsc.typeAttributes.put('timeZone', 'UTC');
                }

                when 'number'{
                    fsc.isNormalField = false;
                    fsc.isCurrency = true;
                    fsc.typeAttributes.put('minimumFractionDigits', dfr.getScale());
                }
                when 'percent'{
                    fsc.typeAttributes.put('minimumFractionDigits', dfr.getScale());
                }

                when 'reference' {
                    fsc.type = 'reference';
                    fsc.isLookup = true;
                    fsc.isNormalField = false;

                    if(dfr.getFilteredLookupInfo() != null){ 
                        fsc.isDependent = true;
                        fsc.lookupControllingFields = new Set<String>();
                        fsc.lookupControllingFields.addAll(dfr.getFilteredLookupInfo().getControllingFields());
                    }
                    
                    String isNameField = FieldSetHandler.getNameField(dfr.getReferenceTo()[0].getDescribe().getName());
                    String lookupName = String.join(new List<String>{
                            fsc.apiName.replaceAll('__c$', '__r').replaceAll('Id$', ''),
                            isNameField
                    }, '.');

                    //add the lookupName to the list of fields to query
                    retVal.colNames.add(lookupName);
                    fsc.typeAttributes.put('label', new Map<String, Object>{'fieldName' => lookupName,'lookupApi' => lookupName.substringBeforeLast('.')});
                    fsc.typeAttributes.put('target', 'self');
                    fsc.typeAttributes.put('referenceObject',dfr.getReferenceTo()[0].getDescribe().getName());
                    fsc.typeAttributes.put('isNameField',isNameField);
                }

                when 'picklist', 'multipicklist' {
                    if(dfr.getController() != null){ 
                        fsc.isDependent = true;
                        fsc.dependentOn = dfr.getController().getDescribe().getName();
                        fsc.dependentPicklistValues = dependentPicklistEntries(dfr);
                        retVal.colNames.add(fsc.dependentOn);
                    }
                    Map<String, String> picklistValues = new Map<String, String>();
                    for (Schema.PicklistEntry objPickList : dfr.getPicklistValues()) {
                        picklistValues.put(objPickList.getLabel(),objPickList.getValue());
                    }
                    fsc.picklistValues = picklistValues;
                }
                when 'textarea'{
                    fsc.isRichText = dfr.isHtmlFormatted();
                }
                when 'boolean' {
                    fsc.isRequired = eachFieldSetMember != null ? eachFieldSetMember.getRequired() == true : false;
                }
                when 'formula'{
                    fsc.type = 'formula';
                    String type = dfr.getCalculatedFormula().startsWith(HYPERLINK) ? HYPERLINK : IMAGE;
                    String[] details;
                    if(type == HYPERLINK){
                        details = dfr.getCalculatedFormula().replaceAll('"','').substringAfter(HYPERLINK).split(',');
                    }else{
                        details = dfr.getCalculatedFormula().replaceAll('"','').substringAfter(IMAGE).split(',');
                    }
                    fsc.typeAttributes.put('type', type);
                    fsc.typeAttributes.put('link', details[0].trim().replace('(',''));
                    fsc.typeAttributes.put('displaytext', details[1].trim().replace(')',''));
                    fsc.typeAttributes.put('target', details.size() == 3 ? details[2].trim().replace(')','') : '_blank');
                    fsc.typeAttributes.put('height', details.size() >= 4 ? details[2].trim().replace(')','') + 'px': '');
                    fsc.typeAttributes.put('width', details.size() >= 4 ? 
                            Integer.valueOf(details[3].trim().replace(')','')) > 400 ? '400px': details[3].trim().replace(')','') + 'px' : '');
                }

            } 
            retVal.colDefs.put(fsc.apiName,fsc);
            retVal.colNames.add(fsc.apiName);
        }
        return retVal;
    }
    // this will detect the isname field and return that by looping on all the fields
    public static String getNameField(String objectApiName){
        Map<String, SObjectField> fields = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();
        if (!fields.containsKey('Name') || !fields.get('Name').getDescribe().isNameField())
        {
            for(String field : fields.keySet()){
                if(fields.get(field).getDescribe().isNameField() == true){
                    nameFieldsBySObjects.put(objectApiName,fields.get(field).getDescribe().getName());
                    return fields.get(field).getDescribe().getName();
                }
            }
        }
        nameFieldsBySObjects.put(objectApiName,'Name');
        return 'Name';
    }
    public Map<String, Map<String,String>> dependentPicklistEntries(Schema.DescribeFieldResult depend){
        Schema.DescribeFieldResult control = Test.isRunningTest() ? depend : depend.getController().getDescribe();
        List<Schema.PicklistEntry> controlEntries;
        if(control.getType() != Schema.DisplayType.Boolean) {
            controlEntries = control.getPicklistValues();
        }
    
        String base64map = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
        Map<String,Map<String,String>> dependentPicklistValues = new Map<String,Map<String,String>>();
        for (Schema.PicklistEntry entry : depend.getPicklistValues()) {
            if (entry.isActive() && String.isNotEmpty(String.valueOf(((Map<String,Object>) JSON.deserializeUntyped(JSON.serialize(entry))).get('validFor')))) {
                List<String> base64chars = String.valueOf(((Map<String,Object>) JSON.deserializeUntyped(JSON.serialize(entry))).get('validFor')).split('');
                for (Integer index = 0; index < (controlEntries != null ? controlEntries.size() : 2); index++) {
                    Object controlValue =
                            (controlEntries == null
                                    ?   (Object) (index == 1)
                                    :   (Object) (controlEntries[index].isActive() ? controlEntries[index].getValue() : null)
                            );
                    Integer bitIndex = index / 6;
                    if (bitIndex > base64chars.size() - 1) {
                        break;
                    }
                    Integer bitShift = 5 - Math.mod(index, 6);
                    if  (controlValue == null || (base64map.indexOf( base64chars[ bitIndex ] ) & (1 << bitShift)) == 0)
                        continue;
                    if (!dependentPicklistValues.containsKey((String) controlValue)) {
                        dependentPicklistValues.put((String) controlValue, new Map<String,String>());
                    }
                    dependentPicklistValues.get((String) controlValue).put(entry.getLabel(),entry.getValue());
                }
            }
        }
        return dependentPicklistValues;

    }
    private class FieldSetProcessorReturnType {
        public Map<String,FieldSetColumn> colDefs;
        public List<String> colNames;

        public FieldSetProcessorReturnType() {
            this.colDefs = new Map<String,FieldSetColumn>();
            this.colNames = new List<String>();
        }
    }    

    public class FieldSetResponse {
        @AuraEnabled
        public List<FieldSetColumn> mainColumns;
        @AuraEnabled
        public List<FieldSetColumn> extraColumns;
        @AuraEnabled
        public List<FieldSetColumn> requiredColumns;
        @AuraEnabled
        public List<FieldSetColumn> subGridColumns;
        @AuraEnabled
        public FieldSetColumn rowNumberColumn;
        @AuraEnabled
        public String subqueryRelationshipName;
        @AuraEnabled
        public String subgridParentApiName;
        public Set<String> fieldNames;
        public Set<String> subGridFieldNames;       

        //pass in sobject type to cast object to specific sobject type?
        public FieldSetResponse() {
            this.mainColumns = new List<FieldSetColumn>();
            this.extraColumns = new List<FieldSetColumn>();
            this.requiredColumns = new List<FieldSetColumn>();
            this.subGridColumns = new List<FieldSetColumn>();
            this.rowNumberColumn = new FieldSetColumn();
            this.fieldNames = new Set<String>();
            this.subGridFieldNames = new Set<String>();
            this.subqueryRelationshipName = '';
            this.subgridParentApiName = '';
        }
    }

    public class FieldSetColumn {
        @AuraEnabled
        public String apiName {get; private set;}
        @AuraEnabled
        public String label {get; private set;}
        @AuraEnabled
        public String type {get; private set;}
        @AuraEnabled
        public Map<String,Map<String,String>> dependentPicklistValues {get; private set;}
        @AuraEnabled
        public Boolean isDependent {get; private set;}
        @AuraEnabled
        public String dependentOn {get; private set;}
        @AuraEnabled
        public Boolean updateable {get; private set;}
        @AuraEnabled
        public Boolean isLookup {get; private set;}
        @AuraEnabled
        public Boolean isAutoNumber {get; private set;}
        @AuraEnabled
        public Boolean isNameField {get; private set;}
        @AuraEnabled
        public Boolean isRequired {get;set;}
        @AuraEnabled
        public Boolean isRichText {get; private set;}
        @AuraEnabled
        public String currencyStyle {get; private set;}
        @AuraEnabled
        public String currencyCode {get; private set;}   
        @AuraEnabled
        public Map<String, Object> typeAttributes {get;set;}      
        @AuraEnabled
        public Map<String,String> picklistValues {get;set;}
        @AuraEnabled
        public Boolean isCurrency {get; private set;}
        @AuraEnabled
        public Boolean isMultiCurrencyEnabled {get; private set;}
        @AuraEnabled
        public Boolean isNormalField {get; private set;}
        @AuraEnabled
        public Boolean isCreateable {get; private set;}
        @AuraEnabled
        public Boolean isUnique {get; private set;}
        @AuraEnabled 
        public String inlineHelpText {get; private set;}
        @AuraEnabled 
        public Boolean hasInlineHelpText {get; private set;}
        @AuraEnabled 
        public String value {get; set;}
        @AuraEnabled 
        public Set<String> lookupControllingFields {get; private set;}
        public FieldSetColumn() {
        
        }
    }

    //a new wrapper to handle the inputs from datagrid
    public class FieldSetRequest {
        public String sObjectName;
        public String mainFieldSetName;
        public String extraFieldSetName;
        public String reOrderFieldName;
        public String filter;
        public String subquerySObjectName;
        public String subqueryRelationshipName;
        public String subqueryRelationshipFieldset;
        public String recordsLimit;
        public String orderByField;
        public String orderByDir;
        public FieldSetRequest(){}
        public FieldSetRequest(String sObjectName, String mainFieldSetName, String extraFieldSetName, String reOrderFieldName){
            this.sObjectName = sObjectName;
            this.mainFieldSetName = mainFieldSetName;
            this.extraFieldSetName = extraFieldSetName;
            this.reOrderFieldName = reOrderFieldName;
        }
    }
}