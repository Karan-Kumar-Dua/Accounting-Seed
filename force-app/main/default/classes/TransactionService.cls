//======================================================================================================
// This class forms an integration point with an extension package we provide. The methods in this class can
// only be executed if the correct authorization key is included as a parameter. The authorization key
// is stored in a metadata type in both this package and our extension package.
//
// This class must execute in a without sharing context. This approach was discussed and vetted by Nitin Arya
// of the Salesforce Security review team. Please consult with him before failing us for the Security Review.
//======================================================================================================
global without sharing class TransactionService {

    public class TransactionServiceAuthorizationException extends Exception {}
    public static final String AUTHORIZATION_ERROR = Label.COMMON_AUTHORIZATION_ERROR;

    global static void createTransactions(List<Transaction__c> transactions, String authKey) {
        if (EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.TRANSACTION_CREATE_KEY))) != authKey) {
            throw new TransactionServiceAuthorizationException(AUTHORIZATION_ERROR);
        }
        TransactionActions.createTransactions(transactions);
    }

    global static void deleteTransactions(List<Transaction__c> transactions, String authKey) {
        if (EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.TRANSACTION_UPDATE_DELETE_KEY))) != authKey) {
            throw new TransactionServiceAuthorizationException(AUTHORIZATION_ERROR);
        }
        TransactionActions.deleteTransactions(transactions);
    }
}