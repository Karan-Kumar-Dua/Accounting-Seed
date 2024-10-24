public with sharing class AccountingSeedHubService {

    private static final String ERROR = Label.ERROR;
    private static final String DETAILS = Label.DETAILS;
    
    public AccountingSeedHubService() {

    }

    public static Map<String, Object> getAccessTokenAccountingHub(String authCode) {
        try {
            Map<String, String> headers = new Map<String, String>();
            HttpResponse response;

            String endPoint = AccountingSeedHubHelper.baseURI + '/services/oauth2/token?code=' + authCode + '&grant_type=authorization_code&';
            endPoint += 'client_id=' + AccountingSeedHubHelper.CLIENT_ID + '&client_secret=' + AccountingSeedHubHelper.CLIENT_SECRET + '&redirect_uri=' + AccountingSeedHubHelper.SITE_URL;
            response = HttpHandler.post(endPoint, headers, '');
            
            if(response.getStatusCode() == 200){
               return ( Map< String, Object> )JSON.deserializeUntyped( response.getBody() );
            }
            else{
                String fullError = handleOAuthErrors(response);
                throw new AccountingSeedHubHelper.AccountingSeedHubException(ERROR + ': ' + response.getStatusCode() + DETAILS + ': ' + fullError);
            }
        }
        catch (AccountingSeedHubHelper.AccountingSeedHubException exp) {
            throw exp;
        }
        catch (Exception e) {
            throw new AccountingSeedHubHelper.AccountingSeedHubException(e.getMessage()+' '+e.getLineNumber());
        }
    }

    public static string getAuthenticateUserName(String authCode) {
        try {
            Map < String, Object > resultMap = getAccessTokenAccountingHub(authCode);
            Map<String, String> headers = new Map<String, String>();
            HttpResponse response;
            
            String id =( String )resultMap.get( 'id' );
            String orgId = id.split('id/')[1].split('/')[0];
            String usrId = id.split('id/')[1].split('/')[1];
            
            String endPoint = AccountingSeedHubHelper.baseURI + '/id/' + orgId + '/' + usrId;
            headers.put('Authorization', 'Bearer '+ ( String )resultMap.get( 'access_token' ));
            response = HttpHandler.post(endPoint, headers, '');

            if(response.getStatusCode() == 200){
               resultMap = ( Map< String, Object> )JSON.deserializeUntyped( response.getBody() );
            }
            else{
                String fullError = handleOAuthErrors(response);
                throw new AccountingSeedHubHelper.AccountingSeedHubException(ERROR + ': ' + response.getStatusCode() + DETAILS + ': ' + fullError);
            }
            
            return ( String )resultMap.get( 'username' );
        }
        catch (AccountingSeedHubHelper.AccountingSeedHubException exp) {
            throw exp;
        }
        catch (Exception e) {
            throw new AccountingSeedHubHelper.AccountingSeedHubException(e.getMessage()+' '+e.getLineNumber());
        }
    }

    public static String handleOAuthErrors(HttpResponse response) {
        Map< String, Object> errMap = ( Map< String, Object> )JSON.deserializeUntyped( response.getBody() );
        return ( String )errMap.get('error') +' '+ ( String )errMap.get('error_description');
    }
}