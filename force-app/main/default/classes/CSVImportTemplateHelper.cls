public with sharing class CSVImportTemplateHelper {
    @AuraEnabled
    public static List<CSVImportTemplateHandler.ImportTemplate> getImportTemplates(String detailObject, String parentObject){
        return CSVImportTemplateHandler.getImportTemplates(detailObject, parentObject);
    }
    @AuraEnabled(cacheable=true)
    public static CSVImportTemplateHandler.ImportTemplate getImportTemplate(String recordId){
        return new CSVImportTemplateHandler.ImportTemplate(CSVImportTemplateHandler.getImportTemplate(recordId));
    }
    @AuraEnabled(cacheable=true)
    public static CSVImportTemplateService.CSVFieldMapper getImportFieldDefinitions(String recordId){
        Import_Template__c importTemplate = CSVImportTemplateHandler.getImportTemplate(recordId);
        return CSVImportTemplateHandler.getFieldMappings(importTemplate);
    }
    @AuraEnabled
    public static List<CSVImportTemplateHandler.ImportFields> getImportFields(String recordId, String[] columns, String childObj){
        return CSVImportTemplateHandler.getImportFields(recordId, columns,childObj);
    }
    @AuraEnabled(cacheable=true)
    public static List<CSVImportTemplateHandler.Records> getRecordIds(String recordsToFetch){
        return CSVImportTemplateHandler.getRecordIds(recordsToFetch);
    }
    @AuraEnabled
    public static CSVImportTemplateHandler.Response importChildRecord(String recordsToImport){
        return CSVImportTemplateHandler.importRecords(recordsToImport);
    }
    @AuraEnabled
    public static List<String> importFields(String importFieldsJson){
        return CSVImportTemplateHandler.saveImportFields(importFieldsJson);
    }
    @AuraEnabled
    public static CSVImportTemplateHandler.Response getParentUpdatedRecords(String recordsToFetch,String records){
        return CSVImportTemplateHandler.getParentUpdatedRecords(recordsToFetch,records);
    }
}