public with sharing class ImportFieldActions {
    public static void handleBeforeInsert(List<Import_Field__c> importFields){
        Set<Id> importTemplates = new Set<Id>();

        for(Import_Field__c field : importFields){
            importTemplates.add(field.Import_Template__c);
        }

        List<String> queryFields = new List<String>{
            'ID', 'Name'
        };
        String queryCondition = 'Id IN :importTemplates';

        SOQLBuilder theQuery = new SOQLBuilder(Import_Template__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);
        List<Import_Template__c> resultList =  (List<Import_Template__c>)Database.query(theQuery.toSOQL());

        Map<Id,String> importTemplateNames = new Map<Id,String>();
        for(Import_Template__c result : resultList){
            if(!importTemplateNames.containsKey(result.Id)){
                importTemplateNames.put(result.Id, result.Name);
            }
        }

        for(Import_Field__c field : importFields){
            field.Import_Key__c = importTemplateNames.get(field.Import_Template__c) + '|'+field.Target_Object__c + '|' + field.Target_Field__c;
        }
    }
}