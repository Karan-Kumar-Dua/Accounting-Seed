public with sharing class BankAccountHelper {

  private static Final String BANK_ACCOUNT_SIGN_UPLOAD_ERROR = Label.BANK_ACCOUNT_SIGN_UPLOAD_ERROR;
  private static Final String BANK_ACCOUNT_SIGN_LINK_ERROR = Label.BANK_ACCOUNT_SIGN_LINK_ERROR;
  private static Final String BANK_ACCOUNT_SIGNATURE_BLOCK_ERROR = Label.BANK_ACCOUNT_SIGNATURE_BLOCK_ERROR;

  private class BankAccountFileUploadException extends Exception{}

    @AuraEnabled
    public static void uploadSignature(String signatureDetails1) {
      BankAccountSignatureWrapper signatureDetails=(BankAccountSignatureWrapper)JSON.deserialize(signatureDetails1,BankAccountSignatureWrapper.class);
          ContentVersion cv = createContentVersion(signatureDetails);
          if(cv == null) {
            throw new BankAccountFileUploadException(BANK_ACCOUNT_SIGN_UPLOAD_ERROR);
          }
          else {
            ContentDocumentLink cdl = createContentLink(cv.Id, signatureDetails.record_id);
              if (cdl == null) { throw new BankAccountFileUploadException(BANK_ACCOUNT_SIGN_LINK_ERROR); }
              else {
                  updateBankAccountRecord(cv,signatureDetails.record_id);
              }
          }
    }
    /*
     * @method createContentVersion() [private]
     * @desc Creates a content version from a given file's base64 and name
     * 
     * @param {String} base64 - base64 string that represents the file
     * @param {String} filename - full file name with extension, i.e. 'products.csv'
     * 
     * @return {ContentVersion} - returns the newly created ContentVersion, or null
     *   if there was an error inserting the record
     */
    private static ContentVersion createContentVersion(BankAccountSignatureWrapper signatureDetails) {
      try {
        ContentVersion cv = new ContentVersion();
        cv.VersionData = EncodingUtil.base64Decode(signatureDetails.base64_of_signature_file);
        cv.Title = signatureDetails.signature_file_name;
        cv.ExtId__c = signatureDetails.external_id;
        cv.PathOnClient = signatureDetails.signature_file_name;
  
        SFDCSecurityUtils.insertCheckCRUDAndFLS(cv, new List<String>{'VersionData','Title','ExtId__c','PathOnClient'});
        return cv;
      } 
      catch(Exception e) {
        return null;
      }
    }
  
    private static ContentDocumentLink createContentLink(String contentVersionId, String recordId) {
      try {
      ContentDocumentLink cdl = new ContentDocumentLink();
      cdl.ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =: contentVersionId].ContentDocumentId;
      cdl.LinkedEntityId = recordId;
      
      SFDCSecurityUtils.insertCheckCRUDAndFLS(cdl, new List<String>{'LinkedEntityId','ShareType'});
      return cdl;
      } 
      catch(Exception ex) {
        return null;
      }
  }

  private static void updateBankAccountRecord(ContentVersion cv, String recordId) {
    try {
      List<String> queryFields = new List<String> {
        'Id',
        'Signature_Block__c'
      };
      String queryCondition = 'Id = \'' +  recordId +  '\'';
     
      SOQLBuilder theQuery = new SOQLBuilder(Bank_Account__c.SObjectType);
      theQuery
          .assertIsAccessible()
          .setEnforceFLS(true)
          .selectFields(queryFields)
          .setCondition(queryCondition);

      Bank_Account__c bc = (Bank_Account__c)Database.query(theQuery.toSOQL());
      bc.Signature_Block__c= cv.ExtId__c;
      SFDCSecurityUtils.updateCheckCRUDAndFLS(bc, new List<String>{'Signature_Block__c'});
    }
    catch(Exception e) {
      throw new BankAccountFileUploadException(BANK_ACCOUNT_SIGNATURE_BLOCK_ERROR);
    }
}

  public class BankAccountSignatureWrapper
  {
      @AuraEnabled
      public String signature_file_name;
      @AuraEnabled
      public String base64_of_signature_file;
      @AuraEnabled
      public String record_id;
      @AuraEnabled
      public String external_id;
  }
}