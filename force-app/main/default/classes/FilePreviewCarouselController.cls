public with sharing class FilePreviewCarouselController {

    private static Set<String> imageFileTypes = new Set<String>{'PNG', 'JPG', 'JPEG', 'BMP', 'GIF', 'TIF', 'TIFF'};
    private static Set<String> otherFileTypes = new Set<String>{'PDF', 'WORD', 'WORD_X', 'EXCEL', 'EXCEL_X', 'POWER_POINT', 'POWER_POINT_X'};

    @AuraEnabled(cacheable=true)
    public static List<RelatedFilesWrapper> getRelatedFilesByRecordId(String params) {

        Params paramsVar = (Params) JSON.deserialize(params, Params.class);

        String recordId = paramsVar.recordId;
        String fileId = paramsVar.fileId;
        String fieldNameForFileID = paramsVar.fieldNameForFileID;

        String objectApiName = Id.valueOf(recordId).getSObjectType().getDescribe().getName();
        SObject sObjectVar = Schema.getGlobalDescribe().get(objectApiName).newSObject();

        sObjectVar = querySObject(recordId, fieldNameForFileID, sObjectVar);

        List<RelatedFilesWrapper> relatedFilesWrappers = new List<RelatedFilesWrapper>();
        Set<Id> fileIds = new Set<Id>();
        for (ContentDocumentLink docLink : queryContentDocumentLinks(recordId, fileId)) {
            fileIds.add(docLink.ContentDocumentId);
        }

        if (!fileIds.isEmpty()) {
            Integer count = 1;
            for (ContentVersion contVersion : queryContentVersions(fileIds)) {
                RelatedFilesWrapper relatedFile = new RelatedFilesWrapper();
                relatedFile.isPreviewAvailable = true;
                relatedFile.contentDocumentId = contVersion.ContentDocumentId;
                relatedFile.fileTitle = contVersion.Title;
                relatedFile.isPdf = false;
                relatedFile.previewUrl = '/sfc/servlet.shepherd/document/download/' + contVersion.ContentDocumentId;
                if (imageFileTypes.contains(contVersion.FileType)){
                    relatedFile.renderAsPdf = false;
                } else if (otherFileTypes.contains(contVersion.FileType)){
                    relatedFile.renderAsPdf = true;
                    if (contVersion.FileType != 'PDF'){
                        relatedFile.previewUrl = '/sfc/servlet.shepherd/version/renditionDownload?rendition=PDF&versionId=' + contVersion.Id;
                    } else {
                        relatedFile.isPdf = true;
                    }
                }
                relatedFile.key = 'slide-' + count;
                relatedFile.keyHref = '#slide-' + count;
                relatedFile.recordCount = count;
                relatedFile.extId = contVersion.ExtId__c;
                if (String.isNotBlank(fieldNameForFileID)) { //Since it is not applicable when the FilePreviewCarousel is placed as child component
                    relatedFile.isDefaultFile = (String.isNotBlank((String) sObjectVar.get(fieldNameForFileID)) && (String) sObjectVar.get(fieldNameForFileID) == contVersion.ExtId__c);
                }
                relatedFilesWrappers.add(relatedFile);
                count = count + 1;
            }
        }
        return relatedFilesWrappers;
    }

    @AuraEnabled
    public static void setDefaultFileId(Id recordId, String fieldName, String extId) {

        SObject sObj = recordId.getSobjectType().newSObject();
        sObj.put('Id', recordId);
        sObj.put(fieldName, extId);
        SFDCSecurityUtils.updateCheckCRUDAndFLS(sObj, new List<String>());
    }

    @AuraEnabled
    public static Boolean checkPreviewAvailability(String contentDocumentId){
        return FilePreviewService.checkPreviewAvailability(contentDocumentId);
    }

    private static SObject querySObject(String recordId, String fieldNameForFileID, SObject objectApiName){

        Schema.SObjectType objectType = objectApiName.getSObjectType();

        List<String> queryFields = new List<String>{'Id'};

        String queryCondition = 'Id = :recordId';

        if (String.isNotBlank(fieldNameForFileID)) {
            queryFields.add(fieldNameForFileID);
        }

        SOQLBuilder theQuery = new SOQLBuilder(objectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
        	.setLimit(1);

        return (SObject) Database.query(theQuery.toSOQL());
    }

    private static List<ContentDocumentLink> queryContentDocumentLinks(String recordId, String fileId) {
        List<String> queryFields = new List<String>{'ContentDocumentId'};

        String queryCondition = 'LinkedEntityId = :recordId';

        if (String.isNotBlank(fileId)) {
            queryCondition += ' AND ContentDocument.LatestPublishedVersion.AcctSeed__ExtId__c = \'' + fileId + '\' ';
        }

        SOQLBuilder theQuery = new SOQLBuilder(ContentDocumentLink.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<ContentDocumentLink>) Database.query(theQuery.toSOQL());
    }

    private static List<ContentVersion> queryContentVersions(Set<Id> fileIds) {
        List<String> queryFields = new List<String>{
            'Id',
            'ContentDocumentId',
            'FileType',
            'Title',
            'ExtId__c'
        };

        List<String> supportedFileTypes = new List<String>(imageFileTypes);
        supportedFileTypes.addAll(otherFileTypes);

        String queryCondition = 'ContentDocumentId IN :fileIds AND FileType IN :supportedFileTypes';

        SOQLBuilder theQuery = new SOQLBuilder(ContentVersion.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<ContentVersion>) Database.query(theQuery.toSOQL());
    }

    public class RelatedFilesWrapper{
        @AuraEnabled
        public String previewUrl{ get; set; }

        @AuraEnabled
        public String fileTitle{ get; set; }

        @AuraEnabled
        public Boolean isPdf{ get; set; }

         @AuraEnabled
        public Boolean renderAsPdf{ get; set; }

        @AuraEnabled
        public String key{ get; set; }

        @AuraEnabled
        public String keyHref{ get; set; }

        @AuraEnabled
        public Integer recordCount{ get; set; }

        @AuraEnabled
        public Boolean isDefaultFile{ get; set; }

        @AuraEnabled
        public String extId{ get; set; }

        @AuraEnabled
        public String contentDocumentId{ get; set; }

        @AuraEnabled
        public Boolean isPreviewAvailable{ get; set; }

    }

    public class Params {
        @AuraEnabled
        public String recordId { get; set; }
        @AuraEnabled
        public String fileId { get; set; }
        @AuraEnabled
        public String fieldNameForFileID { get; set; }

    }
}