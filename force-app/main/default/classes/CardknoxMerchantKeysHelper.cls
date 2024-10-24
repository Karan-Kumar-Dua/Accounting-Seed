public with sharing class CardknoxMerchantKeysHelper {
    public static final String HIDDEN_VALUE = Label.CRDKNX_HIDDEN_VALUE;
    @AuraEnabled
    public static Keys getKeys(String externalKey){
        try {
            if(String.isBlank(externalKey)){
                return new Keys(externalKey);
            }
            Keys__c userKeys = Keys__c.getValues(externalKey);

            if(userKeys == null){
                return new Keys(externalKey);
            }
            return new Keys(userKeys);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    @AuraEnabled
    public static void upsertUserKeys(String jsonKeys, Id ppRecordId){
        try {
            Keys userKeyResp = (Keys)JSON.deserialize(jsonKeys, Keys.class);

            Keys__c userKeys = Keys__c.getValues(userKeyResp.externalKey);

            if(userKeys == null){
                userKeys = new Keys__c();
                userKeys.Name = userKeyResp.externalKey;
                userKeys.Value_1__c = userKeyResp.xKey;
                userKeys.Value_2__c = userKeyResp.iFieldsKey;
                userKeys.KeyId__c = userKeyResp.externalKey;
                SFDCSecurityUtils.insertProxy(userKeys);
            }else{
                userKeys.Value_1__c = userKeyResp.xKey == HIDDEN_VALUE ? userKeys.Value_1__c : userKeyResp.xKey;
                userKeys.Value_2__c = userKeyResp.iFieldsKey == HIDDEN_VALUE ? userKeys.Value_2__c : userKeyResp.iFieldsKey;
                SFDCSecurityUtils.updateProxy(userKeys);
            }

            //update Payment Processor Active Field
            SFDCSecurityUtils.updateProxy(new Payment_Processor__c (Id = ppRecordId, Active__c = true));

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    public class Keys{
        @AuraEnabled
        public String externalKey{get;set;}
        @AuraEnabled
        public String xKey{get;set;}
        @AuraEnabled
        public String iFieldsKey{get;set;}
        public Keys(Keys__c setting){
            this.externalKey = setting.Name;
            this.xKey = Label.CRDKNX_HIDDEN_VALUE; 
            this.iFieldsKey = Label.CRDKNX_HIDDEN_VALUE; 
        }
        public Keys(String externalKey){
            this.externalKey = externalKey;
            this.xKey = ''; 
            this.iFieldsKey = ''; 
        }
    }
}