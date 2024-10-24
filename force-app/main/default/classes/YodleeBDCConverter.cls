public class YodleeBDCConverter extends AbstractBDCConverter {

    public static final String sourceApiName = 'Yodlee';
    private static final String ERR_BDC_YODLEE_API = Label.ERR_BDC_YODLEE_API;

    //ProviderAccount classes/methods are public so the connector can get the required info for other objects
    private with sharing class ProviderAccountModel {
        public String id;
        public String providerId;
        public DateTime createdDate;
        public String status;
        public String name;
        public DateTime lastUpdated;
        public List<DatasetModel> dataset;
    }

    private with sharing class ProviderAccountsResponse {
        public List<ProviderAccountModel> providerAccount;
    }

    public with sharing class ProvidersResponse {
        public List<ProviderModel> provider;
    }

    public with sharing class ProviderModel {
        public String id;
        public String name;
        public DateTime lastModified;
    }

    private with sharing class AccountModel {
        public String id;
        public String providerAccountId;
        public String providerName;
        /*
        CONTAINER:
        bank, creditCard, investment, insurance, loan, otherAssets, otherLiabilities, realEstate, reward, bill
        */
        public String container;
        public String accountName;
        public String nickname;
        public String accountNumber;
        public DateTime lastUpdated;
        public String accountType;
        public Money balance;
        public Money runningBalance;
        public Money availableBalance;
        public Money availableCredit;
        public Money currentBalance;
        public String accountStatus; //ACTIVE,INACTIVE,TO_BE_CLOSED,CLOSED
        public AutoRefreshModel autoRefresh;
        public List<DatasetModel> dataset;
    }

    private with sharing class AccountsResponse {
        public List<AccountModel> account;
    }
    private with sharing class TransactionsCountResponse {
        public TransactionModel yodleeTransaction;
    }

    private with sharing class TransactionModel {
        public TransactionsTotal TOTAL;

        //used in GET /transactions response
        public String accountId;
        public Money amount;
        public String baseType;
        public String container;
        public Date yodleeDate;
        public String id;
        public String memo;
        public Date postDate;
        public Date transactionDate;
        public String type;
        public TransactionDescription description;
        public Money runningBalance;
        public String parentCategoryId;
        public String subType;
        public String merchantType;
        public Merchant merchant;
        public String categoryType;
        public String highLevelCategoryId; 
        public String categoryId;
        public String detailCategoryId; 
        public String category; 
        public String checkNumber;
        public String status;
    }

    @TestVisible
    private with sharing class TransactionsResponse {
        private List<TransactionModel> yodleeTransaction;

        public List<TransactionModel> getTransactionModels(Boolean onlyPosted) {
            if (onlyPosted) {
                List<TransactionModel> onlyPostedTransactionModels = new List<YodleeBDCConverter.TransactionModel>();
                for (TransactionModel tm : yodleeTransaction) {
                    if (tm.status == 'POSTED') {
                        onlyPostedTransactionModels.add(tm);
                    }
                }
                return onlyPostedTransactionModels;
            } else {
                return yodleeTransaction;
            }
        }
    }

    private with sharing class FinancialInstitutionModel {
        private String id;
        private String name;
        private DateTime lastModified;
        private string status;
    }

    //used with Transaction
    private with sharing class Merchant {
        public String id;
        public String name;
        public List<String> categoryLabel;
        public Address address;
    }

    public with sharing class Address {
        public String country; //two letter valid ISO code
        public String address1;
        public String address2;
        public String address3;
        public String street;
        public String fullAddress;
        public String state;
        public String city;
        public String ZIP;
        public String type;
        public String sourceType;
    }

    //used with Transaction and Account
    private with sharing class Money {
        @AuraEnabled
        public Decimal amount;
        @AuraEnabled
        public String yodleeCurrency;

    }

    //used with Account
    private with sharing class AutoRefreshModel {
        public String status;
        public String additionalStatus;
        public DateTime asOfDate;
    }

    //used with Account
    public with sharing class DatasetModel {
        public String name;
        public DateTime nextUpdateScheduled;
        public String additionalStatus;
        public DateTime lastUpdateAttempt;

        public DatasetModel(String name, DateTime nextUpdateScheduled, DateTime lastupdateAttempt, String additionalStatus) {
            this.name = name;
            this.nextUpdateScheduled = nextUpdateScheduled;
            this.lastUpdateAttempt = lastUpdateAttempt;
            this.additionalStatus = additionalStatus;
        }

        public Boolean isAdditionalAuthenticationRequired() {
            return this.additionalStatus == 'ADDL_AUTHENTICATION_REQUIRED';
        }

        public Boolean isTokenExpired() {
            //nextUpdateScheduled does not update immediately when someone refreshes their credentials
            //so, if nextUpdateScheduled is NULL or in the past, check to see if the lastUpdateAttempt is greater than 48 hours ago            
            Boolean retVal;
            Boolean lastUpdateAttemptTooFarBack = this.lastUpdateAttempt != NULL ?
                ((DateTime.now().getTime() - this.lastUpdateAttempt.getTime()) / 3600000) > 24 :
                true;
            
            if (this.nextUpdateScheduled == NULL) {
                retVal = lastUpdateAttemptTooFarBack;                
            } else if (this.nextUpdateScheduled.getTime() > DateTime.now().getTime()){
                retVal = false;
            } else {
                retVal = lastUpdateAttemptTooFarBack;
            }
            return retVal;
        }
    }

    //used with Transaction
    private with sharing class TransactionDescription {
        public String original;
        public String simple;
    }

    private with sharing class TransactionsTotal {
        public Integer count;
    }

    private with sharing class TransactionCategoriesResponse {
        public List<TransactionCategoryModel> transactionCategory;
    }

    private with sharing class TransactionCategoryModel {
        public Integer id;
        public String category;
        public Integer highLevelCategoryId;
        public String highLevelCategoryName;
        public String source;
        public String classification;
        public String type;
        public List<TransactionDetailCategory> detailCategory;
    }

    private with sharing class TransactionDetailCategory {
        public Integer id;
        public String name;
    }


    //some of the JSON keys have names which are reserved keywords in APEX
    //that is why we need substitute some of them
    private static String cleanJsonResponse(String json) {
        json = json.replaceAll('"transaction":', '"yodleeTransaction":');
        json = json.replaceAll('"date":', '"yodleeDate":');
        json = json.replaceAll('"currency":', '"yodleeCurrency":');
        json = json.replaceAll('"currency" :', '"yodleeCurrency":');
        return json;
    }

	public override BDCServiceResult convertFinancialInstitutionIdentities(List<HttpResponse> responses){
        BDCServiceResult serviceResult = new BDCServiceResult();
        //create a list of general object to return
        List<BDCFinancialInstitutionIdentity> finInstIdens = new List<BDCFinancialInstitutionIdentity>();

        //convert the response to a usable Yodlee specfic object
        for (HttpResponse response : responses) {
            ProviderAccountsResponse providerAccountResponse = (ProviderAccountsResponse) JSON.deserialize(
                response.getBody(),
                ProviderAccountsResponse.class
            );

            //providerAccountResponse can return empty if no Accounts have been linked
            if(response.getStatusCode() != 200 || providerAccountResponse?.providerAccount == null ){ 
                continue;
            }

            //convert the Yodlee specific object to the general object
            for (ProviderAccountModel pam : providerAccountResponse.providerAccount) {
                BDCFinancialInstitutionIdentity aNewIden = new BDCFinancialInstitutionIdentity();
                aNewIden.Id = pam.Id;
                aNewIden.financialInstitutionId = pam.providerId;
                aNewIden.status = pam.status;
                aNewIden.source = YodleeBDCConverter.sourceApiName;
                
                //todo iron this out potentially populate additionalStatus List 
                if (pam.status == BankTransactionsHelper.PROVIDER_STATUS_FAILED) {
                    for (DatasetModel dataset : pam.dataset) {
                        if (dataset.name == 'BASIC_AGG_DATA' && dataset.isAdditionalAuthenticationRequired()){
                            aNewIden.status = BankTransactionsHelper.PROVIDER_STATUS_USER_INPUT_REQUIRED;
                        }
                    }                            
                }
                if (pam.status != BankTransactionsHelper.PROVIDER_STATUS_FAILED && pam.status != BankTransactionsHelper.PROVIDER_STATUS_USER_INPUT_REQUIRED) {
                    for (DatasetModel dataset : pam.dataset) {
                        if (dataset.name == 'BASIC_AGG_DATA' && dataset.isTokenExpired()) {
                            aNewIden.status = BankTransactionsHelper.PROVIDER_STATUS_USER_INPUT_REQUIRED;        
                        }
                    }                                                       
                }
                finInstIdens.add(aNewIden);
            }
    
        }

        serviceResult.isSuccess = true;
        BDCDataModel dataModel = new BDCDataModel();
        dataModel.bdcFinancialInstitutionIdentities = new List<BDCFinancialInstitutionIdentity>(finInstIdens);
        serviceResult.data = dataModel;

        return serviceResult;
    }

	public override BDCServiceResult convertTransactions(List<HttpResponse> responses){
        BDCServiceResult serviceResult = new BDCServiceResult();
        List<BDCTransaction> convertedTransactions = new List<BDCTransaction>();

        for (HttpResponse response : responses) {

            //first convert the response to a usable Yodlee specfic object
            TransactionsResponse tResponse = (TransactionsResponse) JSON.deserialize(
                cleanJsonResponse(response.getBody()),
                TransactionsResponse.class
            );

            List<TransactionModel> tModels = tResponse.getTransactionModels(true);
            //Transactions can return null if no transactions have been linked
            if(response.getStatusCode() != 200 || tResponse == null || tModels == null) { 
                continue;
            }

            //then convert each transaction object from response to general BDC Transaction model
            for (TransactionModel tModel :  tModels){ 
                BDCTransaction aTransaction = new BDCTransaction();
                aTransaction.Id = tModel.Id;
                aTransaction.accountId = tModel.accountId;
                aTransaction.amount = tModel.amount.amount;
                aTransaction.transactionDate = tModel.transactionDate != NULL ? tModel.transactionDate : tModel.yodleeDate ;
                aTransaction.postDate = tModel.postDate;
                aTransaction.description = tModel?.description?.original;
                aTransaction.shortDescription =  (tModel.description != NULL) ? tModel.description.simple : NULL;
                aTransaction.checkNumber = tModel.checkNumber;        
                aTransaction.runningBalance = (tModel.runningBalance != null)? tModel.runningBalance.amount: 0;
                aTransaction.currencyIsoCode = (tModel?.amount?.yodleeCurrency != null) ? tModel.amount.YodleeCurrency : MultiCurrencyHandler.CORPORATE_CURRENCY;
                aTransaction.merchantName = tModel?.merchant?.name;
                aTransaction.merchantType = tModel.merchantType;
                aTransaction.merchantCategory =  (tModel.merchant != NULL && tModel.merchant.categoryLabel != NULL)
                                                ? FinancialSuiteUtils.trunc(String.join(tModel.merchant.categoryLabel, ','), 255) 
                                                : NULL;          
                aTransaction.merchantId = (tModel.merchant != NULL) ? tModel.merchant.id : NULL;
                aTransaction.merchantType = tModel.merchantType;
                aTransaction.type = tModel.type;
                aTransaction.memo = tModel.memo;
                aTransaction.status = tModel.status;
                aTransaction.GLAccountMappingId = null;
                aTransaction.source = YodleeBDCConverter.sourceApiName;
                aTransaction.container = tModel.container;
                aTransaction.baseType = tModel.baseType;
                aTransaction.categoryType = tModel.categoryType;
                aTransaction.categoryId = tModel.categoryId;
                aTransaction.categoryLevel1Id = tModel.highLevelCategoryId;
                aTransaction.categoryLevel2Id = tModel.categoryId;
                aTransaction.categoryLevel3Id = tModel.detailCategoryId;
                aTransaction.categoryCustomId = tModel.parentCategoryId;

                convertedTransactions.add(aTransaction);
            }
        }
        serviceResult.isSuccess = true;
        BDCDataModel dataModel = new BDCDataModel();
        dataModel.bdcTransactions = new List<BDCTransaction>(convertedTransactions);
        serviceResult.data = dataModel;

        return serviceResult;
    }

    public override BDCServiceResult convertAccounts(List<HttpResponse> responses){
        BDCServiceResult serviceResult = new BDCServiceResult();

        //Create a list of generalized accounts to be returned 
        List<BDCAccount> bdcAccounts = new List<BDCAccount>();
        //convert the responses to Yodlee specific objects
        for (HttpResponse aResponse : responses) {
            AccountsResponse accountsResponse = (AccountsResponse) JSON.deserialize(
            cleanJsonResponse(aResponse.getBody()),
            AccountsResponse.class);
            
            
            //Accounts Response can return null if no Accounts have been linked
            if(aResponse.getStatusCode() != 200 || accountsResponse?.account == null ){ 
                continue;
            }

            //Yodlee getAccounts will return a success but empty body for accounts that
            //exist but are opted to not be linked via fast link.  
                //convert the Yodlee specific models to generalized models
                for (AccountModel accModel : accountsResponse.account) {
                    BDCAccount aNewBdcAccount = new BDCAccount();
                    aNewBdcAccount.Id = accModel.Id;
                    aNewBdcAccount.financialInstitutionIdentity = accModel.providerAccountId;
                    aNewBdcAccount.name = accModel.accountName;
                    aNewBdcAccount.nickname = accModel.nickname;
                    aNewBdcAccount.accountType = accModel.accountType;
                    aNewBdcAccount.accountNumber = accModel.accountNumber;
                    aNewBdcAccount.maskedAccountNumber =  accModel.accountNumber != NULL ? 'xxxx' + accModel.accountNumber.right(4) : '';
                    aNewBdcAccount.status = accModel.accountStatus;
                    aNewBdcAccount.ledgerId = null;
                    aNewBdcAccount.glAccountId = null;
                    aNewBdcAccount.source = YodleeBDCConverter.sourceApiName;
                    aNewBdcAccount.lastRefreshDate = accModel.autoRefresh.asOfDate;
                    aNewBdcAccount.initialStartDate = accModel.lastUpdated;
                    aNewBdcAccount.balance = accModel.balance.amount;
                    aNewBdcAccount.bdcCurrencyISOCode = accModel.balance != null ? accModel.balance.yodleeCurrency : MultiCurrencyHandler.CORPORATE_CURRENCY;
                    aNewBdcAccount.currentBalance = accModel.currentBalance != NULL ? accModel.currentBalance.amount : accModel.runningBalance != NULL ? accModel.runningBalance.amount : 0;
                    aNewBdcAccount.availableBalance = accModel.availableBalance != NULL ? accModel.availableBalance.amount : accModel.availableCredit != NULL ? accModel.availableCredit.amount : 0;
                    aNewBdcAccount.lastUpdated = accModel.lastUpdated;
                    bdcAccounts.add(aNewBdcAccount);
                }

        }

        serviceResult.isSuccess = true;
        BDCDataModel dataModel = new BDCDataModel();
        dataModel.bdcAccounts = new List<BDCAccount>(bdcAccounts);
        serviceResult.data = dataModel;

        return serviceResult;
    }
    
    public override BDCServiceResult convertFinancialInstitutions(List<HttpResponse> responses){
        BDCServiceResult serviceResult = new BDCServiceResult();
        //create a list with generalized financial institution types
        List<BDCFinancialInstitution> finInstModels = new List<BDCFinancialInstitution>();

        //convert the responses to a Yodlee specific object
        for (HttpResponse response : responses) {
            //parse the responses
            ProvidersResponse providersResponse = (providersResponse) JSON.deserialize(
                response.getBody(),
                ProvidersResponse.class
            );

            //Financial Instituions can return null if no Financial Instituion have been linked
            if(response.getStatusCode() != 200 || providersResponse?.provider == null ){ 
                continue;
            }

            //loop through the yodlee specific fin institutions and convert them to the generalized types
            for (ProviderModel aProviderModel : providersResponse.provider) {
                BDCFinancialInstitution finInst = new BDCFinancialInstitution();
                finInst.id = aProviderModel.id;
                finInst.name = aProviderModel.name;
                finInst.source = YodleeBDCConverter.sourceApiName;
                finInstModels.add(finInst);
            }
        }

        serviceResult.isSuccess = true;
        BDCDataModel dataModel = new BDCDataModel();
        dataModel.bdcFinancialInstitutions = new List<BDCFinancialInstitution>(finInstModels);
        serviceResult.data = dataModel;

        return serviceResult;
    }


    public override BDCServiceResult convertCategories(List<HttpResponse> responses){
        BDCServiceResult serviceResult = new BDCServiceResult();
        //create a list with generalized financial institution types
        Map<String, BDCCategory> mBDCCategories = new Map<String, BDCCategory>();

        //convert the responses to a Yodlee specific object
        for (HttpResponse response : responses) {
            //parse the responses
            TransactionCategoriesResponse categoryResponse = (TransactionCategoriesResponse) JSON.deserialize(
                response.getBody(),
                TransactionCategoriesResponse.class
            );

             //Category Response can return null if no Categories have been linked
             if(response.getStatusCode() != 200 || categoryResponse?.transactionCategory == null ){ 
                continue;
            }
          
            for (TransactionCategoryModel aCategoryModel : categoryResponse.transactionCategory) { 
                mBDCCategories.put(String.valueOf(aCategoryModel.highLevelCategoryId), 
                    createBDCCategory(String.valueOf(aCategoryModel.highLevelCategoryId), aCategoryModel.highLevelCategoryName, null, aCategoryModel.source));
                mBDCCategories.put(String.valueOf(aCategoryModel.id), 
                    createBDCCategory(String.valueOf(aCategoryModel.id), aCategoryModel.category, String.valueOf(aCategoryModel.highLevelCategoryId), aCategoryModel.source));
                if (aCategoryModel.detailCategory != null) {
                    for (TransactionDetailCategory detail : aCategoryModel.detailCategory) {
                        mBDCCategories.put(String.valueOf(detail.id), 
                            createBDCCategory(String.valueOf(detail.id), detail.name, String.valueOf(aCategoryModel.id), aCategoryModel.source));
                    }
                }
            }
        }
        serviceResult.isSuccess = true;
        BDCDataModel dataModel = new BDCDataModel();
        dataModel.bdcCategories = mBDCCategories;
        serviceResult.data = dataModel;

        return serviceResult;
   }

   //Method to convert delete Financial Institution Identity Response
    public override BDCServiceResult convertDeleteFinancialInstitutionIdentity(List<HttpResponse> responses, BDCFinancialInstitutionIdentity finInstIden){
        BDCServiceResult result = new BDCServiceResult();

        //If successful, then set result success true otherwise false
        for(HttpResponse response : responses){
            if(response.getStatusCode() >= 400) {
                BDCServiceResult.BDCError error = new BDCServiceResult.BDCError(ERR_BDC_YODLEE_API);
                result = new BDCServiceResult(null,false,new BDCServiceResult.BDCError[]{error});
            }   
            else {
                result.isSuccess = true;
            }
        }

        return result;
    }

    public Integer convertTransactionCount(List<HttpResponse> responses){
        Integer totalTransactions = 0;
        for (HttpResponse response : responses) {
            TransactionsCountResponse tcResponse = (TransactionsCountResponse) JSON.deserialize(
                cleanJsonResponse(response.getBody()),
                TransactionsCountResponse.class
            );
            //Transaction Count can return null if no Transactions have been linked
            if(response.getStatusCode() != 200 || tcResponse?.yodleeTransaction?.TOTAL?.count == null ){ 
                continue;
            }

            totalTransactions += tcResponse.yodleeTransaction.TOTAL.count;
        }
        return totalTransactions;
    }

   public static String formatDate(Date aDate) {
    return aDate.year()
        + '-'
        + FinancialSuiteUtils.leftPad(String.valueOf(aDate.month()), ((aDate.month() > 9) ? 0 : 1))
        + '-'
        + FinancialSuiteUtils.leftPad(String.valueOf(aDate.day()), ((aDate.day() > 9) ? 0 : 1));
    }

   private BDCCategory createBDCCategory(String id, String name, String parentID, String source){
        BDCCategory category = new BDCCategory();
        category.id = id;
        category.name = name;
        category.source = source;
        category.parentCategoryId = parentID;

        return category;
   }


}