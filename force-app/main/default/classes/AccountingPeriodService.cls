//======================================================================================================
// This class forms an integration point with an extension package we provide. The setStatus method can
// only be executed if the correct authorization key is included as a parameter. The authorization key
// is stored in a metadata type in both this package and our extension package.
//
// This class must execute in a without sharing context. This approach was discussed and vetted by Nitin Arya
// of the Salesforce Security review team. Please consult with him before failing us for the Security Review.
//======================================================================================================
global without sharing class AccountingPeriodService {

    public class ServiceAuthorizationException extends Exception {}
    public static final String AUTHORIZATION_ERROR = Label.COMMON_AUTHORIZATION_ERROR;

    global static void setStatus(List<Accounting_Period__c> acctPeriods, String status, String authKey) {

        if (EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY))) != authKey) {
            throw new ServiceAuthorizationException(AUTHORIZATION_ERROR);
        }

        for (Accounting_Period__c period : acctPeriods) {
            period.Status__c = status;
        }
        AccountingPeriodActions.isPreventUpdateOverride = true;
        SFDCSecurityUtils.updateProxy(acctPeriods);
        AccountingPeriodActions.isPreventUpdateOverride = false;
    }

}