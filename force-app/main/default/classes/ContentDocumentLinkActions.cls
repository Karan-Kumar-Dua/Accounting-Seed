public with sharing class ContentDocumentLinkActions {
    public static void afterInsertHandler(List<ContentDocumentLink> newList){
        Set<Id> contentDocumentIds = new Set<Id>();
        for(ContentDocumentLink docLink :newList){
            if(docLink.LinkedEntityId.getSobjectType().getDescribe().name == 'AcctSeed__Account_Payable__c'){
                contentDocumentIds.add(docLink.ContentDocumentId);
            }
        }

        if(!contentDocumentIds.isEmpty()){
            populateUUIDonContentVersion(contentDocumentIds);
        }
    }

    public static void populateUUIDonContentVersion(Set<Id> contentDocumentIds){
        List<ContentVersion> contentVersions = queryContentVersions(contentDocumentIds);
        if(!contentVersions.isEmpty()){
            contentVersions = UUID.generateUUID(contentVersions, ContentVersion.ExtId__c.getDescribe().getName());
            SFDCSecurityUtils.updateCheckCRUDAndFLS(contentVersions, new List<String>());
        }
    }
    
    private static List<ContentVersion> queryContentVersions(Set<Id> contentDocumentIds) {
        List<String> queryFields = new List<String>{
            'Id',
            'ExtId__c'
        };

        String queryCondition = 'ContentDocumentId IN :contentDocumentIds AND ExtId__c = NULL';

        SOQLBuilder theQuery = new SOQLBuilder(ContentVersion.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<ContentVersion>) Database.query(theQuery.toSOQL());
    }
}