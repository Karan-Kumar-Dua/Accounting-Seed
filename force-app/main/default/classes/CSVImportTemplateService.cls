public with sharing class CSVImportTemplateService {
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static final String REFERENCE = 'REFERENCE';

    public static CSVFieldMapper getFieldMappings(Import_Template__c importTemplate){
        try{
            List<Mapping> targetObjects = getTargetObject(importTemplate);
            List<Mapping> lookupTypes = getLookupType();
            Map<String,List<FieldDefinitions>> targetFields = getTargetFields(importTemplate);
            return new CSVFieldMapper(targetObjects,lookupTypes,targetFields);        
        }catch(Exception e){
            return new CSVFieldMapper(e.getMessage());
        }
    }
    private static List<Mapping> getTargetObject(Import_Template__c importTemplate){
        List<Mapping> targetObjects = new List<Mapping>();

        Schema.DescribeSobjectResult[] results = Schema.describeSObjects(new String[]{PACKAGE_QUALIFIER+'Import_Template__c'});
        for(Schema.PicklistEntry pe : results[0].fields.getMap().get(PACKAGE_QUALIFIER+'Parent__c').getDescribe().getPickListValues()){
            if(importTemplate.Parent__c == pe.getValue()){
                targetObjects.add(new Mapping(pe.getLabel() + ' (' +pe.getValue()+')' ,pe.getValue()));
            }
        }
        for(Schema.PicklistEntry pe : results[0].fields.getMap().get(PACKAGE_QUALIFIER+'Detail__c').getDescribe().getPickListValues()){
            if(importTemplate.Detail__c == pe.getValue()){
                targetObjects.add(new Mapping(pe.getLabel() + ' (' +pe.getValue()+')',pe.getValue()));
            }
        }
        return targetObjects;
    }
    private static List<Mapping> getLookupType(){
        List<Mapping> lookupTypes = new List<Mapping>();

        Schema.DescribeSobjectResult[] results = Schema.describeSObjects(new String[]{PACKAGE_QUALIFIER+'Import_Field__c'});
        for(Schema.PicklistEntry pe : results[0].fields.getMap().get(PACKAGE_QUALIFIER+'Lookup_Type__c').getDescribe().getPickListValues()){
            lookupTypes.add(new Mapping(pe.getLabel() ,pe.getValue()));
        }
        return lookupTypes;
    }
    private static Map<String,List<FieldDefinitions>> getTargetFields(Import_Template__c importTemplate){
        Map<String,List<FieldDefinitions>> targetFields = new Map<String,List<FieldDefinitions>>();

        List<String> types = new List<String>();
        if(importTemplate.Parent__c != null){
            types.add(importTemplate.Parent__c);
        }
        if(importTemplate.Detail__c != null){
            types.add(importTemplate.Detail__c);
        }
        for(Schema.DescribeSobjectResult res : Schema.describeSObjects(types)) {
            for(Schema.SObjectField fs : res.fields.getMap().values()){
                FieldDefinitions fd = new FieldDefinitions();
                fd.label = fs.getDescribe().getLabel()  + ' (' +fs.getDescribe().getName()+')';
                fd.apiName = fs.getDescribe().getName();
                fd.type = String.valueOf(fs.getDescribe().getType());
                fd.isExternalId = fs.getDescribe().isExternalId();
                fd.isIdLookup = fs.getDescribe().isIdLookup();
                fd.isNamePointing = fs.getDescribe().isNameField();
                fd.parentPointing = fd.type == REFERENCE ? String.valueOf(fs.getDescribe().getReferenceTo()).replace('(','').replace(')','') : ''; 

                if(fd.type == REFERENCE){
                    fd.externalIdFields = getParentMappings(new String[]{fd.parentPointing});
                }
                if(targetFields.containsKey(String.valueOf(res.getName())) == false){
                    targetFields.put(String.valueOf(res.getName()),new List<FieldDefinitions>{fd});
                }else{
                    targetFields.get(String.valueOf(res.getName())).add(fd);
                }
            }
        }
        return getSortedFileds(targetFields);
    }
    private static  Map<String,List<FieldDefinitions>> getSortedFileds(Map<String,List<FieldDefinitions>> targetFields){
        Map<String,List<FieldDefinitions>> sortedTargetFields = new Map<String,List<FieldDefinitions>>();
        for(String objName : targetFields.keySet()){
            List<FieldDefinitions> defs = targetFields.get(objName);
            defs.sort();
            sortedTargetFields.put(objName,defs);
        }
        return sortedTargetFields;
    }
    private static List<Mapping> getParentMappings(String[] objValue){
        List<Mapping> mappings = new List<Mapping>();
        try{
            for(Schema.SObjectField fsd : Schema.describeSObjects(objValue)[0].fields.getMap().values()){
                if(fsd.getDescribe().isExternalId() == true){
                    mappings.add(new Mapping(fsd.getDescribe().getLabel()  + ' (' +fsd.getDescribe().getName()+')',fsd.getDescribe().getName()));
                }
            }
            return mappings;
        }catch(Exception e){
            return mappings;
        }
    }
    public class CSVFieldMapper{
        @AuraEnabled
        public List<Mapping> targetObjects;
        @AuraEnabled
        public List<Mapping> lookupTypes;
        @AuraEnabled
        public Map<String,List<FieldDefinitions>> targetFields;
        @AuraEnabled
        public String error;
        public CSVFieldMapper(List<Mapping> targetObjects,List<Mapping> lookupTypes,Map<String,List<FieldDefinitions>> targetFields){
            this.targetFields = targetFields;
            this.lookupTypes = lookupTypes;
            this.targetObjects = targetObjects;
        }
        public CSVFieldMapper(String error){
            this.error = error;
        }

    }
    public class Mapping{
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String value;
        public Mapping(){}
        public Mapping(String label, String value){
            this.label = label;
            this.value = value;
        }
    }
    public class FieldDefinitions implements Comparable{
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String apiName;
        @AuraEnabled
        public String type;
        @AuraEnabled
        public Boolean isExternalId;
        @AuraEnabled
        public Boolean isIdLookup;
        @AuraEnabled
        public Boolean isNamePointing;
        @AuraEnabled
        public String parentPointing;
        @AuraEnabled
        public List<Mapping> externalIdFields;
        
        public Integer compareTo(Object compareTo){
            FieldDefinitions fd = (FieldDefinitions)compareTo;
            if(label == fd.label){
                return 0;
            } else if(label < fd.label){
                return -1;
            } else {
                return 1;
            }
        }
    }
}