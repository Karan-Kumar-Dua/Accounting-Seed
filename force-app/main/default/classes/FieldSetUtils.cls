public without sharing class FieldSetUtils {

    public static DataTableResponse getColumnsFromFieldSet(String objectName, String fieldSetName, List<String> ignoredFields) {
        Schema.SObjectType SObjectTypeObj = Schema.getGlobalDescribe().get(objectName);
        Schema.DescribeSObjectResult DescribeSObjectResultObj = SObjectTypeObj.getDescribe();
        Schema.FieldSet fieldSetObj = DescribeSObjectResultObj.fieldsets.getMap().get(fieldSetName);
        
        List<DataTableColumns> dataColumns = new List<DataTableColumns>();
        List<String> fields = new List<String>();
        
        DatatableResponse response = new DataTableResponse();

        //convert ignoredFieldNames to lower case
        for (Integer i = 0; i < ignoredFields.size(); i++) {
            ignoredFields[i] = ignoredFields[i].toLowerCase();
        }
        
        for (Schema.FieldSetMember eachFieldSetMember : fieldSetObj.getFields()) {
            Schema.DescribeFieldResult dfr = eachFieldSetMember.getSObjectField().getDescribe();

            if (dfr.isAccessible()) {
                if (!ignoredFields.contains(String.valueOf(eachFieldSetMember.getFieldPath().toLowerCase()))) {
                    String dataType = String.valueOf(eachFieldSetMember.getType()).toLowerCase();
                    if (dataType == 'datetime') {
                        dataType = 'date';
                    }
                    if (dataType == 'Double') {
                        dataType = 'number';
                    }
                    if (dataType == 'currency') {
                        dataType = 'customCurrency';
                    }
                    if (dataType == 'percent') {
                        dataType = 'customPercent';
                    }
                    DataTableColumns dataColumn = new DataTableColumns( String.valueOf(eachFieldSetMember.getLabel()),
                                                                        String.valueOf(eachFieldSetMember.getFieldPath()),
                                                                        dataType,
                                                                        true
                    );

                    switch on dataType {
                        when 'date' {
                            dataColumn.typeAttributes = new Map<String, Object>();
                            dataColumn.typeAttributes.put('month', '2-digit');
                            dataColumn.typeAttributes.put('day', '2-digit');
                            dataColumn.typeAttributes.put('year', 'numeric');
                            dataColumn.typeAttributes.put('timeZone', 'UTC');
                        }

                        when 'number' {
                            dataColumn.typeAttributes = new Map<String, Object>();
                            dataColumn.typeAttributes.put('minimumFractionDigits', dfr.getScale());
                        }

                        when 'reference' {
                            dataColumn.type = 'url';
                            dataColumn.typeAttributes = new Map<String, Object>();
                            String lookupName = dataColumn.fieldName.replaceAll('__c$', '__r').replaceAll('Id$', '') + '.Name';
                            fields.add(lookupName);
                            dataColumn.typeAttributes.put('label', new Map<String, Object>{'fieldName' => lookupName});
                            dataColumn.typeAttributes.put('target', 'self');
                        }

                        when 'customCurrency' {
                            dataColumn.typeAttributes = new Map<String, Object>();
                            dataColumn.typeAttributes.put('currencyCode', new Map<String, Object>{'fieldName' => 'currency'});
                            dataColumn.typeAttributes.put('isMultiCurrencyEnabled', new Map<String, Object>{'fieldName' => 'isMultiCurrencyEnabled'}); 
                            dataColumn.cellAttributes = new Map<String, Object>();
                            dataColumn.cellAttributes.put('alignment', 'right');
                        }

                        when 'string' {
                            dataColumn.cellAttributes = new Map<String, Object>();
                            dataColumn.cellAttributes.put('alignment', 'left');
                        }

                        when 'customPercent' {
                            dataColumn.typeAttributes = new Map<String, Object>();
                            dataColumn.typeAttributes.put('minimumFractionDigits', dfr.getScale());
                        }

                        when else {
                            dataColumn.cellAttributes = new Map<String, Object>();
                            dataColumn.cellAttributes.put('alignment', 'left');
                        }
                    }
                    dataColumns.add(dataColumn);         
                    fields.add(String.valueOf(eachFieldSetMember.getFieldPath()));

                }
            }
        }

        if (!dataColumns.isEmpty()) {
            response.dataTableColumns = dataColumns;
            response.fieldNames = fields;
        }

        return response;
    }

    public static Map<String, Object> getFieldSetData (List<String> fieldNames, SObject record){
        return getDataFromFieldSet(fieldnames, record);
    }

    public static Map<String, Object> getFieldSetData (FieldSetUtils.DataTableResponse DTR, SObject record){
        list<string> FieldNames = new list<string>();
        if(DTR != null){
            FieldNames = DTR.fieldNames;
        }
        return getDataFromFieldSet(fieldnames, record);
    }

    private static Map<String, Object> getDataFromFieldSet (List<String> fieldNames, SObject record){
        Map<String, Object> fieldSetData = new Map<String, Object>();
        List<String> referencedFields = new List<String>();

        for (String fieldName : fieldNames) {
            if (fieldName.countMatches('.') > 1) {
                String firstLevelRelField = fieldName.substringBefore('.');
                String secondLevelRelField = fieldName.substringBetween('.', '.');
                if (record.getSobject(firstLevelRelField) != null
                    && record.getSobject(firstLevelRelField).getSObject(secondLevelRelField) != NULL) {
                    fieldSetData.put(
                        fieldName,
                        record
                            .getSobject(firstLevelRelField)
                            .getSobject(secondLevelRelField)
                            .get('Name')
                    );
                    referencedFields.add(fieldName.left(fieldName.lastIndexOf('__r') + 3).replaceAll('__r$', '__c'));
                }
            }
            else if (fieldName.countMatches('.') == 1) {
                String firstLevelRelField = fieldName.substringBefore('.');
                String fieldOnRelatedRecord = fieldName.substringAfter('.');
                SObject relatedRecord = record.getSobject(firstLevelRelField);
                if (relatedRecord != null) {
                    fieldSetData.put(fieldName, relatedRecord.get(fieldOnRelatedRecord));
                    referencedFields.add(fieldName.left(fieldName.lastIndexOf('__r') + 3).replaceAll('__r$', '__c'));
                }
            }
            else {
                fieldSetData.put(fieldName, record.get(fieldName));
            }
        }

        for (String fieldName : fieldSetData.keySet()) {
            if (referencedFields.contains(fieldName) && fieldSetData.get(fieldName) != null) {
                fieldSetData.put(fieldName, '/lightning/r/' + fieldSetData.get(fieldName) + '/view');
            }
        }

        return fieldSetData;
    }

    public class DataTableColumns {
        public String label {get;set;}
        public String fieldName {get;set;}
        public String type {get;set;}
        public Boolean sortable {get;set;}
        public Map<String, Object> cellAttributes {get;set;}
        public Map<String, Object> typeAttributes {get;set;}

        public DataTableColumns(String label, String fieldName, String type, Boolean sortable) {
            this.label = label;
            this.fieldName = fieldName;
            this.type = type;
            this.sortable = sortable;
            
        }
    }

    public class DataTableResponse {
        public List<DataTableColumns> dataTableColumns {get;set;}
        public List<String> fieldNames {get;set;}
        
        public DataTableResponse() {
            dataTableColumns = new List<DataTableColumns>();
            fieldNames = new List<String>();
        }
    }
}