public with sharing class FileManagerController {
    private static final String BANK_ACCOUNT_SIGNATURE_BLOCK_ERROR = Label.BANK_ACCOUNT_SIGNATURE_BLOCK_ERROR;
    private static final String INF_FILE_MANAGER_LEDGER_LOGO_ERROR = Label.INF_FILE_MANAGER_LEDGER_LOGO_ERROR;
    private static final String LEDGER_OBJECT = 'AcctSeed__Ledger__c';
    private static final String BANK_ACCOUNT_OBJECT = 'AcctSeed__Bank_Account__c';
    private static final String BANK_ACCOUNT_SIGNATURE_BLOCK_FIELD = 'Signature_Block__c';
    private static final String BANK_ACCOUNT_SIGNATURE_BLOCK_2_FIELD = 'Signature_Block_2__c';

    private class FileManagerControllerUploadException extends Exception {
    }

    @AuraEnabled
    public static String getFileId(String recordId, String objectApiName, String fieldName) {
        String fileId = '';
        SOQLBuilder theQuery;
        String queryCondition = 'Id = \'' + recordId + '\'';
        List<String> queryFields = new List<String>{'Id'};

        if (objectApiName.equalsIgnoreCase(LEDGER_OBJECT)) {
            queryFields.add(fieldName);
            theQuery = new SOQLBuilder(AcctSeed__Ledger__c.SObjectType);
        } else if (objectApiName.equalsIgnoreCase(BANK_ACCOUNT_OBJECT) && fieldName.equalsIgnoreCase(BANK_ACCOUNT_SIGNATURE_BLOCK_FIELD)) {
            queryFields.add(fieldName);
            theQuery = new SOQLBuilder(AcctSeed__Bank_Account__c.SObjectType);
        } else if (objectApiName.equalsIgnoreCase(BANK_ACCOUNT_OBJECT) && fieldName.equalsIgnoreCase(BANK_ACCOUNT_SIGNATURE_BLOCK_2_FIELD)){
            queryFields.add(fieldName);
            theQuery = new SOQLBuilder(AcctSeed__Bank_Account__c.SObjectType);
        }
       
        theQuery.assertIsAccessible().setEnforceFLS(true).selectFields(queryFields).setCondition(queryCondition);

        if (objectApiName.equalsIgnoreCase(BANK_ACCOUNT_OBJECT)) {
            AcctSeed__Bank_Account__c bankAccount = (AcctSeed__Bank_Account__c) Database.query(theQuery.toSOQL());
            fileId = (fieldName.equalsIgnoreCase(BANK_ACCOUNT_SIGNATURE_BLOCK_FIELD))?(bankAccount.Signature_Block__c):(bankAccount.Signature_Block_2__c);
        } else if (objectApiName.equalsIgnoreCase(LEDGER_OBJECT)) {
            AcctSeed__Ledger__c ledger = (AcctSeed__Ledger__c) Database.query(theQuery.toSOQL());
            fileId = ledger.Logo__c;
        }
        return fileId;
    }

    @AuraEnabled
    public static String updateFile(String fileDetailsParam, String fieldName) {
        FileManagerWrapper fileDetails = (FileManagerWrapper) JSON.deserialize(fileDetailsParam, FileManagerWrapper.class);
        String cvId = getContentVersionId(fileDetails.documentId);
        String extId = updateContentVersion(cvId);
        updateSObjectRecord(fileDetails.record_id, fileDetails.object_api_name, extId, fieldName);
        return extId;
    }

    private static void updateSObjectRecord(String recordId, String objectApiName, String extId, String fieldName) {
        try {
            List<String> queryFields = new List<String>{'Id'};

            if (objectApiName.equalsIgnoreCase(BANK_ACCOUNT_OBJECT) && fieldName.equalsIgnoreCase(BANK_ACCOUNT_SIGNATURE_BLOCK_FIELD)) {
                queryFields.add(fieldName);    
            }else if(objectApiName.equalsIgnoreCase(BANK_ACCOUNT_OBJECT) && fieldName.equalsIgnoreCase(BANK_ACCOUNT_SIGNATURE_BLOCK_2_FIELD)){
                queryFields.add(fieldName);
            } else if (objectApiName.equalsIgnoreCase(LEDGER_OBJECT)) {
                queryFields.add(fieldName);
            }
            if (objectApiName.equalsIgnoreCase(BANK_ACCOUNT_OBJECT)) {
                AcctSeed__Bank_Account__c bc = new AcctSeed__Bank_Account__c();
                bc.Id = recordId;
                if(fieldName.equalsIgnoreCase(BANK_ACCOUNT_SIGNATURE_BLOCK_FIELD)){
                    bc.Signature_Block__c = extId;
                }else if(fieldName.equalsIgnoreCase(BANK_ACCOUNT_SIGNATURE_BLOCK_2_FIELD)){
                    bc.Signature_Block_2__c = extId;
                } 
                SFDCSecurityUtils.updateCheckCRUDAndFLS(bc, new List<String>{queryFields[1]});
            } else if (objectApiName.equalsIgnoreCase(LEDGER_OBJECT)) {
                AcctSeed__Ledger__c ld = new AcctSeed__Ledger__c();
                ld.Id = recordId;
                ld.Logo__c = extId;
                SFDCSecurityUtils.updateCheckCRUDAndFLS(ld, new List<String>{queryFields[1]});
            }
        } catch (Exception e) {
            if (objectApiName.equalsIgnoreCase(BANK_ACCOUNT_OBJECT)) {
                throw new FileManagerControllerUploadException(BANK_ACCOUNT_SIGNATURE_BLOCK_ERROR);
            } else if (objectApiName.equalsIgnoreCase(LEDGER_OBJECT)) {
                throw new FileManagerControllerUploadException(INF_FILE_MANAGER_LEDGER_LOGO_ERROR);
            }
        }
    }

    private static String getContentVersionId(Id documentId) {

        String cvId = '';
        ContentDocument cd = new ContentDocument();

        List<String> queryFields = new List<String>{'LatestPublishedVersionId'};
        String queryCondition = 'Id = :documentId';

        SOQLBuilder theQuery = new SOQLBuilder(ContentDocument.SObjectType);
        theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition);

        cd = (ContentDocument) Database.query(theQuery.toSOQL());
        cvId = cd.LatestPublishedVersionId;

        return cvId;
    }

    private static String updateContentVersion(String cvId) {

        String extId = FinancialSuiteUtils.getUUID();

        ContentVersion cv = new ContentVersion();
        cv.Id = cvId;
        cv.ExtId__c = extId;

        SFDCSecurityUtils.updateCheckCRUDAndFLS(cv, new List<String>{'ExtId__c'});
        
        return extId;
    }
    
    @TestVisible
    private class FileManagerWrapper {
        @TestVisible
        private String documentId;
        @TestVisible
        private String record_id;
        @TestVisible
        private String object_api_name;
    }

}