public with sharing class AccountingSeedHubHelper { 
        
        public class AccountingSeedHubException extends Exception{}

        public static Final String CLIENT_ID = GlobalVariables.AccountingSeedHubSettings.Value_1__c + GlobalVariables.AccountingSeedHubSettings.Value_3__c;
        public static Final String CLIENT_SECRET = GlobalVariables.AccountingSeedHubSettings.Value_2__c;
        public static Final String SITE_URL = GlobalVariables.AccountingSeedHubSettings.Value_4__c;
        public static Final String baseURI = URL.getSalesforceBaseUrl().toExternalForm();

        public AccountingSeedHubHelper() {}

        @AuraEnabled
        public static string authorizeAccountingHub(){
            String authEndPoint = baseURI + '/services/oauth2/authorize?response_type=code&';
            authEndPoint += 'client_id=' + CLIENT_ID + '&redirect_uri=' + SITE_URL; 
            return authEndPoint;
        }

        @AuraEnabled
        public static Object authenticateAccountingHub(String authCode){
            try {
                return SaveAccountingSeedHubUsername( AccountingSeedHubService.getAuthenticateUserName(authCode) );
            }
             catch (Exception e) {
                throw new AccountingSeedHubException(e.getMessage()+' '+e.getLineNumber());
            }
        }

        public static Object SaveAccountingSeedHubUsername(String user_Name){
            try{
                Accounting_Settings__c acctSettings = AccountingSettingsHandler.getAccountingSettings();
                acctSettings.Hub_UserName__c = user_Name;
                SFDCSecurityUtils.updateCheckCRUDAndFLS(acctSettings, new List<String>{
                    'Hub_UserName__c'
                });

                return AccountingSettingsHelper.getSettings();
            }
            catch(Exception e){
                throw new AccountingSeedHubException(e.getMessage()+' '+e.getLineNumber());
            }
        }
        
        @AuraEnabled
        public static Object DeleteAccountingSeedHubUsername(){
            try{
                Accounting_Settings__c acctSettings = AccountingSettingsHandler.getAccountingSettings();
                acctSettings.Hub_UserName__c = null;
                SFDCSecurityUtils.updateCheckCRUDAndFLS(acctSettings, new List<String>{
                    'Hub_UserName__c'
                });

                return AccountingSettingsHelper.getSettings();
            }
            catch(Exception e){
                throw new AccountingSeedHubException(e.getMessage()+' '+e.getLineNumber());
            }
        }
    }