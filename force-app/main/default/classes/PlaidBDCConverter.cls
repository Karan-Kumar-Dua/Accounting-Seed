public class PlaidBDCConverter extends AbstractBDCConverter {
    public static final String sourceString = 'Plaid';
    private static Map<String, BDC_Access_Tokens__c> financialInstitutionIdToAccessTokens;
    private static final String ERR_BDC_PLAID_API = Label.ERR_BDC_PLAID_API;
    @TestVisible
    private static final String plaidErrorNotReady = 'PRODUCT_NOT_READY';
    @TestVisible
    private static final String INSTITUTION_NOT_READY = Label.INSTITUTION_NOT_READY;
    private static final String UKNOWN_PLAID_ERROR_RESPONSE = Label.UKNOWN_PLAID_ERROR_RESPONSE;
    //this datetime is a consistent datetime for updating records
    private DateTime nowTime = System.DateTime.now();

    //represents a converted access token http response
    private with sharing class AccessTokenModel {
        public String access_token;
        public String item_id;
        public String request_id;
        
        public String error_code;
        public String error_message;
        public String error_type;
    }

    //the next two objects are for transactions
    private with sharing class TransactionModel {

        public String transaction_id;
        public String account_id;
        public String category_id;
        public Decimal amount;
        public Date PlaidDate;
        public Date authorized_date;
        public String name;
        public String iso_currency_code;
        public String merchant_name;
        public String check_number;
        public String transaction_type;
        public Boolean pending;
    }

    private with sharing class TransactionsResponse {
        public List<TransactionModel> transactions;
        public FinancialInstitutionIdentityModel item;
        public List<AccountModel> accounts;
        public Integer total_transactions;

    }

    //the next 3 objects are for accounts

    private with sharing class BalanceModel {
        public Decimal available;
        public Decimal current;
        public String iso_currency_code;
        public Decimal PlaidLimit;
    }


    private with sharing class AccountModel{
            public String account_id;
            public BalanceModel balances;
            public String mask;
            public String name;
            public String official_name;
            public String subtype;
            public String type;

    }

    private with sharing class AccountResponse {
        public List<AccountModel> accounts;
        public FinancialInstitutionIdentityModel item;
    }

    private with sharing class FinanciaInstitutionModel {
        public String institution_id;
        public String name;

    }

    private with sharing class FinanciaInstitutionResponse {
        public FinanciaInstitutionModel institution;
    }

    private with sharing class FinancialInstitutionIdentityModel {
        public String item_id;
        public String institution_id;

    }

    private with sharing class FinancialInstitutionIdentityResponse {
        public FinancialInstitutionIdentityModel item;
    }

    //when fully contructed, it represents the BDCCategory with references to its Child BDCCategories
    //This is an intermediary recursive object used to assign parent ids to the BDC Category object
    private with sharing class CategoryLayer {
        public BDCCategory theCategory;

        //A list of hierarchy name strings in order as returned by the api
        //The first represents the top layer of the hierarchy and the last is the name of this object
        //this will be used to construct and navigate the nameToSubCategoryMap
        public List<String> categoryHierarchy;

        //this will be used to find the correct Category parent Id
        public Map<String, CategoryLayer> nameToSubCategoryMap;

        //returns the layer number, top level layer is 0
        public Integer getLayerNumber() {
            return categoryHierarchy.size() - 1;
        }
        
    }

    private with sharing class CategoryModel {
        public String category_id;
        public List<String> hierarchy;
    }

    private with sharing class CategoriesResponse {
        public List<CategoryModel> categories;
    }

    private with sharing class PlaidErrorResponseModel {
        public String display_message;
        public String documentation_url;
        public String error_code;
        public String error_message;
        public String error_type;
        public String request_id;
        public String suggested_action;
    }

    private static String cleanJsonResponse(String json) {
        json = json.replaceAll('"transaction":', '"PlaidTransaction":');
        json = json.replaceAll('"date":', '"PlaidDate":');
        json = json.replaceAll('"currency":', '"PlaidCurrency":');
        json = json.replaceAll('"limit":', '"PlaidLimit":');
        return json;
    }

    public void updateNowTime() {
        this.nowTime = System.DateTime.now();
    } 

    /*
    * This function takes any number of Institution Ids and their corresponding access token responses.
    * It extracts the token, then saves them into a custom setting
    * The tokens will later be retrieved when making calls to the associated financial institution
    * If an access token for the institution already exists, the access token replaces the old access token.
    * Function returns True if all access tokens were saved successfully.
    */
    public void convertAccessTokens(Map<String, HttpResponse> institutionIdToAccessTokenResponses) {

        //break up the map by institution Id. Create a new name for each new connection to an institution.
        //currently, it is assumed here that only one connection per institution can be created at a time.
        Map<String, Integer> instIdToNumberToCreate = new Map<String, Integer>();
        for (String instId : institutionIdToAccessTokenResponses.keySet()) {
            instIdToNumberToCreate.put(instId, 1);
        }

        //create a new connection name for each of the responses
        Map<String, List<String>> newConnectionNames = PlaidBDCIdentityComparator.createNewConnectionNames(instIdToNumberToCreate);

        //convert all the responses, save the institution ids in a list for later
        List<BDC_Access_Tokens__c> bdcAccessTokens = new List<BDC_Access_Tokens__c>();
        for (String instId: institutionIdToAccessTokenResponses.keySet()) {
            HttpResponse response = institutionIdToAccessTokenResponses.get(instId);

            AccessTokenModel atModel= (AccessTokenModel) JSON.deserialize(
                cleanJsonResponse(response.getBody()),
                AccessTokenModel.class
            );

            if (atModel.error_message != null || atModel.error_message != null) {
                String errorMessage = '';
                if (atModel.error_code != null) {errorMessage += atModel.error_code + ': ';}
                if (atModel.error_message != null) {errorMessage += atModel.error_message;}
                throw new BDCService.BDCException(errorMessage);
            }


            BDC_Access_Tokens__c aToken = new BDC_Access_Tokens__c();
            aToken.Financial_Institution_Identity_Id__c = atModel.item_id;
            aToken.Financial_Institution_Id__c = instId;
            aToken.Identity_Name__c = newConnectionNames.get(instId)[0];
            aToken.name = aToken.Financial_Institution_Identity_Id__c;
            aToken.Source__c = PlaidBDCConverter.sourceString;
            aToken.Token__c = atModel.access_token;
            bdcAccessTokens.add(aToken);

        }
        try {
            SFDCSecurityUtils.insertProxy(bdcAccessTokens);

        } catch (Exception e){
            throw e;

        }

    }

    /*
    * Method to convert Transations into specified data model
    */
    public override BDCServiceResult convertTransactions(List<HttpResponse> responses) {
        List<ResponsePair> responsesAndIdentities = new List<ResponsePair>();
        for (HttpResponse response : responses) {
            String delimiter = ';';
            //parse out the identity

            ResponsePair newPair = new ResponsePair();
            newPair.identifier = response.getBody().substringAfterLast(delimiter);
            //change the body to its original form
            newPair.response = response;
            newPair.response.setBody(response.getBody().substringBeforeLast(delimiter));
            responsesAndIdentities.add(newPair);
        }
        Map<String, BDC_Access_Tokens__c> idenIdToAccToken = PlaidBDCIdentityComparator.getIdentityIdToTokenMap();

        List<BDCServiceResult.BDCError> bdcErrors = new List<BDCServiceResult.BDCError>();
        List<BDCTransaction> convertedTransactions = new List<BDCTransaction>();
        //alsoadd accounts to the returned object so they can later be used to update the GLAMs
        List<BDCAccount> convertedAccounts = new List<BDCAccount>();
        Integer totalTransactions = 0;

        for (ResponsePair resPair : responsesAndIdentities) {

            HttpResponse response = resPair.response;

            if(response.getStatusCode() == 200){
                try {
                    //first convert the response to a usable Plaid specfic object
                    TransactionsResponse tResponse = (TransactionsResponse) JSON.deserialize(
                        cleanJsonResponse(response.getBody()),
                        TransactionsResponse.class
                    );
                    totalTransactions = tResponse.total_transactions;

                    //the accounts are also passed in the response. Parse them and use some of the info from them to populate transactions.
                    //this data structure is used to populate some info on the transactions
                    Map<String, AccountModel> accountIdToObject = new Map<String, AccountModel>();


                    for (AccountModel accModel : tResponse.accounts) {
                        accountIdToObject.put(accModel.account_id, accModel);
                        BDCAccount bdcAccModel = convertAccountModelToBDCAccount(accModel, tResponse.item);
                        convertedAccounts.add(bdcAccModel);
                    }

                    //then convert each transaction object to a BDC Transaction model
                    for (TransactionModel tModel :  tResponse.transactions){ 
                        //skip pending transactions
                        if (tModel.pending) {
                            continue;
                        }
                        BDCTransaction aTransaction = new BDCTransaction();
                        aTransaction.id = tModel.transaction_id;
                        aTransaction.accountId = tModel.account_id;
                        aTransaction.categoryId = tModel.category_id;
                        aTransaction.amount = tModel.amount;
                        if (tModel.authorized_date != null) {
                            aTransaction.transactionDate = tModel.authorized_date;
                        } else {
                            aTransaction.transactionDate = tModel.PlaidDate;
                        }
                        aTransaction.postDate = tModel.PlaidDate;
                        aTransaction.description = tModel.name;
                        aTransaction.currencyIsoCode = tModel.iso_currency_code;
                        aTransaction.merchantName = tModel.merchant_name;
                        aTransaction.checkNumber = tModel.check_number;
                        aTransaction.type = tModel.transaction_type;
                        //check to make sure the account was returned to set base type and container
                        if (tModel.account_id != null && accountIdToObject.get(tModel.account_id) != null && accountIdToObject.get(tModel.account_id).type != null) {
                            AccountModel associatedAccount = accountIdToObject.get(tModel.account_id);
                            //set the base type according to the amount's sign and account type. Then remove that sign.
                            /* below are the 4 types of accounts.
                            credit: Credit card
                            depository: Depository account
                            loan: Loan account
                            other: Non-specified account type
                            */
                            if (associatedAccount.type == 'credit') {
                                if (aTransaction.amount >= 0) {
                                    aTransaction.baseType = 'Debit';
                                } else {
                                    aTransaction.baseType = 'Credit';
                                }
                            } else {
                                //the sign of the amount from Plaid is based on whether money moves in or out of the account. Not the account type.
                                //in Accounting seed however, the type of account determines whether the value is a debit or credit.
                                //Flip the sign here to accomodate this.
                                aTransaction.amount = aTransaction.amount * -1;
                                if (aTransaction.amount >= 0) {
                                    aTransaction.baseType = 'Credit';
                                } else {
                                    aTransaction.baseType = 'Debit';
                                }
                            }
                            aTransaction.amount = aTransaction.amount.abs();
                            aTransaction.container = associatedAccount.type;
                        }

                        convertedTransactions.add(aTransaction);
                    }
                } catch (Exception exp) {
                    bdcErrors.add(createError(response.getBody()));
                }
            }

            else {
                try {
                    //attempt to fit the response to the error object.
                    PlaidErrorResponseModel tResponse = (PlaidErrorResponseModel) JSON.deserialize(
                        cleanJsonResponse(response.getBody()),
                        PlaidErrorResponseModel.class
                    );
                    String errorCode = tResponse.error_code;
                    String errorMessage = tResponse.error_message;
                    String fullError = '';
                    //custom error messaging
                    if (errorCode == PlaidBDCConverter.plaidErrorNotReady) {
                        fullError = idenIdToAccToken.get(resPair.identifier).Identity_Name__c + ' ' + PlaidBDCConverter.INSTITUTION_NOT_READY;
                    } else {
                        fullError = idenIdToAccToken.get(resPair.identifier).Identity_Name__c + ' ' + errorCode + ': ' + errorMessage;
                    }
                    EventPubSub.publish(
                        EventPubSub.createEvent(
                            EventPubSub.PublishDelay.IMMEDIATE,
                            EventRegistry.RegisteredEvent.BANK_TRANSACTIONS_ERROR,
                            FinancialSuiteUtils.getUUID(),
                            fullError
                        )
                    );
                    throw new BDCService.BDCException(fullError);
                }
                catch (BDCService.BDCException exp) {
                    throw exp;
                }
                catch (Exception exp) {
                    throw new BDCService.BDCException(PlaidBDCConverter.UKNOWN_PLAID_ERROR_RESPONSE);
                }

            }
        }
        
        BDCDataModel dataModel = new BDCDataModel();
        dataModel.bdcTransactions = convertedTransactions;
        dataModel.bdcAccounts = convertedAccounts;
        dataModel.totalTransactions = totalTransactions;

        return checkAPIError(dataModel,bdcErrors,responses.size());
    }

    private BDCAccount convertAccountModelToBDCAccount(AccountModel acctModel, FinancialInstitutionIdentityModel finInstIdenModel) {
        BDCAccount newBdcAccount = new BDCAccount();
        newBdcAccount.Id = acctModel.account_id;
        newBdcAccount.name = acctModel.official_name;
        newBdcAccount.nickname = acctModel.name;
        newBdcAccount.accountType = acctModel.type;
        newBdcAccount.maskedAccountNumber = acctModel.mask;
        newBdcAccount.source = PlaidBDCConverter.sourceString;
        newBdcAccount.lastRefreshDate = this.nowTime.date();
        newBdcAccount.currentBalance = acctModel.balances.current;
        newBdcAccount.availableBalance = acctModel.balances.available;
        newBdcAccount.bdcCurrencyISOCode = acctModel.balances.iso_currency_code;
        newBdcAccount.lastUpdated = this.nowTime;
        newBdcAccount.financialInstitutionIdentity = finInstIdenModel.item_id;
        newBdcAccount.financialInstitutionId = finInstIdenModel.institution_id;
        return newBdcAccount;
    }
 
    /*
    * Method to convert Accounts into specified data model
    */
    public override BDCServiceResult convertAccounts(List<HttpResponse> responses){
        List<BDCServiceResult.BDCError> bdcErrors = new List<BDCServiceResult.BDCError>();
        List<BDCAccount> convertedAccounts = new List<BDCAccount>();

        for (HttpResponse response : responses) {

            if(response.getStatusCode() == 200){
                //first convert the response to a usable Plaid specfic object
                AccountResponse acctResponse = (AccountResponse) JSON.deserialize(
                cleanJsonResponse(response.getBody()),
                AccountResponse.class
                );

                //then convert each Account object to a BDC Account model
                for (AccountModel acctModel : acctResponse.accounts) {
                    BDCAccount newBdcAccount = convertAccountModelToBDCAccount(acctModel, acctResponse.item);
                    convertedAccounts.add(newBdcAccount);
                }
            }
            
            else {
                bdcErrors.add(createError(response.getBody()));
           }
        }

        BDCDataModel dataModel = new BDCDataModel();
        dataModel.bdcAccounts = new List<BDCAccount>(convertedAccounts);

        return checkAPIError(dataModel,bdcErrors,responses.size());
    }

    /*
    * Method to convert Financial Institution into specified data model
    */
    public override BDCServiceResult convertFinancialInstitutions(List<HttpResponse> responses){
        List<BDCFinancialInstitution> convertedFinInsts = new List<BDCFinancialInstitution>();
        List<BDCServiceResult.BDCError> bdcErrors = new List<BDCServiceResult.BDCError>();

        for (HttpResponse response : responses) {

            if(response.getStatusCode() == 200){
                //first convert the response to a usable Plaid specfic object
                FinanciaInstitutionResponse finInstresponse = (FinanciaInstitutionResponse) JSON.deserialize(
                    response.getBody(),
                    FinanciaInstitutionResponse.class
                );

                //then convert each transaction object to a BDC Transaction model
                BDCFinancialInstitution bdcObject = new BDCFinancialInstitution();
                bdcObject.id = finInstResponse.institution.institution_id;
                bdcObject.name = finInstResponse.institution.name;
                bdcObject.source = PlaidBDCConverter.sourceString;
                convertedFinInsts.add(bdcObject);
            }

            else {
                bdcErrors.add(createError(response.getBody()));
            }
        }

        BDCDataModel dataModel = new BDCDataModel();
        dataModel.bdcFinancialInstitutions = new List<BDCFinancialInstitution>(convertedFinInsts);

        return checkAPIError(dataModel,bdcErrors,responses.size());

    }


    /*
    * a private class to decorate the HttpResponse class
    */
    private class ResponsePair {
        public String identifier;
        public HttpResponse response;
    }

    

    /*
    * Method to convert Financial Institution Identities into specified data model
    */
    public override BDCServiceResult convertFinancialInstitutionIdentities(List<HttpResponse> responses){
        //responses resulting in error do not necessarily contain the associated identity
        //Parse the financial institution identity Id (added to the body in the connector) to properly associate any errors to relevant identities
        List<ResponsePair> responsesAndIdentities = new List<ResponsePair>();
        for (HttpResponse response : responses) {
            String delimiter = ';';
            //parse out the identity

            ResponsePair newPair = new ResponsePair();
            newPair.identifier = response.getBody().substringAfterLast(delimiter);
            //change the body to its original form
            newPair.response = response;
            newPair.response.setBody(response.getBody().substringBeforeLast(delimiter));
            responsesAndIdentities.add(newPair);
        }

         List<BDCServiceResult.BDCError> bdcErrors = new List<BDCServiceResult.BDCError>();
         List<BDCFinancialInstitutionIdentity> convertedFinancialInstitutionIdentities = new List<BDCFinancialInstitutionIdentity>();

        Map<String, BDC_Access_Tokens__c> identityIdToToken = PlaidBDCIdentityComparator.getIdentityIdToTokenMap();
        
        for (ResponsePair resPair : responsesAndIdentities) {
            HttpResponse response = resPair.response;

            if(response.getStatusCode() == 200){
                //first convert the response to a usable Plaid specfic object
                FinancialInstitutionIdentityResponse fResponse = (FinancialInstitutionIdentityResponse) JSON.deserialize(
                    cleanJsonResponse(response.getBody()),
                    FinancialInstitutionIdentityResponse.class
                );

                BDCFinancialInstitutionIdentity bdcObject = new BDCFinancialInstitutionIdentity();
                bdcObject.id = fResponse.item.item_id;
                bdcObject.financialInstitutionid = fResponse.item.institution_id;
                //since the identity name is created internally, names are managed in the access token object but not in Plaid.
                //Use a map to re-establish the relationship between the idenity name on the corresponding access token
                bdcObject.identityName = identityIdToToken.get(fResponse.item.item_id).Identity_Name__c;
                bdcObject.status = 'OK';
                bdcObject.source = PlaidBDCConverter.sourceString;
                convertedFinancialInstitutionIdentities.add(bdcObject);
            }

            else {
                //If the response is in error, use the existing access token to populate the info so that users can still interact with the identity/connection
                BDC_Access_Tokens__c existingToken = identityIdToToken.get(resPair.identifier);
                BDCFinancialInstitutionIdentity bdcObject = new BDCFinancialInstitutionIdentity();
                bdcObject.id = existingToken.Financial_Institution_Identity_Id__c;
                bdcObject.financialInstitutionid = existingToken.Financial_Institution_Id__c;
                bdcObject.identityName = existingToken.Identity_Name__c;
                //Ideally this should come from the error response
                bdcObject.status = 'Bad Request';
                bdcObject.source = PlaidBDCConverter.sourceString;

                convertedFinancialInstitutionIdentities.add(bdcObject);

                //add to bdc errors to warn the user
                bdcErrors.add(createError(existingToken.Identity_Name__c + ': ', response.getBody()));
            }
        }

        //always return as a success so the identities can be interacted with, but include the error list regardless
        BDCDataModel dataModel = new BDCDataModel();
        dataModel.bdcFinancialInstitutionIdentities = convertedFinancialInstitutionIdentities;
        return new BDCServiceResult(dataModel,true,bdcErrors);
    }

    /* 
    *  
    * The purpose of the category converter function is to convert the http response returned by Plaid. 
    * The BDCCategory object contains 4 instance variables:
    * 
    *    -Id
    *    -Name
    *    -Source
    *    -parentCategoryId
    *
    * Populating the first 3 is trivial, however populating the parentCategoryId is difficult because of the format of the response. 
    * Each category in the response has a Hierarchy which defines the place of the category in a polytree with an ordered list of names. 
    * The conversion function creates this graph and uses the graph to define the parentCategoryId.
    *
    * There are a few considerations taken into account when creating the tree.
    *
    *    -Ids are unique
    *    -Names are not unique at any level, but categories with the same parent category must have a unique name
    *    -The categories may be in any order. Although the responses seem to be ordered with parent categories being defined first, there no documentation guaranteeing this. Therefore, the algorithm was programmed without assuming order.
    *    -The agorithm does not assume any number of layers. However, the Plaid api seems to only go to 3 layers maximum.
    *
    */
    public override BDCServiceResult convertCategories(List<HttpResponse> responses){
        List<BDCServiceResult.BDCError> bdcErrors = new List<BDCServiceResult.BDCError>();
        Map<String, BDCCategory> convertedCategories = new Map<String, BDCCategory>();

        for (HttpResponse response : responses) {
            if(response.getStatusCode() == 200){
                //first convert the responses to the category models
                CategoriesResponse cResponse = (CategoriesResponse ) JSON.deserialize(
                    cleanJsonResponse(response.getBody()),
                    CategoriesResponse.class
                );

                Map<String, CategoryLayer> categoryParentReferenceMap = new Map<String, CategoryLayer>();
                List<CategoryLayer> allCategoryLayers = new List<CategoryLayer>();
                for (CategoryModel cModel : cResponse.categories) {

                    //first start constructing each of BDCcategory objects except the parent Id
                    BDCCategory newCategory = new BDCCategory();
                    newCategory.Id = cModel.category_id;
                    newCategory.name = cModel.hierarchy[cModel.hierarchy.size() - 1];
                    newCategory.source = PlaidBDCConverter.sourceString;


                    CategoryLayer newLayer = new CategoryLayer();
                    newLayer.theCategory = newCategory;
                    newLayer.categoryHierarchy = cModel.hierarchy;
                    newLayer.nameToSubCategoryMap = new Map<String, CategoryLayer>();


                    //set up the top layer so that there is a starting point for the map
                    if (newLayer.getLayerNumber() == 0) {
                        categoryParentReferenceMap.put(newLayer.theCategory.name, newLayer);
                    }

                    allCategoryLayers.add(newLayer);
                }

                //now that the Category layers are constructed
                //loop through each category and add them to the map according to the hierarchy
                for (CategoryLayer targetNewLayer : allCategoryLayers) {

                    //if it's a first level category, skip it
                    if (targetNewLayer.categoryHierarchy.size() == 1) {
                        continue;
                    }

                    //start at the top of the hierarchy tree, these were set up above
                    //navigate through the hierarchy with the hierarchy names
                    //either creating or navigating the structure
                    CategoryLayer currentLayer = categoryParentReferenceMap.get(targetNewLayer.categoryHierarchy[0]);
                    for (Integer hierarchyLayerIndex = 1; hierarchyLayerIndex < targetNewLayer.categoryHierarchy.size(); hierarchyLayerIndex++) {
                        //if we are at the layer right above the targetLayer, assign the subcategory map to have the target layer as the child
                        if (hierarchyLayerIndex == targetNewLayer.categoryHierarchy.size() -1) {
                            //currentLayer.theCategory = targetNewLayer.theCategory;
                            //currentLayer.categoryHierarchy = targetNewLayer.categoryHierarchy;
                            currentLayer.nameToSubCategoryMap.put(targetNewLayer.theCategory.name, targetNewLayer);
                            break;
                        }

                        //make sure the layer has a name to subCategory map defined.
                        //TODO maybe not necessary
                        if (currentLayer.nameToSubCategoryMap == null) {
                            currentLayer.nameToSubCategoryMap = new Map<String, CategoryLayer>();
                        }

                        
                        //check if the next layer exist, and create a placeholder if it does not
                        if (currentLayer.nameToSubCategoryMap.get(targetNewLayer.categoryHierarchy[hierarchyLayerIndex]) == null) {
                            CategoryLayer placeHolderLayer = new CategoryLayer();
                            placeHolderLayer.nameToSubCategoryMap = new Map<String, CategoryLayer>();
                            currentLayer.nameToSubCategoryMap.put(targetNewLayer.categoryHierarchy[hierarchyLayerIndex], placeHolderLayer);
                        } else {
                            //if it already exists, move to the next layer
                            currentLayer = currentLayer.nameToSubCategoryMap.get(targetNewLayer.categoryHierarchy[hierarchyLayerIndex]);
                        }

                    }
                }

                //Now that the tree has been constructed, use it as way to reference the parent Id of each BDCCategory
                for (CategoryLayer aCategoryLayer : allCategoryLayers) {
                    //define a current layer to traverse the map
                    CategoryLayer currentLayer = categoryParentReferenceMap.get(aCategoryLayer.categoryHierarchy[0]);

                    //no need to populate the parent id if it's a top level category
                    if (aCategoryLayer.categoryHierarchy.size() == 1) {
                        convertedCategories.put(aCategoryLayer.theCategory.Id, aCategoryLayer.theCategory);
                        continue;
                    }
                    //go to one level above the current category to get its parent
                    for (Integer categoryNameIndex = 1; categoryNameIndex < aCategoryLayer.categoryHierarchy.size() - 1 ; categoryNameIndex++) {
                        String categoryName = aCategoryLayer.categoryHierarchy[categoryNameIndex];
                        currentLayer = currentLayer.nameToSubCategoryMap.get(categoryName);
                    }
                    aCategoryLayer.theCategory.parentCategoryId =  currentLayer.theCategory.id;
                    convertedCategories.put(aCategoryLayer.theCategory.Id, aCategoryLayer.theCategory);
                }
            } 
            else {
               //If response is unsuccessfull then return the error
               bdcErrors.add(createError(response.getBody()));
            }
        }

        BDCDataModel dataModel = new BDCDataModel();
        dataModel.bdcCategories = new Map<String, BDCCategory>(convertedCategories);

        return checkAPIError(dataModel,bdcErrors,responses.size());
  
    }

    //Method to convert Financial Instituion Identity response
    public override BDCServiceResult convertDeleteFinancialInstitutionIdentity(List<HttpResponse> responses, BDCFinancialInstitutionIdentity finInstIden){
        BDCServiceResult result = new BDCServiceResult();
        
        //Get the response and iterate to find out the Success or Error
        //NOTE -: The response list should only contain one response for Plaid and 
        //        There will not going to be any situation where we will be having multiple responses for delete.
        for(HttpResponse response : responses){
            if(response.getStatusCode() == 200){
                result.isSuccess = true;
            }  
            else {

                //If response is unsuccessfull then return the error
                result = new BDCServiceResult(null,false,new BDCServiceResult.BDCError[]{createError(response.getBody())});
            }
        }

        //Even if the delete call fails, delete the old acccess token since Plaid may have no record of this
        deleteBDCAccessToken(finInstIden);

        return result;
    }

    //Method to delete the custom setting for Access token of Plaid
    private static void deleteBDCAccessToken(BDCFinancialInstitutionIdentity finInstIden) {
        List<BDC_Access_Tokens__c> accessToken = new List<BDC_Access_Tokens__c>();

        //Get the access token and add into delete list
        Map<String, BDC_Access_Tokens__c> accTokens = PlaidBDCConverter.getAccessTokens();
        for (BDC_Access_Tokens__c accToken : accTokens.values()) {
            if(accToken.Financial_Institution_Identity_Id__c == finInstIden.Id) {
                accessToken.add(accToken);
            }
        }

        //Deletion of acces tokens
        delete accessToken;
    }

    //Get Access Tokens
    private static Map<String, BDC_Access_Tokens__c> getAccessTokens() {
        refreshAccessTokens();
        return financialInstitutionIdToAccessTokens;
    }

    
    //Method queries any saved access tokens and saves then as a static member
    private static void refreshAccessTokens() {
        financialInstitutionIdToAccessTokens = new Map<String,BDC_Access_Tokens__c>();

        //Get existing Plaid Access Tokens
        for (BDC_Access_Tokens__c aTokenObject : BDC_Access_Tokens__c.getAll().values()) {
            financialInstitutionIdToAccessTokens.put(aTokenObject.Financial_Institution_Id__c, aTokenObject);
        }
    }

    //Method to check if API has error or not
    private static BDCServiceResult checkAPIError(BDCDataModel dataModel, List<BDCServiceResult.BDCError> bdcErrors, Integer responseSize) {
        if(responseSize == bdcErrors.size() && responseSize != 0) {
            return new BDCServiceResult(null,false,bdcErrors);
        }   
        else {
            return new BDCServiceResult(dataModel,true,bdcErrors);
        }     
    }

    private static BDCServiceResult.BDCError createError(String responseBody) {
         //If response is unsuccessfull then return the error
        PlaidErrorResponseModel fResponse = (PlaidErrorResponseModel) JSON.deserialize(responseBody,
        PlaidErrorResponseModel.class);

        return new BDCServiceResult.BDCError(ERR_BDC_PLAID_API +  ' ' + fResponse.request_id + '.');
    }

    private static BDCServiceResult.BDCError createError(String prefix, String responseBody) {
        PlaidErrorResponseModel fResponse = (PlaidErrorResponseModel) JSON.deserialize(responseBody,
        PlaidErrorResponseModel.class);

        return new BDCServiceResult.BDCError(prefix + ' ' + ERR_BDC_PLAID_API +  ' ' + fResponse.request_id + '.');
    }
}