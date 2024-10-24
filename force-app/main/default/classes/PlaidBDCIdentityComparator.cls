/*
* This class was created to:
*     -- Determine whether or not a new item is an attempt to link an item that already exists
*     -- Determine what action should be taken when a match is found. 
*/
public class PlaidBDCIdentityComparator{
    private static final String ERR_BDC_NAME_TEMPL = Label.BDC_CONNECTION_NAME_TEMPLATE;

        //For some banks, logins are directly overwritten by the bank when the same login is detected. The same must be done to the access tokens.

    /*
    *  given a list of new access tokens return a map of the financial institution id to all access tokens for the institution
    */
    public static Map<String, List<BDC_Access_Tokens__c>> groupAccessTokensByInstitution(List<BDC_Access_Tokens__c> allTokens) {

        if (allTokens == null || allTokens.isEmpty()){
            return null;
        }
        Map<String, List<BDC_Access_Tokens__c>> institutionIdToTokens = new Map<String, List<BDC_Access_Tokens__c>>();
        for (BDC_Access_Tokens__c aToken : allTokens) {
            List<BDC_Access_Tokens__c> instList = institutionIdToTokens.get(aToken.Financial_Institution_Id__c);
            if (instList == null) {
                instList = new List<BDC_Access_Tokens__c>();
                institutionIdToTokens.put(aToken.Financial_Institution_Id__c, instList);
            }
            instList.add(aToken);
        }
        return institutionIdToTokens;
    }

    /*
    *  returns a map from an existing access token's item id to its token
    */
    public static Map<String, BDC_Access_Tokens__c> getIdentityIdToTokenMap() {
        Map<String, BDC_Access_Tokens__c> idenIdsToTokens = new Map<String, BDC_Access_Tokens__c>();
        List<BDC_Access_Tokens__c> accessTokens = BDC_Access_Tokens__c.getAll().values();
        for (BDC_Access_Tokens__c aToken : accessTokens) {
           idenIdsToTokens.put(aToken.Financial_Institution_Identity_Id__c, aToken); 
        }
        return idenIdsToTokens;
    }

    /*
    *  returns a map from an existing access token's item id to the identity name
    */
    public static Map<String, String> getIdentityIdToIdentityNameMap() {
        Map<String, String> idenIdsToName = new Map<String, String>();
        List<BDC_Access_Tokens__c> accessTokens = BDC_Access_Tokens__c.getAll().values();
        for (BDC_Access_Tokens__c aToken : accessTokens) {
           idenIdsToName.put(aToken.Financial_Institution_Identity_Id__c, aToken.Identity_Name__c); 
        }
        return idenIdsToName;
    }

    /*
    *  retrieves all existing connection names by institution id
    */
    private static Map<String, Set<String>> getConnectionNames() {
            Map<String, Set<String>> allCurrentConnectionNames = new Map<String, Set<String>>();
            //query for the existing tokens to ensure uniqueness
            List<BDC_Access_Tokens__c> allAccessTokens = BDC_Access_Tokens__c.getAll().values();
            for (BDC_Access_Tokens__c aToken : allAccessTokens) {
                if (allCurrentConnectionNames.get(aToken.Financial_Institution_Id__c) == null) {
                    allCurrentConnectionNames.put(aToken.Financial_Institution_Id__c, new Set<String>());
                }
                allCurrentConnectionNames.get(aToken.Financial_Institution_Id__c).add(aToken.Identity_Name__c);
        }
        return allCurrentConnectionNames;
    }

    /*
    *  returns a new connection name that does not exist in the given list
    *  if the given list is null, existing connections will be retrieved from the access tokens
    *  formatted as "Connection_#"
    */
    private static String createNewConnectionName(Set<String> existingConnectionNames) {
        if (existingConnectionNames == null || existingConnectionNames.isEmpty()) {
            return ERR_BDC_NAME_TEMPL + '1';
        }
        Integer counter = 1;
        String newConnectionName = ERR_BDC_NAME_TEMPL;
        while(true) {
            if (!existingConnectionNames.contains(newConnectionName + String.valueOf(counter))) {
                return newConnectionName + String.valueOf(counter);
            }
            counter++;
        }
        return null;
    }

    /*
    *  returns a map of identity ids to a List of new connection names for the given connections
    *  formatted as "Connection_#"
    */
    public static Map<String, List<String>> createNewConnectionNames(Map<String, Integer> instIdToNumberOfNewNames) {
        Map<String, Set<String>> institutionIdToConnectionName = getConnectionNames();
        Map<String, List<String>> newNames = new Map<String, List<String>>();
        for (String instId : instIdToNumberOfNewNames.keySet()) {
            Integer numberOfNames = instIdToNumberOfNewNames.get(instId);
            for (Integer nameCounter = 0; nameCounter < numberOfNames; nameCounter++) {
                //add the new name to the new name list
                String newName = createNewConnectionName(institutionIdToConnectionName.get(instId));
                if (newNames.get(instid) == null) {
                    newNames.put(instId, new List<String>());
                }
                newNames.get(instId).add(newName);

                //also add it to the existing names so it can be compared to subsequent names
                if (institutionIdToConnectionName.get(instid) == null) {
                    institutionIdToConnectionName.put(instId, new Set<String>());
                }
                institutionIdToConnectionName.get(instId).add(newName);
            }
        }
        return newNames;
    }

}